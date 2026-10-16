//go:build ebitengine

package darkmagicmobile

import (
	"fmt"
	"sort"
	"sync"
	"sync/atomic"
	"time"

	"github.com/hajimehoshi/ebiten/v2"
)

var performance performanceFrames

// SetPerformanceOverlayEnabled bounds timing collection to visible overlay sessions.
func SetPerformanceOverlayEnabled(enabled bool) { performance.setEnabled(enabled) }

// PerformanceSummary reports draw callback intervals, not GPU execution time.
func PerformanceSummary() string { return performance.summary(ebiten.ActualFPS(), time.Now()) }

type performanceFrames struct {
	enabled atomic.Bool
	mu      sync.Mutex
	last    time.Time
	samples [120]time.Duration
	count   int
	next    int
}

func (p *performanceFrames) setEnabled(enabled bool) {
	p.mu.Lock()
	defer p.mu.Unlock()

	p.enabled.Store(enabled)
	p.last, p.count, p.next = time.Time{}, 0, 0
}

func (p *performanceFrames) record(now time.Time) {
	if !p.enabled.Load() {
		return
	}

	p.mu.Lock()
	defer p.mu.Unlock()

	if !p.enabled.Load() {
		return
	}

	if !p.last.IsZero() {
		p.samples[p.next] = now.Sub(p.last)
		p.next = (p.next + 1) % len(p.samples)
		p.count = min(p.count+1, len(p.samples))
	}

	p.last = now
}

func (p *performanceFrames) summary(fps float64, now time.Time) string {
	p.mu.Lock()
	if !p.enabled.Load() || p.count == 0 || now.Sub(p.last) > 2*time.Second {
		p.mu.Unlock()
		return "Waiting for frames"
	}

	samples := append([]time.Duration(nil), p.samples[:p.count]...)
	p.mu.Unlock()
	sort.Slice(samples, func(i, j int) bool { return samples[i] < samples[j] })
	p95 := samples[(len(samples)*95+99)/100-1]

	return fmt.Sprintf("%.0f FPS | %.1f ms p95", fps, float64(p95)/float64(time.Millisecond))
}
