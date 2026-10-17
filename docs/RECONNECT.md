# Reconnect and live TURN renewal: supported scope

Gameplay reconnect is **not implemented** in this build. The UI intentionally
offers no Reconnect button. A host may continue locally after peer loss; a guest
returns safely to the menu. Host migration is out of scope.

What is implemented:

* Match-specific 256-bit random bearer capabilities, delivered over the member's
  signaling WebSocket. Server stores only SHA-256 digests and compares them in
  constant time. Tokens have a fixed match deadline, default 12 hours, and are
  revoked when either member explicitly closes the room. Names are not identity.
* Authenticated `refresh_ice` can reattach a **signaling** socket after signaling
  loss, without replacing the existing gameplay peer. Roles cannot be stolen by
  room code or display name. A still-open member socket cannot be displaced.
* RequestLedger owns a bounded recent-ID cache plus a high-water mark in the
  gameplay match. Old/duplicate IDs stay rejected after eviction. It must survive
  any future transport replacement; resetting the ledger is not reconnect.
* Compatibility handshake compares gameplay protocol 2, game version 0.3.0,
  scenario/action schemas, and exact bundled unit/weapon file hashes. Snapshots
  repeat the manifest. Incompatible peers cannot submit gameplay requests.
* Existing host snapshots contain initial scenario, current entity states,
  wounds/removals/objectives, turn/phase/player, pending combat decisions,
  canonical sequence/history, dice, and compatibility/profile hashes. Matching
  bundled profiles are required rather than trusting client-local variants.

## Precise native API limitation

The vendored webrtc-native 1.2.2 implementation's `initialize()` starts by closing
the current peer. Godot's public wrapper has no `setConfiguration()` or
`restartIce()` method. In the pinned native implementation `create_offer()` only
accepts `STATE_NEW`. Re-initialization to change TURN credentials would therefore
destroy an established direct or relayed session. This release does not call it
to refresh a live peer, and does not claim transparent renewal.

The client tracks the server-provided TTL using monotonic time, requests renewal
before expiry, and caches fresh ICE configuration for a future peer. It can
reconnect signaling with its private capability if the gameplay connection is
still active. A failed refresh uses bounded exponential backoff and never stops
an otherwise working data connection. The initial active peer's expiry is tracked
separately: fetching credentials does not pretend to extend its allocation.
Before that original deadline a warning recommends saving if relay service is
required. Continued relayed operation beyond the original credential deadline
is **not guaranteed**; whether an existing allocation remains refreshable depends
on the relay's authentication/allocation behavior. No live-allocation renewal has
been validated against coturn here.

Primary implementation references:

* [Pinned native peer lifecycle](https://github.com/godotengine/webrtc-native/blob/1.2.2-stable/src/WebRTCLibPeerConnection.cpp)
* [Godot 4.6 peer connection API](https://docs.godotengine.org/en/4.6/classes/class_webrtcpeerconnection.html)

## Safest planned guest → host reconnect

This is a design contract, **not a functioning flow**:

1. Pause canonical action acceptance at the host after loss; cancel all previews.
   Keep the authoritative game, ledger, and current sequence in memory.
2. Guest reauthorizes signaling with its match-specific capability before the
   fixed match expiry. Server must add a separate `resume_match` protocol with
   role validation and a strictly increasing connection generation; `refresh_ice`
   alone does not authorize replacing a gameplay peer.
3. Host explicitly accepts a single new generation. Both sides build fresh native
   peers with newly issued ICE credentials. Cancel/close the previous generation
   and reject stale SDP, ICE, frames, and callbacks.
4. Prove the returning player's identity again over the encrypted gameplay
   channel using a host-bound resume capability. The current signaling renewal
   token is not yet a host-validated gameplay identity. Do not trust a name,
   a room code alone, or a newly allocated Godot peer ID.
5. Run compatibility checks. Host sends the complete authoritative snapshot and
   request high-water mark. The guest discards provisional local state, installs
   that snapshot, acknowledges its hash/sequence, and uses a fresh request ID
   above the host watermark. Never reroll dice or replay unsent local intent.
6. Only then unpause the match. A duplicated pre-disconnect attack request must
   not generate a second roll or a second canonical action.

Required implementation/validation before exposing the button: generation-safe
transport replacement, host-bound identity proof, snapshot ACK/readiness barrier,
request-ID reconciliation, simultaneous disconnect races, and real TURN/network
failure testing. The present transport treats peer loss as terminal; adding a
button without these changes would falsely advertise recovery.
