# Content and tabletop automation

`resources/content.json` is the central catalog of four factions, sixteen units,
twelve weapons, reusable visual scenes, and two showcase scenarios. Original
generic profiles and scenarios remain available. No commercial setting, rules
database, logos, insignia, or proprietary meshes are included.

Scenarios refer to `unit_id`. The registry resolves a unit profile, which owns
its weapon IDs and `model_scene`. Legacy `profile` paths still load. The editor
lists all sixteen units grouped by faction prefix and preserves IDs when saving.
Gameplay scripts never inspect imported mesh node names.

| Faction | Units | Example behavior |
|---|---|---|
| The Legion | Legion Trooper, Legion Heavy, Legion Walker, Legion Battle Tank | Durable generalists; dark blue and gunmetal |
| The Horde | Horde Raider, Horde Bruiser, Horde Gunner, Horde War Machine | Many attacks and weaker saves; rust and scrap metal |
| The Swarm | Swarm Crawler, Swarm Hunter, Swarm Brood Beast, Swarm Winged Beast | Fast melee creatures; purple and bone |
| The Synthetics | Synthetic Drone, Synthetic Sentinel, Synthetic Destroyer, Synthetic Walker | Slow durable shooters; black and teal |

Weapon profiles: Pulse Rifle, Combat Blade, Breach Cannon, Siege Projector,
Scrap Blades, Scrap Repeater, Scrap Crusher, Raking Talons, Crushing Fangs,
Spine Volley, Arc Beam, Energy Lance. These are sandbox examples, not competitive
balance targets. Winged creatures currently use normal flat-board movement.

## Miniature conventions

One world unit remains one inch. `base_mm / 25.4 / 2` determines the circular
footprint; 25, 32, 40, 60, 80 and 100 mm are used initially. 50 mm and other
sizes use the same helper without another mesh scene. CylinderShape3D drives
picking; horizontal base radii drive movement, coherency and range.

`Miniature` holds stable model identity, wounds and gameplay collision. Its
`VisualRoot` loads the scene; `LOSOrigin` is an independent configured Marker3D.
`visual_scale`, `gameplay_height`, and `los_height` are separate properties.
Swapping art never changes movement or range. A missing scene logs a warning
and uses the original generic fallback. Authored substitute scenes provide
humanoids, robots, walkers, tanks and biological creatures until CC0 unit
downloads become available; these are not imported Quaternius models.

Substitutes include original armor panels, backpacks, antennae, spikes, crests,
sensors, and simple weapons. Box geometry and palette materials are shared.
Stable cosmetic IDs derive small yaw/scale variations from model IDs; the
scenario capture preserves explicit cosmetic IDs. These never affect stats.

## Attack workflow

Select a squad, open Attack / Battle Log, choose a weapon, choose an enemy with
Target [4], then Confirm Attack. A confirmation dialog shows the current
eligibility/count; the engine recomputes eligibility when resolving. Green/red
rings indicate eligible/ineligible models while the attack panel is visible.
Each living attacker needs range and an unobstructed torso-height ray to the
same living enemy model. Range uses base edges. Melee uses the same range
eligibility with `type: melee`; there is no pile-in or consolidation.

Attack dice equal eligible models times weapon attacks. Hit, wound and save
arrays remain visible in the scrollable result and battle log. Wound thresholds
remain centralized in `AttackResolver.wound_target`. New profiles use positive
AP penalties: `modified_save_target(3, 1) == 4`. Seven means impossible.
Legacy profiles retain signed AP through the existing `save_target` helper.
Fixed damage equals failed saves times weapon damage; variable damage is deferred.

Manual allocation and casualty removal are the defaults. Settings optionally
enable auto-allocation and auto-removal. Auto-allocation chooses an already
wounded living model first, then the lowest stable model ID. It records the
same reversible damage/removal actions as manual play. Excess damage remains
pending for explicit discard after all valid recipients are gone. In multiplayer,
these are host settings and run only in the authoritative request execution.

Active-player checks apply offline too. The attack panel exposes an offline
sandbox override. Online ownership, active-team, and equipped weapon-index
checks remain enforced by the host regardless of this toggle.

## Movement and phases

The existing movement budget rings, origin markers, moved/remaining distances,
coherency links and invalid-model indication are retained. Auto-arrange proposes
a regular nearby grid around the squad centroid. Existing path, collision,
movement-budget and coherency checks must all pass, and the player must still
confirm the move. It does not select destinations or play the game.

Entering Movement surfaces a movement prompt without opening a provisional move
or blocking autosave. Shooting/Fight opens the attack panel. Manual tools remain
available and the existing host phase controls remain intact.

## Objectives and scoring

Living, unremoved models whose base touches an objective control radius count
for their team. A unique highest count controls it; a tie or no models is neutral.
Hover shows the counts and controller; the sidebar includes an objective summary
and scoreboard using faction names where a team contains one faction.

`scoring.objective_points_per_round` is optional and defaults to zero. Entering
the second team's End phase awards both teams points for their controlled
objectives. A recorded `scored_rounds` guard prevents phase-back/forward farming.
The manual Round+ override skips scoring; it does not fabricate omitted rounds.
These are generic demonstration semantics, not a specific mission system.

## Persistence, replay and compatibility

New games embed unit and equipped-weapon snapshots in `initial_scenario`.
Scenario rebuilds prefer those snapshots to installed stats. Save archives keep
stable IDs, faction/team through profiles/scenarios, positions, wounds, removals,
cosmetic IDs, combat dice/pending damage and scores. They never serialize meshes.
New saves/replays write full floating-point precision. Old archives without
profile snapshots still depend on their installed legacy definitions.

Game version is now 0.4.0. Network compatibility hashes the catalog plus all unit
and weapon files. Both clients must install matching content; no model files
are transmitted. Visual-only changes do not affect gameplay snapshots, though
editing a profile's visual path currently changes the conservative whole-file
compatibility hash. Old 0.3 clients cannot join this version.

Startup validation reports missing references, bad stats and scene paths.
Missing visuals remain playable. Dedicated checks exercise all imported GLB
loads, profile/scenario references, range and LOS, combat, scoring, settings,
save/replay, host checks and fallback visuals.
