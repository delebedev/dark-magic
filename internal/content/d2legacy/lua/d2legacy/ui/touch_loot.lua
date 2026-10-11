local dev = require("engine.dev/v1")
local ecs = require("engine.ecs/v1")
local render = require("engine.render/v1")
local display = require("engine.display/v1")
local controls = require("d2legacy.ui.controls")
local widgets = require("d2legacy.ui.touch_widgets")
local inventory = require("d2legacy.ui.touch_inventory")
local bases = require("d2legacy.loot.items")
local M = {}

function M.close(state)
    if not state then return end
    if state.open then state.cancel() end
    state.open, state.taking = false, nil
    state.panel.touch.pending = nil
    state.panel.touch.root:set_visible(false)
end

function M.select(state, id)
    if not state then return end
    local item = state.ground[id]
    if not item then return end
    state.open, state.taking = true, nil
    inventory.select(state.panel, nil)
    state.panel.touch.ground = item
end

function M.create(parent, palette, items, take, cancel)
    if not dev.option("touch_controls") then return end
    local state = { root=render.create("hud", parent), labels={}, ground={}, bases={},
        items=items, cancel=cancel, open=false }
    state.root:set_z(1400000)
    local panel = { root=parent, controls=controls.new(), equipment_slots={}, item_palette=palette,
        items=items, item_snapshot=items.snapshot() }
    state.panel = panel
    inventory.create(panel, palette, {
        close=function() M.close(state) end,
        inventory=function(id) M.close(state); inventory.open_inventory(id) end,
        take=function(item)
            if state.taking then return end
            local baseline = {}
            for _, owned in ipairs(panel.item_snapshot.items) do
                if owned.container ~= "world" then baseline[owned.id] = true end
            end
            state.taking = {id=item.id, baseline=baseline, elapsed=0}
            panel.touch.feedback = "[gold]Approaching item...[/]"
            take(item)
        end,
    })
    panel.touch.root:set_visible(false)
    return state
end

local function acquired(state)
    local pending = state.taking
    if not pending then return end
    for _, item in ipairs(state.panel.item_snapshot.items) do
        local suffix = ":" .. item.id
        if not pending.baseline[item.id] and item.container ~= "world" and item.container ~= "corpse"
            and pending.id:sub(-#suffix) == suffix then return item end
    end
end

function M.update(state, world, level_id, camera_x, camera_y, target_x, target_y, allowed, elapsed, approaching)
    if not state then return false end
    if not allowed then
        M.close(state)
        state.root:set_visible(false)
        return false
    end
    state.root:set_visible(not state.open)
    local geometry = widgets.geometry()
    local width, height = display.size()
    local camera_px, camera_py = world:subtile_to_pixel(camera_x, camera_y)
    local seen = {}
    state.ground = {}
    for _, entity in ipairs(ecs.query({all={"d2legacy.world.selectable", "d2legacy.world.position",
        "d2legacy.world.location", "d2legacy.item.presentation"}, none={"d2legacy.world.inactive"}})) do
        local selectable = ecs.get(entity, "d2legacy.world.selectable")
        local location = ecs.get(entity, "d2legacy.world.location")
        if selectable:get("kind") == "item" and location:get("level_id") == level_id then
            local id = selectable:get("id")
            local code = selectable:get("label")
            if state.bases[code] == nil then state.bases[code] = bases.base(code) or false end
            local base = state.bases[code]
            local position = ecs.get(entity, "d2legacy.world.position")
            local art = ecs.get(entity, "d2legacy.item.presentation")
            local x, y = position:get("x"), position:get("y")
            local px, py = world:subtile_to_pixel(x, y)
            px, py = px-camera_px+target_x, py-camera_py+target_y
            local inventory_art = art:get("inventory_dc6")
            local item = {id=id, label=code, code=code, body_slots=base and base.body_slots or nil,
                container="world", x=x, y=y, radius=selectable:get("radius"),
                inventory_dc6=inventory_art ~= "" and inventory_art or base and base.inventory_dc6 or "",
                inspection=state.items.inspect(id)}
            state.ground[id] = item
            if px > geometry.left and px < width-geometry.right and py > geometry.top+55*geometry.scale_y
                and py < height-geometry.bottom-110*geometry.scale_y then
                seen[id] = true
                local label = state.labels[id]
                if not label then
                    label = widgets.button(state.root, state.panel.controls, "loot:"..id, inventory.name(item),
                        function() M.select(state, id) end, state.panel.item_palette)
                    state.labels[id] = label
                end
                widgets.place(label, px-55*geometry.scale_x, py+8*geometry.scale_y,
                    110*geometry.scale_x, 30*geometry.scale_y, geometry)
                label.root:set_visible(not state.open)
                state.panel.controls:set_visible(label.control.id, not state.open)
            end
        end
    end
    for id, label in pairs(state.labels) do
        if not state.ground[id] then
            local manager, control = state.panel.controls, label.control
            manager.by_id[control.id] = nil
            for index, registered in ipairs(manager.controls) do
                if registered == control then table.remove(manager.controls,index); break end
            end
            if manager.focus == control then manager.focus = nil end
            if manager.pointer_capture == control then manager.pointer_capture = nil end
            if manager.pressed == control then manager.pressed = nil end
            label.root:destroy()
            state.labels[id] = nil
        elseif not seen[id] then
            label.root:set_visible(false)
            state.panel.controls:set_visible(label.control.id, false)
        end
    end
    state.panel.item_snapshot = state.items.snapshot()
    state.panel.controls.offset_x = 0
    if state.open then
        state.panel.controls.offset_x = width-800-geometry.right
        local owned = acquired(state)
        if owned then
            inventory.select(state.panel, owned)
            state.panel.touch.feedback = "[green]Taken. In your backpack.[/]"
            state.taking = nil
        elseif state.taking then
            if not approaching then state.taking.elapsed = state.taking.elapsed + elapsed end
            if state.taking.elapsed > 1 then
                state.taking = nil
                state.panel.touch.feedback = "[red]Not taken yet. Check reach or backpack space.[/]"
            end
        end
        local ground = state.panel.touch.ground
        if ground then
            state.panel.touch.ground = state.ground[ground.id]
            if not state.panel.touch.ground then state.panel.touch.feedback = "[red]Item no longer here.[/]" end
        end
        inventory.refresh(state.panel)
        if state.panel.touch.ground then
            state.panel.controls:set_enabled("item_action_1", not state.taking)
        end
        -- Ground label rectangles use screen coordinates, while the tray uses panel coordinates.
        for _, label in pairs(state.labels) do state.panel.controls:set_visible(label.control.id, false) end
    else
        for _, widget in ipairs(state.panel.touch.buttons) do state.panel.controls:set_visible(widget.control.id, false) end
        state.panel.controls:set_visible("touch_close", false)
    end
    state.panel.touch.root:set_visible(state.open)
    if state.open then state.panel.controls:set_visible("touch_close", true) end
    local was_open = state.open
    state.panel.controls:update()
    return was_open or state.open or state.panel.controls.pointer_consumed
end

function M.destroy(state)
    if state then inventory.destroy(state.panel.touch); state.root:destroy() end
end
return M
