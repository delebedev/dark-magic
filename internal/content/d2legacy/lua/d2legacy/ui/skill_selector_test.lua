local test = require("d2legacy.tests/v1")

return test.suite({
    name = "skill selector",
    profile = "module",
    tier = "fast",
    cases = {
        test.case("orders_both_sides_and_assigns_through_the_hud", function(t)
            t:run(function()
                local tips, ready = 0, false
                local function node()
                    return {
                        set_dc6 = function() end,
                        set_position = function() end,
                        set_visible = function() end,
                    }
                end
                test.mock_module("engine.render/v1", {
                    create = node,
                    preload = function(requests)
                        test.expect(#requests):equals(5)
                        return 1
                    end,
                    preload_status = function()
                        return { done = ready, failed = 0 }
                    end,
                }, {})
                test.mock_module("engine.locale/v1", {
                    text = function(key)
                        return key
                    end,
                }, {})
                test.mock_module("d2legacy.ui.tooltip", {
                    create = function()
                        tips = tips + 1
                        return node()
                    end,
                }, {})
                local controls = {
                    add = function(_, control)
                        return control
                    end,
                }
                local definition = {
                    left = { y = 550 },
                    width = 48,
                    height = 48,
                    selector_left = 90,
                    selector_right = 720,
                }
                local selected
                local module = require("d2legacy.ui.skill_selector")
                local selector = module.create(nil, definition, "sky", controls, function(side, id)
                    selected = { side, id }
                end)
                local skills = {}
                for _, id in ipairs({ 40, 36, 38, 37, 39 }) do
                    skills[#skills + 1] = {
                        id = id,
                        list_row = 0,
                        left_allowed = true,
                        right_allowed = true,
                        sheet = "test",
                        icon = id,
                    }
                end
                skills[1].left_allowed = false
                module.set_skills(selector, skills)
                module.set_skills(selector, skills)
                test.expect(#selector.buttons):equals(0)
                ready = true
                module.set_skills(selector, skills)
                test.expect(#selector.buttons):equals(4)
                module.set_skills(selector, skills)
                module.set_skills(selector, skills)
                test.expect(#selector.buttons):equals(9)
                test.expect(tips):equals(0)
                for index = 1, 4 do
                    test.expect(selector.buttons[index].control.id):equals("left_skill_choice_" .. (35 + index))
                end
                for index = 1, 5 do
                    test.expect(selector.buttons[index + 4].control.id):equals("right_skill_choice_" .. (41 - index))
                end
                module.toggle(selector, "left")
                test.expect(selector.buttons[1].control.visible):equals(true)
                test.expect(selector.buttons[6].control.visible):equals(false)
                selector.buttons[1].control.on_state(nil, "hover")
                selector.buttons[1].control.on_state(nil, "pressed")
                test.expect(tips):equals(1)
                selector.buttons[1].control.on_activate()
                test.expect(selected):deep_equals({ "left", 36 })
                test.expect(selector.open):equals(nil)
            end)
        end),
    },
})
