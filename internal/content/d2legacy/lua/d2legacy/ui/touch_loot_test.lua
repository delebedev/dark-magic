local test = require("d2legacy.tests/v1")
return test.suite({
    name = "touch loot",
    profile = "module",
    tier = "fast",
    cases = {
        test.case("selection_is_read_only_and_take_waits_for_owned_snapshot", function(t)
            t:run(function()
                local function node()
                    return {
                        set_z = function() end,
                        fill_rect = function() end,
                        set_scale = function() end,
                        set_position = function() end,
                        set_visible = function(_, value)
                            test.expect(type(value)):equals("boolean")
                        end,
                        set_tint = function() end,
                        set_dc6 = function()
                            return 96, 32
                        end,
                        destroy = function() end,
                    }
                end
                local geometry = { scale_x = 1.5, scale_y = 1.5, left = 90, top = 0, right = 90, bottom = 30 }
                test.mock_module("engine.dev/v1", {
                    option = function()
                        return true
                    end,
                }, {})
                test.mock_module("engine.render/v1", { create = node }, {})
                test.mock_module("engine.display/v1", {
                    geometry = function()
                        return geometry
                    end,
                    size = function()
                        return 1304, 600
                    end,
                }, {})
                test.mock_module("engine.input/v1", {
                    cursor = function()
                        return 0, 0
                    end,
                    pressed = function()
                        return false
                    end,
                    released = function()
                        return false
                    end,
                    down = function()
                        return false
                    end,
                }, {})
                test.mock_module("engine.records/v1", {
                    load = function()
                        return {}
                    end,
                }, {})
                test.mock_module("engine.locale/v1", {
                    text = function(key)
                        return key
                    end,
                }, {})
                test.mock_module("d2legacy.loot.items", {
                    base = function(code)
                        test.expect(code):equals("ssd")
                        return { body_slots = "rarm,larm", inventory_dc6 = "sword" }
                    end,
                }, {})
                test.mock_module("d2legacy.ui.text", { set = function() end }, {})
                local present = true
                local function component(values)
                    return {
                        get = function(_, key)
                            return values[key]
                        end,
                    }
                end
                local entity = {}
                local data = {
                    ["d2legacy.world.selectable"] = component({
                        id = "item:source:blade",
                        kind = "item",
                        label = "ssd",
                        radius = 3.5,
                    }),
                    ["d2legacy.world.position"] = component({ x = 400, y = 200 }),
                    ["d2legacy.world.location"] = component({ level_id = 1 }),
                    ["d2legacy.item.presentation"] = component({ world_dc6 = "drop", inventory_dc6 = "" }),
                }
                test.mock_module("engine.ecs/v1", {
                    query = function()
                        return present and { entity } or {}
                    end,
                    get = function(_, key)
                        return data[key]
                    end,
                }, {})
                local snapshot = { items = {}, active_weapon_set = 0, move_result = {} }
                local calls = 0
                local inspection =
                    { identified = true, status = "complete", damage = { min_raw = 512, max_raw = 1536 } }
                local items = {
                    snapshot = function()
                        return snapshot
                    end,
                    inspect = function()
                        return inspection
                    end,
                }
                local ui = require("d2legacy.ui.touch_loot")
                local state = ui.create(node(), "palette", items, function()
                    calls = calls + 1
                end, function() end)
                local world = {
                    subtile_to_pixel = function(_, x, y)
                        return x, y
                    end,
                }
                local function update(dt, approaching)
                    return ui.update(state, world, 1, 0, 0, 0, 0, true, dt or 0, approaching)
                end
                update()
                ui.select(state, "item:source:blade")
                update()
                test.expect(calls):equals(0)
                test.expect(state.panel.touch.details_text):equals("On the ground\nDamage 2 - 6")
                test.expect(state.panel.touch.ground.inventory_dc6):equals("sword")
                test.expect(state.panel.touch.ground.body_slots):equals("rarm,larm")
                state.panel.controls:activate(state.panel.controls:get("item_action_1"))
                test.expect(calls):equals(1)
                update(2, true)
                test.expect(state.taking ~= nil):equals(true)
                update(2, false)
                test.expect(state.taking):equals(nil)
                test.expect(state.panel.touch.feedback):equals("[red]Not taken yet. Check reach or backpack space.[/]")
                state.panel.controls:activate(state.panel.controls:get("item_action_1"))
                test.expect(calls):equals(2)
                snapshot.items = {
                    {
                        id = "blade",
                        code = "ssd",
                        container = "inventory",
                        body_slots = "rarm,larm",
                        width = 1,
                        height = 3,
                        inventory_dc6 = "sword",
                        inspection = inspection,
                    },
                }
                present = false
                update()
                test.expect(state.panel.touch.selected_id):equals("blade")
                test.expect(state.panel.touch.feedback):equals("[green]Taken. In your backpack.[/]")
                test.expect(state.panel.touch.ground):equals(nil)
                test.expect(state.labels["item:source:blade"]):equals(nil)
                test.expect(state.panel.controls.by_id["loot:item:source:blade"]):equals(nil)
                ui.destroy(state)
            end)
        end),
    },
})
