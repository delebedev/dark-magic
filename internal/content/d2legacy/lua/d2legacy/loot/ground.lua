-- Materialize one death's already-rolled loot without rolling it again.

local ecs = require("engine.ecs/v1")
local bases = require("d2legacy.loot.items")
local generation = require("d2legacy.loot.generate")
local item_entity = require("d2legacy.items.entity")
local M = {}

local function layout_for(entities, credited_id)
    local owner
    for _, entity in ipairs(entities) do
        local identity = ecs.get(entity, "d2legacy.player.identity")
        local selected = ecs.get(entity, "d2legacy.world.selectable")
        if identity and selected and selected:get("id") == credited_id then
            owner = identity:get("player")
            break
        end
    end
    local fallback
    for _, entity in ipairs(entities) do
        local layout = ecs.get(entity, "d2legacy.items.layout")
        if layout then
            fallback = fallback or entity
            if layout:get("owner") == owner then return entity end
        end
    end
    return fallback
end

local function available_id(entities, base)
    local used = {}
    for _, entity in ipairs(entities) do
        local item = ecs.get(entity, "d2legacy.item.identity")
        if item then used[item:get("id")] = true end
    end
    local id, suffix = base, 1
    while used[id] do
        suffix = suffix + 1
        id = base .. ":" .. suffix
    end
    return id
end

function M.spawn(context, entities, structural, monster, drops, credited_id)
    local layout = layout_for(entities, credited_id)
    local position = ecs.get(monster, "d2legacy.world.position")
    local location = ecs.get(monster, "d2legacy.world.location")
    if not layout or not position or not location then return end

    for index, drop in ipairs(drops) do
        local base = bases.base(drop.code)
        -- shortcut: currency amounts and specialized quality effects remain in
        -- the rolled facts; extend their policies before claiming full loot fidelity.
        if base and drop.code ~= "gld" and base.width > 0 and base.height > 0 then
            local item = {}
            for key, value in pairs(base) do item[key] = value end
            item.id = available_id(entities,
                "loot:" .. context.tick .. ":" .. monster:id() .. ":" .. index)
            item.container = "world"
            item.x, item.y = math.floor(position:get("x")), math.floor(position:get("y"))
            item.act, item.level_id = location:get("act"), location:get("level_id")
            item.identified = drop.quality == "normal" or drop.quality == "superior" or drop.quality == "low"
            item.generation = {
                quality = drop.quality, level = drop.level,
                facts = generation.encode({drop}),
            }
            structural:create(item_entity.components(layout, item))
        end
    end
end

return M
