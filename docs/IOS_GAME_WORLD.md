# Game World parity slice

The target is upstream `game_world`, the same disposable Amazon used by
`make play-game-world`. It uses normal starting skills, vitals, movement,
collision, combat, item authority, and the authored town/Blood Moor exit.
This is not a new expedition, campaign, or mobile simulation.

## Controls

- Move with the left pad or tap ground. Hold the large Attack pad to target a
  visible hostile. The small pads use other admitted starting skills.
- Tap the original HUD skill well to choose an existing learned skill.
  Choosing a right-hand skill changes the large touch pad.
- **Panels** opens a native menu for Inventory, Character, Skills, Quests, Map,
  Options, Help, Run / walk, and Swap weapons. Each emits its existing desktop
  logical input action. The game still owns panel routing and command policy.
- **Back** emits Cancel: close the focused panel, or open pause in the world.
- Walk through the normal town exit to enter Blood Moor. Walk back through its
  corresponding exit to return. Game World has no Warp Lab portal fixture.

Native controls occupy the upper-right safe area. They work without diagnostics
and have UIKit accessibility labels. The rendered game canvas still lacks
VoiceOver elements. Full-width world rendering retains the original fixed HUD. Inventory and
Skills translate their authored art and pointer hit regions to the right edge.
Held item art subtracts the same offset so it stays beneath the finger.

## Boundaries

The host queues one validated input press followed by a release at the ordinary
frame-input seam, before console and scene focus routing. It cannot submit
simulation commands. A connected keyboard retains ownership of held actions.
The bridge rejects unknown names and overlapping pending presses.

Changing levels clears pending touch casts, target IDs, and casting gates from
the old world. Holding movement can continue against the destination map's
existing navigation policy. Touch skill assignments wait for authority feedback.
HUD changes rebind the main pad, while direct-pad assignment acknowledgements
preserve its loadout.

The retained composer now stamps nodes with immutable creation order. Ebitengine
uses that order after layer/Z sorting, matching Raylib rather than recycled
handle-slot order. Without this, reopening inventory after world teardown could
paint the background over items and the close control. No item state was lost.

## Reproduce

Build using [IOS.md](IOS.md). Normal launch selects **Game World · Amazon** from
the native picker, or uses `DARK_MAGIC_START_SCENE=game_world`.

For quick exit regression testing only, launch with
`DARK_MAGIC_INPUT_DIAGNOSTICS=1` and `DARK_MAGIC_FIXTURE_WORLD_SPAWN=seam`.
This forwards the existing desktop `--fixture-world-spawn seam` option. It only
changes the initial fixture position and is ignored without diagnostics.
The ordinary phone build starts at the normal town entry. Probes supply raw
input, not a transition command. The diagnostic overlay reports observed level
and player coordinates.

With licensed MPQs configured:

```sh
MPQ_DIRECTORY=/absolute/path/to/lod GOTOOLCHAIN=go1.25.12 \
  go test ./internal/app/clientapp \
  -run 'TestGameWorldWalksAuthoredExitAndReturns|TestCombatLabFixtureEntersBloodMoor' -v
GOTOOLCHAIN=go1.25.12 go test -tags ebitengine ./internal/app/clientapp ./mobile \
  -run 'TestHostedActionInput|TestHostedOptions|TestHostedGame'
GOTOOLCHAIN=go1.25.12 go test ./internal/mod/d2legacy \
  -run 'TestLuaSuites/d2legacy/(ui|gameplay|dev)/(touch_controls|touch_input|input_diagnostics|world)$' -v
```

The exit test uses production movement and transition systems. The existing
combat test isolates attack/damage and moves its generated target into range;
it does not establish live touch pursuit or mobile combat parity.

## Shared upstream gaps

Automap is a placeholder overlay. Quests, Help, and some NPC/dialog panels are
incomplete. Exposing their existing actions does not implement their contents.
The skill-tree shell also renders as a narrow strip on Raylib desktop. Skill
allocation remains unavailable. Fixture characters are disposable, as on the desktop fixture path. No durable
campaign saves, level progression, loot loop, or new abilities are added.

Ebitengine's audio adapter still discards mixer commands on desktop and iOS.
The renderer also has documented palette/effect parity gaps against Raylib.
This slice targets gameplay entry and input access, not full Raylib parity.

## Observed evidence, 2026-10-11

| Behavior | Evidence |
| --- | --- |
| Desktop baseline | Raylib Game World, Inventory, and Skills rendered from the same disposable fixture. Panels were selected through `--start-overlays`; short automated keyboard events were unreliable. |
| Ordinary exit travel | Simulator raw ground taps walked from town level 1 to Blood Moor level 2 and back to 1. The diagnostic overlay and new real-MPQ authority test agree on both transitions. |
| Normal melee | On open ground in Blood Moor, holding Attack selected a stable generated Fallen ID, approached it, and rendered its corpse. The first fence-side target was difficult to reach; navigation around collision remains imperfect. No lab stats or spells were granted. |
| Inventory | After travel, the right-aligned panel showed its original sword and potion. A potion moved from column 2 to column 3 through ordinary item commands and remained there after returning to town. |
| Panel access | Inventory, Character, Skills, Map, and Pause opened. Back closed panels and restored world input. Map and Skills retain their upstream incomplete presentation. |
| HUD assignment | Choosing Throw in the original right-hand chooser changed the main pad to Throw and moved Attack to a small pad. |
| Lifecycle | Simulator Home/background/resume retained PID 31423. Native Back closed the preserved pause overlay and a raw pad gesture moved the Amazon again. |

Local captures contain licensed art and remain outside Git:
`.local/ios-parity-world-demo.mp4`, `.local/ios-parity-combat.mp4`,
`.local/ios-parity-final-demo.mp4`, `.local/ios-parity-fallen-kill.png`,
`.local/ios-parity-inventory-fixed.png`, and
`.local/ios-parity-return-inventory.png`.

Verification logs: `.local/ios-parity-real-tests.log`,
`.local/ios-parity-go-tests.log`, `.local/ios-parity-lua-tests.log`,
`.local/ios-parity-layout-tests.log`, `.local/ios-parity-render-tests.log`, and
`.local/ios-parity-race-tests.log`. Framework, Simulator host, and signed device
host builds completed. A fresh ignored derived-data directory
`.local/ios-parity-build` avoided Xcode's cached missing-XCFramework description
following regeneration.

Other native menu entries, physical two-thumb comfort, long sessions, and a
complete campaign remain unverified. Full desktop parity is not claimed.

The corrected build installed on the paired iPhone (`ios-parity-phone-install.json`).
Remote launch was rejected by the phone lock with “Unable to launch
org.darkmagic.experimental because the device was not, or could not be,
unlocked.” Launch and physical acceptance are pending unlock. Phone launch uses
normal town entry and diagnostics disabled.
