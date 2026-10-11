package clientapp

import "testing"

func TestGameWorldWalksAuthoredExitAndReturns(t *testing.T) {
	fixture := newRealD2LegacyFixture(t, realD2LegacyFixtureConfig{
		startScene: "game_world", fixtureCharacters: 1, fixtureWorldLevel: 1, fixtureWorldSpawn: "seam",
	})
	app := fixture.app
	if err := app.network.StartSelected(); err != nil {
		t.Fatal(err)
	}
	fixture.advanceGame(t, 10)
	controls := requireRealStore(t, fixture, "d2legacy.world.player_control", "no controlled player")
	locations := requireRealStore(t, fixture, "d2legacy.world.location", "no location")
	location, _ := locations.Get(controls.Entities()[0])
	t.Logf("town exit=%+v wilderness exit=%+v", app.transitionSeam.Town, app.transitionSeam.Wilderness)
	for _, leg := range []struct {
		x, y  float64
		level int
	}{
		{app.transitionSeam.Town.X, app.transitionSeam.Town.Y, 2},
		{app.transitionSeam.Wilderness.X, app.transitionSeam.Wilderness.Y, 1},
	} {
		if err := app.playerControl.SetMoveTarget(leg.x, leg.y); err != nil {
			t.Fatal(err)
		}
		for range 250 {
			fixture.advanceGame(t, 1)
			level, _ := location.Get("level_id")
			if level == int64(leg.level) {
				break
			}
		}
		level, _ := location.Get("level_id")
		if level != int64(leg.level) || app.activeWorldLevel != leg.level {
			t.Fatalf("walking exit left authority/presentation at %v/%d, want %d", level, app.activeWorldLevel, leg.level)
		}
		if app.playerControl.HasMoveTarget() {
			t.Fatal("travel retained the old world's movement target")
		}
	}
}

func TestGameWorldSwordRejectsWrongSlotAndEquipsBothHands(t *testing.T) {
	fixture := newRealD2LegacyFixture(t, realD2LegacyFixtureConfig{
		startScene: "game_world", fixtureCharacters: 1, fixtureWorldLevel: 1,
	})
	if err := fixture.app.network.StartSelected(); err != nil {
		t.Fatal(err)
	}
	fixture.advanceGame(t, 10)
	items := requireRealStore(t, fixture, "d2legacy.item.identity", "no items")
	placements := requireRealStore(t, fixture, "d2legacy.item.placement", "no placements")
	for _, entity := range items.Entities() {
		item, _ := items.Get(entity)
		id, _ := item.Get("id")
		if id != "fixture-short-sword" {
			continue
		}
		placed, _ := placements.Get(entity)
		move := func(destination map[string]any, held bool) {
			t.Helper()
			if err := fixture.app.commandIntents.Submit("item.move", map[string]any{
				"item_id": id, "destination": destination, "place_held": held,
			}); err != nil {
				t.Fatal(err)
			}
			fixture.advanceGame(t, 2)
		}
		for _, slot := range []string{"rarm", "larm"} {
			move(map[string]any{"container": "held"}, false)
			move(map[string]any{"container": "equipment", "slot": "head"}, true)
			container, _ := placed.Get("container")
			if container != "held" {
				t.Fatalf("invalid drop moved sword to %v", container)
			}
			move(map[string]any{"container": "equipment", "slot": slot}, true)
			container, _ = placed.Get("container")
			actualSlot, _ := placed.Get("slot")
			if container != "equipment" || actualSlot != slot {
				t.Fatalf("sword placement = %v/%v, want equipment/%s", container, actualSlot, slot)
			}
		}
		return
	}
	t.Fatal("real Game World fixture has no short sword")
}
