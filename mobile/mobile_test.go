//go:build ebitengine

package darkmagicmobile

import (
	"math"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestScreenGeometryRejectsInvalidHostValues(t *testing.T) {
	previous := game
	game = &mobileGame{}
	t.Cleanup(func() { game = previous })
	if err := SetScreenGeometry(874, 402, 62, 0, 62, 21); err != nil {
		t.Fatal(err)
	}
	for _, args := range [][6]float64{{0, 402, 0, 0, 0, 0}, {874, 402, 500, 0, 500, 0}, {874, 402, 0, -1, 0, 0}, {874, math.NaN(), 0, 0, 0, 0}, {874, 402, 0, 0, math.Inf(1), 0}} {
		if err := SetScreenGeometry(args[0], args[1], args[2], args[3], args[4], args[5]); err == nil {
			t.Fatalf("accepted invalid geometry: %v", args)
		}
	}
	if value := game.geometry.Load(); value == nil || value.Width != 874 || value.Bottom != 21 {
		t.Fatalf("invalid update replaced valid geometry: %+v", value)
	}
}

func TestConfigureUsesSandboxPathsAndRejectsReconfiguration(t *testing.T) {
	previous := game
	game = &mobileGame{}
	t.Cleanup(func() { game = previous })
	for _, key := range []string{"MPQ_DIRECTORY", "DARK_MAGIC_PREFERENCES", "DARK_MAGIC_SHELL_CONFIG", "DARK_MAGIC_ASSET_SET_CACHE", "DARK_MAGIC_DEBUG_ADDR"} {
		t.Setenv(key, "")
	}
	assets := t.TempDir()
	data := filepath.Join(t.TempDir(), "support")
	if err := Configure("relative", data, "spell_lab", true); err == nil {
		t.Fatal("accepted relative asset path")
	}

	if err := Configure(assets, data, "unknown", true); err == nil {
		t.Fatal("accepted unknown scene during configuration")
	}

	if err := Configure(assets, data, "spell_lab", true); err != nil {
		t.Fatal(err)
	}
	if os.Getenv("MPQ_DIRECTORY") != assets || os.Getenv("DARK_MAGIC_PREFERENCES") != filepath.Join(data, "preferences.json") {
		t.Fatal("sandbox paths were not propagated")
	}

	if game.startScene != "spell_lab" || !game.nativeAudio {
		t.Fatal("selected host configuration was not retained")
	}
	if info, err := os.Stat(data); err != nil || !info.IsDir() {
		t.Fatalf("data directory: %v", err)
	}

	if err := Configure(assets, data, "spell_lab", true); err == nil {
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
	options, err := hostedOptions("ui_lab", true)
	if err != nil || options.StartScene != "ui_lab" || options.FixtureCharacters != 0 || options.ExpandViewport {
		t.Fatalf("UI startup acquired a disposable character: %+v, %v", options, err)
	}
	for _, scene := range []string{"", "normal"} {
		options, err := hostedOptions(scene, true)
		if err != nil || options.StartScene != "title" || options.FixtureCharacters != 0 || !options.TouchControls || !options.ExpandViewport {
			t.Fatalf("normal startup must show the touch-enabled title without a fixture: %+v, %v", options, err)
		}
	}
	for _, scene := range []string{"game_world"} {
		options, err := hostedOptions(scene, true)
		if err != nil || options.FixtureCharacters != 1 || options.FixtureWorldLevel != 1 || options.StartScene != "game_world" || !options.ExpandViewport {
			t.Fatalf("world startup cannot admit its upstream town fixture: %+v, %v", options, err)
		}
	}
	for _, scene := range []string{"spell_lab", "warp_lab"} {
		options, err := hostedOptions(scene, true)
		if err != nil || options.StartScene != scene || options.FixtureCharacters != 0 || options.FixtureWorldLevel != 0 || !options.ExpandViewport {
			t.Fatalf("lab startup overrides upstream fixture defaults: %+v, %v", options, err)
		}
	}

	if _, err := hostedOptions("unknown", true); err == nil {
		t.Fatal("accepted an unsupported direct-start scene")
	}
}

func TestHostedOptionsUseHostAudioConfiguration(t *testing.T) {
	for _, nativeAudio := range []bool{false, true} {
		for _, scene := range []string{"normal", "game_world"} {
			options, err := hostedOptions(scene, nativeAudio)
			if err != nil {
				t.Fatal(err)
			}

			if options.DisableNativeAudio == nativeAudio {
				t.Fatalf("scene %q with native audio %v: disabled = %v", scene, nativeAudio, options.DisableNativeAudio)
			}
		}
	}
}

func TestHostedOptionsRestrictSeamFixtureToDiagnostics(t *testing.T) {
	t.Setenv("DARK_MAGIC_FIXTURE_WORLD_SPAWN", "seam")
	t.Setenv("DARK_MAGIC_INPUT_DIAGNOSTICS", "0")

	options, _ := hostedOptions("game_world", true)
	if options.FixtureWorldSpawn != "" {
		t.Fatal("normal Game World moved to the seam")
	}
	t.Setenv("DARK_MAGIC_INPUT_DIAGNOSTICS", "1")

	options, _ = hostedOptions("game_world", true)
	if options.FixtureWorldSpawn != "seam" {
		t.Fatal("diagnostic seam fixture was ignored")
	}

	options, _ = hostedOptions("spell_lab", true)
	if options.FixtureWorldSpawn != "" {
		t.Fatal("overrode lab fixture")
	}
}

func TestHostedOptionsKeepRenderDensitySeparateFromLayout(t *testing.T) {
	for _, density := range []string{"1", "2", "native"} {
		t.Setenv("DARK_MAGIC_RENDER_DENSITY", density)

		options, err := hostedOptions("normal", false)
		if err != nil {
			t.Fatal(err)
		}

		if options.RenderDensity != density || options.MaxRenderDensity != 2 ||
			!options.ExpandViewport || options.NativeResolution {
			t.Fatalf("density changed mobile layout: %+v", options)
		}
	}
}
