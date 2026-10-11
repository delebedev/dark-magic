-- Opt-in observations of input delivery, UI activation, and submitted intent.
local dev = require("engine.dev/v1")
local display = require("engine.display/v1")
local input = require("engine.input/v1")
local render = require("engine.render/v1")
local text = require("d2legacy.ui.text")

local M = {}

function M.create(parent, controls)
    if not dev.option("input_diagnostics") then return nil end
    local width = display.size()
    local root = render.create("hud", parent)
    root:set_z(1600000)
    local background = render.create("hud", root)
    background:fill_rect(1, 1, 0, 0, 0, 210)
    background:set_scale(width - 80, 52)
    background:set_position(width / 2, 110)
    local label = render.create("hud", root)
    label:set_position(width / 2, 110)
    local marker = render.create("hud", root)
    for _, size in ipairs({ { 13, 1 }, { 1, 13 } }) do
        local line = render.create("hud", marker)
        line:fill_rect(1, 1, 255, 220, 80, 255)
        line:set_scale(size[1], size[2])
    end
    if controls then controls.pointer_trace = {} end
    return { root = root, label = label, background = background, marker = marker, width = width,
        controls = controls, presses = 0, releases = 0, intent = "none" }
end

function M.record(state, kind, x, y, target)
    if not state then return end
    state.intent = string.format("%s %.1f,%.1f %s", kind, x, y, target or "ground")
end

function M.update(state, hero_x, hero_y)
    if not state then return end
    local width, height = display.size()
    if state.width ~= width then
        state.width = width
        state.background:set_scale(width - 80, 52)
        state.background:set_position(width / 2, 110)
        state.label:set_position(width / 2, 110)
        state.value = nil
    end
    local x, y = input.cursor()
    local contacts = input.contacts()
    if #contacts > 0 then state.source = input.pointer_source() end
    if input.pressed("pointer_primary") then state.presses = state.presses + 1 end
    if input.released("pointer_primary") then state.releases = state.releases + 1 end
    if input.pressed("pointer_primary") or input.released("pointer_primary") or input.down("pointer_primary") then
        state.x, state.y, state.source = x, y, input.pointer_source()
    end
    state.marker:set_position(state.x or x, state.y or y)
    state.marker:set_visible(state.presses > 0)
    local trace = state.controls and state.controls.pointer_trace or {}
    local value = string.format(
        "%dx%d  %s %.0f,%.0f  PRESS %d RELEASE %d HELD %s CONTACTS %d\nUI %s  ACTIVATED %s (%d)\nINTENT %s  PLAYER %.1f,%.1f",
        width, height, state.source or "native", state.x or x, state.y or y, state.presses, state.releases, tostring(input.down("pointer_primary")), #contacts,
        trace.hover or "none", trace.activation or "none", trace.activations or 0,
        state.intent, hero_x, hero_y)
    if value ~= state.value then
        text.set(state.label, "font_lab_color", value, state.width - 100, "center")
        state.value = value
    end
end

function M.destroy(state)
    if not state then return end
    if state.controls then state.controls.pointer_trace = nil end
    state.root:destroy()
end

return M
