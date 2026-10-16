local test = require("d2legacy.tests/v1")

return test.suite({
    name = "game loading layout",
    profile = "module",
    tier = "fast",
    cases = {
        test.case("artwork_stays_centered_when_frontend_canvas_resizes", function(t)
            t:run(function()
                local width, height, artwork = 800, 600, nil
                test.mock_module("engine.display/v1", {
                    size = function()
                        return width, height
                    end,
                    geometry = function()
                        return {}
                    end,
                }, {})
                test.mock_module("engine.render/v1", {
                    assets_available = function()
                        return true
                    end,
                    create = function(_, parent)
                        return {
                            parent = parent,
                            set_position = function(self, x, y)
                                self.x, self.y = x, y
                            end,
                            set_scale = function(self, x, y)
                                self.sx, self.sy = x, y
                            end,
                            fill_rect = function(self)
                                artwork = self
                            end,
                        }
                    end,
                }, {})
                test.mock_module("engine.audio/v1", { stop_group = function() end }, {})
                test.mock_module("engine.scene/v1", {
                    replace = function()
                        error("unexpected scene transition")
                    end,
                }, {})
                test.mock_module("engine.loading/v1", {
                    begin = function() end,
                    status = function()
                        return { state = "loading", progress = 0 }
                    end,
                }, {})
                test.mock_module("engine.network/v1", {
                    status = function()
                        return { phase = "local" }
                    end,
                }, {})
                test.mock_module("d2legacy.ui.loading_graphic", {
                    attach = function()
                        return 10, "loading"
                    end,
                    seek = function() end,
                }, {})
                local layout = require("d2legacy.ui.frontend_layout")
                local scene = layout.wrap(require("d2legacy.screens.game_loading"), true)
                local state = {}
                scene.enter(state)
                local function expect_center(node)
                    local x, y = 0, 0
                    while node do
                        x = x * (node.sx or 1) + (node.x or 0)
                        y = y * (node.sy or 1) + (node.y or 0)
                        node = node.parent
                    end
                    test.expect(x):equals(width / 2)
                    test.expect(y):equals(height / 2)
                end
                expect_center(artwork)
                expect_center(state.animation)
                width = 1304
                scene.update(state, 0)
                expect_center(artwork)
                expect_center(state.animation)
                width, height = 400, 300
                scene.update(state, 0)
                expect_center(artwork)
                expect_center(state.animation)
            end)
        end),
    },
})
