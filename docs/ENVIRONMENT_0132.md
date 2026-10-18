# GrimTable 0.13.2 — Exterior Approach Refinement

Continues the completed 0.13.1 composition pass with a small cosmetic patch to
Hollow Basilica and Ashfall Station. Built with Godot 4.6.1 Compatibility on
Windows, 18 October 2026.

## Changes

- Sub-inch, low-frequency erosion breaks the regular outline of the existing
  authored road and yard masks. Sediment softens paving and steel margins into
  ash; aggregate wear varies road surfaces without changing their layout.
- Ground joints now use staggered courses and small local offsets. Existing
  localized damage masks, Blender normal/AO bakes and tactical grids are reused.
- Seven authored stretches identify surviving forecourt, processional, service
  and rail-shoulder margins. Short, low-contrast, individually chipped remnants
  avoid long parallel rows. Separate seeds make their appearance reproducible.
- The shallow geometry is 0.014–0.032 inches high, has no bodies or shadows,
  and joins the existing material batches. Loose chips respect clutter settings.
- The menu reads its version from project metadata. Project and multiplayer
  build identifiers both read 0.13.2; the existing matching-version requirement
  therefore still applies.

No changes to scenario records, objective positions, unit profiles, bases,
movement, LOS, cover, combat or save schemas are included.

## Native before/after evidence

Both phases use the same map, units, 1440×900 resolution, Medium quality and
camera settings. All images are unedited Godot renders. The capture script is
[`tools/art/capture_0132.gd`](../tools/art/capture_0132.gd).

| View | 0.13.1 baseline | 0.13.2 |
|---|---|---|
| Basilica overview | [Before](environment/0132/hollow_basilica_wide_before.png) | [After](environment/0132/hollow_basilica_wide_after.png) |
| Basilica approach | [Before](environment/0132/hollow_basilica_approach_before.png) | [After](environment/0132/hollow_basilica_approach_after.png) |
| Ashfall overview | [Before](environment/0132/ashfall_station_wide_before.png) | [After](environment/0132/ashfall_station_wide_after.png) |
| Ashfall approach | [Before](environment/0132/ashfall_station_approach_before.png) | [After](environment/0132/ashfall_station_approach_after.png) |

An initial visual review rejected brighter, longer rows of fragments because
they read as stepping stones. The final treatment uses short, single-sided,
darker remnants with flat normals. This is a restrained refinement; the two
boards still contain broad exposed ash and stylized modular floor treatment.

## Validation

Affected existing suites: **469 checks, zero failures**:

- Composition plus one AI round per map: 153. Includes legal starting bases,
  objective routes, compound movement/LOS, exact save/load, transferred canonical
  scenario state and editor placement/rotation/duplication.
- Environment/editor: 257, including legacy-themed maps and material batching.
- Guided experience: 42.
- Visual settings and presentation: 17.

The final AI rounds finished with zero invalid actions: Basilica 23 ticks and
6 movement actions; Ashfall 29 ticks and 6 movement actions. These are route
and legality checks, not competitive-balance evidence. A preliminary composition
run also passed before the final cosmetic refinement.

This patch uses affected-suite validation rather than repeating the complete
0.13.1 regression or its public-network infrastructure checks. Tests and captures
use separate workspace-local profiles to preserve player data.

## Performance sample

The existing 0.13.1 stress fixture and camera, Medium, Compatibility renderer,
1280×800, VSync off, 90 frames per mode, Ryzen 5 2600 / GTX 1660 Ti:

| Models | Idle FPS | Movement frame | Targeting frame | Draw calls | Static memory |
|---:|---:|---:|---:|---:|---:|
| 100 | 162.6 | 6.45 ms | 6.62 ms | 2,291 | 156.2 MB |
| 200 | 89.2 | 11.55 ms | 11.64 ms | 4,307 | 173.8 MB |

One short sample per size. The previous recorded sample was 157.7 / 86.3 FPS;
this does not establish a general speedup. The new dressing adds one shared
material batch in the Basilica fixture. Cold first load was 3.31 seconds;
the subsequent 200-model scene loaded in 0.95 seconds. Cache variability limits
comparison. [Raw benchmark](benchmarks/approaches_0132.json).

## Windows standalone

The separate Windows x86_64 release export passed the existing composition
smoke: **46 checks, zero failures**, exit 0. It opened both maps, moved and
attacked, checked clear/blocked LOS and objective picking, restored exact battle
and replay state, and placed/rotated/duplicated editor clusters. Screenshots
were captured by the executable during that run. Together with the affected
suites, **515 checks passed**. A separate geometry diagnostic confirmed upward
top normals on the shallow road fragments.

Run `builds/GrimTable-0.13.2-windows-x86_64/GrimTable.exe`, or extract
`builds/GrimTable-0.13.2-windows-x86_64.zip` and distribute the whole folder.
The existing `builds/windows/GrimTable.exe` remains the 0.13.1 build. DLL,
licenses, release notes and checksums are included with 0.13.2. The inherited
smoke script/result names retain `0131`; the result's version field is 0.13.2.
No other platform was exported for this patch.

## Authoring and next work

[`approaches_0132.json`](../resources/environment/approaches_0132.json) contains
the seven authored stretches. `LocationComposition` renders them through the
existing dressing system. The new `roadstone` palette entry is used only by
these remnants. Existing Blender sources and baked textures were preserved.

All additions are original MIT work; no new downloads or third-party art.
Human playtesting of the asymmetric objective lanes remains outstanding. In
particular, observe first-time players choosing the west Basilica breach and
Ashfall's cargo corridor before expanding either board or adding more maps.
