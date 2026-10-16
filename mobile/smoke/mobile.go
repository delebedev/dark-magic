//go:build ebitengine

// Package darkmagicmobile is an asset-free M0 diagnostic, not a Dark Magic scene.
package darkmagicmobile

import (
	"fmt"
	"image/color"

	"github.com/hajimehoshi/ebiten/v2"
	"github.com/hajimehoshi/ebiten/v2/ebitenutil"
)

// RequiresGameAssets lets the native host skip asset preparation for the smoke binding.
func RequiresGameAssets() bool { return false }

// Configure matches the native host's binding; the diagnostic needs no assets.
func Configure(assetDirectory, dataDirectory, startScene string) error { return nil }

func SetScreenGeometry(width, height, left, top, right, bottom float64) error { return nil }

func ProbeTap(x, y int) error { return fmt.Errorf("tap probe is unavailable in smoke mode") }

func PressAction(action string) error { return fmt.Errorf("actions are unavailable in smoke mode") }

func ProbeContacts(encoded string) error {
	return fmt.Errorf("contact probes are unavailable in smoke mode")
}

func LogicalWidth() int { return 800 }

type smokeGame struct {
	ticks int
	x, y  int
}

func (g *smokeGame) Update() error {
	g.ticks++
	for _, id := range ebiten.AppendTouchIDs(nil) {
		g.x, g.y = ebiten.TouchPosition(id)
		break
	}
	return nil
}

func (g *smokeGame) Draw(screen *ebiten.Image) {
	screen.Fill(color.RGBA{R: 24, G: 32, B: 48, A: 255})
	ebitenutil.DebugPrint(screen, fmt.Sprintf("M0: Ebitengine iOS smoke test\nNo Diablo assets or gameplay\nTick: %d\nTouch: %d, %d", g.ticks, g.x, g.y))
	ebitenutil.DrawRect(screen, float64(g.x)-8, float64(g.y)-8, 16, 16, color.White)
}

func (*smokeGame) Layout(width, height int) (int, int) { return 800, 600 }

type TextInputHandler interface {
	EditText(id int64, value, title string, secure bool)
}

func SetTextInputHandler(handler TextInputHandler)                  {}
func CompleteTextInput(id int64, value string, accepted bool) error { return nil }
