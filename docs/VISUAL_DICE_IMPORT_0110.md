# GrimTable 0.11.0 ? Battlefield, Dice and Local Miniatures

Implemented in the existing Godot 4.6.1 project. Gameplay movement, attack
resolution, AI decisions, transport authority, content compatibility and replay
schemas remain in their existing systems. This milestone adds presentation and
local cosmetic tooling.

## Playing this version

Run `builds/windows/GrimTable.exe` with its existing WebRTC DLL and license files.
Use Play ? The Ashen Basilica, Ashfall Manufactorum or Toxic Forge. Ashfall
Station remains the Guided starting scenario and also receives new terrain art.
The main menu now renders The Ashen Basilica as a live diorama.

Settings ? Cinematic Dice offers Off, Quick and Full, ivory/steel material styles,
and a volume control. Reduced motion resolves directly to the correct faces.
Skip animation reveals the current result; Dismiss all clears presentation.
Gameplay remains responsive while dice play. The manual roller offers public
host-authoritative rolls or private local-only rolls.

## Dice implementation and canonical synchronization

`CinematicDie` creates original chamfered cube geometry with individually modeled
pips. Local normals define faces 1?6; opposite faces sum to seven. That same
normal table supplies final quaternions and independent top-face verification.
A separate SubViewport/world contains a tray, static floor/walls and Jolt
RigidBody3D dice with bounded impulses, friction, bounce and continuous collision.
Dice tumble and collide physically for 0.6 seconds in Quick or 1.7 in Full.
A 0.4-second interpolation moves them into separated result slots and settles
onto the predetermined face. This is cosmetic physics followed by controlled
settling; physical randomness never determines gameplay.

Combat supplies its already-resolved hit, wound and armor arrays. The tray queues
these stages, followed by the canonical damage summary. Manual combat retains
explicit reveal buttons. Successes receive a constant material highlight and
check marks in the exact result summary, supplementing color. Original impact
synthesis responds to body contacts, with a throttle to avoid noisy collisions.

The tray creates at most twelve physics dice. Larger pools show twelve
representative dice and the complete, scrollable numeric pool. No actual result
is discarded. This is a representative display rather than serial animation of
every die in a huge pool. Presentation currently implements D6 only; the mesh
and tray classes are separate so future dice can supply another face contract.

Host gameplay RNG, canonical messages and ActionCodec remain authoritative.
Replays use recorded arrays. A focused real ENet two-peer test verifies host
results, client results and final faces. An unchanged snapshot no longer emits
a second roll animation after a canonical event or on an unrelated UI refresh.
Network build compatibility is 0.11.0; protocol/action/save versions stay the
same. Existing saves still load; online peers use the same game version as before.

## Local miniature library and formats that worked

Main Menu ? Miniature Library contains the saved model list, Import, Delete,
editing controls, assignment and a live studio viewport. Drag to orbit, scroll
to zoom, or choose Front/Side/Top/Reset. Scale, three rotation axes, ground offset,
25/32/40/50/60/80/100 mm cosmetic bases, base style and a vertical cosmetic LOS
marker are editable. Alt-drag adjusts the marker. Auto Fit normalizes visual
height; Auto Orient restores the import coordinate axes. These are explicit
buttons and do not silently overwrite manual adjustments.

Primary/secondary color, metallic, roughness and emission overrides are available.
AnimationPlayers are retained, clips can be previewed and mapped to Idle, Move,
Attack, Hit and Defeat. The existing controller blends mapped clips or uses its
procedural fallback. Static GLB/glTF and conversion fixtures were tested; a broad
library of third-party skeletal rigs was not validated.

| Format | Actual implementation and validation |
|---|---|
| GLB 2 | Runtime GLTFDocument/GLTFState import; tested in the packaged Windows application, with embedded PNG material data in targeted tests |
| glTF 2 | Runtime import with validated relative BIN and PNG/JPEG resources copied into managed storage; external-buffer and texture fixture passed |
| OBJ | Converted by the user's Blender installation to GLB; original triangle fixture converted and imported with Blender 5.0 |
| FBX | Converted by Blender to GLB; original Blender-exported cube fixture converted and imported with Blender 5.0 |

Blender is optional for native glTF. Configure its executable in the library;
Windows also detects installed Blender Foundation folders. The controlled
conversion runs on a worker thread with factory startup, disabled auto-execution,
an application-owned script and explicit arguments. No Blender download/install
or script supplied inside a model is performed. Missing Blender produces manual
conversion instructions. This workflow is not an operating-system sandbox for
arbitrary malicious files; conversion cancellation/progress is limited.

Records and copied dependencies live in `user://miniatures/<id>/`. Transform,
material, assignment and licensing metadata persist there. Multiple assigned
records provide deterministic variants for a profile. Cosmetic assets never
enter canonical gameplay snapshots, profile hashes or WebRTC payloads. Gameplay
bases, picking collision and LOS origins remain profile-defined. The imported
base size and LOS marker are visual references for existing profile replacements.
Base *style* applies to the canonical base; selecting a larger cosmetic base does
not enlarge a competitive unit's footprint.

Missing files retain their local record and fall back to the authored model,
with a nonblocking message. Existing authored miniatures remain installed.
Library assignments apply when a battlefield loads. There is no private model
bundling in shareable mods. Local import grants no redistribution rights; creator,
source, license and notes fields are optional user records.

## Import limits and error handling

Model data and dependencies are limited to 32 MB combined; resource collections
are bounded, accessor counts cap at 300,000 each and two million combined, and
there can be at most 32 animation clips. PNG/JPEG dimensions are inspected before
native decoding: 4096 per dimension and 16 million aggregate pixels. Core glTF 2
is supported; data URIs, sparse accessors, vendor extensions and other texture
formats are rejected with conversion guidance. GLB must contain embedded data or
safe supported resources; relative glTF dependencies are copied before loading.

URI decoding precedes validation. Absolute paths, traversal, network URIs,
unsupported resource types and linked dependencies are rejected. Unsupported
extension/script fields are rejected, extras metadata is stripped before native
import, and generated visual nodes have scripts/collision/cameras/lights removed.
Malformed, missing and oversized fixtures return errors instead of crashing.
Complex arbitrary models can still be expensive within these limits; this is a
bounded runtime importer, not a promise to accept every glTF exporter extension.
Deleting a library entry removes its record and primary model; copied dependency
files can remain in that entry's managed folder.

## Terrain and atmosphere

All new geometry is original MIT artwork. No additional third-party archive was
required. Existing licensed Kenney dressing remains. The shared procedural kit
adds pointed arches, fractured wall masses, broken tracery, buttresses, monumental
pillars, communications spires, manufactories, generators, tanks, refinery pipes,
raised machinery decks, bunkers, barricades, siege wreckage, craters and rubble.
Toxic Forge includes a low reflective runoff pool. Variations use stable object
IDs and arithmetic rather than gameplay RNG.

Twelve shared surface presets cover concrete, stone, oxidized steel, military
paint, industrial flooring, scorched metal, sandstone, rust, hazards, rubble,
ceramic and energy. The procedural shader combines coarse weathering, chips,
stains, cracks, roughness/metal variation and small derivative normal detail.
Scenery meshes are merged per material. Ground gains worn roads/markings, cracks
and scorch variation; miniature materials gain wear and textured base shading.
Theme colors and Day/Dusk/Night lighting presets vary the mood. Existing sparse
steam and warning lights extend to the showcase environments, with density
control. Compatibility rendering remains supported; advanced effects retain the
existing quality gates.

The Ashen Basilica uses tall corner ruins, a ruined manufactorum, silent spire,
central pillars, ancient dynamo, relay objectives and open approach/firing lanes.
Ashfall Manufactorum and Toxic Forge substitute industrial masses and different
surface/lighting palettes. They intentionally share a tested gameplay layout.

The editor exposes the new terrain palette, move/rotate/delete/duplicate tools,
existing placement ghosts, optional one-inch grid snapping and theme controls.
Hover cards and tactical footprints use actual gameplay traits. Collision/LOS
proxies are the existing box/L-shaped primitives, including conservative blocked
wall openings. Decorative rubble/pools have no movement collision. Upper decks,
arches and gantries do not create legal elevated standing surfaces. No climbing,
new combat rule or inferred visual collision was introduced.

## Validation and Windows package

One full Godot regression ran: **1,594 checks passed, zero failures**, across the
16 existing and three new suites. No second full regression ran. It includes
existing AI, save/load/replay, editor, content, mod and local network checks.
No separate signaling service, TURN or public internet matrix was executed.
See `validation_0110.txt` for the concise results.

New focused suites cover six face mappings, repeated pools, Quick/Full/Off,
skipping, capped large pools, combat integration without RNG consumption,
recorded replay faces, native imports, relative dependencies, invalid/oversized
resources, traversal, transform/base persistence, assignment and fallback, all
three themes, spawn clearance, editor palette placement, duplication and scenario
save/load. The Blender-enabled importer follow-up passed **32 checks**. The final
real local ENet pair passed **25 checks**, including exact faces and suppression
of duplicate snapshot presentation. The release-version bump and snapshot guard
received these focused checks after the full-run source snapshot.

A Windows standalone export was copied to a folder with no source project files.
One focused graphical packaged smoke passed **23 checks**, including physical
dice/final faces, runtime GLB import, actual unit artwork replacement with
unchanged base/LOS, a complete AI round with zero illegal actions, exact save/load
and exact replay. The saved test round contains 36 recorded events. Screenshots
were captured from that application. The final export includes the small network
presentation guard and received an additional headless startup check.
The existing harmless local certificate-store warning still appears in the
headless editor/test environment. Linux/macOS were not rebuilt for this milestone.

## Performance

Ryzen 5 2600 / GTX 1660 Ti, Godot 4.6.1 compatibility renderer, Medium, 1280?800,
vsync off. One 100-model and one 200-model scenario were measured, with Basilica
terrain added to the established large-board test. Each mode sampled 90 frames.
This is heavier scenery than the previous baseline and not an identical-scene
comparison.

| Models | Idle FPS | Movement frame | Targeting frame | Previous documented FPS |
|---:|---:|---:|---:|---:|
| 100 | 119.9 | 8.70 ms | 9.33 ms | 157.4 |
| 200 | 67.2 | 15.04 ms | 14.91 ms | 81.5 |

One twelve-die Full roll was sampled separately: **1.23 ms/frame** for the tray
alone during its physical phase. This is not a combined-battle worst-case cost.
Raw hardware, memory, draw-call and timing data: `benchmarks/visual_0110.json`.
Large AI formation checks can still hitch; no safe small change justified altering
the planner during this visual milestone. Imported mesh complexity can change
performance substantially. Arbitrary third-party rigs and very large cosmetic
libraries need additional real-user testing.

## Screenshots and remaining scope

[Previous 0.10.0 battlefield](living_battlefield_0100.png) ?
[Basilica](basilica_0110.png) ? [Manufactorum](ashfall_manufactorum_0110.png) ?
[Toxic Forge](toxic_forge_0110.png) ? [Tumbling dice](dice_tumble_0110.png) ?
[Settled dice](dice_result_0110.png) ? [Miniature Library](miniature_library_0110.png).

The art remains procedural/stylized, with conservative collision proxies and
original authored fallback miniatures. There is no high-resolution scanned asset
library, physical destruction simulation, arbitrary elevated movement, full model
editor, automatic web asset download or new gameplay rule system. Larger pools
use representative physical dice. Local assets remain local. These boundaries
are intentional and are reflected in the interfaces and error messages.
