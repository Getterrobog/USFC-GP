#!/usr/bin/env python3
"""Explicit network step for a pinned FishBase release used by rfishbase.

Existing files are reused only when their recorded SHA-256 matches. No live
taxonomy cleaning is performed. Run the separate builder offline after this step.
"""
import concurrent.futures
import datetime
import hashlib
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
VERSION = "26.06"
TABLES = ("species", "estimate", "ecology", "maturity", "popgrowth", "reproduc",
          "fecundity", "stocks", "larvae", "larvdyn", "synonyms", "refrens", "spawning", "matrix")
# Public S3 origin also used by rfishbase for listing these objects. The
# data.source.coop convenience endpoint returned HTTP 403 in this environment.
BASE = f"https://s3.us-west-2.amazonaws.com/us-west-2.opendata.source.coop/cboettig/fishbase/fb/v{VERSION}/parquet"


def download_all():
    directory = ROOT / "Data/LifeHistory/raw" / f"v{VERSION}"
    directory.mkdir(parents=True, exist_ok=True)
    manifest_path = directory / "download_manifest.json"
    prior = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}

    def fetch(table):
        path = directory / f"{table}.parquet"
        if table in prior and path.exists():
            if hashlib.sha256(path.read_bytes()).hexdigest() != prior[table]["sha256"]:
                raise ValueError(f"Cached file checksum mismatch: {path}")
            return table, prior[table]
        url = f"{BASE}/{table}.parquet"
        with urllib.request.urlopen(url, timeout=90) as response:
            content = response.read()
            modified = response.headers.get("Last-Modified", "")
        if not content.startswith(b"PAR1") or not content.endswith(b"PAR1"):
            raise ValueError(f"Invalid parquet response: {url}")
        path.write_bytes(content)
        return table, dict(url=url, version=VERSION, bytes=len(content),
            sha256=hashlib.sha256(content).hexdigest(),
            retrieved_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
            last_modified_http=modified)

    manifest = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        for table, record in executor.map(fetch, TABLES):
            manifest[table] = record
            print(f"{table}: {record['bytes']} bytes", flush=True)
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    download_all()
