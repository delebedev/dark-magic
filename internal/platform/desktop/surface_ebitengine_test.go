//go:build ebitengine

package desktop

import (
	"testing"

	"github.com/gravestench/dark-magic/internal/presentation/surface"
)

func TestEbitengineDensityMapsEveryContactToLogicalSpace(t *testing.T) {
	for _, fit := range []string{"contain", "stretch"} {
		options := DefaultOptions()
		options.RenderDensity, options.ViewportFit = "2", fit
		r := newEbitRenderer(options)

		g, err := options.surfacePolicy().Resolve(1000, 600, 2000, 1200)
		if err != nil {
			t.Fatal(err)
		}

		r.surface.Store(g)
		input := newEbitInput(r)

		v, _ := surface.Fit(g.PixelWidth, g.PixelHeight, g.RenderWidth, g.RenderHeight, "contain")
		for _, point := range [][2]int{{100, 100}, {700, 500}} {
			px := g.Viewport.X + float64(point[0])*g.Viewport.Width/float64(g.Width)
			py := g.Viewport.Y + float64(point[1])*g.Viewport.Height/float64(g.Height)

			x, y := input.logicalPosition(
				int((px-v.X)*float64(g.RenderWidth)/v.Width), int((py-v.Y)*float64(g.RenderHeight)/v.Height),
			)
			if x != point[0] || y != point[1] {
				t.Fatalf("%s contact %v maps to %d,%d", fit, point, x, y)
			}
		}

		if w, h := r.Resolution(); w != 800 || h != 600 {
			t.Fatalf("density changed logical size: %d,%d", w, h)
		}

		if x, y, inside := r.ScreenToGame(500, 300); x != 400 || y != 300 || !inside {
			t.Fatalf("host center: %d,%d %v", x, y, inside)
		}
	}
}
