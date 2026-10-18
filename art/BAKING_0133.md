# Baked material workflow — 0.13.3

Use Python 3.11+ to launch Blender 5.0.1. No downloaded texture inputs are used.

```powershell
python tools/art/bake_textures.py --assets sanctum legion_infantry
python tools/art/bake_textures.py --assets heavy_walker swarm_creature scenic_ground
python tools/art/validate_bakes.py
```

Pass `--blender PATH` or set `BLENDER_EXE` if Blender is not on PATH or installed
in its standard Windows location. The launcher checks each source exists, saves
content-addressed backups of existing GLBs and derived sources in
`.runtime/bake_backups`, reports errors with a per-asset log, and verifies that
the original Blender file's SHA256 did not change.

The pipeline reads the existing `02_GAME_EXPORT` collection. It recovers material
ownership from the old palette UVs, then creates a separate `BakeUV` with Blender
Smart Project at 50 degrees and a .003 fractional island margin. Meshes are
triangulated before baking, ensuring the bake and glTF exporter use the same
triangle/tangent basis. Silhouette geometry and triangle counts are retained.

Editable derivatives are saved under `art/blender/baked_0133/`. The original
`01_SOURCE_EDITABLE` collections remain in the untouched original files; the
derivative also contains `03_HIGH_RELIEF_0133`, the tessellated surface sources.
Stone/concrete have physically recessed course joints; armor has restrained
scoring in exposed panel bands; carapace has shallow growth grooves. Cycles CPU
uses selected-to-active **tangent NORMAL**, +X/+Y/+Z, with per-object ray bounds.
AO is a separate local geometry bake. No sun, studio lamp or world shadow is
written into a reusable color texture.

The finish recipes emit neutral undercoat/color, material regions, curvature,
dirt and response maps. AO, roughness and metallic pack into RGB ORM. Armor
finish alpha stores sparse curvature-gated paint loss. Source pigment uses sRGB;
normals, masks and ORM are non-color data. Default painted colors are exported
in a separate fallback albedo for standard glTF viewers, while Godot uses neutral
undercoat plus independent RGB paint weights.

After Godot imports the new files, run:

```powershell
python tools/art/configure_baked_imports.py
```

Import once more in Godot to apply mipmaps, high-quality VRAM compression, +Y
normal interpretation and **disabled alpha-border processing** on data images.
Finish alpha is data, not transparency. The finished material remains opaque;
only shallow scenery floor margins use a deterministic opaque fragment cutout.

`validate_bakes.py` requires numpy and Pillow. It checks original-source hashes,
GLB texture associations, UV bounds, tangent validity, normal variation, preserved
silhouette bounds and a UV triangle-interior overlap raster. The raster samples
at up to 1024px and does not certify subpixel islands. The exporter repairs zero
tangents only on numerically degenerate slivers, and refuses the workaround if
their combined area exceeds 0.01% of the surface. The guard retains their geometry
and reports the exact affected area. Large or visible UV problems require a new
unwrap, not a relaxed guard. Inspect front/rear views in Godot after validation.

The pipeline is a recipe for these named original assets. Edit their original
source geometry, or the explicit recipes, then rebake. It does not infer paint
regions for arbitrary imported models and does not implement a painting UI.
See `resources/environment/material_regions_0133.json` for channel contracts.
