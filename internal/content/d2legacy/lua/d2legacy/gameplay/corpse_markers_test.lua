local test = require("d2legacy.tests/v1")
return test.suite({
    profile = "module",
    tier = "fast",
    cases = {
        test.case("recovery_and_level_changes_remove_retained_corpse_marker", {
            test.run(function()
                local present, level, kind, destroyed = true, 1, "player_corpse", 0
                local entity = {
                    id = function()
                        return 1
                    end,
                }
                test.mock_module("engine.ecs/v1", {
                    query = function()
                        return present and { entity } or {}
                    end,
                    get = function(_, name)
                        local values = { kind = kind, label = "Hero", level_id = level, x = 12, y = 14 }
                        return {
                            get = function(_, key)
                                return values[key]
                            end,
                        }
                    end,
                }, { "query", "get" })
                test.mock_module("engine.render/v1", {
                    create = function()
                        return {
                            set_position = function() end,
                            set_z = function() end,
                            destroy = function()
                                destroyed = destroyed + 1
                            end,
                        }
                    end,
                }, { "create" })
                local labels = 0
                test.mock_module("d2legacy.ui.text", {
                    set = function(_, _, label)
                        labels = labels + 1
                        test.expect(label):equals("Hero's corpse")
                    end,
                }, { "set" })
                local world = {
                    canvas = function()
                        return 800, 600
                    end,
                    subtile_to_pixel = function(_, x, y)
                        return x, y
                    end,
                    entity_depth = function()
                        return 1
                    end,
                }
                local view = require("d2legacy.gameplay.corpse_markers").new({}, world, 1)
                view:update()
                view:update()
                test.expect(labels):equals(1)
                present = false
                view:update()
                test.expect(destroyed):equals(1)
                present = true
                view:update()
                level = 2
                view:update()
                test.expect(destroyed):equals(2)
                level = 1
                kind = "hostile"
                view:update()
                test.expect(labels):equals(2)
                kind = "player_corpse"
                view:update()
                view:destroy()
                test.expect(destroyed):equals(3)
            end),
        }),
    },
})
