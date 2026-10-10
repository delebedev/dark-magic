package desktop

import (
	"github.com/gravestench/dark-magic/internal/inputstate"
	"testing"
)

func TestTouchPointer(t *testing.T) {
	var pointer touchPointer
	steps := []struct {
		points  []touchPoint
		x, y    int
		action  inputstate.ActionState
		present bool
	}{
		{nil, 0, 0, inputstate.ActionState{}, false},
		{[]touchPoint{{7, 60, 105}}, 60, 105, inputstate.ActionState{Pressed: true}, true},
		{[]touchPoint{{8, 400, 200}, {7, 100, 120}}, 100, 120, inputstate.ActionState{Down: true}, true},
		{[]touchPoint{{8, 400, 200}}, 100, 120, inputstate.ActionState{Released: true}, true},
		{[]touchPoint{{8, 420, 200}}, 100, 120, inputstate.ActionState{}, true},
		{nil, 0, 0, inputstate.ActionState{}, false},
		{[]touchPoint{{9, -10, 700}}, -10, 700, inputstate.ActionState{}, true},
		{nil, 0, 0, inputstate.ActionState{}, false},
	}
	for index, step := range steps {
		x, y, action, present := pointer.sample(step.points, 800, 600)
		if x != step.x || y != step.y || action != step.action || present != step.present {
			t.Fatalf("step %d: got (%d,%d,%+v,%v), want %+v", index, x, y, action, present, step)
		}
	}
}
