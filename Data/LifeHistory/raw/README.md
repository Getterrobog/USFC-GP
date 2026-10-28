# Versioned FishBase downloads

Release directories such as `v26.06/` contain cached source `.parquet` tables.
Parquet is a tabular storage format; these are not map images or museum-lot CSVs.
Use the release's `download_manifest.json` to identify each source and verify its
contents. An incomplete download may contain tables before the manifest is written.

The explicit network step is:

```bash
# Run from the repository root.
python3 Scripts/download_fishbase_traits.py
```

The pinned release and table list are defined in that script. Existing files are
reused only when they match the previously recorded SHA-256. Do not hand-edit the
cached tables or treat their modification time as the source release date.

See the [life-history data guide](../README.md) for how these sources relate to the
project. The atlas and historical screening workflows do not require this download.
