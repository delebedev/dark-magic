//go:build ios && ebitengine

package darkmagicmobile

import "github.com/hajimehoshi/ebiten/v2/mobile"

func init() { mobile.SetGame(&smokeGame{}) }
