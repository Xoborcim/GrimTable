# Desktop builds

## Current Windows package: 0.10.0

`builds/windows/GrimTable.exe` and
`builds/GrimTable-0.10.0-windows-x86_64.zip` contain the Living Battlefield + AI
Opponent release. The standalone export passed 15 graphical AI workflow checks,
exit 0, from a folder without project sources. The complete Godot regression ran
once with 1,306 passing checks; only affected presentation checks followed fixes.
See [the milestone report](LIVING_AI_0100.md) for exact scope and limitations.

Repeat the focused workflow with isolated application data:

```sh
GrimTable.exe -- --smoke-living
```

It writes `living_smoke_result.txt` and screenshots in the test profile. Ship the
entire bundle including the native WebRTC DLL, licenses and release notes.
Linux/macOS artifacts were not refreshed for this release.

Use Godot **4.6.1 standard** with the matching **4.6.1.stable official export templates**. No .NET runtime is needed. Install templates through Godot's export-template manager, then run from the repository root:

```sh
godot --headless --path . --export-release "Windows Desktop" builds/windows/GrimTable.exe
godot --headless --path . --export-release "Linux Desktop" builds/linux/GrimTable.x86_64
godot --headless --path . --export-release "macOS" builds/macos/GrimTable.zip
godot --headless --path . --script res://tools/release_metadata.gd
```

Create destination folders first. Presets use portable relative paths, include JSON resources, and exclude tests, documentation, backend/infra sources, caches, and development artifacts. Windows/Linux embed the resource pack. Ship `GODOT_LICENSES.txt`, `licenses/`, and the exported native WebRTC library alongside each build. The Windows DLL is required even though the PCK is embedded. See [native dependency provenance](../addons/webrtc_native/UPSTREAM.md).

## Validated in this workspace

- All seven source check suites pass through `tools/run_checks.gd`. It creates an isolated validation project/application identity rather than using normal player saves.
- Main menu, scenario browser, editor, and replay screens rendered with the Compatibility renderer on Windows / NVIDIA OpenGL.
- The Windows release executable was copied to a folder containing no project files and launched directly, without the Godot editor. The opt-in packaged smoke test passed native demo loading, save/load, in-game placement, custom scenario persistence/reconstruction, and replayed movement.
- Two standalone Windows processes with the vendored release WebRTC DLL passed the room-code battle smoke test, including equal hashes and recorded combat, with signaling closed after negotiation. Local direct P2P and source ENet were tested. TURN relay was not runtime-tested.
- The packaged test rendered the battlefield, editor, and menu at 1280×800. Source screens were also inspected at 1440×900.
- Linux output was checked as a 64-bit little-endian x86-64 ELF executable. It was **not executed on Linux**.
- macOS output contains a `.app` bundle with a universal Mach-O executable containing x86-64 and arm64 slices. It was **not executed on macOS**.

To repeat the opt-in standalone Windows check:

```sh
GrimTable.exe -- --smoke-export
```

Use a separate test OS account/application-data environment for this export check. It creates named smoke-test files and screenshots under the test application's `user://`, deletes its temporary scenario/game files, and writes `packaged_smoke_result.txt` as PASS/FAIL. This flag is never used during normal play. The regular source test runner handles its own isolation.

## Remaining platform work

**Windows:** the build is unsigned. Resource patching/code signing is disabled so export does not depend on machine-specific external tools. Runtime gameplay is native and self-contained; normal OS graphics-driver requirements still apply.

**Linux:** validate on a real Linux desktop, including input, rendering, application-data access, custom scenario saves, replay, and window/fullscreen changes. Depending on how the executable is transferred, run `chmod +x GrimTable.x86_64` before launching. Cross-export and ELF checks do not establish runtime compatibility.

**macOS:** the archive is intentionally unsigned and unnotarized. Validate on both target architectures before release. Distribution through normal macOS security workflows requires configuring an appropriate Developer ID identity, signing the app, notarizing it, and stapling the notarization ticket using Apple tooling/credentials. Those steps were not performed here. ETC2/ASTC import support is enabled as required by the universal export; the application continues to use the Compatibility renderer.

## Portability and persistence

Application assets use case-consistent `res://` paths. Player data uses `user://`. Export presets contain no developer machine paths. Automated application checks audit production script/resource/scene references. Builds do not require the repository's original directory, editor caches, absolute asset locations, or a network connection.

The engine on this Windows host reports a certificate-store warning at startup. It has not blocked offline checks or local WS/WebRTC tests. Remote WSS certificate verification has not been runtime-tested here and has not been disabled. Online play needs a configured signaling service; offline play remains independent of networking.


## 0.4.0 content build

Windows was rebuilt for this milestone and passed isolated standalone
faction/combat/save/replay and two-client ENet smoke checks. Ship the additional
Kenney notices/asset registry under `builds/windows/licenses/assets`.
Linux/macOS artifacts remain prior-version packages and were not rebuilt.
See [MILESTONE_REPORT.md](MILESTONE_REPORT.md).


## 0.5.0 minimal Windows mod smoke

The Windows build was refreshed and tested from a folder without project sources.
Install `examples/mods/example_army` into the test profile's `user://mods/`, then run
`GrimTable.exe -- --smoke-content-packs`. This opt-in flag verifies launch, built-in
content, mod-folder creation, sample-pack loading and starting its scenario. It
writes `user://mod_packaged_smoke_result.txt` and a screenshot. Use isolated test
application data. The result was PASS / exit 0; no old gameplay matrix was rerun.
The example is also supplied under `builds/windows/examples/mods/`. Linux/macOS
packages remain unchanged. See [MODDING.md](MODDING.md).
