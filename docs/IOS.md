# Experimental iOS port

This branch explores Ebitengine plus a UIKit host. It is not a playable mobile
Diablo II release. M2 is deferred until M1 has been demonstrated on hardware.

## Status and feasibility

Observed on 2026-10-10:

Upstream baseline: `9d450c5d452198dec4fd9d53f9c6a9e1b0145334`.

- Desktop Ebitengine client compiles with Go 1.25.12 and Ebitengine 2.9.9.
- Desktop `--start-scene ui_lab` stops at asset validation. No real-asset desktop
  scene has been verified in this checkout.
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
  `codesign --verify --deep --strict`. Device installation is blocked while the
  paired phone is locked and its Developer Disk Image cannot be mounted.
- Targeted Go checks cover the application, command, content, input, session,
  hosted lifecycle/error propagation, touch translation, and smoke diagnostic.
  Architecture checks pass. Original-asset cases are not evidence without MPQs.
- Xcode builds and installs the smoke app. On an iPhone 17 Pro Simulator running
  iOS 26.4.1, the 800x600 diagnostic renders with landscape letterboxing, ticks
  advance, a drag changes touch coordinates to `(205, 202)`, and the white marker
  follows. Backgrounding for five seconds and returning preserves the process
  and touch state. This is Simulator input, not a physical-device touch test.
- Startup logs contain UIKit main-thread assertions from Ebitengine's Metal
  `addSublayer` call. Rendering continues, but this is an unresolved renderer issue.
- **No original-asset scene or physical-iPhone launch is verified. M0's desktop
  scene requirement and M1 remain incomplete.**

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
`ios-smoke-device-build.log`. Native screenshots retain
the Simulator display's portrait pixel orientation; the UI window was landscape.

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
- The initial real scene is the unchanged `ui_lab`. It tests existing authored
  Diablo controls without requiring a gameplay network service.
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
  session retains its bounded fixed-tick clock. Hardware suspension remains unverified.

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

For the real scene, place original LoD MPQs into `ios/Assets` with lowercase
archive filenames, including `d2data.mpq`, `d2char.mpq`, `d2exp.mpq`, and
`patch_d2.mpq`. These files are ignored. Rebuild the framework:

```sh
./ios/build.sh
open ios/DarkMagic.xcodeproj
```

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

## Remaining concerns

Go's native binding compilation, the UIKit host link, and a signed smoke device
build succeed. Physical-device behavior remains unverified. Real-client runtime
assembly still needs compatible MPQs. Asset validation errors are shown by the
native host. Client bootstrap currently couples even UI-only scenes to gameplay
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
