package clientapp

import (
	"errors"
	"sync"

	"github.com/gravestench/dark-magic/internal/inputstate"
)

// Native buttons have no keyboard release event; publish one complete pulse.
type hostedActionInput struct {
	mu      sync.Mutex
	action  string
	release bool
}

func (p *hostedActionInput) queue(action string) error {
	switch action {
	case "inventory", "character", "skills", "quests", "automap", "options", "help", "cancel",
		"toggle_run", "swap_weapons":
	default:
		return errors.New("unsupported native input action")
	}

	p.mu.Lock()
	defer p.mu.Unlock()

	if p.action != "" {
		return errors.New("a native input action is still pending")
	}

	p.action = action

	return nil
}

func (p *hostedActionInput) frame(frame inputstate.Frame) inputstate.Frame {
	p.mu.Lock()
	defer p.mu.Unlock()

	if p.action == "" {
		return frame
	}

	frame.Actions = cloneActions(frame.Actions)
	action := p.action

	state := frame.Actions[action]
	if !p.release {
		state.Pressed, state.Down = true, true
		state.Released = false
		p.release = true
	} else {
		// A connected keyboard may still own the same held action.
		state.Released = !state.Down
		p.action, p.release = "", false
	}

	frame.Actions[action] = state

	return frame
}
