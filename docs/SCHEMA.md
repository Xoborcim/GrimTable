# Scenario, save, and replay formats

These formats use JSON with explicit versions. Distances are inches, positions are `[x, y, z]` with `y = 0`, and rotations are degrees. Object IDs are stable ASCII letters/digits/underscores/hyphens, globally unique within a scenario. Display names may change without changing identity.

## Scenario format 1

`resources/scenarios/demo.json` is the complete example; `empty.json` is an empty-board starting point.

```json
{
  "format_version": 1,
  "id": "example",
  "name": "Example Scenario",
  "notes": "Optional instructions",
  "board": {"width": 60, "depth": 44},
  "coherency_distance": 2,
  "deployment_zones": [
    {"id":"zone_a", "shape":"rectangle", "team":0,
     "name":"Team A", "center":[0,17.5], "size":[60,9]}
  ],
  "terrain": [
    {"id":"wall_1", "title":"Wall", "kind":"box",
     "position":[0,0,0], "size":[7,3,0.8], "rotation":90,
     "tint":"#7a817c", "blocks_movement":true, "blocks_los":true}
  ],
  "objectives": [
    {"id":"objective_1", "name":"Relay", "number":1,
     "radius":3, "position":[10,0,0]}
  ],
  "armies": [
    {"id":"alpha", "name":"Alpha Squad", "team":0,
     "profile":"res://resources/units/trooper.json",
     "models":[{"id":"alpha_1", "label":"A1", "position":[0,0,16], "rotation":0}]}
  ],
  "starting_state":{"round":1,"phase":0,"team":0,"deployment":true}
}
```

The profile path resolves a generic unit definition with its weapon reference. Unit creation initializes health from that profile; scenario files do not store battle damage or casualty state. `kind` currently supports `box` and `ruin`. Deployment shape representation is separate from scene rendering and can gain more implementations later.

## Game save format 2

Top-level fields are `format_version`, `scenario_reference`, `initial_scenario`, `models`, `terrain`, `objectives`, `turn`, `combat`, `battle_log`, `replay_supported`, and `undo_redo`.

The embedded initial scenario is authoritative for reconstructing the roster and scenery, even if the original custom scenario file is no longer present. Current-state collections reference stable IDs and contain only mutable game state. `combat` stores the complete current attack result, target unit, attack ID, and remaining unallocated damage. `battle_log` includes recorded dice and ordered state deltas.

`undo_redo.persisted` is false: runtime command objects are not rehydrated on load. Historical execute/undo/redo records remain available to deterministic playback.

Legacy `version: 1` files are recognized as original-demo saves. They can migrate forward while preserving readable logs. Since early logs omitted some state transitions, migrated files set `replay_supported: false`; replay reports an explicit error. Normal new scenarios always record complete replay histories.

## Replay format 1

```json
{
  "format_version": 1,
  "initial_scenario": {"...":"complete scenario definition"},
  "events": [
    {
      "sequence": 42,
      "kind": "execute",
      "payload": {
        "title": "Move Alpha Squad",
        "kind": "unit_move",
        "type": "unit_move",
        "actor": "alpha",
        "affected_objects": ["alpha_1"],
        "changes": [
          {"id":"alpha_1", "property":"global_position",
           "before":[0,0,16], "after":[0,0,19]}
        ],
        "metadata": {"unit":"alpha", "coherency_override":false}
      }
    }
  ]
}
```

Sequences are monotonically increasing. Event kinds include `execute`, `undo`, `redo`, `attack`, `turn`, and `start_game`. Commands retain readable titles while IDs and typed property deltas carry their actual meaning. Replay applies `after` for execute/redo and `before` for undo.

The codec whitelists `global_position`, `wounds`, `removed`, current combat state, and remaining attack damage. It never accepts arbitrary property names or invokes scripts named by input. Attack records include shooter/target IDs, source/target profiles, contributing model IDs, every individual die, thresholds, successes, failed saves, and potential damage. Allocation/removal commands add actual damage and casualty IDs. Turn transitions contain full before/after tracker values.

Attack state is associated with `attack_<sequence>` identities so later allocations and their undo/redo affect the correct recorded result. JSON number arrays are normalized to integer dice; playback never calls RNG methods. The codec is a local replay foundation, not a multiplayer protocol.
