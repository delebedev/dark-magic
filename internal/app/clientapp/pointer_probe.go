package clientapp

import (
	"errors"
	"sync"

	"github.com/gravestench/dark-magic/internal/inputstate"
)

// UIKit submits coordinates; the frame owner emits one press, hold, and release.
type pointerTapProbe struct {
	mu                         sync.Mutex
	width, height, x, y, phase int
}

func (p *pointerTapProbe) queue(x, y int) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	if x < 0 || y < 0 || x >= p.width || y >= p.height {
		return errors.New("probe coordinates are outside the logical viewport")
	}
	if p.phase != 0 {
		return errors.New("a probe tap is still pending")
	}
	p.x, p.y, p.phase = x, y, 1
	return nil
}

func (p *pointerTapProbe) frame(frame inputstate.Frame, width, height int) inputstate.Frame {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.width, p.height = width, height
	if p.phase == 0 {
		return frame
	}
	if p.x >= width || p.y >= height {
		p.phase = 0
		return frame
	}
	frame.CursorX, frame.CursorY = float64(p.x), float64(p.y)
	frame.PointerSource = "probe"
	frame.Actions = cloneActions(frame.Actions)
	frame.Actions["pointer_primary"] = inputstate.ActionState{
		Pressed: p.phase == 1, Down: p.phase < 3, Released: p.phase == 3,
	}
	p.phase = (p.phase + 1) % 4
	return frame
}
