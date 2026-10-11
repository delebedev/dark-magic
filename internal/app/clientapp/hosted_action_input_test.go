package clientapp

import (
	"testing"

	"github.com/gravestench/dark-magic/internal/inputstate"
)

func TestHostedActionInputPulseAndFocus(t *testing.T) {
	var input hostedActionInput
	if input.queue("player.use_skill") == nil {
		t.Fatal("accepted a gameplay command")
	}
	if err := input.queue("inventory"); err != nil {
		t.Fatal(err)
	}
	if input.queue("cancel") == nil {
		t.Fatal("overwrote pending input")
	}
	native := inputstate.Frame{Actions: map[string]inputstate.ActionState{"inventory": {}}}
	press := input.frame(native)
	if !press.Actions["inventory"].Pressed || !press.Actions["inventory"].Down {
		t.Fatal("missing press")
	}
	if native.Actions["inventory"].Down {
		t.Fatal("mutated backend input")
	}
	routed := inputstate.Route(press, inputstate.FocusOwner{Domain: inputstate.FocusDebug}, true, false, "none")
	if len(routed.Actions) != 0 {
		t.Fatal("native input bypassed console focus")
	}
	release := input.frame(native)
	if release.Actions["inventory"].Down || !release.Actions["inventory"].Released {
		t.Fatal("missing release")
	}
	if input.frame(native).Actions["inventory"].Released {
		t.Fatal("repeated release")
	}
	if err := input.queue("cancel"); err != nil {
		t.Fatal(err)
	}
	input.frame(native)
	held := input.frame(inputstate.Frame{Actions: map[string]inputstate.ActionState{"cancel": {Down: true}}})
	if !held.Actions["cancel"].Down || held.Actions["cancel"].Released {
		t.Fatal("released native keyboard")
	}
}
