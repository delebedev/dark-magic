-- Presentation intent selection over copied contacts and world facts.
local M = {}
local modal_cancelled = false

function M.cancel()
    modal_cancelled = true
end

function M.layout(width, height)
    return {
        move = { x = 152, y = height - 194, radius = 88 },
        buttons = {
            { x = width - 152, y = height - 194, radius = 66 },
            { x = width - 264, y = height - 292, radius = 46 },
            { x = width - 146, y = height - 336, radius = 46 },
        },
    }
end

local function inside(point, pad)
    return (point.x - pad.x)^2 + (point.y - pad.y)^2 <= pad.radius^2
end

function M.sample(state, contacts, layout, allowed)
    if modal_cancelled then allowed,modal_cancelled=false,false end
    state.previous = state.previous or {}
    local current, output = {}, { consumed = false }
    for _, point in ipairs(contacts) do current[point.id] = point end
    if not allowed then
        output.stop = state.moving == true
        state.move_id, state.skill_id, state.button, state.moving = nil, nil, nil, false
        state.previous = current
        return output
    end
    for _, point in ipairs(contacts) do
        if not state.previous[point.id] then
            if not state.move_id and inside(point, layout.move) then
                state.move_id = point.id
            elseif not state.skill_id then
                for index, button in ipairs(layout.buttons) do
                    if inside(point, button) then
                        state.skill_id, state.button = point.id, index
                        output.skill_pressed = true
                        break
                    end
                end
            end
        end
    end
    local move = state.move_id and current[state.move_id]
    if state.move_id then output.consumed = true end
    if move then
        local dx, dy = move.x - layout.move.x, move.y - layout.move.y
        local length = math.sqrt(dx*dx + dy*dy)
        if length > 14 then
            output.move_x, output.move_y = dx/length, dy/length
            output.knob_x, output.knob_y = dx/math.max(1, length/58), dy/math.max(1, length/58)
        end
    else state.move_id = nil end
    local moving = output.move_x ~= nil
    output.stop = state.moving == true and not moving
    state.moving = moving
    local skill = state.skill_id and current[state.skill_id]
    if state.skill_id then output.consumed = true end
    if skill then
        local button = layout.buttons[state.button]
        local dx, dy = skill.x - button.x, skill.y - button.y
        local length = math.sqrt(dx*dx + dy*dy)
        output.button, output.skill_down = state.button, true
        output.cancelled = length > 180
        if length > 18 then output.aim_x, output.aim_y = dx/length, dy/length end
        state.last_aim_x, state.last_aim_y, state.cancelled = output.aim_x, output.aim_y, output.cancelled
    elseif state.skill_id then
        output.button, output.skill_released = state.button, true
        output.aim_x, output.aim_y, output.cancelled = state.last_aim_x, state.last_aim_y, state.cancelled
        state.skill_id, state.button = nil, nil
    end
    state.previous = current
    return output
end

-- Screen-space scoring preserves visual direction under the isometric camera.
function M.target(candidates, hero_x, hero_y, aim_x, aim_y, locked_id)
    local best, best_score
    for _, candidate in ipairs(candidates) do
        local dx, dy = candidate.screen_x - hero_x, candidate.screen_y - hero_y
        local distance = math.sqrt(dx*dx + dy*dy)
        local dot = aim_x and (dx*aim_x + dy*aim_y)/math.max(1, distance) or 1
        if not candidate.dead and distance <= 360 and (not aim_x or dot >= 0.72) then
            local score = distance + (1-dot)*280 - (candidate.id == locked_id and 65 or 0)
            if not best_score or score < best_score or (score == best_score and candidate.id < best.id) then
                best, best_score = candidate, score
            end
        end
    end
    return best
end

return M
