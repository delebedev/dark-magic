package raylibRenderer

import "testing"

// TestLogicalMonitorSizeConvertsRetinaVideoModeToWindowPoints protects visible window placement on high-DPI monitors.
func TestLogicalMonitorSizeConvertsRetinaVideoModeToWindowPoints(t *testing.T) {
	width, height := logicalMonitorSize(3024, 1964, 2, 2)
	if width != 1512 || height != 982 {
		t.Fatalf("logical monitor = %dx%d", width, height)
	}
}

// TestMacOSWindowWorkAreaKeepsClientChromeClearOfSystemUI verifies that the
// initial window is centered within Cocoa's visible frame rather than the raw mode.
func TestMacOSWindowWorkAreaKeepsClientChromeClearOfSystemUI(t *testing.T) {
	x, y, width, height := macOSWindowWorkArea(1512, 0, 1512, 982)
	if x != 1512 || y != 24 || width != 1512 || height != 866 {
		t.Fatalf("macOS work area = %d,%d %dx%d", x, y, width, height)
	}

	windowWidth, windowHeight, windowX, windowY := fitWindowToMonitor(1440, 900, width, height, x, y)
	if windowWidth != 1440 || windowHeight != 866 || windowX != 1548 || windowY != 24 {
		t.Fatalf("fitted macOS window = %d,%d %dx%d", windowX, windowY, windowWidth, windowHeight)
	}
}

// TestFitWindowToMonitorCentersWithinSecondaryDisplay covers clamping and non-primary desktop origins.
func TestFitWindowToMonitorCentersWithinSecondaryDisplay(t *testing.T) {
	width, height, x, y := fitWindowToMonitor(1600, 1000, 1512, 982, 1512, 0)
	if width != 1512 || height != 982 || x != 1512 || y != 0 {
		t.Fatalf("fit = %dx%d at %d,%d", width, height, x, y)
	}

	width, height, x, y = fitWindowToMonitor(1000, 700, 1440, 900, -1440, 40)
	if width != 1000 || height != 700 || x != -1220 || y != 140 {
		t.Fatalf("secondary fit = %dx%d at %d,%d", width, height, x, y)
	}
}

func TestDensityMapsHighDPIInputWithoutChangingLogicalSize(t *testing.T) {
	config := DefaultConfig()
	config.Resolution.Density = "2"
	service := &Service{config: &config}

	g, err := service.surfacePolicy().Resolve(1000, 600, 2000, 1200)
	if err != nil {
		t.Fatal(err)
	}

	service.surface.Store(g)

	if w, h := service.Resolution(); w != 800 || h != 600 {
		t.Fatalf("density changed logical size: %d,%d", w, h)
	}

	if w, h := service.frameResolution(); w != 1600 || h != 1200 {
		t.Fatalf("render size: %d,%d", w, h)
	}

	if x, y, inside := service.ScreenToGame(500, 300); x != 400 || y != 300 || !inside {
		t.Fatalf("host center: %d,%d %v", x, y, inside)
	}

	if _, _, inside := service.ScreenToGame(0, 300); inside {
		t.Fatal("letterbox accepted")
	}

	config.Resolution.Expand = true
	service.config = &config

	g, err = service.surfacePolicy().Resolve(900, 400, 2700, 1200)
	if err != nil {
		t.Fatal(err)
	}

	service.surface.Store(g)

	if w, h := service.Resolution(); w != 1350 || h != 600 {
		t.Fatalf("expanded size: %d,%d", w, h)
	}
}
