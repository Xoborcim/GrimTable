# Milestone validation

Godot 4.6.1 stable, GDScript, Compatibility renderer.

| Suite | Passed | Failed |
|---|---:|---:|
| Original tabletop | 275 | 0 |
| Squad movement / combat | 76 | 0 |
| Scenario serialization / deterministic replay / save migration | 48 | 0 |
| Menus / editor input / auto-save / portable resource references | 55 | 0 |
| Network authority / stable hashing / action validation / menus | 48 | 0 |
| Internet readiness / renewal / compatibility / channel audit | 67 | 0 |
| Real unavailable-service socket failure | 3 | 0 |
| Total | **572** | **0** |

All suites ran through the isolated source-project runner. The renderer checks inspected the main menu, browser, terrain/unit/objective editing, and replay screens. The application suite also exercised actual viewport pointer input for editor selection and terrain dragging, numeric property changes, Save As/name retention, custom browser discovery, malformed JSON handling, and auto-save exclusion during unconfirmed movement.

Replay tests serialize the history through JSON before playback, compare the complete resulting world state, check exact integer attack rolls, seek back to the initial state, step forward, jump to intermediate indices, and reject arbitrary object-property deltas. They include damage, casualty removal, objective movement, phase changes, undo and redo. Version-1 saves were loaded from a different active scenario and migrated without falsely claiming their incomplete histories are replayable.

Windows release exports launched natively from an isolated folder containing the executable and its WebRTC DLL. The packaged smoke check returned **PASS** after exercising bundled assets, game save/load, custom editor placement and scenario persistence, scenario reconstruction, and replayed movement. Screenshots confirmed the board/editor/menu at 1280×800. The executable embeds its resource pack and does not depend on the editor or repository files.

Nineteen signaling/probe tests pass: the original nine plus fixed expected TURN HMAC, token parsing/expiry, authenticated renewal and signaling reattachment, capability revocation, health/metrics privacy, strict ICE URL parsing and STUN/TURN wire/message-integrity checks. The expected HMAC was also independently checked with .NET cryptography. These are not evidence of a live coturn allocation. On this restricted Windows host run `node --test --test-isolation=none` in `server/signaling`; CI runs normal `npm test` on Linux.

Two real source processes passed WebRTC and ENet match smoke tests. Two standalone Windows release processes also passed WebRTC using the release GDExtension DLL and NVIDIA OpenGL. Tests cover room codes, SDP/ICE, lobby/scenario synchronization, both armies' deployment, confirmed movement, undo/redo, combat with identical individual dice, target-owner damage allocation, casualty removal, phase changes, equal final hashes, and clean guest disconnect. The latest harness also deliberately changes a guest wound and verifies that a requested host snapshot repairs the divergence. Signaling was deliberately closed after connection; gameplay continued. Latest recorded final hash: `9fc324b768987252a3d43715d411343f91ba2904121fc52cae6869c58a208a76`.

Compose configuration passed `docker-compose v2.39.4 ... config --quiet` with example environment values. **No Docker daemon/coturn runtime was available; TURN relay and the Docker image build were not tested locally.** WSL enumeration was denied by the environment. Public internet NAT traversal and remote WSS/TLS remain untested. CI includes the Docker build/configuration checks but has not been run remotely here.

The current milestone also tested stopping the signaling process during a local established match; gameplay continued and hashes matched. Both clients fetched fresh credential configuration with an acknowledgment while retaining the same gameplay peer. Added outbound application delay of 50/100/200 ms per peer passed full gameplay, actual casualty removal, dice/hash comparison and resync (roughly 110/210/410 ms application RTT). This is not OS packet-loss testing. Source/Windows runtime remains local; [PUBLIC_TEST_REPORT.md](PUBLIC_TEST_REPORT.md) lists all public-internet results as untested.

Linux and macOS exports completed successfully. Structural inspection identified Linux ELF64 x86-64 and a macOS app archive with universal x86-64/arm64 Mach-O slices. **No target-OS runtime validation was performed for Linux or macOS.** The macOS archive is unsigned/unnotarized.

The only recurring engine startup error in these checks is the host's certificate-store warning. No GDScript parser/runtime errors or failed checks remained in the final runs.

Reproduce with `godot --headless --path . --script res://tools/run_checks.gd`. Export procedures and platform requirements are in [BUILD.md](BUILD.md). Generated release checksums are in `builds/SHA256SUMS.txt`.


## 2026-10-16 content milestone

All eight Godot suites pass: **921 checks**, including **251 new content checks**.
All 19 signaling tests pass with `node --test --test-isolation=none` in this
restricted environment. Source ENet/WebRTC, graphical showcases and isolated
Windows packaged smoke passed. See [MILESTONE_REPORT.md](MILESTONE_REPORT.md) for
exact scope, assets, runtime evidence, totals and remaining limitations.


## 2026-10-16 external packs / performance milestone (0.5.0)

One final full Godot pass: **1,007 checks, zero failures**, including 54 mod and
10 cache-correctness checks. Focused development checks covered content, mods,
persistence/replay and performance invalidation. One baseline/optimized benchmark
pair and one minimal Windows package smoke were run. Backend/signaling and full
ENet/WebRTC/TURN gameplay matrices were not repeated. See
[MOD_PERFORMANCE_REPORT.md](MOD_PERFORMANCE_REPORT.md) for precise scope.
