# iOS host

`codex/mobile-ui-loop` is this fork's documented mobile integration branch.
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
on mobile branches and pull requests into `codex/mobile-ui-loop`.

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

World scenes keep a 600-pixel logical height and expand to the landscape aspect
ratio. The original HUD remains centered. Normal launches and UI Lab stay 800×600 with contain
scaling. Normal launch enters the main menu directly, skipping desktop startup warm-up. Ebitengine supplies logical touch coordinates. No second desktop
coordinate conversion is applied. See [touch controls](IOS_TOUCH.md) for input,
panels and diagnostic probes.

## Review workflow

Open iPhone-related PRs in `delebedev/dark-magic` against
`codex/mobile-ui-loop` for Denis to review. Keep the historical mobile baseline
and develop each change on a feature branch. Upstream extraction is separate.

Use a concise body specific to the change until a fork template is agreed.
Explain the user-visible problem and result, plus any consequential constraint.
Attach a short video for visible UI changes, showing the action and its result.
State Simulator or physical iPhone, any fixture, and material untested behavior.
Touch, lifecycle, persistence and performance claims require matching evidence.
Build success alone proves compilation. Keep raw logs and exact check commands
in private receipts; include only useful observed outcomes in the PR.

GitHub CLI provides native media attachments through `--attach`. Check local
`gh pr create --help` before submission. Write the body to a file, with a video
reference alone in its paragraph, then pass that same absolute path:

```sh
gh pr create -R delebedev/dark-magic --base codex/mobile-ui-loop \
  --head YOUR_FEATURE_BRANCH --title 'Concrete visible change' \
  --body-file /absolute/path/pr-body.md \
  --attach /absolute/path/review.mp4
```

The body can contain `![](/absolute/path/review.mp4)` where the video belongs.
GitHub replaces it with an uploaded attachment that renders as a player.
Read back the PR body and verify the uploaded attachment. If upload partly
fails, inspect whether the PR was created before retrying. Upload only curated,
reviewed media; keep assets, saves, device identifiers and raw evidence private.
Native iPhone tooling does not need the upstream retail-comparison layout.

OTA installation happens only when Denis requests it. Simulator evidence is the
default; avoid offering OTA or asking for phone/network changes during ordinary
implementation and review. Physical-device checks require separate access and
must be reported separately from Simulator results.

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
