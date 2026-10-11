local render = require("engine.render/v1")
local scenes = require("engine.scene/v1")
local dev = require("engine.dev/v1")
local display = require("engine.display/v1")
local controls = require("d2legacy.ui.controls")
local widgets = require("d2legacy.ui.touch_widgets")
local input = require("engine.input/v1")
local M = {}

function M.create(parent, palette)
    if not dev.option("touch_controls") then return nil end
    local state = { root = render.create("hud", parent), controls = controls.new(), buttons = {} }
    state.root:set_z(1500000)
    for _, entry in ipairs({{"inventory", "Inventory", "right"}, {"character", "Character", "left"}, {"pause", "Pause", "full"}}) do
        local scene, label, slot = entry[1], entry[2], entry[3]
        state.buttons[#state.buttons+1] = widgets.button(state.root, state.controls, scene, label,
            function() state.opened=true; scenes.toggle_overlay(scene, slot) end, palette)
    end
    return state
end

function M.update(state, allowed)
    if not state then return false end
    state.root:set_visible(allowed)
    if not allowed then state.controls.pointer_capture,state.contact_id,state.captured=nil,nil,nil; return false end
    local geometry = widgets.geometry()
    local width = display.size()
    local sx, sy = geometry.scale_x, geometry.scale_y
    local x, y = width - geometry.right - (3*88 + 2*4 + 8)*sx, geometry.top + 8*sy
    for index, widget in ipairs(state.buttons) do
        widgets.place(widget, x + (index-1)*92*sx, y, 88*sx, 30*sy, geometry)
    end
    local contacts,current = input.contacts(),{}
    for _, point in ipairs(contacts) do current[point.id]=point end
    if #contacts>0 or state.contact_id then
        -- A native contact owns this activation even if a mouse edge preceded it.
        state.controls.pointer_capture=nil
        state.previous=state.previous or {}
        for _, point in ipairs(contacts) do
            if not state.previous[point.id] and not state.contact_id then
                for _, widget in ipairs(state.buttons) do
                    local control=widget.control
                    if point.x>=control.x and point.x<control.x+control.width and point.y>=control.y and point.y<control.y+control.height then
                        state.contact_id,state.captured=point.id,control
                        control.on_state(control,"pressed")
                        break
                    end
                end
            end
        end
        local consumed=state.contact_id~=nil
        if state.contact_id then
            local point=current[state.contact_id]
            if point then state.last_x,state.last_y=point.x,point.y
            else
                local control=state.captured
                control.on_state(control,"normal")
                if state.last_x>=control.x and state.last_x<control.x+control.width and state.last_y>=control.y and state.last_y<control.y+control.height then
                    state.controls:activate(control)
                end
                state.contact_id,state.captured=nil,nil
            end
        end
        state.previous=current
        return consumed
    end
    state.previous=current
    state.controls:update()
    return state.controls.pointer_consumed
end

function M.destroy(state)
    if state then state.root:destroy() end
end

return M
