# GrimTable 0.4.0 content and automation report

Date: 2026-10-16. The existing tabletop, editor, networking, save/load and replay
systems were extended. **The full requested milestone is not complete:** CC0
miniature downloads were unavailable, so original authored substitutes ship in
their place. A project-wide software license also remains a maintainer decision.

## Assets and licensing

| Imported package | Creator | Source | License | Exact imported models |
|---|---|---|---|---|
| Space Station Kit 1.0 | Kenney | https://kenney.nl/assets/space-station-kit | CC0-1.0 | 97 GLBs |
| Modular Space Kit 1.0 | Kenney | https://kenney.nl/assets/modular-space-kit | CC0-1.0 | 40 GLBs |

License pages and archive License.txt files were verified before inclusion.
Retrieval date: 2026-10-16. Original archives, extracted unmodified GLBs,
colormap PNGs and license notices are retained. Every filename/checksum is in
`assets/third_party/assets.json`; each file inherits its package's creator,
source, license and retrieval metadata. `docs/asset_audit.json` lists every GLB's
triangles, materials and textures. See [ASSETS.md](ASSETS.md) for the sources and
exact reproducible import steps. `container-wide.glb` is used in both showcases.

Unavailable: Character Soldier, SWAT, Mech, Tank, Orc, Enemy Small, Enemy Large,
Alien, Robot Enemy, Enemy Flying, and Sci-Fi Modular Gun Pack. Poly Pizza direct
retrieval returned HTTP 403; the creator-linked Ultimate Space Kit Google Drive
download returned quota-exceeded HTML. No such payload was treated as an asset,
and no restriction was bypassed. CC0 was verified on the listed pages except
Robot Enemy, whose page timed out. No Quaternius model or weapon is shipped.

All sixteen unit visual scenes are original GrimTable primitive-based art with
faction colors and accessories. They replace the plain cylinder presentation
in the new showcases, but do **not** meet the requested imported-CC0-unit-art
acceptance criterion. The original generic demo remains available.

No root project license was present. LICENSE records that status without
inventing a license grant. Kenney and existing WebRTC third-party notices are
preserved; the Windows build ships the asset license notices and registry.

## Content created

| Faction | Four unit archetypes |
|---|---|
| The Legion | Legion Trooper, Legion Heavy, Legion Walker, Legion Battle Tank |
| The Horde | Horde Raider, Horde Bruiser, Horde Gunner, Horde War Machine |
| The Swarm | Swarm Crawler, Swarm Hunter, Swarm Brood Beast, Swarm Winged Beast |
| The Synthetics | Synthetic Drone, Synthetic Sentinel, Synthetic Destroyer, Synthetic Walker |

Twelve weapon definitions: Pulse Rifle, Combat Blade, Breach Cannon, Siege
Projector, Scrap Blades, Scrap Repeater, Scrap Crusher, Raking Talons, Crushing
Fangs, Spine Volley, Arc Beam, Energy Lance.

`ContentRegistry` reads factions/units/weapons/models/scenarios from JSON.
Scenario unit IDs resolve profiles; profiles resolve weapon IDs and visual
scenes. Gameplay identity and primitive collision remain separate from art.
The editor palette derives the new entries from this same registry.

Bases use explicit millimeter diameters converted to inches. Current profiles
use 25/32/40/60/80/100 mm, and other sizes such as 50 mm work with the same helper.
Gameplay height, LOS Marker3D height, art scale and stable cosmetic ID are
independent. Small deterministic yaw/scale and three tint variants affect art
only. Original panels, backpacks, sensors, antennae, spikes and crests are built
by the reusable visual script; shared box meshes/materials reduce duplication.

The pipeline provides pinned fetch/checksum verification, safe manifest-listed
archive extraction, license/checksum-gated visual wrapper generation, and an
offline GLB audit. Missing scenes warn and fall back without disabling gameplay.
All 137 imported GLBs loaded in Godot 4.6.1. Their source totals are 102,512
triangles, maximum 10,880 per GLB, one material per GLB, shared 512 x 512 colormap
textures. No large-army performance benchmark was performed.

## Automation and usability

- Attack panel: weapon selection, per-model base-edge range and LOS filtering,
  green/red eligibility rings, attack-count preview and explicit confirmation.
  The host recomputes eligibility and rolls hits, wounds and saves. All arrays
  are visible in the result/battle log. Fixed damage is failed saves x damage.
- Central wound-strength comparison retained; positive AP penalties added for
  new profiles, with legacy signed AP preserved. Impossible saves use 7+.
- Manual allocation/removal remain defaults. Opt-in host settings choose an
  already-wounded valid model first, then a deterministic stable ID, and record
  ordinary damage/removal actions. Defeated models remain visible by default.
- Existing movement rings, origins, distances, coherency links and validation
  retained. Auto-arrange proposes a nearby grid or line and still requires
  movement confirmation. It never chooses tactical destinations.
- Movement phase surfaces the movement workflow; Shooting/Fight surfaces Attack.
  Manual tools and the offline sandbox active-player override remain available.
- Readable multi-weapon unit cards, compact hover information and wound/defeat
  indicators added. Original faction palettes are independent of team ownership.
- Objectives count living bases touching the control radius. A unique highest
  count controls; ties/no models are neutral. Hover/sidebar show counts, faction
  names and control. Optional scenario points award both teams at the second
  team's End phase once per full round. Phase rewinds cannot duplicate points.
  Manual Round+ skips scoring. Both showcase scenarios award one point/objective.

## Multiplayer, replay and persistence

Host authority remains in the existing request system. Requests now include a
validated equipped weapon index. Ownership/active-player checks remain enforced.
Game version is 0.4.0; compatibility includes the catalog and unit/weapon files.
No GLBs are transmitted. Whole-profile file hashes conservatively reject even a
profile-only visual-path change; direct art changes need not alter gameplay.

New matches embed unit and weapon snapshots in their initial scenario. New
saves/replays preserve full floating precision; replay uses recorded dice and
action deltas without rerolling. IDs, factions/teams, loadouts, cosmetics, wounds,
positions, removals, pending damage and objective scores persist. Old archives
without snapshots still rely on their installed legacy profiles.

## Validation actually run

All original test files were retained. Counts in the application suite grow with
the source-reference audit, so that suite's total differs from the old 55.

| Godot suite | Checks | Failures |
|---|---:|---:|
| Original tabletop | 275 | 0 |
| Squads/combat | 76 | 0 |
| Scenarios/replay | 48 | 0 |
| Application/editor/path audit | 153 | 0 |
| Network authority/hash | 48 | 0 |
| Internet readiness | 67 | 0 |
| Unavailable-service sockets | 3 | 0 |
| New content/automation | 251 | 0 |
| **Total Godot** | **921** | **0** |

All **19 signaling/probe tests** also passed, for **940 checks/tests** across
these runners, excluding additional runtime/network smoke assertions. The default
Node test launcher hit this environment's child-process EPERM restriction; the
same tests passed with `node --test --test-isolation=none`.

The Godot runner uses an isolated cloned project and application-data directory.
`python tools/fetch_assets.py --check` passed all included source hashes.
The visual import tool successfully generated `normalized_cargo.tscn` from its
verified registered GLB. Source logs are under `.runtime/`.

## Runtime smoke results

Native Windows graphical tests ran on Godot 4.6.1 Compatibility/OpenGL with an
NVIDIA GTX 1660 Ti. Both showcase boards were rendered and screenshots inspected.
The source smoke exercised picking, selection, squad movement, coherency,
auto-arrange, weapon changes, enemy targeting, range and LOS exclusion,
confirmation, dice, manual damage/casualty removal, optional allocation/removal,
objective scoring/contesting, phase advance, save/load and exact replay state.
This was scripted runtime testing plus screenshot inspection, not a full manual
playtest or large-army FPS benchmark.

Two real clients passed ENet and local WebRTC smoke with Legion/Synthetic
profiles and visuals, movement/undo/redo, authoritative attack dice, manual damage,
casualties, identical objective-control results, shared dice and equal hashes.
Snapshot resync repaired deliberate client divergence. The WebRTC test continued
after closing signaling. These are localhost tests; public TURN/WSS and
separate-network play were not tested.

The Windows release was rebuilt and copied with its native DLL/licenses to
`.runtime/standalone-content`, containing no source project. Launched from that
directory, it passed packaged generic/editor/save/replay checks and new faction
visual/combat/save/load/replay checks at 1280 x 800. The packaged result is PASS.
Two exported ENet clients and two exported WebRTC clients also passed. The existing engine certificate-store
warning remains and did not prevent these local tests.

Linux/macOS artifacts were not rebuilt or runtime-tested in this milestone and
remain prior-version packages. Do not treat them as 0.4.0 releases.

## Remaining work / next milestone

1. Obtain the unavailable verified CC0 unit models using permitted provider
   downloads, retain provenance and replace the authored substitutes via wrappers.
2. Have maintainers select the software/content license for original project work.
3. Perform large-army frame-time/draw-call testing and targeted visual refinement.
4. Continue public WSS/TURN and separate-network QA, followed by platform runtime QA.

There is no AI, army-building points system, variable-damage dice, complex
abilities, campaign, workshop browser, or proprietary rules content. The simplified
single-ray LOS, flat movement, sandbox action economy and legacy archive limits
remain intentional and documented in [CONTENT.md](CONTENT.md).
