# iOS host

`mobile` is this fork's documented mobile integration branch.
Upstream `main` remains the reference for shared engine behavior.

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
The smoke binding needs no Diablo assets and shows a touch marker rather than
gameplay. The Xcode build also needs no assets; launching gameplay does.

Run `make test-mobile` to check native launch preferences, Ebitengine-tagged
mobile Go packages and the focused shared hosted-input tests.
Default `make test` excludes them. The fork's Mobile workflow runs that target
on mobile branches and pull requests into `mobile`.

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

The host defaults to the ordinary main menu and character roster. Shake opens a
native Developer panel with two remembered preferences: launch mode and Input
diagnostics. Launch modes are Normal game, Game World · Amazon, Spell Lab, Warp
Lab and UI Lab. Changes apply after force-closing and reopening the app. The
panel pauses the game until Done, including across background/foreground changes.
It remains available in optimized private builds.

Agents can open the same panel in a running process through LLDB. After attaching:

```text
expression -l objc++ -- @import UIKit
expression -l objc++ -- (void)[(NSObject *)[[UIApplication sharedApplication] delegate] performSelectorOnMainThread:NSSelectorFromString(@"showDeveloperPanel") withObject:nil waitUntilDone:NO]
process detach
```

The presenter also dispatches calls made off the main thread. Simulator shake is
Control-Command-Z. Native controls expose `developer.*` accessibility identifiers.
Debugger attachment on a physical phone requires a separately qualified connection.

`DARK_MAGIC_START_SCENE=normal|game_world|spell_lab|warp_lab|ui_lab` and
`DARK_MAGIC_INPUT_DIAGNOSTICS=0|1` override remembered values for that process.
They do not replace saved preferences. For an installed Simulator application:

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

The mobile surface keeps a 600-pixel logical height and expands to the landscape
aspect ratio, including after ordinary menu-to-game transitions. UI Lab alone
retains the fixed 800×600 diagnostic canvas.

Lobby screens share `d2legacy.ui.frontend_layout`, selected by the scene registry.
It centers the authored 800×600 controls inside the safe area, scales them down
uniformly when needed, and applies the inverse transform to pointer hit testing
and the software cursor. Tiled backgrounds preserve their authored center, including baked-in labels,
over a dimmed, uniformly scaled backdrop filling the surrounding space. Character
selection and creation instead cover the canvas with their background art, without
the framed center and side panels. Resize updates cancel an old control capture.
Gameplay keeps its own world and HUD layout. Normal startup enters the main menu
directly, skipping desktop startup warm-up. See [touch controls](IOS_TOUCH.md)
for input, panels and diagnostic probes.

Tapping a text field opens a native iOS editor with the system keyboard. Done
applies the field's existing filter and character limit; Cancel keeps its value.
The game pauses while editing. UIKit owns keyboard presentation in
`ios/NativeTextInput.swift`; Lua controls retain validation and field ownership.

## Backend limitations

Ebitengine currently discards audio mixer commands on desktop and iOS. Renderer
palette/effect gaps are documented in [PERFORMANCE.md](PERFORMANCE.md). Automap,
quests and skill allocation retain the existing incomplete scene implementations.
UIKit may terminate a suspended process. Durable gameplay checkpoints are needed
before claiming save safety. The rendered canvas has no VoiceOver elements.

The Ebitengine Metal setup has emitted UIKit off-main-thread layer assertions.
The dependency is unpatched. Real-device input comfort, thermal load, dense combat
and long sessions need separate verification before distribution.
A Simulator build checks native compilation, not real-phone behavior.
