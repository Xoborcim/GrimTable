# Data-only content packs (GrimTable 0.5.0)

Install a self-contained folder under `user://mods/`, then use **Main Menu ? Mods ?
Reload Mods**. Open Mods Folder shows the actual application-data directory.
Enabled/disabled selections persist in `user://mod_settings.cfg`; new valid packs
are enabled by default. Reload/toggles are available only from the main menu.
Return to the main menu before replacing pack files. No internet connection or
application rebuild is required. Each process keeps its validated definitions
stable until the next explicit reload.

For development only, `res://mods/` is also scanned. Its `.gdignore` prevents the
Godot editor from treating pack files as project scripts. User-installed packs
should always use `user://mods/`; development folders need not be exported.

## Structure and discovery

```text
example_army/
  manifest.json
  factions/expedition.json
  units/infantry.json
  units/heavy.json
  weapons/rifle.json
  weapons/cannon.json
  scenarios/outpost.json
  models/                    # optional static GLBs with embedded textures
```

The four definition directories contain `.json` files directly, not nested
subdirectories. Files and pack IDs are sorted deterministically. Dependencies
load first; ready packs load in ID order. Missing, disabled, failed or cyclic
dependencies reject the dependent pack. A bad pack is rolled back completely
without removing earlier valid packs. Mods shows the pack name/version/author,
enabled state and reason for any error. Duplicate pack IDs reject both folders;
content IDs cannot override earlier definitions.

## Manifest

Required fields are shown below. `version` is `major.minor.patch` (numeric
components 0?999). `grimtable_version` accepts an exact version or a simple
minimum such as `>=0.4.0`. Complex ranges/prereleases are not supported yet.
Optional `homepage` and `license` are metadata strings; the loader never opens
links or grants redistribution rights. Optional `dependencies` is an array of
pack IDs, not version constraints. Declare every cross-pack reference there.
Multiplayer separately compares actual installed pack versions and gameplay hashes.

### manifest.json

```json
{
  "id": "example_army",
  "name": "Frontier Expedition",
  "version": "1.0.0",
  "grimtable_version": ">=0.4.0",
  "author": "GrimTable Example",
  "description": "A data-only original expedition force using built-in fallback art.",
  "dependencies": []
}
```

### Faction: factions/expedition.json

```json
{
  "id": "example_army:expedition",
  "name": "Frontier Expedition",
  "color": "#607254",
  "accent": "#d8c687"
}
```

### Unit: units/infantry.json

```json
{
  "id": "example_army:infantry",
  "name": "Expedition Scout",
  "faction": "example_army:expedition",
  "movement": 7,
  "defense": 3,
  "save": 4,
  "wounds": 2,
  "base_mm": 32,
  "weapons": [
    "example_army:rifle"
  ],
  "fallback_visual": "legion_trooper",
  "gameplay_height": 1.7,
  "los_height": 1.35
}
```

### Unit: units/heavy.json

```json
{
  "id": "example_army:heavy",
  "name": "Expedition Anchor",
  "faction": "example_army:expedition",
  "movement": 4,
  "defense": 6,
  "save": 4,
  "wounds": 5,
  "base_mm": 60,
  "weapons": [
    "example_army:cannon"
  ],
  "fallback_visual": "synthetic_destroyer",
  "gameplay_height": 2.7,
  "los_height": 2.1
}
```

### Weapon: weapons/rifle.json

```json
{
  "id": "example_army:rifle",
  "name": "Expedition Carbine",
  "range": 20,
  "attacks": 2,
  "hit": 3,
  "strength": 4,
  "ap": 1,
  "damage": 1,
  "type": "ranged",
  "tags": []
}
```

### Weapon: weapons/cannon.json

```json
{
  "id": "example_army:cannon",
  "name": "Field Projector",
  "range": 28,
  "attacks": 3,
  "hit": 3,
  "strength": 6,
  "ap": 2,
  "damage": 2,
  "type": "ranged",
  "tags": []
}
```

## IDs, definitions and editor integration

Every external definition ID must use `pack_id:local_id`; local IDs use ASCII
letters, digits, `_` or `-`. IDs must be unique across the pack's categories.
The `grimtable` namespace is reserved. Old built-in IDs remain valid, and aliases
such as `grimtable:legion_trooper` resolve to the same built-in profile.

Faction `color` is an HTML color. Units reference a faction and an array of weapon
IDs. `wounds` becomes the existing engine's `max_wounds`; either form is accepted.
Movement and bases must be positive, wounds/defense are positive integers,
`save`/weapon `hit` are 2?7, and other weapon counts are bounded integers.
`base_mm` defines the footprint in inches (`base_mm / 25.4` diameter). Height,
LOS origin and visual scale are independent from movement/range. AP in external
packs is a nonnegative penalty; no commercial rules text is required.

References may point to the same pack, built-ins, or declared dependencies.
Definitions cannot supply executable scripts or replace built-in stats. The
scenario editor reads the live registry, grouping palette labels by pack and
faction. Start a new editor session after reloading packs.

## Scenarios

Scenarios use the existing schema; army entries reference `unit_id` rather than
file paths. Scenario IDs are namespaced, while on-table squad/model/objective IDs
remain ordinary unique IDs. Mod scenarios cannot provide raw profile snapshots,
profile file paths, or terrain `visual_scene` resources. Profiles are snapshotted
by the engine when a game starts. The full sample scenario is below.

```json
{
  "format_version": 1,
  "id": "example_army:outpost",
  "name": "Frontier Outpost",
  "notes": "Expedition scouts test a field projector against a Legion patrol.",
  "board": {
    "width": 60,
    "depth": 44
  },
  "coherency_distance": 2,
  "deployment_zones": [
    {
      "id": "zone_a",
      "shape": "rectangle",
      "team": 0,
      "name": "TEAM A DEPLOYMENT",
      "center": [
        0,
        17.5
      ],
      "size": [
        60,
        9
      ]
    },
    {
      "id": "zone_b",
      "shape": "rectangle",
      "team": 1,
      "name": "TEAM B DEPLOYMENT",
      "center": [
        0,
        -17.5
      ],
      "size": [
        60,
        9
      ]
    }
  ],
  "terrain": [],
  "objectives": [
    {
      "id": "marker",
      "name": "Outpost Beacon",
      "number": 1,
      "radius": 3,
      "position": [
        0,
        0,
        0
      ]
    }
  ],
  "armies": [
    {
      "id": "squad_0",
      "name": "Outpost squad 0",
      "team": 0,
      "unit_id": "example_army:infantry",
      "models": [
        {
          "id": "m_0_0",
          "position": [
            -3.4,
            0,
            6
          ]
        },
        {
          "id": "m_0_1",
          "position": [
            -1.7,
            0,
            6
          ]
        },
        {
          "id": "m_0_2",
          "position": [
            0.0,
            0,
            6
          ]
        },
        {
          "id": "m_0_3",
          "position": [
            1.7,
            0,
            6
          ]
        },
        {
          "id": "m_0_4",
          "position": [
            3.4,
            0,
            6
          ]
        }
      ]
    },
    {
      "id": "squad_1",
      "name": "Outpost squad 1",
      "team": 0,
      "unit_id": "example_army:heavy",
      "models": [
        {
          "id": "m_1_0",
          "position": [
            0.0,
            0,
            10
          ]
        }
      ]
    },
    {
      "id": "squad_2",
      "name": "Outpost squad 2",
      "team": 1,
      "unit_id": "grimtable:legion_trooper",
      "models": [
        {
          "id": "m_2_0",
          "position": [
            -3.4,
            0,
            -6
          ]
        },
        {
          "id": "m_2_1",
          "position": [
            -1.7,
            0,
            -6
          ]
        },
        {
          "id": "m_2_2",
          "position": [
            0.0,
            0,
            -6
          ]
        },
        {
          "id": "m_2_3",
          "position": [
            1.7,
            0,
            -6
          ]
        },
        {
          "id": "m_2_4",
          "position": [
            3.4,
            0,
            -6
          ]
        }
      ]
    }
  ],
  "starting_state": {
    "round": 1,
    "phase": 0,
    "team": 0,
    "deployment": false
  },
  "scoring": {
    "objective_points_per_round": 1
  }
}
```

## Optional model and texture support

`fallback_visual` names a built-in unit's permanent GrimTable-authored scene.
It is required to be a known built-in visual. If omitted, Legion Trooper is used.
The model's own gameplay stats remain independent from the visual choice.

To prefer an external visual, add a **relative pack-local** GLB path:

```json
{
  "visual": "models/scout.glb",
  "fallback_visual": "legion_trooper",
  "visual_scale": 1.0
}
```

These fields extend a complete unit definition; this fragment is not itself a
unit. GLBs load at runtime via GLTFDocument, so a packaged application needs no
Godot import cache for them. Export a static pose with baked orientation/scale;
forward is -Z and the visual floor sits on the miniature base. Adjust only
`visual_scale` for art sizing; set gameplay height/LOS separately.

The basic loader accepts bounded **static GLB 2** files with embedded buffers and
embedded PNG textures. It rejects external/data URIs, skins/animations, custom
extensions, extras/script metadata, unsafe node graphs and excessive resources.
Limits include 16 MB per GLB, 256 mesh/node entries, 250,000 elements per accessor,
2 million accessor elements total, 4096 x 4096 maximum PNG dimensions and 16 million
texture pixels total. Cameras/lights/collision/animation controllers are stripped
from generated scenes; processing is disabled for the visual subtree.

Separate texture files, raw `.gltf`, `.tscn`, `.tres`, `.pck`, GDScript, DLLs and
native extensions are **not loaded by the basic mod system**. Keep images inside
the GLB. Other files may accompany a pack (such as license notices) but do not
execute. Use the trusted project import tools for built-in art, not external
Godot scenes. Missing/unloadable preferred art uses the permanent built-in
fallback; it never substitutes unrelated gameplay stats.

## Validation and path rules

JSON definitions are limited to 2 MB and 200 files per category. Resource paths
must remain inside the owning pack. Absolute paths, `..`, `.`, alternate separators,
URI schemes, Windows device/stream names, trailing dots/spaces and symbolic links
in traversed components are rejected. Only ordinary ASCII filename components
are accepted. The runtime never mounts executable archives or downloads mods.

Use the same safety constraints on Linux/macOS; these platforms were not
runtime-tested in this milestone. No custom scripting/abilities API is provided.
The restricted loader is not a guarantee against bugs in the underlying native
model/image parsers; distribute content from sources you trust.

## Saves and replay

New saves and initial scenarios include:

```json
{
  "required_content": [
    {"id": "example_army", "version": "1.0.0"}
  ]
}
```

Dependencies are included transitively. Live saves require the recorded packs
and versions; a missing pack produces a clear load error. The engine keeps
frozen gameplay unit/weapon definitions, so old saves/replays retain their stats.
Replays may run without the pack when those snapshots are sufficient, using
built-in fallback art and recorded dice. Older built-in saves retain their IDs.
Changing a pack's gameplay without increasing its version is discouraged; saves
still use their snapshots and multiplayer checks the actual gameplay hash.

## Multiplayer

Both clients install/enable the same packs. The existing compatibility gate
compares sorted enabled pack IDs, exact versions, and hashes of normalized unit/
weapon definitions. Local install folder names and external visual file paths
are excluded from mod gameplay hashes. Built-in compatibility checks remain in
place. Even an unused extra enabled pack currently causes a conservative mismatch.
Nothing is automatically downloaded or transferred over ENet/WebRTC. No networking
infrastructure or signaling protocol changes are needed.

## Install the example

Copy the repository's `examples/mods/example_army` folder to the directory opened
by Mods ? Open Mods Folder. The result must be
`user://mods/example_army/manifest.json`, not a double-nested folder. Click Reload
Mods. Frontier Expedition should show enabled; Frontier Outpost appears in Play
Scenario, and its Scout/Anchor appear in the editor palette. The example contains
one faction, two units, two weapons and one scenario, and uses existing authored
visuals only. Remove/disable the folder from the main menu to uninstall it.

## Common errors

| Error | Fix |
|---|---|
| Missing manifest / malformed JSON | Check file placement, JSON syntax and required fields. |
| ID must use namespace | Prefix every content ID with the manifest ID and `:`. |
| Duplicate pack/content ID | Remove the duplicate folder or choose distinct IDs; overriding is unsupported. |
| Missing weapon/faction/unit | Correct its ID and declare cross-pack dependencies. |
| Missing/failed dependency | Install and enable it; remove cycles. |
| Unsafe visual path | Use a simple relative `.glb` path inside the pack. |
| GLB extensions/URIs/animations unsupported | Export a static GLB with embedded PNG textures and no custom metadata. |
| Missing content pack while loading | Install/enable the exact recorded version, or use a snapshot-backed replay. |
| Content pack differs online | Use matching versions/gameplay definitions and enabled pack sets. |

Focused validation is in `tests/mod_test.gd`; it uses an isolated application-data
folder when invoked through `tools/run_checks.gd`. Do not run tests against your
normal player data. See [PERFORMANCE.md](PERFORMANCE.md) for benchmark results.


## 0.7 automation traits

Existing mod unit movement/base/weapon definitions participate in Quick Move,
Fire All and ranged/melee eligibility without faction-specific code. Weapon
profiles remain unit-wide groups; per-model mixed equipment is not added here.
Scenario definitions may provide:

```json
"rules": {
  "difficult_ground_penalty": 2,
  "charge": {"dice": 2, "sides": 6, "bonus": 0, "engagement_range": 1}
}
```

Terrain can add `difficult_ground: true` or `movement_penalty: 2`. A route pays the
strongest touched area's flat penalty once. Existing `cover_bonus` is also
supported. Movement penalties must be 0–24 inches; charge configuration is
validated. The editor preserves these fields, but dedicated rule/trait widgets
remain future work. See [AUTOMATION_070.md](AUTOMATION_070.md) for complete semantics.
Both online players must use compatible 0.7.0 gameplay builds and matching packs.
