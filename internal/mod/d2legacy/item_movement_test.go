package d2legacy

import (
	"testing"

	"github.com/gravestench/dark-magic/internal/content"
	gameecs "github.com/gravestench/dark-magic/internal/game/ecs"
	gamesession "github.com/gravestench/dark-magic/internal/game/session"
)

func TestItemMoveInvalidDropPreservesItemsAndSession(t *testing.T) {
	for _, tc := range []struct {
		name        string
		destination map[string]any
		placeHeld   bool
	}{
		{"sword in head slot", map[string]any{"container": "equipment", "slot": "head"}, true},
		{"outside grid", map[string]any{"container": "inventory", "x": -1, "y": 0}, true},
		{"footprint beyond grid", map[string]any{"container": "inventory", "x": 0, "y": 3}, true},
		{"two overlapping items", map[string]any{"container": "inventory", "x": 1, "y": 1}, true},
		{"occupied slot without swap", map[string]any{"container": "equipment", "slot": "rarm"}, false},
		{"invalid weapon set", map[string]any{"container": "equipment", "slot": "rarm", "weapon_set": 2}, true},
		{"sword in belt", map[string]any{"container": "belt", "belt_slot": 0}, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			engine := gameecs.New()
			t.Cleanup(func() { _ = engine.Close() })
			session, err := gamesession.New(engine, gamesession.Config{})
			if err != nil {
				t.Fatal(err)
			}
			t.Cleanup(func() { _ = session.Close() })
			authority, err := StartWithConfig(t.Context(), content.D2Legacy(), fixtureRecords{}, engine, session,
				Config{Seed: 91, InitialData: map[string]any{"d2legacy.items": map[string]any{
					"owner": "alice", "inventory_width": 4.0, "inventory_height": 4.0, "belt_capacity": 4.0,
					"items": []any{
						map[string]any{"id": "sword", "code": "ssd", "width": 1.0, "height": 3.0,
							"body_slots": "rarm,larm", "container": "held"},
						map[string]any{"id": "a", "code": "cap", "width": 1.0, "height": 1.0,
							"container": "inventory", "x": 1.0, "y": 1.0},
						map[string]any{"id": "b", "code": "cap", "width": 1.0, "height": 1.0,
							"container": "inventory", "x": 1.0, "y": 2.0},
						map[string]any{"id": "equipped", "code": "ssd", "width": 1.0, "height": 3.0,
							"body_slots": "rarm,larm", "container": "equipment", "slot": "rarm"},
					},
				}}})
			if err != nil {
				t.Fatal(err)
			}
			t.Cleanup(func() { _ = authority.Stop(t.Context()) })
			if err := session.Submit(itemCommand(t, 1, 1, "item.move", map[string]any{
				"item_id": "sword", "place_held": tc.placeHeld, "destination": tc.destination,
			})); err != nil {
				t.Fatal(err)
			}
			if err := session.Step(); err != nil {
				t.Fatalf("invalid drop stopped session: %v", err)
			}
			assertItemPlacement(t, engine, "sword", "held", "")
			assertItemPlacement(t, engine, "a", "inventory", "")
			assertItemPlacement(t, engine, "b", "inventory", "")
			assertItemPlacement(t, engine, "equipped", "equipment", "rarm")
			if err := session.Submit(itemCommand(t, 2, 2, "item.move", map[string]any{
				"item_id": "sword", "place_held": true,
				"destination": map[string]any{"container": "equipment", "slot": "rarm"},
			})); err != nil {
				t.Fatal(err)
			}
			if err := session.Submit(itemCommand(t, 2, 3, "item.move", map[string]any{
				"item_id": "sword", "place_held": true,
				"destination": map[string]any{"container": "equipment", "slot": "larm"},
			})); err != nil {
				t.Fatal(err)
			}
			if err := session.Step(); err != nil {
				t.Fatalf("valid equip after invalid drop: %v", err)
			}
			assertItemPlacement(t, engine, "sword", "equipment", "rarm")
			assertItemPlacement(t, engine, "equipped", "held", "")
		})
	}
}
