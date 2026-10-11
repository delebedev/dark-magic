local render = require("engine.render/v1")
local records = require("engine.records/v1")
local locale = require("engine.locale/v1")
local text = require("d2legacy.ui.text")
local widgets = require("d2legacy.ui.touch_widgets")
local M = {}
local names
local next_selection
local description = require("d2legacy.ui.item_description")
local slots = {rarm="right hand", larm="left hand", head="head", neck="neck", tors="body",
    rrin="right ring", lrin="left ring", belt="belt", feet="feet", glov="gloves"}
local reasons = {
    ["item cannot use body slot"] = "Cannot equip in that slot.",
    ["item slot is occupied"] = "That slot is occupied.",
    ["item does not fit grid"] = "Item does not fit there.",
    ["item footprint is occupied"] = "That space is occupied.",
}

function M.name(item)
    if not names then
        names = {}
        for _, path in ipairs({"Weapons", "Armor", "Misc"}) do
            for _, row in ipairs(assert(records.load("data/global/excel/" .. path .. ".txt"))) do
                if row.code and row.code ~= "" then names[row.code] = row.namestr or row.name end
            end
        end
    end
    local key = names[item.code] or item.label
    return key and (locale.text(key) or key) or item.code or "Item"
end

local function rect(root, width, height, x, y, color)
    local node = render.create("modal", root)
    node:fill_rect(1, 1, color[1], color[2], color[3], color[4] or 255)
    node:set_scale(width, height)
    node:set_position(x, y)
    return node
end

function M.selected(self)
    for _, item in ipairs(self.item_snapshot.items) do
        if item.id == self.touch.selected_id then return item end
    end
    return self.touch.ground
end

function M.select(self, item)
    if self.touch.pending then return end
    self.touch.ground = nil
    self.touch.selected_id = item and item.id
    self.touch.moving, self.touch.feedback = false, nil
end

function M.request(self, destination)
    local state, item = self.touch, M.selected(self)
    if not item or state.pending or state.ground then return end
    state.pending = {token = self.items.move(item.id, destination, item.container == "held"),
        item_id = item.id, destination = destination}
    state.feedback = "[gold]Waiting...[/]"
end

function M.open_inventory(id)
    next_selection = id
    require("engine.scene/v1").toggle_overlay("inventory", "right")
end

function M.create(self, palette, options)
    local root = render.create("modal")
    root:set_z(1500000)
    local state = {root = root, buttons = {}, borders = {}, options = options or {}}
    if not options then state.selected_id, next_selection = next_selection, nil end
    self.touch = state
    state.background = rect(root, 1, 1, 0, 0, {9,8,6,240})
    state.trim = rect(root, 1, 1, 0, 0, {120,93,53,255})
    state.title = render.create("modal", root)
    state.details = render.create("modal", root)
    state.comparison = render.create("modal", root)
    state.message = render.create("modal", root)
    state.icon = render.create("modal", root)
    for index = 1, 3 do
        state.buttons[index] = widgets.button(root, self.controls, "item_action_" .. index, "Equip", function()
            local item = M.selected(self)
            if not item or state.pending then return end
            if state.ground then
                state.options.take(item)
            elseif index == 3 and state.options.inventory then
                state.options.inventory(item.id)
            elseif index <= 2 then
                local slot = state.equip_slots[index]
                M.request(self, {container="equipment", slot=slot,
                    weapon_set=(slot=="rarm" or slot=="larm") and self.item_snapshot.active_weapon_set or 0})
            else
                state.moving = not state.moving
                state.feedback = state.moving and "[gold]Tap a grid cell or equipment slot.[/]" or nil
            end
        end, palette, "modal")
    end
    for index=1,4 do state.borders[index] = rect(self.root,1,1,0,0,{225,185,100,255}) end
    state.close = widgets.button(root, self.controls, "touch_close", "Close", function()
        if state.options.close then state.options.close()
        else require("engine.scene/v1").toggle_overlay("inventory", "right") end
    end, palette, "modal")
    return state
end

function M.item_bounds(self, item)
    if item.container == "inventory" and self.grid_left then
        return self.grid_left+item.x*self.cell_width, self.grid_top+item.y*self.cell_height,
            item.width*self.cell_width, item.height*self.cell_height
    elseif item.container == "equipment" then
        local slot = self.equipment_slots[item.slot]
        if slot and (item.slot ~= "rarm" and item.slot ~= "larm" or item.weapon_set == self.item_snapshot.active_weapon_set) then
            return slot.x, slot.y, slot.width, slot.height
        end
    end
end

-- Exact footprints win. Expanded empty margins choose the nearest item edge.
function M.item_at(self, x, y)
    local geometry = widgets.geometry()
    local best, score
    for _, item in ipairs(self.item_snapshot.items) do
        if item.container == "inventory" then
            local left, top, width, height = M.item_bounds(self, item)
            local dx, dy = math.max(left-x, 0, x-left-width), math.max(top-y, 0, y-top-height)
            if dx==0 and dy==0 then return item end
            local px, py = math.max(0,(30*geometry.scale_x-width)/2), math.max(0,(30*geometry.scale_y-height)/2)
            local distance = dx*dx+dy*dy
            if dx<=px and dy<=py and (not score or distance<score) then best,score=item,distance end
        end
    end
    return best
end

function M.refresh(self)
    local state, item = self.touch, M.selected(self)
    local geometry = widgets.geometry()
    local sx, sy = geometry.scale_x, geometry.scale_y
    for id, slot in pairs(self.equipment_slots) do
        for _, control in ipairs(self.controls.controls) do
            if control.id:sub(1,10)=="equipment_" and control.body_loc==id then
                control.x,control.y,control.width,control.height=slot.x,slot.y,slot.width,slot.height
                widgets.expand(control,geometry)
            end
        end
    end
    local panel_left = self.controls.offset_x + 400
    local width = math.min(250*sx, panel_left - geometry.left - 24*sx)
    local x, y = panel_left - width - 12*sx, geometry.top+16*sy
    state.root:set_position(x,y)
    state.background:set_scale(width,326*sy)
    state.background:set_position(width/2,163*sy)
    state.trim:set_scale(width,sy)
    state.trim:set_position(width/2,0)
    if state.pending then
        local result = self.item_snapshot.move_result
        if result and result.token == state.pending.token and result.item_id == state.pending.item_id then
            local destination = state.pending.destination
            state.feedback = result.reason ~= "" and "[red]" .. (reasons[result.reason] or result.reason) .. "[/]"
                or "[green]" .. (destination.container == "equipment" and "Equipped " .. (slots[destination.slot] or destination.slot)
                    or "Moved to backpack") .. ".[/]"
            if result.reason == "" then state.moving = false end
            state.pending = nil
        end
    end
    state.equip_slots = {}
    if item and not state.ground then
        for slot in string.gmatch(item.body_slots or "", "[^,]+") do
            if #state.equip_slots < 2 then state.equip_slots[#state.equip_slots+1] = slot end
        end
    end
    local title = item and "[gold]" .. M.name(item) .. "[/]" or "[gold]Inventory[/]"
    local location = item and (state.ground and "On the ground" or item.container=="equipment"
        and "Equipped: " .. (slots[item.slot] or item.slot) or "Backpack")
    local details = item and location .. "\n" .. description.facts(item.inspection)
        or "Tap an item to inspect.\nChoose Equip or Move."
    local comparison = item and description.comparison(item, self.item_snapshot) or ""
    local message = state.feedback or (state.ground and "[gold]Take to put in your backpack.[/]"
        or "[gold]Select before moving.[/]")
    for _, entry in ipairs({{state.title,title,40,"title_text"},{state.details,details,125,"details_text"},
        {state.comparison,comparison,180,"comparison_text"},{state.message,message,226,"message_text"}}) do
        if state[entry[4]] ~= entry[2] then
            text.set(entry[1],"font_lab_color",entry[2],(width-24*sx)/sx,"center")
            state[entry[4]] = entry[2]
        end
        entry[1]:set_scale(sx,sy)
        entry[1]:set_position(width/2,entry[3]*sy)
    end
    state.icon:set_visible(item ~= nil and item.inventory_dc6 ~= "")
    if item and item.inventory_dc6 ~= "" and state.icon_id ~= item.id then
        state.icon:set_dc6(item.inventory_dc6, self.item_palette, 0, 0)
        state.icon_id = item.id
    end
    state.icon:set_position(width/2,88*sy)
    state.icon:set_scale(sx*0.8,sy*0.8)
    for index, widget in ipairs(state.buttons) do
        local slot = state.equip_slots[index]
        local visible = state.ground and index == 1 or not state.ground and (index==3 or slot ~= nil)
        self.controls:set_visible(widget.control.id, visible)
        widget.root:set_visible(visible)
        self.controls:set_enabled(widget.control.id, item ~= nil and not state.pending
            and (index==3 or not (item.container=="equipment" and item.slot==slot)))
        widgets.label(widget,state.ground and "Take" or index==3 and (state.moving and "Cancel move" or "Move")
            or slot=="rarm" and "Equip right" or slot=="larm" and "Equip left" or "Equip")
        local column = index==2 and 1 or 0
        local row = index==3 and 1 or 0
        widgets.place(widget,column*width/2, (256+row*34)*sy, width/2,30*sy,geometry)
        widget.control.x = x+widget.control.x-self.controls.offset_x
        widget.control.y = y+widget.control.y
    end
    widgets.place(state.close,width-72*sx,0,72*sx,30*sy,geometry)
    state.close.control.x = x+state.close.control.x-self.controls.offset_x
    state.close.control.y = y+state.close.control.y
    local left, top, w, h
    if item then left,top,w,h=M.item_bounds(self,item) end
    for _, border in ipairs(state.borders) do border:set_visible(left~=nil) end
    if left then
        local edges={{w+4,2,left+w/2,top-2},{w+4,2,left+w/2,top+h+2},{2,h,left-2,top+h/2},{2,h,left+w+2,top+h/2}}
        for index, edge in ipairs(edges) do
            state.borders[index]:set_scale(edge[1],edge[2])
            state.borders[index]:set_position(edge[3],edge[4])
        end
    end
end

function M.destroy(state)
    if state then state.root:destroy() end
end

return M
