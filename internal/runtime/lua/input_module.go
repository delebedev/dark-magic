package modruntime

import (
	"github.com/gravestench/dark-magic/internal/inputstate"
	lua "github.com/yuin/gopher-lua"
)

// InputModule exposes frame-stable logical actions rather than backend key
// codes or direct Raylib calls.
func InputModule(input *inputstate.Store, editors ...*TextEditor) Module {
	var editor *TextEditor
	if len(editors) > 0 {
		editor = editors[0]
	}
	return Module{
		Name: "engine.input/v1",
		Help: documentedModule("Read the current normalized input frame.", map[string]CommandHelp{
			"edit_text":        commandHelp("engine.input.edit_text(value, title, secure)", "Open an optional native editor; return its request ID or zero when unavailable."),
			"text_edit_result": commandHelp("engine.input.text_edit_result(id)", "Consume a native edit result as done, accepted, value."),
			"text": commandHelp(
				"engine.input.text()",
				"Return text entered during the current frame.",
			),
			"down": commandHelp(
				"engine.input.down(action)",
				"Report whether an action is currently held.",
			),
			"pressed": commandHelp(
				"engine.input.pressed(action)",
				"Report whether an action was pressed this frame.",
			),
			"released": commandHelp(
				"engine.input.released(action)",
				"Report whether an action was released this frame.",
			),
			"pointer_source": commandHelp(
				"engine.input.pointer_source()",
				"Return native or probe for the current pointer frame.",
			),
			"contacts": commandHelp("engine.input.contacts()", "Return copied active touches with stable IDs and logical x/y coordinates."),
			"cursor": commandHelp(
				"engine.input.cursor()",
				"Return the current cursor coordinates.",
			),
			"scroll": commandHelp(
				"engine.input.scroll()",
				"Return this frame's high-resolution horizontal and vertical pointer scroll deltas.",
			),
			"owner": commandHelp(
				"engine.input.owner()",
				"Return the current input focus domain and owner ID.",
			),
		}),
		Loader: func(state *lua.LState) int {
			module := state.SetFuncs(state.NewTable(), map[string]lua.LGFunction{
				"edit_text": func(state *lua.LState) int {
					id, err := editor.Begin(state.CheckString(1), state.CheckString(2), state.OptBool(3, false))
					if err != nil {
						state.RaiseError("%v", err)
						return 0
					}
					state.Push(lua.LNumber(id))
					return 1
				},
				"text_edit_result": func(state *lua.LState) int {
					done, accepted, value := editor.Result(int64(state.CheckNumber(1)))
					state.Push(lua.LBool(done))
					state.Push(lua.LBool(accepted))
					state.Push(lua.LString(value))
					return 3
				},
				"text": func(state *lua.LState) int {
					state.Push(lua.LString(input.Text()))
					return 1
				},
				"down": func(state *lua.LState) int {
					action := input.Action(state.CheckString(1))
					state.Push(lua.LBool(action.Down || action.Pressed))

					return 1
				},
				"pressed": func(state *lua.LState) int {
					action := input.Action(state.CheckString(1))
					state.Push(lua.LBool(action.Pressed))

					return 1
				},
				"released": func(state *lua.LState) int {
					action := input.Action(state.CheckString(1))
					state.Push(lua.LBool(action.Released))

					return 1
				},
				"pointer_source": func(state *lua.LState) int {
					source := input.Snapshot().PointerSource
					if source == "" {
						source = "native"
					}
					state.Push(lua.LString(source))
					return 1
				},
				"contacts": func(state *lua.LState) int {
					contacts := state.NewTable()
					for _, point := range input.Snapshot().Contacts {
						entry := state.NewTable()
						entry.RawSetString("id", lua.LNumber(point.ID))
						entry.RawSetString("x", lua.LNumber(point.X))
						entry.RawSetString("y", lua.LNumber(point.Y))
						contacts.Append(entry)
					}
					state.Push(contacts)
					return 1
				},
				"cursor": func(state *lua.LState) int {
					x, y := input.Cursor()
					state.Push(lua.LNumber(x))
					state.Push(lua.LNumber(y))

					return 2
				},
				"scroll": func(state *lua.LState) int {
					x, y := input.Scroll()
					state.Push(lua.LNumber(x))
					state.Push(lua.LNumber(y))

					return 2
				},
				"owner": func(state *lua.LState) int {
					owner := input.Owner()
					state.Push(lua.LString(owner.Domain))
					state.Push(lua.LString(owner.ID))

					return 2
				},
			})
			module.RawSetString("api", lua.LNumber(1))
			state.Push(module)

			return 1
		},
	}
}
