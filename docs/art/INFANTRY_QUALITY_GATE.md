# Legion infantry reference gate

The infantry was developed and reviewed before starting the other three assets.
Review used front/side/rear/hero/tactical Blender renders and matched native Godot
captures. Several geometry/material iterations preceded acceptance.

The comparison does not exploit a broken old model: mixed indexed/unindexed
SurfaceTool batching originally hid some old armor. Chamfer meshes now supply
indices, and the complete old authored geometry is used as the baseline. Old
Godot custom materials are represented by their paint/metal factors in Blender;
the separate Godot comparison uses the actual shaders. Both models use the same
camera, normalized overall height, studio lights and physical base.

| Criterion | Observed change |
|---|---|
| Silhouette | Shaped shoulder shells, tapered greaves and anatomical torso replace rectangular armor blocks |
| Anatomy | Connected neck/collar, shoulder/elbow bearings, supported forearms and deliberate foot placement |
| Armor | Inset/crowned pectorals, segmented abdomen, shaped knee shields and shin ridges |
| Weapon | Profile-extruded receiver, actual muzzle opening, recessed vents, magazine, stock and wrapped fingers |
| Surface geometry | Hardware, rear turbine vanes, cables, respirator recesses and folded cloth are modeled |
| Materials | Shared midnight-blue, ivory, gunmetal, brass and cold-optic treatment, with geometry-based edge paint |
| Tactical readability | Broad armor, helmet, rifle and base remain identifiable at reduced size; native battlefield capture is included |
| Coherence | Matching mechanical connections, trim widths and painted base treatment across front, side and rear |

Issues found and corrected included a faceted helmet, missing visor recess,
oversized forearm, floating fasteners, reversed export-facing orientation,
double-darkened atlas colors and reversed inspector view labels. The matched
review sheets arrange unchanged renders; they are not retouched.

This passes the project's **substantial improvement over the previous reference**
gate. It is not a claim of independently certified professional sculpt quality.
The stance remains restrained; hand anatomy and cloth could receive more manual
sculpting, and some hard-surface construction remains evident at close zoom.
Those are recorded in the milestone report rather than hidden by lighting.

- `comparisons/legion_infantry_side_by_side.png`
- `comparisons/infantry_godot_before_hero.png`
- `comparisons/infantry_godot_after_hero.png`
- `renders/legion_infantry_front.png`, `side.png`, `rear.png`, `hero.png`, `tactical.png`
- `gameplay/art_inspect_legion_trooper_0120.png`
