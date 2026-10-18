# GrimTable 0.13.1 — Battlefield Composition & Surface Detail

Built with Godot 4.6.1 and Blender 5.0.1 on Windows, 18 October 2026.

This correction reconstructs **The Hollow Basilica** and **Ashfall Station** as
connected locations. It replaces isolated landmark placement and uninterrupted
tile fields with ruined building plans, owned foundations/paving, localized
collapse fans and distinct transport/service surfaces. The native screenshots
below are the visual evidence; validation counts are functional evidence.

## Architectural composition

The Basilica was developed and reviewed first. Its **Shattered Sanctum** has a
surviving rear arcade, interrupted west wall, broken crossing piers and a
cantilevered half arch. Footings trace the missing walls. The collapsed west
transept shares the nave's floor treatment; displaced column drums, masonry
and exposed reinforcement follow its actual breaks. Tall forms concentrate in
the northwest, leaving an exposed central crossing and a fortified service flank.

The eastern **Breached Gate** has attached broken bulkhead halves and separated
supports, leaving a genuine walker-width passage. A ruined shrine and dead
terminal lead toward the crossing. The service court contains a split generator
housing with exposed rotor, severed coolant lines, a collapsed beam, torn cable
junction and damaged deck. An abandoned checkpoint combines sheared barriers,
an inert broken turret and ammunition cases. These are composed assets, not
independent scatter added to fill space.

Ashfall was rebuilt after the Basilica review. A **Ruptured Manufacturing Hall**
encloses the eastern generator yard. Torn wall profiles, service apertures,
ventilators, a surviving hoist truss and hanging lift cable join the existing
refinery tower into one complex. The west side has a casemate/checkpoint,
severed process mains and a bombarded approach. Embedded cargo rails and the
cross-junction connect the two sides. Its industrial shell and decking differ
from the Basilica's masonry and ceremonial remains.

Original Ashfall army profiles, starting model positions, objective positions
and guided approach lane are retained. Basilica objective positions deliberately
changed to the reliquary, crossing and broken distribution node. Neither map
uses mirrored visual placement as its balance mechanism.

## Ground, damage and materials

- Fractured beveled slabs belong to each cluster. Missing/split slabs, low
  footing fragments and debris continue the damaged structure into its floor.
- Collapse fans concentrate larger fragments inside declared blocked areas.
  Smaller fragments spread into playable ground at only 0.025–0.075 inches high.
  They do not add hidden collision or movement penalties.
- Shallow concave crater geometry has a recessed center relative to a broken
  raised lip, expelled roadway fragments and radial tears. The standing plane
  remains Y=0; there is no new elevation rule or below-board hole.
- Original 512px pigment/ORM atlases share a restrained ash-stone, soot-mortar,
  muted iron-oxide and painted-metal palette. Exported GLBs embed their images.
- Actual **Cycles CPU selected-to-active NORMAL and AO bakes** transfer a carved
  branching stone relief to a UV quad. High relief and target remain editable
  in `surface_bake.blend`; the two 512px maps are used by the runtime ground shader.
  These are reusable surface bakes, not whole-map lightmaps or per-building AO.
- Two authored 512px RGBA masks define paving, steel, soot/damage and localized
  fracture branches. Damage events include wall collapses, gate blasts, generator
  spills and shell impacts. Dust fans follow their recorded directions.
  The RGB data is preserved by disabling transparency-edge processing on masks.
- Legacy ground remains available. New location layouts suppress the old broad
  tile grid; the existing tactical/movement grid remains available on demand.

Normal/AO detail is intentionally restrained. Geometry supplies the major damage
and silhouette. The surface treatment does not depend on expensive renderer-only
decals or new dynamic lights. Existing sparse ash/vapor and theme lighting are
reused. Low `*_GroundContact` export meshes have shadow casting disabled; this
corrected visible striping on very thin slabs without removing wall shadows.

Layout authoring lives in
[`layouts_0131.json`](../resources/environment/layouts_0131.json). Layout masks
cover the canonical 60×44-inch board in world coordinates. They are curated
location presets, not a general automatic terrain painting tool.

## Original Blender assets and reusable clusters

All sources are under `art/blender/environment/0131/`; all exports are under
`assets/terrain/environment/0131/`. Each basename below has both `.blend` and
`.glb`. Sources retain editable construction and a separate evaluated export.

| Basename / editor cluster | Triangles | Export meshes |
|---|---:|---:|
| `sanctum` / Shattered Sanctum | 95,282 | 2 |
| `transept` / Collapsed Transept | 74,232 | 2 |
| `breached_gate` / Breached Gate | 53,508 | 2 |
| `shrine` / Ruined Shrine | 21,486 | 2 |
| `industrial_wreck` / Industrial Wreckage | 55,692 | 2 |
| `checkpoint` / Destroyed Checkpoint | 31,846 | 2 |
| `pipeline` / Broken Pipeline | 28,442 | 2 |
| `crater` / Cratered Roadway | 7,584 | 1 |
| `station_hall` / Ruptured Manufacturing Hall | 63,752 | 2 |

Each exported mesh uses one shared atlas material. Godot import generates LODs
and shadow meshes. Cosmetic runtime fragments/rails are consolidated by material.
No library of unused clusters is instantiated into a battle.

See [metrics](environment/0131/mesh_metrics.json),
[source/GLB validation](environment/0131/asset_validation.json),
[mask validation](environment/0131/mask_validation.json) and the
[Blender workflow](../art/ENVIRONMENT.md). The edited-source exporter was exercised
on `station_hall`, preserving the source design instead of regenerating it.

## Gameplay footprints, editor and camera

The existing terrain record supports an optional list of up to 16 simple local
box parts. This is needed to leave real passages inside larger authored clusters.
The same parts drive movement sweeps, physics LOS bodies, picking and tactical
footprint outlines. Bounds/finite-value validation rejects malformed parts.
Legacy box/L-shaped records and old saves retain their existing behavior.

Walls, columns, substantial fallen fragments and machinery have declared blocking
parts. Low decorative slabs, cables and dust have no bodies. Broken pipelines
block movement at their standing sections but are explicitly nonblocking for LOS.
Cratered Roadway uses the existing cover +1 and 2-inch difficult-ground traits.
Separate low floor records define nave/checkpoint cover; artwork does not infer
cover or change a unit's authoritative base or eye height. Upper arches, floors
and hoists are decorative, with no elevated standing positions.

The editor adds a **Clusters** category with nine rendered previews, actual
compound footprint ghosts, rotation, duplication and fixed authored sizes.
**Surface Layout** selects Legacy, Sanctum or Transport. A scalable **Ruin Cover
Floor** record exposes explicit cover areas without an oversized visual slab.
No new modeling editor, navigation architecture or combat rule was introduced.

New location starts use distance 53, pitch 0.92, heading 0.08 and target
`(0, 0.5, -2)`: less unused backdrop, a clearer landmark/crossing and readable
staging. Comparison captures retain the old fixed camera separately. The existing
table surround remains restrained; no surrounding open world was built.

## Screenshot evidence

All battlefield images are actual Godot Compatibility renders, not AI images or
paintovers. Comparisons place unchanged native render pixels side by side with
labels outside them. The [capture manifest](environment/0131/capture_manifest.json)
records matching camera, scale, resolution and quality. Units were temporarily
hidden for separate location-only evidence.

| View | Evidence |
|---|---|
| Basilica before/after, identical camera | [Comparison](environment/0131/hollow_basilica_comparison.png) |
| Basilica three-quarter | [Detail](environment/0131/hollow_basilica_detail.png) |
| Basilica foundation/rubble close-up | [Integration](environment/0131/hollow_basilica_integration.png) |
| Basilica without miniatures | [Location](environment/0131/hollow_basilica_location.png) |
| Ashfall before/after, identical camera | [Comparison](environment/0131/ashfall_station_comparison.png) |
| Ashfall manufacturing detail | [Detail](environment/0131/ashfall_station_detail.png) |
| Ashfall ground/plant close-up | [Integration](environment/0131/ashfall_station_integration.png) |
| Ashfall without miniatures | [Location](environment/0131/ashfall_station_location.png) |
| Packaged tactical gameplay | [Basilica](environment/0131/hollow_basilica_tactical_0131.png) |
| Packaged default gameplay framing | [Basilica](environment/0131/hollow_basilica_gameplay_0131.png), [Ashfall](environment/0131/ashfall_station_gameplay_0131.png) |
| Packaged cluster editor | [Palette](environment/0131/cluster_editor_0131.png) |

The initial Basilica review revealed corduroy-like normal detail and thin-slab
shadow artifacts. Relief geometry was changed and rebaked; low slabs were split
from shadow-casting structure. Later reviews replaced separate court props with
the generator/checkpoint cluster and removed distracting perimeter stick marks.
A late close-up also revealed rotated footings with incorrect pivots; their
origins were corrected, all cluster sources/GLBs regenerated, footing bounds
validated and both maps recaptured. The final result reads as a continuous
nave/transept and a distinct service flank,
with coarse debris tied to breaks. Exterior approaches remain visibly simpler.

## Targeted and regression validation

- Nine editable Blender sources and self-contained GLBs: finite geometry,
  nondegenerate game faces, UVs, material/texture retention and exact triangle
  counts; surface-bake source and four runtime maps verified.
- Focused composition + AI: **153 checks, zero failures**. Both maps load;
  all starting bases are legal; all objective centers are accessible; representative
  infantry, walker and opposing units have terrain routes to every objective.
  Test-only coarse searches validate edges with existing swept-footprint queries.
- One legal AI round per map: Basilica **22 ticks / 5 movement actions**;
  Ashfall **30 ticks / 5 movement actions**; both finished with **zero invalid
  actions**. These are navigation spot checks, not exhaustive balance simulations.
- Explicit west-breach movement, standing-wall movement/LOS, walker gate clearance,
  compound tactical outlines, exact scenario/game roundtrips, invalid footprint
  rejection, editor rotation/duplication and surface persistence pass.
- Guided beginner suite: **42 checks**, zero failures. Affected environment/editor
  suite: **257 checks**, zero failures.
- One minimal **two-process local ENet** check: host 6 / guest 7 checks, zero
  failures. Version handshake, actual compound-footprint transfer, open breach,
  blocked wall, state hashes and canonical five-die results match. No separate
  signaling/TURN/public-infrastructure matrix was run.
- The focused source application smoke passed **46 checks** covering both maps,
  actual moves/attacks, clickable objectives, exact save/load/replay and editor
  cluster placement/rotation/duplication.

The complete regression ran **exactly once: 22 suites / 2,211 checks**. The first
run had one failure: an obsolete `LivingAtmosphere` node-name assertion after
Ashfall moved to the existing authored refinery/vapor system. That assertion
was corrected to verify current machinery and active sparse steam. The affected
suite then passed **27 checks** in a focused rerun. No second full suite was run;
there are **zero unresolved failures**. This is not reported as an initially
clean full run. The runner's existing local networking assertions were included.

Evidence: [targeted checks and AI](environment/0131/targeted_validation.json),
[two-client results](environment/0131/lan_validation.json),
[single-regression digest and correction](environment/0131/regression.json).

## Performance

One 100-model and one 200-model sample, Ryzen 5 2600 / GTX 1660 Ti, Godot
Compatibility, Medium, 1280×800, VSync off, 90 measured frames per mode. The
120-inch mixed-roster stress fixture and camera from 0.13.0 are retained; the
actual new Basilica terrain and location treatment replace its environment.

| Models | Idle FPS | Movement frame | Targeting frame | Draw calls | Static memory | Load |
|---:|---:|---:|---:|---:|---:|---:|
| 100 | 157.7 | 6.53 ms | 6.89 ms | 2,290 | 156.2 MB | 1.84 s |
| 200 | 86.3 | 12.03 ms | 11.99 ms | 4,306 | 173.7 MB | 0.85 s |

The measurements preceded the final cosmetic footing-pivot correction; triangle
and material budgets were unchanged. The previous samples were 138.4/82.1 FPS. No slowdown was observed in this short
fixture; fewer draws and consolidated clusters offset added geometry. This is
not a guarantee of a general speedup or a worst-case dense all-hero battle.
Cache/load variability and short samples limit comparison. Both requested
comfort targets are exceeded here. See [raw data](benchmarks/composition_0131.json).

## Windows standalone

A fresh Windows x86_64 release export completed successfully. Its **final
packaged smoke passed 46 checks with zero failures**: both maps, new default
framing, clickable objectives, legal squad approaches/coherency, blocked/clear
LOS, attacks, exact battle save/load, exact replay and editor cluster
placement/rotation/duplication plus scenario roundtrip. Packaged screenshots
are linked above. An earlier packaged smoke also passed 46 checks before the late footing-pivot
correction. The corrected assets were revalidated, the Windows executable
rebuilt, and the focused packaged smoke repeated because those assets changed:
**two packaged smoke executions total**. No second full regression was run.

[Packaged result](environment/0131/packaged_validation.json). Launch
`builds/windows/GrimTable.exe`; distribute the whole containing folder with its
native DLL and licenses. Build metadata, notices and release notes identify
0.13.1. Only Windows was exported and smoke-tested for this correction.

## Provenance and remaining visual weaknesses

All new mesh geometry, material images, bakes, layouts and tooling are original
GrimTable MIT work. No new downloaded models/textures or protected iconography
were introduced. The [reference study](environment/0131/REFERENCE_STUDY.md)
records the physical diorama construction principles consulted, accessible
sources and unavailable pages. No reference imagery is redistributed. Existing
Kenney/font/engine/WebRTC licenses still apply.

This remains stylized modular tabletop art. The broken slab language is reused,
exterior approaches still contain broad ash surfaces, and floor-mask edges are
more graphic than hand-sculpted terrain blending. Some older Ashfall secondary
props remain simpler than the new hall and generator. The crater is shallow,
not excavated through the physical board. Upper architecture has conservative
simple LOS bodies rather than window-accurate collision, and there is no new
occlusion cutaway. Fixed layout masks need deliberate authoring for other map
dimensions. AI checks establish routes and legal play, not competitive balance.

Recommended next step: a small manual art refinement of exterior approaches and
ground transitions on these two boards—less regular slab edges, more bespoke
surface painting and damaged road contours—plus a short human playtest of the
asymmetric objective lanes. Extend that finished language before adding maps.
