# GrimTable 0.13.0 — Environment & Map Art Pass

This release focuses on board composition, landmark geometry, ground treatment
and environment editing. It adds eight original Blender terrain assets and
recomposes the major showcase maps. Miniature profiles, combat rules, AI
architecture, networking, save/replay and mod architecture were not rebuilt.

## Flagship and map composition

**The Hollow Basilica** is the new flagship and main-menu diorama. The existing
Blender nave is moved into the midfield composition, facing a broken gatehouse.
A reliquary court, cloister, blasted vestry, broken civic screen and cooling
shrine form secondary clusters. A damaged processional crossing connects the
three objectives. Open foreground staging gives way to denser midfield cover;
the outer flanks preserve two continuous infantry routes.

The objectives are named **Reliquary Access**, **Broken Crossing** and
**Emergency Relay**, with floor rings/inlays and nearby landmark relationships.
Support units have an opening ranged opportunity around the blockers; rifle
squads still need to maneuver. Default framing looks toward the crossing and
nave, rather than treating the board as an uncomposed prop gallery.

**The Ashen Basilica** adopts the same curated gothic layout as the flagship, as
an upgrade of its existing scenario identity. **Ashfall Manufactorum** uses a
refinery core, cooling bank, supply hoist and abandoned press, transformer,
defensive casemate and severed conduits. **Toxic Forge** shifts the core, cooling
bank and bunker and adds runoff pads with difficult-ground traits, pollution
color treatment and corroded industrial surfaces. These two maps share the
industrial kit and several lane anchors; they are not wholly unrelated layouts.

| Review capture | Path |
|---|---|
| Flagship wide | [Wide shot](environment/flagship_wide_0130.png) |
| Default gameplay | [Gameplay](environment/flagship_gameplay_0130.png) |
| Environment detail | [Nave/court detail](environment/environment_detail_0130.png) |
| Tactical overlay | [Tactical view](environment/flagship_tactical_0130.png) |
| Old/upgraded map | [Matched comparison](environment/ashen_basilica_comparison_0130.png) |
| Manufactorum | [Industrial board](environment/ashfall_manufactorum_0130.png) |
| Toxic Forge | [Toxic board](environment/toxic_forge_0130.png) |
| Editor browsing | [Palette preview](environment/editor_palette_0130.png) |

The old/upgraded Ashen Basilica images use the same 1440×900 viewport, camera
position, pitch, heading and framing. Ground, lighting, models and map composition
are allowed to change: those are the subject of the comparison. The review sheet
only labels and arranges unchanged captures. The old image was captured before
this environment pass at High quality; the final after image comes from the
Windows package at Medium quality (both Compatibility rendering).

## Terrain families and source geometry

Created in Blender **5.0.1**, integrated in Godot **4.6.1**. Every new landmark has
an editable `.blend`, a separate evaluated game mesh and a self-contained GLB.

| Asset | Triangles | Source | Export |
|---|---:|---|---|
| Broken gatehouse | 27,352 | [Blend](../art/blender/environment/gatehouse.blend) | [GLB](../assets/terrain/environment/gatehouse.glb) |
| Cloister wall | 23,552 | [Blend](../art/blender/environment/cloister.blend) | [GLB](../assets/terrain/environment/cloister.glb) |
| Refinery core | 16,004 | [Blend](../art/blender/environment/refinery_core.blend) | [GLB](../assets/terrain/environment/refinery_core.glb) |
| Cooling bank | 5,456 | [Blend](../art/blender/environment/cooling_bank.blend) | [GLB](../assets/terrain/environment/cooling_bank.glb) |
| Blasted casemate | 9,824 | [Blend](../art/blender/environment/breach_bunker.blend) | [GLB](../assets/terrain/environment/breach_bunker.glb) |
| Split-circle reliquary | 2,544 | [Blend](../art/blender/environment/reliquary.blend) | [GLB](../assets/terrain/environment/reliquary.glb) |
| Freight hoist / abandoned press | 7,068 | [Blend](../art/blender/environment/hoist.blend) | [GLB](../assets/terrain/environment/hoist.glb) |
| Revetment trench | 4,892 | [Blend](../art/blender/environment/trench.blend) | [GLB](../assets/terrain/environment/trench.glb) |

Gothic pieces use extruded broken wall profiles, real Boolean-cut lancet windows,
individual arch stones, tapered buttresses, damaged pinnacles, bent support rods
and ground fragments. Industrial pieces use curved variable-section vessels,
reinforcement hoops, swept coolant lines, load-bearing ribs, gauges, lattice
hoist members and an abandoned press bed. Defensive pieces use shaped damaged
concrete profiles, recessed firing slits and low revetments/duckboards.

Existing procedural gothic walls, pillars, pipes, generators, barricades, craters,
rubble, wreckage and factory pieces remain available. The new palette entries
complement those families. Small scatter uses shared chipped ground fragments,
embedded maintenance details and wear markings; this is not a new exhaustive
library of individually sculpted tools, corpses or supply props. Multiple common
pieces gain deterministic soot/rust/worn treatments, while source profiles give
the gatehouse and cloister distinct damage silhouettes.

See [source workflow](../art/ENVIRONMENT.md),
[mesh metrics](environment/mesh_metrics.json) and
[source/export validation](environment/asset_validation.json).

## Ground, materials and atmosphere

- Cathedral ground combines broken flagstone, inset ceramic-like paving,
  processional bands, a damaged floor rose, ash margins and blast staining.
- Industrial ground uses worn steel decking, embedded conduits, drainage grates,
  broken hazard borders, scorched concrete and oil-like staining.
- Toxic ground adds contaminated color breakup and runoff pools. Difficult-ground
  penalties come from explicit scenario terrain, not the shader.
- A siege/wasteland appearance preset uses the existing desert ground theme with
  muted earthen breakup and dust; it is a theme preset, not a fourth new scenario.
- Shared materials cover weathered masonry, tile, ash, iron, rust, brass, soot,
  hazard paint and muddy/sludge ground. New terrain retains the original 1024px
  pigment/ORM atlases and gains world-space masonry courses, restrained grime and
  varied roughness. There are no new normal/AO bakes or photographic textures.
- Reusable planar wear masks work in Compatibility rendering. Broken slabs and
  ground fragments are actual low geometry, batched by shared material.
- Cool cathedral ambient and warm key light preserve stone volume; industrial
  boards use cooler ambient, while Toxic Forge has a muted polluted tint. Day,
  Dusk and Night remain available. Clear disables fog and emitters; Dust and Vapor
  select sparse particles. Existing Low quality/reduced-motion/particle settings
  suppress atmospheric emission. No flashing effects were added.
- The table remains a physical framed diorama, with Obsidian or Brass surround
  trim. Empty staging pockets are intentional play space, not scatter targets.

Visual iterations removed the uniform all-over tile treatment, reduced unrelated
edge props, rebalanced ground brightness and removed rectangular scenery base
plates. A batching issue that revived hidden plates and caused floor shadow
artifacts was fixed by removing those plates before batching.

## Editor and gameplay readability

The editor groups terrain by Gothic, Industrial, Battlefield, Scatter,
Centerpieces, Decorative and Objectives, with an All view and a rendered 3D
preview. The placement ghost continues to show the authoritative footprint.
Category changes refresh that ghost. Existing duplication, 15-degree rotation,
ground placement and optional grid snap are retained. Authored environment
footprint dimensions are locked in the property panel; move/rotate/duplicate are
available. Ground theme, lighting, atmospheric mode/density, clutter density and
surround finish can be selected independently or initialized from a theme preset.
Appearance fields survive scenario capture/save/load and old scenarios receive
compatible defaults.

The ground grid is hidden by default and exposed during movement, measuring,
editing or tactical view. Terrain inspection still reports actual cover,
movement and LOS traits. Decorative ground dressing has no bodies and adds no
rules. Rubble outside blocked terrain stays low, so it does not impersonate a new
barrier. Objective centers and unit spawns are validated as reachable/clear.

Collision remains conservative: the nave uses its original L-shaped footprint;
new standalone landmarks use explicit box footprints. Hoist/press footprints are
blocked even where a visual gap remains, and firing windows do not create new
LOS rules. Upper floors and platforms remain decorative. Canonical miniature
bases, authoritative positions and LOS heights are unchanged.

## Performance and validation

One 100-model and one 200-model benchmark were run on the documented Ryzen 5 2600
/ GTX 1660 Ti setup: Godot Compatibility, Medium, 1280×800, VSync off, 90 measured
frames per mode. The 120-inch mixed-roster stress fixture/camera is retained from
0.12.0, with the new landmark layout and environment dressing enabled.

| Models | Idle FPS | Movement frame | Targeting frame | Draw calls | Static memory | Load |
|---:|---:|---:|---:|---:|---:|---:|
| 100 | 138.4 | 7.13 ms | 7.39 ms | 2,662 | 158.5 MB | 2.05 s |
| 200 | 82.1 | 12.31 ms | 12.78 ms | 4,678 | 177.3 MB | 0.84 s |

Previous short samples were 135.6/78.8 FPS. These results show no observed
regression in this fixture, not a guarantee of a general speedup. Terrain content
and batching changed, caches affect load times, and these are short samples.
There was no repeated benchmark matrix or worst-case all-hero roster test.
See [raw performance data](benchmarks/environment_0130.json).

Targeted validation covers all eight Blender sources/GLBs, atlas retention,
scenario loading, legal staging, objective access, two flank routes, firing
opportunities, movement/LOS blockers, tactical footprints, map roundtrip, palette
filter/preview, explicit landmark placement/duplication and appearance persistence.
The source-export path was also exercised on the gatehouse. The final focused
environment suite passed **221 checks**, the affected terrain/editor suite passed
**219 checks** in the full run, and the visual suite passed **17 checks**.

The complete regression ran **exactly once**, passing **1,971 checks across 21
suites with zero failures**. No corrective full rerun was needed. The runner's
existing local network/readiness assertions were included; no separate signaling,
TURN, public-infrastructure or network/AI matrix was rerun. See
[the complete suite digest](environment/regression_0130.json).

A fresh Windows release export passed its **single packaged smoke run: 23 checks,
zero failures**. It opened all upgraded themes, captured default framing and the
tactical view, committed a legal squad move, checked passage/cost through trench
cover, tested blocked and clear firing lanes, resolved an attack around the
landmarks and completed one legal AI round on the flagship. Exact game save/load,
editor category browsing, authored landmark placement and exact scenario
save/load also passed. See [the durable packaged result](environment/packaged_validation_0130.json).
The battlefield screenshots listed above are from that package. The editor image
uses a fresh native Godot editor launch of the same source, so it does not inherit
the battle smoke's round-summary dialog. Earlier source-only capture passes were
visual reviews, not additional packaged smoke executions.

The standalone is `builds/windows/GrimTable.exe`. Distribute its containing folder
with the native DLL and license files. Only Windows was exported/tested for this
milestone. Build metadata and release notes identify 0.13.0.

## Provenance and remaining environment weaknesses

All new geometry, shaders, layouts and ground markings are original GrimTable
MIT work. No third-party models or new downloads were introduced. Existing asset
and engine notices continue to apply in `THIRD_PARTY_NOTICES.md`.

The boards have stronger anchors and floor composition, but remain stylized
modular tabletop environments rather than bespoke sculpted landscapes. Several
small 0.11 props and rubble forms are still simple. Stone damage/paint largely
uses reusable geometry and procedural wear; localized texture storytelling and
high-to-low normal/AO bakes remain absent. Industrial/toxic maps share substantial
kit and composition. The surround/background remains understated. Dense scatter
is limited deliberately, and conservative collision prevents some visually open
spaces from being traversable. No claim of professional art quality is based on
validation counts alone; use the screenshots to judge the improvement.

Recommended next milestone: a focused environment texture/terrain refinement
pass on this flagship—manual damage sculpting and baked stone/metal normals,
more distinctive secondary industrial structures and a small curated storytelling
prop set—while preserving its readable lane plan and existing gameplay rules.
