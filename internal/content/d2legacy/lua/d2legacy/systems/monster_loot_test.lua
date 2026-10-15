local test = require("d2legacy.tests/v1")
local fixtures = require("d2legacy.tests.support.fixtures")

local function expect_drop()
    local ecs = require("engine.ecs/v1")
    local entities = ecs.query({ all = { "d2legacy.item.identity" } })
    test.expect(#entities):equals(1)
    local entity = entities[1]
    local item = ecs.get(entity, "d2legacy.item.identity")
    test.expect(item:get("code")):equals("ssd")
    test.expect(ecs.get(entity, "d2legacy.item.placement"):get("container")):equals("world")
    test.expect(ecs.get(entity, "d2legacy.world.location"):get("level_id")):equals(1)
    test.expect(ecs.get(entity, "d2legacy.world.position"):get("x")):equals(12)
    test.expect(ecs.get(entity, "d2legacy.item.melee"):get("physical_min")):equals(512)
    test.expect(ecs.get(entity, "d2legacy.item.presentation"):get("world_dc6")):equals("data/global/items/flpssd.dc6")
    local generation = ecs.get(entity, "d2legacy.item.generation")
    test.expect(generation:get("level")):equals(1)
    local death = ecs.query({ all = { "d2legacy.monster.death" } })[1]
    test.expect(generation:get("facts")):equals(ecs.get(death, "d2legacy.monster.death"):get("drops"))
end

return test.suite({
    profile = "authority",
    tier = "fast",
    covers = { "internal/game/item" },
    initial_data = {
        ["d2legacy.items"] = {
            owner = "alice",
            inventory_width = 10,
            inventory_height = 4,
            items = test.array(),
        },
    },
    records = {
        ["data/global/excel/treasureclassex.txt"] = {
            {
                ["Treasure Class"] = "sword",
                Picks = "-1",
                Item1 = "ssd",
                Prob1 = "1",
            },
        },
        ["data/global/excel/weapons.txt"] = {
            {
                code = "ssd",
                type = "swor",
                invwidth = "1",
                invheight = "3",
                mindam = "2",
                maxdam = "7",
                rangeadder = "0",
                invfile = "invssd",
                flippyfile = "flpssd",
                wclass = "1hs",
                level = "1",
                levelreq = "1",
            },
        },
        ["data/global/excel/itemratio.txt"] = {
            {
                Version = "1",
                Uber = "0",
                ["Class Specific"] = "0",
                Unique = "9999",
                Set = "9999",
                Rare = "9999",
                Magic = "9999",
                HiQuality = "9999",
                Normal = "1",
            },
        },
    },
    cases = {
        test.case("death_materializes_one_durable_drop_without_reroll", {
            test.submit_system({
                tick = 1,
                sequence = 1,
                kind = "system.player.enter",
                payload = fixtures.player_entry(),
            }),
            test.submit_system({
                tick = 1,
                sequence = 2,
                kind = "system.monster.spawn",
                payload = fixtures.monster_spawn({ x = 12, y = 12 }),
            }),
            test.step(1),
            test.run(function()
                local ecs = require("engine.ecs/v1")
                local monster = ecs.query({ all = { "d2legacy.monster.identity" } })[1]
                ecs.get(monster, "d2legacy.monster.identity"):set("treasure_class", "sword")
                ecs.get(monster, "d2legacy.monster.stats"):set("health", 0)
            end),
            test.step(1),
            test.run(expect_drop),
            test.step(3),
            test.run(expect_drop),
            test.expect_checkpoint_parity(2),
            test.restore_checkpoint(),
            test.run(expect_drop),
        }),
    },
})
