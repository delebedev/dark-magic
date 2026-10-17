package modruntime

import (
	"sync"
	"time"

	lua "github.com/yuin/gopher-lua"
)

// Feedback coalesces presentation intents until the host finishes an update.
type Feedback struct {
	mu          sync.Mutex
	play        func(string)
	enabled     bool
	skipFrame   bool
	pending     string
	lastPulse   time.Time
	lastRelease time.Time
}

func (f *Feedback) SetHandler(play func(string)) {
	f.mu.Lock()
	defer f.mu.Unlock()

	f.play, f.pending = play, ""
}

// SetEnabled discards queued cues and the first resumed frame's historical events.
func (f *Feedback) SetEnabled(enabled bool) {
	f.mu.Lock()
	defer f.mu.Unlock()

	if f.enabled != enabled {
		f.enabled, f.skipFrame, f.pending = enabled, enabled, ""
	}
}

func (f *Feedback) Clear() {
	if f == nil {
		return
	}

	f.mu.Lock()
	f.pending = ""
	f.mu.Unlock()
}

func feedbackPriority(kind string) int {
	switch kind {
	case "activate":
		return 1
	case "press":
		return 2
	case "release":
		return 3
	default:
		return 0
	}
}

func (f *Feedback) request(kind string) {
	if f == nil {
		return
	}

	f.mu.Lock()
	defer f.mu.Unlock()

	if f.enabled && f.play != nil && feedbackPriority(kind) > feedbackPriority(f.pending) {
		f.pending = kind
	}
}

// Flush drops suppressed cues instead of accumulating a delayed vibration backlog.
func (f *Feedback) Flush(now time.Time) {
	f.mu.Lock()
	kind, play := f.pending, f.play
	f.pending = ""
	skip := f.skipFrame

	f.skipFrame = false
	if !f.enabled || skip || kind == "" || play == nil || now.Sub(f.lastPulse) < 80*time.Millisecond ||
		(kind == "release" && now.Sub(f.lastRelease) < 250*time.Millisecond) {
		f.mu.Unlock()
		return
	}

	f.lastPulse = now
	if kind == "release" {
		f.lastRelease = now
	}
	f.mu.Unlock()
	play(kind)
}

// FeedbackModule leaves pattern design and hardware eligibility with the native host.
func FeedbackModule(feedback *Feedback) Module {
	help := documentedModule("Request optional tactile presentation feedback.", map[string]CommandHelp{
		"emit":  commandHelp("engine.feedback.emit(kind)", "Request press, activate or release feedback."),
		"clear": commandHelp("engine.feedback.clear()", "Discard pending feedback when presentation ends."),
	})

	return Module{Name: "engine.feedback/v1", Help: help, Loader: func(state *lua.LState) int {
		module := state.SetFuncs(state.NewTable(), map[string]lua.LGFunction{
			"emit": func(state *lua.LState) int {
				kind := state.CheckString(1)
				if feedbackPriority(kind) == 0 {
					state.ArgError(1, "expected press, activate or release")
					return 0
				}

				feedback.request(kind)

				return 0
			},
			"clear": func(*lua.LState) int { feedback.Clear(); return 0 },
		})
		module.RawSetString("api", lua.LNumber(1))
		state.Push(module)

		return 1
	}}
}
