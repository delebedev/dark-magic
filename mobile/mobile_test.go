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
	if err := Configure("relative", data); err == nil {
		t.Fatal("accepted relative asset path")
	}
	if err := Configure(assets, data); err != nil {
		t.Fatal(err)
	}
	if os.Getenv("MPQ_DIRECTORY") != assets || os.Getenv("DARK_MAGIC_PREFERENCES") != filepath.Join(data, "preferences.json") {
		t.Fatal("sandbox paths were not propagated")
	}
	if info, err := os.Stat(data); err != nil || !info.IsDir() {
		t.Fatalf("data directory: %v", err)
	}
	if err := Configure(assets, data); err == nil {
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
	if err != nil || options.StartScene != "ui_lab" || options.FixtureCharacters != 0 {
		t.Fatalf("UI startup acquired a disposable character: %+v, %v", options, err)
	}
	for _, scene := range []string{"", "game_world"} {
		options, err := hostedOptions(scene)
		if err != nil || options.FixtureCharacters != 1 || options.FixtureWorldLevel != 1 || options.StartScene != "game_world" {
			t.Fatalf("world startup cannot admit its upstream town fixture: %+v, %v", options, err)
		}
	}
	if _, err := hostedOptions("unknown"); err == nil {
		t.Fatal("accepted an unsupported direct-start scene")
	}
}
