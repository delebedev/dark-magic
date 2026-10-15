local test = require("d2legacy.tests/v1")

local function load_controls()
    test.mock_module("engine.input/v1", {}, {})
    return require("d2legacy.ui.controls")
end

return test.suite({
    name = "shared UI control state",
    profile = "module",
    tier = "fast",
    cases = {
        test.case("pointer_trace_distinguishes_capture_from_activation", function(t)
            t:run(function()
                local frame = { x = 210, y = 10 }
                test.mock_module("engine.input/v1", {
                    cursor = function()
                        return frame.x, frame.y
                    end,
                    pressed = function(action)
                        return action == "pointer_primary" and frame.pressed or false
                    end,
                    released = function(action)
                        return action == "pointer_primary" and frame.released or false
                    end,
                    down = function()
                        return false
                    end,
                }, {})
                local manager = require("d2legacy.ui.controls").new()
                manager.pointer_trace = {}
                manager.offset_x = 200
                local activations = 0
                manager:add({
                    id = "skill",
                    x = 0,
                    y = 0,
                    width = 44,
                    height = 44,
                    focusable = false,
                    on_activate = function()
                        activations = activations + 1
                    end,
                })
                frame.pressed = true
                manager:update()
                test.expect(manager.pointer_consumed):equals(true)
                frame.pressed, frame.released, frame.x = false, true, 300
                manager:update()
                test.expect(activations):equals(0)
                test.expect(manager.pointer_trace.capture):equals("skill")
                test.expect(manager.pointer_trace.hover):equals("none")
                test.expect(manager.pointer_consumed):equals(true)
                frame.released = false
                manager:update()
                test.expect(manager.pointer_consumed):equals(false)
                frame.x, frame.pressed, frame.released = 210, true, false
                manager:update()
                frame.pressed, frame.released = false, true
                manager:update()
                test.expect(activations):equals(1)
                test.expect(manager.pointer_trace.activation):equals("skill")
                test.expect(manager.pointer_trace.activations):equals(1)
            end)
        end),
        test.case("disabling_updates_authored_visual_state_immediately", function(t)
            t:run(function()
                local controls = load_controls()
                local manager = controls.new()
                local observed = {}
                manager:add({
                    id = "action",
                    x = 0,
                    y = 0,
                    width = 100,
                    height = 30,
                    on_state = function(_, state)
                        observed[#observed + 1] = state
                    end,
                })

                manager:set_enabled("action", false)

                test.expect(manager:get("action").state):equals("disabled")
                test.expect(observed):deep_equals({ "disabled" })
            end)
        end),
        test.case("reenabling_restores_an_opaque_normal_state", function(t)
            t:run(function()
                local controls = load_controls()
                local manager = controls.new()
                local observed = {}
                manager:add({
                    id = "action",
                    x = 0,
                    y = 0,
                    width = 100,
                    height = 30,
                    enabled = false,
                    on_state = function(_, state)
                        observed[#observed + 1] = state
                    end,
                })

                manager:set_enabled("action", true)

                test.expect(manager:get("action").state):equals("normal")
                test.expect(observed):deep_equals({ "normal" })
            end)
        end),
    },
})
