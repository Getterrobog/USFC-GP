# Public genomic data inventory for the 80 atlas species

Open **[index.html](index.html)** for the searchable species summary and expandable
assembly/study records. It works locally without a server. Filter by species,
WGS sample count, annotated assemblies, annotated references, labeled low-coverage
sequencing and mapping candidates. Read [methods and field definitions](../../docs/genomics_inventory.md)
before interpreting sample counts as contemporary fish.

Open **[maps.html](maps.html)** for the separate genomic geographic viewer.
It works offline, using embedded records and coastlines. The default view shows
regional mapping candidates; **All WGS records · review flags included** exposes
the wider inventory, including duplicate/pool/captive and undated records.
The historical atlas pages link to these maps and display genomic summary cards
and availability filters without combining genomic accessions with museum counts.

## Geographic viewer

- Species/common-name, order, family, life-stage, collection-year and genomic
  availability controls refine the view. Unknown genomic stages remain unknown.
- Every map uses 2° cells and the fixed 100–50°W, 5–60°N extent. **Worldwide** changes
  all maps together to −180–180°, −90–90°; years and species never trigger cropping.
- Each species starts with all selected years. Choose a year, use the arrows,
  click a timeline bar or **Play years**. Playback cycles dated sampled years in
  the browser; it does not generate another set of GIFs/PNGs. Gaps remain visible
  on the chronological timeline, and undated records have a separate static frame.
- Cell colors count BioSample accessions on a log scale, fixed across displayed
  years within each species/filter selection. Hatching denotes approximate
  positions, including publication-reported shared sampling sites.
- Click a cell (or use keyboard focus + Enter) for accession, study, collection
  year, locality, spatial scope, source links, evidence IDs and review flags.
  **Grid cells: years and counts** lists year (accessions) for each cell.
- **Download SVG** saves the selected geographic map with year, count and legend.
  All plotting is local; no map tiles, remote JavaScript or server are required.

The summary distinguishes records plotted, outside the selected extent, and
without coordinates. Geographic conflicts remain unplotted. Undated records in
the review cohort remain included with year bounds unless their checkbox is
cleared. The default candidate cohort always requires an assigned year after
1930. GEOME discovery leads lacking verified WGS links are not plotted.

`map_records.csv` contains every WGS BioSample used by the viewer (including those
without coordinates); `map_cells.csv` contains geographic counts by species,
cohort, life stage, year and cell. Cohorts overlap—do not sum them together.
`map_input_checksums.csv` and `map_session_info.txt` record inputs and environment.
These `map_*` files are derived viewer exports and are excluded from the inventory
SQLite database, avoiding stale map tables during an inventory refresh.

**[genomics.sqlite](genomics.sqlite)** contains the CSV tables below, with indexed
species and accession keys. Open it with DB Browser for SQLite, SQLite, Python's
`sqlite3`, or R's `DBI`/`RSQLite` if installed. The build itself does not need those
R packages. All tables are also ordinary UTF-8 CSVs for spreadsheet/R use.

| Table | Unit / purpose |
| --- | --- |
| `species_summary.csv` | All 80 species, including explicit search-zero and unresolved-taxonomy outcomes |
| `taxon_crosswalk.csv` | Exact project names, archive names/taxids, decisions, and query status |
| `assemblies.csv` | One assembly record; annotation evidence, reference designation, quality statistics and BioSample links |
| `runs.csv` | One run; WGS/other-assay classification, technical-duplicate flags, yield and download URLs |
| `samples.csv` | One species × BioSample accession; collection date/location, stage, biological flags and nominal depth |
| `studies.csv` | One species × study; sample counts, descriptions, locality/date coverage, publication links |
| `sample_attributes.csv` | Original individual attribute values with source URLs; supports auditing and manual recovery |
| `atlas_candidates.csv` | WGS sample accessions with a single post-1930 year and coordinates inside the atlas extent, passing automatic exclusion flags |
| `atlas_candidate_cells.csv` | Candidate BioSample counts per 2° cell, collection year and life stage |
| `metadata_review_queue.csv` | Every WGS sample and its unresolved metadata/identity/integration checks |
| `sample_retrieval.csv` | Full sample XML retrieval status |
| `queries.csv` | Source URLs, retrieval timestamps, checksums and cached response paths |
| `input_checksums.csv` | MD5 fingerprints of exact local inputs and scripts used |
| `location_provenance.csv` | One sample × field × source assertion: original value, URL/DOI, source sample ID, row/section, matching method, precision scope and acceptance/conflict decision |
| `location_sources.csv` | Publication/repository source registry with original-file URLs, timestamps and SHA256s |
| `location_coverage.csv` | All 80 species: archive versus enriched geographic/date coverage, newly georeferenced accessions and conflicts |
| `publication_location_review.csv` | Reviewed study/publication links, recovered tables, blocked downloads and remaining leads |
| `geome_records.csv`, `geome_searches.csv` | GEOME discovery leads and all 80 search outcomes; not automatically WGS samples |
| `location_queries.csv` | Exact cached GEOME/publication requests and response hashes |

`resolved_config.R` and `session_info.txt` record settings and the R environment.

## Rebuild and validate

Run from the repository root:

```bash
Rscript tests/test_genomics_inventory.R
Rscript Scripts/build_genomics_inventory.R          # cached, offline
Rscript Scripts/build_genomics_maps.R               # geographic viewer + both historical pages
Rscript tests/test_atlas_genomics.R
python3 tests/validate_genomics_inventory.py
# Explicit network steps, if desired:
Rscript Scripts/build_genomics_inventory.R --download
Rscript Scripts/build_genomics_inventory.R --download --refresh
```

`--reuse-normalized` skips cache parsing for development; normal offline builds
verify response SHA256s and reconstruct the transport tables first. Python 3
standard library plus base R suffice. The helper downloads only metadata.
The map build additionally uses the atlas's already installed `maps` R package;
`Scripts/install_atlas_dependencies.R` is the explicit installation step if needed.
Rebuild maps after refreshing inventory data. Keep the sibling `SamplingAtlas`
directory for its shared species illustrations, credits and historical links.

## Use in R or SQL

```r
species <- read.csv("Output/Genomics/species_summary.csv")
subset(species, wgs_samples >= 50 & annotated_reference_assemblies > 0)
samples <- read.csv("Output/Genomics/samples.csv", na.strings = "")
subset(samples, map_candidate)
```

```sql
SELECT species, wgs_samples, annotated_reference_assemblies, mapped_dated_samples
FROM species_summary
WHERE wgs_samples >= 50
ORDER BY mapped_dated_samples DESC;

SELECT c.species, c.sample_accession, c.year, c.latitude, c.longitude,
       r.run_accession, r.library_layout, r.base_count, r.fastq_ftp
FROM atlas_candidates AS c
JOIN runs AS r USING (species, sample_accession)
WHERE r.wgs_eligible = 'TRUE';
```

## What a mapping candidate means

A candidate is a **BioSample accession**, not a confirmed independent wild fish.
`sample_count=1` and `count_unit=BioSample_accession`; `specimen_count` is deliberately
blank. Validate biological individuality, duplicated deposits, population identity,
collection provenance and habitat before adding specimen counts to museum maps.
Pools, captive/cross evidence, cell lines, hybrids and potential duplicate
individuals are flagged; missing coordinates and ambiguous collection years remain
unassigned. A bounding box is not a basin/habitat classification.

The database preserves all collection years worldwide, including historical and
ancient-study records. Only the candidate export requires a year after 1930 and
the fixed historical-atlas bounds. It does not alter the historical atlas,
its counts, or the species-selection rankings.

## Trace a location to its evidence

`samples.csv` preserves original normalized archive values as `archive_latitude`,
`archive_longitude`, `archive_locality_raw`, `archive_coordinates_raw`,
`archive_collection_date_raw`, `archive_year` and original parsing statuses.
The unprefixed fields contain reconciled archive/publication evidence.
`location_evidence_ids` and `date_evidence_ids` link directly to the provenance
ledger; IDs are local to the build, so retain the matching output snapshot.
The stable join across builds is species + BioSample + field + source + source
record/locator. `location_source_ids` gives the contributing source IDs.

```sql
SELECT field, value, value2, raw_value, source_url, publication_doi,
       source_record_id, source_locator, match_method, coordinate_scope, decision
FROM location_provenance
WHERE species = 'Menidia menidia' AND sample_accession = 'SAMN06436866';
```

Publication coordinates can identify a shared sampling site rather than an
individual GPS position: `coordinate_scope=reported_population_site` and
`coordinate_approximate=TRUE` make that distinction explicit for newly filled
locations. Unknown numerical uncertainty is left blank. Conflicting positions
are kept as separate evidence rows and withheld from the reconciled coordinates.
Library-quality exclusions from the publication remain in the database but are
excluded from mapping candidates. GEOME records are leads until an explicit
sample-level connection to a genomic accession is verified.
