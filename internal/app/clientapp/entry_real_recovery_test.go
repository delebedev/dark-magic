package clientapp

import (
	d2save "github.com/gravestench/dark-magic/internal/mod/d2legacy/adapter/save"
	"testing"
)

func TestGameWorldSavedCorpseRecoversAtPreparedTownSpawn(t *testing.T) {
	fixture := newRealD2LegacyFixture(t, realD2LegacyFixtureConfig{startScene: "game_world", fixtureWorldLevel: 1})
	app := fixture.app
	character := developmentCharacter(0, "Amazon")
	character.Stats.Health = 0
	character.Stats.Mana = 0
	character.Stats.Stamina = 0
	character.Death = &d2save.Death{}

	character.Inventory = &d2save.Inventory{InventoryWidth: 10,
		InventoryHeight: 4,
		StashWidth:      6,
		StashHeight:     8,
		CubeWidth:       3,
		CubeHeight:      4,
		BeltCapacity:    4,
		VendorWidth:     10,
		VendorHeight:    10,

		Corpses: []d2save.Corpse{{ID: "saved-body"}},
		Items: []d2save.Item{{ID: "cap",
			Code:       "cap",
			Width:      2,
			Height:     2,
			Container:  "corpse",
			CorpseID:   "saved-body",
			BodySlots:  "head",
			Slot:       "head",
			Defense:    6,
			Identified: true}}}
	if err := app.saves.CreateSelected(character); err != nil {
		t.Fatal(err)
	}

	if err := app.network.StartSelected(); err != nil {
		t.Fatal(err)
	}

	fixture.advanceGame(t, 10)
	identities := requireRealStore(t, fixture, "d2legacy.player.identity", "no player")
	hero := identities.Entities()[0]
	deaths := requireRealStore(t, fixture, "d2legacy.player.death", "no death store")

	death, ok := deaths.Get(hero)
	if !ok {
		t.Fatal("saved death not admitted")
	}

	tick, _ := death.Get("tick")

	corpses := requireRealStore(t, fixture, "d2legacy.player.corpse", "no corpse store")
	if corpses.Len() != 1 {
		t.Fatal("saved corpse not rebuilt")
	}

	location := requireRealStore(t, fixture, "d2legacy.world.location", "no location")
	corpseLocation, _ := location.Get(corpses.Entities()[0])

	level, _ := corpseLocation.Get("level_id")
	if level != int64(1) {
		t.Fatal("saved corpse not in town")
	}

	if err := app.commandIntents.Submit("player.continue", map[string]any{"death_tick": tick}); err != nil {
		t.Fatal(err)
	}

	fixture.advanceGame(t, 3)

	if _, dead := deaths.Get(hero); dead {
		t.Fatal("Continue did not remove canonical death")
	}

	vitals := requireRealStore(t, fixture, "d2legacy.player.vitals", "no vitals")

	vital, _ := vitals.Get(hero)
	for _, name := range []string{"health", "mana", "stamina"} {
		current, _ := vital.Get(name)

		maximum, _ := vital.Get("max_" + name)
		if current != maximum {
			t.Fatalf("%s not refilled: %v/%v", name, current, maximum)
		}
	}

	heroLocation, _ := location.Get(hero)

	level, _ = heroLocation.Get("level_id")
	if level != int64(1) || app.activeWorldLevel != 1 {
		t.Fatal("Continue did not synchronize town authority and presentation")
	}

	if err := app.commandIntents.Submit("player.corpse.recover",
		map[string]any{"target_id": "player_corpse:saved-body"}); err != nil {
		t.Fatal(err)
	}

	fixture.advanceGame(t, 3)

	if corpses.Len() != 0 {
		positions := requireRealStore(t, fixture, "d2legacy.world.position", "no positions")
		px, py := dynamicPosition(positions, hero)
		cx, cy := dynamicPosition(positions, corpses.Entities()[0])
		corpse, _ := corpses.Get(corpses.Entities()[0])
		owner, _ := corpse.Get("owner")
		inactive := requireRealStore(t, fixture, "d2legacy.world.inactive", "no inactive")
		_, hidden := inactive.Get(corpses.Entities()[0])
		t.Fatalf("town collision/reach prevented saved corpse recovery: hero=%v at %.1f,%.1f "+
			"corpse owner=%v at %.1f,%.1f hidden=%v clear=%v selfclear=%v",
			hero,
			px,
			py,
			owner,
			cx,
			cy,
			hidden,
			app.gameWorlds[1].LineClear(px,
				py,
				cx,
				cy),
			app.gameWorlds[1].LineClear(px,
				py,
				px,
				py))
	}

	items := requireRealStore(t, fixture, "d2legacy.item.identity", "no gear")

	placements := requireRealStore(t, fixture, "d2legacy.item.placement", "no placement")
	if items.Len() != 1 {
		t.Fatal("recovery lost or duplicated gear")
	}

	placed, _ := placements.Get(items.Entities()[0])

	container, _ := placed.Get("container")
	if container != "equipment" {
		t.Fatalf("cap not re-equipped: %v", container)
	}

	t.Logf("owned real town geometry: saved corpse restored, Continue refilled resources, cap recovered at prepared spawn")
}
