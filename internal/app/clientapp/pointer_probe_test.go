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

func TestContactProbe(t *testing.T) {
	p := &pointerTapProbe{width: 1304, height: 600}
	for _, bad := range []string{`[]`, `[{"Frames":1,"Contacts":[{"ID":1,"X":1304,"Y":0}]}]`, `[{"Frames":601}]`, `[{"Frames":1,"Contacts":[{"ID":1,"X":10,"Y":10},{"ID":1,"X":20,"Y":10}]},{"Frames":1}]`} {
		if err := p.queueContacts(bad); err == nil {
			t.Fatalf("accepted %s", bad)
		}
	}
	if err := p.queueContacts(`[{"Frames":2,"Contacts":[{"ID":1,"X":210,"Y":406},{"ID":2,"X":1152,"Y":406}]},{"Frames":1}]`); err != nil {
		t.Fatal(err)
	}
	if err := p.queue(10, 10); err == nil {
		t.Fatal("tap overwrote contacts")
	}
	native := inputstate.Frame{Actions: map[string]inputstate.ActionState{"pointer_primary": {Pressed: true}}}
	for _, count := range []int{2, 2, 0} {
		frame := p.frame(native, 1304, 600)
		if len(frame.Contacts) != count || frame.PointerSource != "probe" || frame.Actions["pointer_primary"].Pressed {
			t.Fatalf("bad probe frame %+v", frame)
		}
	}
	if !native.Actions["pointer_primary"].Pressed {
		t.Fatal("mutated native actions")
	}
	if p.frame(native, 1304, 600).PointerSource != "" {
		t.Fatal("retained probe ownership")
	}
}
