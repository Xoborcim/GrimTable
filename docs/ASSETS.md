# Asset provenance and import policy

Reviewed/retrieved: **2026-10-17**. Miniature/terrain assets remain restricted to
verified CC0 or Public Domain. The explicitly requested open-font pass adds
unmodified Barlow under SIL Open Font License 1.1, with its copyright/license bundled. No copyrighted commercial setting
content, ripped meshes, logos or insignia were used. Network downloads are
explicit development tools; gameplay never downloads art.

The exact machine-readable inventory, source URLs, retrieval dates, original
archive SHA256 and per-extracted-file SHA256 are in
[assets.json](../assets/third_party/assets.json). Third-party originals remain
under `assets/third_party`; authored scenes and attachments are under
`assets/grimtable` and `scripts/content/demo_visual.gd`.

## Included third-party content

| Asset | Creator | Verified source/license | Retrieved | GLBs |
|---|---|---|---|---|
| Space Station Kit 1.0 | Kenney | [Source](https://kenney.nl/assets/space-station-kit), [CC0-1.0](https://creativecommons.org/publicdomain/zero/1.0/) | 2026-10-16 | 97 |
| Modular Space Kit 1.0 | Kenney | [Source](https://kenney.nl/assets/modular-space-kit), [CC0-1.0](https://creativecommons.org/publicdomain/zero/1.0/) | 2026-10-16 | 40 |

Each archive contains a `License.txt` confirming CC0 and the creator. Originals
are preserved as `original.zip`. GLB files and bundled license/readme text were
extracted unchanged. Materials are in the GLBs; each kit references its bundled shared colormap PNG. The showcase
scenarios currently use the Space Station Kit `container-wide` through an
original normalized wrapper. Remaining GLBs are available content-library
sources, not automatically placed terrain. No high-poly collision was generated.

## Unit and weapon downloads unavailable

Poly Pizza page/license reads were available through the web tool for all listed
candidates except Robot Enemy. Direct site retrieval returned HTTP 403. The
creator's official [Ultimate Space Kit](https://quaternius.com/packs/ultimatespacekit.html)
page confirms CC0 and links a public Google Drive folder. Its Enemy Small and
License.txt download requests returned quota-exceeded HTML instead of assets.
Those responses were rejected; no restrictions were bypassed. No Quaternius
unit or weapon mesh is included. Robot Enemy remains unverified because its
page timed out; historical license assumptions were not treated as verification.

| Candidate | Creator | Source | License verification / result |
|---|---|---|---|
| Character Soldier | Quaternius | [Source](https://poly.pizza/m/PpLF4rt4ah) | CC0-1.0 confirmed on page; download unavailable |
| SWAT | Quaternius | [Source](https://poly.pizza/m/Btfn3G5Xv4) | CC0-1.0 confirmed on page; download unavailable |
| Mech | Quaternius | [Source](https://poly.pizza/m/4UvIHxnoSR) | CC0-1.0 confirmed on page; download unavailable |
| Tank | Quaternius | [Source](https://poly.pizza/m/jWS1CLA0RO) | CC0-1.0 confirmed on page; download unavailable |
| Orc | Quaternius | [Source](https://poly.pizza/m/5vO2YJsPEf) | CC0-1.0 confirmed on page; download unavailable |
| Enemy Small | Quaternius | [Source](https://poly.pizza/m/4LjT020LQh) | CC0-1.0 confirmed on page; download unavailable |
| Enemy Large | Quaternius | [Source](https://poly.pizza/m/UgBmRVnQ9h) | CC0-1.0 confirmed on page; download unavailable |
| Alien | Quaternius | [Source](https://poly.pizza/m/sUTLXji0aL) | CC0-1.0 confirmed on page; download unavailable |
| Robot Enemy | Quaternius | [Source](https://poly.pizza/m/1gNo5ezvmr) | Unverified: page timed out; not imported |
| Enemy Flying | Quaternius | [Source](https://poly.pizza/m/kzpT6fNmM5) | CC0-1.0 confirmed on page; download unavailable |
| Sci-Fi Modular Gun Pack | Quaternius | [Source](https://poly.pizza/bundle/Sci-Fi-Modular-Gun-Pack-TbRddR9Fsu) | CC0-1.0 confirmed on page; download unavailable |

To obtain a unit manually, open its source page, verify the current license,
use the provider's download UI, and retain its license notice. Stop if access
is restricted or licensing is unclear. Place unmodified originals in the
appropriate `assets/third_party/quaternius/{characters,creatures,vehicles,weapons}`
folder, then add a registry entry with source, creator, license, verification
and retrieval date, file paths and SHA256. Do not label a fallback as imported art.

## Reproducible pipeline

1. `python tools/fetch_assets.py --check` verifies included archive/model hashes
   without network access. `python tools/fetch_assets.py` retrieves only pinned,
   reviewed downloads and extracts only manifest-listed files. Errors/checksum
   mismatches fail without replacing valid files. Unavailable candidates are
   reported with manual source links; no alternate download APIs are attempted.
2. Open/import the project in Godot 4.6.1, or run `godot --headless --editor --quit`.
3. Prepare an art-only wrapper using the license/checksum-gated tool:

   ```sh
   godot --headless --path . --script res://tools/import_visual.gd -- --asset=kenney_space_station_kit "--file=res://assets/third_party/kenney/terrain/space-station-kit/Models/GLB format/container-wide.glb" --id=my_cargo_visual --height=1.8 --yaw=0
   ```

   This centers/floors visual bounds and applies the chosen visual height/yaw.
   Existing authored output is never overwritten. Preview the result, then set
   a unit's `model_scene` or terrain `visual_scene`. Configure the gameplay base,
   height and LOS explicitly in the profile; mesh bounds never define rules.
   The tool was run successfully to produce `normalized_cargo.tscn`.
4. `python tools/audit_assets.py` writes triangle/material/texture counts and
   source hashes to [asset_audit.json](asset_audit.json). Run the Godot checks
   and inspect a rendered scenario before shipping.

## Performance audit

137 imported GLBs contain 102,512 source triangles total. Maximum per asset: 10,880; maximum materials per asset: 1. Shared PNG colormap dimensions: 512 x 512.
Godot loaded every GLB in the content check suite. Resources from imported
PackedScenes are shared. Original substitute miniatures share box meshes and
palette materials; gameplay uses one primitive collider per miniature. The
source GLB total is not the scene's rendered triangle count. No large-army FPS
benchmark was performed; no destructive optimization was justified.

## Project licensing

The owner selected MIT on 2026-10-17. The root [LICENSE](../LICENSE) covers
original code, documentation and artwork. Existing third-party assets and fonts
retain their own licenses. See [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).
Older milestone notes below record the status at their respective release dates.


## Official miniature retry ? 0.5.0

All six creator-owned sources below were rechecked on 2026-10-16 and explicitly
link CC0-1.0. No miniature bytes were imported. Every authored GrimTable visual
is now recorded as its profile's permanent `fallback_model_scene`. Preferred
visuals remain independent of gameplay bases/stats and may fail safely.

| Official pack | Verified source | Retrieval result |
|---|---|---|
| Animated Mech Pack | [Quaternius](https://quaternius.com/packs/animatedmech.html) | Reached official model folders; George.gltf / Tank.obj / Alien.gltf public download requests returned quota/restriction HTML. Stopped without alternate endpoints. |
| Animated Tanks Pack | [Quaternius](https://quaternius.com/packs/animatedtanks.html) | Reached official model folders; George.gltf / Tank.obj / Alien.gltf public download requests returned quota/restriction HTML. Stopped without alternate endpoints. |
| Ultimate Monsters Pack | [Quaternius](https://quaternius.com/packs/ultimatemonsters.html) | Reached official model folders; George.gltf / Tank.obj / Alien.gltf public download requests returned quota/restriction HTML. Stopped without alternate endpoints. |
| Sci-Fi Essentials Kit | [Quaternius](https://quaternius.com/packs/scifiessentialskit.html) | No stable direct public file link; manual creator download needed. |
| Sci-Fi Modular Gun Pack | [Quaternius](https://quaternius.com/packs/scifimodularguns.html) | No directly retrievable GLB/glTF/archive at linked public folder level; manual download needed. |
| Ultimate Modular Men / Characters Pack | [Quaternius](https://quaternius.com/packs/ultimatemodularcharacters.html) | No directly retrievable GLB/glTF/archive at linked public folder level; manual download needed. |

Manual steps: open the creator page, verify the current CC0 notice, choose its
public Download control, and use the provider's normal download interface.
For mechs: Flat Colors ? glTF. For tanks: OBJ (with matching MTL) or FBX.
For monsters: Big/Flying ? glTF, including the referenced atlas. For the other
packs, use the creator-linked interactive download. Stop if quota/access limits
remain. Do not switch endpoints to evade them. Retain the license notice and
record retrieved files/checksums before using the existing import pipeline.

Replacement outcome: **none**. Legion Walker/Tank, Synthetic Walker/Destroyer,
Swarm Brood/Winged Beast, infantry and weapons retain their original artwork.
External download availability does not block the mod/performance milestone.


## 0.6.0 presentation assets

No new third-party assets were downloaded. The showcase reuses the registered
Kenney Space Station Kit containers, pipes and rocks as decorative objects.
Original sources and licenses remain unchanged. New faction paint, authored
armor/carapace details, board shader, base/selection geometry and the battlefield
menu render are GrimTable-authored. `docs/grimtable.png` is an in-engine capture;
`assets/grimtable/materials/menu_battlefield.png` is an original battlefield render.
Small decorative props have no gameplay collision and cast no dynamic shadows.


0.8.0 adds original procedural terrain wear/ground treatment, objective beacons,
rounded authored miniature details and UI indicators. It imports no new
third-party models, textures, fonts or audio. Existing third-party license records
and the owner's project-license decision remain unchanged.


## 0.9.0 UI font and authored presentation

Barlow Regular and SemiBold, by Jeremy Tribby / The Barlow Project Authors,
were retrieved on 2026-10-17 from the official Google Fonts repository after
[verifying OFL 1.1](https://github.com/google/fonts/blob/main/ofl/barlow/OFL.txt).
Original project: https://github.com/jpt/barlow. The unmodified TTFs are in
`assets/third_party/fonts/barlow/`, with the complete `ofl.txt`. Download URLs and
SHA256 values for both fonts and their license are recorded in `assets.json`.
The Windows distribution also includes `licenses/fonts/barlow/ofl.txt`.

All new SVG icons, chamfer/organic sculpts, shaders, holograms, terrain dressing,
table surround and menu composition are original GrimTable work. No additional
third-party miniature, terrain, texture, audio or promotional artwork was imported.
The owner subsequently selected MIT; see [LICENSING_DECISION.md](LICENSING_DECISION.md).
