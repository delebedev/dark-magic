local test = require("d2legacy.tests/v1")

return test.suite({
    name = "input diagnostics",
    profile = "module",
    tier = "fast",
    cases = {
        test.case("observes_taps_and_viewport_without_changing_intent", function(t)
            t:run(function()
                local enabled, width, pressed, released = false, 800, false, false
                local created, label = 0, ""
                local function node()
                    created = created + 1
                    return {
                        set_z = function() end,
                        fill_rect = function() end,
                        set_scale = function() end,
                        set_position = function() end,
                        set_visible = function() end,
                        destroy = function() end,
                    }
                end
                test.mock_module("engine.dev/v1", {
                    option = function()
                        return enabled
                    end,
                }, {})
                test.mock_module("engine.display/v1", {
                    size = function()
                        return width, 600
                    end,
                }, {})
                test.mock_module("engine.render/v1", { create = node }, {})
                test.mock_module("engine.input/v1", {
                    cursor = function()
                        return 1100, 200
                    end,
                    contacts = function()
                        return {}
                    end,
                    pressed = function()
                        return pressed
                    end,
                    released = function()
                        return released
                    end,
                    down = function()
                        return pressed
                    end,
                    pointer_source = function()
                        return "probe"
                    end,
                }, {})
                test.mock_module("d2legacy.ui.text", {
                    set = function(_, _, value)
                        label = value
                    end,
                }, {})
                local diagnostic = require("d2legacy.dev.input_diagnostics")
                test.expect(diagnostic.create(nil, nil)):equals(nil)
                test.expect(created):equals(0)
                enabled = true
                local controls = {}
                local state = diagnostic.create(nil, controls)
                diagnostic.record(state, "move", 12, 30)
                width, pressed = 1304, true
                diagnostic.update(state, 9, 20)
                pressed, released = false, true
                diagnostic.update(state, 10, 20, 2)
                test.expect(state.presses):equals(1)
                test.expect(state.releases):equals(1)
                test.expect(state.width):equals(1304)
                test.expect(state.intent):equals("move 12.0,30.0 ground")
                test.expect(label:find("probe 1100,200", 1, true) ~= nil):equals(true)
                test.expect(label:find("LEVEL 2 PLAYER 10.0,20.0", 1, true) ~= nil):equals(true)
                diagnostic.destroy(state)
                test.expect(controls.pointer_trace):equals(nil)
            end)
        end),
    },
})
