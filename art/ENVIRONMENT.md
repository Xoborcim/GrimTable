# Environment source workflow — 0.13.1

The composition correction adds nine original location sources in
`art/blender/environment/0131/`. Each retains editable contour extrusions,
Boolean apertures, swept cables, bevels, fractured slabs and source rubble.
`02_GAME_EXPORT` contains at most two atlas-consolidated meshes. Low geometry
named `*_GroundContact` does not cast shadows in Godot, avoiding shadow-map
artifacts on thin paving; walls, columns and large rubble retain shadows.

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.0\blender.exe' --background --disable-autoexec --python-exit-code 1 --python tools/art/export_composition_0131.py -- station_hall
& 'C:\Program Files\Blender Foundation\Blender 5.0\blender.exe' --background --disable-autoexec --python-exit-code 1 --python tools/art/validate_composition_0131.py
```

The edited-source export path was exercised on the manufacturing hall. The
generator `build_composition_0131.py -- <names>` recreates the original design
and **overwrites manual edits**. It defaults to the four Basilica clusters;
specify other names explicitly. `compose_0131.py hollow` / `station` similarly
regenerate the curated scenario and registry. The `SPECS` records are the source
of each cluster's fixed size and simple compound gameplay footprint. Change
these deliberately with the geometry; collision is never inferred from a GLB.

`bake_surfaces_0131.py -- bake` performs actual Cycles CPU selected-to-active
NORMAL and AO bakes at 512px and retains high relief / UV target in
`surface_bake.blend`. `-- Sanctum Transport` regenerates the two 512px location
masks from `resources/environment/layouts_0131.json`: R paving, G steel,
B damage/soot, A localized fracture branches. Those masks cover the canonical
60-by-44-inch board in world coordinates and flip V when sampled in Godot.
They are fixed location layouts, not an automatic terrain painter. Larger
custom boards retain the same authored center region.

Native screenshots are captured by `tools/art/capture_0131.gd -- after`, with
the fixed before-camera recorded in that script. It also captures closer
views and the location with miniatures hidden. Blender source files and docs
are excluded from the packaged game. All new art is original MIT work.

## Previous modular environment sources

The eight original environment assets are editable in Blender 5.0.1 under
`art/blender/environment/`. Each source has `01_SOURCE_EDITABLE` and
`02_GAME_EXPORT` collections. Unhide source objects and hide the evaluated game
mesh before editing. Textures are packed. Sources are excluded from Godot export
by the existing `art/.gdignore`.

Authoring uses **inches**, unlike the miniature generator's millimeter helper
arguments. One scene unit equals one tabletop inch. Blender Z-up exports to
Godot Y-up through glTF. Environment exports do not apply the miniature-facing
180-degree yaw. The origin is at ground center. Footprints are recorded in
`docs/environment/mesh_metrics.json` and match the editor records; geometry never
creates gameplay collision automatically.

Re-export edited geometry without regenerating its design:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.0\blender.exe' --background --disable-autoexec --python-exit-code 1 --python tools/art/export_environment.py -- gatehouse
& 'C:\Program Files\Blender Foundation\Blender 5.0\blender.exe' --background --disable-autoexec --python-exit-code 1 --python tools/art/validate_environment.py
```

The exporter evaluates editable source modifiers, joins a separate game mesh,
preserves atlas UVs/materials and writes the source and GLB. It does not rebuild
the design. The gatehouse source-export path was exercised during development.

To reproduce the original scripted designs instead, use
`tools/art/build_environment.py` inside Blender, optionally followed by
`-- gatehouse` or another asset name. **This replaces manual source edits.**
`tools/art/compose_environment.py` similarly regenerates the four curated JSON
layouts; do not run it to preserve hand-edited scenario changes.

The shared original pigment and ORM atlases remain in
`assets/miniatures/materials/`. One mesh/material per exported landmark keeps draw
counts low. Godot generates LODs and shadow meshes. The environment shader adds
world-space stone courses, restrained grime, roughness variation and three
deterministic wear treatments while retaining the original atlas palette.

The runtime ground dressing in `EnvironmentArt` batches chipped slabs, ceremonial
inlays, road markings, drainage and low rubble by shared material. Planar wear
masks use a separate transparent pass for Compatibility rendering. They are
cosmetic, have no bodies, and add no gameplay penalties. The scenario's original
terrain records remain the source of movement, cover and LOS traits.

All new sources, maps, shaders and pigment derivatives are original MIT GrimTable
art. No third-party mesh foundation or texture download was used.
