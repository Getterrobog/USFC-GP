#!/usr/bin/env python3
"""Explicit acquisition of configured evidence sources; offline builds never download."""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
import urllib.request
from concurrent.futures import ThreadPoolExecutor

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'Data/LifeHistorySupplement'

def acquire(source):
    path = ROOT / source['archive_path']
    meta_path = path.with_suffix(path.suffix + '.metadata.json')
    if path.exists() and meta_path.exists():
        meta = json.loads(meta_path.read_text())
        if hashlib.sha256(path.read_bytes()).hexdigest() != meta['sha256']:
            raise ValueError(f'Cached source checksum mismatch: {path}')
        if meta['requested_url'] != source['url']:
            raise ValueError(f'Cached URL mismatch: {path}')
        return source['source_id'], 'verified cache'
    request = urllib.request.Request(source['url'], headers={'User-Agent': 'USFC-GP research evidence acquisition'})
    with urllib.request.urlopen(request, timeout=45) as response:
        content = response.read()
        if path.suffix == '.pdf' and not content.startswith(b'%PDF'):
            raise ValueError(f'Not a PDF: {source["url"]}')
        meta = dict(requested_url=source['url'], resolved_url=response.url,
                    retrieved_at=datetime.now(timezone.utc).isoformat(),
                    sha256=hashlib.sha256(content).hexdigest(), bytes=len(content),
                    content_type=response.headers.get('Content-Type'),
                    last_modified=response.headers.get('Last-Modified'))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)
    meta_path.write_text(json.dumps(meta, indent=2) + '\n')
    return source['source_id'], 'downloaded'

def main():
    sources = json.loads((ROOT / 'config/life_history_supplement_sources.json').read_text())
    failures = []
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = [(s, pool.submit(acquire, s)) for s in sources if s.get('acquisition') == 'download']
        for source, future in futures:
            try:
                print(*future.result(), flush=True)
            except Exception as exc:
                failures.append(dict(source_id=source['source_id'], url=source['url'], error=str(exc)))
                print(source['source_id'], str(exc), flush=True)
    (BASE / 'acquisition_failures.json').write_text(json.dumps(failures, indent=2) + '\n')
    if failures:
        raise SystemExit(1)

if __name__ == '__main__':
    main()
