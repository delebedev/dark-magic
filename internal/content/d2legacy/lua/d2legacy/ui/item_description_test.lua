local test = require("d2legacy.tests/v1")
return test.suite({name="item description", profile = "module", tier = "fast", cases = {
    test.case("formats_item_units_and_preserves_inspection_qualifications", function(t)
        t:run(function()
            local description = require("d2legacy.ui.item_description")
            test.expect(description.facts({identified=true,status="complete",damage={min_raw=512,max_raw=1664}}))
                :equals("Damage 2 - 6.5")
            test.expect(description.facts({identified=true,status="complete",defense=0})):equals("Defense 0")
            test.expect(description.facts({identified=false,status="unidentified",defense=666})):equals("Unidentified")
            test.expect(description.facts({identified=true,status="partial",defense=16}))
                :equals("Defense 16\nOther effects not shown")
            test.expect(description.facts(nil)):equals("Details unavailable")
            test.expect(description.comparison({container="world",inspection={defense=8}}, {items={}}))
                :equals("Equipment comparison after Take.")
        end)
    end),
    test.case("compares_only_matching_slots_in_the_active_weapon_set", function(t)
        t:run(function()
            local description = require("d2legacy.ui.item_description")
            local selected = {id="new",body_slots="rarm,larm"}
            local snapshot = {active_weapon_set=0,items={
                {id="old",container="equipment",slot="rarm",weapon_set=0,
                    inspection={identified=true,status="complete",damage={min_raw=256,max_raw=768}}},
                {id="other",container="equipment",slot="rarm",weapon_set=1,
                    inspection={identified=true,status="complete",damage={min_raw=999,max_raw=999}}},
                {id="hidden",container="equipment",slot="larm",weapon_set=0,
                    inspection={identified=false,status="unidentified",defense=999}},
            }}
            test.expect(description.comparison(selected,snapshot))
                :equals("[gold]Right hand now[/]\nDamage 1 - 3\n[gold]Left hand now[/]\nUnidentified")
        end)
    end),
}})
