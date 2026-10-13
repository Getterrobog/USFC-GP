# Public genomic metadata inputs

This directory holds **metadata, not sequencing reads or genome FASTAs**, for the
80 species in `Output/SpeciesSelection/species_investigation_queue.csv`.
Start with [the inventory viewer](../../Output/Genomics/index.html) or
[output documentation](../../Output/Genomics/README.md).

- [raw/](raw/README.md): compressed, original ENA/NCBI responses and request manifests.
- [normalized/](normalized/README.md): lossless tabular transport of the relevant
  archive fields, prior to scientific classification and screening in R.

Explicitly retrieve missing public metadata and build the inventory:

```bash
Rscript Scripts/build_genomics_inventory.R --download
```

Omit `--download` to rebuild entirely offline. Add `--refresh` with `--download`
to replace cached responses with a newer snapshot. Snapshot updates can change
archive counts; retain the older committed version when comparing releases.
The ordinary rebuild verifies cached response SHA256s.

Python 3's standard library handles HTTP, XML/JSON, compression and SQLite.
All scientific classification, date/coordinate interpretation, eligibility,
aggregation and reporting are implemented in base R. No additional R packages
or API credentials are required. See [methods](../../docs/genomics_inventory.md).
