package raylibRenderer

import (
	rl "github.com/gen2brain/raylib-go/raylib"
	"github.com/gravestench/dark-magic/internal/presentation/surface"
)

// SetWindowTitle changes the native title on the renderer owner thread; callers should schedule it through OnFrame when
// originating from another goroutine.
func (s *Service) SetWindowTitle(title string) {
	rl.SetWindowTitle(title)
}

// WindowSize returns host points for window-space overlays, before Raylib applies its DPI transform.
func (s *Service) WindowSize() (width, height int) {
	return rl.GetScreenWidth(), rl.GetScreenHeight()
}

// Resolution returns the fixed logical game surface unless native rendering was selected. Native mode follows the
// drawable window exactly, so the renderer has no final scaling step.
func (s *Service) Resolution() (int, int) {
	g := s.surfaceGeometry()
	return g.Width, g.Height
}

func (s *Service) surfacePolicy() surface.Policy {
	c := s.config.Resolution

	return surface.Policy{
		Width: c.Width, Height: c.Height, Expand: c.Expand, Native: c.Native,
		Fit: c.Fit, Density: c.Density, MaxDensity: c.MaxDensity,
	}
}

func (s *Service) surfaceGeometry() surface.Geometry {
	if value := s.surface.Load(); value != nil {
		return value.(surface.Geometry)
	}

	if s.config == nil {
		return surface.Geometry{}
	}

	g, _ := s.surfacePolicy().Resolve(
		s.config.Window.Width, s.config.Window.Height, s.config.Window.Width, s.config.Window.Height,
	)

	return g
}

func (s *Service) resolveSurface() error {
	g, err := s.surfacePolicy().Resolve(
		rl.GetScreenWidth(), rl.GetScreenHeight(), rl.GetRenderWidth(), rl.GetRenderHeight(),
	)
	if err == nil {
		if previous := s.surface.Load(); previous == nil || previous.(surface.Geometry) != g {
			s.surface.Store(g)
		}
	}

	return err
}
