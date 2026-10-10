//go:build ebitengine

package darkmagicmobile

import "testing"

func TestSmokeGame(t *testing.T) {
	g := &smokeGame{}
	if err := g.Update(); err != nil || g.ticks != 1 {
		t.Fatalf("update: ticks=%d error=%v", g.ticks, err)
	}
	if width, height := g.Layout(2000, 900); width != 800 || height != 600 {
		t.Fatalf("layout: %dx%d", width, height)
	}
}
