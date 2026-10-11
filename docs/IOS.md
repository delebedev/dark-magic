# Experimental iOS port

This branch explores Ebitengine plus a UIKit host. It is not a playable mobile
Diablo II release. M1 is demonstrated for the existing `ui_lab` scene. The first
M2 slice runs the existing `game_world` scene with a disposable Amazon in Act I
town. Touch movement, camera follow, and background/resume work in the Simulator.
The user also confirms town rendering and movement on the physical iPhone.
The next [Game World parity slice](IOS_GAME_WORLD.md) adds native access to
existing panel hotkeys and verifies ordinary exit travel and Amazon melee in
the Simulator.

## Status and feasibility

Observed on 2026-10-10:

Upstream baseline: `9d450c5d452198dec4fd9d53f9c6a9e1b0145334`.

- Desktop Ebitengine client compiles with Go 1.25.12 and Ebitengine 2.9.9.
- Desktop `--start-scene ui_lab` runs with MPQs extracted from full local
  installers. The existing capture pipeline records an 800x600 original-art
  frame with authored buttons, fonts, checkbox, and slider. Its SHA-256 is
  `64e8c3a1fb3a4b6d5238721c2724118fd0dd9e64b753414e30f4261e5b392528`.
- iOS/arm64 package resolution succeeds. The 410-package graph contains no
  Raylib, FFmpeg/astiav, desktop GLFW, or Bubble Tea dependency. QUIC and pgx
  remain reachable through existing client composition. This is dependency
  analysis; native binding compilation also succeeds.
- Both smoke and real-engine bindings compile into iPhone arm64 and Simulator
  arm64/x86_64 XCFramework slices with Xcode 26.6 and the iOS 26.5 SDK.
- Objective-C binding generation confirms the native Configure signature.
  The Swift/UIKit host type-checks and links with the real binding for arm64
  iPhone and Simulator. The real-engine Xcode Simulator app builds successfully.
  The smoke device app builds with a local development signature and passes
  `codesign --verify --deep --strict`. Installation succeeds on a paired physical
  iPhone 16 Pro running iOS 26.6.2 after unlocking it. Initial launch is denied
  until the user trusts the developer profile on the phone. After that,
  `devicectl` launches the app successfully. The user confirms the diagnostic
  title, increasing ticks, a white marker following drag input, changing touch
  coordinates, and successful background/resume. Physical-screen evidence is
  user-reported; no phone screenshot or runtime console capture was collected.
- The real-engine app then builds, installs, and launches on that same phone
  with five original MPQs bundled. The user confirms `UI LAB`, the stone
  `AUTHORED BUTTON`, gold checkbox, skull slider, and working button-release
  activation and slider drag. It uses the unchanged existing scene and normal
  in-process authoritative client composition. The user also confirms button
  interaction with Airplane Mode enabled and Wi-Fi disabled, then successful
  rendering and button interaction after backgrounding and returning. No
  separate network service is required for this scene.
- Desktop `game_world` renders town with the upstream development character and
  completes the existing `--fixture-pointer-move` acceptance before capture.
  On an iPhone 17 Pro Simulator running iOS 26.5, the same scene renders original
  terrain, Amazon animation, and HUD. Ground gestures move the character in both
  directions while terrain shifts under the centered camera. Backgrounding for
  at least five seconds and returning preserves process 48726 and the town
  position; subsequent gestures still move the character. Some very short
  automated taps require repeating. Input reliability needs hardware checking.
- The default-town build installs on the same physical iPhone 16 Pro and launches
  after unlocking it. The user confirms town, Amazon, health/mana HUD, and ground
  tap/hold movement with camera follow. This is user-reported hardware acceptance;
  gameplay background/resume, collision boundaries, and performance on the phone
  remain unverified. Full M2 is not complete because transitions are unchecked.
- Targeted Go checks cover the application, command, content, input, session,
  hosted lifecycle/error propagation, touch translation, and smoke diagnostic.
  Architecture checks pass. With the extracted MPQs, the real-content check
  reads the patched sets table and lists 263 DT1 and 2,276 DS1 assets.
- Xcode builds and installs the smoke app. On an iPhone 17 Pro Simulator running
  iOS 26.4.1, the 800x600 diagnostic renders with landscape letterboxing, ticks
  advance, a drag changes touch coordinates to `(205, 202)`, and the white marker
  follows. Backgrounding for five seconds and returning preserves the process
  and touch state. This is Simulator input, not a physical-device touch test.
- Startup logs contain UIKit main-thread assertions from Ebitengine's Metal
  `addSublayer` call. Rendering continues, but this is an unresolved renderer issue.
- **M0 and M1 are demonstrated for this UI slice.** Desktop and Simulator checks
  run; the user confirms the existing original-art scene, basic touch input,
  offline interaction, and background/resume on the iPhone. The installer asset
  directories identify themselves as 1.14b; 1.14d asset parity and the remaining
  hardware stress checks have not been verified.

The Mac initially had roughly 20 GiB free and only Command Line Tools selected.
Full Xcode was not found in Applications or the Spotlight application index.
Go and the pinned ebitenmobile tool were installed for investigation. After
space was freed, the App Store installed the last compatible Xcode version,
26.6 (17F113), on macOS 26.5.1. First-launch components are installed. An existing
iOS 26.4.1 runtime works for smoke testing; iOS 26.5 platform support and its
Simulator runtime are also installed. About 14 GiB remains free after installation.
The global developer-directory selection is preserved; builds use
`DEVELOPER_DIR` explicitly.

Local evidence is ignored under `.local/`: `ios-smoke-touch.png`,
`ios-smoke-resumed.png`, `ios-smoke-runtime.log`, `ios-real-bind.log`,
`ios-host-link.log`, `ios-device-host-link.log`, `ios-real-build.log`, and
`ios-smoke-device-build.log`, plus `ios-device-install.json` and
`ios-device-launch.json`. Native screenshots retain
the Simulator display's portrait pixel orientation; the UI window was landscape.
Real-scene evidence: `.local/desktop-lod-ui-lab/01-ui_lab.png`, its `report.json`,
`.local/desktop-lod-capture.log`, `.local/ios-lod-device-build.log`,
`.local/ios-lod-device-install.json`, `.local/ios-lod-device-launch.json`, and
`.local/ios-lod-device-processes.json`. Physical visual/input acceptance is the
user's confirmation in this conversation, not an agent-observed phone screenshot.
Town evidence: `.local/desktop-town/01-game_world.png` and `report.json`,
`.local/desktop-town.log`, `.local/ios-town-before.png`, `ios-town-moved.png`,
`ios-town-before-resume.png`, `ios-town-resumed.png`, `ios-town-resumed-moved.png`,
and `.local/ios-world-sim.stderr`. Native town builds and device installation
are recorded in `.local/ios-world-default-{sim,device}-build.log` and
`.local/ios-world-default-device-install-retry.json`.
The default Simulator launch is captured in `.local/ios-town-default.png`.
The explicit `ui_lab` override also renders in the Simulator. Hardware launch
is recorded in `.local/ios-town-default-device-launch.json`; visual/movement
acceptance is the user's confirmation in this conversation.

### Advanced labs, 2026-10-11

The mobile entry point also admits upstream `spell_lab` and `warp_lab`. Their
existing development-scene defaults supply disposable characters, skill loadout,
monsters, and portal fixtures. No mobile simulation or replacement gameplay was
added. The Configure binding takes the selected scene explicitly, with matching
real/smoke signatures and validation before configuration is committed.

Observed in the iOS 26.5 Simulator: Spell Lab renders Blood Moor, the Sorceress,
three hostiles, and the original HUD. Ground input moves her. Targeted primary
input produces an orange Fire Bolt effect and dead hostile sprites. After
backgrounding for five seconds and returning to the same process, another
cast kills a hostile. Evidence: `.local/ios-spell-combat.mov`,
`ios-spell-kill.png`, and `ios-spell-resumed-kill.png`.

The upstream real-asset authority tests for production spell families and warp
movement/transitions pass. Those tests are headless evidence, not live iOS proof
of other skills or portal crossings. Spell Lab uses a level-30 Sorceress with
43 implemented exact-ID skills and a deep mana fixture that replenishes mana.
It does not demonstrate normal retail mana regeneration or progression.

The skill chooser did not open during automated Simulator well taps, including
some complete press/release events. The cause remains unconfirmed. Secondary
skill touch input was not mapped in that build. Direct touch skills are now
described in [IOS_TOUCH.md](IOS_TOUCH.md). Summons and live portal
crossings remain unverified. Temporary input/control traces were removed before
packaging the phone build.

The final native scene picker renders in the Simulator. Choosing Spell Lab
launches its original scene, and terminating/relaunching returns to the picker.
Choosing Warp Lab also renders town, the Amazon, the blue portal, and its
read-only crossing diagnostics.
The same signed build installs and launches on the paired iPhone 16 Pro.
Hardware lab interaction is awaiting user testing. Build/install evidence:
`.local/ios-labs-picker-{sim,device}-build.log`,
`ios-labs-picker-device-install.json`, and `ios-labs-picker-device-launch.json`.
Picker/selected-scene evidence: `ios-labs-picker.png` and
`ios-spell-picker-launch.png`, and `ios-warp-picker-launch.png`.
Targeted real/smoke binding tests pass.

### Full installer extraction on the Mac

The user's Downloads folder contains complete base and expansion
`Installer Tome.mpq` archives. Unlike the small Blizzard downloader EXE, these
contain the finished game archives under `Common`. `ios/extract-installer.py`
uses the already-installed StormLib host tool to extract eleven MPQs directly.
No Wine, CrossOver, Windows, installer execution, or key-file processing is needed.

```sh
brew install stormlib
python3 ios/extract-installer.py \
  '/path/to/Diablo II/Installer Tome.mpq' \
  '/path/to/LoD/Installer Tome.mpq' \
  '/path/outside/git/lod'
```

The output must be new and outside Git. The tool checks extracted sizes, opens
each nested MPQ, and records SHA-256 hashes. It selects the expansion's
`patch_d2.mpq` rather than the base patch. Existing assets are never overwritten.
Failure can leave a partial output for inspection; choose a new output path
for another attempt. Locally, extraction is saved in `~/src/dark-magic-assets/lod`.

The installer folders identify their asset snapshot as 1.14b. The accompanying
1.14d patch executable contains binary deltas, not ready-to-copy replacement
MPQs. It was inspected but not run or applied. Original 1.14d gameplay parity
is therefore not established by this UI experiment. The normal desktop client
and real iPhone `ui_lab` do work with the extracted snapshot.

### Downloaded demo

An intact, archived Blizzard Macintosh shareware demo was downloaded separately
from the code. Its archive checksum matches the mirror's published value:
`7a026c82ceb30ac2c3764c9cd8445822e71eeee2b51d7bca48b96a89a9254d06`.

Sources: [demo archive and provenance](https://systemless.org/diablo-ii/),
[Blizzard's included shareware readme](https://static.classicmacdemos.com/demos/diablo-ii/README.html).
The demo's distribution terms do not establish permission to redistribute an
iOS application containing its extracted artwork. Assets stay outside Git.

The Mac demo has MPQ data forks with names such as `Diablo II Game Data`,
`Diablo II Graphics`, and `Diablo II Patch`. Local symlinks named `d2data.mpq`,
`d2char.mpq`, and `patch_d2.mpq` let the existing loader inspect these archives.
Their listfiles are readable. They do not provide the required expansion asset
`data/global/ui/FrontEnd/trademarkscreenEXP.dc6`.

The demo patch lists `data/GLOBAL/UI/FrontEnd/trademark.DC6` and
`data/global/ui/FrontEnd/3WideButtonBlank.dc6`. Attempts to read either through
the existing MPQ decoder fail with `decryption of MPQ failed`. StormLib 9.40
can read these assets. The cause in the Go decoder has not been verified.
No engine codec fix or substitute expansion art is included.
The base archive's `data/global/missiles/arrow.dcc` does decode and produces a
headless diagnostic PNG with the decoder's fallback palette. That proves some
real demo content is readable, not that a scene or its authored colors work.
The host extraction tool below reads 159 original assets into a 13 MiB loose
directory, including authored fonts, palettes, and the three-wide button.
116 other literal asset references are absent from this demo. Its generated
presentation extension points the unused title background at the original
classic title. It changes no scene or gameplay code.

The normal desktop client then fails with:

```text
load class movement rates: d2legacy movement: data/global/excel/charstats.txt row 2 class "Amazon" has invalid movement/stamina facts
```

The demo's older CharStats table has no stamina column. Normal client assembly
loads the movement catalog even for `ui_lab`. Inventing gameplay values would
hide incompatibility, so this experiment stops there. The demo profile is not
wired into the mobile entry point. The supported real-scene path still needs
compatible original LoD MPQs. Evidence: `.local/desktop-demo-ui-lab.log`.

To reproduce the extraction and desktop compatibility probe:

```sh
brew install stormlib
python3 ios/prepare-demo.py /path/to/demo-mpq-symlinks /path/outside/git/demo-loose
export GOTOOLCHAIN=go1.25.12
export DARK_MAGIC_MOD_CACHE="$PWD/.local/demo-modcache"
export DARK_MAGIC_MOD_PROFILE="$PWD/.local/demo-mods.json"
go run ./internal/dev/tools/demo_profile -source /path/outside/git/demo-loose/demo-profile
MPQ_DIRECTORY=/path/outside/git/demo-loose \
  go run -tags ebitengine ./cmd/client --mods d2demo_profile --start-scene ui_lab
```

StormLib is a host extraction tool, not an iOS dependency. The output must be
a new directory outside Git or the ignored `ios/Assets` directory. Existing
assets are never overwritten. The final command currently reports the error
above; it is a compatibility probe, not a working scene workaround.

## Implementation decisions

- `mobile` is a native binding composition root, not a supported engine library.
  gomobile generates an external `gobind` module, so the bound package must be
  outside Go's `internal` import restriction. Engine implementation stays internal.
- `clientapp.NewHostedGame` reuses normal application assembly, Lua scenes,
  retained composition, and authoritative offline session. UIKit owns the loop
  instead of calling desktop `RunGame`. There is no separate mobile simulation.
- The desktop executable keeps its signal handling. The hosted client has a
  cancellable context and idempotent cleanup. Scene failures retain their original
  errors and shut down application consumers before closing mounted content.
- M1 used the unchanged `ui_lab`. The default now starts the unchanged
  `game_world` with `FixtureCharacters=1` and `FixtureWorldLevel=1`, exactly as
  desktop development runs do. The existing fixture selects an ephemeral Amazon
  and activates ordinary offline authority. It disables profile persistence,
  so this slice resets after process termination and cannot replace real saves.
  `DARK_MAGIC_START_SCENE=ui_lab` still selects the M1 scene without a fixture.
- A separate `mobile/smoke` binding is an explicit asset-free M0 diagnostic.
  Its screen identifies itself as a smoke test with no Diablo assets or gameplay.
- Touch IDs are translated to existing `pointer_primary` press/hold/release
  snapshots. The first finger retains ownership until release. Remaining fingers
  cannot become a new click until all are lifted. Ebitengine supplies logical
  coordinates; do not apply desktop screen conversion again. Initial touches in
  letterboxing are rejected. Touch keyboard/text entry and gestures are deferred.
- The authored logical surface stays 800x600 with aspect-preserving letterboxing
  and nearest filtering. UIKit restricts the phone host to landscape.
- MPQs are read from a bundled `Assets` folder, or `Documents/Assets` when present.
  The existing VFS keeps patch precedence. Preferences, profile, and asset hash
  cache go into Application Support, never the read-only bundle.
- UIKit resign/active callbacks call Ebitengine suspend/resume. Large elapsed gaps
  are discarded for presentation and hosted application stepping. The existing
  session retains its bounded fixed-tick clock. Smoke and real UI background/resume
  work on hardware according to the user. Lock/unlock, process termination, and
  gameplay-state persistence remain unverified.

## Build and run

Install Go, full Xcode, and its iOS platform support. Select that developer directory
or set `DEVELOPER_DIR` for this shell. Preserve any existing machine configuration:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-path
```

From the repository root, create the M0 framework first:

```sh
./ios/build.sh --smoke
open ios/DarkMagic.xcodeproj
```

The script pins Go 1.25.12 and ebitenmobile 2.9.9 to match the engine dependency.
It builds device and Simulator slices into ignored `ios/Darkmagicmobile.xcframework`.
The framework name matches gomobile's generated `Darkmagicmobile` module so
Swift can discover it without manual module-map flags.
Do not install `ebitenmobile@latest` independently of an engine upgrade.

Select the shared `DarkMagic` scheme and an installed iPhone Simulator in Xcode.
Run. Expected evidence: the M0 diagnostic shows increasing ticks and updates its
touch coordinates/marker. This checks UIKit, Metal, input, and Go integration.
It does not count as a Dark Magic scene.

A command-line Simulator build, after binding:

```sh
xcodebuild -project ios/DarkMagic.xcodeproj -scheme DarkMagic \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ios/build CODE_SIGNING_ALLOWED=NO build
```

For the real scenes, copy extracted original LoD MPQs into `ios/Assets` with lowercase
archive filenames, including `d2data.mpq`, `d2char.mpq`, `d2exp.mpq`, and
`patch_d2.mpq`. This experiment also bundles `d2sfx.mpq`. These five archives total
834,011,197 bytes. The other six archives remain outside the checkout; native
audio is disabled and this scene needs no cinematics. These files are ignored.
Rebuild the framework:

```sh
./ios/build.sh
open ios/DarkMagic.xcodeproj
```

The UIKit host now opens a scene picker: Town, Spell Lab, Warp Lab, and UI Lab.
Choose Town for Act I with the disposable Amazon. Tap ground
to move, or hold/drag to keep issuing the existing pointer movement command.
The existing camera follows the character. Audio is muted. Closing the process
discards this development character and its position.

To repeat M1, set `DARK_MAGIC_START_SCENE=ui_lab` in the Xcode scheme's Run
environment, or launch the installed Simulator app with:

```sh
SIMCTL_CHILD_DARK_MAGIC_START_SCENE=ui_lab \
  xcrun simctl launch --terminate-running-process booted org.darkmagic.experimental
```

Omit that environment variable for the picker. Force-close the app and reopen
to choose another scene. Backgrounding and returning keeps the running scene.
Scene selection is passed directly to the Go Configure binding; the native host
does not change gameplay or restart Ebitengine in-process.

Alternatively, install the app and use Finder file sharing to copy an `Assets`
folder into Dark Magic's Documents directory. Relaunch the app. An existing
Documents/Assets directory takes precedence over the bundled folder.

For an unsigned installed Simulator app, its Documents location is available via:

```sh
xcrun simctl get_app_container booted org.darkmagic.experimental data
```

For a physical phone, select a signing team and unique bundle identifier in
Xcode, connect/pair the phone, enable Developer Mode as required, and run the
same scheme. Signing credentials and team settings are intentionally not committed.
Keep the phone unlocked while Xcode mounts its Developer Disk Image. If the
installed app reports an untrusted developer, open Settings > General > VPN &
Device Management on the phone and trust/verify your Developer App profile.
The local Personal Team profile used for this experiment expires on 2026-10-17;
rebuild and reinstall with a renewed profile after expiry.

First verify the desktop scene with the same asset set:

```sh
MPQ_DIRECTORY=/path/to/original-lod-mpqs GOTOOLCHAIN=go1.25.12 \
  go run -tags ebitengine ./cmd/client --start-scene ui_lab
```

## Acceptance before M2

Record device/OS, asset version, build revision, screenshot, and observed results:

1. Desktop `ui_lab` renders authored buttons/fonts with those original assets.
2. Simulator smoke launches, accepts input, backgrounds, and resumes.
3. Physical iPhone displays unchanged `ui_lab` with original art at correct aspect.
4. Tap AUTHORED BUTTON. Its existing status line shows activation after release.
   Drag the slider. Test letterboxing, a second finger, rotation between landscape
   sides, lock/unlock, and background/resume without a stuck pointer or time jump.
5. Repeat in airplane mode. Inspect Xcode console for scene/render errors.

## Wide viewport and input diagnostics

World scenes keep a 600-pixel logical height and expand horizontally to the
landscape drawable's aspect ratio. The original 800-wide HUD stays centered,
with its control hit tests translated by the same offset. Camera anchoring,
chunk residency, pointer projection, and overlay input splits use the live
display width. UI Lab retains its authored 800×600 contain profile.

Launch the development probe with:

```sh
SIMCTL_CHILD_DARK_MAGIC_START_SCENE=spell_lab \
SIMCTL_CHILD_DARK_MAGIC_INPUT_DIAGNOSTICS=1 \
  xcrun simctl launch --terminate-running-process booted org.darkmagic.experimental
```

The native Probe X / Probe Y fields accept logical pixel coordinates. Probe tap
queues a press, hold, and release across three ordinary client input frames.
Coordinates outside the live viewport and overlapping pending taps are rejected.
The probe never calls simulation commands directly. The diagnostic strip reports
viewport size, last pointer source/coordinates, press/release counts, HUD activation,
last submitted world intent, and the authoritative player position. The gold
crosshair marks the last pointer event. The source explicitly distinguishes probe
input from native input.

These controls are opt-in and live above the Ebitengine view in a UIKit container.
Their accessibility labels allow repeatable Simulator automation. Game canvas
controls already have Lua accessibility descriptions, but those descriptions are
not bridged to UIKit accessibility. Probe evidence proves logical input routing
and gameplay response. It does not replace hardware touch or VoiceOver acceptance.

The first probe found an upstream HUD bug: entity handles are distinct Lua values,
so comparing a learned skill's owner handle directly with the player dropped all
learned skills from the HUD snapshot. Comparing entity IDs preserves ownership.
The skill chooser also used a comparator that could return true in both directions
for the left side. Its ordering now selects an explicit ascending or descending
comparison and respects each side’s allowed-skill flag. Icons use the existing
asset preloader and are admitted four at a time. Hidden skill tooltips are created
only when shown, avoiding a cold asset-decode burst when the player enters the scene.
Skill presentation indexes immutable record tables once and returns separate
semantic values, eliminating repeated table reads for every learned skill each frame.
The HUD manager marks the whole pointer transaction consumed so a chooser tap
over the world cannot simultaneously submit a movement command.

Simulator evidence on 2026-10-11 (iPhone 17 Pro, iOS 26.5, original installer MPQs):

- Cold Spell Lab launch renders a 1304×600 logical world with centered original HUD.
- Probe 393,574 opens the chooser. Probe 414,478 assigns skill 47, closes the
  chooser, leaves the player at 9.0,203.0, and submits no world intent.
- Probe 900,450 submits movement beyond the old logical width and visibly moves
  the player with the camera following.
- Simulator Home and reopening preserve the process and selected skill. The next
  probe increments both counters and still moves the player.
- A post-resume probe at 670,350 submits a skill-47 cast against a named hostile
  and the scene renders its death animation/corpse.
- Direct canvas automation produced no pointer events in the same session.
  Native probe controls consistently queued paired press/release events.

Local proof captures: `.local/ios-wide-selector-proof.png` and
`.local/ios-wide-final-landscape.png`. Captures contain
original art and stay outside Git. The wider build with repaired skill selection
was installed and launched on the paired iPhone 16 Pro. The final build, including
prevention of chooser-tap movement, was installed afterward. Its remote launch was
blocked by the phone lock; unlock and open DarkMagic to resume physical acceptance.

This is a world-viewport experiment. Inventory and Skills now align their fixed
art and touch regions to the right edge, as described in [IOS_GAME_WORLD.md](IOS_GAME_WORLD.md).
Other legacy panels still need a separate responsive-layout pass. Finite isometric zone edges
can expose black beyond the authored map boundary, even when the drawable is filled.

## Remaining concerns

The first M2 slice has Simulator movement, camera-follow, and resume evidence,
plus user-confirmed town movement on the iPhone. Spell Lab also has Simulator
combat evidence and direct touch controls described in [IOS_TOUCH.md](IOS_TOUCH.md).
Ordinary town/Blood Moor exit travel and starting-skill melee now have Simulator
evidence in [IOS_GAME_WORLD.md](IOS_GAME_WORLD.md). Collision edge cases, broader
combat parity, and phone gameplay performance still need measurements. Native raw-contact probes make
Simulator gestures reproducible. Physical two-thumb comfort remains unverified.

Go's native binding compilation, the UIKit host link, and a signed smoke device
build succeed. The existing original-art UI scene and touch interaction also
work on the physical phone according to the user, including offline interaction
and background/resume. Offline cold launch and gameplay-state persistence have
not been checked.
Full installer extraction resolves the earlier asset blocker without adding an
iOS decoder dependency or changing simulation data. Asset validation errors
are shown by the native host. Client bootstrap currently couples even UI-only
scenes to gameplay
catalog validation. A future demo-data adapter would need to address that boundary
without inventing authoritative movement facts.

The smoke test's runtime log reports
`Modifying properties of a view's layer off the main thread is not allowed`
and `Unsupported layout off the main thread` during Ebitengine Metal setup.
The stack reaches `internal/graphicsdriver/metal/view_ios.go`'s `addSublayer`.
No upstream dependency patch or version upgrade is included. The test kept
rendering, but iOS compatibility and stricter future enforcement need investigation.

The existing Ebitengine adapter drains audio muted, lacks a native console
overlay, rejects final `pal.dat` quantization, and uses CPU quantization for
per-node palettes. See [PERFORMANCE.md](PERFORMANCE.md). Mobile memory, first-run
asset hashing, decode/upload stalls, safe-area behavior, thermal load, and dense
combat need measurements. UIKit can terminate a suspended app without cleanup;
durable background checkpoints are needed before claiming save safety for play.

This architecture provides a plausible route to a playable port: simulation and
Lua policy already run offline and presentation is backend-neutral. Practical
playability is still an inference. It depends on real-device rendering/performance,
audio/palette parity, controls, persistence, and asset availability. This branch
does not establish that the full game is playable or ready for distribution.
