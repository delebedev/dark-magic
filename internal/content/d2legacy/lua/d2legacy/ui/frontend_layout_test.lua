local test = require("d2legacy.tests/v1")

return test.suite({
    name = "frontend viewport layout",
    profile = "module",
    tier = "fast",
    cases = {
        test.case("preserves_authored_controls_and_fits_asymmetric_safe_areas", function(t)
            t:run(function()
                test.mock_module("engine.display/v1", {}, {})
                test.mock_module("engine.render/v1", {}, {})
                local layout = require("d2legacy.ui.frontend_layout")
                local x, y, scale = layout.geometry(800, 600)
                test.expect(x):equals(0)
                test.expect(y):equals(0)
                test.expect(scale):equals(1)
                x, y, scale = layout.geometry(1304, 600, { left = 60, right = 20 })
                test.expect(x):equals(272)
                test.expect(y):equals(0)
                test.expect(scale):equals(1)
                x, y, scale = layout.geometry(400, 320, { top = 20 })
                test.expect(x):equals(0)
                test.expect(y):equals(20)
                test.expect(scale):equals(0.5)
            end)
        end),
        test.case("resize_updates_controls_and_cursor_before_scene_input", function(t)
            t:run(function()
                local width, height = 1304, 600
                test.mock_module("engine.display/v1", {
                    size = function()
                        return width, height
                    end,
                    geometry = function()
                        return {}
                    end,
                }, {})
                test.mock_module("engine.render/v1", {}, {})
                local layout = require("d2legacy.ui.frontend_layout")
                local state = {}
                local definition = layout.wrap({
                    create = function(self)
                        self.root = {
                            set_position = function(_, x, y)
                                self.x, self.y = x, y
                            end,
                            set_scale = function(_, x, y)
                                self.sx, self.sy = x, y
                            end,
                        }
                        self.controls = { pointer_capture = "old contact" }
                        self.cursor = {}
                    end,
                    update = function(self)
                        test.expect(self.controls.offset_x):equals(self.x)
                        test.expect(self.cursor.canvas_x):equals(self.x)
                        test.expect(self.controls.pointer_scale):equals(self.sx)
                    end,
                })
                definition.create(state)
                local clipped = {
                    set_clip = function(self, x, y, width, height)
                        self.x, self.y, self.width, self.height = x, y, width, height
                    end,
                }
                layout.clip(state.root, clipped, 10, 20, 30, 40)
                test.expect(clipped.x):equals(262)
                definition.enter(state)
                test.expect(state.x):equals(252)
                test.expect(state.controls.pointer_capture):equals(nil)
                width, height = 400, 300
                definition.update(state)
                test.expect(state.x):equals(0)
                test.expect(state.sx):equals(0.5)
                test.expect(state.sy):equals(0.5)
                test.expect(clipped.x):equals(5)
                test.expect(clipped.width):equals(15)
            end)
        end),
        test.case("background_preserves_authored_center_over_clipped_backdrop", function(t)
            t:run(function()
                local nodes = {}
                test.mock_module("engine.render/v1", {
                    assets_available = function()
                        return true
                    end,
                    create = function()
                        local node = {
                            set_dc6 = function() end,
                            set_z = function() end,
                            set_tint = function() end,
                            set_clip = function(self, x, y, width, height)
                                self.clip_x, self.clip_width = x, width
                            end,
                            set_visible = function(self, visible)
                                self.visible = visible
                            end,
                            set_position = function(self, x, y)
                                self.x, self.y = x, y
                            end,
                            set_scale = function(self, x, y)
                                self.sx, self.sy = x, y
                            end,
                        }
                        nodes[#nodes + 1] = node
                        return node
                    end,
                }, {})
                local dc6 = require("d2legacy.ui.dc6")
                local root = {}
                dc6.frontend_background(root, "hud", "background", "palette", {
                    columns = { 400, 400 },
                    rows = { 300, 300 },
                    first_frame = 0,
                    direction = 0,
                })
                dc6.resize_frontend_background(root, 1200, 600, 200, 0, 1)
                test.expect(nodes[1].sx):equals(1)
                test.expect(nodes[1].sy):equals(1)
                test.expect(nodes[1].x):equals(200)
                test.expect(nodes[5].sx):equals(1.5)
                test.expect(nodes[5].clip_x):equals(0)
                test.expect(nodes[5].clip_width):equals(200)
                test.expect(nodes[9].sx):equals(1.5)
                test.expect(nodes[9].clip_x):equals(1000)
                dc6.resize_frontend_background(root, 800, 600, 0, 0, 1)
                test.expect(nodes[1].sx):equals(1)
                test.expect(nodes[1].x):equals(200)
                test.expect(nodes[1].y):equals(150)
                test.expect(nodes[5].visible):equals(false)
            end)
        end),
    },
})
