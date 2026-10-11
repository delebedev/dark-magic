package clientapp

import (
	"testing"

	"github.com/gravestench/dark-magic/internal/inputstate"
)

func TestPointerTapProbe(t *testing.T) {
	probe := &pointerTapProbe{width: 1300, height: 600}
	if err := probe.queue(1300, 500); err == nil {
		t.Fatal("accepted viewport edge")
	}
	if err := probe.queue(1100, 200); err != nil {
		t.Fatal(err)
	}
	if err := probe.queue(10, 10); err == nil {
		t.Fatal("overwrote pending gesture")
	}
	native := inputstate.Frame{Actions: map[string]inputstate.ActionState{"pointer_primary": {}}}
	for _, want := range []inputstate.ActionState{{Pressed: true, Down: true}, {Down: true}, {Released: true}} {
		got := probe.frame(native, 1300, 600)
		if got.Actions["pointer_primary"] != want || got.PointerSource != "probe" || got.CursorX != 1100 {
			t.Fatalf("probe frame: %+v", got)
		}
	}
	if native.Actions["pointer_primary"] != (inputstate.ActionState{}) {
		t.Fatal("modified native frame")
	}
	if got := probe.frame(native, 1300, 600); got.PointerSource != "" {
		t.Fatal("probe retained input ownership")
	}
	if err := probe.queue(1200, 200); err != nil {
		t.Fatal(err)
	}
	if got := probe.frame(native, 800, 600); got.PointerSource != "" {
		t.Fatal("resize retained out-of-bounds tap")
	}
}
