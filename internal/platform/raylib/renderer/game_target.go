package raylibRenderer

import (
	"fmt"

	rl "github.com/gen2brain/raylib-go/raylib"
)

// startGameTarget allocates the resolved raster surface on the renderer owner thread.
func (s *Service) startGameTarget() error {
	if err := s.resolveSurface(); err != nil {
		return err
	}

	width, height := s.frameResolution()
	if width <= 0 || height <= 0 {
		return fmt.Errorf("renderer: logical resolution requires positive dimensions, got %dx%d", width, height)
	}

	s.gameTarget = rl.LoadRenderTexture(int32(width), int32(height))
	if !rl.IsRenderTextureValid(s.gameTarget) {
		return fmt.Errorf("renderer: create logical game target %dx%d", width, height)
	}

	rl.SetTextureFilter(s.gameTarget.Texture, rl.FilterPoint)

	return nil
}

// resizeGameTargetForWindow resolves layout and density before frame callbacks, replacing targets only when needed.
func (s *Service) resizeGameTargetForWindow() error {
	if s.config == nil {
		return nil
	}

	if err := s.resolveSurface(); err != nil {
		return err
	}

	width, height := s.frameResolution()
	if width <= 0 || height <= 0 {
		return fmt.Errorf("renderer: native resolution requires positive dimensions, got %dx%d", width, height)
	}

	if s.paletteQuantizer != nil {
		return s.resizePaletteTarget(width, height)
	}

	if int(s.gameTarget.Texture.Width) == width && int(s.gameTarget.Texture.Height) == height {
		return nil
	}

	s.stopGameTarget()

	return s.startGameTarget()
}

// frameResolution is safe both during startup (after the native window exists but before isInit is published) and
// during steady-state resize handling.
func (s *Service) frameResolution() (int, int) {
	g := s.surfaceGeometry()
	return g.RenderWidth, g.RenderHeight
}

// stopGameTarget releases the logical render texture once and clears its handle so repeated shutdown remains safe.
func (s *Service) stopGameTarget() {
	if rl.IsRenderTextureValid(s.gameTarget) {
		rl.UnloadRenderTexture(s.gameTarget)
		s.gameTarget = rl.RenderTexture2D{}
	}
}

// renderGameTarget draws one complete logical frame into an offscreen texture. The camera and scene graph are confined
// to this target so later window-space overlays do not inherit their transform.
func (s *Service) renderGameTarget(target rl.RenderTexture2D) {
	rl.BeginTextureMode(target)
	rl.ClearBackground(rl.Black)
	rl.BeginMode2D(s.camera)
	sx, sy := s.surfaceGeometry().RasterScale()
	rl.MultMatrix(rl.MatrixScale(float32(sx), float32(sy), 1))
	s.update()
	s.render()
	rl.EndMode2D()
	rl.EndTextureMode()
}

// presentGameTarget maps the logical texture into the current drawable viewport, optionally through a final shader. A
// negative source height corrects render-texture orientation without copying pixels.
func (s *Service) presentGameTarget(target rl.RenderTexture2D, shader *rl.Shader) {
	geometry := s.surfaceGeometry()
	viewport := geometry.Viewport
	// BeginDrawing applies the window DPI transform, so its destination uses host points.
	scaleX := float32(geometry.PointWidth) / float32(geometry.PixelWidth)
	scaleY := float32(geometry.PointHeight) / float32(geometry.PixelHeight)

	if shader != nil {
		rl.BeginShaderMode(*shader)

		defer rl.EndShaderMode()
	}

	source := rl.NewRectangle(0, 0, float32(target.Texture.Width), -float32(target.Texture.Height))
	destination := rl.NewRectangle(
		float32(viewport.X)*scaleX, float32(viewport.Y)*scaleY,
		float32(viewport.Width)*scaleX, float32(viewport.Height)*scaleY,
	)
	rl.DrawTexturePro(target.Texture, source, destination, rl.Vector2{}, 0, rl.White)
}
