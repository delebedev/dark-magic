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
        test.case("native_text_edit_uses_existing_filter_limit_and_cancel", function(t)
            t:run(function()
                local accepted = true
                test.mock_module("engine.input/v1", {
                    cursor = function()
                        return -1, -1
                    end,
                    pressed = function(action)
                        return false
                    end,
                    released = function()
                        return false
                    end,
                    down = function()
                        return false
                    end,
                    text = function()
                        return ""
                    end,
                    edit_text = function(value, title, secure)
                        test.expect(title):equals("Name")
                        test.expect(secure):equals(false)
                        return 42
                    end,
                    text_edit_result = function(id)
                        test.expect(id):equals(42)
                        return true, accepted, "newname"
                    end,
                }, {})
                local manager = require("d2legacy.ui.controls").new()
                local field = manager:add_text_field({
                    id = "name",
                    label = "Name",
                    x = 0,
                    y = 0,
                    width = 100,
                    height = 30,
                    value = "old",
                    max_length = 5,
                    filter = string.upper,
                })
                manager:activate(field)
                manager:update()
                test.expect(field.value):equals("NEWNA")
                accepted = false
                manager:activate(field)
                manager:update()
                test.expect(field.value):equals("NEWNA")
                accepted = true
                field.filter = function()
                    return nil
                end
                manager:activate(field)
                manager:update()
                test.expect(field.value):equals("")
            end)
        end),
        test.case("confirm_submits_a_text_field_without_opening_native_editor", function(t)
            t:run(function()
                local requests, submissions = 0, 0
                test.mock_module("engine.input/v1", {
                    cursor = function()
                        return -1, -1
                    end,
                    pressed = function(action)
                        return action == "confirm"
                    end,
                    released = function()
                        return false
                    end,
                    down = function()
                        return false
                    end,
                    text = function()
                        return ""
                    end,
                    edit_text = function()
                        requests = requests + 1
                        return 42
                    end,
                    text_edit_result = function()
                        return false, false, ""
                    end,
                }, {})
                local manager = require("d2legacy.ui.controls").new()
                local field = manager:add_text_field({
                    id = "name",
                    value = "Hero",
                    x = 0,
                    y = 0,
                    width = 100,
                    height = 30,
                    on_activate = function()
                        submissions = submissions + 1
                    end,
                })
                manager:set_focus(field)
                manager:update()
                test.expect(submissions):equals(1)
                test.expect(requests):equals(0)
                test.expect(field.native_edit):equals(nil)
            end)
        end),
        test.case("pointer_trace_distinguishes_capture_from_activation", function(t)
            t:run(function()
                local frame = { x = 220, y = 20 }
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
                manager.pointer_scale = 2
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
                frame.x, frame.pressed, frame.released = 220, true, false
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
