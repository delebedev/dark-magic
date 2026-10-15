package clientapp

import (
	"encoding/json"
	"errors"
	"math"
	"sync"

	"github.com/gravestench/dark-magic/internal/inputstate"
)

// UIKit submits coordinates; the frame owner emits one press, hold, and release.
type pointerTapProbe struct {
	mu                         sync.Mutex
	width, height, x, y, phase int
	gestures                   []contactProbeFrame
}

func (p *pointerTapProbe) queue(x, y int) error {
	p.mu.Lock()
	defer p.mu.Unlock()

	if x < 0 || y < 0 || x >= p.width || y >= p.height {
		return errors.New("probe coordinates are outside the logical viewport")
	}

	if p.phase != 0 || len(p.gestures) > 0 {
		return errors.New("a probe tap is still pending")
	}

	p.x, p.y, p.phase = x, y, 1

	return nil
}

func (p *pointerTapProbe) frame(frame inputstate.Frame, width, height int) inputstate.Frame {
	p.mu.Lock()
	defer p.mu.Unlock()

	p.width, p.height = width, height
	if len(p.gestures) > 0 {
		step := &p.gestures[0]
		for _, point := range step.Contacts {
			if point.X >= float64(width) || point.Y >= float64(height) {
				p.gestures = nil
				frame.Contacts = nil
				frame.PointerSource = "probe"
				frame.Actions = cloneActions(frame.Actions)
				frame.Actions["pointer_primary"] = inputstate.ActionState{}

				return frame
			}
		}

		frame.Contacts = append([]inputstate.Contact(nil), step.Contacts...)
		frame.PointerSource = "probe"
		frame.Actions = cloneActions(frame.Actions)
		frame.Actions["pointer_primary"] = inputstate.ActionState{}

		step.Frames--
		if step.Frames == 0 {
			p.gestures = p.gestures[1:]
		}

		return frame
	}

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

// Probe gestures supply the same frame contacts as the native touch sampler.
type contactProbeFrame struct {
	Frames   int
	Contacts []inputstate.Contact
}

func (p *pointerTapProbe) queueContacts(encoded string) error {
	p.mu.Lock()
	defer p.mu.Unlock()

	if p.phase != 0 || len(p.gestures) > 0 {
		return errors.New("a probe gesture is still pending")
	}

	if len(encoded) > 32768 {
		return errors.New("probe gesture is too large")
	}

	var steps []contactProbeFrame
	if err := json.Unmarshal([]byte(encoded), &steps); err != nil {
		return err
	}

	total := 0

	for _, step := range steps {
		if step.Frames < 1 || step.Frames > 600 || len(step.Contacts) > 4 {
			return errors.New("invalid probe frame")
		}

		total += step.Frames
		if total > 600 {
			return errors.New("probe gesture exceeds ten seconds")
		}

		ids := map[int]bool{}
		for _, point := range step.Contacts {
			if ids[point.ID] || point.ID < 0 ||
				math.IsNaN(point.X) || math.IsNaN(point.Y) ||
				math.IsInf(point.X, 0) || math.IsInf(point.Y, 0) ||
				point.X < 0 || point.X >= float64(p.width) ||
				point.Y < 0 || point.Y >= float64(p.height) {
				return errors.New("invalid probe contact")
			}

			ids[point.ID] = true
		}
	}

	if len(steps) == 0 || len(steps[len(steps)-1].Contacts) > 0 {
		return errors.New("probe must end with all fingers released")
	}

	p.gestures = steps

	return nil
}
