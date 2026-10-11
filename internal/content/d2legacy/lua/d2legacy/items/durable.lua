-- Validate portable possessions before player admission mutates ECS.
local M = {}
local containers = { inventory=true, stash=true, cube=true, equipment=true,
    hireling=true, belt=true, quest_service=true, held=true, corpse=true }

local function integer(value, minimum, maximum)
    return type(value)=="number" and value==math.floor(value)
        and value>=minimum and value<=maximum
end

local function text(value, maximum)
    return type(value) == "string" and #value <= maximum and not value:find("\0", 1, true)
end

local function occupied(item, other)
    if item.container ~= other.container then return false end
    if item.container == "corpse" and item.corpse_id ~= other.corpse_id then return false end
    if item.container == "inventory" or item.container == "stash" or item.container == "cube" then
        return item.x < other.x + other.width and other.x < item.x + item.width
            and item.y < other.y + other.height and other.y < item.y + item.height
    elseif item.container == "belt" then
        return item.belt_slot == other.belt_slot
    elseif item.container == "held" then
        return true
    end
    return item.slot == other.slot and (item.container ~= "equipment" and item.container ~= "corpse"
        or item.slot ~= "rarm" and item.slot ~= "larm" or item.weapon_set == other.weapon_set)
end

function M.validate(inventory, progression)
    if inventory then
        assert(type(inventory)=="table" and type(inventory.items)=="table" and #inventory.items<=256,
            "durable inventory is invalid")
        for _, field in ipairs({"inventory_width","inventory_height","stash_width","stash_height",
            "cube_width","cube_height","vendor_width","vendor_height","belt_capacity"}) do
            assert(integer(inventory[field],0,16), "durable layout dimension is invalid")
        end
        assert(integer(inventory.active_weapon_set,0,1), "durable weapon set is invalid")
        assert(integer(inventory.carried_gold,0,2147483647)
            and integer(inventory.stashed_gold,0,2147483647), "durable gold is invalid")
        local corpses = {}
        assert(inventory.corpses == nil or type(inventory.corpses) == "table"
            and #inventory.corpses <= 16, "durable corpses exceed bounds")
        for _, corpse in ipairs(inventory.corpses or {}) do
            assert(type(corpse) == "table" and text(corpse.id, 114) and corpse.id ~= ""
                and not corpses[corpse.id], "durable corpse ID is invalid")
            corpses[corpse.id] = true
        end
        local ids={}
        for index, item in ipairs(inventory.items) do
            assert(text(item.id,128) and item.id~="" and not ids[item.id],
                "durable item ID is invalid")
            ids[item.id]=true
            assert(text(item.code,64) and item.code~="", "durable item code is invalid")
            assert(containers[item.container], "ground and vendor items cannot be admitted as possessions")
            assert(integer(item.width,1,16) and integer(item.height,1,16)
                and integer(item.x,0,16) and integer(item.y,0,16), "durable footprint is invalid")
            if item.container=="inventory" or item.container=="stash" or item.container=="cube" then
                assert(item.x+item.width<=inventory[item.container.."_width"]
                    and item.y+item.height<=inventory[item.container.."_height"], "durable item exceeds grid")
            end
            assert(integer(item.weapon_set,0,1) and integer(item.belt_slot,0,15)
                and item.page==0, "durable item placement is invalid")
            if item.container == "corpse" then
                assert(text(item.corpse_id, 114) and corpses[item.corpse_id], "durable corpse item is unbound")
            else
                assert(item.corpse_id == nil or item.corpse_id == "", "live item has a corpse link")
            end
            if item.container == "equipment" or item.container == "hireling" or item.container == "corpse" then
                assert(type(item.slot) == "string" and item.slot ~= ""
                    and ("," .. (item.body_slots or "") .. ","):find("," .. item.slot .. ",", 1, true),
                    "durable body slot is invalid")
                assert(item.weapon_set == 0 or (item.container == "equipment" or item.container == "corpse")
                    and (item.slot == "rarm" or item.slot == "larm"), "durable shared weapon set is invalid")
            elseif item.container == "quest_service" then
                assert(type(item.slot) == "string" and item.slot ~= "", "durable service slot is invalid")
            elseif item.container == "belt" then
                assert(item.belt_eligible == true and item.belt_slot < inventory.belt_capacity,
                    "durable belt slot is invalid")
            end
            for other = 1, index - 1 do
                assert(not occupied(item, inventory.items[other]), "durable item placement is occupied")
            end
            assert(type(item.stat_modifiers or {})=="table" and #(item.stat_modifiers or {})<=128,
                "durable item modifiers exceed bounds")
            for _, field in ipairs({"item_types","body_slots","applied_services","slot","inventory_dc6",
                "world_dc6","composite","weapon_class","melee_weapon_class"}) do
                assert(item[field]==nil or text(item[field],512),
                    "durable item text is invalid")
            end
            assert((item.base_cost or 0) >= 0 and (item.defense or 0) >= 0
                and (item.physical_min or 0) >= 0 and (item.physical_max or 0) >= (item.physical_min or 0),
                "durable item mechanics are invalid")
            for _, field in ipairs({"material_flags","base_cost","physical_min","physical_max","attack_rating",
                "attack_rate","defense","base_defense_max","speed_penalty"}) do
                assert(integer(item[field] or 0,-2147483648,2147483647), "durable item number is invalid")
            end
            assert(type(item.melee_range or 0)=="number" and (item.melee_range or 0)>=0
                and (item.melee_range or 0)<=64, "durable melee range is invalid")
            for _, field in ipairs({"identified","belt_eligible","world_animated"}) do
                assert(item[field]==nil or type(item[field])=="boolean", "durable item flag is invalid")
            end
            if item.generation then
                assert(type(item.generation.quality)=="string" and #item.generation.quality<=32
                    and integer(item.generation.level,0,255) and type(item.generation.facts)=="string"
                    and #item.generation.facts<=65536, "durable generation is invalid")
            end
            local modifier_ids={}
            for _, modifier in ipairs(item.stat_modifiers or {}) do
                for _, field in ipairs({"source_kind","source_id","stat","operation"}) do
                    assert(type(modifier[field])=="string" and #modifier[field]<=128,
                        "durable modifier text is invalid")
                end
                assert(integer(modifier.order,0,2147483647)
                    and integer(modifier.value,-2147483648,2147483647), "durable modifier number is invalid")
                assert(modifier.operation=="add" or modifier.operation=="percent",
                    "durable modifier operation is invalid")
                local id=modifier.source_kind..":"..modifier.order..":"..modifier.source_id
                assert(not modifier_ids[id], "duplicate durable modifier")
                modifier_ids[id]=true
            end
        end
    end
    if progression then
        assert(integer(progression.unspent_skill_points,0,1000000)
            and integer(progression.highest_completed_difficulty,-1,2), "durable progression is invalid")
        assert(type(progression.skills)=="table" and #progression.skills<=512, "durable skills exceed bounds")
        local ids={}
        for _, skill in ipairs(progression.skills) do
            assert(integer(skill.skill_id,0,4095) and integer(skill.level,1,255) and not ids[skill.skill_id],
                "durable skill is invalid")
            ids[skill.skill_id]=true
        end
        if #progression.skills>0 then
            assert(ids[progression.left_skill] and ids[progression.right_skill], "durable skill selection is invalid")
        end
        if progression.quest then
            local quest=progression.quest
            assert(integer(quest.quest_id,1,64) and integer(quest.stage,0,255)
                and type(quest.completed)=="boolean" and type(quest.rewarded)=="boolean"
                and (not quest.rewarded or quest.completed), "durable quest is invalid")
        end
    end
end

return M
