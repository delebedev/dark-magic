-- Quest-log presentation reads the authenticated player's durable progress.
--
-- This file demonstrates reading GAME CATALOG data without owning game state.
-- `d2legacy.quest_catalog/v1` tells presentation what quests exist and which localized
-- title keys they use. The panel arranges those facts into recovered sockets.
-- Lua authority owns quest completion and rewards.

local ecs = require("engine.ecs/v1")
local render = require("engine.render/v1")
local input = require("engine.input/v1")
local scenes = require("engine.scene/v1")
local data = require("engine.data/v1")
local locale = require("engine.locale/v1")
local controls = require("d2legacy.ui.controls")
local button = require("d2legacy.ui.button")
local text = require("d2legacy.ui.text")

local manifest = assert(data.load_manifest("manifests/presentation.v1.json", "d2legacy.presentation/v1"))
local screen = manifest.screens.quests
local offset_x, offset_y = screen.offset_x or 0, screen.offset_y or 0

local function dc6(root, sheet, palette, frame, x, y)
    local node = render.create("modal", root)
    local w, h = node:set_dc6(sheet, palette, 0, frame)
    node:set_position(x + w / 2, y + h / 2)
    return node
end

local function translated(key, fallback)
    -- Prefer localization. If a recovered row has no usable string key, retain a
    -- readable catalog name, and as a last resort show the key itself.
    return locale.text(key) or fallback or key
end

return {
    blocks_update_below = true,

    enter = function(self)
        self.root = render.create("modal")
        self.controls = controls.new()
        if not render.assets_available() then return end

        local panel, palette = screen.panel, manifest.palettes[screen.panel.palette]

        -- The quest background is four quadrants. Explicit placement makes the
        -- original frame arrangement visible in data/code instead of hiding it in native code.
        dc6(self.root, panel.sheet, palette, panel.frames[1], panel.x + offset_x, panel.y + offset_y)
        dc6(self.root, panel.sheet, palette, panel.frames[2], panel.x + offset_x + 256, panel.y + offset_y)
        dc6(self.root, panel.sheet, palette, panel.frames[3], panel.x + offset_x, panel.y + offset_y + 256)
        dc6(self.root, panel.sheet, palette, panel.frames[4], panel.x + offset_x + 256, panel.y + offset_y + 256)

        -- Five act tabs use every other frame in the authored sheet. The
        -- currently active/interactive quest behavior can grow on top of these same nodes later.
        for act = 0, 4 do
            dc6(self.root, screen.tabs.sheet, palette, act * 2, screen.tabs.x + offset_x + act * screen.tabs.step, screen.tabs.y + offset_y)
        end

        -- Require recovered catalog data only after the asset-backed path is
        -- entered; lightweight/headless presentation harnesses may omit it.
        local catalog = require("d2legacy.quest_catalog/v1")
        local quests = catalog.quests(0)

        for index, socket in ipairs(screen.sockets.positions) do
            -- Draw the empty quest socket first.
            dc6(self.root, screen.sockets.sheet, palette, 0, socket.x + offset_x, socket.y + offset_y)

            -- Array index pairs the recovered socket with this act's catalog quest.
            local quest = quests[index]
            if quest then
                text.create(self.root, "formal_small", translated(quest.title_string_key, quest.name), socket.x + offset_x + 39, socket.y + offset_y + 57, 90)
            end
        end

        local status="Den of Evil: explore every chamber and defeat its monsters."
        local owner="local-player"
        local available,network=pcall(require,"engine.network/v1")
        if available then
            local id=network.status().player_id
            if id and id~="" then owner=id end
        end
        for _,entity in ipairs(ecs.query({all={"d2legacy.player.identity"}})) do
            if ecs.get(entity,"d2legacy.player.identity"):get("player")==owner then
                local progress=ecs.get(entity,"d2legacy.quest.progress")
                if progress and progress:get("quest_id")==1 then
                    if progress:get("rewarded") then status="Den of Evil: rewarded. Akara granted one skill point."
                    elseif progress:get("completed") then status="Den of Evil: cleared. Return to Akara for one skill point."
                    else status="Den of Evil: in progress. Explore every chamber and defeat its monsters." end
                end
            end
        end
        text.create(self.root, "formal_small", status, screen.unavailable.x + offset_x, screen.unavailable.y + offset_y, screen.unavailable.width)

        local close = screen.close
        local close_placement = {
            sheet=close.sheet, palette=close.palette, up_frame=close.up_frame, down_frame=close.down_frame,
            x=close.x + offset_x, y=close.y + offset_y, width=close.width, height=close.height, label=close.label,
        }
        button.create(self.root, self.controls, "close", close_placement, assert(locale.text(close.label)), {
            layer="modal", show_label=false, sound=manifest.sounds.button,
            tooltip=assert(locale.text(close.label)), on_activate=function() scenes.toggle_overlay("quests", "left") end,
        })
    end,

    update = function(self)
        self.controls:update()
        if input.pressed("quests") or input.pressed("cancel") then scenes.pop() end
    end,
}
