package modruntime

import lua "github.com/yuin/gopher-lua"

// ScreenGeometry contains host point dimensions and safe-area insets.
type ScreenGeometry struct {
	Width, Height, Left, Top, Right, Bottom float64
}

// DisplayModule exposes the current renderable surface without exposing a
// platform window handle. Responsive scenes use it to lay out native-pixel
// workspaces while input remains in the same coordinate space.
func DisplayModule(size func() (width, height int), geometry ...func() ScreenGeometry) Module {
	help := documentedModule("Inspect the current logical or native render surface.", map[string]CommandHelp{
		"size":     commandHelp("engine.display.size()", "Return the current render surface width and height."),
		"geometry": commandHelp("engine.display.geometry()", "Return point scaling and safe-area insets in logical coordinates."),
	})

	return Module{Name: "engine.display/v1", Help: help, Loader: func(state *lua.LState) int {
		module := state.SetFuncs(state.NewTable(), map[string]lua.LGFunction{
			"geometry": func(state *lua.LState) int {
				width, height := 0, 0
				if size != nil {
					width, height = size()
				}
				scaleX, scaleY := 1.0, 1.0
				var host ScreenGeometry
				if len(geometry) > 0 && geometry[0] != nil {
					host = geometry[0]()
					if host.Width > 0 && host.Height > 0 {
						scaleX, scaleY = float64(width)/host.Width, float64(height)/host.Height
					}
				}
				value := state.NewTable()
				for key, number := range map[string]float64{
					"scale_x": scaleX, "scale_y": scaleY,
					"left": host.Left * scaleX, "top": host.Top * scaleY,
					"right": host.Right * scaleX, "bottom": host.Bottom * scaleY,
				} {
					value.RawSetString(key, lua.LNumber(number))
				}
				state.Push(value)
				return 1
			},
			"size": func(state *lua.LState) int {
				width, height := 0, 0
				if size != nil {
					width, height = size()
				}
				state.Push(lua.LNumber(width))
				state.Push(lua.LNumber(height))
				return 2
			},
		})
		module.RawSetString("api", lua.LNumber(1))
		state.Push(module)
		return 1
	}}
}
