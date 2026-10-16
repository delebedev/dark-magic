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

Routine builds exclude `ios/Assets` from the app. Keep the same bundle identifier
when updating so the phone retains its `Documents/Assets` directory.

To seed a device once, put legally acquired classic Diablo II + LoD MPQs in ignored
`ios/Assets`, with lowercase filenames: `d2data.mpq`, `d2char.mpq`, `d2exp.mpq`,
`patch_d2.mpq`, and `d2sfx.mpq`. Build with the Xcode override
`EXCLUDED_SOURCE_FILE_NAMES=` to include them. Install and launch that seed build
before sending routine builds. Migration temporarily keeps both copies, so allow
space for another asset set until the next lean update. A phone running an older bundled-assets build
needs this migration launch before its first lean update.

First launch copies bundled assets off the main thread into a staging directory,
checks that every required archive is a readable, nonempty regular file, then
renames it to `Documents/Assets`. An interrupted staging copy is retried on the
next seed launch. Existing complete imported assets take precedence and are never
overwritten by a seed. Incomplete imported sets fail with the missing filenames.
The ordinary engine still validates archive contents when opening them.

Subsequent builds omit the override and ship only the app code. Xcode removes the
old bundled resource when switching the same derived-data directory back to a
routine build. The installed app reuses its persistent archives without copying
them again. Assets are excluded from device backups because they can be seeded
again. Uninstalling removes this data; updating in place preserves it. A fresh
lean installation needs a seed or a complete set imported through File Sharing.
The smoke binding skips asset preparation and remains asset-free.

Keep archives and original-art captures out of Git. The VFS retains patch
precedence. Preferences, profiles and asset hashing caches use Application
Support. Asset replacement is separate from app updates: close the app before
replacing its complete `Documents/Assets` set.

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
caches a missing-XCFramework or precompiled-header error after switching
bindings, clean the target or use a fresh derived-data directory.

## Scenes and lifecycle

The host defaults to the title screen. Tap once to reach the ordinary main menu,
then continue to the character roster. Shake opens a native Developer panel
with two remembered preferences: launch mode and Input
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
Gameplay keeps its own world and HUD layout. Normal startup enters the title
screen, skipping desktop startup warm-up and cinematics. The title's existing
frontend music continues through the menus and stops when game loading begins.
See [touch controls](IOS_TOUCH.md) for input, panels and diagnostic probes.

Tapping a text field opens a native iOS editor with the system keyboard. Done
applies the field's existing filter and character limit; Cancel keeps its value.
The game pauses while editing. UIKit owns keyboard presentation in
`ios/NativeTextInput.swift`; Lua controls retain validation and field ownership.

## Error reporting

Sentry is opt-in. Put your project's public ingestion DSN in ignored
`ios/Sentry.local.xcconfig` (xcconfig URLs escape the double slash):

```text
SENTRY_DSN = https:/$()/PUBLIC_KEY@HOST/PROJECT_ID
SENTRY_ORG = YOUR_ORG
SENTRY_PROJECT = YOUR_PROJECT
```

An empty DSN disables reporting. Simulator builds clear the configured DSN by
default. For a deliberate reporting check, pass `SENTRY_DSN=YOUR_DSN` on the
`xcodebuild` command line. Configured phone builds report even in Debug.
The pinned Sentry Cocoa 8.x package preserves the host's iOS 13 deployment target. The host reports native crashes and explicitly
captures startup and game-update errors, including the original Lua traceback.
Go-bound errors use their error text as the issue title. Lua errors use the
source path and cause for grouping, so changing command sequences or source line
numbers does not split the same failure. The complete original error, including
the Lua traceback and command sequence, remains in the NSError mechanism details.
Native crash grouping is unchanged.

Events carry the launch scene and a release based on the build's Git revision
(with a dirty marker for uncommitted changes). App hangs, session tracking,
automatic breadcrumbs, tracing, screenshots and view hierarchies are disabled.
No save files or assets are attached. A process crash is sent on a subsequent
launch. Handled errors can be sent while the stopped-game view remains open.

Debug and Release builds generate dSYMs. Install the current CLI with
`brew install getsentry/tools/sentry` and run `sentry auth login` once.
Browser authorization stores credentials outside the checkout and supports
refreshing OAuth tokens. The phone build phase uses that login to upload symbols.
Missing CLI/authentication warns and keeps the build usable. Upload failures fail
the build. Simulator builds skip symbol upload. CI can supply `SENTRY_AUTH_TOKEN`
instead. Keep tokens in a secret store, never in xcconfig or Git. The DSN permits
ingestion only. Authenticated agents can read errors with
`sentry issue list YOUR_ORG/YOUR_PROJECT`.
Embedded Go fatal crashes still need their own stack-reporting qualification.

## Backend limitations

The mobile host enables Ebitengine's WAV effect and music adapter. Cinematic PCM
remains muted. The optional `d2xmusic.mpq` supplies the expansion title track, while
`d2music.mpq` supplies base-game music. The required five-archive seed alone does
not contain these tracks. Import optional music archives into the same `Documents/Assets` directory when music is wanted.
An existing complete installation can also receive a seed containing only
`d2xmusic.mpq`: launch copies that archive through staging if it is missing.
Existing required and optional archives are never replaced. Subsequent builds
can return to the normal asset exclusions.
The WAV adapter accepts the pinned decoder's PCM encodings and rejects odd-sized
pre-data chunks. Cinematic audio and device-consumed PCM timing remain deferred.
Renderer palette/effect gaps are documented in [PERFORMANCE.md](PERFORMANCE.md). Automap,
quests and skill allocation retain the existing incomplete scene implementations.
UIKit may terminate a suspended process. Durable gameplay checkpoints are needed
before claiming save safety. The rendered canvas has no VoiceOver elements.

The Ebitengine Metal setup has emitted UIKit off-main-thread layer assertions.
The dependency is unpatched. Real-device input comfort, thermal load, dense combat
and long sessions need separate verification before distribution.
A Simulator build checks native compilation, not real-phone behavior.
