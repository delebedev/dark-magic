package d2legacy

import (
	"encoding/json"
	"fmt"
	"math"
	"os"
	"testing"

	"github.com/gravestench/dark-magic/internal/content"
	recordstore "github.com/gravestench/dark-magic/internal/game/data/store"
	gameecs "github.com/gravestench/dark-magic/internal/game/ecs"
	gamesession "github.com/gravestench/dark-magic/internal/game/session"
	"github.com/gravestench/dark-magic/internal/game/simulation"
	gameworld "github.com/gravestench/dark-magic/internal/game/world"
	entryworld "github.com/gravestench/dark-magic/internal/mod/d2legacy/adapter/entryworld"
)

type dungeonPopulationObjects struct{}

func (dungeonPopulationObjects) ResolveStaticObject(int, int) (int, string, bool) {
	return 0, "", false
}
func (dungeonPopulationObjects) ResolveDynamicObject(int, int) (string, bool) { return "", false }

func TestDenNaturalEncountersOccupyReachableChambers(t *testing.T) {
	directory := os.Getenv("DARK_MAGIC_TEST_MPQ_DIRECTORY")
	if directory == "" {
		t.Skip("set DARK_MAGIC_TEST_MPQ_DIRECTORY to owned Diablo II assets")
	}
	t.Setenv("MPQ_DIRECTORY", directory)
	source, err := content.FromEnvironment(content.Layer{Name: "d2legacy", FS: content.D2Legacy()})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { source.Close() })
	records := recordstore.New(source)
	for _, seed := range []uint64{1, 17, 42} {
		t.Run(fmt.Sprint(seed), func(t *testing.T) {
			prepared, err := entryworld.Build(t.Context(), source, content.D2Legacy(), records, dungeonPopulationObjects{}, seed, 0)
			if err != nil {
				t.Fatal(err)
			}
			engine := gameecs.New()
			session, err := gamesession.New(engine, gamesession.Config{CheckpointInterval: 1})
			if err != nil {
				t.Fatal(err)
			}
			authority, err := StartWithConfig(t.Context(), content.D2Legacy(), records, engine, session, Config{Seed: seed, InitialData: prepared.InitialData("", false)})
			if err != nil {
				t.Fatal(err)
			}
			t.Cleanup(func() { authority.Stop(t.Context()); session.Close(); engine.Close() })
			if err := prepared.InstallCollision(t.Context(), authority.Runtime); err != nil {
				t.Fatal(err)
			}
			command, err := prepared.PopulationCommand(0)
			if err != nil {
				t.Fatal(err)
			}
			if err := session.Submit(command); err != nil {
				t.Fatal(err)
			}
			stepSession(t, session, 1)
			dungeonMap := prepared.Worlds[8]
			area := prepared.PopulationData(0)["additional_zones"].([]any)[0].(map[string]any)
			// Admit one player per chamber to activate every generated room without mutating ECS state.
			for index, value := range area["rooms"].([]any) {
				room := value.(map[string]any)
				points := room["points"].([]any)
				point := points[len(points)-1].(map[string]any)
				var payload map[string]any
				if err := json.Unmarshal(generatedPlayerPayload(t, fmt.Sprintf("hero%d", index), fmt.Sprintf("player%d", index), point["x"].(float64), point["y"].(float64)), &payload); err != nil {
					t.Fatal(err)
				}
				payload["level_id"], payload["world_width"], payload["world_height"] = 8, dungeonMap.WidthSubtiles, dungeonMap.HeightSubtiles
				encoded, err := json.Marshal(payload)
				if err != nil {
					t.Fatal(err)
				}
				if err := session.Submit(simulation.Command{Tick: 2, Player: "system", Authority: simulation.AuthoritySystem, Sequence: uint64(index + 1), Kind: "system.player.enter", Payload: encoded}); err != nil {
					t.Fatal(err)
				}
			}
			stepSession(t, session, 1)
			monsters := dynamicStore(t, engine, "d2legacy.monster.identity")
			positions := dynamicStore(t, engine, "d2legacy.world.position")
			residents := dynamicStore(t, engine, "d2legacy.world.room_resident")
			colliders := dynamicStore(t, engine, "d2legacy.world.collider")
			chambers := map[string]int{}
			used := []gameworld.Point{}
			spawn := prepared.Spawns[8]
			for _, entity := range monsters.Entities() {
				resident, _ := residents.Get(entity)
				level, _ := resident.Get("level_id")
				if level != int64(8) {
					continue
				}
				room, _ := resident.Get("room_id")
				chambers[room.(string)]++
				position, _ := positions.Get(entity)
				x, _ := position.Get("x")
				y, _ := position.Get("y")
				collider, _ := colliders.Get(entity)
				radius, _ := collider.Get("radius")
				point := gameworld.Point{X: x.(float64), Y: y.(float64)}
				if !dungeonMap.WalkableStep(point, point, radius.(float64)) {
					t.Fatalf("monster %d has blocked footprint", entity)
				}
				if _, err := dungeonMap.FindPath(gameworld.PathRequest{Start: gameworld.Point{X: spawn[0], Y: spawn[1]}, Goal: point, Radius: 1}); err != nil {
					t.Fatalf("monster %d is inaccessible: %v", entity, err)
				}
				for _, other := range used {
					if math.Hypot(point.X-other.X, point.Y-other.Y) < 4 {
						t.Fatal("monster pack members overlap")
					}
				}
				used = append(used, point)
			}
			if len(chambers) < 2 {
				t.Fatalf("seed %d: natural encounters occupied only %d chamber(s)", seed, len(chambers))
			}
			t.Logf("%d natural monsters across %d reachable chambers: %v", len(used), len(chambers), chambers)
		})
	}
}
