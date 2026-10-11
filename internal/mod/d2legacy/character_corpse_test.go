package d2legacy

import (
	"encoding/json"
	"path/filepath"
	"testing"

	"github.com/gravestench/dark-magic/internal/content"
	gameecs "github.com/gravestench/dark-magic/internal/game/ecs"
	gamesession "github.com/gravestench/dark-magic/internal/game/session"
	"github.com/gravestench/dark-magic/internal/game/simulation"
	gameworld "github.com/gravestench/dark-magic/internal/game/world"
	playeradapter "github.com/gravestench/dark-magic/internal/mod/d2legacy/adapter/player"
	d2save "github.com/gravestench/dark-magic/internal/mod/d2legacy/adapter/save"
	modruntime "github.com/gravestench/dark-magic/internal/runtime/lua"
)

func TestSavedDeathAndCorpseSurviveProfileAdmissionAndRecoverOnce(t *testing.T) {
	character := d2save.Character{ID: "hero", Name: "Hero", Class: "Amazon", Level: 1, Expansion: true,
		Stats: &d2save.Stats{Dexterity: 20, Vitality: 20, Health: 0, MaxHealth: 50, Mana: 1, MaxMana: 20, Stamina: 1, MaxStamina: 84, Experience: 1000},
		Death: &d2save.Death{}, Inventory: &d2save.Inventory{InventoryWidth: 10, InventoryHeight: 4, StashWidth: 6, StashHeight: 8, CubeWidth: 3, CubeHeight: 4, BeltCapacity: 4, VendorWidth: 10, VendorHeight: 10,
			Corpses: []d2save.Corpse{{ID: "saved-body"}}, Items: []d2save.Item{{ID: "cap", Code: "cap", Container: "corpse", CorpseID: "saved-body", BodySlots: "head", Slot: "head", Width: 2, Height: 2, Defense: 6, Identified: true}}}}
	path := filepath.Join(t.TempDir(), "profile.json")
	for iteration, owner := range []string{"alice", "bob"} {
		engine := gameecs.New()
		session, err := gamesession.New(engine, gamesession.Config{CheckpointInterval: 1})
		if err != nil {
			t.Fatal(err)
		}
		initial := map[string]any{"d2legacy.respawn": map[string]any{"act": 1, "level_id": 1, "x": 10, "y": 12, "width": 100, "height": 80}}
		authority, err := StartWithConfig(t.Context(), content.D2Legacy(), generatedHostileRecords(), engine, session, Config{Seed: 1, InitialData: initial})
		if err != nil {
			t.Fatal(err)
		}
		t.Cleanup(func() { authority.Stop(t.Context()); session.Close(); engine.Close() })
		geometry, err := gameworld.NewOpenMap(100, 80)
		if err != nil {
			t.Fatal(err)
		}
		if err := modruntime.SetWorldMapForLevel(t.Context(), authority.Runtime, "d2legacy.gameplay.systems.init", "set_collision", 1, geometry); err != nil {
			t.Fatal(err)
		}
		destination, err := playeradapter.NewDestination(10, 12, 100, 80, 1, 1)
		if err != nil {
			t.Fatal(err)
		}
		admission, err := playeradapter.AdmissionCommand(character, owner, destination, "system", 1, 1, simulation.AuthoritySystem)
		if err != nil {
			t.Fatal(err)
		}
		if err := session.Submit(admission); err != nil {
			t.Fatal(err)
		}
		stepSession(t, session, 3)
		project := func() (d2save.Character, playeradapter.ClientView) {
			checkpoint, err := session.CanonicalCheckpoint()
			if err != nil {
				t.Fatal(err)
			}
			saved, err := playeradapter.ProjectCharacter(owner, character, checkpoint)
			if err != nil {
				t.Fatal(err)
			}
			payload, err := playeradapter.ProjectClientView(owner, checkpoint)
			if err != nil {
				t.Fatal(err)
			}
			var view playeradapter.ClientView
			if err := json.Unmarshal(payload, &view); err != nil {
				t.Fatal(err)
			}
			if err := playeradapter.ValidateClientView(view, checkpoint.Tick); err != nil {
				t.Fatalf("projected view invalid: %v: %s", err, payload)
			}
			merged, err := playeradapter.MergePrivateCharacter(character, view.HUD, view.Private)
			if err != nil {
				t.Fatal(err)
			}
			if (merged.Death != nil) != (saved.Death != nil) || len(merged.Inventory.Corpses) != len(saved.Inventory.Corpses) {
				t.Fatal("remote save loses death/corpse state")
			}
			foreign, err := playeradapter.ProjectPrivateView("someone-else", checkpoint)
			if err != nil {
				t.Fatal(err)
			}
			if foreign.Death != nil || foreign.Character != nil || len(foreign.Items.Items) != 0 {
				t.Fatal("private corpse data leaked")
			}
			return saved, view
		}
		saved, view := project()
		if saved.Death == nil || view.Private.Death == nil || saved.Stats.Experience != 1000 || len(saved.Inventory.Corpses) != 1 || saved.Inventory.Items[0].CorpseID != "saved-body" {
			t.Fatalf("saved corpse drift: %#v", saved)
		}
		corpseVisible := false
		for _, entity := range view.World.Entities {
			if entity.ID == "player_corpse:saved-body" {
				corpseVisible = true
				if entity.Owner != owner {
					t.Fatal("corpse owner did not rebind")
				}
			}
		}
		if !corpseVisible {
			t.Fatal("saved corpse has no public selectable marker")
		}
		if iteration == 1 {
			submit := func(sequence uint64, kind string, payload any) {
				encoded, err := json.Marshal(payload)
				if err != nil {
					t.Fatal(err)
				}
				if err := session.Submit(simulation.Command{Tick: engine.Tick() + 1, Player: owner, Authority: simulation.AuthorityPlayer, Sequence: sequence, Kind: kind, Payload: encoded}); err != nil {
					t.Fatal(err)
				}
				stepSession(t, session, 2)
			}
			submit(1, "player.continue", map[string]any{"death_tick": view.Private.Death.Tick})
			saved, view = project()
			if saved.Death != nil || view.Private.Death != nil || saved.Stats.Health != 50 || saved.Stats.Mana != 20 || saved.Stats.Stamina != saved.Stats.MaxStamina {
				t.Fatalf("Continue did not clear death and refill resources: stats=%+v death=%+v presentation=%+v", saved.Stats, saved.Death, view.Private.Death)
			}
			submit(2, "player.corpse.recover", map[string]any{"target_id": "player_corpse:saved-body"})
			submit(3, "player.corpse.recover", map[string]any{"target_id": "player_corpse:saved-body"})
			saved, _ = project()
			if len(saved.Inventory.Corpses) != 0 || len(saved.Inventory.Items) != 1 || saved.Inventory.Items[0].Container != "equipment" || saved.Inventory.Items[0].CorpseID != "" {
				t.Fatalf("recovery lost or duplicated gear: %#v", saved.Inventory)
			}
			combat := componentSnapshot(t, engine, playerEntity(t, engine, owner), "d2legacy.player.combat_stats")
			if combat["defense"] != int64(11) {
				t.Fatalf("gear defense not restored once: %v", combat)
			}
		}
		store := d2save.New(saved)
		if err := store.Select(saved.ID); err != nil {
			t.Fatal(err)
		}
		if err := d2save.WriteProfileFile(path, store.Profile()); err != nil {
			t.Fatal(err)
		}
		profile, err := d2save.ReadProfileFile(path)
		if err != nil {
			t.Fatal(err)
		}
		restored, err := d2save.NewFromProfile(profile)
		if err != nil {
			t.Fatal(err)
		}
		character, _ = restored.Selected()
	}
}
