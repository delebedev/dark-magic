local render = require("engine.render/v1")
local display = require("engine.display/v1")
local text = require("d2legacy.ui.text")
local M = {}

function M.geometry()
    return display.geometry()
end

function M.button(parent, manager, id, label, activate, palette, layer)
    local root = render.create(layer or "hud", parent)
    local skin = render.create(layer or "hud", root)
    local caption = render.create(layer or "hud", root)
    local widget = { root = root, skin = skin, caption = caption, label = label }
    widget.control = manager:add({
        id = id, label = label, x = 0, y = 0, width = 1, height = 1,
        on_activate = activate,
        on_state = function(_, state)
            widget.state = state
            local w, h = skin:set_dc6("data/global/ui/FrontEnd/CancelButtonBlank.dc6", palette, 0,
                state == "pressed" and 1 or 0)
            widget.skin_width, widget.skin_height = w, h
            skin:set_tint(state == "disabled" and 100 or 255, state == "disabled" and 100 or 255,
                state == "disabled" and 100 or 255)
            M.label(widget, widget.label)
            if widget.width then
                local sx, sy = widget.geometry.scale_x, widget.geometry.scale_y
                skin:set_scale((widget.width-8*sx)/w, (widget.height-8*sy)/h)
                caption:set_position(0, state == "pressed" and sy or 0)
            end
        end,
    })
    widget.control.on_state(widget.control, "normal")
    return widget
end

function M.label(widget, label)
    local color = widget.state == "disabled" and "grey" or "gold"
    local value = "[" .. color .. "]" .. label .. "[/]"
    if widget.text ~= value then
        text.set(widget.caption, "font_lab_color", value, 0, "center")
        widget.text, widget.label = value, label
        widget.control.label = label
    end
end

function M.place(widget, x, y, width, height, geometry)
    widget.x, widget.y, widget.width, widget.height, widget.geometry = x, y, width, height, geometry
    local sx, sy = geometry.scale_x, geometry.scale_y
    widget.root:set_position(x + width/2, y + height/2)
    widget.skin:set_scale((width - 8*sx)/widget.skin_width, (height - 8*sy)/widget.skin_height)
    widget.caption:set_scale(sx, sy)
    widget.caption:set_position(0, widget.state == "pressed" and sy or 0)
    local control = widget.control
    control.x, control.y, control.width, control.height = x, y, width, height
end

function M.expand(control, geometry)
    local width, height = math.max(control.width, 30*geometry.scale_x), math.max(control.height, 30*geometry.scale_y)
    local x, y = control.x - (width-control.width)/2, control.y - (height-control.height)/2
    control.x, control.y, control.width, control.height = x, y, width, height
end

return M
