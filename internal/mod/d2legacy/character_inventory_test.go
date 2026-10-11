package d2legacy

import (
	"path/filepath"
	"reflect"
	"sort"
	"testing"

	"github.com/gravestench/dark-magic/internal/content"
	gameecs "github.com/gravestench/dark-magic/internal/game/ecs"
	gamesession "github.com/gravestench/dark-magic/internal/game/session"
	"github.com/gravestench/dark-magic/internal/game/simulation"
	playeradapter "github.com/gravestench/dark-magic/internal/mod/d2legacy/adapter/player"
	d2save "github.com/gravestench/dark-magic/internal/mod/d2legacy/adapter/save"
)

func TestCharacterInventorySurvivesFreshProfileAdmission(t *testing.T) {
	character := d2save.Character{ID: "hero", Name: "Hero", Class: "Amazon", Level: 1, Expansion: true,
		Stats: &d2save.Stats{Dexterity: 20, Vitality: 20, Defense: 7, Health: 50, MaxHealth: 50, Mana: 20, MaxMana: 20, Stamina: 84, MaxStamina: 84},
		Inventory: &d2save.Inventory{InventoryWidth: 10, InventoryHeight: 4, StashWidth: 6, StashHeight: 8, CubeWidth: 3, CubeHeight: 4,
			BeltCapacity: 4, VendorWidth: 10, VendorHeight: 10, CarriedGold: 123, StashedGold: 456, Items: []d2save.Item{
				{ID: "sword", Code: "ssd", ItemTypes: "swor,weap", Width: 1, Height: 3, BodySlots: "rarm,larm", Container: "inventory", X: 2, Y: 1,
					Identified: true, PhysicalMin: 512, PhysicalMax: 1024, MeleeRange: 2,
					Generation: &d2save.ItemGeneration{Quality: "normal", Level: 3, Facts: `{"code":"ssd"}`}},
				{ID: "armor", Code: "qui", ItemTypes: "tors", Width: 2, Height: 3, BodySlots: "tors", Container: "equipment", Slot: "tors", Identified: true,
					Defense: 9, StatModifiers: []d2save.ItemModifier{{SourceID: "fixture", SourceKind: "item", Stat: "defense", Operation: "add", Value: 2, Order: 1}}},
			}},
		Progression: &d2save.Progression{UnspentSkillPoints: 3, HighestCompletedDifficulty: -1, LeftSkill: 0, RightSkill: 0,
			Skills: []d2save.LearnedSkill{{SkillID: 0, Level: 2}}, Quest: &d2save.Quest{QuestID: 1, Stage: 3, Completed: true, Rewarded: true}},
	}
	records := generatedHostileRecords()
	records["data/global/excel/skills.txt"] = []map[string]string{{"Id": "0", "skill": "Attack", "general": "1", "leftskill": "1", "skilldesc": "attack",
		"srvstfunc": "1", "srvdofunc": "1", "cltstfunc": "1", "cltdofunc": "1", "range": "both", "itypea1": "weap", "anim": "A1", "UseAttackRate": "1", "TargetableOnly": "1", "SearchEnemyXY": "1", "AttackNoMana": "1", "interrupt": "1", "InGame": "1", "mana": "0", "minmana": "0", "SrcDam": "128"}}
	records["data/global/excel/skilldesc.txt"] = []map[string]string{{"skilldesc": "attack", "ListRow": "0", "IconCel": "0"}}
	sort.Slice(character.Inventory.Items, func(i, j int) bool { return character.Inventory.Items[i].ID < character.Inventory.Items[j].ID })
	path := filepath.Join(t.TempDir(), "profile.json")
	for _, owner := range []string{"alice", "bob", "alice"} {
		engine := gameecs.New()
		session, err := gamesession.New(engine, gamesession.Config{CheckpointInterval: 1})
		if err != nil {
			t.Fatal(err)
		}
		authority, err := StartWithConfig(t.Context(), content.D2Legacy(), records, engine, session, Config{Seed: 1})
		if err != nil {
			t.Fatal(err)
		}
		t.Cleanup(func() { authority.Stop(t.Context()); session.Close(); engine.Close() })
		destination, err := playeradapter.NewDestination(1, 1, 100, 100, 1, 2)
		if err != nil {
			t.Fatal(err)
		}
		command, err := playeradapter.AdmissionCommand(character, owner, destination, "system", 1, 1, simulation.AuthoritySystem)
		if err != nil {
			t.Fatal(err)
		}
		if err := session.Submit(command); err != nil {
			t.Fatal(err)
		}
		stepSession(t, session, 3)
		checkpoint, err := session.CanonicalCheckpoint()
		if err != nil {
			t.Fatal(err)
		}
		result, err := playeradapter.ProjectCharacter(owner, character, checkpoint)
		if err != nil {
			t.Fatal(err)
		}
		if !reflect.DeepEqual(result.Inventory, character.Inventory) {
			t.Fatalf("owner %s inventory drift:\ngot %#v\nwant %#v", owner, result.Inventory, character.Inventory)
		}
		if !reflect.DeepEqual(result.Progression, character.Progression) {
			t.Fatalf("owner %s progression drift: got %#v want %#v", owner, result.Progression, character.Progression)
		}
		if result.Stats.Defense != 7 {
			t.Fatalf("base defense inflated on reload: %d", result.Stats.Defense)
		}
		combat := componentSnapshot(t, engine, playerEntity(t, engine, owner), "d2legacy.player.combat_stats")
		if combat["defense"] != int64(23) {
			t.Fatalf("equipment defense did not reactivate once: %v", combat)
		}
		foreign, err := playeradapter.ProjectPrivateView("someone-else", checkpoint)
		if err != nil {
			t.Fatal(err)
		}
		if len(foreign.Items.Items) != 0 {
			t.Fatal("fresh admission exposed possessions to another owner")
		}
		store := d2save.New(result)
		if err := store.Select(result.ID); err != nil {
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
