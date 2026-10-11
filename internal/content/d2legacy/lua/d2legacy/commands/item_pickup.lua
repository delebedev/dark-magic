-- Ground items become owned inventory only after range and space checks.

local commands = require("engine.authority_command/v1")
local ecs = require("engine.ecs/v1")
local owner = require("d2legacy.items.command_owner")
local find = require("d2legacy.items.find")
local placement = require("d2legacy.items.placement")
local world = require("d2legacy.items.world")
local collision = require("d2legacy.gameplay.collision")
local M = {}

function M.validate(command)
    assert(type(command.payload) == "table", "pickup payload is required")
    owner.resolve(command)
    local id = command.payload.target_id
    assert(type(id) == "string" and id ~= "" and #id <= 128, "pickup target ID is required")
end

local function player_entity(player)
    for _, entity in ipairs(ecs.query({ all = {
        "d2legacy.player.identity", "d2legacy.world.position", "d2legacy.world.location",
    } })) do
        if ecs.get(entity, "d2legacy.player.identity"):get("player") == player then return entity end
    end
end

local function in_range(player, item)
    if ecs.get(player, "d2legacy.player.death") then return false end
    local player_location = ecs.get(player, "d2legacy.world.location")
    local item_location = ecs.get(item, "d2legacy.world.location")
    if not item_location or player_location:get("act") ~= item_location:get("act")
        or player_location:get("level_id") ~= item_location:get("level_id") then return false end
    local from = ecs.get(player, "d2legacy.world.position")
    local to = ecs.get(item, "d2legacy.world.position")
    local dx, dy = from:get("x") - to:get("x"), from:get("y") - to:get("y")
    return dx * dx + dy * dy <= 3.5 * 3.5
        and collision.line_clear(player_location:get("level_id"), from:get("x"), from:get("y"), to:get("x"), to:get("y"))
end

function M.apply(command)
    local player_id = owner.resolve(command)
    local player = player_entity(player_id)
    local layout = find.layout(player_id)
    if not player or not layout then return end
    local entities = ecs.query({ all = { "d2legacy.item.identity", "d2legacy.item.placement" } })
    for _, entity in ipairs(entities) do
        local selected = ecs.get(entity, "d2legacy.world.selectable")
        local current = ecs.get(entity, "d2legacy.item.placement")
        if selected and selected:get("id") == command.payload.target_id and current:get("container") == "world"
            and not ecs.get(entity, "d2legacy.world.inactive") and in_range(player, entity) then
            local item = ecs.get(entity, "d2legacy.item.identity")
            local destination = placement.first_free(layout, entity, item, entities)
            if not destination then return end
            item:set("owner", layout)
            placement.set(current, destination)
            world.clear(entity)
            return
        end
    end
end

function M.register()
    commands.register({ kind = "item.pickup", authorities = { "player" }, validate = M.validate, apply = M.apply })
end

return M
