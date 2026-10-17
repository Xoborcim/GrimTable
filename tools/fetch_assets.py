"""Fetch only pinned, license-reviewed public downloads. Never runs during gameplay.

Use --check to audit installed files without network access. HTTP errors, HTML
quota pages and checksum mismatches are failures; no alternate endpoints are tried.
"""
import argparse
import hashlib
import json
from pathlib import Path
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    registry = json.loads((ROOT / 'assets/third_party/assets.json').read_text())
    failed = 0
    for asset in registry['assets']:
        if asset['status'] != 'included':
            print(f"MANUAL {asset['name']}: {asset['source']}")
            continue
        if asset['license'] not in ('CC0-1.0', 'Public-Domain', 'OFL-1.1') or not asset.get('license_verified'):
            raise ValueError('Unverified redistribution license')
        for item in asset['files']:
            path = (ROOT / item['path']).resolve()
            if not path.is_relative_to(ROOT / 'assets/third_party'):
                raise ValueError('Destination outside third_party')
            try:
                if not args.check and item.get('download'):
                    data = urllib.request.urlopen(item['download'], timeout=45).read()
                    if hashlib.sha256(data).hexdigest() != item['sha256']:
                        raise ValueError('Checksum mismatch (or download restriction page)')
                    path.parent.mkdir(parents=True, exist_ok=True)
                    temp = path.with_suffix(path.suffix + '.tmp')
                    temp.write_bytes(data)
                    temp.replace(path)
                if hashlib.sha256(path.read_bytes()).hexdigest() != item['sha256']:
                    raise ValueError('Installed checksum mismatch')
                print('OK', item['path'])
                if not args.check and asset.get('extracted_files') and path.suffix == '.zip':
                    with zipfile.ZipFile(path) as archive:
                        for entry in asset['extracted_files']:
                            target = (path.parent / entry['archive_path']).resolve()
                            if not target.is_relative_to(path.parent):
                                raise ValueError('Unsafe archive destination')
                            data = archive.read(entry['archive_path'])
                            if hashlib.sha256(data).hexdigest() != entry['sha256']:
                                raise ValueError('Extracted checksum mismatch')
                            target.parent.mkdir(parents=True, exist_ok=True)
                            target.write_bytes(data)
                for entry in asset.get('extracted_files', []):
                    target = path.parent / entry['archive_path']
                    if hashlib.sha256(target.read_bytes()).hexdigest() != entry['sha256']:
                        raise ValueError('Extracted model/texture checksum mismatch')
            except Exception as error:
                failed += 1
                print('FAILED', asset['name'], error)
    return bool(failed)


if __name__ == '__main__':
    raise SystemExit(main())
