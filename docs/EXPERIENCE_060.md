# GrimTable 0.6.0 — player experience

This release builds on the existing game, content packs, host authority and
deterministic replay. It adds no network infrastructure or external miniature
downloads. The authored miniature art is permanent content.

## Battlefield and miniatures

- Warm directional key, cool fill and readable ambient light, with Filmic tone
  mapping. Compatibility/OpenGL remains the renderer. Unsupported SSAO/bloom
  controls are deliberately absent.
- Low disables dynamic key shadows and MSAA; Medium uses key shadows and 2x MSAA;
  High uses key shadows and 4x MSAA. No per-miniature processing loop was added.
- Three procedural board palettes: `industrial`, `desert`, `alien`. Set
  `board.theme` in scenario JSON. Industrial panels have fine seams and wear;
  desert and alien surfaces use natural variation. The editor preserves this
  field when saving. Board edges have physical trim and reference ticks.
- All sixteen authored visual scenes use muted faction paints. Legion gains
  layered shoulder/knee/chest armor and field equipment; Horde has asymmetric
  scrap plates and oversized weapons; Swarm has segmented carapaces, mandibles,
  claws and tails; Synthetics have sensor bars, alloy panels and energy details.
  Three ID-derived equipment variants supplement existing scale/yaw variation.
- Cosmetic meshes remain merged by material inside each miniature and shared
  across matching appearances. Gameplay bases, IDs, LOS and picking remain
  independent of these meshes.
- Beveled bases, faction markers, solid illuminated selection/hover rings,
  readiness text, wounded/defeated marks and fewer idle floating labels.
- Terrain gains reusable cap/rib/lamp treatment. **Footprints** toggles ground
  boundaries; F3 retains the separate collision diagnostic view.
- Ashfall Station is the first menu action, with a closer opening camera,
  station bulkheads, supply relays, cover aprons and reused Kenney props. The
  peripheral props are decorative: they do not block movement or LOS. Only used
  GLBs are instantiated, and small decorative props cast no dynamic shadows.
- Main menu uses an original in-engine battlefield render. Play actions show
  loading feedback before constructing the scenario. HUD panels, compact unit
  cards and the game-state header use a shared dark/teal/amber direction.

## Referee assistance

- The phase assistant tracks moved/ranged/melee actions per round by deriving
  them from canonical action records. Undo/redo, loaded logs and replay therefore
  use the same history. These are reminders, not action locks.
- **Next Unmoved Unit**, **Next Unit That Can Attack**, and general next-unit
  selection cycle eligible units of the active team. Attack suggestions check
  the phase's weapon types, range and LOS; players choose the target.
- Leaving Movement/Shooting/Fight can warn about unfinished actions. **Advance
  anyway** permits passing. Manual tools remain available.
- Line, Two Rows and Cluster propose nearby formations. **Auto Place Unit** scans
  a deployment zone in a fixed order for the first legal coherent formation.
  Both use existing base collision, board, terrain, movement and coherency checks,
  and leave the player to confirm or cancel. There is no tactical optimization.
- Existing move confirmation continues to update spatial/objective state and
  record the battle log; no extra bookkeeping click is required.
- Attack Control lists enemy units and exact eligible-model/dice counts. A
  weapon profile represents one group carried by the unit's living models.
  Assign different groups to different targets, then confirm **Resolve Groups**.
  Each group is a normal canonical attack, resolved sequentially; manual pending
  damage must be allocated or explicitly discarded before the next group.
  Online groups wait for the host's recorded result before continuing.
- **Suggested Model** selects a living wounded recipient first, then stable ID
  order. It applies no damage. Existing auto-allocation/removal stay OFF by default.
- Scenario cover is explicit, not inferred from partial visibility. A terrain
  item can set `cover_bonus` from 0 to 3. Every living defending base must touch
  the same area's footprint to qualify. The strongest qualifying area applies;
  bonuses do not stack. Save = base save + positive AP penalty − cover, clamped
  to 2+ through impossible 7+. Legacy signed AP remains supported. Example:

  ```json
  {
    "id": "relay_cover", "title": "Relay apron", "kind": "box",
    "size": [9, 0.12, 6], "position": [-13, 0, 5],
    "blocks_movement": false, "blocks_los": false, "cover_bonus": 1
  }
  ```

- Objective markers show A/B or neutral/contested symbols as well as color.
  Hover retains exact team counts. Scenario scoring remains once per full round;
  a round-complete dialog shows team totals when the next round begins.

## Combat presentation and preferences

A short cosmetic panel stages the already-recorded hit, wound and save dice,
with success symbols and colors. It explains AP/cover/save arithmetic and damage.
The full exact result remains in Attack Control and the chronological battle log.
Large dice groups scroll instead of expanding over the whole screen. Continue
dismisses the presentation, and it also dismisses automatically.

Lightweight tracers/impact rings use canonical attack endpoints, expire after
0.16 seconds, and never simulate gameplay collision or randomness. Defeated
miniatures remain visibly compressed/marked until explicitly removed under the
default policy. Replay emits the same cosmetic feedback from recorded results.

Settings include Low/Medium/High quality, Fast/Normal/Detailed combat timing,
cosmetic effects, optional combat camera (OFF), reduced motion, UI text scale,
phase warnings (ON), combat summaries (ON), automatic scoring (ON), and existing
auto-allocation/removal (OFF). Scoring/allocation/removal are host preferences
online. Camera focus is a one-time transition, so manual input immediately takes
over; reduced motion makes camera transitions immediate. Panning now accelerates
and decelerates smoothly. No screen shake is used.

## Persistence and multiplayer

The action schema is unchanged. Cover metadata lives in frozen scenarios and
cover-adjusted saves/dice are recorded in attack results; replay never recalculates
them. Appearance changes do not alter base sizes or profile statistics. The
existing compatibility gate now reports 0.6.0 so older gameplay builds cannot join.
There is no particle synchronization, mod transfer or new networking service.

A small real ENet host/guest check resolved one attack with explicit cover. Both
received dice `[6,5,3,2,5,1,5,2,4,4]`, cover bonus 1 and identical state hash
`7338b6f7a17cac70917106a692b8b2fff33647ef8f1f7b049a0479934f1335b1`.
The focused validation also checks rejection of an older version manifest.

## Measured performance

Windows, Godot 4.6.1 Compatibility/OpenGL, Ryzen 5 2600 (6 cores / 12 threads),
GTX 1660 Ti, 1280×800, VSync disabled, 90 sampled frames per mode. These short
local measurements are not universal performance guarantees. Mixed authored
miniatures use the same deterministic benchmark layout as 0.5.0; the table below
compares its previous optimized run with the new Medium presentation.

| Models | 0.5 FPS / frame | 0.6 FPS / frame | Move-mode frame | Target-mode frame | Load | Static memory |
|---|---|---|---|---|---|---|
| 100 | 223.5 / 4.48 ms | 139.3 / 7.18 ms | 7.04 ms | 7.15 ms | 906 ms | 99.8 MiB |
| 200 | 135.3 / 7.39 ms | 83.2 / 12.01 ms | 11.95 ms | 12.24 ms | 615 ms | 124.2 MiB |

Selection averaged 0.75 ms, movement validation 0.52/0.92 ms and uncached attack
preview about 0.10 ms. The first size includes cold geometry/resource creation;
the second reuses caches. Additional surfaces, shadows and MSAA cost frame time,
but both tested battle sizes stayed smooth. Low is available for weaker hardware.
No spatial-index rewrite or interactive MultiMesh conversion was justified.
Stationary measurement geometry now reuses its previous line/endpoints rather
than recreating them every frame. Existing event-driven objective/LOS/coherency
caches and merged miniature geometry remain intact.

Raw data: [experience_060.json](benchmarks/experience_060.json).
Repeat with `--script res://tools/benchmark_large_battle.gd -- --counts=100,200 --label=my_run`.

## Validation and package

Targeted development used the movement/combat suite, 49 experience checks,
graphical captures after presentation changes and the single 100/200 model
benchmark run. Experience checks cover settings, themes, validation, formations,
deployment, bookkeeping/undo/redo, cover, target/group controls, suggested damage,
sequential profiles and exact replay state/dice.

The full Godot runner was executed **once**. It found eight assertion failures
from three causes: cover's new numeric field needed JSON type normalization,
the art-directory reference failed the portable-path audit, and the original
auto-arrange fallback needed to be retained. These were fixed; only affected
replay/save (48), application (189), content (251) and experience (49) suites were
rerun. Final aggregate: **1,070 passing checks** across eleven suites:

| Suite | Checks |
|---|---:|
| Prototype | 275 |
| Squads/combat | 76 |
| Scenario/replay | 48 |
| Application/resource audit | 189 |
| Existing network regression | 48 |
| Existing internet-readiness regression | 67 |
| Existing network-failure regression | 3 |
| Content | 251 |
| Mods | 54 |
| Performance caches | 10 |
| 0.6 experience | 49 |

The comprehensive runner includes its existing Godot network checks; these were
not repeated as separate testing matrices. The additional two-client test was one
small ENet attack/compatibility check, not the previous full multiplayer workflow.

Fresh standalone Windows export: **15 smoke checks passed**, graphical
Compatibility/OpenGL launch, exit code 0. The packaged application loaded Ashfall
Station and its authored models, confirmed a coherent move, resolved ranged and
melee attacks, retained exact dice, recorded end-phase scoring, and restored the
same complete state hash after save/load. The screenshot exposed overflowing
combat controls; the panel now scrolls, with a new bounds assertion verified in
the corrected package. This was automated in the actual graphical executable,
not a claim of a manual play session.

[Packaged combat screenshot](combat_060.png). The build is
`builds/windows/GrimTable.exe`, with its existing accompanying DLL and licenses.
Windows was rebuilt; older Linux/macOS artifacts were not refreshed. The existing
nonblocking Windows certificate-store warning still appears in engine logs.

No signaling, TURN, public-server or WebRTC infrastructure matrix was rerun.
Third-party asset sources/licenses are unchanged; see [ASSETS.md](ASSETS.md).

## Limits and next work

- Stylized primitive miniatures remain deliberately low-poly; this is not a
  sculpted or animated miniature pipeline.
- Weapon groups currently mean unit-wide loadout profiles. Per-model mixed
  equipment authoring and a more elaborate split-fire editor are future work.
- Cover uses explicit all-model footprint areas. There is no partial-cover
  visibility estimate, difficult-ground movement rule or new charge-roll flow.
  Melee uses the existing shared range/LOS/attack pipeline.
- Formation tools can reject obstructed proposals; they do not route or optimize
  positions. Whole-army auto-deployment is not added.
- No physical 3D dice, audio library, elaborate particles, LOD pipeline or new
  casualty fade system. Optional automatic removal still removes immediately.
- Objective counts remain automatic; a persistent manual objective-owner override
  is not added. Existing wound/setup/phase controls remain available.
- UI scale applies on the next battlefield; long cards use scrolling. The editor
  preserves theme/cover JSON but has no dedicated theme/cover authoring controls yet.
- Benchmark samples are short and do not represent every terrain/camera/layout.

Recommended next milestone: focused player usability sessions and polish of the
remaining interaction edges—mixed equipment editing, deployment discoverability,
editor theme/trait controls and longer performance testing on another GPU.
