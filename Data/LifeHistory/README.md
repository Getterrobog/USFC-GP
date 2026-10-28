# Archived life-history source data

`raw/v26.06/` contains 14 unmodified FishBase Parquet tables downloaded on
12 October 2026. `download_manifest.json` records exact URLs, retrieval times,
HTTP modification dates, byte counts and SHA-256 hashes.

Source: FishBase team, **FishBase release 26.06**, Parquet snapshots curated by
Carl Boettiger at [Source Cooperative](https://source.coop/cboettig/fishbase).
License: [Creative Commons Attribution–NonCommercial 4.0](https://creativecommons.org/licenses/by-nc/4.0/),
as stated by the provider. Preserve this attribution and license when sharing the
data and derived FishBase extracts. Local code/documentation do not alter the
source-data license. Version 26.06 is the provider's release label, not a guaranteed
cutoff date for individual records.

Keep these files unchanged. An explicit network step is available as
`python3 Scripts/download_fishbase_traits.py`; the separate
`python3 Scripts/build_life_history.py` verifies the cache and works offline.
See [methods and limitations](../../docs/life_history_workflow.md).
