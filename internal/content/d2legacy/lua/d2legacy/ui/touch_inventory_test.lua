local test = require("d2legacy.tests/v1")
local function mock_presentation()
    test.mock_module("engine.render/v1", {}, {})
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
    test.mock_module("engine.input/v1", {}, {})
    test.mock_module("engine.display/v1", {}, {})
    test.mock_module("d2legacy.ui.text", { set = function() end }, {})
end
return test.suite({
    name = "touch inventory",
    profile = "module",
    tier = "fast",
    cases = {
        test.case("selects_without_moving_and_submits_only_explicit_actions", function(t)
            t:run(function()
                mock_presentation()
                local requests = {}
                local sword = { id = "sword", container = "inventory", width = 1, height = 3, x = 0, y = 0 }
                local self = {
                    touch = {},
                    item_snapshot = { items = { sword } },
                    items = {
                        move = function(id, destination, held)
                            requests[#requests + 1] = { id = id, destination = destination, held = held }
                            return "move:1"
                        end,
                    },
                }
                local ui = require("d2legacy.ui.touch_inventory")
                test.expect(ui.select(self, nil)):equals(false)
                test.expect(ui.request(self, { container = "equipment", slot = "rarm" })):equals(false)
                test.expect(ui.select(self, sword)):equals(true)
                test.expect(ui.select(self, sword)):equals(false)
                test.expect(#requests):equals(0)
                test.expect(sword.container):equals("inventory")
                test.expect(ui.request(self, { container = "equipment", slot = "rarm" })):equals(true)
                test.expect(#requests):equals(1)
                test.expect(requests[1].held):equals(false)
                test.expect(self.touch.pending.token):equals("move:1")
                test.expect(ui.request(self, { container = "equipment", slot = "larm" })):equals(false)
                test.expect(ui.select(self, nil)):equals(false)
                test.expect(#requests):equals(1)
                test.expect(self.touch.selected_id):equals("sword")
            end)
        end),
        test.case("expands_item_selection_but_prefers_an_actual_neighbor", function(t)
            t:run(function()
                mock_presentation()
                test.mock_module("engine.display/v1", {
                    geometry = function()
                        return { scale_x = 2, scale_y = 2 }
                    end,
                }, {})
                local sword = { id = "sword", container = "inventory", width = 1, height = 3, x = 0, y = 0 }
                local potion = { id = "potion", container = "inventory", width = 1, height = 1, x = 1, y = 0 }
                local self = {
                    grid_left = 100,
                    grid_top = 100,
                    cell_width = 32,
                    cell_height = 32,
                    item_snapshot = { items = { sword, potion } },
                }
                local ui = require("d2legacy.ui.touch_inventory")
                test.expect(ui.item_at(self, 90, 130).id):equals("sword")
                test.expect(ui.item_at(self, 140, 115).id):equals("potion")
                test.expect(ui.item_at(self, 70, 130)):equals(nil)
            end)
        end),
        test.case("waits_for_its_authority_result_and_recovers_after_refusal", function(t)
            t:run(function()
                mock_presentation()
                local function node()
                    return {
                        set_z = function() end,
                        fill_rect = function() end,
                        set_scale = function() end,
                        set_position = function() end,
                        set_visible = function() end,
                        set_tint = function() end,
                        set_dc6 = function()
                            return 96, 32
                        end,
                        destroy = function() end,
                    }
                end
                test.mock_module("engine.render/v1", { create = node }, {})
                local geometry = { scale_x = 1.5, scale_y = 1.5, left = 90, top = 0, right = 90, bottom = 30 }
                test.mock_module("engine.display/v1", {
                    geometry = function()
                        return geometry
                    end,
                }, {})
                test.mock_module("d2legacy.ui.text", {
                    set = function()
                        return 64, 16
                    end,
                }, {})
                test.mock_module("engine.records/v1", {
                    load = function()
                        return {}
                    end,
                }, {})
                local ui = require("d2legacy.ui.touch_inventory")
                local sword = {
                    id = "sword",
                    code = "ssd",
                    body_slots = "rarm,larm",
                    inventory_dc6 = "sword",
                    container = "inventory",
                    width = 1,
                    height = 3,
                    x = 0,
                    y = 0,
                }
                local sequence = 0
                local self = {
                    root = node(),
                    controls = require("d2legacy.ui.controls").new(),
                    equipment_slots = {},
                    grid_left = 410,
                    grid_top = 300,
                    cell_width = 32,
                    cell_height = 32,
                    item_palette = "palette",
                    item_snapshot = { items = { sword }, move_result = { token = "", reason = "" } },
                    items = {
                        move = function()
                            sequence = sequence + 1
                            return "move:" .. sequence
                        end,
                    },
                }
                self.controls.offset_x = 500
                ui.create(self, "palette")
                ui.select(self, sword)
                self.touch.moving = true
                ui.request(self, { container = "equipment", slot = "head" })
                self.item_snapshot.move_result = { token = "unrelated", item_id = "sword", reason = "" }
                ui.refresh(self)
                test.expect(self.touch.pending.token):equals("move:1")
                local close = self.touch.close.control
                local close_x, close_y = close.x, close.y
                close.on_state(close, "pressed")
                test.expect(close.x):equals(close_x)
                test.expect(close.y):equals(close_y)
                self.item_snapshot.move_result =
                    { token = "move:1", item_id = "sword", reason = "item cannot use body slot" }
                ui.refresh(self)
                test.expect(self.touch.pending):equals(nil)
                test.expect(self.touch.moving):equals(true)
                test.expect(self.touch.feedback):equals("[red]Cannot equip in that slot.[/]")
                ui.request(self, { container = "equipment", slot = "rarm" })
                sword.container, sword.slot, sword.weapon_set = "equipment", "rarm", 0
                self.item_snapshot.move_result = { token = "move:2", item_id = "sword", reason = "" }
                ui.refresh(self)
                test.expect(self.touch.moving):equals(false)
                test.expect(self.touch.selected_id):equals("sword")
                test.expect(self.touch.feedback):equals("[green]Equipped right hand.[/]")
            end)
        end),
    },
})
