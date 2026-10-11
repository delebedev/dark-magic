package clientapp

import (
	"github.com/gravestench/akara"
	gameecs "github.com/gravestench/dark-magic/internal/game/ecs"
	playeradapter "github.com/gravestench/dark-magic/internal/mod/d2legacy/adapter/player"
	"testing"
)

func TestConnectedQuestProjectionReplacesOnlyOwnerProgress(t *testing.T) {
	engine := gameecs.New()
	defer engine.Close()
	registerRemoteViewSchemas(t, engine)
	app := &application{clientSimulation: engine}
	connected := connectedProjectionFixture()
	connected.Private.Quest = &playeradapter.QuestView{QuestID: 1, Stage: 3, Completed: true}
	if err := app.installRemoteProjection(connected.HUD, connected.Private, connected.Party, true); err != nil {
		t.Fatal(err)
	}
	quests, _ := akara.GetDynamicStore(engine.World(), "d2legacy.quest.progress")
	if quests.Len() != 1 {
		t.Fatalf("quest count=%d", quests.Len())
	}
	identities, _ := akara.GetDynamicStore(engine.World(), "d2legacy.player.identity")
	owner := quests.Entities()[0]
	identity, _ := identities.Get(owner)
	id, _ := identity.Get("player")
	if id != "player-2" {
		t.Fatalf("quest attached to %v", id)
	}
	connected.Private.Quest.Rewarded = true
	connected.Private.Tick++
	connected.HUD.Tick++
	if err := app.installRemoteProjection(connected.HUD, connected.Private, connected.Party, true); err != nil {
		t.Fatal(err)
	}
	quest, _ := quests.Get(owner)
	rewarded, _ := quest.Get("rewarded")
	if rewarded != true {
		t.Fatal("quest correction was not installed")
	}
	connected.Private.Quest = nil
	connected.Private.Tick++
	connected.HUD.Tick++
	if err := app.installRemoteProjection(connected.HUD, connected.Private, connected.Party, true); err != nil {
		t.Fatal(err)
	}
	if quests.Len() != 0 {
		t.Fatal("removed quest remained in presentation")
	}
	if _, ok := identities.Get(owner); !ok {
		t.Fatal("quest replacement destroyed hero")
	}
}
