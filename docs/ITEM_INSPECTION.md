# Item inspection presentation contract

`require("d2legacy.items.api").inspect(id)` returns a fresh value table or `nil`
when the item is absent. Use the inventory item `id` for owned possessions,
or the public ground selectable ID (`item:<owner>:<item-id>`) before pickup.
`items.api.snapshot().items[i].inspection` exposes the same table.

```lua
{
    identified = true,
    status = "complete",
    damage = { min_raw = 512, max_raw = 1536 }, -- optional, 8.8 units: divide by 256
    defense = 16, -- optional, whole defense units
}
```

Damage is the item's physical range used by the equipped melee profile. It
excludes strength, skills, character modifiers, hit chance and target mitigation.
Defense is this item's armor contribution, including the supported local
enhanced-defense calculation shared with equipment. It excludes dexterity and
other character defense sources. Missing fields mean unavailable or inapplicable,
never zero. A present zero is a measured contribution.

Statuses:

- `complete`: the reported contributions are available with no known unreported modifiers.
- `partial`: reported contributions are available, but other modifiers or
  non-normal quality effects are outside this small contract. Describe the
  available facts and show that additional effects are not represented.
- `unidentified`: identification is false. Numeric damage and defense are omitted.
- `missing_facts`: mechanical facts have not been supplied. Numeric fields are omitted.

The conservative identification policy hides numeric values until identified.
It does not claim to reproduce every native unidentified base-item tooltip.
Unknown affixes never become invented damage or defense values.

Authority resolves the facts in Lua. Connected clients receive this allowlist
through private item views and nearby public ground-item views, then read the
same snapshot API. Ground inspection does not transmit inventory ownership,
raw modifiers, RNG or authoritative item components.

Protocol versions: client view 15, private view 4, world view 8. Both endpoints
must use compatible core revisions. Inspection does not change gameplay commands.

Verification: `TestGameWorldItemInspectionMatchesConnectedProjection` uses owned
real assets, compares local Lua snapshots with private projection and connected
Lua snapshots, drops the sword through an ordinary command, and compares its
public ground inspection. Lua inspection cases cover local enhanced defense,
unidentified values, partial modifiers, missing mechanics and copied tables.
