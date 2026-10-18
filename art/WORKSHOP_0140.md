# Miniature Workshop authoring

The player Workshop is a cosmetic editor. Model profile JSON, canonical bases,
LOS, weapon definitions, WorldState, save/replay schemas and network messages
do not contain the Workshop's local files.

## Rebuild the authored Legion components

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.0\blender.exe' --background --python tools/art/build_workshop.py
python tools/art/workshop_uv_islands.py
python tools/art/workshop_region_ids.py
```

The scripts read original/derived 0.13.3 Blender sources. They never save over
them. New editable output is `art/blender/workshop_0140/legion_components.blend`;
the game export is `assets/workshop/legion_components.glb`.

`build_workshop.py` maps the existing baked low mesh to original named source
parts, preserving the BakeUV atlas. Head, shoulders, backpack, weapon, lower
body and complete upper body remain separate rigid components. Added beveled
plates, sensors, aerials, canisters and decorations are original GrimTable work.
All alternatives live in the source collection. Godot selects one alternative
per slot and removes unused alternatives when creating a battle figure.

Stable node names (`head_0`, `head_1`, etc.) are the attachment contract.
`resources/workshop/legion_parts.json` records family, slot, position, rotation,
material regions, pose compatibility and visual/gameplay constraints. The
current shoulder slot changes both shoulders together. None of the cosmetic
weapon options changes an equipped weapon profile.

`workshop_region_ids.py` reads the exact per-face material recipes and UVs
retained on the preserved high-relief bake meshes. It rasterizes
categorical palette IDs into lossless textures: **0 outside, palette ID + 1
inside**. These are separate from continuous curvature/dirt masks. This avoids
decoding interpolated ID values at color boundaries as cloth or glowing optics.
Actual palette IDs and agreement with independent baked paint-mask interiors
are reported in `docs/art/workshop_0140/region_ids.json`. Blender V coordinates
are flipped into glTF/PNG row coordinates. Tiny bevels still limit coverage
at subpixel details.

`workshop_uv_islands.py` reads the prepared Legion GLB and creates an integer
UV-chart ownership image. The atlas has 2,244 charts. Decals are clipped to the
selected chart rather than painting other islands which happen to be nearby.

After the first Godot import, run:

```powershell
python tools/art/configure_baked_imports.py
```

Then import again. The three standard fallback textures use compressed,
mipmapped imports. Integer region and island images remain lossless with
no mipmaps or automatic 3D compression. The runtime shader samples IDs using
nearest filtering. Normal, AO, roughness, metallic and pigment maps reuse 0.13.3.

## Adding a compatible family later

Author fitted components and stable pivots, then provide a family/slot manifest
following `legion_parts.json`. Extend the capability and slot validation tables
explicitly; an imported GLB cannot opt into sockets by naming a node. Define
safe articulated controls per family. Keep display articulation inside the
animation controller's outer visual transform. Do not add cosmetic geometry to
movement or LOS colliders.

The initial pose contract is rigid head yaw and a small complete upper-body
turn. It does not imply a skeletal rig, arm IK, leg articulation or arbitrary
static-mesh posing.

## Painting and persistence

Compositing order is baked pigment, region tint, editable brush overlay,
island-clipped markings, then baked-information-driven finishing. The original
normal and ORM maps remain independent. Imported StandardMaterial3D instances
retain their textures and receive per-surface tints; they do not acquire masks,
UV painting or pose support automatically.

The brush builds a [TriangleMesh BVH](https://docs.godotengine.org/en/4.6/classes/class_trianglemesh.html)
over visible geometry, including unpaintable occluders. Every screen brush
sample resolves the nearest hit, interpolates UV coordinates barycentrically,
and writes only that visible point's texel. The editor never paints a large UV
disk across unrelated islands. Freehand is enabled only on the prepared Legion
baked surfaces; newly added unwrapped attachment accents remain region-painted.

Brush images are 1024 square RGBA. GPU copies receive alpha-edge padding and
mips; editable originals remain separate. History stores complete document
states and compressed overlay snapshots, capped at 24 entries / 32 MB. A stroke
is one undo step. Markings use a separate raster layer and persist as editable
placement records. Text markings use original compact A–Z/0–9 stencil glyphs.

`user://workshop/` holds figures, revisioned images, assignments, schemes,
palette colors and onboarding preferences. Figure writes save new image
revisions before atomically replacing JSON; old images are cleaned only after
successful replacement. Managed IDs/path validation prevents source-model
overwrites. Scheme JSON includes colors/effects only, never meshes or scripts.

Assignments resolve model, squad, profile, then faction references locally.
Missing records/textures/models are optional visual failures and never prevent
canonical battle or replay loading. No Workshop image or mesh transfer exists.
