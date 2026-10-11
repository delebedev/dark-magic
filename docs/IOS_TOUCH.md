# Touch combat experiment

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

## Decisions and sources

[Riiablo's GameScreen](https://github.com/collinsmith/riiablo/blob/59aa8d5021c457e8d2891bb23c9e3a0ef724c6b3/core/src/main/java/com/riiablo/screen/GameScreen.java)
uses a dead-zone touchpad, normalized direction, and inverse isometric
projection. Adopt those interaction ideas. Its direct ECS velocity writes do
not fit Dark Magic's client/authority split. Its
[README](https://github.com/collinsmith/riiablo/blob/59aa8d5021c457e8d2891bb23c9e3a0ef724c6b3/README.md)
explicitly calls the game incomplete. No Java code, assets, or dependencies are
copied.

[Blizzard's D2R console design](https://news.blizzard.com/en-us/article/23722094/bringing-the-original-diablo-ii-experience-to-console)
uses direct skill activation and prioritized cone targeting without a cursor.
Adopt direct activation and show one target. This experiment scores only live,
visible hostiles, with a directional cone and a modest current-target preference.
Corpse, loot, NPC, and class-specific targeting need separate work.

[GGG's PoE2 0.3 targeting notes](https://www.pathofexile.com/forum/view-thread/3826682/filter-account-type/staff)
distinguish directional projectile aiming from ground-location targeting.
[The official console developer diary](https://www.youtube.com/watch?v=GqYTZHX-QVE)
is a useful wider controller reference. Our proposal keeps movement and aiming
separate, but does not import PoE2 movement-while-casting or dodge mechanics.
These are source-based design observations, not a hands-on commercial-controller
comparison.

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

## Observed evidence, 2026-10-11

The iOS 26.5 Simulator shows Fire Ball impact and dead hostile sprites. The
two-contact probe moves the Sorceress and camera, casts while both contacts
remain owned, resumes movement after the casting contact releases, and stops
at `(16.4, 196.6)` when movement releases. Ice Blast's aimed release submits a
ground cast. Its cancellation submits no cast and leaves the hero stationary.
These observations use raw contact probes, not physical two-thumb input.

The first Nova build later displayed `context deadline exceeded` in
`game_world.lua:784` while processing semantic sound cues. The phone user also
reported Nova producing the native black error panel. Each sound cue copied
all 4,699 Sounds.txt records into Lua and searched them again. The sound adapter
now retains one catalog and case-insensitive index, preserving grouped variants
and redirect selection. A targeted regression exercises repeated playback with
one catalog load. The runtime deadline is unchanged.

After that change, Nova renders its expanding lightning ring and dead hostile
sprites on a fresh Simulator process. Repeated Nova and another Nova after
Home/background/resume complete in the same process (`91956`) without an error
panel. Local evidence: `.local/ios-touch-nova-fixed.mp4`,
`.local/ios-touch-nova-fix.stderr`, `.local/ios-touch-audio-tests.log`,
`.local/ios-touch-go-tests.log`, and `.local/ios-touch-ui-tests.log`.
The earlier movement/Fire Ball recording is `.local/ios-touch-demo.mp4`.
The corrected signed build installs and launches on the paired iPhone with
diagnostics disabled. Evidence: `.local/ios-touch-nova-fixed-phone-install.json`
and `.local/ios-touch-nova-fixed-phone-launch.json`. The user confirms repeated
Nova and background/resume work on the iPhone without the error panel. The
landscape recording for review is
`.local/ios-touch-nova-demo-landscape.mp4`.

## Limits

These controls do not provide VoiceOver elements for the rendered canvas.
The native diagnostic panel is accessible. Physical two-thumb feel, safe-area
comfort, long sessions, audio, and broader skill targeting remain unverified.
Spell Lab retains its upstream disposable level-30 character, generous mana,
and nearby hostiles. It demonstrates existing gameplay implementations rather
than full Diablo II parity. Original asset captures stay in ignored `.local/`.
