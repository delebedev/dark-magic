-- Death presentation submits owner commands and waits for canonical recovery.
local render = require("engine.render/v1")
local input = require("engine.input/v1")
local scenes = require("engine.scene/v1")
local locale = require("engine.locale/v1")
local text = require("d2legacy.ui.text")
local data = require("engine.data/v1")
local ecs = require("engine.ecs/v1")
local network_ok, network = pcall(require, "engine.network/v1")
local manifest = assert(data.load_manifest("manifests/presentation.v1.json", "d2legacy.presentation/v1"))
local screen = assert(manifest.screens.death)

local function owner_death()
    local ok, entities = pcall(ecs.query, { all = { "d2legacy.world.player_control", "d2legacy.player.death" } })
    if not ok then return end
    local owner = network_ok and network.status().player_id or "local-player"
    owner = owner or "local-player"
    for _, entity in ipairs(entities) do
        if ecs.get(entity, "d2legacy.world.player_control"):get("player") == owner then
            return ecs.get(entity, "d2legacy.player.death")
        end
    end
end

return {
    blocks_update_below = false,
    enter = function(self)
        self.root = render.create("hud")
        local death = owner_death()
        self.bound = death ~= nil
        if not render.assets_available() then return end
        text.create(self.root, "death_primary", assert(locale.text("d2legacy.death.died")), screen.x, screen.died_y, screen.width)
        if death and death:get("hardcore") then
            text.create(self.root, "death_secondary", assert(locale.text("d2legacy.death.hardcore")), screen.x, screen.hardcore_y, screen.width)
        elseif death and death:get("stage") == "capacity_exhausted" then
            text.create(self.root, "death_secondary", "Corpse storage is full. Save and exit.", screen.x, screen.continue_y, screen.width)
        else
            text.create(self.root, "death_primary", assert(locale.text("d2legacy.death.continue")), screen.x, screen.continue_y, screen.width)
            text.create(self.root, "death_secondary", "Tap to continue", screen.x, screen.hardcore_y, screen.width)
        end
    end,
    update = function(self)
        local death = owner_death()
        if self.bound and not death then scenes.pop(); return end
        if not (input.pressed("cancel") or input.pressed("confirm") or input.pressed("pointer_primary")) then return end
        if not self.bound then scenes.pop(); return end
        if death:get("hardcore") or death:get("stage") == "capacity_exhausted" then
            scenes.push("pause")
        else
            require("d2legacy.player_intents").continue(death:get("tick"))
        end
    end,
}
