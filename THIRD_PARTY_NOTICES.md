# Third-party notices

Original GrimTable code, documentation and artwork are licensed under the root
[MIT license](LICENSE). The following third-party material retains its original
copyrights and licenses. The root license does not replace these notices.

## Assets and fonts

| Material | Creator / source | License | Notice and inventory |
|---|---|---|---|
| Space Station Kit | [Kenney](https://kenney.nl/assets/space-station-kit) | CC0-1.0 | `assets/third_party/kenney/terrain/space-station-kit/License.txt` |
| Modular Space Kit | [Kenney](https://kenney.nl/assets/modular-space-kit) | CC0-1.0 | `assets/third_party/kenney/terrain/modular-space-kit/License.txt` |
| Barlow Regular and SemiBold | [The Barlow Project Authors](https://github.com/jpt/barlow), distributed through [Google Fonts](https://github.com/google/fonts/tree/main/ofl/barlow) | OFL-1.1 | `assets/third_party/fonts/barlow/ofl.txt` |

`assets/third_party/assets.json` records archive URLs, retrieval dates and SHA256
checksums for included assets. `docs/ASSETS.md` explains the import history.
Unavailable candidate models listed there are not included in the repository.
Keep font licenses with redistributed fonts. CC0 asset credits are preserved
for provenance. Original GrimTable models and their procedural source are MIT.

## Native WebRTC extension

The unmodified binaries in `addons/webrtc_native/` come from the official
[godotengine/webrtc-native 1.2.2-stable release](https://github.com/godotengine/webrtc-native/releases/tag/1.2.2-stable).
`addons/webrtc_native/UPSTREAM.md` records the archive checksum, version and build
provenance. Complete bundled license texts are preserved in that directory:

| Component | Bundled license file | License |
|---|---|---|
| webrtc-native | `LICENSE.webrtc-native` | MIT |
| libdatachannel | `LICENSE.libdatachannel` | MPL-2.0 |
| libjuice | `LICENSE.libjuice` | MPL-2.0 |
| mbedTLS | `LICENSE.mbedtls` | Apache-2.0 OR GPL-2.0-or-later |
| plog | `LICENSE.plog` | MIT |
| usrsctp | `LICENSE.usrsctp` | BSD terms in bundled notice |
| libsrtp | `LICENSE.libsrtp` | BSD terms in bundled notice |

For this MIT distribution, mbedTLS is used under its Apache-2.0 alternative.
Read the preserved notices for component-specific conditions and copyrights.

Source availability for the MPL components: the extension's
[versioned source and build instructions](https://github.com/godotengine/webrtc-native/tree/1.2.2-stable)
identify its dependency revisions. The shipped release documents libdatachannel
0.24.6, whose source is available at
[libdatachannel v0.24.6](https://github.com/paullouisageneau/libdatachannel/tree/v0.24.6).
Its `deps/` submodules pin dependency sources, including
[libjuice](https://github.com/paullouisageneau/libdatachannel/tree/v0.24.6/deps/libjuice).
Obtain the pinned revisions and retain these MPL notices when redistributing
the binaries. Modifications to covered MPL files must remain available under
MPL-2.0 when distributed. The bundled binaries have not been modified here.

Do not interpret the project's MIT license as replacing MPL source-availability
requirements. If rebuilding the extension with different dependencies, record
the new revisions, build instructions and license notices before distributing it.

## Engine and signaling dependency

[Godot Engine](https://godotengine.org/license/) is MIT licensed and includes its
own third-party components. Exported packages include `GODOT_LICENSES.txt`,
generated from the engine's license and component notices. The engine binary
is not vendored in this source repository.

The signaling server declares `ws` 8.22.0 under MIT in
`server/signaling/package-lock.json`. Its source and license are available from
[websockets/ws](https://github.com/websockets/ws). `npm ci` installs that package
with its upstream license; `node_modules/` is excluded from source control.

## Desktop redistribution

Ship the original GrimTable `LICENSE`, this notices file, `GODOT_LICENSES.txt`,
the native dependency notices, the asset registry and original asset/font license
files with any desktop build containing those components. The Windows bundle
uses a `licenses/` folder for component notices. Keep the native WebRTC DLL beside
the executable. Externally installed content packs retain their authors' licenses
and are not automatically covered by MIT.
