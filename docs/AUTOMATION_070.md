# GrimTable 0.7.0 — players choose, GrimTable keeps track

This release streamlines the existing engine rather than replacing its combat,
movement, networking, content registry or replay systems. No AI, matchmaking,
new infrastructure or asset downloads were added.

## Normal player interactions

Counts include selecting the squad and exclude moving the camera. These are
deliberate clicks, not individual model drags or dice-stage confirmations.

| Action | Normal clicks | Flow |
|---|---:|---|
| Move | 4 | Select squad → Move → destination → Confirm Move |
| Ranged attack | 4 | Select squad → Attack → enemy → Attack / Fire All |
| Attack with one legal target | 3 | Select squad → Attack → Attack / Fire All; target defaults reversibly |
| Charge | 5 | Select squad → Charge → enemy → Roll Charge → Confirm Move |

Charge retains two distinct commitments: rolling commits the attempt, while
movement confirmation approves the generated position. Cancelling the position
does not grant another roll. A valid recorded roll can be resumed. Under Ask Me,
damage allocation is an additional player decision: Apply uses the suggested
recipient and amount, or Choose Another opens the existing allocation controls.

The new action-preview panel keeps the attack and movement confirmations visible
without scrolling the unit card. More contains the original manual tools, split
fire and referee controls. Short rosters show readiness for the current phase.

## Movement, deployment and charge

Quick movement preserves the squad's current formation first. If that does not
fit, Auto tries fixed Cluster, Line and Two Rows layouts around the requested
anchor, followed by fixed nearby offsets up to three inches away. It checks the
existing movement allowance, coherency, bases, terrain, board boundary and swept
paths. It never evaluates cover, objectives, threats or tactical value. Models in
the same moving squad may cross one another's paths, but final bases cannot overlap.

An invalid proposal restores the original positions and explains why. Another
destination, a formation choice, Manual positioning or Cancel remain available.
The preview shows terrain cost and remaining movement per model. A single radius
guide and origin markers replace overlapping per-model radius circles in Quick
mode. Detailed individual drag previews remain available in Manual mode.

Auto Deploy Army places simple legal formations in a fixed zone scan order. Local
play places both armies; online it places only the requesting player's army. If
some squads do not fit, legal placements remain and the errors are reported.
Ready checks required models, zones, collision and coherency. Deployment errors
offer Focus Problem. Both online players must Ready; local Ready validates both
sides. Deployment actions mark units deployed rather than using their first-round
movement.

Charge is a player-selected target plus an authoritative configured roll. The
default is two six-sided dice, no bonus and a one-inch engagement range. These
are generic scenario parameters, not faction-specific rules:

```json
{
  "rules": {
    "difficult_ground_penalty": 2,
    "charge": {"dice": 2, "sides": 6, "bonus": 0, "engagement_range": 1}
  }
}
```

Supported charge dice: 1–10 dice, 2–20 sides, bonus −20 through 20; engagement
range 0.1–6 inches. The UI shows required base distance and exact recorded roll.
After success, the geometry helper proposes a legal formation near the chosen
target. The player confirms or adjusts it. Obstructions or terrain costs may mean
the direct formation cannot fit even though the geometric distance was reachable.
The helper explains this; it does not route around terrain or choose another enemy.

## Combat and damage

Attack automatically lists targets with distance and available attack count.
One legal target defaults without firing. Legal targets are marked on the board;
illegal ones are explained or hidden by preference. Fire All uses every eligible
unit-wide weapon group for the current ranged/melee context. The existing
per-model range and LOS checks choose attackers, not the player. Melee uses the
same resolver. Split Fire remains an explicit advanced choice.

The preview shows weapon/model groups, attacks, hit target, wound target and
modified save. Hover explains strength/defense, AP, cover and excluded models.
Confirmation resolves the complete deterministic hit → wound → save → damage
pipeline. Different weapon profiles resolve sequentially, with defender allocation
between groups when needed. They never mix dice into an opaque combined roll.

Fast displays a short final count chain with optional Show Dice. Detailed shows
the recorded stages automatically. Manual reveals those same recorded stages on
button presses. Manual is presentation pacing, not a new physical-dice input or
replacement gameplay RNG. Exact dice always remain in the battle log and replay.

Ask Me suggests a wounded living model first, then stable ID order. Apply handles
the amount and pool arithmetic. Choose Another preserves the player's decision.
Auto-Allocate uses the same deterministic order on the host. Ask Before Removing
remains the casualty default; automatic removal is optional. Removal has a brief
cosmetic shrink/topple transition, disabled by reduced motion/effects preferences.
Picking and authoritative casualty state update immediately.

If the last valid recipient dies, excess damage clears in the same canonical
allocation action. There is no overkill-discard bookkeeping click, and Undo restores
both the model and the previous pool atomically.

## Terrain, objectives and scoring

Cover remains an explicit area: every living defending base must touch a qualifying
area. The strongest bonus applies without stacking. It is included automatically
in previews, saves and result explanations. Host/local referee overrides are available.

Difficult terrain supports either `difficult_ground: true`, using the scenario's
default penalty, or an explicit `movement_penalty` from 0 to 24 inches:

```json
{
  "id": "rubble", "title": "Rubble", "kind": "box",
  "size": [8, 0.12, 4], "position": [0, 0, 0],
  "blocks_movement": false, "blocks_los": false,
  "movement_penalty": 2
}
```

A route pays the strongest touched area's flat penalty once. Additional drag
waypoints do not multiply it. Rotated rectangular footprints, conservatively
expanded by base radius, determine whether the route touches an area. The same
cost is used in Quick previews, manual sessions and host validation, including
charge movement. Terrain traits survive scenario capture and frozen saves/replays.

Objective control continues to invalidate on movement, casualties, deployment and
relevant state changes. Scenario scoring occurs at its existing end-of-round
timing. Score deltas and totals appear without requiring arithmetic. Referee
ownership corrections also feed the shared scoring calculation.

## Assistance settings and correction tools

- **Assisted:** Quick formations, Fast combat, phase offers and camera assistance;
  automatic objective/scoring calculation; damage allocation and casualty removal
  still ask by default. Automatically advancing phases remains OFF.
- **Tabletop:** individual model positioning, Detailed combat, manual casualty
  confirmation, no automatic phase offers/camera assistance, and visible manual tools.
- **Custom:** retains individual preferences, including Manual combat pacing,
  auto-allocation, automatic casualties, target filtering and opt-in phase advancement.

NEXT selects the next ready unit or offers the next phase when nothing relevant
remains. It never silently passes a player's turn by default. Opt-in advancement
skips completed action phases, stopping at End. End Turn is the player's explicit
decision to pass unused actions and perform phase/scoring bookkeeping. Pending
damage and unfinished weapon groups must be handled first.

The phase assistant derives moved/fired/charged/fought state from canonical records,
so Undo/redo and replay remain consistent. Manual tools can repeat actions for
sandbox exceptions; normal contextual buttons guide the common once-per-round flow.

More → Manual Override allows host/local correction of wounds, score, objective
owner, cover and phase. Existing movement/setup tools permit position corrections
where allowed. Guests cannot issue referee corrections. Automatic/override choices
are explicit and recorded. Move Undo remains visible; online Undo retains the
existing host restrictions and canonical synchronization.

Two short hints remember selection/action understanding. Settings can reset them.
Camera assistance is optional, and manual camera input cancels the current focus
motion. Existing reduced motion, text scale and visual accessibility remain available.
Readiness, legality and dice successes use text and symbols as well as colors.

## Persistence, mods and multiplayer

Profiles and weapons remain data-driven, including supported modded profiles.
Unit-wide equipped profiles are automatically treated as model groups. This release
does not add per-model equipment authoring or a new mod architecture.

Charge grants, readiness and referee corrections use validated optional fields in
the existing canonical turn snapshots. Movement uses the existing action deltas
and route metadata. The host recomputes costs, checks the recorded charge grant,
target and engagement endpoint, and rejects forged movement budgets. Allocation,
casualties, scoring and exact rolls remain canonical. Visual assistance is local.
Compatibility now requires matching 0.7.0 builds. Older saves remain readable;
snapshot-backed replays never reroll attacks or charges.

The minimal two-client ENet scenario confirmed identical automatic attack dice,
one damage allocated by the defender, score 1–0 and final hash:
`fe1c84c04b2012ef481bd81773be882a414609821d3804bfc11edb0de94adca8`.
The initial fixture produced a successful save; it was adjusted to ensure this
same small check exercised positive allocation. No full multiplayer workflow,
signaling protocol, TURN or public-server matrix was repeated.

## Performance and validation

Godot 4.6.1 Compatibility/OpenGL, Windows, Ryzen 5 2600, GTX 1660 Ti, 1280×800,
Medium, uncapped/VSync OFF, 90 frames per mode. Same deterministic mixed-army
benchmark and camera; camera assistance is disabled for repeatability.

| Models | 0.6 FPS / frame | 0.7 FPS / frame | Movement / targeting frame | Selection | Attack preview |
|---|---|---|---|---|---|
| 100 | 139.3 / 7.18 ms | 136.9 / 7.30 ms | 6.94 / 7.22 ms | 0.86 ms | 0.092 ms |
| 200 | 83.2 / 12.01 ms | 81.9 / 12.21 ms | 12.33 / 12.60 ms | 0.89 ms | 0.095 ms |

Static memory was 104.9/126.0 MiB; load time 1,030/606 ms, with cold resource
creation in the first size. These short local results are not universal guarantees.
The frame-time change is about 2%; both tested sizes stayed responsive. Assistant
refreshes are event-driven and coalesced. No per-frame all-army LOS/objective scans
or speculative optimization rewrite was added. Raw data: [automation_070.json](benchmarks/automation_070.json).

Targeted development: 90 automation checks, affected movement/combat (76) and
save/replay (48) checks, graphical scenario/interaction smoke, and one 100/200-model
performance run. The automation checks cover presets, real destination clicks,
formation legality, terrain costs, Fire All, display modes, charge authority,
allocation, undo/redo, readiness, focus visibility, overrides and exact persistence.

The comprehensive Godot runner was executed **exactly once**. It found one old
test that assumed the last terrain item was cover; adding rubble exposed the
assumption. The check now locates the existing cover area by ID and still verifies
its persisted bonus. Only the affected experience suite was rerun, alongside
focused checks for subsequent overkill and Focus visibility fixes. Final aggregate:
**1,161 passing checks** across twelve suites, including **90 automation checks**.

Fresh standalone Windows x86_64 package: **32 graphical smoke checks passed**, exit
code 0. It loads the six-squad Ashfall showcase, exercises destination-click
movement and terrain costs, confirms ranged Fire All, allocates damage, rolls and
confirms a charge, detects melee, scores turns, saves/loads and replays exact state.
The added deployment segment verifies visible Focus guidance, Auto Deploy and Ready.
Attack confirmation visibility is asserted in the real executable. The packaged
Windows certificate-store warning remains an existing nonblocking engine warning.

Screenshots: [Quick Move](quick_move_070.png), [Quick Attack](quick_attack_070.png),
[deployment guidance](ready_070.png).

## Remaining decisions and limits

Players still choose destinations, targets, whether to charge, split-fire targets,
damage recipients under Ask Me, casualty removal under Ask, and when to end/pass.
Those are decisions rather than arithmetic. No routine range, LOS, dice counting,
wound/save/AP/damage arithmetic, objective counting or scoring calculation is required.

Formation placement is a bounded geometric convenience, not pathfinding. Narrow
terrain layouts or very large squads can require a nearby anchor or Manual
positioning. Difficult ground uses the documented flat strongest-area penalty,
not a distance-weighted movement simulation. Charge uses the straight geometric
required distance; the final preview also validates actual route costs and terrain.
Explicit-area cover remains deliberately simple.

Manual combat reveals canonical outcomes; arbitrary physical-dice replacement
is not implemented. Settings retain compatibility with existing saves and profiles;
the current multiplayer version gate requires both players to update. Windows is
rebuilt for this milestone; Linux/macOS binaries are unchanged.

Recommended next UX improvement: observe first-time players completing one turn,
then improve blocked-formation guidance and in-editor authoring of terrain/charge
traits. More infrastructure is not needed for that work.
