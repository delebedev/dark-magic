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
