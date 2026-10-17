# Vendored native WebRTC

Official godotengine/webrtc-native **1.2.2-stable**, commit `62135fc`.
Godot 4.3+ GDExtension, tested here with Godot 4.6.1 Windows x86_64.

Source: https://github.com/godotengine/webrtc-native/releases/tag/1.2.2-stable

Archive: https://github.com/godotengine/webrtc-native/releases/download/1.2.2-stable/godot-extension-webrtc_native.zip

Archive SHA-256: `98e9446921740d995bd9ca1be48798dc3c2ceed51e044a25ce18b3cff11f56e5`

The archive contents are vendored unchanged beside this document, including all
upstream platform binaries, the extension descriptor, and third-party licenses.
No machine-wide plugin installation is required. Includes libdatachannel 0.24.6
and mbedTLS 3.6.7. See `LICENSE.*` for redistribution terms.

`tools/fetch_webrtc.mjs` reproduces the download with a checksum check; extract
the resulting ZIP at the project root to restore the upstream files.

Windows exports require the accompanying `libwebrtc_native.windows.template_release.x86_64.dll`.
Godot copies it alongside the executable. Distribute the entire export folder,
including `licenses/`, rather than the EXE alone. Linux and macOS libraries are
included upstream; neither platform has been runtime-tested in this milestone.
The export presets select the applicable library automatically.

The standard Godot API exposes connection and gathering states, but not selected
candidate statistics. GrimTable therefore displays route as unavailable. This
version's native configuration does not implement `iceTransportPolicy`; the
relay-only test flag filters non-relay SDP/trickle candidates on both clients.
