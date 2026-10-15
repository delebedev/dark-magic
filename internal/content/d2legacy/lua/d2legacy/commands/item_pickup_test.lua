local test = require("d2legacy.tests/v1")
local fixtures = require("d2legacy.tests.support.fixtures")
local ground_item, player, barrier

local function prepare()
    local ecs = require("engine.ecs/v1")
    player = ecs.query({ all = { "d2legacy.player.identity" } })[1]
    local layout = ecs.create({
        ["d2legacy.items.layout"] = {
            owner = "bob",
            inventory_width = 2,
            inventory_height = 3,
            stash_width = 0,
            stash_height = 0,
            cube_width = 0,
            cube_height = 0,
            belt_capacity = 0,
            active_weapon_set = 0,
            vendor_width = 0,
            vendor_height = 0,
            carried_gold = 0,
            stashed_gold = 0,
        },
    })
    ground_item = require("d2legacy.items.entity").create(layout, {
        id = "sword",
        code = "ssd",
        width = 1,
        height = 3,
        container = "world",
        x = 12,
        y = 12,
        act = 1,
        level_id = 1,
    })
    barrier = { clear = true }
    require("d2legacy.gameplay.collision").set(1, {
        line_clear = function()
            return barrier.clear
        end,
        integrate_velocity = function(_, x, y)
            return x, y
        end,
    })
end

local function pickup()
    return test.submit({
        tick = 2,
        sequence = 1,
        player = "alice",
        kind = "item.pickup",
        payload = { target_id = "item:bob:sword" },
    })
end

local function start(run)
    return {
        test.submit_system({
            tick = 1,
            sequence = 1,
            kind = "system.player.enter",
            payload = fixtures.player_entry(),
        }),
        test.step(1),
        test.run(prepare),
        test.run(run),
    }
end

return test.suite({
    profile = "authority",
    tier = "fast",
    covers = { "internal/game/item" },
    initial_data = {
        ["d2legacy.items"] = {
            owner = "alice",
            inventory_width = 1,
            inventory_height = 3,
            items = test.array(),
        },
    },
    cases = {
        test.case("picks_up_through_command_and_transfers_ownership_once", {
            test.submit_system({
                tick = 1,
                sequence = 1,
                kind = "system.player.enter",
                payload = fixtures.player_entry(),
            }),
            test.step(1),
            test.run(prepare),
            pickup(),
            test.step(1),
            test.run(function()
                local ecs = require("engine.ecs/v1")
                local identity = ecs.get(ground_item, "d2legacy.item.identity")
                local layout = ecs.get(identity:get("owner"), "d2legacy.items.layout")
                test.expect(layout:get("owner")):equals("alice")
                local placed = ecs.get(ground_item, "d2legacy.item.placement")
                test.expect(placed:get("container")):equals("inventory")
                test.assert(
                    not ecs.get(ground_item, "d2legacy.world.selectable"),
                    "picked-up item is no longer selectable"
                )
                require("d2legacy.commands.item_pickup").apply({
                    player = "alice",
                    authority = "player",
                    payload = { target_id = "item:bob:sword" },
                })
                test.expect(#ecs.query({ all = { "d2legacy.item.identity" } })):equals(1)
            end),
        }),
        test.case(
            "refuses_stale_distant_other_level_blocked_and_full_inventory",
            start(function()
                local ecs = require("engine.ecs/v1")
                local command = { player = "alice", authority = "player", payload = { target_id = "item:bob:sword" } }
                local policy = require("d2legacy.commands.item_pickup")
                local function refused()
                    policy.apply(command)
                    local placed = ecs.get(ground_item, "d2legacy.item.placement")
                    test.expect(placed:get("container")):equals("world")
                end
                local position = ecs.get(ground_item, "d2legacy.world.position")
                position:set("x", 30)
                refused()
                position:set("x", 12)
                local location = ecs.get(ground_item, "d2legacy.world.location")
                location:set("level_id", 2)
                refused()
                location:set("level_id", 1)
                barrier.clear = false
                refused()
                barrier.clear = true
                ecs.set(ground_item, "d2legacy.world.inactive", {})
                refused()
                ecs.remove(ground_item, "d2legacy.world.inactive")
                local layout = require("d2legacy.items.find").layout("alice")
                require("d2legacy.items.entity").create(
                    layout,
                    { id = "occupied", code = "ssd", width = 1, height = 3, container = "inventory", x = 0, y = 0 }
                )
                refused()
                local identity = ecs.get(ground_item, "d2legacy.item.identity")
                local original = ecs.get(identity:get("owner"), "d2legacy.items.layout")
                test.expect(original:get("owner")):equals("bob")
            end)
        ),
        test.case(
            "legacy_move_cannot_bypass_ground_reach",
            start(function()
                local ecs = require("engine.ecs/v1")
                local layout = require("d2legacy.items.find").layout("alice")
                ecs.get(ground_item, "d2legacy.item.identity"):set("owner", layout)
                local movement = require("d2legacy.commands.item_movement")
                local command = {
                    player = "alice",
                    authority = "player",
                    payload = {
                        item_id = "sword",
                        destination = { container = "held" },
                    },
                }
                local placed = ecs.get(ground_item, "d2legacy.item.placement")
                local position = ecs.get(ground_item, "d2legacy.world.position")
                position:set("x", 30)
                movement.apply_move(command)
                test.expect(placed:get("container")):equals("world")
                position:set("x", 12)
                barrier.clear = false
                movement.apply_move(command)
                test.expect(placed:get("container")):equals("world")
                barrier.clear = true
                movement.apply_move(command)
                test.expect(placed:get("container")):equals("held")
                command.payload.destination = { container = "world", x = 30, y = 12 }
                movement.apply_move(command)
                test.expect(placed:get("container")):equals("held")
                command.payload.destination.x = 12
                movement.apply_move(command)
                test.expect(placed:get("container")):equals("world")
                test.expect(ecs.get(ground_item, "d2legacy.world.selectable"):get("label")):equals("ssd")
            end)
        ),
    },
})
