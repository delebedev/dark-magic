package desktop

import (
	"image"
	"image/color"
	"image/draw"

	"github.com/gravestench/dark-magic/internal/presentation/surface"
)

// contiguousRGBA copies any image and non-zero origin into tightly packed, zero-origin RGBA storage required by native
// texture upload paths.
func contiguousRGBA(source image.Image) *image.RGBA {
	bounds := source.Bounds()
	result := image.NewRGBA(image.Rect(0, 0, bounds.Dx(), bounds.Dy()))
	draw.Draw(result, result.Bounds(), source, bounds.Min, draw.Src)

	return result
}

// quantizeImage chooses the nearest palette RGB value for every visible pixel while preserving source alpha. Fully
// transparent pixels are left untouched so hidden RGB data cannot produce palette fringes later.
func quantizeImage(source image.Image, palette color.Palette) *image.RGBA {
	rgba := contiguousRGBA(source)

	colors := make([]color.RGBA, len(palette))
	for index, entry := range palette {
		colors[index] = color.RGBAModel.Convert(entry).(color.RGBA)
	}

	for offset := 0; offset < len(rgba.Pix); offset += 4 {
		if rgba.Pix[offset+3] == 0 {
			continue
		}

		best, distance := color.RGBA{}, int(^uint(0)>>1)

		// Alpha is excluded from distance so palette entries select visible color
		// while the assignment below leaves the source coverage byte unchanged.
		for _, candidate := range colors {
			red := int(rgba.Pix[offset]) - int(candidate.R)
			green := int(rgba.Pix[offset+1]) - int(candidate.G)

			blue := int(rgba.Pix[offset+2]) - int(candidate.B)
			if candidateDistance := red*red + green*green + blue*blue; candidateDistance < distance {
				best, distance = candidate, candidateDistance
			}
		}

		rgba.Pix[offset], rgba.Pix[offset+1], rgba.Pix[offset+2] = best.R, best.G, best.B
	}

	return rgba
}

func (o Options) surfacePolicy() surface.Policy {
	return surface.Policy{
		Width: o.LogicalWidth, Height: o.LogicalHeight, Expand: o.ExpandViewport, Native: o.NativeResolution,
		Fit: o.ViewportFit, Density: o.RenderDensity, MaxDensity: o.MaxRenderDensity,
	}
}
