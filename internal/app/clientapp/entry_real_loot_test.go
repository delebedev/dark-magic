package clientapp

import (
	"encoding/json"
	"math"
	"strconv"
	"testing"

	"github.com/gravestench/akara"
	"github.com/gravestench/dark-magic/internal/game/simulation"
)

func TestGameWorldDenCombatCommitsNaturalNoDropRolls(t *testing.T) {
	fixture := newRealD2LegacyFixture(t, realD2LegacyFixtureConfig{startScene: "game_world", fixtureCharacters: 1})

	app := fixture.app
	if err := app.network.StartSelected(); err != nil {
		t.Fatal(err)
	}

	fixture.advanceGame(t, 10)
	players := requireRealStore(t, fixture, "d2legacy.player.identity", "no player")
	hero := players.Entities()[0]
	locations := requireRealStore(t, fixture, "d2legacy.world.location", "no locations")
	positions := requireRealStore(t, fixture, "d2legacy.world.position", "no positions")
	location, _ := locations.Get(hero)
	monsters := requireRealStore(t, fixture, "d2legacy.monster.identity", "no natural monsters")
	deaths := requireRealStore(t, fixture, "d2legacy.monster.death", "no death store")
	selectables := requireRealStore(t, fixture, "d2legacy.world.selectable", "no selectable store")
	inactive := requireRealStore(t, fixture, "d2legacy.world.inactive", "no residency")
	kill := func(target akara.Entity) {
		selected, _ := selectables.Get(target)
		targetID, _ := selected.Get("id")
		definition, _ := monsters.Get(target)
		family, _ := definition.Get("definition_id")
		tc, _ := definition.Get("treasure_class")

		x, y := dynamicPosition(positions, target)
		if err := app.playerControl.SetMoveTarget(x, y); err != nil {
			t.Fatal(err)
		}

		for range 1000 {
			fixture.advanceGame(t, 1)

			px, py := dynamicPosition(positions, hero)

			x, y = dynamicPosition(positions, target)
			if math.Hypot(px-x, py-y) < 2.8 {
				break
			}
		}

		px, py := dynamicPosition(positions, hero)
		if err := app.playerControl.SetMoveTarget(px, py); err != nil {
			t.Fatal(err)
		}

		replay, err := app.offlineSession.Replay()
		if err != nil {
			t.Fatal(err)
		}

		checkpoint := replay.Checkpoints[len(replay.Checkpoints)-1]

		var rng struct {
			Seed    uint64            `json:"seed"`
			Streams map[string]uint64 `json:"streams"`
		}

		for _, participant := range checkpoint.Participants {
			if participant.ID == "engine.authoritative_rng/v1" {
				if err := json.Unmarshal(participant.Data, &rng); err != nil {
					t.Fatal(err)
				}
			}
		}

		beforeRoll, found := rng.Streams["d2legacy.loot.treasure_class"]
		if !found {
			t.Fatal("missing authoritative TC stream")
		}

		for attack := 0; attack < 60; attack++ {
			if _, dead := deaths.Get(target); dead {
				break
			}

			x, y := dynamicPosition(positions, target)
			if err := app.commandIntents.Submit("player.use_skill",
				map[string]any{"side": "left",
					"target_x":  x,
					"target_y":  y,
					"target_id": targetID}); err != nil {
				t.Fatal(err)
			}

			fixture.advanceGame(t, 20)
		}

		death, dead := deaths.Get(target)
		if !dead {
			stats := requireRealStore(t, fixture, "d2legacy.monster.stats", "no stats")
			stat, _ := stats.Get(target)
			health, _ := stat.Get("health")
			px, py := dynamicPosition(positions, hero)
			tx, ty := dynamicPosition(positions, target)
			t.Fatalf("ordinary attacks did not kill %v health=%v player=(%.1f,%.1f) target=(%.1f,%.1f)",
				family,
				health,
				px,
				py,
				tx,
				ty)
		}

		drops, _ := death.Get("drops")

		rows, err := app.records.Load("data/global/excel/treasureclassex.txt")
		if err != nil {
			t.Fatal(err)
		}

		var row map[string]string

		for _, candidate := range rows {
			if candidate["Treasure Class"] == tc {
				row = candidate
				break
			}
		}

		if row == nil {
			t.Fatalf("real TC row absent: %v", tc)
		}

		rawNoDrop, _ := strconv.Atoi(row["NoDrop"])
		picks, _ := strconv.Atoi(row["Picks"])
		weight := 0

		for i := 1; i <= 10; i++ {
			n, _ := strconv.Atoi(row["Prob"+strconv.Itoa(i)])
			weight += n
		}

		count, _ := death.Get("no_drop_player_count")
		chance := float64(rawNoDrop) / float64(rawNoDrop+weight)
		adjustedChance := math.Pow(chance, float64(count.(int64)))
		noDrop := uint64(math.Floor(float64(weight) * adjustedChance / (1 - adjustedChance)))
		// Reconstruct a read-only copy of the recorded pre-death stream, without drawing from gameplay RNG.
		roll := simulation.RestoreStream(beforeRoll).Uint64n(uint64(weight) + noDrop)
		if picks != 1 || roll >= noDrop || drops != "[]" {
			t.Fatalf("empty loot was not the expected real NoDrop outcome: row=%v roll=%d adjustedNoDrop=%d drops=%v",
				row,
				roll,
				noDrop,
				drops)
		}

		t.Logf("seed=%d natural kill %v TC=%v Picks=%d NoDrop=%d itemWeight=%d "+
			"adjustedNoDrop=%d rootRoll=%d noDropPlayers=%v drops=%v row=%v",
			rng.Seed,
			family,
			tc,
			picks,
			rawNoDrop,
			weight,
			noDrop,
			roll,
			count,
			drops,
			row)
	}

	for _, leg := range []struct {
		x, y  float64
		level int
	}{{app.transitionSeam.Town.X,
		app.transitionSeam.Town.Y,
		2},
		{app.additionalTransitionSeams[0].Town.X,
			app.additionalTransitionSeams[0].Town.Y,
			8}} {
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
		if level != int64(leg.level) {
			px, py := dynamicPosition(positions, hero)
			vitals := requireRealStore(t, fixture, "d2legacy.player.vitals", "no vitals")
			vital, _ := vitals.Get(hero)
			health, _ := vital.Get("health")
			playerDeaths := requireRealStore(t, fixture, "d2legacy.player.death", "no player death store")
			_, dead := playerDeaths.Get(hero)
			t.Fatalf("ordinary travel did not reach level %d at (%v,%v), destination=(%v,%v), health=%v dead=%v",
				leg.level,
				px,
				py,
				leg.x,
				leg.y,
				health,
				dead)
		}
	}

	fixture.advanceGame(t, 2)
	// The normal harness uses map seed 1 and authority RNG seed 0.
	for encounter := 0; encounter < 3; encounter++ {
		px, py := dynamicPosition(positions, hero)

		var target akara.Entity

		nearest := math.Inf(1)

		for _, entity := range monsters.Entities() {
			if _, dead := deaths.Get(entity); dead {
				continue
			}

			if _, hidden := inactive.Get(entity); hidden {
				continue
			}

			monsterLocation, ok := locations.Get(entity)
			if !ok {
				continue
			}

			level, _ := monsterLocation.Get("level_id")
			if level != int64(8) {
				continue
			}

			x, y := dynamicPosition(positions, entity)

			distance := math.Hypot(x-px, y-py)
			if distance < nearest {
				target, nearest = entity, distance
			}
		}

		if target == 0 {
			t.Fatal("fixed Den encounter produced no living natural monster")
		}

		kill(target)
	}
}
