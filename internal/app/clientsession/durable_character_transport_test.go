package clientsession

import (
	"context"
	"reflect"
	"testing"
	"time"

	playeradapter "github.com/gravestench/dark-magic/internal/mod/d2legacy/adapter/player"
	d2save "github.com/gravestench/dark-magic/internal/mod/d2legacy/adapter/save"
)

func TestSelfHostedPrivateCharacterSurvivesDisconnectAndFreshAdmission(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	fixture := newLiveGameworldFixture(t, ctx)
	first := durableTransportCharacter("hero", 7, 9, 2, 3, true)
	second := durableTransportCharacter("peer", 17, 19, 6, 8, false)
	connected := connectLiveCharacter(t, ctx, fixture, first)
	peer := connectLiveCharacter(t, ctx, fixture, second)
	if _, err := connected.Refresh(ctx); err != nil {
		t.Fatal(err)
	}
	if _, err := peer.Refresh(ctx); err != nil {
		t.Fatal(err)
	}
	assertDurableTransportOwner(t, connected, first)
	assertDurableTransportOwner(t, peer, second)

	detached := connected.PrivateView().Character
	detached.Inventory.Items[0].Generation.Facts = "corrupted"
	detached.Inventory.Items[0].StatModifiers[0].Value = 999
	detached.Progression.Skills[0].Level = 99
	detached.Progression.Quest.Rewarded = false
	*detached.DefenseBeforeEquipment = 999
	*detached.Vitality = 999
	assertDurableTransportOwner(t, connected, first)
	assertDurableTransportOwner(t, peer, second)

	if _, err := connected.Refresh(ctx); err != nil {
		t.Fatal(err)
	}
	hud, _ := connected.View()
	merged, err := playeradapter.MergePrivateCharacter(first, hud, connected.PrivateView())
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(merged.Inventory, first.Inventory) || !reflect.DeepEqual(merged.Progression, first.Progression) {
		t.Fatalf("disconnect discarded possessions/reward: inventory=%#v progression=%#v", merged.Inventory, merged.Progression)
	}
	if merged.Stats.Defense != 7 || merged.Stats.Vitality != 20 {
		t.Fatalf("disconnect persisted derived stats: %#v", merged.Stats)
	}
	if err := connected.Close(ctx); err != nil {
		t.Fatal(err)
	}
	// A fresh host proves the merged character needs no previous ECS allocation or admission owner.
	nextFixture := newLiveGameworldFixture(t, ctx)
	next := connectLiveCharacter(t, ctx, nextFixture, merged)
	assertDurableTransportOwner(t, next, first)
	ticker := time.NewTicker(600 * time.Millisecond)
	defer ticker.Stop()
	for {
		if _, err := next.Refresh(ctx); err != nil {
			t.Fatal(err)
		}
		nextHUD, _ := next.View()
		if nextHUD.Combat.Defense == 23 {
			break
		}
		select {
		case <-ticker.C:
		case <-ctx.Done():
			t.Fatalf("fresh admission applied armor twice or lost it: defense=%d", nextHUD.Combat.Defense)
		}
	}
	assertDurableTransportOwner(t, next, first)
}

func durableTransportCharacter(id string, baseDefense, armorDefense, modifier, points int64, rewarded bool) d2save.Character {
	return d2save.Character{ID: id, Name: id, Class: "Amazon", Level: 1, Expansion: true,
		Stats: &d2save.Stats{Dexterity: 20, Vitality: 20, Defense: int(baseDefense), Health: 50, MaxHealth: 50, Mana: 20, MaxMana: 20, Stamina: 84, MaxStamina: 84},
		Inventory: &d2save.Inventory{InventoryWidth: 10, InventoryHeight: 4, StashWidth: 6, StashHeight: 8, CubeWidth: 3, CubeHeight: 4, BeltCapacity: 4, VendorWidth: 10, VendorHeight: 10, CarriedGold: 123, Items: []d2save.Item{{
			ID: id + "-armor", Code: "qui", ItemTypes: "tors", BodySlots: "tors", Width: 2, Height: 3, Container: "equipment", Slot: "tors", Identified: true, Defense: armorDefense,
			Generation:    &d2save.ItemGeneration{Quality: "magic", Level: 3, Facts: `{"code":"qui","source":"saved"}`},
			StatModifiers: []d2save.ItemModifier{{SourceID: id + "-defense", SourceKind: "item", Stat: "defense", Operation: "add", Value: modifier, Order: 1}},
		}}},
		Progression: &d2save.Progression{UnspentSkillPoints: points, HighestCompletedDifficulty: -1, LeftSkill: 36, RightSkill: 36,
			Skills: []d2save.LearnedSkill{{SkillID: 36, Level: 2}}, Quest: &d2save.Quest{QuestID: 1, Stage: 3, Completed: rewarded, Rewarded: rewarded}},
	}
}

func assertDurableTransportOwner(t *testing.T, connected *Session, expected d2save.Character) {
	t.Helper()
	private := connected.PrivateView()
	state := private.Character
	if state == nil || state.Inventory == nil || state.Progression == nil {
		t.Fatalf("missing connected character: %#v", private)
	}
	if !reflect.DeepEqual(state.Inventory, expected.Inventory) {
		t.Fatalf("owner inventory drift/leak: got %#v want %#v", state.Inventory, expected.Inventory)
	}
	if !reflect.DeepEqual(state.Progression, expected.Progression) {
		t.Fatalf("owner progression drift/leak: got %#v want %#v", state.Progression, expected.Progression)
	}
	if state.DefenseBeforeEquipment == nil || *state.DefenseBeforeEquipment != int64(expected.Stats.Defense+expected.Stats.Dexterity/4) {
		t.Fatalf("base defense=%v", state.DefenseBeforeEquipment)
	}
	if state.Vitality == nil || *state.Vitality != int64(expected.Stats.Vitality) {
		t.Fatalf("base vitality=%v", state.Vitality)
	}
}
