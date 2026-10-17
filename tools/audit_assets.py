"""Offline glTF audit: triangles, materials, embedded textures and SHA256.

Uses the standard library; never modifies third-party originals.
"""
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]


def audit(path):
    raw = path.read_bytes()
    size, kind = struct.unpack_from('<II', raw, 12)
    if raw[:4] != b'glTF' or kind != 0x4E4F534A:
        raise ValueError(f'Invalid GLB: {path}')
    doc = json.loads(raw[20:20 + size])
    textures = []
    binary_start = 20 + size + 8
    for image in doc.get('images', []):
        texture = {'mime_type': image.get('mimeType', 'external')}
        data = b''
        if 'bufferView' in image:
            view = doc['bufferViews'][image['bufferView']]
            offset = binary_start + view.get('byteOffset', 0)
            data = raw[offset:offset + view['byteLength']]
        elif 'uri' in image and not image['uri'].startswith('data:'):
            source = (path.parent / image['uri']).resolve()
            if not source.is_relative_to(ROOT / 'assets/third_party'):
                raise ValueError('Texture outside third-party tree')
            data = source.read_bytes()
            texture['path'] = source.relative_to(ROOT).as_posix()
        if data[:8] == b'\x89PNG\r\n\x1a\n':
            texture['width'], texture['height'] = struct.unpack_from('>II', data, 16)
        textures.append(texture)
    triangles = 0
    for mesh in doc.get('meshes', []):
        for primitive in mesh['primitives']:
            count = doc['accessors'][primitive['indices']]['count'] if 'indices' in primitive else doc['accessors'][primitive['attributes']['POSITION']]['count']
            if primitive.get('mode', 4) == 4:
                triangles += count // 3
    return {'path': path.relative_to(ROOT).as_posix(), 'sha256': hashlib.sha256(raw).hexdigest(), 'bytes': len(raw), 'triangles': triangles, 'materials': len(doc.get('materials', [])), 'images': len(doc.get('images', [])), 'textures': textures}


if __name__ == '__main__':
    result = [audit(p) for p in sorted((ROOT / 'assets/third_party').rglob('*.glb'))]
    target = ROOT / 'docs/asset_audit.json'
    target.write_text(json.dumps(result, indent=2) + '\n')
    print(f'{len(result)} GLBs; {sum(x["triangles"] for x in result)} source triangles; report: {target}')
