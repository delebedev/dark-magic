//go:build ebitengine

// Package darkmagicmobile binds the existing client to a UIKit-owned loop.
package darkmagicmobile

import (
	"errors"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"

	"github.com/gravestench/dark-magic/internal/app/clientapp"
	"github.com/gravestench/dark-magic/internal/content"
	"github.com/gravestench/dark-magic/internal/distribution"
	modruntime "github.com/gravestench/dark-magic/internal/runtime/lua"
	"github.com/hajimehoshi/ebiten/v2"
)

var game = &mobileGame{}

type mobileGame struct {
	mu            sync.Mutex
	configured    bool
	dataDirectory string
	startScene    string
	client        *clientapp.HostedGame
	content       *content.FS
	mods          *distribution.ModSet
	geometry      atomic.Pointer[modruntime.ScreenGeometry]
}

// SetScreenGeometry receives UIKit points, never framebuffer pixels.
func SetScreenGeometry(width, height, left, top, right, bottom float64) error {
	for _, value := range []float64{width, height, left, top, right, bottom} {
		if math.IsNaN(value) || math.IsInf(value, 0) || value < 0 || value > 10000 {
			return errors.New("invalid screen geometry")
		}
	}
	if width <= 0 || height <= 0 || left+right >= width || top+bottom >= height {
		return errors.New("invalid screen safe area")
	}
	game.geometry.Store(&modruntime.ScreenGeometry{Width: width, Height: height, Left: left, Top: top, Right: right, Bottom: bottom})
	return nil
}

// Configure must run once before creating the generated view controller.
// Assets are read-only; all persistent output goes to Application Support.
func Configure(assetDirectory, dataDirectory, startScene string) error {
	game.mu.Lock()
	defer game.mu.Unlock()
	if game.configured {
		return errors.New("Dark Magic is already configured")
	}
	if !filepath.IsAbs(assetDirectory) || !filepath.IsAbs(dataDirectory) || strings.Contains(assetDirectory, ",") {
		return errors.New("asset and data directories must be absolute; asset directory cannot contain commas")
	}
	if _, err := hostedOptions(startScene); err != nil {
		return err
	}
	info, err := os.Stat(assetDirectory)
	if err != nil || !info.IsDir() {
		return fmt.Errorf("asset directory %q is unavailable", assetDirectory)
	}
	if err := os.MkdirAll(dataDirectory, 0o700); err != nil {
		return err
	}
	for key, value := range map[string]string{
		"MPQ_DIRECTORY":              assetDirectory,
		"DARK_MAGIC_PREFERENCES":     filepath.Join(dataDirectory, "preferences.json"),
		"DARK_MAGIC_SHELL_CONFIG":    filepath.Join(dataDirectory, "shell.json"),
		"DARK_MAGIC_ASSET_SET_CACHE": filepath.Join(dataDirectory, "asset-set.json"),
		"DARK_MAGIC_DEBUG_ADDR":      "",
	} {
		if err := os.Setenv(key, value); err != nil {
			return err
		}
	}
	game.dataDirectory, game.startScene, game.configured = dataDirectory, startScene, true
	return nil
}

func (g *mobileGame) start() error {
	g.mu.Lock()
	defer g.mu.Unlock()
	if !g.configured {
		return errors.New("call Configure before creating the Ebitengine view controller")
	}
	options, err := hostedOptions(g.startScene)
	if err != nil {
		return err
	}
	g.mods, err = distribution.PrepareMods("none")
	if err != nil {
		return err
	}
	g.content, err = content.FromEnvironment(g.mods.Layers...)
	if err != nil {
		return err
	}
	if err := content.ValidateClientAssets(g.content); err != nil {
		return err
	}
	assetSetID, err := content.AssetSetIdentityFromEnvironment()
	if err != nil {
		return err
	}
	options.Content, options.Mods, options.Packages = g.content, &g.mods.Resolved, g.mods.Packages
	options.AssetSetID = assetSetID
	options.PlayerProfilePath = filepath.Join(g.dataDirectory, "player-profile.json")
	g.client, err = clientapp.NewHostedGame(options)
	return err
}

// Ordinary startup keeps the engine roster flow; direct world launch uses a disposable character.
func hostedOptions(scene string) (clientapp.Options, error) {
	options := clientapp.Options{StartScene: "ui_lab", ViewportFit: "contain", DisableNativeAudio: true, InputDiagnostics: os.Getenv("DARK_MAGIC_INPUT_DIAGNOSTICS") == "1"}
	switch scene {
	case "ui_lab":
	case "spell_lab", "warp_lab":
		options.StartScene = scene
	case "", "normal":
		// Mobile enters the ordinary roster flow without the desktop startup warm-up.
		options.StartScene = "main_menu"
	case "game_world":
		options.StartScene = "game_world"
		options.FixtureCharacters, options.FixtureWorldLevel = 1, 1
	default:
		return options, fmt.Errorf("unsupported mobile start scene %q", scene)
	}
	options.ExpandViewport = options.StartScene != "ui_lab" && options.StartScene != "main_menu"
	options.TouchControls = options.StartScene != "ui_lab"
	options.ScreenGeometry = func() modruntime.ScreenGeometry {
		if value := game.geometry.Load(); value != nil {
			return *value
		}
		return modruntime.ScreenGeometry{}
	}
	if options.InputDiagnostics && options.StartScene == "game_world" {
		options.FixtureWorldSpawn = os.Getenv("DARK_MAGIC_FIXTURE_WORLD_SPAWN")
	}
	return options, nil
}

func PressAction(action string) error {
	game.mu.Lock()
	defer game.mu.Unlock()
	if game.client == nil {
		return errors.New("game is not ready")
	}
	return game.client.PressAction(action)
}

// ProbeTap queues a labelled development tap through ordinary logical input.
func ProbeTap(x, y int) error {
	game.mu.Lock()
	defer game.mu.Unlock()
	if game.client == nil {
		return errors.New("game is not ready")
	}
	return game.client.ProbeTap(x, y)
}

// ProbeContacts accepts bounded diagnostic touch frames with a final release.
func ProbeContacts(encoded string) error {
	game.mu.Lock()
	defer game.mu.Unlock()
	if game.client == nil {
		return errors.New("game is not ready")
	}
	return game.client.ProbeContacts(encoded)
}

func LogicalWidth() int {
	game.mu.Lock()
	defer game.mu.Unlock()
	if game.client == nil {
		return 0
	}
	return game.client.LogicalWidth()
}

func (g *mobileGame) Update() error {
	if g.client == nil {
		if err := g.start(); err != nil {
			return errors.Join(err, g.close())
		}
	}
	if err := g.client.Update(); err != nil {
		return errors.Join(err, g.close())
	}
	return nil
}

func (g *mobileGame) Draw(screen *ebiten.Image) {
	if g.client != nil {
		g.client.Draw(screen)
	}
}

func (g *mobileGame) Layout(width, height int) (int, int) {
	if g.client != nil {
		return g.client.Layout(width, height)
	}
	return 800, 600
}

func (g *mobileGame) DrawFinalScreen(screen ebiten.FinalScreen, offscreen *ebiten.Image, geoM ebiten.GeoM) {
	if g.client != nil {
		g.client.DrawFinalScreen(screen, offscreen, geoM)
	}
}

func (g *mobileGame) close() error {
	var err error
	if g.client != nil {
		err = g.client.Close()
	}
	return errors.Join(err, g.content.Close(), g.mods.Close())
}
