package d2legacy

import (
	"encoding/json"
	"fmt"
	"github.com/gravestench/dark-magic/internal/content"
	gameecs "github.com/gravestench/dark-magic/internal/game/ecs"
	gamesession "github.com/gravestench/dark-magic/internal/game/session"
	"github.com/gravestench/dark-magic/internal/game/simulation"
	playeradapter "github.com/gravestench/dark-magic/internal/mod/d2legacy/adapter/player"
	"testing"
)

func TestGeneratedDenClearAndAkaraRewardRestore(t *testing.T) {
	records := generatedHostileRecords()
	records["data/global/excel/levels.txt"] = append(records["data/global/excel/levels.txt"], map[string]string{"Id": "8", "MonDen": "100000", "NumMon": "1", "mon1": "fallen"})
	initial := map[string]any{"d2legacy.interactions": map[string]any{"owner": "alice", "targets": []any{map[string]any{"id": "npc:akara", "npc": "akara", "x": 12, "y": 0, "radius": 3, "level_id": 8, "room_id": "b", "resident_id": "akara"}}}}
	start := func(checkpoint *simulation.Checkpoint) (*gameecs.Engine, *gamesession.Session) {
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
		return engine, session
	}
	engine, session := start(nil)
	submit := func(s *gamesession.Session, tick uint64, owner string, seq uint64, kind string, payload any) {
		encoded, err := json.Marshal(payload)
		if err != nil {
			t.Fatal(err)
		}
		auth := simulation.AuthorityPlayer
		if owner == "system" {
			auth = simulation.AuthoritySystem
		}
		if err := s.Submit(simulation.Command{Tick: tick, Player: owner, Authority: auth, Sequence: seq, Kind: kind, Payload: encoded}); err != nil {
			t.Fatal(err)
		}
	}
	rooms := []any{}
	for i := 0; i < 4; i++ {
		rooms = append(rooms, map[string]any{"id": string(rune('a' + i)), "populate": true, "x": i * 8, "y": -2, "width": 8, "height": 8, "points": []any{map[string]any{"x": i*8 + 4, "y": 3}}})
	}
	submit(session, 1, "system", 1, "system.population.bootstrap", map[string]any{"act": 1, "level_id": 8, "difficulty": 0, "rooms": rooms, "links": []any{}})
	stepSession(t, session, 1)
	var player map[string]any
	json.Unmarshal(generatedPlayerPayload(t, "hero", "alice", 1, 0), &player)
	player["level_id"] = 8
	submit(session, 2, "system", 2, "system.player.enter", player)
	stepSession(t, session, 1)
	assertQuest := func(e *gameecs.Engine, complete, rewarded bool) {
		t.Helper()
		q := componentSnapshot(t, e, playerEntity(t, e, "alice"), "d2legacy.quest.progress")
		if q["completed"] != complete || q["rewarded"] != rewarded {
			t.Fatalf("quest=%v", q)
		}
	}
	assertQuest(engine, false, false)
	seq := uint64(0)
	move := func(e *gameecs.Engine, s *gamesession.Session, x int) {
		seq++
		submit(s, e.Tick()+1, "alice", seq, "player.move", map[string]any{"x": 0, "y": 0, "running": false, "target": map[string]any{"x": x, "y": 0}})
		stepSession(t, s, 40)
	}
	kill := func(e *gameecs.Engine, s *gamesession.Session, room string) {
		seq++
		x := int(room[0]-'a')*8 + 4
		submit(s, e.Tick()+1, "alice", seq, "player.use_skill", map[string]any{"side": "left", "target_x": x, "target_y": 3, "target_id": fmt.Sprintf("monster:level:8:room:%s:monster:1", room)})
		stepSession(t, s, 12)
		monster := monsterEntity(t, e, fmt.Sprintf("level:8:room:%s:monster:1", room))
		if _, ok := dynamicStore(t, e, "d2legacy.monster.death").Get(monster); !ok {
			t.Fatalf("room %s monster survived ordinary cast", room)
		}
	}
	kill(engine, session, "a")
	assertQuest(engine, false, false)
	move(engine, session, 9)
	move(engine, session, 17)
	kill(engine, session, "c")
	move(engine, session, 25)
	kill(engine, session, "d")
	assertQuest(engine, false, false)
	assertResidentActivation(t, engine, monsterEntity(t, engine, "level:8:room:b:monster:1"), false, true)
	replay, err := session.Replay()
	if err != nil {
		t.Fatal(err)
	}
	checkpoint := replay.Checkpoints[len(replay.Checkpoints)-1]
	restored, restoredSession := start(&checkpoint)

	finish := func(e *gameecs.Engine, s *gamesession.Session, systemSeq uint64) {
		move(e, s, 9)
		kill(e, s, "b")
		assertQuest(e, true, false)
		seq++
		submit(s, e.Tick()+1, "alice", seq, "interaction.open", map[string]any{"target": "npc:akara"})
		stepSession(t, s, 1)
		assertQuest(e, true, true)
		seq++
		submit(s, e.Tick()+1, "alice", seq, "interaction.open", map[string]any{"target": "npc:akara"})
		stepSession(t, s, 1)
		seq++
		submit(s, e.Tick()+1, "alice", seq, "quest.claim_reward", map[string]any{})
		stepSession(t, s, 1)
		submit(s, e.Tick()+1, "system", systemSeq, "system.quest.complete", map[string]any{"player": "alice", "quest_id": 1})
		stepSession(t, s, 1)
		assertQuest(e, true, true)
		p := componentSnapshot(t, e, playerEntity(t, e, "alice"), "d2legacy.player.progress")
		if p["unspent_skill_points"] != int64(1) {
			t.Fatalf("reward points=%v", p)
		}
	}
	finish(engine, session, 3)
	seq = 0
	finish(restored, restoredSession, 1)
	assertEqualLatestChecksums(t, session, restoredSession, "Den clear and Akara reward")
	finalReplay, err := session.Replay()
	if err != nil {
		t.Fatal(err)
	}
	final := finalReplay.Checkpoints[len(finalReplay.Checkpoints)-1]
	owner, err := playeradapter.ProjectPrivateView("alice", final)
	if err != nil {
		t.Fatal(err)
	}
	if owner.Quest == nil || !owner.Quest.Completed || !owner.Quest.Rewarded {
		t.Fatalf("owner quest projection=%v", owner.Quest)
	}
	other, err := playeradapter.ProjectPrivateView("bob", final)
	if err != nil {
		t.Fatal(err)
	}
	if other.Quest != nil {
		t.Fatalf("owner quest leaked=%v", other.Quest)
	}
}

func TestAkaraRefusesStaleAndOutOfLevelReward(t *testing.T) {
	for _, outOfLevel := range []bool{false, true} {
		t.Run(fmt.Sprint(outOfLevel), func(t *testing.T) {
			engine := gameecs.New()
			defer engine.Close()
			session, err := gamesession.New(engine, gamesession.Config{})
			if err != nil {
				t.Fatal(err)
			}
			defer session.Close()
			initial := map[string]any{"d2legacy.interactions": map[string]any{"owner": "alice", "targets": []any{map[string]any{"id": "npc:akara", "npc": "akara", "x": 1, "y": 0, "radius": 3, "level_id": 2, "room_id": "a", "resident_id": "akara"}}}}
			if outOfLevel {
				initial["d2legacy.world_transitions"] = map[string]any{"seams": []any{map[string]any{"source_level": 2, "destination_level": 8, "source_x": 10, "source_y": 0, "arrival_x": 1, "arrival_y": 0, "world_width": 100, "world_height": 100}}}
			}
			authority, err := StartWithConfig(t.Context(), content.D2Legacy(), fixtureRecords{}, engine, session, Config{Seed: 1, InitialData: initial})
			if err != nil {
				t.Fatal(err)
			}
			defer authority.Stop(t.Context())
			submit := func(owner string, seq uint64, kind string, payload json.RawMessage) {
				auth := simulation.AuthorityPlayer
				if owner == "system" {
					auth = simulation.AuthoritySystem
				}
				if err := session.Submit(simulation.Command{Tick: engine.Tick() + 1, Player: owner, Authority: auth, Sequence: seq, Kind: kind, Payload: payload}); err != nil {
					t.Fatal(err)
				}
				stepSession(t, session, 1)
			}
			submit("system", 1, "system.player.enter", generatedPlayerPayload(t, "hero", "alice", 1, 0))
			submit("alice", 1, "interaction.open", []byte(`{"target":"npc:akara"}`))
			submit("system", 2, "system.quest.complete", []byte(`{"player":"alice","quest_id":1}`))
			submit("alice", 2, "player.move", []byte(`{"x":0,"y":0,"running":false,"target":{"x":10,"y":0}}`))
			stepSession(t, session, 40)
			submit("alice", 3, "quest.claim_reward", []byte(`{}`))
			q := componentSnapshot(t, engine, playerEntity(t, engine, "alice"), "d2legacy.quest.progress")
			if q["rewarded"] != false {
				t.Fatalf("stale reward granted: %v", q)
			}
			if outOfLevel {
				location := componentSnapshot(t, engine, playerEntity(t, engine, "alice"), "d2legacy.world.location")
				if location["level_id"] != int64(8) {
					t.Fatalf("test did not cross level: %v", location)
				}
			}
		})
	}
}
