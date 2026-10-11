local M = {}
local slots = { rarm="Right hand", larm="Left hand", head="Head", neck="Neck", tors="Body",
    rrin="Right ring", lrin="Left ring", belt="Belt", feet="Feet", glov="Gloves" }

local function number(raw)
    return string.format("%.2f", raw / 256):gsub("0+$", ""):gsub("%.$", "")
end

function M.facts(value)
    if not value or value.status == "missing_facts" then return "Details unavailable" end
    if not value.identified or value.status == "unidentified" then return "Unidentified" end
    local lines = {}
    if value.damage then
        lines[#lines+1] = "Damage " .. number(value.damage.min_raw) .. " - " .. number(value.damage.max_raw)
    end
    if value.defense ~= nil then lines[#lines+1] = "Defense " .. value.defense end
    if #lines == 0 then lines[1] = "Damage/defense unavailable" end
    if value.status == "partial" then lines[#lines+1] = "Other effects not shown" end
    return table.concat(lines, "\n")
end

function M.comparison(item, snapshot)
    if item.container == "world" and not item.body_slots then return "Equipment comparison after Take." end
    local body_slots = item.body_slots or ""
    local lines = {}
    for slot in string.gmatch(body_slots, "[^,]+") do
        for _, equipped in ipairs(snapshot.items) do
            if equipped.container == "equipment" and equipped.slot == slot and equipped.id ~= item.id
                and (slot ~= "rarm" and slot ~= "larm" or equipped.weapon_set == snapshot.active_weapon_set) then
                lines[#lines+1] = "[gold]" .. (slots[slot] or slot) .. " now[/]\n" .. M.facts(equipped.inspection)
            end
        end
    end
    return table.concat(lines, "\n")
end
return M
