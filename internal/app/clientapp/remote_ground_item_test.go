package clientapp

import (
	"testing"

	"github.com/gravestench/akara"
	gameecs "github.com/gravestench/dark-magic/internal/game/ecs"
	playeradapter "github.com/gravestench/dark-magic/internal/mod/d2legacy/adapter/player"
)

func TestRemoteGroundItemHasArtAndSelectionWithoutMonsterAuthority(t *testing.T) {
	engine := gameecs.New()

	t.Cleanup(func() { _ = engine.Close() })
	registerRemoteViewSchemas(t, engine)
	app := &application{clientSimulation: engine}
	location := playeradapter.HUDLocation{Act: 1, LevelID: 8}

	item := playeradapter.WorldEntity{ID: "item:alice:sword", Kind: "item", Label: "Short Sword",
		Position: playeradapter.HUDPosition{X: 12, Y: 14}, Radius: 3.5, Priority: 15,
		WorldDC6: "data/global/items/flpssd.dc6", WorldAnimated: true}
	if err := app.syncRemoteMirrors([]playeradapter.WorldEntity{item}, location); err != nil {
		t.Fatal(err)
	}

	entity := app.remoteMirrors[item.ID]
	presentation, _ := akara.GetDynamicStore(engine.World(), "d2legacy.item.presentation")

	value, found := presentation.Get(entity)
	if !found {
		t.Fatal("ground item presentation missing")
	}

	path, _ := value.Get("world_dc6")
	if path != item.WorldDC6 {
		t.Fatalf("ground art=%v", path)
	}

	for _, name := range []string{"d2legacy.monster.identity", "d2legacy.world.collider", "d2legacy.item.identity"} {
		store, _ := akara.GetDynamicStore(engine.World(), name)
		if _, found := store.Get(entity); found {
			t.Fatalf("public ground item gained private authority: %s", name)
		}
	}

	if err := app.syncRemoteMirrors(nil, location); err != nil {
		t.Fatal(err)
	}

	if len(app.remoteMirrors) != 0 || presentation.Len() != 0 {
		t.Fatal("picked-up item left a stale ground mirror")
	}
}
