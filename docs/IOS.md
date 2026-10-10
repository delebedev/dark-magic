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
  analysis, not successful native compilation.
- Objective-C binding generation succeeds and confirms the native Configure
  signature. Xcode project/plist syntax and Swift parsing pass.
- Targeted Go checks cover the application, command, content, input, session,
  hosted lifecycle/error propagation, touch translation, and smoke diagnostic.
  Architecture checks pass. Original-asset cases are not evidence without MPQs.
- Native bind stops with `gomobile: -target="ios" requires Xcode`.
- **Nothing has launched on an iPhone or Simulator. M0 and M1 are incomplete.**

The Mac initially had roughly 20 GiB free and only Command Line Tools selected.
Full Xcode was not found in Applications or the Spotlight application index.
Go and the pinned ebitenmobile tool were installed for investigation. Free space
must be addressed before installing Xcode plus an iOS Simulator runtime.

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
the existing MPQ decoder fail with `decryption of MPQ failed`. The cause has
not been verified. No codec fix or substitute expansion art is included.
The base archive's `data/global/missiles/arrow.dcc` does decode and produces a
headless diagnostic PNG with the decoder's fallback palette. That proves some
real demo content is readable, not that a scene or its authored colors work.
The demo is useful for archive experiments but currently cannot boot `ui_lab`.
The supported real-scene path still needs original LoD 1.14d MPQs.

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
It builds device and Simulator slices into ignored `ios/DarkMagic.xcframework`.
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

Xcode installation, iOS compilation/linking, signing, Simulator launch, and
physical-device behavior are unverified. Package resolution cannot expose native
linker problems. Asset validation errors are shown by the native host.

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
