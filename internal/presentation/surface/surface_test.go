package surface

import (
	"math"
	"testing"
)

func TestDensityPreservesLayoutAndInput(t *testing.T) {
	for _, fit := range []string{"contain", "stretch"} {
		for _, density := range []string{"1", "2", "native"} {
			for _, host := range [][4]int{{900, 400, 2700, 1200}, {400, 900, 1200, 2700}, {1000, 700, 2000, 1400}} {
				p := Policy{Width: 800, Height: 600, Expand: true, Fit: fit, Density: density}

				g, err := p.Resolve(host[0], host[1], host[2], host[3])
				if err != nil {
					t.Fatal(err)
				}

				base, _ := (Policy{Width: 800, Height: 600, Expand: true, Fit: fit}).Resolve(host[0], host[1], host[2], host[3])
				if g.Width != base.Width || g.Height != base.Height || g.Viewport != base.Viewport {
					t.Fatalf("density changed layout: %+v", g)
				}

				for _, point := range [][2]float64{{0, 0}, {0.2, 0.8}, {0.8, 0.2}, {0.5, 0.5}} {
					wantX, wantY := point[0]*float64(g.Width), point[1]*float64(g.Height)
					px, py := g.Viewport.X+point[0]*g.Viewport.Width, g.Viewport.Y+point[1]*g.Viewport.Height

					x, y, inside := g.PointToLogical(px*float64(host[0])/float64(host[2]), py*float64(host[1])/float64(host[3]))
					if math.Abs(x-wantX) > 1e-9 || math.Abs(y-wantY) > 1e-9 || !inside {
						t.Fatalf("point mapping: %v %v %v", x, y, inside)
					}

					v, _ := Fit(host[2], host[3], g.RenderWidth, g.RenderHeight, "contain")

					x, y, inside = g.RasterInputToLogical(
						(px-v.X)*float64(g.RenderWidth)/v.Width, (py-v.Y)*float64(g.RenderHeight)/v.Height,
					)
					if math.Abs(x-wantX) > 1e-9 || math.Abs(y-wantY) > 1e-9 || !inside {
						t.Fatalf("raster mapping: %v %v %v", x, y, inside)
					}
				}

				if _, _, inside := g.PixelToLogical(g.Viewport.X+g.Viewport.Width, g.Viewport.Y); inside {
					t.Fatal("right edge inside")
				}
			}
		}
	}
}

func TestNativeDensityAndWorkspace(t *testing.T) {
	p := Policy{Width: 800, Height: 600, Expand: true, Density: "native"}

	g, _ := p.Resolve(900, 400, 2700, 1200)
	if g.Width != 1350 || g.RenderWidth != 2700 || g.RenderHeight != 1200 {
		t.Fatalf("phone: %+v", g)
	}

	p.MaxDensity = 1.5

	g, _ = p.Resolve(900, 400, 2700, 1200)
	if g.RenderWidth != 2025 || g.RenderHeight != 900 {
		t.Fatalf("cap: %+v", g)
	}

	p = Policy{Width: 800, Height: 600, Native: true}

	g, _ = p.Resolve(900, 400, 2700, 1200)
	if g.Width != 2700 || g.Height != 1200 || g.RenderWidth != 2700 {
		t.Fatalf("workspace: %+v", g)
	}

	x, y, inside := g.PointToLogical(450, 200)
	if x != 1350 || y != 600 || !inside {
		t.Fatalf("workspace input: %v,%v %v", x, y, inside)
	}
}

func TestInvalidPolicy(t *testing.T) {
	for _, p := range []Policy{
		{}, {Width: 800, Height: 600, Density: "3"}, {Width: 800, Height: 600, MaxDensity: math.NaN()},
		{Width: 800, Height: 600, MaxDensity: 0.5}, {Width: 800, Height: 600, MaxDensity: 5},
		{Width: 800, Height: 600, Native: true, Density: "2"}, {Width: 800, Height: 600, Fit: "other"},
	} {
		if p.Validate() == nil {
			t.Fatalf("accepted %+v", p)
		}
	}

	if _, err := (Policy{Width: 20000, Height: 600}).Resolve(800, 600, 800, 600); err == nil {
		t.Fatal("accepted oversized target")
	}
}

func TestViewportAndExpansion(t *testing.T) {
	contained, err := Fit(1920, 1080, 800, 600, "contain")
	if err != nil || contained != (Rect{X: 240, Width: 1440, Height: 1080}) {
		t.Fatalf("contain: %+v %v", contained, err)
	}

	stretched, err := Fit(1920, 1080, 800, 600, "stretch")
	if err != nil || stretched != (Rect{Width: 1920, Height: 1080}) {
		t.Fatalf("stretch: %+v %v", stretched, err)
	}

	for _, tc := range []struct{ width, height, want int }{
		{800, 600, 800}, {1920, 1080, 1067}, {2622, 1206, 1304}, {600, 800, 800},
	} {
		g, err := (Policy{Width: 800, Height: 600, Expand: true}).Resolve(tc.width, tc.height, tc.width, tc.height)
		if err != nil || g.Width != tc.want || g.Height != 600 {
			t.Fatalf("expansion: %+v %v", g, err)
		}
	}
}

func TestRasterInputPreservesNonzeroIntegerContacts(t *testing.T) {
	for _, density := range []string{"1", "2"} {
		g, err := (Policy{Width: 800, Height: 600, Density: density}).Resolve(960, 540, 1920, 1080)
		if err != nil {
			t.Fatal(err)
		}

		scaleX, scaleY := g.RasterScale()
		for _, point := range [][2]float64{{2, 4}, {17, 23}, {798, 598}} {
			x, y, inside := g.RasterInputToLogical(point[0]*scaleX, point[1]*scaleY)
			if x != point[0] || y != point[1] || !inside {
				t.Fatalf("density %s %v mapped to %v,%v %v", density, point, x, y, inside)
			}
		}
	}
}
