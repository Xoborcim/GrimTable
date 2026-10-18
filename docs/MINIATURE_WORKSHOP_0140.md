# GrimTable 0.14.0 — Miniature Workshop

The Miniature Workshop is a working local hobby editor, accessible from the
main menu and the existing Miniature Library. Its first complete workflow is
Legion infantry: paint regions, apply finishing, brush actual surfaces, assemble
fitted components, set a limited pose, customize a base, save a variant and see
it in an actual battle.

The repository started clean at 0.13.3, commit
`2657b2c413126dfe5aae5fb268f023e16b0cf903`. Existing source models, game profiles,
scenario definitions, saved-game/replay formats and network protocol remain.
Only the advertised game version changes to 0.14.0. Personal imported models and
collections are not committed or packaged.

## Supported models

| Capability | Legion infantry | Heavy walker | Swarm creature | Imported GLB/glTF |
|---|---|---|---|---|
| Region colors | Primary, secondary, trim, cloth, weapon, steel, optics | Primary, secondary, trim, weapon, steel, optics | Shared organic body tint | Per-material tints, preserving original textures |
| Finishing | Wash, dry-brush, highlight, wear, metal/roughness, glow | Same supported mechanical controls | Organic wash/highlight/weathering/roughness | Metallic and roughness adjustments |
| Freehand brush/eraser | Prepared baked surfaces | No | No | No |
| Surface markings | Prepared UV charts | No | No | No |
| Assembly | Six fitted cosmetic slots | No | No | No |
| Posing | Rigid head and complete upper assembly | No | No | Existing library animation preview; no new pose tools |
| Scenic bases, collection, local assignment | Yes | Yes | Yes | Yes |

Unsupported operations are hidden or explained. Imports are not rejected because
they lack masks, unique UVs or a rig. Their existing library placement and
animation mapping remain available. New attachment accents support region
painting; freehand targets the prepared baked Legion surfaces rather than those
small additional meshes.

## Studio and interaction

The central viewport occupies most of the window. A compact category rail
selects Build, Paint, Pose, Base or Collection; contextual controls occupy the
right side. A neutral work surface, adaptive plinth, soft studio illumination
and contact shading keep attention on the miniature. Standard, bright and
atmospheric lighting presets are available.

- Right-drag orbits, middle-drag pans, wheel zooms; Front/Side/Rear and Reset
  Camera provide predictable views. Inspect mode also allows left-drag orbit.
- Region mode picks a supported material region on the visible model.
- Brush/Eraser use left-drag exclusively for paint, with a radius cursor,
  2–32 screen-pixel radius and 5–100% opacity. The camera remains on right-drag.
- Ctrl+Z / Ctrl+Y undo and redo, Ctrl+S saves. The header shows unsaved changes;
  changing figures or leaving prompts before discarding edits.
- Optional turntable rotation, clean viewport screenshots and a first-use guide
  are implemented. Transparent-background capture is not included.

Color selection includes a picker, hex entry, copy/paste, per-region reset,
saved/recent colors and eight original named starter paints. Four original
scheme presets are Azure Sentinels, Oxide Wardens, Obsidian Surveyors and
Verdant Watch.

## Paint architecture

The shader composites original baked pigment, independent region colors, a
per-figure freehand overlay, a separate marking layer and final finishing.
Normals, local AO, roughness, metallic response and existing sculpted detail
remain independent. Wash uses baked dirt/cavity information; dry-brush and
highlight follow raised detail; wear remains controlled by the baked finish.
Organic surfaces use their own treatment and do not receive metallic chipping.

Dedicated categorical masks are rasterized from the exact UVs and original
material recipes retained on 0.13.3 high-relief Blender meshes. They use nearest
sampling, lossless import and no mipmaps. This avoids treating interpolated
numeric IDs as another material. Source V coordinates are converted to glTF/PNG
orientation. Independent paint-mask interior checks agree at 99.4–100% for
Legion and 98.4–100% for the walker; subpixel edges remain a coverage limitation.
See [region validation](art/workshop_0140/region_ids.json).

The 3D brush uses a TriangleMesh BVH containing all visible preview geometry,
including surfaces which cannot be painted. Each screen sample resolves the
nearest triangle and its barycentric UV coordinates, then writes that visible
surface's texel. It does not draw a UV-radius disk across unrelated charts or
continue through the first surface to hidden geometry. The 1024×1024 RGBA
overlay is independent of original textures and remains editable after loading.
GPU copies receive alpha-edge padding and mipmaps. Each stroke is one undo step;
compressed history is bounded to 24 entries and 32 MB.

Generic stripes, diamonds, hazard marks, numbers and compact A–Z/0–9 text can be
placed by clicking a prepared surface. Scale and rotation remain editable;
markings can be removed or undone. They are clipped to the selected UV chart,
using an authored ownership mask with 2,244 charts. Sixteen markings are allowed
per figure. This is a lightweight marking layer, not a full layer editor or
custom-image decal importer.

## Assembly, posing and bases

The initial original Legion set contains:

- Three helmets: Sentinel, Surveyor and Bastion.
- Three paired shoulder treatments: Standard, Reinforced and Bulwark.
- Three backpacks: Reactor, Signal and Coolant.
- Three cosmetic rifle appearances: Service, Vented and Rail.
- Optional pouch, canister or signal-tablet accessory.
- Optional masonry, conduit or fractured-tile base decoration.

These adapt existing authored geometry and add fitted beveled detail. Stable
named attachment pivots and the [component manifest](../resources/workshop/legion_parts.json)
specify family, slot, transform, material regions and constraints. Incompatible
families/indices are rejected. The equipped Pulse Rifle/Combat Blade remain
authoritative and are displayed separately; cosmetic rifle selection changes no
damage, attacks, range or legality.

Neutral, Ready, Aiming, Advancing and Heroic Display are bounded rigid-part pose
presets. Controls allow head yaw within ±25° and complete upper-assembly yaw
within ±8°. Arms remain attached to the weapon. There is no new skeleton, IK,
independent arm posing, leg articulation or arbitrary static-GLB posing.
Existing battle animation retains the outer visual transform and its muzzle
marker; display articulation does not replace locomotion/reaction controls.

Rubble, Industrial, Stone and Ash bases expose rim paint, ground accent and a
short nameplate. Decorations use the fitted Legion slot. Base diameter always
comes from the gameplay profile; cosmetic geometry adds no collision or LOS.
The tactical inspector retains customized base materials and imported
per-surface overrides.

## Collection, schemes and battle use

Save, Save As New, Duplicate, Rename, confirmed Delete and Revert to Original
are functional. Reverting resets the current variant in the editor and remains
undoable until saved. Saved figures have cached thumbnails and can be filtered
by name, faction, profile, family and default/custom status, with name/family
sorting. Thumbnails load in visible batches and caches are bounded.

Collection controls assign a saved figure to a model ID, squad ID, compatible
profile or compatible faction. A scenario-target chooser helps select existing
IDs. Imported models can select a compatible gameplay profile through their
existing library record. Assignments apply when a battlefield loads; Preview in
Battle saves, assigns the profile and opens the existing Iron Reliquary scenario.

Paint schemes save separately as versioned JSON containing validated colors and
finishing values. Export includes no meshes, scripts or third-party model files.
Scheme application to a squad/faction preserves each saved figure's brush
overlay, marking records and part selections. Compatible profile defaults are
created where needed so a faction scheme can also reach unspecialized units.
The initial scheme format does not include decal choices.

Managed files live under `user://workshop/`: validated figure JSON, revisioned
PNG images, scheme/palette preferences and local assignment references. Writes
save new image revisions first, atomically replace JSON, and clean superseded
images only after success. Original GLBs and Blender files are never edited by
player actions.

Cosmetics resolve locally outside WorldState and canonical profiles. No mesh,
paint texture or artwork is transmitted. Missing cosmetic records/models use
the existing authored fallback; missing overlays retain underlying materials.
Save/load and replay work from canonical state independently of these files.

## Performance and resource cost

Final measurements use the existing Hollow Basilica mixed-roster stress fixture,
Medium Compatibility, 1280×800, VSync off and 90 frames per mode on Ryzen 5 2600 /
GTX 1660 Ti. The custom fixture equips its Legion infantry (20% of the roster)
with a shared painted overlay and alternate helmet, shoulders, backpack and
cosmetic weapon. No bake/import/test process ran alongside the final samples.

| Models | 0.13.3 FPS | 0.14.0 default FPS | Customized fixture FPS | Default/custom draw calls |
|---:|---:|---:|---:|---:|
| 100 | 156.7 | 155.9 | 143.7 | 2,292 / 2,812 |
| 200 | 86.4 | 85.0 | 75.0 | 4,308 / 5,348 |

Relative to the same-run defaults, customization costs about 7.8% / 11.8% idle
FPS. Default results are within short-sample variability of 0.13.3. The custom
fixture remains above the previous 120/65 comfort goals; movement/targeting
averaged approximately 7.37/7.46 ms at 100 and 13.63/13.65 ms at 200. This is not
an all-custom army, all-walker or many-unique-overlay worst case.

Static memory measured 156.9/174.5 MiB default and 159.5/180.8 MiB custom.
[Default benchmark](benchmarks/workshop_default_0140.json) ·
[Custom benchmark](benchmarks/workshop_custom_0140.json).

Overlays cost approximately 5.33 MiB each with full RGBA8 mip chains. A marking
layer costs another 5.33 MiB when present. Textures/material variants are shared
across repeated uses of the same saved figure. The three region-ID images total
6 MiB as R8 without mips; the RGBA8 island map adds 4 MiB. Three standard fallback
textures use mipmapped BC imports (approximately 4 MiB total at 8bpp). CPU editing
images, bounded history, preview geometry, cached scenes and the engine add
further memory. See [texture inventory](art/workshop_0140/texture_cost.json) and
[packaged monitor readings](art/workshop_0140/packaged_validation.json); those
monitor totals include existing artwork and render resources, not an isolated
Workshop delta. Seven new PNG source files total **2,492,041 bytes (2.38 MiB)**.
The packaged smoke observed approximately **410 MiB texture memory / 547 MiB
video memory** after its Workshop and battle operations. Editing
history/thumbnail/material caches are released on exit;
mounted battle figures retain their own resource references.

The new component GLB is approximately 12 MiB. Editable Blender source stays out
of the game package. Reusing external fallback images and batching compatible
rigid parts are future opportunities to reduce duplication and draw calls.

## Validation and Windows delivery

- One full regression: **24 suites / 2,361 checks / zero failures**.
- Final affected suites: **240 checks**, comprising Workshop 84, materials 56,
  authored art 74 and miniature importing 26. The workflow also validates
  categorical mask orientation against independent existing paint masks.
- Packaged Workshop: **33 checks**, including GUI-driven brush marks, whole-stroke
  undo/redo, paint/part/pose persistence, independent variants, scheme preservation,
  actual battle appearance, canonical base/state preservation, save/load,
  missing-record fallback and replay opening.
- Separate application restart: **4 checks**, confirming collection, paint,
  helmet and assignment persistence.
- Existing packaged gameplay/editor smoke: **46 checks**, covering both maps,
  selection/LOS, moves/attacks, exact save/load/replay and scenario editing.

The full suite ran once before the final small cosmetic/ID refinements; affected
suites and the packaged renderer covered the final changes. No additional TURN,
signaling or AI infrastructure matrix was run. The machine emits an environmental
root-certificate-store warning; it did not prevent rendering or validation.

The final Windows release uses Godot 4.6.1 OpenGL Compatibility. Run
`builds/GrimTable-0.14.0-windows-x86_64/GrimTable.exe`, or extract the complete
`builds/GrimTable-0.14.0-windows-x86_64.zip`. Keep its native DLL alongside it.
The distribution includes licenses, checksums, this report and native images.
[Build manifest](art/workshop_0140/build_manifest.json) ·
[Regression](art/workshop_0140/regression.json) ·
[Screenshot gallery](art/workshop_0140/gallery.html).

## Evidence and remaining limits

The gallery contains native exported-application screenshots of default Legion,
two paint schemes, alternate components, real brush strokes, surface markings,
four base finishes, saved collection, a clean studio photo, a customized figure
in battle and collection persistence after restarting. Images are not retouched.

This initial release concentrates full assembly/brush/pose support on one Legion
family. Its helmet and equipment variants share the original underlying sculpt;
they are fitted adaptations, not three completely unrelated new character
models. Freehand is a single editable overlay, with no pressure-sensitive brush,
UV seam dilation, professional layer stack or arbitrary imported-model painting.
Very small UV islands may produce discontinuous-looking paint at extreme zoom;
the brush avoids cross-island leakage rather than inventing adjacent pixels.
Markings remain bounded by UV-chart seams. Transparent photos and user-image
decals are absent. Human usability/playtesting across more hardware remains
valuable, particularly for large collections and armies with many unique paints.

[Authoring and extension workflow](../art/WORKSHOP_0140.md) documents the preserved
sources, component contract, mask generation, brush method and local file model.
