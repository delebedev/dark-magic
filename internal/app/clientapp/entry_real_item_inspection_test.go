package clientapp

import (
	"encoding/json"
	"math"
	"reflect"
	"testing"

	"github.com/gravestench/akara"
	"github.com/gravestench/dark-magic/internal/content"
	gameecs "github.com/gravestench/dark-magic/internal/game/ecs"
	playeradapter "github.com/gravestench/dark-magic/internal/mod/d2legacy/adapter/player"
	modruntime "github.com/gravestench/dark-magic/internal/runtime/lua"
)

func TestGameWorldItemInspectionMatchesConnectedProjection(t *testing.T) {
	fixture := newRealD2LegacyFixture(t, realD2LegacyFixtureConfig{startScene: "game_world", fixtureCharacters: 1})
	app := fixture.app
	if err := app.network.StartSelected(); err != nil {
		t.Fatal(err)
	}
	fixture.advanceGame(t, 3)
	engine := gameecs.New()
	t.Cleanup(func() { engine.Close() })
	registerRemoteViewSchemas(t, engine)
	runtime := modruntime.New()
	if err := runtime.RegisterInstaller(modruntime.ContentRequire(content.D2Legacy(), "lua")); err != nil {
		t.Fatal(err)
	}
	if err := runtime.RegisterModule(modruntime.NewECSCapability(runtime, engine).Module()); err != nil {
		t.Fatal(err)
	}
	if err := runtime.Start(t.Context()); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { runtime.Stop(t.Context()) })
	inspect := func(runtime *modruntime.Runtime, id string) playeradapter.ItemInspectionView {
		t.Helper()
		value, err := modruntime.Call(t.Context(), runtime, "d2legacy.items.snapshot", "inspect", id)
		if err != nil {
			t.Fatal(err)
		}
		encoded, err := json.Marshal(value)
		if err != nil {
			t.Fatal(err)
		}
		var result playeradapter.ItemInspectionView
		if err := json.Unmarshal(encoded, &result); err != nil {
			t.Fatal(err)
		}
		return result
	}
	checkpoint, err := app.offlineSession.CanonicalCheckpoint()
	if err != nil {
		t.Fatal(err)
	}
	private, err := playeradapter.ProjectPrivateView("local-player", checkpoint)
	if err != nil {
		t.Fatal(err)
	}
	layout, err := installPrivateItemLayout(engine.World(), "local-player", private.Items.Layout)
	if err != nil {
		t.Fatal(err)
	}
	if err := installPrivateItems(engine.World(), layout, private.Items.Items); err != nil {
		t.Fatal(err)
	}
	for _, item := range private.Items.Items {
		local := inspect(app.scripts, item.ID)
		connected := inspect(runtime, item.ID)
		if !reflect.DeepEqual(local, connected) || item.Inspection == nil || !reflect.DeepEqual(local, *item.Inspection) {
			t.Fatalf("item=%s local=%+v connected=%+v wire=%+v", item.ID, local, connected, item.Inspection)
		}
	}
	identities := requireRealStore(t, fixture, "d2legacy.player.identity", "no player")
	positions := requireRealStore(t, fixture, "d2legacy.world.position", "no positions")
	x, y := dynamicPosition(positions, identities.Entities()[0])
	if err := app.commandIntents.Submit("item.move", map[string]any{"item_id": "fixture-short-sword", "destination": map[string]any{"container": "world", "x": math.Floor(x), "y": math.Floor(y)}}); err != nil {
		t.Fatal(err)
	}
	fixture.advanceGame(t, 2)
	checkpoint, err = app.offlineSession.CanonicalCheckpoint()
	if err != nil {
		t.Fatal(err)
	}
	payload, err := playeradapter.ProjectWorldView("local-player", checkpoint)
	if err != nil {
		t.Fatal(err)
	}
	var world playeradapter.WorldView
	if err := json.Unmarshal(payload, &world); err != nil {
		t.Fatal(err)
	}
	remote := &application{clientSimulation: engine}
	var ground playeradapter.WorldEntity
	for _, entity := range world.Entities {
		if entity.Kind == "item" {
			ground = entity
			break
		}
	}
	if ground.ID == "" {
		t.Fatal("ordinary drop did not produce public ground item")
	}
	if err := remote.syncRemoteMirrors([]playeradapter.WorldEntity{ground}, playeradapter.HUDLocation{Act: 1, LevelID: 1}); err != nil {
		t.Fatal(err)
	}
	local, connected := inspect(app.scripts, ground.ID), inspect(runtime, ground.ID)
	if !reflect.DeepEqual(local, connected) || local.Damage == nil {
		t.Fatalf("ground local=%+v connected=%+v", local, connected)
	}
	store, _ := akara.GetDynamicStore(engine.World(), "d2legacy.item.identity")
	if _, found := store.Get(remote.remoteMirrors[ground.ID]); found {
		t.Fatal("inspection exposed private ground authority")
	}
}
