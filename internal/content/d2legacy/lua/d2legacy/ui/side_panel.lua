local display = require("engine.display/v1")
local M = {}

-- Translate authored right-side art and hit regions together on wider viewports.
function M.align_right(state, authored_width)
    local offset = display.size() - authored_width
    state.root:set_position(offset, 0)
    state.controls.offset_x = offset
end

return M
