# GrimTable 0.5.0 — external packs and large battles

Date: 2026-10-16. This milestone extends the existing registry, visual pipeline,
editor, persistence and compatibility gate. No new networking infrastructure,
AI, campaign, matchmaking or rules subsystem was added.

## Official asset retry

The official Quaternius pages for Animated Mech, Animated Tanks, Ultimate
Monsters, Sci-Fi Essentials, Sci-Fi Modular Guns, and Ultimate Modular Men /
Characters were rechecked and their CC0 links verified. Limited requests reached
the creator-linked model folders; sampled mech/tank/monster file downloads
returned quota/restriction HTML. Other download flows remained manual. No
restriction was bypassed, and no new third-party miniature was imported.

Replaced visuals: **none**. All sixteen authored miniature scenes remain, and
their unit profiles now explicitly preserve permanent fallback scene references.
Existing Kenney assets remain unchanged. Priority walkers/tanks/creatures still
use their original art. [ASSETS.md](ASSETS.md) and the machine-readable registry
record official sources, licenses, retry outcomes and manual steps. External
download unavailability does not block this milestone.

## External content packs

- `ModLoader` discovers `user://mods/` and optional development `res://mods/`.
  It validates manifests/content and registers each pack transactionally.
  Invalid packs report an error without preventing healthy packs or built-ins.
- Required manifest fields: `id`, `name`, `version`, `grimtable_version`, `author`,
  `description`. Optional metadata: `homepage`, `license`, `dependencies`.
  Exact/minimum version requirements and dependency IDs are supported; complex
  semantic-version ranges and dependency version constraints are deferred.
- Content IDs use `pack:local_id`; `grimtable:` aliases preserve existing
  built-in IDs. Duplicate content/pack namespaces reject cleanly. Dependencies
  load before dependants, with deterministic ID ordering and cycle errors.
- JSON-only factions, units, weapons and scenarios are supported. Static,
  embedded-texture GLBs load at runtime without an editor import cache. External
  scenes/scripts/native libraries are not loaded. Path confinement, link checks,
  format/resource limits and restricted GLB metadata protect the data boundary.
- Main Menu → Mods shows name, version, author, enabled state and errors, plus
  folder/reload controls. Enable/disable persists. Reload is refused while an
  active battle/editor exists. The editor palette derives pack/faction groups
  from the loaded registry.

The developer sample, `examples/mods/example_army`, provides **Frontier
Expedition**, **Expedition Scout**, **Expedition Anchor**, **Expedition Carbine**,
**Field Projector**, and **Frontier Outpost**. It uses authored built-in visuals
only. Copy the folder to `user://mods/` and reload. A convenience copy is shipped
under `builds/windows/examples/mods/`. Complete JSON examples, install steps,
schema limits and troubleshooting are in [MODDING.md](MODDING.md).

## Save, replay and multiplayer behavior

Saves and initial scenarios record required pack IDs/versions, including
transitive dependencies. Live saves reject missing or wrong-version packs with
a clear message. Gameplay profile/weapon snapshots remain authoritative for
old matches. Snapshot-backed replays can run without the visual pack, using
permanent fallback art and recorded dice. Existing built-in IDs remain valid.

The existing multiplayer compatibility gate now compares enabled pack IDs,
versions and normalized gameplay hashes. Mod install paths and external visual
paths are excluded from those hashes. Missing, extra-enabled, version-mismatched
or gameplay-mismatched packs reject before play. Built-in compatibility checks
remain intact. No mods/files are sent over the game connection.

The lightweight compatibility test exercised this actual gate with matching,
wrong-version, changed-hash and missing-pack manifests. No full ENet/WebRTC
gameplay matrix was repeated, and no signaling protocol code was modified.

## Measured performance

Hardware: AMD Ryzen 5 2600, 12 logical CPUs; NVIDIA GTX 1660 Ti; Windows;
Godot 4.6.1 Compatibility/OpenGL; 1280 x 800; VSync off; uncapped.

| Models | Baseline FPS | Optimized FPS | Optimized frame ms | Scene load ms | Static memory MiB | Select/pick ms | Move validation ms | Attack preview ms |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 25 | 255.2 | 498.7 | 2.01 | 654.7 | 79.9 | 0.691 | 0.180 | 0.095 |
| 50 | 286.6 | 366.0 | 2.73 | 178.5 | 83.8 | 0.757 | 0.293 | 0.094 |
| 100 | 163.3 | 223.5 | 4.48 | 271.1 | 92.3 | 0.692 | 0.493 | 0.095 |
| 200 | 92.3 | 135.3 | 7.39 | 464.7 | 107.7 | 0.700 | 0.934 | 0.095 |
| 300 | 61.5 | 95.3 | 10.49 | 645.6 | 123.7 | 0.690 | 1.369 | 0.097 |

One baseline and one optimized run were made. Each mode averages 90 frames after
12 warm-up frames; high-FPS cases are noisy. The first load includes initial
setup. Static memory is Godot's allocation monitor, not process RAM/VRAM.
Selection is API+pick CPU time; movement validation is measured separately from
stationary movement-mode rendering. These are not universal guarantees or full
input-latency measurements. [PERFORMANCE.md](PERFORMANCE.md) and the raw JSON
reports describe the deterministic setup and exact limitations.

Measured improvements: decorative mesh parts are batched/shared within each
miniature, leaving unique model identity/collision untouched. At 300 models,
targeting draw calls fell from 10,600 to 6,329. Coherency links rebuild only when
the formation changes. Attack/LOS previews and objective control use state/
spatial invalidation instead of recurring unchanged scans. A post-physics
revision prevents stale ray results after terrain removal. Hover remains one
central ray; no unnecessary spatial partition or interactive MultiMesh rewrite
was introduced. No destructive art reduction was needed.

## Validation actually performed

During implementation, focused suites covered mods, assets/content, persistence/
replay and cache correctness. Benchmarks were run before/after optimization.
The final comprehensive Godot runner was executed **once**, near completion:

| Suite | Checks | Failures |
|---|---:|---:|
| Original tabletop | 275 | 0 |
| Squads/combat | 76 | 0 |
| Scenarios/replay | 48 | 0 |
| Application/editor/path audit | 175 | 0 |
| Network authority/hash | 48 | 0 |
| Internet readiness | 67 | 0 |
| Unavailable-service sockets | 3 | 0 |
| Content/assets | 251 | 0 |
| External mods | 54 | 0 |
| Performance cache correctness | 10 | 0 |
| **Total** | **1007** | **0** |

Application audit counts grow with source references. No existing test suite
was removed. The 19 previously proven signaling/server tests were **not rerun**:
only the client-side compatibility manifest changed, with no shared backend or
signaling protocol change. Public network, LAN gameplay and TURN matrix tests
were likewise not repeated. Included asset checksums passed the offline checker.

The fresh Windows release was copied with its DLL/licenses to an isolated folder
without the source project. Exactly one new minimal packaged smoke verified:
launch, built-in content, creation of the user mods directory, external sample
loading and starting Frontier Outpost. It returned **PASS / exit 0**. Its native
rendered screenshot was inspected. The old comprehensive gameplay packaged smoke
was not repeated. Windows shows the previously known certificate-store warning;
it did not block these offline checks. Linux/macOS artifacts were not rebuilt.

## Limitations and next milestone

External visuals currently require static GLB with embedded PNGs; no animations,
external texture paths, custom GLTF extensions, executable scenes or scripting
API. Pack dependencies are ID-only; multiplayer conservatively requires identical
enabled pack sets, including unused packs. Versioned saves require installed
packs for live play, while replay can use snapshots/fallbacks. GLB safety depends
in part on Godot's native parsers; this is a restricted data loader, not a process
sandbox. Cross-platform runtime mod loading remains untested.

No software license was selected. [LICENSING_DECISION.md](LICENSING_DECISION.md)
compares MIT and GPL-3.0 for the project owner; third-party notices are preserved.

Recommended next milestone: obtain the unavailable creator models through
permitted downloads, prepare static mod-ready visuals, and extend performance
QA to longer active-drag runs and additional hardware/platforms. Resolve the
owner's license choice before public distribution as licensed open source.
