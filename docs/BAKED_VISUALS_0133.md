# GrimTable 0.13.3 — Baked Visual Finish

This milestone finishes representative existing artwork with local surface
bakes and consistent painted materials in Godot 4.6.1's Windows Compatibility
renderer. It adds no gameplay systems or Workshop UI.

## Baseline and scope

The starting repository was at 0.13.2 with the 0.11–0.13.2 work still local above
the 0.10.0 Git commit. Its status and source hashes are recorded in
[`starting_state.json`](art/baked_0133/starting_state.json). A complete identifiable
source baseline is preserved locally as
`builds/GrimTable-0.13.2-source-baseline.zip`. Existing Windows builds remain.
Original Blender files were not rewritten; validation checks their SHA256.

## Assets and maps

| Assets | Resolution | Maps per asset |
|---|---:|---:|
| Legion infantry | 1024 | 6 |
| Heavy walker | 2048 | 6 |
| Swarm creature | 1024 | 4 |
| Shattered Sanctum | 2048 | 4 |
| Collapsed Transept, Breached Gate | 1024 | 4 |
| Ruined Shrine, Cratered Roadway | 512 | 4 |
| Manufacturing Hall | 2048 | 4 |
| Industrial Wreckage, Checkpoint, Refinery Core | 1024 | 4 |
| Broken Pipeline, shared scenic ground | 512 | 4 |

**14 assets / 60 PNG maps.** All have pigment, tangent normal, RGB ORM and a
finish mask. Legion infantry/walker add RGB paint-region masks and a default
painted fallback albedo for standard GLB viewers. No 4K textures were generated.
Each asset retains one material atlas, including shared atlas use across the
separate structure and shallow ground-contact meshes of environment clusters.

## Reusable bake workflow

[`bake_textures.py`](../tools/art/bake_textures.py) locates Blender, validates
the selected existing sources, backs up previous exports/derived files,
creates unique padded UVs and saves editable derivatives. Full instructions:
[`art/BAKING_0133.md`](../art/BAKING_0133.md).

The former overlapping palette UVs are retained only in original sources.
Derived export meshes use a unique Smart Project layout at 50 degrees and .003
fractional island margin. Bake padding is 4px at 512/1024 and 8px at 2048.
Triangulation precedes the bake and glTF export. Normals use Blender's MikkTSpace
tangent basis with **+X, +Y, +Z**, matching
[Godot's OpenGL normal convention](https://docs.godotengine.org/en/4.4/tutorials/3d/standard_material_3d.html).

There is a real Cycles CPU selected-to-active high-to-low normal bake for every
processed asset. Derived tessellated sources contain shallow carved stone joints,
restrained armor scoring or organic growth grooves. AO is baked separately from
object geometry. Curvature, dirt, palette ownership and response are emission
bakes; they do not contain a fixed sun or studio-light direction. The method
uses Blender's [selected-to-active baking workflow](https://docs.blender.org/manual/en/5.0/render/cycles/baking.html).

The bake complements existing silhouettes. Export triangle counts and bounds
are checked against the preserved baseline. No new terrain collection or
replacement gameplay footprints were created.

## Material architecture and visual changes

`BakedMaterials` caches the shipping finishing material by asset and contact
variant. It recognizes an explicit GLB material name, leaving arbitrary user GLBs
on their existing material path. Albedo/undercoat uses an sRGB sampler; normal,
ORM and masks use data samplers. ORM is **R AO / G roughness / B metallic**.
Mips and high-quality VRAM compression are enabled. Alpha-border processing is
disabled on data textures, preserving wear data at zero alpha. Normals are +Y;
no green-channel inversion is applied.

- **Legion:** a neutral undercoat and independent primary/secondary/trim masks
  retain surface detail during color changes. Curvature-gated pigment loss,
  moderate local cavity shading and rough enamel distinguish armor from darker
  joints and reflective weapon/piston steel. Wear stays on exposed raised areas.
- **Walker:** the same paint architecture uses 2K maps for larger panels, deeper
  mechanical recesses and a clear enamel/steel response. The silhouette and
  existing mechanical structures are retained.
- **Swarm:** carapace growth grooves and local color variation differ from matte
  skin and bone/claws. The organic branch has no metallic paint-chipping layer.
- **Basilica:** local course detail and block-to-block pigment variation replace
  uniform wall coloring. Recesses, broken surfaces, dust and foundation grime
  share one restrained stone family across structures and rubble.
- **Ground transitions:** the ground shader adds embedded partial-stone outlines
  within authored transition bands. Shallow GLB floor margins receive matching
  ash deposits and deterministic opaque cutouts, so actual ground shows between
  surviving pieces. Walls and gameplay bodies are unaffected. This avoids a
  transparent blended layer and retains the real thin-floor silhouette.
- **Ashfall:** industrial steel, rust, concrete and restrained hazard markings
  remain distinct from the Basilica. Existing machinery, rails and damage events
  retain their layout. Structural legacy blue palette slots receive a graphite
  finish in scenery; miniatures retain their own paint colors.
- **Bases:** existing scenic geometry receives local bakes. Rubble, Industrial,
  Stone and Scorched/Ash base surfaces reuse existing relief maps. Canonical
  radii, collision and LOS markers remain unchanged.

AO is intentionally restrained: a small local albedo contribution and moderate
ambient-only occlusion. No realtime sun is permanently painted onto movable
models. Optics keep their painted color; interpolated numeric IDs do not drive
emissive output.

## Paint-region preparation

[`material_regions_0133.json`](../resources/environment/material_regions_0133.json)
defines three paint-weight channels and sixteen material IDs covering armor,
trim, cloth, weapon/metal, optics, organic regions, stone and base earth. Numeric
IDs are stored in finish B / 15; future tools should read them with nearest
sampling. Paint weights can filter linearly.

The developer Legion sample changes primary blue to oxide red and secondary
ivory to sage. It duplicates only the inspection material and checks that normal,
ORM, wear and paint-mask resources remain identical. Closing inspection retains
the exact gameplay snapshot. It is a developer demonstration, not player paint
controls or an implementation of the Workshop.

For the next milestone, persist colors as cosmetic overrides referencing the
shared textures; expose compatible region controls from this contract. Arbitrary
imported GLBs should retain the existing simpler per-material override path.
Do not require masks or alter authoritative bases/LOS to enable painting.

## Visual evidence and review

The [comparison gallery](art/baked_0133/comparisons.html) and images in
[`docs/art/baked_0133/`](art/baked_0133/) use native, unretouched Godot renders.
Required views use matching cameras, scale, lighting and scenario state from
0.13.2 and 0.13.3. Additional captures cover brighter/darker studio light, rear
seams and the recolor sample. Final after-images come from the Windows export.

Initial review rejected an over-bright stone palette and restored architectural
course definition. A wider initial UV projection was replaced after sampled
overlap appeared. Per-vertex normal caching also corrected an excessively slow
high-mesh preparation step. These are workflow corrections, not gameplay changes.

Validation includes GLB channel associations, finite unit tangents, normal
variation, original source hashes, silhouette bounds and a UV interior raster.
At up to 1024px, measured overlap is zero on most assets; the largest nonzero
sample is approximately **0.013%** on the organic asset. This raster is not proof
for every subpixel island. Zero tangents on vanishing bevel slivers receive a
reported orthogonal fallback; meaningful-area degeneracy is rejected. Full
metrics are in [bake validation](art/baked_0133/bake_validation.json).

## Texture cost

New standalone PNG source files total **53,045,455 bytes (50.59 MiB)**. All sixty
RGBA8 textures with full mip chains would occupy approximately **480 MiB**
uncompressed. At a conservative 8bpp BC texture budget, that set is approximately
**120 MiB** with mips; actual format/channel choices and residency vary. These
figures count the fallback albedos as well as shader maps.

A single 2048 map costs approximately 21.33 MiB RGBA8 with mips, or 5.33 MiB at
8bpp. The biggest maps belong to the Sanctum, Manufacturing Hall and walker.
Smaller props/bases stay at 512; scenery shares atlases within each cluster.
Material instances reuse texture resources rather than duplicating per figure.
Self-contained GLBs retain fallback textures, so their embedded images can add
residency alongside the finishing shader's data. The diagnostic Godot texture
monitor is recorded separately from these estimates.

After both maps and the inspection/recolor captures, the **packaged** Godot
monitor reported **420.0 MiB texture memory** and **550.0 MiB video memory**.
This includes existing textures, UI, cached scenes and render resources; it is
not an isolated delta against 0.13.2. Future optimization can share external
fallback/baked image resources at import and selectively consolidate atlases.

## Performance

One 100-model and one 200-model sample, retaining the 0.13.2 stress fixture and
camera. Godot 4.6.1 Compatibility, Medium, 1280×800, VSync off, 90 frames per
mode, Ryzen 5 2600 / GTX 1660 Ti. No bake, import or test processes ran alongside
the benchmark.

| Models | 0.13.2 idle FPS | 0.13.3 idle FPS | Movement frame | Targeting frame | Draw calls |
|---:|---:|---:|---:|---:|---:|
| 100 | 162.6 | **156.7** | 6.69 ms | 6.76 ms | 2,292 |
| 200 | 89.2 | **86.4** | 11.81 ms | 11.98 ms | 4,308 |

The recorded differences are approximately −3.7% / −3.2%; short-sample
variability limits attribution. Both requested comfort goals are exceeded.
Static memory measured 156.5 / 174.1 MiB; cold/second scene loads were 2.67 /
1.62 seconds. This mixed-roster fixture is not a dense all-walker worst case.
[Raw benchmark](benchmarks/baked_0133.json).

## Validation and Windows package

- Bake-file validation passed all **14** assets: source preservation, retained
  bounds/triangle counts, GLB map associations, tangent/normal data and UV audit.
- Affected development suites passed **413 checks**: material 56, authored art
  74, environment/editor 257 and miniature importing 26.
- The complete Godot regression ran **once: 23 suites / 2,275 checks**, all
  passing. The final scenery graphite-tone adjustment then received a focused
  **56-check** material rerun plus the packaged render checks. No second full
  regression or additional public TURN/signaling/AI matrix was run.
- Windows exported successfully. The shipped executable passed **16** baked
  material/inspection/recolor checks and **46** existing gameplay/editor checks,
  both exit 0. The latter covers both maps, objective picking, real moves and
  attacks, clear/blocked LOS, exact save/load/replay and editor cluster operations.
- Standard inspection, brighter light, darker light and rear-seam views were
  captured for all three representative miniatures and reviewed in the export.
  Required after-images and the recolor sample come from this executable.

[Regression](art/baked_0133/regression.json) ·
[Packaged material result](art/baked_0133/packaged_validation.json) ·
[Packaged gameplay result](art/baked_0133/packaged_gameplay.json) ·
[Build manifest](art/baked_0133/build_manifest.json).

Run `builds/GrimTable-0.13.3-windows-x86_64/GrimTable.exe`, or distribute the
whole folder from `builds/GrimTable-0.13.3-windows-x86_64.zip`. The release
contains the native DLL, licenses, checksum, report and native comparison images.
The embedded executable is **332,182,616 bytes (316.79 MiB)**; Blender sources
are excluded from the game package. Only Windows was exported for this pass.

## Limitations and next work

This is stylized modular tabletop art. Some older scenery still uses the prior
material system. Course detail follows a reusable construction pattern; it is
not a unique hand-painted mural on every wall. Floor edge cutouts and embedded
fragments improve breakup but are surface treatment, not a new sculpted terrain
or elevation system. Very tight inspection can reveal low-density UV islands
and the remaining faceted source silhouettes. The original source files remain
available for later selective art refinements.

Human playtesting of asymmetric lanes remains outstanding. The next milestone
can build the Workshop on independent paint colors and shared baked detail;
no Workshop UI, assembly tool, AI expansion or multiplayer feature was added here.
