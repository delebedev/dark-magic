local test = require("d2legacy.tests/v1")

return test.suite({
    name = "click indicator",
    profile = "module",
    tier = "fast",
    cases = {
        test.case("marks_one_press_and_expires_without_consuming_input", function(t)
            t:run(function()
                local enabled, pressed, created = false, false, 0
                local function node()
                    created = created + 1
                    return {
                        set_z = function() end,
                        fill_rect = function() end,
                        set_scale = function() end,
                        set_rotation = function() end,
                        set_position = function(self, x, y)
                            self.x, self.y = x, y
                        end,
                        set_visible = function(self, visible)
                            self.visible = visible
                        end,
                        destroy = function(self)
                            self.destroyed = true
                        end,
                    }
                end
                test.mock_module("engine.dev/v1", {
                    option = function()
                        return enabled
                    end,
                }, {})
                test.mock_module("engine.render/v1", { create = node }, {})
                test.mock_module("engine.input/v1", {
                    pressed = function()
                        return pressed
                    end,
                    cursor = function()
                        return 123, 234
                    end,
                }, {})
                local indicator = require("d2legacy.dev.click_indicator")
                test.expect(indicator.create(nil)):equals(nil)
                test.expect(created):equals(0)
                enabled = true
                local state = indicator.create(nil)
                test.expect(state.root.visible):equals(false)
                pressed = true
                indicator.update(state, 0.01)
                test.expect(pressed):equals(true)
                test.expect(state.root.x):equals(123)
                test.expect(state.root.y):equals(234)
                test.expect(state.root.visible):equals(true)
                pressed = false
                indicator.update(state, 0.2)
                test.expect(state.root.visible):equals(true)
                indicator.update(state, 0.3)
                test.expect(state.root.visible):equals(false)
                indicator.destroy(state)
                test.expect(state.root.destroyed):equals(true)
            end)
        end),
    },
})
