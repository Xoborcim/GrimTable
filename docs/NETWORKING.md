# Room-code multiplayer

GrimTable supports two players: host owns Team A, guest owns Team B. Choose
**Multiplayer → Create Online Game**, select a scenario, and copy the six-character
room code. The other player chooses **Join Online Game**. Both clients must use
the same signaling server, configured in **Network Server Settings**. No public
GrimTable service is provisioned: the shipped URL is the local development
server, `ws://127.0.0.1:8080`. A community deployment uses `wss://your-domain`.
The host chooses the scenario and starts the battle after deployment.

## Architecture

```text
UI / interaction / transactional movement
             ↓ action requests
NetworkSession → NetworkAuthority (host only)
             ↓ existing GameAction / CombatController / DiceManager
BattleLog → ordered canonical events + state hash + validated snapshot
             ↓ transport-independent SceneMultiplayer byte messages
       ENetTransport OR OnlineTransport
                             ↓
                WebRTCMultiplayerPeer / native peer connection
                             ↓
                      direct P2P / TURN relay
```

This checkout had no ENet/session implementation before this milestone. The new
session wraps the existing movement, action, replay, combat, dice, and world-state
systems; there is one authority implementation shared by both transports.
Offline play uses the same systems with no network submission hooks installed.

`scripts/network/multiplayer_transport.gd` owns the common peer lifecycle.
`enet_transport.gd` opens an ENet server/client. `webrtc_transport.gd` handles
signaling, SDP, ICE, WebRTC peer creation, and timeouts. `network_session.gd`
owns protocol sequencing, chunking, synchronization, and disconnect handling.
`network_authority.gd` validates player intent and converts accepted changes
into existing reversible commands.

The signaling service only knows transient rooms, names, SDP, and ICE. It never
receives scenarios, match state, action requests, combat, or dice. Neither it
nor coturn runs the game simulation. Direct peer connections inherently connect
the players' networks; peers can learn one another's network addresses. Normal
UI and signaling logs do not display IPs or SDP. Use a trusted server operator.

## Native dependency and exports

The official [webrtc-native 1.2.2-stable release](https://github.com/godotengine/webrtc-native/releases/tag/1.2.2-stable)
supports Godot 4.3+. Binaries, descriptor, and licenses are vendored under
`addons/webrtc_native/`. See [its provenance document](../addons/webrtc_native/UPSTREAM.md)
for the archive checksum and reproducible restoration command. It contains
libdatachannel 0.24.6 and mbedTLS 3.6.7. Godot loads the GDExtension automatically;
no global installation is needed.

Windows x86_64 is runtime-tested with Godot 4.6.1. Export the **whole Windows
folder**: `GrimTable.exe`, the accompanying WebRTC DLL, Godot notices, and native
dependency notices. Embedded PCK resources do not embed the executable DLL.
Upstream also provides Linux and macOS libraries; their runtime compatibility
has not been tested here. macOS signing/notarization remains a release task.

## Gameplay protocol version 2 (GrimTable 0.3.0)

All gameplay messages are JSON with `version: 2` and a `type`. Signaling remains
version 1. A `hello` handshake compares game version, scenario/action schemas,
and SHA-256 hashes of the bundled unit/weapon JSON before accepting gameplay.
Reliable ordered messages
use the same `SceneMultiplayer` peer-packet API on both transports. Payloads are
split into 10,000-byte chunks; a complete message is limited to 2 MB / 200 chunks.
Malformed frames, duplicate/out-of-order request IDs, excessive requests, and
unsupported commands are rejected. Object deserialization is disabled.

* `request`: monotonically increasing `request_id`, last observed `sequence`,
  `command`, `args`. Clients submit intent; they cannot submit combat results.
* `canonical`: ordered existing battle-log events, resulting `sequence`, state,
  hash, and recorded dice history. `execute`, `undo`, `redo`, `attack`, `dice`,
  `turn`, and `start_game` preserve replay compatibility.
* `lobby` / `snapshot`: validated initial scenario, full ordered history, current
  state, sequence, hash, and dice. Used for initial synchronization and resync.
* `resync`, `rejected`, `ping`, `pong`: recovery, useful errors, application RTT.

The host checks entity IDs, ownership, active player, command/property allowlists,
stale origins, board boundaries, terrain/base collisions, full movement waypoint
costs, deployment zones, and coherency. Only the target owner allocates damage or
removes defeated models. The host controls start, undo/redo, previous phase and
round changes. Either player can request generic dice; only the active player
advances the phase. Manual wound adjustment remains available for owned models.
Online terrain editing and coherency override are disabled. Local play retains
its unrestricted sandbox controls.

Combat requests call the original resolver on the host. The host's DiceManager
generates every hit, wound and save. Both clients use the identical recorded
faces; replay never rerolls. Provisional movement stays local. Confirm sends a
request; cancel sends nothing. Requests are rejected while the host has a
provisional move, preventing snapshots from containing an unconfirmed layout.

Hashes are SHA-256 over sorted-key world state, with all numbers normalized to
fixed-point 1/10,000. This avoids JSON integer/float and negative-zero differences.
Sequence gaps request a complete snapshot. A hash mismatch requests resync twice,
then stops the connection with a visible error if state still differs. Confirmed
actions retain the existing format-version-2 save and deterministic replay data.
Network connections and in-memory undo stacks are not restored from a save.

## Signaling protocol version 1

WebSocket JSON envelopes contain `version: 1`, `type`, and the following fields:

| Direction | Type | Fields |
|---|---|---|
| Client → service | `create_room` | `player_name` |
| Service → host | `room_created` | `room_code`, `ice_servers` |
| Client → service | `join_room` | `player_name`, `room_code` |
| Service → guest | `room_joined` | `room_code`, `player_name`, `ice_servers` |
| Service → host | `peer_joined` | `player_name` |
| Host → guest via service | `offer` | `sdp` |
| Guest → host via service | `answer` | `sdp` |
| Either peer via service | `ice_candidate` | `media`, `index`, `candidate` |
| Either | `ping` / `pong` | none |
| Client → service | `close_room` | none |
| Service → client | `peer_left` | `reason` |
| Service → client | `error` | stable `code`, readable `message` |

Room codes use cryptographic random choices from 32 unambiguous uppercase
characters, six positions (30 bits), uniqueness checked against active
rooms. Entry is case insensitive. One host and one guest are allowed. Explicit
match cancellation closes a room and revokes tokens. Waiting rooms expire after
30 minutes by default; joined renewal-capable matches retain a fixed lease as
described below. New invitations require a new room; no permanent lobby database
or cross-generation ICE reuse exists.

Remote URLs must use WSS. Only literal localhost WS URLs are accepted for local
development. TLS certificate verification stays enabled. The WebSocket remains
open but idle after negotiation. Closing signaling or expiring its room does not
interrupt an established data connection. The two-process smoke test explicitly
closes signaling before playing the battle. ICE restart/reconnect is not
implemented: after loss, the host can continue locally or both can return to the
menu and create a fresh session. The guest has no misleading reconnect button.
See [RECONNECT.md](RECONNECT.md) for the implemented signaling lease and precise
native limitation, plus the generation-safe gameplay reconnect design.

## STUN, TURN, and diagnostics

The service supplies data-driven ICE servers from `STUN_URLS` and `TURN_URLS`.
STUN helps ICE discover reachable addresses. TURN supplies a relay when direct
checks fail. ICE tries candidates together; the UI does not claim separate direct
and relay stages that it cannot observe. Coturn's TURN REST authentication uses
`expiry_timestamp:random_connection_id` usernames and Base64 HMAC-SHA1 passwords.
Only the service and coturn hold `TURN_SHARED_SECRET`; clients receive temporary
credentials on room create/join. Defaults expire after two hours. Clients track
the server TTL using monotonic time and request fresh credentials before expiry.
They can reauthorize a signaling socket using a private match capability. Fresh
configuration is cached; it **cannot be applied to the live native peer** with
the pinned API. A warning precedes the original peer's credential deadline.
Continuous relayed service past that deadline is not guaranteed.

Clients advertise `capabilities: ["credential_refresh"]`. Room responses include
an opaque `session_token`, `session_expires_at`, `server_time`, and
`turn_expires_at` (null if TURN is disabled). `refresh_ice` takes `room_code` and
`session_token`; `ice_credentials` returns fresh ICE configuration/expiry. Tokens
are never gameplay identity proofs. Joined capable matches retain their signaling
authorization for a fixed `MATCH_TTL_SECONDS` (default 12 hours) even if signaling
disconnects. Explicit room closure revokes both tokens. Waiting rooms still expire
after `ROOM_TTL_SECONDS`. Legacy clients retain the earlier disconnect cleanup.

The menu's **Network Diagnostics** shows transport, signaling/SDP state, native peer
and gathering states, local/remote candidate types, renewal state, application
round-trip time, canonical sequence and hash status. The
pinned plugin does not expose the selected candidate pair, so route is explicitly
**unavailable**, never guessed. The normal HUD identifies the player's team.

Local smoke tests without any TURN server are evidence of local direct P2P,
not evidence of internet NAT traversal. The relay-only test filters non-relay
SDP/trickle candidates on **both** clients because this native plugin does not
implement the browser `iceTransportPolicy` setting. See self-hosting instructions
to run it against an actual relay.

## Scope and limits

Two players, no accounts, no public matchmaking, no reconnect/host migration.
The host is trusted and can modify its own program; authority protects the host
from guest requests, not players from a malicious host. Canonical updates carry
validated state snapshots for correctness; large battles/history are limited to
2 MB per message. One accepted command can produce several sequenced battle-log
events. Host undo/redo is intentionally a session-level decision. This is a
prototype protocol, not a complete adversarial network-security audit.

See [SELF_HOSTING.md](SELF_HOSTING.md) for operational controls and backend setup.
