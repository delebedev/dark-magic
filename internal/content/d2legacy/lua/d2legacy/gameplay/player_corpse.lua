-- Owned equipment storage and recovery use the existing item layout.
local ecs = require("engine.ecs/v1")
local initial = require("engine.initial_data/v1")
local find = require("d2legacy.items.find")
local placement = require("d2legacy.items.placement")
local world = require("d2legacy.items.world")
local transition = require("d2legacy.gameplay.transition")
local collision = require("d2legacy.gameplay.collision")
local M = {}

local function corpse_components(player, id, act, level_id, x, y)
    local identity = assert(ecs.get(player, "d2legacy.player.identity"))
    return {
        ["d2legacy.player.corpse"] = { id = id, owner = player },
        ["d2legacy.world.position"] = { x = x, y = y },
        ["d2legacy.world.location"] = { act = act, level_id = level_id },
        ["d2legacy.world.room_attach"] = { id = "player_corpse:" .. id },
        ["d2legacy.world.selectable"] = {
            id = "player_corpse:" .. id, kind = "player_corpse",
            label = identity:get("name"), owner = identity:get("player"), radius = 3.5, priority = 15,
        },
    }
end

function M.capture(entities, structural, player, tick)
    local identity = ecs.get(player, "d2legacy.player.identity")
    local layout = find.layout(identity:get("player"), entities)
    local gear, ids, count = {}, {}, 0
    for _, entity in ipairs(entities) do
        local corpse = ecs.get(entity, "d2legacy.player.corpse")
        if corpse then
            ids[corpse:get("id")] = true
            if corpse:get("owner"):id() == player:id() then count = count + 1 end
        end
        local item = ecs.get(entity, "d2legacy.item.identity")
        local placed = ecs.get(entity, "d2legacy.item.placement")
        if layout and item and placed and item:get("owner"):id() == layout:id()
            and placed:get("container") == "equipment" then gear[#gear + 1] = entity end
    end
    if #gear == 0 then return true end
    if count >= 16 then return false end
    local base = "corpse:" .. identity:get("character_id"):sub(1, 80) .. ":" .. tick
    local id, suffix = base, 0
    while ids[id] do suffix = suffix + 1; id = base .. ":" .. suffix end
    local location = ecs.get(player, "d2legacy.world.location")
    local position = ecs.get(player, "d2legacy.world.position")
    structural:create(corpse_components(player, id, location:get("act"), location:get("level_id"),
        position:get("x"), position:get("y")))
    for _, item in ipairs(gear) do
        ecs.get(item, "d2legacy.item.placement"):set("container", "corpse")
        structural:set(item, "d2legacy.item.corpse", { id = id })
    end
    return true
end

function M.restore(player, inventory, entry)
    if not inventory or #(inventory.corpses or {}) == 0 then return end
    local respawn = initial.get("d2legacy.respawn")
    local level_id = respawn and respawn.level_id or entry.level_id
    local act = respawn and respawn.act or entry.act
    local x = math.max(0, (respawn and respawn.x or entry.x) - 1)
    local y = math.max(0, (respawn and respawn.y or entry.y) - 1)
    local map = collision.for_level(level_id)
    if map and map:blocked_position(x, y) then
        x, y = respawn and respawn.x or entry.x, respawn and respawn.y or entry.y
    end
    for _, corpse in ipairs(inventory.corpses or {}) do
        ecs.create(corpse_components(player, corpse.id, act, level_id, x, y))
    end
    local layout = find.layout(entry.player)
    for _, item in ipairs(inventory.items) do
        if item.container == "corpse" then
            local entity = assert(find.item(layout, item.id))
            ecs.set(entity, "d2legacy.item.corpse", { id = item.corpse_id })
        end
    end
end

function M.continue(player, tick, death_tick)
    local death = ecs.get(player, "d2legacy.player.death")
    if not death or death:get("tick") ~= death_tick or death:get("hardcore")
        or death:get("stage") == "capacity_exhausted" then return end
    local destination = initial.get("d2legacy.respawn")
    if not destination then return end
    transition.validate(destination)
    transition.apply(player, destination)
    if destination.act then ecs.get(player, "d2legacy.world.location"):set("act", destination.act) end
    local vitals = ecs.get(player, "d2legacy.player.vitals")
    for _, name in ipairs({ "health", "mana", "mana_raw", "stamina", "stamina_raw" }) do
        vitals:set(name, vitals:get("max_" .. name))
    end
    ecs.remove(player, "d2legacy.player.death")
    local animation = ecs.get(player, "d2legacy.player.animation")
    animation:set("mode", "NU")
    animation:set("start_tick", tick)
end

function M.recover(player, target_id)
    if ecs.get(player, "d2legacy.player.death") then return end
    local wanted
    for _, entity in ipairs(ecs.query({ all = { "d2legacy.player.corpse", "d2legacy.world.selectable" } })) do
        local corpse = ecs.get(entity, "d2legacy.player.corpse")
        if ecs.get(entity, "d2legacy.world.selectable"):get("id") == target_id
            and corpse:get("owner"):id() == player:id() then wanted = entity; break end
    end
    if not wanted or not world.can_pick_up(player, wanted) then return end
    local id = ecs.get(wanted, "d2legacy.player.corpse"):get("id")
    local layout_entity, layout = find.layout(ecs.get(player, "d2legacy.player.identity"):get("player"))
    local entities = ecs.query({ all = { "d2legacy.item.identity", "d2legacy.item.placement" } })
    local gear = {}
    for _, entity in ipairs(entities) do
        local link = ecs.get(entity, "d2legacy.item.corpse")
        local item = ecs.get(entity, "d2legacy.item.identity")
        local placed = ecs.get(entity, "d2legacy.item.placement")
        if link and link:get("id") == id and item:get("owner"):id() == layout_entity:id()
            and placed:get("container") == "corpse" then
            local destination = placed:snapshot()
            destination.container = "equipment"
            local _, refusal = placement.validate(layout, entity, item, destination, entities, false)
            -- shortcut: Occupied original slots refuse the entire recovery.
            -- Inventory fallback and native partial recovery remain outside this slice.
            if refusal then return end
            gear[#gear + 1] = { entity = entity, destination = destination }
        end
    end
    for _, item in ipairs(gear) do
        placement.set(ecs.get(item.entity, "d2legacy.item.placement"), item.destination)
        ecs.remove(item.entity, "d2legacy.item.corpse")
    end
    ecs.destroy(wanted)
end

return M
