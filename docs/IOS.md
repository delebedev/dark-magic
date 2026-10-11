# iOS host

The experimental UIKit host binds the existing Ebitengine client. Simulation,
Lua scenes, content and retained presentation stay in their existing layers.
`mobile` is the binding composition root because gomobile generates an external
module that cannot import Go's `internal` packages directly. Engine implementation
remains internal. `clientapp.NewHostedGame` composes the ordinary offline authority.

## Build

Install full Xcode with iOS platform support and Go. From the repository root:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
./ios/build.sh
open ios/DarkMagic.xcodeproj
```

`build.sh` pins Go 1.25.12 and ebitenmobile 2.9.9 to the engine dependency. It
creates the ignored `ios/Darkmagicmobile.xcframework` for device and Simulator.
Rebind after Go/Lua changes. Use `./ios/build.sh --smoke` for an asset-free diagnostic
instead of the engine. Rebind without `--smoke` to restore the real engine.

Put legally acquired classic Diablo II + LoD MPQs in ignored `ios/Assets`, with
lowercase filenames: `d2data.mpq`, `d2char.mpq`, `d2exp.mpq`, `patch_d2.mpq`, and
`d2sfx.mpq`. Keep archives and original-art captures out of Git. The existing VFS
retains patch precedence. A Documents/Assets directory supplied through Finder
file sharing takes precedence over bundled assets. Preferences, profiles and
asset hashing caches use Application Support, never the read-only bundle.

Select the shared DarkMagic scheme and an installed iPhone Simulator. For a CLI
build, choose a derived-data directory outside the checkout:

```sh
xcodebuild -project ios/DarkMagic.xcodeproj -scheme DarkMagic \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /absolute/path/to/derived-data CODE_SIGNING_ALLOWED=NO build
```

For a phone, select your signing team in Xcode, connect the unlocked device,
enable Developer Mode and run the same scheme. Signing identities and team
settings are local. A Personal Team build may need renewal after its profile
expires. Trust the developer profile on the phone if iOS requests it. If Xcode
caches a missing-XCFramework error after regeneration, use a fresh derived-data
directory.

## Scenes and lifecycle

The host opens a scene picker: Game World · Amazon, Spell Lab, Warp Lab and UI Lab.
Force-close and reopen to select another scene. Background/resume retains the
running scene. `DARK_MAGIC_START_SCENE=game_world|spell_lab|warp_lab|ui_lab` skips
the picker. For an installed Simulator application:

```sh
SIMCTL_CHILD_DARK_MAGIC_START_SCENE=game_world \
  xcrun simctl launch --terminate-running-process booted org.darkmagic.experimental
```

Game World uses the desktop development fixture: a disposable Amazon at the
normal Act I town entry with offline authority. Process termination discards
fixture state. Spell Lab and Warp Lab retain their existing upstream fixtures.
These scenes do not establish a persistent campaign.

UIKit owns the frame loop and Ebitengine suspend/resume callbacks. The hosted
client discards large elapsed gaps, retains the session's bounded fixed-tick
clock and performs idempotent cleanup. Scene errors retain their original text
in the native error view.

World scenes keep a 600-pixel logical height and expand to the landscape aspect
ratio. The original HUD remains centered. UI Lab stays 800×600 with contain
scaling. Ebitengine supplies logical touch coordinates. No second desktop
coordinate conversion is applied. See [touch controls](IOS_TOUCH.md) for input,
panels and diagnostic probes.

## Backend limitations

Ebitengine currently discards audio mixer commands on desktop and iOS. Renderer
palette/effect gaps are documented in [PERFORMANCE.md](PERFORMANCE.md). Automap,
quests and skill allocation retain the existing incomplete scene implementations.
UIKit may terminate a suspended process. Durable gameplay checkpoints are needed
before claiming save safety. The rendered canvas has no VoiceOver elements.

The Ebitengine Metal setup has emitted UIKit off-main-thread layer assertions.
The dependency is unpatched. Real-device input comfort, thermal load, dense combat
and long sessions need separate verification before distribution.
