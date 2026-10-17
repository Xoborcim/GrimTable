# GrimTable 0.8.0 — learn through play

The battle interface now explains what to do next while preserving the existing
tabletop engine. This milestone changes presentation, onboarding and placement
assistance. It adds no new combat rules, AI, army builder or networking service.

## Screenshots

| Before 0.7.0 | After 0.8.0 |
| --- | --- |
| [Previous battle HUD](before_guided_070.png) | [Fresh Guided match](guided_first_minute.png) |
| [Previous move tools](quick_move_070.png) | [Move preview](guided_move.png) |
| [Previous attack tools](quick_attack_070.png) | [Attack and Why?](guided_attack.png) |

Also see the [selected squad](guided_selected.png), [compact damage decision at
1280×800](guided_damage.png), and [round summary](guided_round.png). These are
in-engine captures, with original GrimTable miniatures and existing Kenney terrain.
The focused round-summary capture uses an assigned score fixture; the complete
turn smoke separately verified automatic objective scoring.

## Normal play

- The header always shows round, whose turn it is, and **You — Enemy** scores.
- A five-step **Move → Shoot → Charge → Fight → Score** tracker distinguishes
  completed, current and future steps with symbols and color. One sentence
  explains the activity; **How does this work?** offers a short optional explanation.
- Primary actions occupy one bottom dock. The next ready squad is prominent when
  nothing is selected. Selection reveals the relevant Move, Attack or Charge
  action, with Measure and Done as secondary tools.
- Continuation names the next activity: **Continue to Shooting**, **Continue to
  Charge**, **Continue to Fight**, **Review turn**, **Count points**, or **Finish
  round**. The engine's Command step is presented as **Start moving**. Starting a
  round from its summary enters movement through the existing canonical phase action.
- The unit card disappears without selection and expands only for inspection.
  It shows model count, **Health**, **Move**, **Armor**, weapons and action state.
  Tooltips retain the underlying wounds/save/hit terminology.
- History is secondary. Manual positioning, deployment tools, dice, save/load,
  phase corrections and referee controls remain in the scrollable **Advanced**
  card, retaining their existing callbacks and shortcuts.
- Undo appears when a reversible action exists. Passing unused squads is legal;
  the warning explains that squads can still move/attack rather than reporting
  an abstract unfinished phase.

Move takes four clicks from an unselected squad: **select → Move → destination →
Confirm**. A ranged attack takes four when choosing a target explicitly:
**select → Attack → enemy → Confirm attack**. A unique legal target remains a
reversible default, reducing this to three. Defender allocation is a separate
player decision; clicking a highlighted model applies the appropriate amount.
Charge continues to use the existing target/roll/preview/confirm flow.

## Guidance and board readability

Fresh settings default to **Guided**. Short contextual cards introduce ownership,
selection, movement, shooting, objectives and camera controls. They are nonmodal,
dismissible and persistent. Understood selection/movement/attack hints retire
through interaction. Reset Gameplay Hints remains available in Settings.

**Standard** keeps automatic formation/combat and next-action help without tutorial
cards. Existing **Assisted** settings migrate to Standard. **Tabletop** retains
manual positioning, detailed combat and exposed advanced controls. **Custom** keeps
individual preferences. Changing window resolution or quality alone no longer silently changes the
gameplay preset. Round summaries suggest Standard without selecting it for the player.

Squad banners show a name, living count and **YOUR TEAM / ENEMY**. Blue/amber base
stripes supplement faction palettes; ready rims are brighter and completed rims
subdued without darkening the miniature. Selection adds a downward marker. Banners
simplify at overview distance; miniatures have no new per-frame processing loop.
Hover information is centralized and compact.

Numbered objective beacons have a projected ring, upright marker and readable
Neutral / Your Team / Enemy / Contested status. Hover explains that nearby units
score points. Control uses the existing event-invalidated cache. Point changes
produce a temporary aggregate toast; the round summary shows scores and current
controlled-objective count. Combat cards and tutorial hints yield to the summary.

## Movement and targeting

Auto formation remains the default. Formation choices appear on failure or in
Advanced. Movement shows an original-position mesh ghost, a soft budget guide,
destination cursor, route distances and remaining allowance including terrain costs.
The circular guide is a budget illustration; wall/path/whole-squad legality is
checked on the destination click, not claimed to be a computed navigation region.

Placement tries the requested anchor and preserved shape, rotations, alternate
layouts, then bounded nearby anchors up to three inches away. It never evaluates
cover, objectives or tactical advantage. Adjusted results explicitly say they are
the closest fit. Failed results retain ghost positions and outline obstructing
terrain; confirmation stays disabled. Focus goes to the failed destination and
Manual remains an escape route. Existing collision, movement-budget and coherency
validation remain authoritative.

Attack immediately marks eligible enemy squads. Target hover explains availability,
out-of-range distance, or terrain blockage. The preview shows grouped attacks,
eligible models, accuracy, damage-roll threshold and enemy armor. A visible
**Why?** expands individual distance/visibility reasons and strength, defense,
armor penetration and cover calculations. It does not reroll or replace engine results.

Fast combat explains how many attacks hit, could damage the target, passed armor
and dealt damage. Exact dice remain available. The result card sits to the side
instead of covering defenders. Pending damage uses small arrow/code markers and
one instruction; the player can click a defending model or apply the suggestion.
Defeated models can remain on the table, and their result card can be closed
without forcing removal. Completed combat UI clears when the phase changes.

## Battlefield presentation

Ashfall Station keeps three squads on each side. Alpha Squad faces a nearby relay
and clear shooting lane; the offset station barrier introduces blocked sight later.
The initial camera frames the player's army, relay and center more closely;
Overview remains available. No scripted opponent was added: local play controls
both teams in turn, stated in the ownership hint and turn header.

Original terrain shaders add restrained grime, roughness variation, panel seams,
edge wear approximation and low hazard bands. Flat cover/difficult areas omit
wall caps/ribs/lights. Ground variations remain texture-free; its grid is subdued
normally and clearer while moving/measuring. Existing industrial/desert/alien
themes and quality settings remain available.

Authored humanoids have rounded helmet/torso forms and about six percent greater
cosmetic scale relative to the previous variation range. Existing layered armor,
weapons, creature shapes and faction palettes remain. Static decorative geometry
is still shared/batched. **Base size, collision, LOS origins and gameplay stats
are unchanged.** No additional third-party imagery, models, audio or textures were added.

## Performance

One 100/200-model spot check used the existing deterministic benchmark, Medium,
1280×800 Compatibility OpenGL, VSync off, 90 frames per mode. Hardware: AMD Ryzen
5 2600, 6 cores / 12 threads; NVIDIA GTX 1660 Ti; Godot 4.6.1. Camera assistance
was disabled for the repeatable benchmark viewpoint.

| Models | 0.7 FPS | 0.8 FPS | Idle frame | Movement frame | Target frame | Selection | Attack preview | Memory |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 100 | 136.9 | 133.6 | 7.49 ms | 7.80 ms | 7.76 ms | 0.99 ms | 0.096 ms | 124.3 MiB |
| 200 | 81.9 | 73.2 | 13.67 ms | 13.99 ms | 14.00 ms | 0.94 ms | 0.095 ms | 149.6 MiB |

That is roughly 2.4% / 10.7% lower idle FPS on this machine. Both cases remained
responsive; these are not universal hardware guarantees. Label visibility updates
four times per second; assistance refreshes are event-driven and coalesced. No
spatial index, render architecture or networking optimization was introduced.
[Raw benchmark](benchmarks/guided_080.json).

## Validation

During implementation: assistance 90, squad/combat 76, experience 49, and new Guided
checks covered the affected behavior. Source graphical smoke captured the actual
scene/UI. One complete isolated Godot regression invocation ran **1,204 checks**
with zero assertion failures. It exposed a deferred refresh after a battle left
the tree; that was fixed and only application checks (192) rerun, cleanly.

Final UI follow-ups added a regression for mutually exclusive hints/round summary;
the Guided suite finishes at **42 passing checks**. The final aggregate is therefore
**1,205 passing Godot checks**. The full runner was not repeated. No separate
signaling, TURN, public infrastructure or full multiplayer gameplay matrix was run.
Action serialization is unchanged; the existing compatibility gate uses build 0.8.0.
Saves, mod content, profile snapshots and replay records use the existing engine.

The Windows x86_64 release was exported and launched graphically. A fresh-settings
packaged walkthrough passed **37 checks**: ownership/phase instructions, selection,
Move/formation/confirmation, continuation, target highlights/Why, one-confirmation
attack, exact dice, direct defender clicks, automatic scoring, round summary and
exact save/load. Visual inspection found overlapping per-model damage prompts;
those became compact arrows. Focused packaged follow-ups tested only affected
damage/round UI at 1280×800, with **11 final checks passing**, exit 0. They also
caught and fixed a hint lingering under the round summary. Final export and fresh
menu launch exit 0 after a small settings-description wrapping correction.

The pre-existing Godot Windows root certificate-store warning still appears; it
did not prevent these offline checks. Logs are under `.runtime/guided-*`. Linux
and macOS packages were not rebuilt.

## First-minute assessment and limits

The fresh-profile graphical walkthrough and screenshot review checked all ten
beginner questions: ownership, current activity, what Move means, selection,
movement, continuation, attacking, why targets are blocked, what objectives are,
and how points are awarded. Each has an in-game cue or explanation. **This was a
scripted walkthrough and interface review, not a novice human usability study.**

Remaining friction: local hotseat side changes still need attention; closely
packed squad banners can overlap; formation convenience does not route squads
around obstacles; fully occluded movement regions are not precomputed. Advanced
tools retain technical tabletop terminology. Default and minimum window sizes
were checked; all UI-scale/resolution combinations were not exhaustively reviewed.

Recommended next UX milestone: watch several first-time players complete one
round, recording time to first selection/move/attack and confusion at side changes
and damage allocation. Use those observations before resuming army-builder work.
