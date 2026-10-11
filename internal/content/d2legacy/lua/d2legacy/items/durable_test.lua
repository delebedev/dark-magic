local test = require("d2legacy.tests/v1")
local durable = require("d2legacy.items.durable")

local function inventory()
    return {
        inventory_width = 10, inventory_height = 4,
        stash_width = 6, stash_height = 8, cube_width = 3, cube_height = 4,
        vendor_width = 10, vendor_height = 10, belt_capacity = 4,
        active_weapon_set = 0, carried_gold = 0, stashed_gold = 0,
        items = {{ id = "sword", code = "ssd", container = "inventory",
            width = 1, height = 3, x = 0, y = 0, weapon_set = 0, belt_slot = 0, page = 0 }},
    }
end

return test.suite({
    name = "durable possessions", profile = "module", tier = "fast",
    cases = {
        test.case("corpse_items_require_distinct_bounded_owned_roots_and_original_slots", function(t)
            t:run(function()
                local function corpse_inventory()
                    local data = inventory()
                    data.corpses = { { id = "first" }, { id = "second" } }
                    local item = data.items[1]
                    item.container, item.corpse_id = "corpse", "first"
                    item.slot, item.body_slots = "rarm", "rarm,larm"
                    data.items[2] = { id = "other", code = "ssd", container = "corpse", corpse_id = "second",
                        slot = "rarm", body_slots = "rarm,larm", width = 1, height = 3,
                        x = 0, y = 0, weapon_set = 0, belt_slot = 0, page = 0 }
                    return data
                end
                durable.validate(corpse_inventory(), nil)
                for _, mutate in ipairs({
                    function(data) data.items[1].corpse_id = "missing" end,
                    function(data) data.corpses[2].id = "first" end,
                    function(data) data.items[2].corpse_id = "first" end,
                    function(data) data.items[1].container = "equipment" end,
                    function(data) data.items[1].slot = "head" end,
                    function(data) data.corpses[1].id = string.rep("x", 115) end,
                    function(data) for index = 3, 17 do data.corpses[index] = { id = tostring(index) } end end,
                }) do
                    local data = corpse_inventory()
                    mutate(data)
                    test.expect(pcall(durable.validate, data, nil)):equals(false)
                end
            end)
        end),
        test.case("rejects_bad_placements_before_admission", function(t)
            t:run(function()
                durable.validate(inventory(), nil)
                local mutations = {
                    function(data) data.items[1].container = "world" end,
                    function(data) data.items[1].x = 10 end,
                    function(data) data.items[1].id = string.rep("x", 129) end,
                    function(data) data.items[1].physical_min = -1 end,
                    function(data)
                        data.items[1].stat_modifiers = {{ source_kind = "item", source_id = "bad",
                            stat = "defense", operation = "bogus", order = 0, value = 1 }}
                    end,
                    function(data)
                        data.items[1].container, data.items[1].slot = "equipment", "tors"
                    end,
                    function(data)
                        data.items[2] = { id = "other", code = "ssd", container = "inventory",
                            width = 1, height = 3, x = 0, y = 0, weapon_set = 0, belt_slot = 0, page = 0 }
                    end,
                }
                for _, mutate in ipairs(mutations) do
                    local data = inventory()
                    mutate(data)
                    test.expect(pcall(durable.validate, data, nil)):equals(false)
                end
            end)
        end),
    },
})
