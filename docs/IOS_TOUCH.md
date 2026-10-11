# Mobile input

The iOS world scenes use a left movement pad and three direct skill buttons.
Spell Lab selects Fire Ball (47), Ice Blast (45), and Nova (48) from its ordinary
admitted learned-skill snapshot. Other characters receive available learned
skills instead. No skill is granted by the controls. Choosing a right-hand skill through the
original HUD rebinds the large touch pad. Assignments made by the direct touch
pads keep their existing three-button layout.

- Drag the left pad to move. Its 14-pixel logical dead zone prevents drift.
  Release to stop. Casting retains the game's existing stationary action rules.
- Hold the large skill button to repeat after the preceding authoritative action
  finishes. Tap either smaller button to cast once on release.
- Drag a skill button to aim. The dotted line shows direction. A gold marker
  shows the selected live hostile. Moving more than 180 logical pixels from the
  button cancels that gesture.
- Two contacts retain independent ownership. Releasing one does not transfer
  the other finger to another control. Panels cancel control ownership.
- Ground taps and the original HUD remain available for existing interactions.

## World panels

- The rendered **Inventory / Character / Pause** toolbar opens ordinary game
  overlays. Inventory and Character have explicit close controls.
- Inventory taps select and inspect. **Equip right / Equip left** and **Move**
  submit the existing item command. Move then asks for a grid cell or equipment
  slot. Selection remains visible after authority refuses a destination.
- Mobile inventory and character panels block all world input. Closing requires
  a fresh contact before movement or combat can resume.
- Native **Tools / Back** and unfinished-panel shortcuts are diagnostics only.
- Walk through the normal town exit to enter Blood Moor. Walk back through its
  corresponding exit to return. Game World has no Warp Lab portal fixture.

Swift supplies UIKit-point geometry and safe insets. Lua converts these to
logical coordinates and anchors each control section separately. New toolbar,
inventory actions, item selection and panel-close hit areas have a provisional
30-point minimum, deliberately below Apple's 44-point recommendation. Artwork
can be smaller than its hit region. Actual phone comfort remains a review gate.
Full-width world rendering retains the original fixed HUD. Inventory and Skills
translate their authored art and hit regions to the right edge. The rendered
game canvas still lacks VoiceOver elements.

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

The retained composer stamps nodes with immutable creation order. Ebitengine
uses that order after layer/Z sorting, matching Raylib. Recycled handle slots
do not change painter order after a world teardown.

## Architecture

Ebitengine publishes copied active touch contacts with stable IDs through
`engine.input/v1`. Input focus suppression also suppresses contacts. The platform
adapter contains no Diablo targeting or control-layout policy.

`d2legacy.gameplay.touch_input` owns gesture selection and screen-space target
scoring. `d2legacy.ui.touch_controls` owns retained visuals and presentation
state. The world scene submits existing `player.move`, `player.assign_skills`,
and `player.use_skill` commands. Skill assignment must be observed back from the
authority before casting. Repetition uses the existing authoritative action gate.

Movement currently submits short ordinary navigation destinations at 10 Hz.
This preserves upstream pathfinding and collision. It is not D2R's direct analog
collision movement. Tight wall following and analog walk/run deserve measured
hardware work before changing the movement command contract.

## Reproduce

Use the framework and Simulator build instructions in [IOS.md](IOS.md). Launch
Spell Lab with `DARK_MAGIC_START_SCENE=spell_lab` and
`DARK_MAGIC_INPUT_DIAGNOSTICS=1`. The native accessible panel supplies labelled
raw contact sequences through the same frame/gesture path as real fingers:

- Move east: hold the movement pad for two seconds, then release.
- Hold main: hold the large skill button for two seconds, then release.
- Move + main: move, add the casting finger, release casting while movement
  stays held, then release movement.
- Aim second: press the second skill, drag toward the upper left, release.
- Cancel second: drag that skill beyond the cancellation radius and release.
- Third skill: tap the third skill and release.

Hide/show probes collapses the native panel for unobstructed captures. Probe
input is labelled `probe`, bounded to the current viewport, limited to ten
seconds, and must finish with all contacts released. It cannot submit gameplay
commands directly. Diagnostics are disabled on normal phone launches.

## Fixture diagnostics and limits

`DARK_MAGIC_INPUT_DIAGNOSTICS=1` enables native raw-contact probes and read-only
world diagnostics. With Game World diagnostics only,
`DARK_MAGIC_FIXTURE_WORLD_SPAWN=seam` forwards the existing desktop exit fixture
position. Normal phone launches leave both overrides disabled.

The native controls and probe panel have UIKit accessibility labels. Rendered
canvas elements do not have VoiceOver equivalents. Target scoring currently
covers live visible hostiles. Corpse, loot, NPC and class-specific targeting need
separate work. The controls do not implement progression, durable saves or new
abilities. Use existing Game World exits for town/Blood Moor travel.
