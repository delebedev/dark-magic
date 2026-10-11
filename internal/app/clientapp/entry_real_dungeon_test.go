package clientapp

import (
	gameworld "github.com/gravestench/dark-magic/internal/game/world"
	"math"
	"testing"
)

// TestGameWorldWalksIntoPopulatedDenAndReturns exercises normal admission and generated collision, without warp fixtures.
func TestGameWorldWalksIntoPopulatedDenAndReturns(t *testing.T) {
	fixture := newRealD2LegacyFixture(t, realD2LegacyFixtureConfig{startScene: "game_world", fixtureCharacters: 1})
	app := fixture.app
	if err := app.network.StartSelected(); err != nil {
		t.Fatal(err)
	}
	fixture.advanceGame(t, 10)
	if len(app.additionalTransitionSeams) != 1 {
		t.Fatalf("dungeon seams=%d", len(app.additionalTransitionSeams))
	}
	seam := app.additionalTransitionSeams[0]
	if seam.Town.LevelID != 2 || seam.Wilderness.LevelID != 8 {
		t.Fatalf("dungeon seam=%+v", seam)
	}
	controls := requireRealStore(t, fixture, "d2legacy.world.player_control", "no player")
	locations := requireRealStore(t, fixture, "d2legacy.world.location", "no location")
	positions := requireRealStore(t, fixture, "d2legacy.world.position", "no position")
	location, _ := locations.Get(controls.Entities()[0])
	colliders := requireRealStore(t, fixture, "d2legacy.world.collider", "no collider")
	collider, _ := colliders.Get(controls.Entities()[0])
	radiusValue, _ := collider.Get("radius")
	t.Logf("collider radius=%v, seam=%+v", radiusValue, seam)
	for _, endpoint := range []struct {
		level        int
		x, y, ax, ay float64
	}{
		{2, seam.Town.X, seam.Town.Y, seam.Town.ArrivalX, seam.Town.ArrivalY},
		{8, seam.Wilderness.X, seam.Wilderness.Y, seam.Wilderness.ArrivalX, seam.Wilderness.ArrivalY},
	} {
		_, err := app.gameWorlds[endpoint.level].FindPath(gameworld.PathRequest{Start: gameworld.Point{X: endpoint.ax, Y: endpoint.ay}, Goal: gameworld.Point{X: endpoint.x, Y: endpoint.y}, Radius: radiusValue.(float64)})
		if err != nil {
			t.Fatalf("level %d arrival-to-exit: %v", endpoint.level, err)
		}
	}
	for _, leg := range []struct {
		x, y  float64
		level int
	}{
		{app.transitionSeam.Town.X, app.transitionSeam.Town.Y, 2},
		{seam.Town.X, seam.Town.Y, 8},
		{seam.Wilderness.X, seam.Wilderness.Y, 2},
	} {
		t.Logf("walking to %d via (%v,%v)", leg.level, leg.x, leg.y)
		if err := app.playerControl.SetMoveTarget(leg.x, leg.y); err != nil {
			t.Fatal(err)
		}
		for range 3000 {
			fixture.advanceGame(t, 1)
			level, _ := location.Get("level_id")
			if level == int64(leg.level) {
				break
			}
		}
		level, _ := location.Get("level_id")
		if level != int64(leg.level) || app.activeWorldLevel != leg.level {
			position, _ := positions.Get(controls.Entities()[0])
			x, _ := position.Get("x")
			y, _ := position.Get("y")
			t.Fatalf("authority/presentation=%v/%d, want %d, player=(%v,%v)", level, app.activeWorldLevel, leg.level, x, y)
		}
		position, _ := positions.Get(controls.Entities()[0])
		x, _ := position.Get("x")
		y, _ := position.Get("y")
		world := app.gameWorlds[leg.level]
		flags, inside := world.FlagsAt(int(math.Floor(x.(float64))), int(math.Floor(y.(float64))))
		if !inside || flags.Blocked() {
			t.Fatal("transition arrived in blocked collision")
		}
		if leg.level == 8 {
			fixture.advanceGame(t, 2)
			monsters := requireRealStore(t, fixture, "d2legacy.monster.identity", "no monsters")
			count := 0
			for _, entity := range monsters.Entities() {
				if monsterLocation, ok := locations.Get(entity); ok {
					value, _ := monsterLocation.Get("level_id")
					if value == int64(8) {
						count++
					}
				}
			}
			if count == 0 {
				t.Fatal("Den activated without naturally populated monsters")
			}
			t.Logf("Den monsters=%d", count)
			app.playerControl.SetRunning(true)
			for _, room := range app.gameWorldZones[8].Rooms() {
				playerPosition, _ := positions.Get(controls.Entities()[0])
				px, _ := playerPosition.Get("x")
				py, _ := playerPosition.Get("y")
				path, err := world.FindPath(gameworld.PathRequest{
					Start:  gameworld.Point{X: px.(float64), Y: py.(float64)},
					Goal:   gameworld.Point{X: float64((room.X + room.Width/2) * gameworld.SubtilesPerTile), Y: float64((room.Y + room.Height/2) * gameworld.SubtilesPerTile)},
					Radius: 1, StopRadius: 20,
				})
				if err != nil {
					t.Fatalf("room %d: %v", room.ID, err)
				}
				goal := path[len(path)-1]
				if err := app.playerControl.SetMoveTarget(goal.X, goal.Y); err != nil {
					t.Fatal(err)
				}
				reached := false
				for range 1200 {
					fixture.advanceGame(t, 1)
					playerPosition, _ = positions.Get(controls.Entities()[0])
					px, _ = playerPosition.Get("x")
					py, _ = playerPosition.Get("y")
					if math.Hypot(px.(float64)-goal.X, py.(float64)-goal.Y) < 1.5 {
						reached = true
						break
					}
				}
				if !reached {
					t.Fatalf("player did not traverse Den room %d, at (%v,%v), target (%v,%v)", room.ID, px, py, goal.X, goal.Y)
				}
				t.Logf("player traversed Den room %d", room.ID)
			}
			app.playerControl.SetRunning(false)
		}
	}
}
