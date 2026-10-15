local display = require("engine.display/v1")
local dc6 = require("d2legacy.ui.dc6")

local M = {}
local clip_groups = setmetatable({}, { __mode = "k" })

local function apply_clip(group, clip)
    clip.node:set_clip(
        group.x + clip.x * group.scale,
        group.y + clip.y * group.scale,
        clip.width * group.scale,
        clip.height * group.scale
    )
end

-- Existing clips use screen coordinates, so transformed lobby roots register authored clips here.
function M.clip(root, node, x, y, width, height)
    if not root then
        node:set_clip(x, y, width, height)
        return
    end
    local group = clip_groups[root] or { x = 0, y = 0, scale = 1 }
    clip_groups[root] = group
    local clip = { node = node, x = x, y = y, width = width, height = height }
    group[#group + 1] = clip
    apply_clip(group, clip)
end

-- Keep authored controls inside the safe area while backgrounds cover the surface.
function M.geometry(width, height, safe)
    safe = safe or {}
    local left, right = safe.left or 0, safe.right or 0
    local top, bottom = safe.top or 0, safe.bottom or 0
    local available_width = math.max(1, width - left - right)
    local available_height = math.max(1, height - top - bottom)
    local scale = math.min(1, available_width / 800, available_height / 600)
    return left + (available_width - 800 * scale) / 2, top + (available_height - 600 * scale) / 2, scale
end

function M.wrap(scene)
    local create, enter, update = scene.create, scene.enter, scene.update
    local function layout(self)
        if not self.root then
            return
        end
        local width, height = display.size()
        if width <= 0 or height <= 0 then
            return
        end
        local x, y, scale = M.geometry(width, height, display.geometry())
        local previous = self.__frontend_layout
        if
            previous
            and previous.x == x
            and previous.y == y
            and previous.scale == scale
            and previous.width == width
            and previous.height == height
        then
            return
        end
        self.__frontend_layout = { x = x, y = y, scale = scale, width = width, height = height }
        self.root:set_position(x, y)
        self.root:set_scale(scale, scale)
        local group = clip_groups[self.root] or {}
        clip_groups[self.root] = group
        group.x, group.y, group.scale = x, y, scale
        for _, clip in ipairs(group) do
            apply_clip(group, clip)
        end
        if self.controls then
            self.controls.offset_x, self.controls.offset_y = x, y
            self.controls.pointer_scale = scale
            self.controls.pointer_capture = nil
        end
        if self.cursor then
            self.cursor.canvas_x, self.cursor.canvas_y, self.cursor.canvas_scale = x, y, scale
        end
        dc6.resize_frontend_background(self.root, width, height, x, y, scale)
    end
    scene.create = function(self)
        if create then
            create(self)
        end
        layout(self)
    end
    scene.enter = function(self)
        if enter then
            enter(self)
        end
        self.__frontend_layout = nil
        layout(self)
    end
    scene.update = function(self, ...)
        layout(self)
        if update then
            return update(self, ...)
        end
    end
    return scene
end

return M
