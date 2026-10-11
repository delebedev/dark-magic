package d2legacy

import (
	"encoding/json"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"reflect"
	"testing"

	"github.com/gravestench/akara"
	"github.com/gravestench/dark-magic/internal/content"
	recordstore "github.com/gravestench/dark-magic/internal/game/data/store"
	gameecs "github.com/gravestench/dark-magic/internal/game/ecs"
	gamesession "github.com/gravestench/dark-magic/internal/game/session"
	"github.com/gravestench/dark-magic/internal/game/simulation"
	gameworld "github.com/gravestench/dark-magic/internal/game/world"
	entryworld "github.com/gravestench/dark-magic/internal/mod/d2legacy/adapter/entryworld"
	playeradapter "github.com/gravestench/dark-magic/internal/mod/d2legacy/adapter/player"
	d2save "github.com/gravestench/dark-magic/internal/mod/d2legacy/adapter/save"
)

func TestNaturalCombatLootPickupSurvivesFreshAdmission(t *testing.T) {
	for _, seed := range []uint64{10, 8} {
		t.Run(fmt.Sprint(seed), func(t *testing.T) { proveNaturalLootAdmission(t, seed) })
	}
}

func proveNaturalLootAdmission(t *testing.T, seed uint64) {
	t.Helper()
	directory := os.Getenv("DARK_MAGIC_TEST_MPQ_DIRECTORY")
	if directory == "" {
		t.Skip("set DARK_MAGIC_TEST_MPQ_DIRECTORY to owned Diablo II assets")
	}
	t.Setenv("MPQ_DIRECTORY", directory)
	source, err := content.FromEnvironment(content.Layer{Name: "d2legacy", FS: content.D2Legacy()})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { source.Close() })
	records := recordstore.New(source)
	ratioRows, err := records.Load("data/global/excel/itemratio.txt")
	if err != nil {
		t.Fatal(err)
	}
	t.Logf("real ItemRatio rows: %v", ratioRows)
	// Map seed 1 retains the production entry recipe. Authority seeds select junk and implicit equipment TCs.
	prepared, err := entryworld.Build(t.Context(), source, content.D2Legacy(), records, dungeonPopulationObjects{}, 1, 0)
	if err != nil {
		t.Fatal(err)
	}
	character := d2save.Character{ID: "hero", Name: "Hero", Class: "Amazon", Level: 1, Expansion: true,
		Stats: &d2save.Stats{Dexterity: 20, Vitality: 20, Health: 50, MaxHealth: 50, Mana: 20, MaxMana: 20, Stamina: 84, MaxStamina: 84}}
	start := func(character d2save.Character, owner string) (*gameecs.Engine, *gamesession.Session) {
		engine := gameecs.New()
		session, err := gamesession.New(engine, gamesession.Config{CheckpointInterval: 1})
		if err != nil {
			t.Fatal(err)
		}
		authority, err := StartWithConfig(t.Context(), content.D2Legacy(), records, engine, session, Config{Seed: seed, InitialData: prepared.InitialData("", false)})
		if err != nil {
			t.Fatal(err)
		}
		t.Cleanup(func() { authority.Stop(t.Context()); session.Close(); engine.Close() })
		if err := prepared.InstallCollision(t.Context(), authority.Runtime); err != nil {
			t.Fatal(err)
		}
		population, err := prepared.PopulationCommand(0)
		if err != nil {
			t.Fatal(err)
		}
		if err := session.Submit(population); err != nil {
			t.Fatal(err)
		}
		destination, err := prepared.Destination(2)
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
		return engine, session
	}
	engine, session := start(character, "alice")
	hero := playerEntity(t, engine, "alice")
	positions := dynamicStore(t, engine, "d2legacy.world.position")
	position := func(entity akara.Entity) gameworld.Point {
		component, ok := positions.Get(entity)
		if !ok {
			t.Fatalf("entity %d has no position", entity)
		}
		x, _ := component.Get("x")
		y, _ := component.Get("y")
		return gameworld.Point{X: x.(float64), Y: y.(float64)}
	}
	sequence := uint64(0)
	submit := func(kind string, payload any) {
		sequence++
		encoded, err := json.Marshal(payload)
		if err != nil {
			t.Fatal(err)
		}
		if err := session.Submit(simulation.Command{Tick: engine.Tick() + 1, Player: "alice", Authority: simulation.AuthorityPlayer, Sequence: sequence, Kind: kind, Payload: encoded}); err != nil {
			t.Fatal(err)
		}
	}
	walk := func(goal gameworld.Point, stop float64) {
		path, err := prepared.Worlds[2].FindPath(gameworld.PathRequest{Start: position(hero), Goal: goal, Radius: 1, StopRadius: stop})
		if err != nil {
			t.Fatal(err)
		}
		for _, point := range path {
			submit("player.move", map[string]any{"x": 0, "y": 0, "running": false, "target": map[string]any{"x": point.X, "y": point.Y}})
			reached := false
			for range 30 {
				stepSession(t, session, 1)
				current := position(hero)
				if math.Hypot(current.X-point.X, current.Y-point.Y) < 0.6 {
					reached = true
					break
				}
			}
			if !reached {
				t.Fatalf("ordinary movement stalled: at %v goal %v", position(hero), point)
			}
		}
		current := position(hero)
		submit("player.move", map[string]any{"x": 0, "y": 0, "running": false, "target": map[string]any{"x": current.X, "y": current.Y}})
		stepSession(t, session, 1)
	}
	monsters := dynamicStore(t, engine, "d2legacy.monster.identity")
	inactive := dynamicStore(t, engine, "d2legacy.world.inactive")
	locations := dynamicStore(t, engine, "d2legacy.world.location")
	var monster akara.Entity
	shortest := math.Inf(1)
	for _, entity := range monsters.Entities() {
		if _, hidden := inactive.Get(entity); hidden {
			continue
		}
		location, ok := locations.Get(entity)
		if !ok {
			continue
		}
		level, _ := location.Get("level_id")
		if level != int64(2) {
			continue
		}
		path, err := prepared.Worlds[2].FindPath(gameworld.PathRequest{Start: position(hero), Goal: position(entity), Radius: 1, StopRadius: 1.5})
		if err == nil && float64(len(path)) < shortest {
			monster, shortest = entity, float64(len(path))
		}
	}
	if monster == 0 {
		t.Fatal("no naturally activated reachable Moor monster")
	}
	walk(position(monster), 1.5)
	selected := dynamicStore(t, engine, "d2legacy.world.selectable")
	target, _ := selected.Get(monster)
	targetID, _ := target.Get("id")
	deaths := dynamicStore(t, engine, "d2legacy.monster.death")
	initialDefinition, _ := monsters.Get(monster)
	initialFamily, _ := initialDefinition.Get("definition_id")
	initialTC, _ := initialDefinition.Get("treasure_class")
	t.Logf("ordinary combat target %v real TC=%v", initialFamily, initialTC)
	for range 100 {
		if _, dead := deaths.Get(monster); dead {
			break
		}
		goal := position(monster)
		submit("player.use_skill", map[string]any{"side": "left", "target_x": goal.X, "target_y": goal.Y, "target_id": targetID})
		stepSession(t, session, 20)
	}
	death, dead := deaths.Get(monster)
	if !dead {
		t.Fatal("natural monster survived ordinary attacks")
	}
	drops, _ := death.Get("drops")
	tc, _ := death.Get("treasure_class")
	definition, _ := monsters.Get(monster)
	family, _ := definition.Get("definition_id")
	t.Logf("mapSeed=1 authoritySeed=%d generated monster=%v TC=%v committed drops=%v", seed, family, tc, drops)
	identities := dynamicStore(t, engine, "d2legacy.item.identity")
	placements := dynamicStore(t, engine, "d2legacy.item.placement")
	var ground akara.Entity
	for _, entity := range identities.Entities() {
		placement, _ := placements.Get(entity)
		container, _ := placement.Get("container")
		if container == "world" {
			ground = entity
			break
		}
	}
	if ground == 0 {
		t.Fatal("real TC produced no supported ground item")
	}
	target, ok := selected.Get(ground)
	if !ok {
		t.Fatal("natural ground item is not selectable")
	}
	itemTarget, _ := target.Get("id")
	checkpoint, err := session.CanonicalCheckpoint()
	if err != nil {
		t.Fatal(err)
	}
	worldJSON, err := playeradapter.ProjectWorldView("alice", checkpoint)
	if err != nil {
		t.Fatal(err)
	}
	var public playeradapter.WorldView
	if err := json.Unmarshal(worldJSON, &public); err != nil {
		t.Fatal(err)
	}
	visible := false
	for _, entity := range public.Entities {
		if entity.ID == itemTarget && entity.Kind == "item" {
			visible = true
		}
	}
	if !visible {
		t.Fatal("natural ground item missing from public world projection")
	}
	walk(position(ground), 1.5)
	submit("item.pickup", map[string]any{"target_id": itemTarget})
	stepSession(t, session, 2)
	if _, ok := selected.Get(ground); ok {
		t.Fatal("ordinary pickup retained ground selection")
	}
	checkpoint, err = session.CanonicalCheckpoint()
	if err != nil {
		t.Fatal(err)
	}
	saved, err := playeradapter.ProjectCharacter("alice", character, checkpoint)
	if err != nil {
		t.Fatal(err)
	}
	if saved.Inventory == nil || len(saved.Inventory.Items) != 1 || saved.Inventory.Items[0].Container != "inventory" {
		t.Fatalf("picked possession missing: %#v", saved.Inventory)
	}
	item := saved.Inventory.Items[0]
	if seed == 8 {
		found := false
		for _, table := range []string{"weapons", "armor"} {
			rows, err := records.Load("data/global/excel/" + table + ".txt")
			if err != nil {
				t.Fatal(err)
			}
			for _, row := range rows {
				if row["code"] == item.Code {
					found = true
				}
			}
		}
		if !found {
			t.Fatalf("implicit equipment TC did not resolve to a real weapon or armor: %s", item.Code)
		}
		var facts []struct {
			Code    string `json:"code"`
			Quality string `json:"quality"`
		}
		if err := json.Unmarshal([]byte(drops.(string)), &facts); err != nil {
			t.Fatal(err)
		}
		if len(facts) != 1 || facts[0].Code != item.Code || facts[0].Quality == "unresolved" {
			t.Fatalf("implicit equipment drop remained unresolved: %v", drops)
		}
	}
	if item.Generation == nil || item.Generation.Facts != drops {
		t.Fatalf("picked item changed natural drop facts: %#v", item)
	}
	path := filepath.Join(t.TempDir(), "profile.json")
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
	saved, _ = restored.Selected()
	fresh, freshSession := start(saved, "bob")
	freshCheckpoint, err := freshSession.CanonicalCheckpoint()
	if err != nil {
		t.Fatal(err)
	}
	reloaded, err := playeradapter.ProjectCharacter("bob", saved, freshCheckpoint)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(reloaded.Inventory, saved.Inventory) {
		t.Fatalf("fresh admission changed natural possession: got %#v want %#v", reloaded.Inventory, saved.Inventory)
	}
	if playerEntity(t, fresh, "bob") == 0 {
		t.Fatal("fresh owner was not admitted")
	}
	t.Logf("public ground item %v code=%s picked into inventory, profile written/read, identical mechanics and generation restored under bob", itemTarget, item.Code)
}
