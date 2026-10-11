local dev = require("engine.dev/v1")
local input = require("engine.input/v1")
local render = require("engine.render/v1")
local text = require("d2legacy.ui.text")
local locale = require("engine.locale/v1")
local touch = require("d2legacy.gameplay.touch_input")
local M = {}

local function rect(root, width, height, x, y, color)
    local node = render.create("hud", root)
    node:fill_rect(1, 1, color[1], color[2], color[3], color[4] or 255)
    node:set_scale(width, height)
    node:set_position(x, y)
    return node
end

local function ring(root, radius, color)
    local node = render.create("hud", root)
    for index = 0, 23 do
        local angle = index*math.pi/12
        local edge = rect(node, radius*0.25, 2, math.cos(angle)*radius, math.sin(angle)*radius, color)
        edge:set_rotation(index*15 + 90)
    end
    return node
end

function M.create(parent, palette)
    if not dev.option("touch_controls") then return nil end
    local root = render.create("hud", parent)
    root:set_z(1450000)
    local state = { root = root, palette = palette, buttons = {}, gesture = {}, slots = {} }
    state.move = ring(root, 88, {180,145,87,190})
    state.knob = ring(root, 28, {230,195,120,235})
    state.move_label = render.create("hud", root)
    text.set(state.move_label, "font_lab_color", "[gold]MOVE[/]", 120, "center")
    for index, radius in ipairs({66,46,46}) do
        local button = { root = render.create("hud", root) }
        button.ring = ring(button.root, radius, {210,170,100,220})
        button.face = rect(button.root, radius*1.3, radius*1.3, 0, 0, {12,10,8,190})
        button.icon = render.create("hud", button.root)
        button.label = render.create("hud", button.root)
        button.label:set_position(0, radius + 17)
        state.buttons[index] = button
    end
    state.reticle = ring(root, 26, {255,215,90,255})
    state.target_label = render.create("hud", root)
    state.status = render.create("hud", root)
    state.dots = {}
    for index=1,8 do state.dots[index] = rect(root, 3, 3, 0, 0, {230,200,130,210}) end
    return state
end

function M.skills(state, snapshot)
    if not state then return end
    local external = state.assigned ~= nil and state.assigned ~= snapshot.right_skill
        and state.assignment ~= snapshot.right_skill
    state.assigned = snapshot.right_skill
    if state.assignment == state.assigned then state.assignment = nil end
    -- HUD selection changes the main pad; direct pad assignment keeps its loadout.
    if not external and #state.slots > 0 or #snapshot.learned_skills == 0 then return end
    if state.job then render.preload_release(state.job); state.job = nil end
    state.slots = {}
    local learned = {}
    for _, skill in ipairs(snapshot.learned_skills) do
        if skill.right_allowed ~= false then learned[skill.id or skill.skill_id] = skill end
    end
    local chosen = {}
    for _, id in ipairs(external and {snapshot.right_skill,47,45,48} or {47,45,48,snapshot.right_skill}) do
        if learned[id] and not chosen[id] and #state.slots < 3 then
            state.slots[#state.slots+1], chosen[id] = learned[id], true
        end
    end
    for _, skill in ipairs(snapshot.learned_skills) do
        local id = skill.id or skill.skill_id
        if learned[id] and not chosen[id] and #state.slots < 3 then
            state.slots[#state.slots+1], chosen[id] = skill, true
        end
    end
    local requests = {}
    for index, skill in ipairs(state.slots) do
        text.set(state.buttons[index].label, "font_lab_color", "[gold]" .. locale.text(skill.name_key) .. "[/]", 160, "center")
        requests[#requests+1] = {kind="dc6_frame", path=skill.sheet, palette=state.palette, direction=0, frame=skill.icon}
    end
    if #requests > 0 then state.job = render.preload(requests) end
end

function M.sample(state, width, height, allowed)
    if not state then return { consumed=false } end
    state.root:set_visible(allowed)
    state.layout = touch.layout(width, height)
    state.move:set_position(state.layout.move.x, state.layout.move.y)
    state.move_label:set_position(state.layout.move.x, state.layout.move.y+112)
    for index, button in ipairs(state.buttons) do
        local pad = state.layout.buttons[index]
        button.root:set_position(pad.x, pad.y)
        button.root:set_visible(allowed and state.slots[index] ~= nil)
    end
    if state.job and render.preload_status(state.job).done then
        assert(render.preload_status(state.job).failed == 0, "preloading touch skill icons failed")
        render.preload_release(state.job)
        state.job = nil
        for index, skill in ipairs(state.slots) do
            state.buttons[index].icon:set_dc6(skill.sheet, state.palette, 0, skill.icon)
            state.buttons[index].icon:set_scale(index == 1 and 1.6 or 1.2, index == 1 and 1.6 or 1.2)
        end
    end
    local contacts = input.contacts()
    -- Mouse and labelled tap probes exercise the same ownership/aiming logic.
    if #contacts == 0 and input.pointer_source() ~= "touch" and input.down("pointer_primary") then
        local x,y = input.cursor()
        contacts = {{id=-1,x=x,y=y}}
    end
    local output = touch.sample(state.gesture, contacts, state.layout, allowed)
    state.move:set_visible(allowed)
    state.knob:set_visible(allowed)
    state.move_label:set_visible(allowed)
    state.knob:set_position(state.layout.move.x+(output.knob_x or 0), state.layout.move.y+(output.knob_y or 0))
    for index, button in ipairs(state.buttons) do
        local scale = output.skill_down and output.button == index and not output.cancelled and 0.93 or 1
        button.root:set_scale(scale,scale)
    end
    output.skill = state.slots[output.button or 0]
    return output
end

function M.feedback(state, target, hero_x, hero_y, aim_x, aim_y, cancelled)
    if not state then return end
    state.reticle:set_visible(target ~= nil and not cancelled)
    state.target_label:set_visible(target ~= nil and not cancelled)
    if target then
        state.reticle:set_position(target.screen_x, target.screen_y-18)
        state.target_label:set_position(target.screen_x, target.screen_y-60)
        local value = "[gold]" .. (target.label or "TARGET") .. "[/]"
        if value ~= state.target_text then
            text.set(state.target_label, "font_lab_color", value, 240, "center")
            state.target_text = value
        end
    end
    for index, dot in ipairs(state.dots) do
        dot:set_visible(aim_x ~= nil and not cancelled)
        if aim_x then dot:set_position(hero_x+aim_x*index*22, hero_y+aim_y*index*22) end
    end
    local value = cancelled and "[red]CANCELLED - RELEASE[/]" or "[gold]HOLD TO CAST | DRAG TO AIM[/]"
    if value ~= state.status_text then
        text.set(state.status, "font_lab_color", value, 440, "center")
        state.status_text = value
    end
    state.status:set_position(state.layout.move.x + (state.layout.buttons[1].x-state.layout.move.x)/2, 462)
end

function M.destroy(state)
    if not state then return end
    if state.job then render.preload_release(state.job) end
    state.root:destroy()
end

return M
