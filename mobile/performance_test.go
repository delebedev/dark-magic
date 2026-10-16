//go:build ebitengine

package darkmagicmobile

import (
	"sync"
	"testing"
	"time"
)

func TestPerformanceFramesTracksPacingAndResetsAfterSuspension(t *testing.T) {
	var frames performanceFrames

	now := time.Unix(1, 0)
	frames.record(now)

	if frames.count != 0 {
		t.Fatal("disabled overlay collected frames")
	}

	frames.setEnabled(true)
	frames.record(now)

	for index := range 120 {
		interval := 16 * time.Millisecond
		if index >= 110 {
			interval = 50 * time.Millisecond
		}

		now = now.Add(interval)
		frames.record(now)
	}

	if got := frames.summary(58, now); got != "58 FPS | 50.0 ms p95" {
		t.Fatal(got)
	}

	for range 120 {
		now = now.Add(16 * time.Millisecond)
		frames.record(now)
	}

	if frames.count != 120 || frames.summary(60, now) != "60 FPS | 16.0 ms p95" {
		t.Fatal("old stalls did not leave the bounded timing window")
	}

	if frames.summary(60, now.Add(3*time.Second)) != "Waiting for frames" {
		t.Fatal("stopped game retained a live FPS reading")
	}

	frames.setEnabled(false)
	frames.setEnabled(true)

	now = now.Add(time.Hour)
	frames.record(now)

	if frames.count != 0 || frames.summary(60, now) != "Waiting for frames" {
		t.Fatal("suspension gap became a frame sample")
	}
}

func TestPerformanceFramesConcurrentSampling(t *testing.T) {
	var frames performanceFrames

	var workers sync.WaitGroup

	frames.setEnabled(true)
	workers.Go(func() {
		for range 1000 {
			frames.record(time.Now())
		}
	})
	workers.Go(func() {
		for range 1000 {
			_ = frames.summary(60, time.Now())
			frames.setEnabled(false)
			frames.setEnabled(true)
		}
	})
	workers.Wait()
}
