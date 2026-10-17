"""Check the staged Git snapshot before publishing; never print secret values."""
import json
import hashlib
from pathlib import Path, PurePosixPath
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
GIT = ['git', '-c', f'safe.directory={ROOT.as_posix()}']
entries = subprocess.check_output(GIT + ['ls-files', '--stage', '-z'], cwd=ROOT).decode().split('\0')
entries = [entry.split('\t', 1) for entry in entries if entry]
paths = [entry[1] for entry in entries]
oids = [entry[0].split()[1] for entry in entries]
blobs = subprocess.check_output(GIT + ['cat-file', '--batch'], input=('\n'.join(oids)+'\n').encode(), cwd=ROOT)
cursor = 0
hashes = {}
issues = []
total = 0
largest = []
patterns = {
    'private key': re.compile(rb'-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----'),
    'GitHub token': re.compile(rb'(?<![A-Za-z0-9_])(?:gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{70,})'),
    'AWS access key': re.compile(rb'(?<![A-Z0-9])(?:AKIA|ASIA)[A-Z0-9]{16}(?![A-Z0-9])'),
}
for relative in paths:
    parts = PurePosixPath(relative).parts
    name = parts[-1]
    if any(p in {'.runtime', '.godot', '.aws', '.ssh', '.codex', '.agents', 'node_modules', 'builds'} for p in parts):
        issues.append({'path': relative, 'reason': 'excluded runtime/private directory staged'})
    if name == '.env' or (name.startswith('.env.') and name != '.env.example') or name.endswith(('.pem', '.key', '.p12', '.pfx')):
        issues.append({'path': relative, 'reason': 'credential/environment filename staged'})
    # Audit the exact staged blob, rather than a possibly different working copy.
    end = blobs.index(b'\n', cursor)
    size = int(blobs[cursor:end].split()[-1])
    data = blobs[end+1:end+1+size]
    cursor = end + 1 + size + 1
    hashes[relative] = hashlib.sha256(data).hexdigest()
    total += len(data)
    largest.append((len(data), relative))
    if len(data) >= 100 * 1024 * 1024:
        issues.append({'path': relative, 'reason': 'exceeds GitHub regular file limit'})
    if b'\0' not in data[:8192]:
        for description, pattern in patterns.items():
            if pattern.search(data):
                issues.append({'path': relative, 'reason': description + ' pattern'})

for required in ['LICENSE', 'THIRD_PARTY_NOTICES.md', 'CONTRIBUTING.md', 'project.godot']:
    if required not in paths:
        issues.append({'path': required, 'reason': 'required project/license file missing'})
registry = json.loads((ROOT / 'assets/third_party/assets.json').read_text())
for asset in registry['assets']:
    if asset['status'] != 'included':
        continue
    expected = [(item['path'], item['sha256']) for item in asset['files']]
    for item in asset.get('extracted_files', []):
        path = PurePosixPath(asset['files'][0]['path']).parent / item['archive_path']
        expected.append((str(path), item['sha256']))
    for path, digest in expected:
        if hashes.get(path) != digest:
            issues.append({'path': path, 'reason': 'staged third-party bytes differ from licensed registry checksum'})
report = {'files': len(paths), 'total_bytes': total, 'largest_files': sorted(largest, reverse=True)[:5],
          'issues': issues, 'scope': 'staged paths, size and high-confidence credential patterns; not a legal or exhaustive secret audit'}
directory = ROOT / '.runtime'
directory.mkdir(exist_ok=True)
(directory / 'github-backup-audit.json').write_text(json.dumps(report, indent=2))
print(json.dumps(report, indent=2))
raise SystemExit(1 if issues else 0)
