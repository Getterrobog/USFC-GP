# Validation checks

Run these commands from the repository root:

| Command | What it checks |
| --- | --- |
| `Rscript tests/test_sampling_atlas.R` | Date/stage parsing, eligibility, counting, fixed map extent, selected-year timeline heights, approximate-location provenance and filter aggregates |
| `Rscript tests/test_atlas_images.R` | Image joins, byte hashes, attribution, permitted embeds, source links, taxonomy notes and missing-cache behavior |
| `Rscript tests/test_sampling_overview.R` | Combined species maps: counts, distinct years, undated/approximate records, label spacing, links and provenance; requires the overview build |
| `Rscript tests/test_sampling_explorer.R` | All 80 species × four map stages against the record audit; cell/year counts, pooled overview agreement, zero/unmapped stages, fixed bounds/scales and source checksums; requires the explorer build |
| `Rscript tests/test_atlas_taxonomy.R` | Catalog row linkage, common-name source agreement, approved aliases and missing/withheld names |
| `Rscript tests/test_atlas_traits.R` | Trait joins, missingness, withheld taxonomy, positive numeric values and length pooling without mixing types |
| `Rscript tests/validate_sampling_atlas.R` | A completed atlas: counts, recorded/estimated contributions, PNGs, GIFs, links and provenance |
| `Rscript tests/test_species_selection.R` | Bounded geographic sites, separate year/stage cells, shared-species evidence, sensitivity and input linkage |
| `python3 -m unittest discover -s tests -p 'test_selection_audit.py'` | Legacy audit boundaries, including ambiguous dates and source CSV handling |

The atlas transformation checks read the repository's source export and curated
name tables. Completed-output validation also requires a fully rendered atlas;
it is not expected to pass on an incomplete batch or data-only build. ImageMagick's
`identify`, when available, checks GIF frame counts and dimensions.

After `Rscript Scripts/build_sampling_explorer.R`, run
`node tests/test_sampling_explorer.cjs` with Playwright available on `NODE_PATH`.
This local-file browser check renders all 320 species/stage choices and validates
cell counts, bounds, label fit, search/keyboard selection, combined filters,
empty results, SVG download, species/stage deep links and viewport fit at five
desktop/mobile sizes, including expanded filters without moving the map.
It also checks independent parent/nested menu states across species changes and
empty results, plus mouse/keyboard panel resizing, width limits and reset.

To validate a different completed output directory:

```bash
Rscript tests/validate_sampling_atlas.R Output/SamplingAtlas
```

These checks establish computational consistency, not the truth of every museum
identification, collection date or position. They do not establish DNA recovery,
population identity or statistical power. See [methods](../docs/README.md) for the
assumptions that require scientific review.

## Public genomic inventory

- `Rscript tests/test_genomics_inventory.R`: checks date ranges, missing dates,
  coordinate signs/ranges/conflicts, embedded coordinate evidence, assay exclusions,
  low-coverage labels, repeated FASTQ checksum handling, DMS site-coordinate parsing
  and publication coordinate agreement/rejection.
- `python3 tests/validate_genomics_inventory.py`: verifies a completed inventory's
  80-species roster, accession uniqueness and joins, count reconciliation, mapping
  exclusions, original-input fingerprints and SQLite integrity/CSV agreement.
  Also checks every attached location/year against its provenance, source SHA256s,
  exact silverside and Fundulus sample crosswalks, withheld Atherinomorus conflicts,
  publication quality exclusions, coverage summaries and all GEOME search outcomes.

Run the build first with `Rscript Scripts/build_genomics_inventory.R`. All checks
are offline and do not modify the historical atlas.

After `Rscript Scripts/build_genomics_maps.R`:

- `Rscript tests/test_atlas_genomics.R`: exact species joins, unresolved taxonomy,
  contemporary counts, cohort/stage/year cell counts, source exports and checksums.
- `node tests/test_genomics_maps.cjs` with Playwright available on `NODE_PATH`:
  genomic filters on both historical pages, map/frame counts, timeline bar heights,
  unchanged extents between years, sample provenance, playback, SVG downloads,
  undated records, empty results and mobile layout. Uses local files only.

- `Rscript tests/test_atlas_traits.R` additionally checks the integrated trait
  source, method/SE display, zero depth, positive behavior flags, unresolved
  taxonomy and inherited/new evidence links.
- `node tests/test_trait_pages.cjs` with Playwright on `NODE_PATH` compares trait
  filtering on all three geographic pages directly against the curated CSV:
  categorical choices, numeric bounds, missingness, zero depth, combined genomic
  criteria, reset, citations and mobile layout.
