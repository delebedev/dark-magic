local test = require("d2legacy.tests/v1")

local records = {
    ["data/global/excel/treasureclassex.txt"] = {
        {
            ["Treasure Class"] = "root",
            Picks = "-1",
            Item1 = "child",
            Prob1 = "1",
            Unique = "200",
        },
        {
            ["Treasure Class"] = "child",
            Picks = "-1",
            Item1 = "rin",
            Prob1 = "1",
            Unique = "100",
            Set = "300",
        },
        { ["Treasure Class"] = "equipment", Picks = "-1", Item1 = "weap3", Prob1 = "1", Magic = "400" },
    },
    ["data/global/excel/ItemTypes.txt"] = {
        { Code = "weap", TreasureClass = "1" },
        { Code = "mele", Equiv1 = "weap" },
        { Code = "swor", Equiv1 = "mele", Rarity = "2" },
        { Code = "axe", Equiv1 = "mele", Rarity = "0" },
        { Code = "armo", TreasureClass = "1" },
        { Code = "helm", Equiv1 = "armo", Rarity = "1" },
        { Code = "mpot", Equiv1 = "weap" },
    },
    ["data/global/excel/weapons.txt"] = {
        { code = "ssd", type = "swor", level = "3", spawnable = "1" },
        { code = "hax", type = "axe", level = "4", spawnable = "1" },
        { code = "disabled", type = "swor", level = "1", spawnable = "0" },
        { code = "quest", type = "swor", level = "1", spawnable = "1", quest = "1" },
        { code = "zero", type = "swor", level = "0", spawnable = "1" },
    },
    ["data/global/excel/armor.txt"] = {
        { code = "cap", type = "helm", level = "1", spawnable = "1" },
    },
    ["data/global/excel/misc.txt"] = {
        { code = "gpl", type = "mpot", level = "1", spawnable = "1" },
    },
}

local function implicit_item_families_resolve_to_eligible_base_codes()
    local treasure = require("d2legacy.loot.treasure_class")
    local context = { no_drop_player_count = 1 }
    local drops = treasure.roll("equipment", context)
    test.expect(#drops):equals(1)
    test.expect(drops[1].code):equals("ssd")
    test.expect(table.concat(drops[1].path, " > ")):equals("equipment > weap3")
    test.expect(drops[1].quality.magic):equals(400)
    test.expect(treasure.roll("weap6", context)[1].code):equals("hax")
    test.expect(treasure.roll("armo3", context)[1].code):equals("cap")
end

local function nested_classes_keep_strongest_quality_modifiers()
    local treasure = require("d2legacy.loot.treasure_class")
    local drops = treasure.roll("root", { no_drop_player_count = 1 })

    test.assert(#drops == 1, [=[#drops == 1]=])
    test.assert(drops[1].code == "rin", [=[drops[1].code == "rin"]=])
    test.assert(drops[1].quality.unique == 200, [=[drops[1].quality.unique == 200]=])
    test.assert(drops[1].quality.set == 300, [=[drops[1].quality.set == 300]=])
    test.assert(
        require("d2legacy.loot.generate").encode({}) == "[]",
        [=[require("d2legacy.loot.generate").encode({}) == "[]"]=]
    )
end

local function nodrop_uses_distinct_effective_and_nearby_counts()
    local treasure = require("d2legacy.loot.treasure_class")
    local function adjusted(count)
        return treasure.adjusted_no_drop(100, 100, {
            no_drop_player_count = count,
        })
    end

    test.assert(adjusted(1) == 100, [=[adjusted(1) == 100]=])
    test.assert(adjusted(2) == 33, [=[adjusted(2) == 33]=])
    test.assert(adjusted(3) == 14, [=[adjusted(3) == 14]=])
    test.assert(adjusted(4) == 6, [=[adjusted(4) == 6]=])
end

return test.suite({
    profile = "module",
    tier = "fast",
    records = records,
    cases = {
        test.case("implicit_item_families_resolve_to_eligible_base_codes", {
            { run = implicit_item_families_resolve_to_eligible_base_codes },
        }),
        test.case("nested_classes_keep_strongest_quality_modifiers", {
            { run = nested_classes_keep_strongest_quality_modifiers },
        }),
        test.case("nodrop_uses_distinct_effective_and_nearby_counts", {
            { run = nodrop_uses_distinct_effective_and_nearby_counts },
        }),
    },
})
