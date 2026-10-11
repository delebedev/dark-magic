-- A press marker acknowledges routed input, never a successful gameplay action.
local dev = require("engine.dev/v1")
local input = require("engine.input/v1")
local render = require("engine.render/v1")
local M = {}

function M.create(parent)
    if not dev.option("show_clicks") then return nil end
    local root = render.create("hud", parent)
    root:set_z(1600001)
    root:set_visible(false)
    for index = 0, 15 do
        local angle = index * math.pi / 8
        local edge = render.create("hud", root)
        edge:fill_rect(1, 1, 245, 225, 175, 210)
        edge:set_scale(5, 2)
        edge:set_position(math.cos(angle) * 14, math.sin(angle) * 14)
        edge:set_rotation(index * 22.5 + 90)
    end
    return { root = root, remaining = 0 }
end

function M.update(state, elapsed)
    if not state then return end
    state.remaining = math.max(0, state.remaining - elapsed)
    if input.pressed("pointer_primary") or input.pressed("pointer_secondary") then
        local x, y = input.cursor()
        state.root:set_position(x, y)
        state.remaining = 0.45
    end
    state.root:set_visible(state.remaining > 0)
end

function M.destroy(state)
    if state then state.root:destroy() end
end

return M
