local test = require("d2legacy.tests/v1")
local fixtures = require("d2legacy.tests.support.fixtures")

local function inventory(corpse_id)
    return {
        inventory_width = 10, inventory_height = 4, stash_width = 6, stash_height = 8,
        cube_width = 3, cube_height = 4, vendor_width = 10, vendor_height = 10,
        belt_capacity = 4, active_weapon_set = 0, carried_gold = 17, stashed_gold = 29,
        corpses = corpse_id and { { id = corpse_id } } or {},
        items = {
            { id = "sword", code = "ssd", container = corpse_id and "corpse" or "equipment",
                corpse_id = corpse_id, slot = "rarm", body_slots = "rarm,larm", weapon_set = 0,
                width = 1, height = 3, x = 0, y = 0, page = 0, belt_slot = 0,
                physical_min = 6, physical_max = 10, melee_range = 1, melee_weapon_class = "1hs" },
            { id = "cap", code = "cap", container = corpse_id and "corpse" or "equipment",
                corpse_id = corpse_id, slot = "head", body_slots = "head", weapon_set = 0,
                width = 2, height = 2, x = 0, y = 0, page = 0, belt_slot = 0, defense = 4 },
            { id = "potion", code = "hp1", container = "belt", belt_eligible = true,
                width = 1, height = 1, x = 0, y = 0, page = 0, weapon_set = 0, belt_slot = 0 },
        },
    }
end

local function enter(options)
    return test.submit_system({ tick = 1, sequence = 1, kind = "system.player.enter",
        payload = fixtures.player_entry(options) })
end

local function command(tick, sequence, kind, payload, player)
    return test.submit({ tick = tick, sequence = sequence, player = player or "alice", kind = kind, payload = payload })
end

local function alice()
    local ecs = require("engine.ecs/v1")
    for _, entity in ipairs(ecs.query({ all = { "d2legacy.player.identity" } })) do
        if ecs.get(entity, "d2legacy.player.identity"):get("player") == "alice" then return entity end
    end
end

local function clear_map()
    require("d2legacy.gameplay.collision").set(1, {
        line_clear = function() return true end,
        barrier_clear = function() return true end,
        blocked_position = function() return false end,
        integrate_velocity = function(_, x, y) return x, y end,
    })
end

local function check_gear(container)
    local ecs = require("engine.ecs/v1")
    for _, entity in ipairs(ecs.query({ all = { "d2legacy.item.identity" } })) do
        local item = ecs.get(entity, "d2legacy.item.identity")
        local placed = ecs.get(entity, "d2legacy.item.placement")
        if item:get("id") == "sword" or item:get("id") == "cap" then
            test.expect(placed:get("container")):equals(container)
            test.expect(ecs.get(entity, "d2legacy.item.corpse") ~= nil):equals(container == "corpse")
        end
        if item:get("id") == "potion" then test.expect(placed:get("container")):equals("belt") end
    end
end

local enemy = fixtures.monster_spawn({ x = 11, y = 12 })
enemy.definition.aggro_radius = 20
enemy.definition.attack_range = 2
enemy.definition.think_interval = 1
enemy.definition.attack_rating = 10000
enemy.definition.physical_min = 4096
enemy.definition.physical_max = 4096

return test.suite({
    profile = "authority",
    tier = "fast",
    covers = { "internal/game/player", "internal/game/item" },
    initial_data = { ["d2legacy.respawn"] = { act = 1, level_id = 1, x = 10, y = 12, width = 100, height = 80 } },
    cases = {
        test.case("ordinary_monster_combat_commits_one_corpse_and_disables_gear", {
            enter({ health = 3, max_health = 3, inventory = inventory() }),
            test.step(2),
            test.run(function()
                test.expect(require("engine.ecs/v1").get(alice(), "d2legacy.player.combat_stats"):get("defense")):equals(9)
            end),
            test.submit_system({ tick = 3, sequence = 2, kind = "system.monster.spawn", payload = enemy }),
            test.step(50),
            test.run(function()
                local ecs = require("engine.ecs/v1")
                local death = ecs.get(alice(), "d2legacy.player.death")
                test.assert(death and death:get("killer_id") == "monster:fallen", "ordinary monster attack did not kill player")
                test.expect(#ecs.query({ all = { "d2legacy.player.corpse" } })):equals(1)
                test.expect(#ecs.query({ all = { "d2legacy.player.death_event" } })):equals(1)
                check_gear("corpse")
                test.expect(ecs.get(alice(), "d2legacy.player.combat_stats"):get("defense")):equals(5)
                local _, layout = require("d2legacy.items.find").layout("alice")
                test.expect(layout:get("carried_gold")):equals(17)
                test.expect(layout:get("stashed_gold")):equals(29)
            end),
            test.expect_checkpoint_parity(2),
        }),
        test.case("saved_dead_character_continues_and_recovers_once_after_checkpoint", {
            enter({ health = 0, inventory = inventory("saved-body"), death = { hardcore = false } }),
            test.step(1), test.restore_checkpoint(), test.run(clear_map),
            command(2, 1, "player.continue", { death_tick = 0 }), test.step(1),
            test.run(function() test.assert(require("engine.ecs/v1").get(alice(), "d2legacy.player.death"), "stale Continue revived player") end),
            command(3, 2, "player.continue", { death_tick = 1 }),
            command(3, 3, "player.continue", { death_tick = 1 }), test.step(1),
            test.run(function()
                local ecs = require("engine.ecs/v1")
                test.assert(not ecs.get(alice(), "d2legacy.player.death"), "Continue left committed death")
                local vitals = ecs.get(alice(), "d2legacy.player.vitals")
                for _, field in ipairs({ "health", "mana", "mana_raw", "stamina", "stamina_raw" }) do
                    test.expect(vitals:get(field)):equals(vitals:get("max_" .. field))
                end
                check_gear("corpse")
            end),
            command(4, 4, "player.corpse.recover", { target_id = "player_corpse:saved-body" }),
            command(4, 5, "player.corpse.recover", { target_id = "player_corpse:saved-body" }), test.step(2),
            test.run(function()
                local ecs = require("engine.ecs/v1")
                check_gear("equipment")
                test.expect(#ecs.query({ all = { "d2legacy.player.corpse" } })):equals(0)
                test.expect(ecs.get(alice(), "d2legacy.player.combat_stats"):get("defense")):equals(9)
                test.expect(ecs.get(alice(), "d2legacy.player.progress"):get("experience")):equals(0)
            end),
            test.expect_checkpoint_parity(2),
        }),
        test.case("corpse_is_owner_and_reach_protected_and_slot_refusal_loses_nothing", {
            enter({ inventory = inventory("saved-body") }), test.step(1), test.run(clear_map),
            test.submit_system({ tick = 2, sequence = 2, kind = "system.player.enter",
                payload = fixtures.player_entry({ player = "bob", character_id = "bob", name = "Bob" }) }),
            test.step(1),
            command(3, 1, "player.corpse.recover", { target_id = "player_corpse:saved-body" }, "bob"), test.step(1),
            test.run(function()
                check_gear("corpse")
                require("engine.ecs/v1").get(alice(), "d2legacy.world.position"):set("x", 40)
            end),
            command(4, 1, "player.corpse.recover", { target_id = "player_corpse:saved-body" }), test.step(1),
            test.run(function()
                local ecs = require("engine.ecs/v1")
                check_gear("corpse")
                ecs.get(alice(), "d2legacy.world.position"):set("x", 10)
                local layout = require("d2legacy.items.find").layout("alice")
                require("d2legacy.items.entity").create(layout, { id = "replacement", code = "cap", container = "equipment",
                    slot = "head", body_slots = "head", width = 2, height = 2 })
            end),
            command(5, 2, "player.corpse.recover", { target_id = "player_corpse:saved-body" }), test.step(1),
            test.run(function()
                check_gear("corpse")
                local ecs = require("engine.ecs/v1")
                test.expect(#ecs.query({ all = { "d2legacy.player.corpse" } })):equals(1)
                local move = require("d2legacy.commands.item_movement")
                local forged = { player = "alice", authority = "player", payload = {
                    item_id = "sword", destination = { container = "held" } } }
                test.expect(pcall(move.validate_move, forged)):equals(false)
                move.apply_move(forged)
                check_gear("corpse")
                require("d2legacy.commands.item_vendor").apply_sell({ player = "alice", authority = "player",
                    payload = { item_id = "sword", vendor = "unopened", category = "weapons" } })
                check_gear("corpse")
                local target, reason = require("d2legacy.gameplay.golem_target").resolve(alice(), 10, 12,
                    "sword", { requires_item_target = true }, ecs.query({ all = { "d2legacy.item.identity" } }))
                test.assert(not target and reason == "item_not_on_ground", "skill accessed corpse gear")
            end),
            test.expect_checkpoint_parity(2),
        }),
        test.case("hardcore_saved_death_cannot_continue", {
            enter({ health = 0, hardcore = true, death = { hardcore = true } }), test.step(1),
            command(2, 1, "player.continue", { death_tick = 1 }), test.step(1),
            test.run(function()
                test.assert(require("engine.ecs/v1").get(alice(), "d2legacy.player.death"), "Hardcore Continue was accepted")
            end),
        }),
        test.case("capacity_exhausted_saved_death_preserves_equipped_gear", {
            enter({ health = 0, inventory = inventory(), death = { hardcore = false, capacity_exhausted = true } }),
            test.step(1),
            command(2, 1, "player.continue", { death_tick = 1 }), test.step(1),
            test.run(function()
                local ecs = require("engine.ecs/v1")
                test.expect(ecs.get(alice(), "d2legacy.player.death"):get("stage")):equals("capacity_exhausted")
                check_gear("equipment")
            end),
        }),
        test.case("portable_corpse_rebinds_to_new_member_and_uses_town_position", {
            enter({ player = "bob", name = "Bob", inventory = inventory("old-member-body") }),
            test.step(1), test.run(clear_map),
            test.run(function()
                local ecs = require("engine.ecs/v1")
                local root = ecs.query({ all = { "d2legacy.player.corpse" } })[1]
                local corpse = ecs.get(root, "d2legacy.player.corpse")
                test.expect(ecs.get(corpse:get("owner"), "d2legacy.player.identity"):get("player")):equals("bob")
                test.expect(corpse:get("id")):equals("old-member-body")
                test.expect(ecs.get(root, "d2legacy.world.position"):get("x")):equals(9)
                test.expect(ecs.get(root, "d2legacy.world.position"):get("y")):equals(11)
            end),
            command(2, 1, "player.corpse.recover", { target_id = "player_corpse:old-member-body" }, "bob"),
            test.step(2), test.run(function() check_gear("equipment") end),
            test.expect_checkpoint_parity(2),
        }),
        test.case("live_hardcore_profile_death_refuses_recovery_with_softcore_host_defaults", {
            enter({ health = 3, max_health = 3, hardcore = true, inventory = inventory() }), test.step(2),
            test.submit_system({ tick = 3, sequence = 2, kind = "system.monster.spawn", payload = enemy }),
            test.step(50),
            test.run(function()
                local ecs = require("engine.ecs/v1")
                local player = alice()
                local death = ecs.get(player, "d2legacy.player.death")
                test.assert(death and death:get("hardcore"), "live Hardcore profile was treated as softcore")
                require("d2legacy.gameplay.player_corpse").continue(player, 54, death:get("tick"))
                test.assert(ecs.get(player, "d2legacy.player.death"), "Hardcore player revived")
                test.expect(#ecs.query({ all = { "d2legacy.player.corpse" } })):equals(0)
                check_gear("equipment")
            end),
        }),
        test.case("sixteen_corpse_capacity_refuses_new_gear_transfer_without_overwrite", {
            enter({ health = 3, max_health = 3, inventory = (function()
                local data = inventory()
                for index = 1, 16 do data.corpses[index] = { id = "old-body-" .. index } end
                return data
            end)() }), test.step(2),
            test.submit_system({ tick = 3, sequence = 2, kind = "system.monster.spawn", payload = enemy }),
            test.step(50),
            test.run(function()
                local ecs = require("engine.ecs/v1")
                local death = ecs.get(alice(), "d2legacy.player.death")
                test.assert(death and death:get("stage") == "capacity_exhausted", "capacity did not refuse death gear transfer")
                test.expect(#ecs.query({ all = { "d2legacy.player.corpse" } })):equals(16)
                check_gear("equipment")
                require("d2legacy.gameplay.player_corpse").continue(alice(), 54, death:get("tick"))
                test.assert(ecs.get(alice(), "d2legacy.player.death"), "capacity refusal allowed Continue")
            end),
            test.expect_checkpoint_parity(2),
        }),
    },
})
