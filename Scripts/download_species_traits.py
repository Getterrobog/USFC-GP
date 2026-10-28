#!/usr/bin/env python3
"""Archive explicitly configured public trait sources; never requires IUCN tokens."""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


def acquire(source):
    path = ROOT / source['archive_path']
    sidecar = path.with_suffix(path.suffix + '.metadata.json')
    if path.exists() and sidecar.exists():
        meta = json.loads(sidecar.read_text())
        if hashlib.sha256(path.read_bytes()).hexdigest() != meta['sha256'] or meta['requested_url'] != source['url']:
            raise ValueError(f'Cached source changed: {path}')
        return 'verified cache'
    request = urllib.request.Request(source['url'], headers={'User-Agent': 'USFC-GP research trait acquisition'})
    with urllib.request.urlopen(request, timeout=45) as response:
        content = response.read()
        meta = dict(requested_url=source['url'], resolved_url=response.url,
            retrieved_at=datetime.now(timezone.utc).isoformat(),
            content_type=response.headers.get('Content-Type'), bytes=len(content),
            sha256=hashlib.sha256(content).hexdigest())
    if source.get('expected_md5') and hashlib.md5(content).hexdigest() != source['expected_md5']:
        raise ValueError('Published source MD5 mismatch: ' + source['source_id'])
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)
    sidecar.write_text(json.dumps(meta, indent=2) + '\n')
    return 'downloaded'


if __name__ == '__main__':
    failures = []
    for source in json.loads((ROOT / 'config/species_traits_sources.json').read_text()):
        if source.get('acquisition', 'download') != 'download':
            continue
        try:
            print(source['source_id'], acquire(source), flush=True)
        except Exception as exc:
            failures.append(dict(source_id=source['source_id'], error=str(exc)))
            print(source['source_id'], str(exc), flush=True)
    if failures:
        (ROOT / 'Data/SpeciesTraits/acquisition_failures.json').write_text(json.dumps(failures, indent=2) + '\n')
        raise SystemExit(1)
