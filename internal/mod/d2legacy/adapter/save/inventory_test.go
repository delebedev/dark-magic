package save

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
)

func TestPortableStateIsClonedAndRejectedBeforeProfileReplacement(t *testing.T) {
	character := Character{ID: "hero", Inventory: &Inventory{InventoryWidth: 10, InventoryHeight: 4,
		Items: []Item{{ID: "sword", Code: "ssd", Container: "inventory", Width: 1, Height: 3,
			Generation:    &ItemGeneration{Quality: "normal", Level: 1, Facts: "{}"},
			StatModifiers: []ItemModifier{{SourceID: "one", SourceKind: "item", Stat: "defense", Operation: "add", Value: 1}}}}},
		Progression: &Progression{HighestCompletedDifficulty: -1, Skills: []LearnedSkill{{SkillID: 0, Level: 1}},
			Quest: &Quest{QuestID: 1, Stage: 1}},
	}
	store := New(character)
	if err := store.Select(character.ID); err != nil {
		t.Fatal(err)
	}
	copy, _ := store.Selected()
	copy.Inventory.Items[0].Generation.Facts = "mutated"
	copy.Inventory.Items[0].StatModifiers[0].Value = 9
	copy.Progression.Skills[0].Level = 9
	copy.Progression.Quest.Completed = true
	again, _ := store.Selected()
	if again.Inventory.Items[0].Generation.Facts != "{}" || again.Inventory.Items[0].StatModifiers[0].Value != 1 ||
		again.Progression.Skills[0].Level != 1 || again.Progression.Quest.Completed {
		t.Fatal("portable state aliases store")
	}
	path := filepath.Join(t.TempDir(), "profile.json")
	if err := WriteProfileFile(path, store.Profile()); err != nil {
		t.Fatal(err)
	}
	before, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	cases := map[string]func(*Character){
		"world loot":               func(c *Character) { c.Inventory.Items[0].Container = "world" },
		"duplicate item":           func(c *Character) { c.Inventory.Items = append(c.Inventory.Items, c.Inventory.Items[0]) },
		"outside grid":             func(c *Character) { c.Inventory.Items[0].X = 10 },
		"oversize layout":          func(c *Character) { c.Inventory.InventoryWidth = 100 },
		"unknown selected skill":   func(c *Character) { c.Progression.LeftSkill = 7 },
		"reward before completion": func(c *Character) { c.Progression.Quest.Rewarded = true },
		"overlapping items": func(c *Character) {
			item := c.Inventory.Items[0]
			item.ID = "other"
			c.Inventory.Items = append(c.Inventory.Items, item)
		},
		"illegal body slot": func(c *Character) {
			c.Inventory.Items[0].Container, c.Inventory.Items[0].Slot = "equipment", "tors"
		},
		"oversize authority number": func(c *Character) { c.Inventory.Items[0].AttackRating = 1 << 32 },
		"unsupported modifier": func(c *Character) {
			c.Inventory.Items[0].StatModifiers[0].Operation = "bogus"
		},
	}
	for name, mutate := range cases {
		t.Run(name, func(t *testing.T) {
			c, _ := store.Selected()
			mutate(&c)
			profile := Profile{Version: ProfileVersion, Selected: c.ID, Characters: []Character{c}}
			if err := WriteProfileFile(path, profile); err == nil {
				t.Fatal("invalid portable state was persisted")
			}
			after, err := os.ReadFile(path)
			if err != nil {
				t.Fatal(err)
			}
			if !bytes.Equal(before, after) {
				t.Fatal("failed save changed existing profile")
			}
			if _, err := EncodeCharacterOffer(c); err == nil {
				t.Fatal("invalid portable state was offered")
			}
		})
	}
}
