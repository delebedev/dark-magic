//go:build ebitengine

package clientapp

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/hajimehoshi/ebiten/v2"
)

type failingHostedGame struct{ err error }

func (g failingHostedGame) Update() error            { return g.err }
func (failingHostedGame) Draw(*ebiten.Image)         {}
func (failingHostedGame) Layout(int, int) (int, int) { return 800, 600 }

func TestHostedGamePreservesSceneErrorAndClosesOnce(t *testing.T) {
	stops := 0
	app := newApplicationWithContext(Options{}, context.Background(), func() { stops++ })
	app.lastFrame = time.Now().Add(-time.Hour)
	sceneErr := errors.New("scene failed")
	app.sceneErrors <- sceneErr
	g := &HostedGame{Game: failingHostedGame{ebiten.Termination}, app: app}
	if err := g.Update(); !errors.Is(err, sceneErr) || !errors.Is(err, ebiten.Termination) {
		t.Fatalf("update discarded errors: %v", err)
	}
	if time.Since(app.lastFrame) > time.Second {
		t.Fatal("resume retained suspended elapsed time")
	}
	if err := g.Close(); err != nil || stops != 1 {
		t.Fatalf("close: stops=%d error=%v", stops, err)
	}
}
