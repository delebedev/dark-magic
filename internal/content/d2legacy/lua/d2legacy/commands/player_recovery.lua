local commands = require("engine.authority_command/v1")
local ecs = require("engine.ecs/v1")
local recovery = require("d2legacy.gameplay.player_corpse")
local M = {}

local function player(command)
    for _, entity in ipairs(ecs.query({ all = { "d2legacy.player.identity" } })) do
        if ecs.get(entity, "d2legacy.player.identity"):get("player") == command.player then return entity end
    end
end

function M.register()
    commands.register({
        kind = "player.continue", authorities = { "player" },
        validate = function(command)
            local tick = command.payload and command.payload.death_tick
            assert(type(tick) == "number" and tick >= 0 and tick == math.floor(tick), "death tick is required")
        end,
        apply = function(command)
            local entity = player(command)
            if entity then recovery.continue(entity, command.tick, command.payload.death_tick) end
        end,
    })
    commands.register({
        kind = "player.corpse.recover", authorities = { "player" },
        validate = function(command)
            local id = command.payload and command.payload.target_id
            assert(type(id) == "string" and id ~= "" and #id <= 128, "corpse target ID is required")
        end,
        apply = function(command)
            local entity = player(command)
            if entity then recovery.recover(entity, command.payload.target_id) end
        end,
    })
end

return M
