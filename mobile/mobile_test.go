//go:build ebitengine

package darkmagicmobile

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestConfigureUsesSandboxPathsAndRejectsReconfiguration(t *testing.T) {
	previous := game
	game = &mobileGame{}
	t.Cleanup(func() { game = previous })
	for _, key := range []string{"MPQ_DIRECTORY", "DARK_MAGIC_PREFERENCES", "DARK_MAGIC_SHELL_CONFIG", "DARK_MAGIC_ASSET_SET_CACHE", "DARK_MAGIC_DEBUG_ADDR"} {
		t.Setenv(key, "")
	}
	assets := t.TempDir()
	data := filepath.Join(t.TempDir(), "support")
	if err := Configure("relative", data, "spell_lab"); err == nil {
		t.Fatal("accepted relative asset path")
	}
	if err := Configure(assets, data, "unknown"); err == nil {
		t.Fatal("accepted unknown scene during configuration")
	}
	if err := Configure(assets, data, "spell_lab"); err != nil {
		t.Fatal(err)
	}
	if os.Getenv("MPQ_DIRECTORY") != assets || os.Getenv("DARK_MAGIC_PREFERENCES") != filepath.Join(data, "preferences.json") {
		t.Fatal("sandbox paths were not propagated")
	}
	if game.startScene != "spell_lab" {
		t.Fatal("selected scene was not retained")
	}
	if info, err := os.Stat(data); err != nil || !info.IsDir() {
		t.Fatalf("data directory: %v", err)
	}
	if err := Configure(assets, data, "spell_lab"); err == nil {
		t.Fatal("accepted repeated configuration")
	}
}

func TestMobileGameRejectsUnconfiguredStart(t *testing.T) {
	g := &mobileGame{}
	if err := g.Update(); err == nil || !strings.Contains(err.Error(), "Configure") {
		t.Fatalf("unconfigured update: %v", err)
	}
}

func TestMobileGameRejectsMissingOriginalAssets(t *testing.T) {
	t.Setenv("MPQ_DIRECTORY", t.TempDir())
	g := &mobileGame{configured: true, dataDirectory: t.TempDir()}
	if err := g.Update(); err == nil || !strings.Contains(err.Error(), "required Diablo II asset") {
		t.Fatalf("missing-asset update: %v", err)
	}
}

func TestHostedOptionsKeepUIProfileAndWorldFixtureSeparate(t *testing.T) {
	options, err := hostedOptions("ui_lab")
	if err != nil || options.StartScene != "ui_lab" || options.FixtureCharacters != 0 || options.ExpandViewport {
		t.Fatalf("UI startup acquired a disposable character: %+v, %v", options, err)
	}
	for _, scene := range []string{"", "game_world"} {
		options, err := hostedOptions(scene)
		if err != nil || options.FixtureCharacters != 1 || options.FixtureWorldLevel != 1 || options.StartScene != "game_world" || !options.ExpandViewport {
			t.Fatalf("world startup cannot admit its upstream town fixture: %+v, %v", options, err)
		}
	}
	for _, scene := range []string{"spell_lab", "warp_lab"} {
		options, err := hostedOptions(scene)
		if err != nil || options.StartScene != scene || options.FixtureCharacters != 0 || options.FixtureWorldLevel != 0 || !options.ExpandViewport {
			t.Fatalf("lab startup overrides upstream fixture defaults: %+v, %v", options, err)
		}
	}
	if _, err := hostedOptions("unknown"); err == nil {
		t.Fatal("accepted an unsupported direct-start scene")
	}
}

func TestHostedOptionsRestrictSeamFixtureToDiagnostics(t *testing.T) {
	t.Setenv("DARK_MAGIC_FIXTURE_WORLD_SPAWN", "seam")
	t.Setenv("DARK_MAGIC_INPUT_DIAGNOSTICS", "0")
	options, _ := hostedOptions("game_world")
	if options.FixtureWorldSpawn != "" {
		t.Fatal("normal Game World moved to the seam")
	}
	t.Setenv("DARK_MAGIC_INPUT_DIAGNOSTICS", "1")
	options, _ = hostedOptions("game_world")
	if options.FixtureWorldSpawn != "seam" {
		t.Fatal("diagnostic seam fixture was ignored")
	}
	options, _ = hostedOptions("spell_lab")
	if options.FixtureWorldSpawn != "" {
		t.Fatal("overrode lab fixture")
	}
}
