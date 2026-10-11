package desktop

import "testing"

func TestExpandedResolution(t *testing.T) {
	for _, tc := range []struct{ outsideWidth, outsideHeight, wantWidth int }{
		{800, 600, 800}, {1920, 1080, 1067}, {2622, 1206, 1304}, {600, 800, 800}, {0, 600, 800},
	} {
		width, height := expandedResolution(800, 600, tc.outsideWidth, tc.outsideHeight)
		if width != tc.wantWidth || height != 600 {
			t.Fatalf("%+v: got %dx%d", tc, width, height)
		}
		if tc.outsideWidth > tc.outsideHeight {
			view, err := calculateViewport(tc.outsideWidth, tc.outsideHeight, width, height, "contain")
			if err != nil || view.x > 1 || view.y > 1 {
				t.Fatalf("expanded viewport: %+v, %v", view, err)
			}
		}
	}
}
