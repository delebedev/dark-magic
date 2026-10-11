package modruntime

import (
	"context"
	"fmt"
	"testing"

	lua "github.com/yuin/gopher-lua"
)

// TestDisplayModuleReportsLiveSurfaceSize proves responsive Lua layout observes renderer changes immediately.
func TestDisplayModuleReportsLiveSurfaceSize(t *testing.T) {
	runtime := New()
	width, height := 1920, 1080
	if err := runtime.RegisterModule(DisplayModule(func() (int, int) { return width, height })); err != nil {
		t.Fatal(err)
	}
	if err := runtime.Start(context.Background()); err != nil {
		t.Fatal(err)
	}
	defer func() { _ = runtime.Stop(context.Background()) }()
	assertSize := func(expectedWidth, expectedHeight int) {
		t.Helper()
		if err := runtime.Run(context.Background(), func(state *lua.LState) error {
			return state.DoString(fmt.Sprintf(`
local display = require("engine.display/v1")
local width, height = display.size()
assert(width == %d and height == %d)
`, expectedWidth, expectedHeight))
		}); err != nil {
			t.Fatal(err)
		}
	}
	assertSize(1920, 1080)
	width, height = 2560, 1440
	assertSize(2560, 1440)
}

func TestDisplayGeometryConvertsHostPointsAndTracksRotation(t *testing.T) {
	runtime := New()
	host := ScreenGeometry{Width: 900, Height: 400, Left: 20, Top: 10, Right: 30, Bottom: 40}
	if err := runtime.RegisterModule(DisplayModule(func() (int, int) { return 1350, 600 }, func() ScreenGeometry { return host })); err != nil {
		t.Fatal(err)
	}
	if err := runtime.Start(t.Context()); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = runtime.Stop(context.Background()) })
	check := func(script string) {
		t.Helper()
		if err := runtime.Run(t.Context(), func(state *lua.LState) error { return state.DoString(script) }); err != nil {
			t.Fatal(err)
		}
	}
	check(`local g=require("engine.display/v1").geometry(); assert(g.scale_x==1.5 and g.scale_y==1.5); assert(g.left==30 and g.top==15 and g.right==45 and g.bottom==60)`)
	host.Left, host.Right = host.Right, host.Left
	check(`local g=require("engine.display/v1").geometry(); assert(g.left==45 and g.right==30); assert(30*g.scale_y==45)`)
}
