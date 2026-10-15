local test = require("d2legacy.tests/v1")
return test.suite({
    profile = "module",
    tier = "fast",
    cases = {
        test.case("owner_continue_waits_for_authority_and_hardcore_opens_exit_menu", {
            test.run(function()
                local current = { tick = 7, hardcore = false, stage = "dead" }
                local pressed, pops, commands, pushed = false, 0, {}, {}
                local owner, foreign = {}, {}
                test.mock_module("engine.ecs/v1", {
                    query = function()
                        return current and { foreign, owner } or {}
                    end,
                    get = function(entity, name)
                        local values = current
                        if name == "d2legacy.world.player_control" then
                            values = { player = entity == owner and "alice" or "bob" }
                        end
                        return {
                            get = function(_, field)
                                return values[field]
                            end,
                        }
                    end,
                }, { "query", "get" })
                test.mock_module("engine.network/v1", {
                    status = function()
                        return { player_id = "alice" }
                    end,
                }, { "status" })
                test.mock_module("engine.input/v1", {
                    pressed = function(action)
                        return pressed and action == "pointer_primary"
                    end,
                }, { "pressed" })
                test.mock_module("engine.scene/v1", {
                    pop = function()
                        pops = pops + 1
                    end,
                    push = function(id)
                        pushed[#pushed + 1] = id
                    end,
                }, { "pop", "push" })
                test.mock_module("engine.render/v1", {
                    create = function()
                        return {}
                    end,
                    assets_available = function()
                        return false
                    end,
                }, { "create", "assets_available" })
                test.mock_module("engine.locale/v1", {
                    text = function(key)
                        return key
                    end,
                }, { "text" })
                test.mock_module("d2legacy.ui.text", { create = function() end }, { "create" })
                test.mock_module("d2legacy.player_intents", {
                    continue = function(tick)
                        commands[#commands + 1] = tick
                    end,
                }, { "continue" })
                local overlay = require("d2legacy.overlays.death")
                local state = {}
                overlay.enter(state)
                pressed = true
                overlay.update(state)
                test.expect(commands[1]):equals(7)
                test.expect(pops):equals(0)
                pressed = false
                current = nil
                overlay.update(state)
                test.expect(pops):equals(1)
                current = { tick = 9, hardcore = true, stage = "dead" }
                state = {}
                overlay.enter(state)
                pressed = true
                overlay.update(state)
                test.expect(#commands):equals(1)
                test.expect(pushed[1]):equals("pause")
                test.expect(overlay.blocks_update_below):equals(false)
            end),
        }),
    },
})
