package modruntime

import (
	"context"
	"reflect"
	"sync"
	"testing"
	"time"

	lua "github.com/yuin/gopher-lua"
)

func TestFeedbackModule(t *testing.T) {
	var feedback Feedback

	var played []string

	feedback.SetHandler(func(kind string) { played = append(played, kind) })
	feedback.SetEnabled(true)

	now := time.Unix(100, 0)
	feedback.Flush(now)

	runtime := New()
	if err := runtime.RegisterModule(FeedbackModule(&feedback)); err != nil {
		t.Fatal(err)
	}

	if err := runtime.Start(t.Context()); err != nil {
		t.Fatal(err)
	}

	t.Cleanup(func() { _ = runtime.Stop(context.Background()) })

	emit := func(script string) {
		t.Helper()

		if err := runtime.Run(t.Context(), func(state *lua.LState) error {
			return state.DoString(`local f=require("engine.feedback/v1"); ` + script)
		}); err != nil {
			t.Fatal(err)
		}
	}
	emit(`f.emit("activate"); f.emit("press"); f.emit("release"); f.emit("release")`)
	feedback.Flush(now)
	emit(`f.emit("release")`)
	feedback.Flush(now.Add(100 * time.Millisecond))
	feedback.Flush(now.Add(300 * time.Millisecond))

	if !reflect.DeepEqual(played, []string{"release"}) {
		t.Fatalf("coalesced/rate-limited cues replayed: %v", played)
	}

	emit(`f.emit("press")`)
	feedback.Flush(now.Add(400 * time.Millisecond))
	emit(`f.emit("activate"); f.clear()`)
	feedback.Flush(now.Add(500 * time.Millisecond))
	feedback.SetEnabled(false)
	emit(`f.emit("release")`)
	feedback.SetEnabled(true)
	emit(`f.emit("release")`)
	feedback.Flush(now.Add(time.Second))
	emit(`f.emit("activate")`)
	feedback.Flush(now.Add(2 * time.Second))
	emit(`assert(not pcall(f.emit, "unknown"))`)

	if !reflect.DeepEqual(played, []string{"release", "press", "activate"}) {
		t.Fatalf("off, reset or resumed frame leaked feedback: %v", played)
	}
}

func TestFeedbackWithoutHost(t *testing.T) {
	state := lua.NewState()
	defer state.Close()

	state.PreloadModule("engine.feedback/v1", FeedbackModule(nil).Loader)

	if err := state.DoString(`local f=require("engine.feedback/v1"); f.emit("release"); f.clear()`); err != nil {
		t.Fatal(err)
	}
}

func TestFeedbackSceneChangesDiscardCoveredCast(t *testing.T) {
	var feedback Feedback

	var played []string

	feedback.SetHandler(func(kind string) { played = append(played, kind) })
	feedback.SetEnabled(true)

	now := time.Unix(100, 0)

	feedback.SetScene("world")
	feedback.Flush(now)
	feedback.request("activate")
	feedback.Flush(now.Add(time.Second))
	feedback.SetScene("inventory")
	feedback.Flush(now.Add(2 * time.Second))
	feedback.request("activate")
	feedback.Flush(now.Add(3 * time.Second))
	feedback.SetScene("world")
	feedback.request("release")
	feedback.Flush(now.Add(4 * time.Second))
	feedback.SetScene("world")
	feedback.request("release")
	feedback.Flush(now.Add(5 * time.Second))

	if !reflect.DeepEqual(played, []string{"activate", "activate", "release"}) {
		t.Fatalf("scene transition replayed covered cast or dropped fresh input: %v", played)
	}
}

func TestFeedbackConcurrentActivity(t *testing.T) {
	var feedback Feedback

	var workers sync.WaitGroup

	feedback.SetHandler(func(string) {})

	for worker := range 3 {
		workers.Go(func() {
			for range 100 {
				switch worker {
				case 0:
					feedback.SetEnabled(false)
					feedback.SetEnabled(true)
				case 1:
					feedback.request("release")
				default:
					feedback.Flush(time.Now())
				}
			}
		})
	}

	workers.Wait()
}
