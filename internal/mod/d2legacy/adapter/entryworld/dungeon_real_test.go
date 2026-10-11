package entryworld

import (
	"os"
	"testing"

	"github.com/gravestench/dark-magic/internal/content"
	recordstore "github.com/gravestench/dark-magic/internal/game/data/store"
	gameworld "github.com/gravestench/dark-magic/internal/game/world"
)

type dungeonTestObjects struct{}

func (dungeonTestObjects) ResolveStaticObject(int, int) (int, string, bool) { return 0, "", false }
func (dungeonTestObjects) ResolveDynamicObject(int, int) (string, bool)     { return "", false }

func TestDungeonAuthoredChambersAreReachable(t *testing.T) {
	directory := os.Getenv("DARK_MAGIC_TEST_MPQ_DIRECTORY")
	if directory == "" {
		t.Skip("set DARK_MAGIC_TEST_MPQ_DIRECTORY to an owned Diablo II MPQ directory")
	}
	t.Setenv("MPQ_DIRECTORY", directory)
	source, err := content.FromEnvironment(content.Layer{Name: "d2legacy", FS: content.D2Legacy()})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		if err := source.Close(); err != nil {
			t.Error(err)
		}
	})
	records := recordstore.New(source)
	for _, seed := range []uint64{1, 17, 42} {
		prepared, err := Build(t.Context(), source, content.D2Legacy(), records, dungeonTestObjects{}, seed, 0)
		if err != nil {
			t.Fatalf("seed %d: %v", seed, err)
		}
		if len(prepared.AdditionalSeams) != 1 {
			t.Fatal("missing dungeon connection")
		}
		dungeon := prepared.AdditionalSeams[0].Wilderness
		gameMap := prepared.Worlds[dungeon.LevelID]
		start := gameworld.Point{X: dungeon.ArrivalX, Y: dungeon.ArrivalY}
		for _, room := range prepared.Zones[dungeon.LevelID].Rooms() {
			x, y, found := gameMap.OpenPointNearSubtileForRadius(float64((room.X+room.Width/2)*gameworld.SubtilesPerTile), float64((room.Y+room.Height/2)*gameworld.SubtilesPerTile), 1)
			if !found {
				t.Fatalf("seed %d room %d has no open center", seed, room.ID)
			}
			if _, err := gameMap.FindPath(gameworld.PathRequest{Start: start, Goal: gameworld.Point{X: x, Y: y}, Radius: 1, StopRadius: 20}); err != nil {
				t.Fatalf("seed %d room %d is disconnected from entrance: %v", seed, room.ID, err)
			}
		}
		t.Logf("seed %d: %d cave chambers reachable at player radius", seed, len(prepared.Zones[dungeon.LevelID].Rooms()))
	}
}
