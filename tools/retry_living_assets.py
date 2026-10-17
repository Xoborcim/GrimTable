"""One ordinary request per creator page; record manual downloads without bypasses."""
import json
import re
import urllib.request
from pathlib import Path

results = []
for name in ["animatedmech", "animatedtanks", "ultimatemonsters", "ultimatespacekit"]:
    url = f"https://quaternius.com/packs/{name}.html"
    try:
        html = urllib.request.urlopen(url, timeout=12).read().decode()
        links = re.findall(r'https://drive.google.com/[^\s<>"\']+', html)
        results.append(dict(source=url, creator="Quaternius", license="CC0-1.0",
                            license_badge_present="CC0" in html, download_links=links,
                            status="Manual creator download; no direct archive imported"))
    except Exception as error:
        results.append(dict(source=url, status=str(error)))
Path("docs/asset_retry_0100.json").write_text(json.dumps(results, indent=2))
print(json.dumps(results, indent=2))
