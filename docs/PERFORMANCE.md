# Large-battle benchmark ? 0.5.0

Measured on Windows with **AMD Ryzen 5 2600 (6 cores / 12 logical CPUs)**,
**NVIDIA GeForce GTX 1660 Ti**, Godot **4.6.1**, Compatibility/OpenGL renderer,
1280 x 800 window, VSync disabled and no FPS cap. These are local observations,
not universal minimum requirements or a guaranteed performance target.

Run from a separate test application-data environment:

```sh
godot --path . --script res://tools/benchmark_large_battle.gd -- --label=my_run
```

The deterministic generator creates 25/50/100/200/300 models in five-model squads,
five mixed unit types, a 120 x 120 board, terrain and three objectives. It
instantiates only the scenario's art, not the whole Kenney library. Each mode
warms up for 12 frames, then averages 90 frames. Raw results and hardware metadata
are in [baseline.json](benchmarks/baseline.json) and
[optimized.json](benchmarks/optimized.json). These short runs are useful for
identifying large bottlenecks; high-FPS cases are sensitive to warm-up/noise.

## Idle render comparison

| Models | Baseline FPS | Optimized FPS | Baseline frame ms | Optimized frame ms | Baseline draw calls* | Optimized draw calls* |
|---:|---:|---:|---:|---:|---:|---:|
| 25 | 255.2 | 498.7 | 3.92 | 2.01 | 1256 | 916 |
| 50 | 286.6 | 366.0 | 3.49 | 2.73 | 2066 | 1386 |
| 100 | 163.3 | 223.5 | 6.12 | 4.48 | 3686 | 2326 |
| 200 | 92.3 | 135.3 | 10.83 | 7.39 | 6926 | 4206 |
| 300 | 61.5 | 95.3 | 16.27 | 10.49 | 10600 | 6329 |

*Draw-call counters were sampled during the targeting mode, not idle. They
include the board, UI, miniatures and their shadow passes.

## Interaction and load costs (optimized run)

| Models | Scene load ms | Godot static memory MiB | Select + pick ms | Squad validation ms | Attack preview ms | Movement-mode frame ms | Targeting frame ms |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 25 | 654.7 | 79.9 | 0.691 | 0.180 | 0.095 | 2.07 | 2.26 |
| 50 | 178.5 | 83.8 | 0.757 | 0.293 | 0.094 | 2.83 | 3.08 |
| 100 | 271.1 | 92.3 | 0.692 | 0.493 | 0.095 | 4.53 | 4.72 |
| 200 | 464.7 | 107.7 | 0.700 | 0.934 | 0.095 | 7.41 | 7.55 |
| 300 | 645.6 | 123.7 | 0.690 | 1.369 | 0.097 | 10.47 | 10.75 |

Scene load includes synchronous scene creation and the first physics frame.
The first case also includes initial class/resource setup; its cold load rose
from about 481 to 655 ms after the additional content loader and mesh batching.
Later warm cases are comparable. Memory is Godot's static allocation monitor,
not total process working set or VRAM.

Selection measures 100 squad-selection/HUD-update plus physics-picking calls.
Squad validation averages 30 legality checks against the full battlefield.
Attack preview averages 100 uncached range/LOS previews between five-model squads.
Movement-mode frame timing has assistance open on a stationary formation;
validation cost is measured separately. It is not an end-to-end input-latency or
continuous mouse-drag benchmark. The camera/frustum is fixed, so this is a
repeatable tabletop view rather than a promise that every model is simultaneously
visible in all possible views. Imported animated armies were not available.

## Changes justified by evidence

At 300 models the original authored art produced roughly 10,600 draw calls and
16.27 ms idle frames. Static decorative parts are now merged by material **within
each miniature** and reused across matching appearances. Geometry, palette and
individual gameplay identity/collision are preserved. Models are not converted
to a single MultiMesh. The result was 6,329 targeting draw calls and 10.49 ms idle
frames at 300 models. At 100/200 models, frames fell from 6.12/10.83 ms to
4.48/7.39 ms. The observed 50?100 model cases were smooth; 200 remained usable.

The audit also found unnecessary recurring work:

- Coherency preview previously destroyed/recreated all link nodes every frame.
  It now recomputes only when the moving squad's positions/health/costs change.
- Attack UI previously reran all per-model LOS checks every 0.2 seconds while
  unchanged. It now keys its preview on attacker/target state, weapon and spatial
  revision. The single-model target ray similarly waits for relevant changes.
- Objective UI previously rescanned every 0.3 seconds. Results now invalidate on
  actions, movement/terrain changes, deployment/turn changes and load/replay.
  Idle UI polls only a cheap revision/score key. Hover uses the same cache.
- Physics-sensitive invalidation has a post-physics revision so a terrain removal
  cannot leave a stale LOS result cached. Focused tests cover that boundary.

Miniatures have no expensive per-model `_process` loop. Hover remains a centralized
single picking ray; the roughly 0.7 ms selection measurement and 0.10 ms uncached
attack previews did not justify a spatial-index rewrite. Ordinary five-model
coherency is still quadratic when it actually changes. No aggressive mesh
reduction, texture destruction, terrain-library preload, networking rewrite or
interactive-model MultiMesh conversion was introduced.

## Validation scope

One baseline run and one optimized run were performed. Targeted cache checks
verify damage/undo/load, terrain LOS invalidation and idle link reuse. Follow-up
work should measure longer runs, active drag input latency, larger squads, varied
camera views and actual imported miniature armies on additional hardware.


## 0.6.0 presentation spot check

Medium-quality visual changes measured 139.3 FPS / 7.18 ms at 100 models and
83.2 FPS / 12.01 ms at 200 on the same documented Ryzen 5 2600 / GTX 1660 Ti,
1280×800 uncapped setup. Selection was about 0.75 ms; uncached attack preview
about 0.10 ms. Richer geometry, shadows and MSAA spend more frame time than 0.5.
Low disables shadows/MSAA. See [the experience report](EXPERIENCE_060.md) and
[raw measurements](benchmarks/experience_060.json). This was one targeted
100/200-model run; the unrelated full benchmark matrix was not repeated.


## 0.7.0 automation spot check

The same 100/200-model Medium setup measured 136.9/81.9 FPS (7.30/12.21 ms idle),
compared with 139.3/83.2 in 0.6. Selection averaged 0.86/0.89 ms; attack preview
0.092/0.095 ms. Assistant work is event-driven and coalesced. Camera assistance
is disabled in the benchmark to keep its viewpoint repeatable. One targeted
100/200 run was performed; see [raw data](benchmarks/automation_070.json) and the
[automation report](AUTOMATION_070.md). No broad optimization rewrite was needed.


## 0.8.0 Guided UX spot check

One repeatable 100/200-model Medium run measured **133.6/73.2 FPS** (7.49/13.67 ms
idle), versus 136.9/81.9 in 0.7 on the same Ryzen 5 2600 / GTX 1660 Ti machine.
Selection averaged 0.99/0.94 ms; attack previews 0.096/0.095 ms. Static memory was
124.3/149.6 MiB. The roughly 2.4%/10.7% idle-FPS reduction remained playable on this
hardware; no architecture rewrite was justified. Squad-label visibility is checked
at 4 Hz; substantive assistant/target refreshes remain event-driven.
See [raw measurements](benchmarks/guided_080.json) and the [UX report](GUIDED_080.md).


## 0.9.0 diorama spot check

One 100/200-model Medium benchmark measured **146.1/83.3 FPS** (6.84/12.01 ms idle),
versus 133.6/73.2 in 0.8 on the same Ryzen 5 2600 / GTX 1660 Ti, 1280×800 uncapped
Compatibility setup. Draw calls fell from 3,767/7,187 to 2,607/5,023; static engine
memory was 121.0/139.0 MiB. Selection averaged 0.62/0.63 ms; attack previews
0.096/0.098 ms. Existing mesh/material sharing and screen-space labels supported
the art pass without a performance-architecture rewrite. No other army sizes were
rebenchmarked. See [raw results](benchmarks/visual_090.json) and [report](VISUAL_090.md).
