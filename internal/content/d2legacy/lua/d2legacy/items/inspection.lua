-- Publish item contributions, independently of character and skill totals.
local ecs = require("engine.ecs/v1")
local resolution = require("d2legacy.policy.stat_resolution")
local M = {}

function M.defense(entities, item, armor)
    local percent = 0
    for _, entity in ipairs(entities) do
        local modifier = ecs.get(entity, "d2legacy.item.stat_modifier")
        if modifier and modifier:get("item"):id() == item:id()
            and modifier:get("stat") == "defense" and modifier:get("operation") == "local_percent" then
            percent = percent + modifier:get("value")
        end
    end
    local base = armor:get("defense")
    if percent ~= 0 and armor:get("base_defense_max") > 0 then base = armor:get("base_defense_max") + 1 end
    return resolution.local_value(base, percent)
end

local function values(entities, entity, identity)
    local result = { identified = identity:get("identified"), status = "complete",
        damage_known = false, damage_min_raw = 0, damage_max_raw = 0,
        defense_known = false, defense = 0 }
    if not result.identified then result.status = "unidentified"; return result end
    local melee = ecs.get(entity, "d2legacy.item.melee")
    local armor = ecs.get(entity, "d2legacy.item.armor")
    if not melee and not armor then result.status = "missing_facts"; return result end
    if melee and melee:get("physical_max") > 0 then
        result.damage_known = true
        result.damage_min_raw, result.damage_max_raw = melee:get("physical_min"), melee:get("physical_max")
    end
    if armor and (armor:get("defense") > 0 or string.find("," .. identity:get("item_types") .. ",", ",armo,", 1, true)) then
        result.defense_known, result.defense = true, M.defense(entities, entity, armor)
    end
    for _, candidate in ipairs(entities) do
        local modifier = ecs.get(candidate, "d2legacy.item.stat_modifier")
        if modifier and modifier:get("item"):id() == entity:id() and modifier:get("value") ~= 0
            and not (modifier:get("stat") == "defense" and modifier:get("operation") == "local_percent") then
            result.status = "partial"
        end
    end
    -- Rolled quality facts do not imply that affix effects have been implemented.
    local generation = ecs.get(entity, "d2legacy.item.generation")
    if generation and generation:get("quality") ~= "normal" then result.status = "partial" end
    return result
end

function M.snapshot(entity)
    local inspection = ecs.get(entity, "d2legacy.item.inspection")
    if not inspection then
        local identity = ecs.get(entity, "d2legacy.item.identity")
        return { status = "missing_facts", identified = identity and identity:get("identified") or false }
    end
    local value = { identified = inspection:get("identified"), status = inspection:get("status") }
    if inspection:get("damage_known") then
        value.damage = { min_raw = inspection:get("damage_min_raw"), max_raw = inspection:get("damage_max_raw") }
    end
    if inspection:get("defense_known") then value.defense = inspection:get("defense") end
    return value
end

function M.register()
    ecs.system({ id = "d2legacy.items.inspection", phase = "presentation",
        query = { any = { "d2legacy.item.identity", "d2legacy.item.stat_modifier" } },
        read = { "d2legacy.item.identity", "d2legacy.item.melee", "d2legacy.item.armor",
            "d2legacy.item.stat_modifier", "d2legacy.item.generation" },
        write = { "d2legacy.item.inspection" },
        update = function(_, entities, structural)
            for _, entity in ipairs(entities) do
                local identity = ecs.get(entity, "d2legacy.item.identity")
                if identity then structural:set(entity, "d2legacy.item.inspection", values(entities, entity, identity)) end
            end
        end,
    })
end
return M
