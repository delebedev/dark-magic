// Package surface separates scene coordinates from raster pixels and host points.
package surface

import (
	"fmt"
	"math"
)

// Policy is fixed at launch. Density affects rasterization, never the scene's extent.
type Policy struct {
	Width, Height  int
	Expand, Native bool
	Fit, Density   string
	MaxDensity     float64
}

// Rect is a rectangle in physical display pixels.
type Rect struct{ X, Y, Width, Height float64 }

// Geometry is one resolved frame's layout, raster and presentation mapping.
type Geometry struct {
	Width, Height             int
	RenderWidth, RenderHeight int
	PointWidth, PointHeight   int
	PixelWidth, PixelHeight   int
	Viewport                  Rect
}

// Validate rejects unsupported policies before either backend allocates native resources.
func (p Policy) Validate() error {
	if p.Width <= 0 || p.Height <= 0 {
		return fmt.Errorf("surface: logical dimensions must be positive")
	}

	if p.Fit != "" && p.Fit != "contain" && p.Fit != "stretch" {
		return fmt.Errorf("surface: unknown fit %q", p.Fit)
	}

	if p.Density != "" && p.Density != "1" && p.Density != "2" && p.Density != "native" {
		return fmt.Errorf("surface: density must be 1, 2 or native, got %q", p.Density)
	}

	if math.IsNaN(p.MaxDensity) || math.IsInf(p.MaxDensity, 0) ||
		p.MaxDensity < 0 || p.MaxDensity > 4 || p.MaxDensity > 0 && p.MaxDensity < 1 {
		return fmt.Errorf("surface: maximum density must be between 1 and 4")
	}

	if p.Native && p.Density != "" && p.Density != "1" {
		return fmt.Errorf("surface: native workspace cannot also select render density")
	}

	return nil
}

// Fit returns the shared presentation rectangle for drawing and input.
func Fit(pixelWidth, pixelHeight, width, height int, fit string) (Rect, error) {
	if pixelWidth <= 0 || pixelHeight <= 0 || width <= 0 || height <= 0 {
		return Rect{}, fmt.Errorf("surface: dimensions must be positive")
	}

	if fit == "stretch" {
		return Rect{Width: float64(pixelWidth), Height: float64(pixelHeight)}, nil
	}

	if fit != "" && fit != "contain" {
		return Rect{}, fmt.Errorf("surface: unknown fit %q", fit)
	}

	scale := math.Min(float64(pixelWidth)/float64(width), float64(pixelHeight)/float64(height))
	w, h := math.Min(float64(pixelWidth), float64(width)*scale), math.Min(float64(pixelHeight), float64(height)*scale)

	return Rect{(float64(pixelWidth) - w) / 2, (float64(pixelHeight) - h) / 2, w, h}, nil
}

// Resolve receives host points and physical pixels separately, including on Retina displays.
func (p Policy) Resolve(pointWidth, pointHeight, pixelWidth, pixelHeight int) (Geometry, error) {
	if err := p.Validate(); err != nil {
		return Geometry{}, err
	}

	if pointWidth <= 0 || pointHeight <= 0 || pixelWidth <= 0 || pixelHeight <= 0 {
		return Geometry{}, fmt.Errorf("surface: host dimensions must be positive")
	}

	w, h := p.Width, p.Height
	if p.Native {
		w, h = pixelWidth, pixelHeight
	} else if p.Expand {
		w = max(w, int(math.Round(float64(h)*float64(pointWidth)/float64(pointHeight))))
	}

	viewport, err := Fit(pixelWidth, pixelHeight, w, h, p.Fit)
	if err != nil {
		return Geometry{}, err
	}

	density := 1.0

	switch p.Density {
	case "2":
		density = 2
	case "native":
		cap := p.MaxDensity
		if cap == 0 {
			cap = 2
		}

		density = math.Min(cap, math.Min(viewport.Width/float64(w), viewport.Height/float64(h)))
	}

	rw, rh := max(1, int(math.Round(float64(w)*density))), max(1, int(math.Round(float64(h)*density)))
	if rw > 16384 || rh > 16384 {
		return Geometry{}, fmt.Errorf("surface: render dimensions %dx%d exceed 16384", rw, rh)
	}

	return Geometry{w, h, rw, rh, pointWidth, pointHeight, pixelWidth, pixelHeight, viewport}, nil
}

// RasterScale accounts for integer raster rounding independently on each axis.
func (g Geometry) RasterScale() (float64, float64) {
	return float64(g.RenderWidth) / float64(g.Width), float64(g.RenderHeight) / float64(g.Height)
}

// PixelToLogical retains out-of-bounds coordinates so drags can leave the viewport.
func (g Geometry) PixelToLogical(x, y float64) (float64, float64, bool) {
	v := g.Viewport

	x, y = (x-v.X)*float64(g.Width)/v.Width, (y-v.Y)*float64(g.Height)/v.Height
	// Roundoff at integer boundaries must not move input into the preceding logical pixel.
	if nearest := math.Round(x); math.Abs(x-nearest) < 1e-9 {
		x = nearest
	}

	if nearest := math.Round(y); math.Abs(y-nearest) < 1e-9 {
		y = nearest
	}

	return x, y, x >= 0 && y >= 0 && x < float64(g.Width) && y < float64(g.Height)
}

// PointToLogical maps native window input through the same physical viewport used to present it.
func (g Geometry) PointToLogical(x, y float64) (float64, float64, bool) {
	return g.PixelToLogical(x*float64(g.PixelWidth)/float64(g.PointWidth), y*float64(g.PixelHeight)/float64(g.PointHeight))
}

// RasterInputToLogical undoes Ebitengine's built-in contain mapping before applying our presentation policy.
func (g Geometry) RasterInputToLogical(x, y float64) (float64, float64, bool) {
	v, _ := Fit(g.PixelWidth, g.PixelHeight, g.RenderWidth, g.RenderHeight, "contain")
	return g.PixelToLogical(v.X+x*v.Width/float64(g.RenderWidth), v.Y+y*v.Height/float64(g.RenderHeight))
}
