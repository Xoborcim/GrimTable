# GrimTable 0.15.0 - Armies and Complete Battles

This milestone builds on the implemented 0.14.0 Workshop. No replacement art,
miniatures, terrain, shaders or lighting overhaul was produced for 0.15.0.
The primary additions are army composition, safe homebrew authoring, canonical
weapon use, deterministic missions and complete battle setup.

## Starting state and preservation

The project reported 0.14.0. HEAD was
`2657b2c413126dfe5aae5fb268f023e16b0cf903` (0.13.3), with the 0.14.0 Workshop
uncommitted. All existing changes were preserved. A 1,674-file source snapshot
was saved before editing to `builds/GrimTable-0.14.0-source-baseline.zip`.
[starting_state.json](armies_0150/starting_state.json) records original Git
status and individual SHA-256 hashes. At the initial handoff the milestone was
uncommitted; subsequent publication is recorded in Git history. Personal
collections and imported models are not part of the changes.

## Player flows

- **Army Builder:** create, edit, name, duplicate, save, import, export and delete
  local lists; built-in starter lists are copied on save. Invalid drafts remain
  editable and saveable, but cannot start a battle. Errors state what to fix.
- Select faction, preset/custom points, any registered faction profile, squad
  size and legal replacement counts. Costs update immediately. Save reusable
  loadouts; invalid preset data cannot bypass the same validator.
- Assign an imported miniature or compatible painted variant without opening
  the Workshop. Apply starter/saved paint schemes to one or all compatible
  squads. New local variants preserve the original figure, parts, bases and
  brushwork. Advanced schemes support the prepared Legion infantry, walker and
  Swarm hunter families, including profiles reusing those fallback families.
  Imported material schemes retain their existing Workshop limitations.
- **Play:** choose saved armies, agreed budget, scenario, primary, tactical
  cards, seed, AI difficulty/local human/spectator mode and board dimensions.
  Presets support 60 x 44 and 90 x 44 inches; custom setup accepts 60-120 x
  44-120 inches. Original terrain positions and inch ranges remain unchanged.
  Save named setups by army/scenario identity; missing references are reported.
- **Quick Play:** retains the existing small preset-army assisted experience.
- Deployment retains move previews, coherency, Auto Deploy and Ready. The new
  roster selects/focuses squads, filters names/status and rotates deployment
  formations through validated, undoable actions. Existing Undo restores earlier
  deployment edits; there is no separate destructive whole-board reset.

## Original rosters and points

There are 24 selectable profiles: six per faction. Four new separate leaders
and four additional tactical variants reuse existing artwork. Leaders are
independent units, with no partially implemented attachment/aura mechanic.

Legion emphasizes armor and combined arms; Horde trades protection for numbers;
Swarm emphasizes speed and monsters; Synthetics emphasize durable precision
firepower with slower core units. Not every faction has every role label.

Costs and bounds live in each canonical unit profile's `roster` object:
`role`, `points_per_model`, `base_points`, `min_size`, `max_size`, `max_units`,
plus legal upgrade/replacement/allowance records. Core infantry supports
5-10 or 5-20 models. Initial optional upgrades are the Legion support cannon,
Horde crusher and Synthetic lance; other profiles expose their baseline loadouts.

| Faction | Budget | Cost | Squads | Models |
|---|---:|---:|---:|---:|
| Horde | 1,000 | 998 | 13 | 46 |
| Horde | 2,000 | 1,998 | 24 | 110 |
| Horde | 500 | 497 | 6 | 20 |
| Legion | 1,000 | 988 | 7 | 22 |
| Legion | 2,000 | 1,986 | 14 | 46 |
| Legion | 500 | 500 | 5 | 19 |
| Swarm | 1,000 | 996 | 12 | 36 |
| Swarm | 2,000 | 1,998 | 20 | 53 |
| Swarm | 500 | 498 | 8 | 28 |
| Synthetics | 1,000 | 988 | 7 | 22 |
| Synthetics | 2,000 | 2,000 | 16 | 42 |
| Synthetics | 500 | 493 | 4 | 15 |

All twelve starters pass the same validator as player, AI and online lists.
[Initial balance estimates](armies_0150/initial_balance.json) include movement,
health, save and expected per-model damage against a fixed reference target.
These are rough original costs, not a competitive balance guarantee. Early
Legion-versus-Swarm automated samples vary by size and favor Legion at larger budgets; no tournament balance is
claimed. More seeds, human games and faction matchups are needed before
adjusting points based on these small samples alone.

A conservative limit of 300 models per army bounds extreme custom-content
compositions; physical deployment must still fit the chosen zones.

## Army and cosmetic architecture

`ArmyRoster` owns version-1 `grimtable_army` JSON, cost calculation, validation,
content fingerprints, dependencies and scenario generation. Lists store stable
unit IDs, counts, legal replacement quantities, names and optional cosmetic
references. They do not embed meshes, textures or executable content. Personal
lists live under `user://armies/`; loadouts and battle presets have separate
bounded formats. Writes use a temporary file and atomic rename.

Saved profile changes and missing content remain explicit errors. The builder
provides an **Accept updated profiles** action; it does not silently rewrite
profiles or remove illegal equipment. Imported lists receive a fresh local ID.
A changed points agreement affects the battle copy, not the saved source list.

Generated scenarios freeze actual gameplay profiles and weapon snapshots. Each
weapon group records its equipped model IDs. The collider, base radius, LOS
height and movement stay canonical, regardless of its selected visual.
Scenario capture now retains configured weapon snapshots rather than collapsing
back to the original default profile.

## Manual combat and automation

The existing tabletop combat panel already offered weapon choice, queued groups,
different targets and manual damage allocation. These were extended instead of
replaced. Its equipment counts now reflect actual holders, and previews refresh
when weapon expenditure or phase changes.

Configured army battles permit **one weapon per model per combat phase**:
ranged in Shooting, melee in Fight. Alternatives on the same model are mutually
exclusive; distinct equipped groups may split fire. Defeated models cannot fire.
Host execution uses the same eligibility service as previews and AI. Usage is
derived from executed/undone/redone canonical actions, preserving undo, reload
and replay behavior. Old sandbox scenarios retain their existing rules.

Assisted Fire All, target selection, Quick Dice, damage automation and phase
assistance remain. These do not expose future random rolls. Defender allocation
still uses the existing ownership-validated manual/AI paths.

## Missions and full battles

Three data-defined primary missions ship: Secure the Field, Convergence and
Network Superiority. Twelve original tactical cards use explicitly implemented
conditions: holding multiple/central/enemy-half sites, forward or rear positioning,
protecting a home site, and destroying selected battlefield roles.

Two tactical cards per team are drawn at round start. Cards score at full round
end and then expire; this initial deck does not permit manual retention/discard.
The mission inspector shows conditions, progress, potential points and the award
ledger. A short animated reveal announces the current team's cards.

Decks use a seeded initial shuffle and persist draw/discard/active/completed
piles. They recycle their recorded discard order only after exhaustion. Mission
state, score totals, scored rounds and unique award IDs live in the canonical
turn snapshot. Revisited phases/repeated processing cannot award twice. Turn
records contain the resulting draws and awards: replay restores them without
calling mission RNG or AI again. Numeric normalization preserves canonical state
through JSON round trips. Duplicate award IDs and unsupported cards are rejected.

Missions finish after six scored rounds, or elimination when damage is resolved.
Outcome is recorded canonically. Results include army names, primary/tactical
scores, rounds, surviving/defeated models and damage, with replay and rematch.
AI utility includes active positional missions and priority targets; difficulty
changes the existing planning weights, without illegal stat bonuses.

## Custom factions and safe rules packs

The player-facing editor creates faction name/description/palette/simple emblem,
unit roles, size limits, points, movement, defense, save, health, base diameter,
baseline weapon choices and fallback visuals. Weapons expose canonical range,
attacks, accuracy, strength, AP, damage and type.

Two implemented weapon traits are exposed:
- `anti_heavy`: +2 Strength against Vehicle, Walker and Creature roles.
- `anti_infantry`: +1 Strength against Infantry, Specialist and Leader roles.

Resolution and AI/previews use the same conditional strength calculation.
There is no untrusted scripting or fictional unsupported ability menu. Faction-wide
scripted abilities, attached leaders, arbitrary triggers and custom mission
condition authoring are outside this initial editor.

Exports are version-1 `grimtable_content_pack` JSON bundles containing rules and
metadata. Installation produces the existing mod folder/manifest/definition
format and reloads `ContentRegistry`; it does not replace the mod architecture.
Existing non-editor packs cannot be overwritten by this editor. Editor pack
updates preserve the previous directory in `user://content_backups/`. Invalid
numbers, references, traits, scripts, model packaging and unsafe paths are rejected.
Creators assign points; custom factions are Homebrew. Local third-party models
are assigned separately and are never automatically redistributed.

## Online authority, saves and replay

Saved Armies mode is available in online and LAN setup. Each player selects a
local saved list. The host validates budget, faction/equipment legality, pack
versions and profile fingerprints, then constructs the actual scenario. Both
players review and explicitly accept its roster/mission/budget/Homebrew agreement
before deployment. The client reconstructs and hashes the same proposal and
rejects changes to its selected army. Mode/content mismatches fail clearly.

The existing host action authority, transport, deterministic combat, canonical
snapshot and replay systems remain. No meshes, paint PNGs or executable rules
are transferred. Missing local cosmetics fall back to normal visuals. Online
rematch uses the host's agreed scenario; clients cannot silently replace it.

Army composition/equipment are retained in frozen scenario data. Mission piles,
awards, round, active player, deployment and readiness are turn state. Existing
save/replay schema versions remain readable; new optional state is validated.
Normal network compatibility requires the matching 0.15.0 build and gameplay packs.

## Workshop and planning performance

A targeted headless CPU profile found repeated PNG encoding of an unchanged
1024-square paint overlay on every Workshop undo checkpoint. Caching by paint revision
retains stroke undo/redo while avoiding re-encoding for region/color/pose edits.

| Operation | Before | After |
|---|---:|---:|
| Checkpoint, unchanged paint | 42.64 ms | 0.074 ms |
| Dirty fingerprint | 1.20 ms | 0.063 ms |
| Material refresh | 0.79 ms | 0.88 ms |

These are eight-call CPU samples, not a claim of measured interactive Workshop
FPS. Geometry rebuild, brush ray sampling, GPU uploads and the studio viewport
remain possible costs. There was no broad Workshop refactor.

Movement sweep validation now filters potentially intersecting models once per
route instead of querying/scanning every model at every 0.12-inch sample.
Runtime AI still spreads movement candidates across frames with its existing
watchdog. Auto Deploy remains a batch operation: the 212-model legal-deployment
test took about 1.8 seconds. This setup pause is a known remaining responsiveness
limit, not a claim that every operation fits a 60-FPS frame.

## Validation and Windows delivery

Final regression, native renderer benchmark and packaged Windows results are
recorded below. The regression is run once against an
isolated project/user profile; any failures receive affected-suite reruns only.
No external TURN, hosted signaling or public-network infrastructure tests are
provisioned or repeated.

The 500/1,000/2,000-point acceptance drivers are bounded, seeded automated
AI-versus-AI games. They exercise army generation, legal deployment, six-round
progression, missions, canonical weapon use, save and replay validation. They
are not human usability tests. The separate dense Swarm test deploys 212 models.

[Regression](armies_0150/regression.json) |
[500-point game](armies_0150/acceptance_500.json) |
[1,000-point game](armies_0150/acceptance_1000.json) |
[2,000-point game](armies_0150/acceptance_2000.json) |
[Native screenshot gallery](armies_0150/gallery.html).

## Final recorded results

The single full regression covered **30 suites / 2,530 checks**. Two old
sixteen-profile count assertions failed and were corrected. Only the affected
content/mod/animation suites plus the updated army-bound/persistence checks were
rerun: **393 focused checks passed**. All thirty suites have a passing final
result; there was no second complete regression. A later header-layout change
received a focused 14-check army/battle rerun and native HUD checks.
[Final validation record](armies_0150/validation_final.json) preserves the
original failures and focused corrections rather than rewriting the first run.

The exported Windows application passed **17 functional checks** covering the
editor, actual equipment, custom profiles, deployment, missions, persistence and
replay. Native screenshot inspection found a header/reveal overlap; correcting it
was followed by **3 focused native HUD checks**, all passing. The final archive executable also passed the same focused UI/persistence
validation after the metadata correction. The final executable uses OpenGL Compatibility on
the GTX 1660 Ti. The root-certificate-store environment warning did not prevent
rendering or any checks.

| Automated game | Models | Rounds | Score (Legion-Swarm) | AI mean / p95 / max decision | Deployment |
|---|---:|---:|---:|---:|---:|
| 500 points | 47 | 6 | 0-3 | 11.3 / 54.0 / 160.4 ms | 92 ms |
| 1,000 points | 58 | 6 | 5-0 | 28.1 / 144.4 / 301.5 ms | 202 ms |
| 2,000 points | 99 | 6 | 27-0 | 33.0 / 118.3 / 221.8 ms | 678 ms |

All three games completed within the bounded driver budget, saved successfully
and passed replay-event validation. These decision timings come from synchronous
automated driving, not render-frame latency. Runtime movement planning retains
frame spreading; some whole decisions still exceed a frame. The sample is too
small for firm balance conclusions (Swarm won the 500-point seed; Legion won the
larger seeds). A separate 212-model legal deployment took 1.86 seconds.

| Mixed-roster renderer test | 0.13.3 reported | 0.14.0 default measured | 0.15.0 measured |
|---|---:|---:|---:|
| 100 models | 156.7 FPS | 155.9 FPS | 156.4 FPS |
| 200 models | 86.4 FPS | 85.0 FPS | 82.9 FPS |

Same existing composition benchmark: Windows, Ryzen 5 2600, GTX 1660 Ti,
1280 x 800, Medium, VSync off, 90 frames per mode. Draw calls remain 2,292 / 4,308.
The 0.15.0 idle static-memory samples were 157.6 / 175.3 MiB. No new texture sets
were added; the executable grew by roughly 130 KiB of rules/UI/data rather than
new art. Benchmark variation and the small sample do not establish a precise
regression percentage. [Raw benchmark](benchmarks/armies_0150.json).

The packaged 2,000-point UI/battle validation reported about 406.4 MiB of render
texture memory and 555.0 MiB of video memory. Those totals include existing
cached menu/scenario assets; they are not additional 0.15.0 texture allocations.
Personal paint overlays remain the existing bounded 1024-square format and
cached material system.

The release folder is `builds/GrimTable-0.15.0-windows-x86_64/`; its distributable
archive is `builds/GrimTable-0.15.0-windows-x86_64.zip`. Keep the native WebRTC DLL
with `GrimTable.exe`. The archive includes licenses, this report, the screenshot
gallery and raw validation/benchmark evidence. It excludes personal content,
imported models, authoring sources and the source-baseline archive.

## Remaining limits and honest scope

Human mouse/keyboard acceptance matches and a new live internet battle have not
been performed by this agent. The local two-peer test exercises real canonical
proposal serialization, independent reconstruction, consent, snapshot application
and matching hashes; it is not evidence of remote connectivity. The unchanged
existing transport tests remain part of the one Godot regression.

Army construction and supported custom rules are functional, but this is an
initial balance release. Alternate baseline weapons share one per-phase model
choice; V1 does not offer separate one-shot ammunition or unlimited simultaneous
weapon firing. Initial replacement allowances cover three built-in infantry
families. Imported cosmetics retain Workshop capability tiers; a scheme is not
promised to repaint arbitrary imported materials. Original map layouts remain
centered on larger boards rather than generating new terrain.

The scope deliberately keeps assembly, painting and gameplay equipment separate,
uses original rules/card text, and introduces no new art-production milestone.
