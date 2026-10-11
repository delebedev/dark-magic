package d2legacy

import (
	"encoding/json"
	"testing"

	"github.com/gravestench/dark-magic/internal/content"
	gameecs "github.com/gravestench/dark-magic/internal/game/ecs"
	gamesession "github.com/gravestench/dark-magic/internal/game/session"
	"github.com/gravestench/dark-magic/internal/game/simulation"
)

func TestDungeonPopulationRestoresWithIndependentRoomResidency(t *testing.T) {
	records := generatedHostileRecords()
	records["data/global/excel/levels.txt"] = append(records["data/global/excel/levels.txt"], map[string]string{"Id": "8", "MonDen": "100000", "NumMon": "1", "mon1": "fallen"})
	initial := map[string]any{"d2legacy.world_transitions": map[string]any{"seams": []any{
		map[string]any{"source_level": 2, "destination_level": 8, "source_x": 9, "source_y": 1, "arrival_x": 1, "arrival_y": 1, "world_width": 100, "world_height": 100},
		map[string]any{"source_level": 8, "destination_level": 2, "source_x": 9, "source_y": 1, "arrival_x": 1, "arrival_y": 1, "world_width": 100, "world_height": 100},
	}}}
	start := func(checkpoint *simulation.Checkpoint) (*Authority, *gameecs.Engine, *gamesession.Session) {
		t.Helper()
		engine := gameecs.New()
		var restore []simulation.ParticipantState
		if checkpoint != nil {
			engine.Close()
			var err error
			engine, err = gameecs.RestoreSnapshot(*checkpoint.Snapshot)
			if err != nil {
				t.Fatal(err)
			}
			restore = checkpoint.Participants
		}
		session, err := gamesession.New(engine, gamesession.Config{CheckpointInterval: 1})
		if err != nil {
			t.Fatal(err)
		}
		authority, err := StartWithConfig(t.Context(), content.D2Legacy(), records, engine, session, Config{Seed: 314, InitialData: initial, Restore: restore})
		if err != nil {
			t.Fatal(err)
		}
		t.Cleanup(func() { authority.Stop(t.Context()); session.Close(); engine.Close() })
		return authority, engine, session
	}
	_, engine, session := start(nil)
	area := func(level int) map[string]any {
		return map[string]any{
			"act": 1, "level_id": level, "difficulty": 0, "links": []any{},
			"rooms": []any{map[string]any{"id": "a", "populate": true, "x": 0, "y": 0, "width": 30, "height": 30, "points": []any{map[string]any{"x": 20, "y": 1}}}},
		}
	}
	population := area(2)
	population["additional_zones"] = []any{area(8)}
	payload, err := json.Marshal(population)
	if err != nil {
		t.Fatal(err)
	}
	if err := session.Submit(simulation.Command{Tick: 1, Player: "population", Authority: simulation.AuthoritySystem, Sequence: 1, Kind: "system.population.bootstrap", Payload: payload}); err != nil {
		t.Fatal(err)
	}
	stepSession(t, session, 1)
	if err := session.Submit(simulation.Command{Tick: 2, Player: "system", Authority: simulation.AuthoritySystem, Sequence: 1, Kind: "system.player.enter", Payload: generatedPlayerPayload(t, "hero", "alice", 1, 1)}); err != nil {
		t.Fatal(err)
	}
	stepSession(t, session, 1)
	moor := monsterEntity(t, engine, "level:2:room:a:monster:1")
	submitMoveCommand(t, session, 3, "alice", 1, 1)
	for engine.Tick() < 100 {
		stepSession(t, session, 1)
		level := componentSnapshot(t, engine, playerEntity(t, engine, "alice"), "d2legacy.world.location")["level_id"]
		if level == int64(8) {
			break
		}
	}
	stepSession(t, session, 1)
	den := monsterEntity(t, engine, "level:8:room:a:monster:1")
	assertResidentActivation(t, engine, moor, false, true)
	assertResidentActivation(t, engine, den, true, true)
	replay, err := session.Replay()
	if err != nil {
		t.Fatal(err)
	}
	checkpoint := replay.Checkpoints[len(replay.Checkpoints)-1]
	_, restoredEngine, restoredSession := start(&checkpoint)
	assertResidentActivation(t, restoredEngine, monsterEntity(t, restoredEngine, "level:2:room:a:monster:1"), false, true)
	assertResidentActivation(t, restoredEngine, monsterEntity(t, restoredEngine, "level:8:room:a:monster:1"), true, true)
	stepSession(t, session, 1)
	stepSession(t, restoredSession, 1)
	assertEqualLatestChecksums(t, session, restoredSession, "dungeon population checkpoint")
}
