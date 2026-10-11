local display = require("engine.display/v1")
local dev = require("engine.dev/v1")
local M = {}

-- Translate authored right-side art and hit regions together on wider viewports.
function M.align_right(state, authored_width)
    local offset = display.size() - authored_width
    if dev.option("touch_controls") and display.geometry then offset = offset - display.geometry().right end
    state.root:set_position(offset, 0)
    state.controls.offset_x = offset
end

return M
