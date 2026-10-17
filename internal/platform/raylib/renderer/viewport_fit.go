package raylibRenderer

import "math"

// ScreenToGame maps native window points into logical game coordinates. Pixels in letterboxing are rejected so clicks
// on decorative margins cannot affect the world.
func (s *Service) ScreenToGame(x, y int) (int, int, bool) {
	gx, gy, inside := s.surfaceGeometry().PointToLogical(float64(x), float64(y))
	return int(math.Floor(gx)), int(math.Floor(gy)), inside
}
