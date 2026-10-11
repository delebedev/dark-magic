//go:build ebitengine

package clientapp

import (
	"context"
	"errors"
	"sync"
	"time"

	"github.com/gravestench/dark-magic/internal/platform/desktop"
	"github.com/hajimehoshi/ebiten/v2"
)

// NewHostedGame composes the ordinary client on the Ebitengine update thread.
// The caller owns content and must stop native updates before calling Close.
func NewHostedGame(options Options) (*HostedGame, error) {
	ctx, cancel := context.WithCancel(context.Background())
	app := newApplicationWithContext(options, ctx, cancel)
	if err := app.assemble(); err != nil {
		cancel()
		return nil, errors.Join(err, app.shutdown())
	}
	game, err := desktop.EbitengineGame(app.renderer, ctx)
	if err != nil {
		cancel()
		return nil, errors.Join(err, app.shutdown())
	}
	if options.InputDiagnostics {
		width, height := app.renderer.Resolution()
		app.pointerProbe = &pointerTapProbe{width: width, height: height}
	}
	return &HostedGame{Game: game, app: app}, nil
}

// HostedGame keeps application cleanup and scene errors with the native game.
type HostedGame struct {
	ebiten.Game
	app       *application
	closeOnce sync.Once
	closeErr  error
}

func (g *HostedGame) ProbeTap(x, y int) error {
	if g.app.pointerProbe == nil {
		return errors.New("enable input diagnostics to use the tap probe")
	}
	return g.app.pointerProbe.queue(x, y)
}

func (g *HostedGame) Update() error {
	// Suspension must not advance UI animations or offline authority by minutes.
	if time.Since(g.app.lastFrame) > 250*time.Millisecond {
		g.app.lastFrame = time.Now()
	}
	err := g.Game.Update()
	select {
	case sceneErr := <-g.app.sceneErrors:
		err = errors.Join(err, sceneErr)
	default:
	}
	if err != nil {
		return errors.Join(err, g.Close())
	}
	return nil
}

func (g *HostedGame) DrawFinalScreen(screen ebiten.FinalScreen, offscreen *ebiten.Image, geoM ebiten.GeoM) {
	g.Game.(ebiten.FinalScreenDrawer).DrawFinalScreen(screen, offscreen, geoM)
}

func (g *HostedGame) Close() error {
	g.closeOnce.Do(func() {
		g.app.stop()
		g.closeErr = g.app.shutdown()
	})
	return g.closeErr
}
