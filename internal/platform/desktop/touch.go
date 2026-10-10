package desktop

import "github.com/gravestench/dark-magic/internal/inputstate"

type touchPoint struct{ id, x, y int }

// shortcut: only one finger drives pointer_primary; add gestures after M1 is demonstrated.
type touchPointer struct {
	id, x, y        int
	active, waiting bool
}

func (p *touchPointer) sample(points []touchPoint, width, height int) (int, int, inputstate.ActionState, bool) {
	if p.active {
		for _, point := range points {
			if point.id == p.id {
				p.x, p.y = point.x, point.y
				return p.x, p.y, inputstate.ActionState{Down: true}, true
			}
		}
		p.active, p.waiting = false, len(points) > 0
		return p.x, p.y, inputstate.ActionState{Released: true}, true
	}
	if len(points) == 0 {
		p.waiting = false
		return 0, 0, inputstate.ActionState{}, false
	}
	if p.waiting {
		return p.x, p.y, inputstate.ActionState{}, true
	}
	point := points[0]
	if point.x < 0 || point.y < 0 || point.x >= width || point.y >= height {
		p.waiting = true
		return point.x, point.y, inputstate.ActionState{}, true
	}
	p.id, p.x, p.y, p.active = point.id, point.x, point.y, true
	return p.x, p.y, inputstate.ActionState{Pressed: true}, true
}
