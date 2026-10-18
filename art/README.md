# GrimTable miniature art sources

All geometry and pigment maps in this art pass are original GrimTable work under
the repository MIT license. No proprietary game models or third-party sculpt
foundations were used.

Open `blender/<asset>.blend` in Blender 5.0.1. Collections:

- `01_SOURCE_EDITABLE`: named contour extrusions, curved armor, mechanical parts,
  editable curve sweeps and organic subdivision/voxel modifiers. Unhide the
  source objects with Alt-H and hide the game mesh to edit them.
- `02_GAME_EXPORT`: evaluated, atlas-mapped game mesh. Sources remain separate.
- `03_STUDIO_BASE`: common physical base used in matched renders. These bases
  are excluded from each major GLB; shared ground detail is exported separately.
- `04_RENDER_STUDIO`: camera, neutral backdrop and softboxes.
- `05_COMPARISON_0110`: hidden old model captured from the existing Godot source.

One Blender scene unit equals one GrimTable tabletop inch. The authoring helpers
take millimeters and convert to that scale. Blender uses Z-up and sculpt forward
-Y. Exports apply a deliberate 180-degree yaw so the units face canonical Godot
-Z after glTF's Y-up conversion. Terrain uses its fixed board X/Z footprint and
does not apply the unit yaw. Origins are on the ground at the base center.

The four nominal overall heights are 43, 96, 46 and 263 mm. Exact evaluated
dimensions and triangle counts are in `docs/art/*_metrics.json`. Small
differences can result from evaluated subdivision/displacement bounds. Model
geometry never sets a gameplay base size, collider or LOS height.

Re-export artist-edited source geometry without regenerating its design:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.0\blender.exe' --background --disable-autoexec --python-exit-code 1 --python tools/art/export_models.py -- legion_infantry
python tools/art/validate_models.py
```

`export_models.py` evaluates the source collection into a fresh game mesh. Use
`--use-game-mesh` to export a manually optimized game collection instead. It
allows object animation export, but this release supplies static models and
uses GrimTable's existing motion fallback; it does not provide a skeletal rig.

To reproduce the original design and studio renders, run
`tools/art/build_assets.py -- <asset>` inside Blender. This **rebuilds** that
asset from its authoring script, replacing manual source edits. Use ordinary
source export for ongoing artist work instead. `--no-render` omits renders;
`--draft` renders front/hero plus the matched comparison. Run from the repository
root. `tools/art/validate_sources.py` opens and checks all four Blender sources.

The shared original 1024px pigment and roughness/metallic atlases are in
`assets/miniatures/materials`. Source palette materials carry an `atlas_tile`
property. Bevel faces get the edge-paint tile, recesses use dark materials, and
each game mesh uses one atlas material. These are procedural pigment maps with
a painted-miniature-inspired treatment, not hand-painted texture scans or baked
normal maps. Godot's GLB import enables generated LODs and shadow meshes.

`art/.gdignore` keeps editable Blender files and comparison references out of the
Godot import/export pipeline. Only game-ready assets under `assets/` ship.
`tools/art/build_comparisons.py` arranges the unchanged before/after renders into
labeled review sheets (requires Pillow); it does not retouch their contents.
