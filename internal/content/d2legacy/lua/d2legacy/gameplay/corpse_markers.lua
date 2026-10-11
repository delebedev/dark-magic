-- shortcut: Use a named corpse marker until dead player body art is supported.
local ecs = require("engine.ecs/v1")
local render = require("engine.render/v1")
local text = require("d2legacy.ui.text")
local M = {}

function M.new(parent, world, level_id)
    local width, height = world:canvas()
    local view = { entries = {} }
    function view:update()
        local seen = {}
        for _, entity in ipairs(ecs.query({ all = { "d2legacy.world.selectable", "d2legacy.world.position", "d2legacy.world.location" },
            none = { "d2legacy.world.inactive" } })) do
            local selectable = ecs.get(entity, "d2legacy.world.selectable")
            if selectable:get("kind") == "player_corpse" and ecs.get(entity, "d2legacy.world.location"):get("level_id") == level_id then
                local key = tostring(entity:id())
                seen[key] = true
                local node = self.entries[key]
                if not node then
                    node = render.create("world", parent)
                    text.set(node, "tooltip", selectable:get("label") .. "'s corpse", 160)
                    self.entries[key] = node
                end
                local position = ecs.get(entity, "d2legacy.world.position")
                local sx, sy = position:get("x"), position:get("y")
                local x, y = world:subtile_to_pixel(sx, sy)
                node:set_position(x - width / 2, y - height / 2)
                node:set_z(world:entity_depth(sx, sy))
            end
        end
        for key, node in pairs(self.entries) do
            if not seen[key] then node:destroy(); self.entries[key] = nil end
        end
    end
    function view:destroy()
        for _, node in pairs(self.entries) do node:destroy() end
        self.entries = {}
    end
    return view
end
return M
