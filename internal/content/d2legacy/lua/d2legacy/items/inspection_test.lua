local test = require("d2legacy.tests/v1")

return test.suite({
    profile = "authority",
    tier = "fast",
    covers = { "internal/game/item" },
    initial_data = {
        ["d2legacy.items"] = {
            owner = "local-player",
            items = {
                {
                    id = "blade",
                    code = "ssd",
                    width = 1,
                    height = 3,
                    container = "inventory",
                    physical_min = 512,
                    physical_max = 1536,
                },
                {
                    id = "cap",
                    code = "cap",
                    width = 2,
                    height = 2,
                    container = "inventory",
                    defense = 6,
                    base_defense_max = 10,
                    stat_modifiers = {
                        { source_id = "enhanced", stat = "defense", operation = "local_percent", value = 50 },
                    },
                },
                {
                    id = "unknown",
                    code = "cap",
                    width = 2,
                    height = 2,
                    container = "inventory",
                    identified = false,
                    defense = 666,
                },
                {
                    id = "partial",
                    code = "ssd",
                    width = 1,
                    height = 3,
                    container = "inventory",
                    physical_min = 256,
                    physical_max = 768,
                    stat_modifiers = {
                        { source_id = "added", stat = "physical_min", operation = "add", value = 256 },
                    },
                },
            },
        },
    },
    cases = {
        test.case("reports_item_contributions_and_hides_unidentified_values", {
            test.step(1),
            test.run(function()
                local snapshots = require("d2legacy.items.snapshot")
                local blade = snapshots.inspect("blade")
                test.expect(blade.damage.min_raw):equals(512)
                test.expect(blade.damage.max_raw):equals(1536)
                test.expect(blade.status):equals("complete")
                test.expect(snapshots.inspect("cap").defense):equals(16)
                local unknown = snapshots.inspect("unknown")
                test.expect(unknown.identified):equals(false)
                test.expect(unknown.status):equals("unidentified")
                test.expect(unknown.defense):equals(nil)
                test.expect(unknown.damage):equals(nil)
                local partial = snapshots.inspect("partial")
                test.expect(partial.status):equals("partial")
                test.expect(partial.damage.min_raw):equals(256)
                blade.damage.min_raw = 999999
                test.expect(snapshots.inspect("blade").damage.min_raw):equals(512)
                test.expect(snapshots.inspect("missing")):equals(nil)
            end),
        }),
        test.case("qualifies_missing_mechanical_facts", {
            test.run(function()
                local ecs = require("engine.ecs/v1")
                for _, entity in ipairs(ecs.query({ all = { "d2legacy.item.identity" } })) do
                    if ecs.get(entity, "d2legacy.item.identity"):get("id") == "blade" then
                        ecs.remove(entity, "d2legacy.item.melee")
                        ecs.remove(entity, "d2legacy.item.armor")
                    end
                end
            end),
            test.step(1),
            test.run(function()
                local value = require("d2legacy.items.snapshot").inspect("blade")
                test.expect(value.status):equals("missing_facts")
                test.expect(value.damage):equals(nil)
                test.expect(value.defense):equals(nil)
            end),
        }),
    },
})
