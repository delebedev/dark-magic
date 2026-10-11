package clientapp

import (
	"github.com/gravestench/akara"
	gameecs "github.com/gravestench/dark-magic/internal/game/ecs"
	playeradapter "github.com/gravestench/dark-magic/internal/mod/d2legacy/adapter/player"
	"testing"
)

func TestConnectedDeathCorrectionClearsWithoutDestroyingHero(t *testing.T) {
	engine := gameecs.New()
	defer engine.Close()
	registerRemoteViewSchemas(t, engine)
	app := &application{clientSimulation: engine}
	connected := connectedProjectionFixture()
	connected.Private.Death = &playeradapter.DeathView{Tick: 1, Stage: "dead"}
	connected.HUD.Vitals.Health = 0
	if err := app.installRemoteProjection(connected.HUD, connected.Private, connected.Party, true); err != nil {
		t.Fatal(err)
	}
	deaths, _ := akara.GetDynamicStore(engine.World(), "d2legacy.player.death")
	if deaths.Len() != 1 {
		t.Fatal("owner death was not mirrored")
	}
	hero := deaths.Entities()[0]
	connected.Private.Death = nil
	connected.Private.Tick++
	connected.HUD.Tick++
	connected.HUD.Vitals.Health = 10
	if err := app.installRemoteProjection(connected.HUD, connected.Private, connected.Party, true); err != nil {
		t.Fatal(err)
	}
	if deaths.Len() != 0 {
		t.Fatal("canonical alive correction retained death")
	}
	identities, _ := akara.GetDynamicStore(engine.World(), "d2legacy.player.identity")
	if _, ok := identities.Get(hero); !ok {
		t.Fatal("death correction destroyed hero")
	}
	corpse, err := engine.World().CreateEntity()
	if err != nil {
		t.Fatal(err)
	}
	if err := installWorldMirror(engine.World(), corpse, playeradapter.WorldEntity{ID: "player_corpse:body", Kind: "player_corpse", Owner: "player-2", Label: "Hero", Radius: 3.5}, playeradapter.HUDLocation{Act: 1, LevelID: 1}, true); err != nil {
		t.Fatal(err)
	}
	if _, ok := identities.Get(corpse); ok {
		t.Fatal("corpse masquerades as controlled player")
	}
	monsters, _ := akara.GetDynamicStore(engine.World(), "d2legacy.monster.identity")
	if _, ok := monsters.Get(corpse); ok {
		t.Fatal("corpse masquerades as monster")
	}
}
