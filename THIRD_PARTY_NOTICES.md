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

## 0.11.0 original visual additions and private imports

`MonumentalTerrain`, `CinematicDie`, the dice impact synthesis, weathered surface
shader and all new scenario compositions are original GrimTable work under MIT.
No additional third-party archive or protected commercial miniature asset was
added for 0.11.0. Existing Kenney assets and font notices above still apply.
See [0.11.0 provenance](docs/ASSET_PROVENANCE_0110.md) for investigated sources.

The local Miniature Library does not grant redistribution rights. Its optional
creator/source/license/notes fields are user records, not license verification.
Private imported models remain in `user://miniatures/`; mod export does not
include that directory and multiplayer never sends those meshes.

## 0.12.0 original Blender art

The four source sculpts in `art/blender/`, their game-ready exports under
`assets/miniatures/` and `assets/terrain/gothic/`, original pigment/PBR atlases,
and the art tooling are original GrimTable work under MIT. No third-party mesh
foundation, scan, extracted game asset or protected faction icon was used.
Blender 5.0.1 and Godot 4.6.1 were used as creation/integration tools; they are not
redistributed as part of these source assets. Existing engine, Kenney, font and
WebRTC notices continue to apply. See `docs/MINIATURE_ART_0120.md` for provenance,
source organization and the limitations of the painted-style treatment.

## 0.13.0 original environment art

The eight editable sources under `art/blender/environment/`, their GLB exports
under `assets/terrain/environment/`, new ground/surface/vapor/wear shaders,
curated showcase layouts and environment authoring tools are original GrimTable
work under MIT. They reuse the original GrimTable pigment/PBR atlases. No new
third-party meshes, texture scans, restricted iconography or downloads were
introduced. Existing Kenney CC0, font, engine and WebRTC notices still apply.
See `docs/ENVIRONMENT_0130.md` and `art/ENVIRONMENT.md`.

## 0.13.1 original composition art

The nine editable cluster sources and surface-bake source under
`art/blender/environment/0131/`, their self-contained GLBs, original pigment/ORM
atlases, Cycles-baked normal/AO maps, authored floor/damage masks and map layouts
are original GrimTable MIT artwork. No third-party geometry, scan, reference
image, insignia or texture was copied into these assets. The physical diorama
references in `docs/environment/0131/REFERENCE_STUDY.md` informed composition
principles only. Existing engine, Kenney, font and WebRTC notices still apply.

## 0.13.2 original approach refinements

The authored approach records, shallow road-margin geometry and ground shader
refinements are original GrimTable MIT work. They reuse existing materials,
layout masks and surface bakes. No new third-party assets were introduced.

## 0.13.3 original baked finish

The derived Blender low/high sources in `art/blender/baked_0133/`, new unique
bake UVs and surface maps in `assets/materials/baked_0133/`, paint-region data,
finishing shaders and art tools are original GrimTable work under MIT. They
derive exclusively from the existing original GrimTable sources and analytic
surface recipes. No downloaded texture, scan, proprietary miniature, protected
faction insignia or reference image was added. Existing engine, font, Kenney
and WebRTC licenses remain applicable. Blender and Godot were creation tools;
their executables are not included in these art-source files.

## 0.14.0 original Miniature Workshop

The Workshop code, fitted Legion component adaptations, new accessory/detail
geometry, categorical region/island masks, original stencil markings and paint
scheme names are GrimTable MIT work. They derive from existing original
GrimTable source artwork. No proprietary models, hobby paint branding or faction
iconography were added. User-imported models and personal paint collections stay
in local user data and are not included in this repository or game package.
