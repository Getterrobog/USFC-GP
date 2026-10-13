# Original public-archive metadata

Subdirectories contain `SHA256(request URL).gz` response bodies and matching
`.json` request manifests. Decompress `.gz` with `gzip -dc` or Python `gzip`;
the response format depends on the directory:

| Directory | Source / format |
| --- | --- |
| `taxonomy/` | ENA exact any-name taxonomy lookup, JSON |
| `runs/` | ENA public genomic run search, TSV, `limit=0` |
| `assemblies/` | NCBI Datasets genome reports, JSON with pagination |
| `samples/` | ENA BioSample metadata, XML, batches of 80 accessions |
| `studies/` | ENA project/study descriptions and publication links, XML |
| `geome/` | GEOME exact-species sample queries with related Event/Tissue metadata, JSON (HTTP payload itself may be gzip encoded) |
| `location_publications/` | Original repository CSV/PDF, Europe PMC full-text XML and supplement ZIP responses |

Every manifest records the complete URL, UTC retrieval time, HTTP status,
uncompressed byte count and uncompressed-content SHA256. The hash in the file
name identifies the URL, not the response bytes. `Output/Genomics/queries.csv`
indexes the requests used by the latest successful build; obsolete cached
requests may remain after changes to batching or queries.

These are evidence snapshots. Do not manually edit them. Normal builds are
offline and reject changed/corrupt response bytes; `--download` retrieves cache
misses and `--download --refresh` deliberately replaces ENA/NCBI snapshots.
The location helper retains pinned publication/GEOME snapshots. For GEOME, the
manifest hash covers the original HTTP payload after removing the cache's outer
gzip wrapper; remove a second gzip layer to inspect JSON when present.
`Output/Genomics/location_queries.csv` indexes location-source requests. No read files
are downloaded. The helper retries transient failures and limits concurrency.
