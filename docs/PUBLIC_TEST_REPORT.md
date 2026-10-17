# Internet validation report — GrimTable 0.3.0

**Status: public-internet acceptance is incomplete.** No VPS access, public test
domain, or second machine/network was supplied. SSH is disabled in this execution
environment and no Docker daemon is available. No VPS was purchased or deployed,
no public endpoint is claimed, and no test below substitutes a LAN for two ISPs.

## Actual environment and evidence

* Windows development host, Godot 4.6.1, official webrtc-native 1.2.2-stable.
* Node.js 25.7.0 locally; service supports Node 22+, pinned `ws` 8.22.0.
* Local signaling endpoint: `ws://127.0.0.1:8080`.
* Native Windows release smoke uses separate app-data directories and the exported
  release DLL; no editor/source files are required beside the executable.
* Compose CLI 2.39.4 validates base and TURN TLS overlay configuration. Container
  image build and Linux coturn execution remain untested locally. Git Bash shell
  execution is also restricted; shell validation is scheduled in Linux CI.

| Requirement | Actual result |
|---|---|
| Public VPS environment | Not available / not deployed |
| Public domains/endpoints | None tested |
| Windows acceptance of WSS certificate chain | Not tested |
| Public STUN binding | Not tested |
| Coturn temporary-credential acceptance/expiry | Not tested against a live relay |
| Direct P2P across separate networks | Not tested |
| Forced TURN gameplay across separate networks | Not tested |
| Local two-process WebRTC | Passed with compatibility handshake, canonical gameplay and resync |
| Local ENet fallback | Passed |
| Signaling socket closed after connection | Passed; gameplay finishes |
| Signaling **process stopped** during established local match | Passed; gameplay and state hashes finish correctly |
| Create room while service unavailable | Passed real socket failure test, actionable bounded timeout |
| Credential issuance/refresh | Server integration passed, client fetched/cache acknowledgment passed locally |
| Live native TURN allocation renewal | Unsupported by pinned API; explicitly not claimed |
| Guest gameplay reconnect | Design/foundations only; not implemented |
| Coturn failure during direct or relayed match | Not tested |
| Real packet loss | Not simulated |
| Linux/macOS runtime | Not tested |

## Local gameplay and latency

Final source regression totals: **572 Godot checks passed** across seven suites
(275 tabletop, 76 squads/combat, 48 scenarios/replay, 55 application/path, 48
networking, 67 readiness/renewal/compatibility, 3 real socket-failure checks).
All **19 Node signaling/probe tests passed**, preserving the original nine.

Smoke checks use the actual app's multiplayer path, demo squad definitions, an
open firing lane and widened deployment zones. They check both armies' deployment,
movement, undo/redo, host-generated attacks and individual dice, damage allocation,
actual casualty removal, phases, matching hashes, explicit snapshot recovery after
deliberate guest divergence, and disconnect handling. Confirmation predicates
inspect actual entity state; an unrelated sequence advance is not a casualty ACK.

Outgoing application frames were delayed by 50, 100, and 200 ms **on each peer**.
These are application-delay tests, not kernel network emulation or packet loss.
All three completed the full gameplay check with identical host/guest combat,
tray dice, casualties and final hash. Representative application RTT was roughly
110, 210 and 410 ms respectively. Local undelayed RTT was in single-digit ms.
These timings do not describe public internet latency.

Final smoke hash for the fixture:
`9fc324b768987252a3d43715d411343f91ba2904121fc52cae6869c58a208a76`.
Raw local logs are generated under `.runtime/network-smoke-<timestamp>/`, ignored
by git. They contain no TURN password or session token. Candidate metadata records
types only. Selected route remains unavailable in the pinned public native API.

## Security findings and changes

* Added protocol/game/schema/profile compatibility checks before gameplay.
* Added bounded request ledger with persistent high-water rejection of duplicates.
* Tightened ICE URL validation before native parsing, including empty hosts,
  control characters, invalid ports/transport, and malformed IPv6 literals.
* Renewal uses 256-bit random, match-specific capabilities; server stores only
  digests, validates expiry, rejects displacement of a live signaling member, and
  revokes both tokens on explicit match closure.
* Fixed TURN HMAC expected vector was independently checked using Windows/.NET
  HMAC-SHA1 as well as server tests. Coturn expiry rejection still needs runtime
  evidence; a unit calculation is not evidence of a live allocation.
* Production server logger records event/error codes only. Tests inspect it for
  secret, password and token leakage. Optional metrics contain aggregate counts.
* Coturn startup validates addresses/port range/realm/secret/TLS files, keeps the
  secret out of process arguments, and uses a private tmpfs configuration.
* No certificate verification was disabled. This host reports a system
  certificate-store startup error; public Windows WSS must be verified separately.

## Commands for the outstanding public test

Follow [SELF_HOSTING.md](SELF_HOSTING.md) to configure DNS, Docker, firewall, TLS,
and actual public/private relay addresses. Verify the backend with:

```sh
node tools/probe_backend.mjs --signal-url=wss://signal.example.com
```

Use `--check-expiry` against a separate TTL-60 test deployment to verify actual
coturn rejection after credential expiry. Backend probe success is not an
end-to-end WebRTC gameplay test.

Run one role per real machine/network:

```powershell
# Machine A / network A:
./tools/internet_peer.ps1 -Godot './builds/windows/GrimTable.exe' -Role host `
  -SignalingUrl 'wss://signal.example.com' -ForceTurn
# Machine B / network B: use Machine A's room code:
./tools/internet_peer.ps1 -Godot './builds/windows/GrimTable.exe' -Role guest `
  -SignalingUrl 'wss://signal.example.com' -RoomCode ABCDEF -ForceTurn
```

Repeat without `-ForceTurn` for normal ICE and with `-KeepSignaling -HoldSeconds 30`
for operator-controlled failure tests. Do not publish a forced relay pass unless
both machines have it enabled and the complete gameplay check passes.

Record: VPS provider/OS, build hashes, domains, certificate issuer/chain result,
network-separation description, credential allocation/expiry result, normal/forced
test logs, RTT, exact combat/dice/hash comparison, failure exercises and UTC dates.
Do not include credentials, tokens, full SDP or player IPs in shared reports.

## Recommended next milestone

Run this prepared deployment and acceptance matrix on an authorized public Linux
VPS with two Windows machines on separate ISPs. Resolve live TURN/WSS findings
before exposing reconnect. [RECONNECT.md](RECONNECT.md) describes the precise
remaining native and session-identity work.
