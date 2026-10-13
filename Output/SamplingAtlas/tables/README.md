# Atlas tables and evidence

Start with [species_summary.csv](species_summary.csv) for species totals, or
[records_audit.csv](records_audit.csv) to trace a specimen count back to a museum
lot. For visual exploration, open the [atlas](../index.html).

A **lot** is one physical catalog entry and can contain several specimens. The
record audit also retains excluded source rows, so filter `included` and
`species_eligible` when reconstructing atlas totals. Do not sum every audit row.

## Main tables

| File or group | Use |
| --- | --- |
| [records_audit.csv](records_audit.csv) | Source row and catalog IDs, original identification, accepted species, counts, stage/date/location evidence and inclusion decisions |
| [species_summary.csv](species_summary.csv) | All in-scope species, their totals and eligibility flags |
| [candidate_screening.csv](candidate_screening.csv) | Eligible species ordered by broad historical sampling opportunities |
| [regional_candidates.csv](regional_candidates.csv) | Dated, recorded-coordinate, availability-screened counts by species, stage and basin |
| [approximate_locations.csv](approximate_locations.csv), [approximation_summary.csv](approximation_summary.csv) | Estimated display positions and their evidence; counts by species and estimation level |
| [annual_display_geographic_counts.csv](annual_display_geographic_counts.csv), [undated_display_geographic_counts.csv](undated_display_geographic_counts.csv) | Counts actually plotted, separating recorded and estimated contributions |
| [annual_geographic_counts.csv](annual_geographic_counts.csv), [undated_geographic_counts.csv](undated_geographic_counts.csv) | Recorded-coordinate cell counts, excluding display estimates |
| [cell_period_sampling.csv](cell_period_sampling.csv), [repeated_historical_cells.csv](repeated_historical_cells.csv) | Availability-screened cell/period counts and repeated historical sampling |
| [shared_assemblages.csv](shared_assemblages.csv), [shared_year_assemblages.csv](shared_year_assemblages.csv) | Broad shared-cell opportunities; the latter keeps individual years separate |
| [filter_counts.csv](filter_counts.csv) | Aggregates driving the viewer's combined filters |
| [review_queue.csv](review_queue.csv), [excluded_records.csv](excluded_records.csv) | Included records needing review and excluded source rows |
| [record_disposition.csv](record_disposition.csv), [date_quality_counts.csv](date_quality_counts.csv), [stage_evidence_counts.csv](stage_evidence_counts.csv), [regional_stage_period_counts.csv](regional_stage_period_counts.csv) | Count and quality summaries |

## Species illustrations

- [species_images.csv](species_images.csv): image catalog joined by exact project
  species name, including credits, source/license URLs, source-stage and taxonomy
  notes, local image path and `display_status` (`embedded`, `source_link`, or
  `not_cached`). Only catalog-approved noncommercial images are embedded.
- [image_input_checksums.csv](image_input_checksums.csv): catalog, cache files,
  download manifest and R attachment-code fingerprints. The download manifest
  under [images/](../images/README.md) also preserves the original SHA-256 values.

## All-year companion maps

- [overview_cells.csv](overview_cells.csv): specimens and lots pooled across all
  included years/stages by species and display grid cell. `years` lists distinct
  assigned years, separated by semicolons; `year_specimens` lists specimen totals
  in the same year order. These totals sum across included lots and life stages
  in that display cell. `undated_specimens` is separate.
  `cell_label` matches the numbered map annotations. Recorded and approximate
  counts remain separate columns.
- [overview_manifest.csv](overview_manifest.csv): species totals, plotted and
  unplotted counts, cell count, fixed bounds, SVG path and image checksum.
- [overview_input_checksums.csv](overview_input_checksums.csv): saved audit,
  configuration and rendering-code fingerprints. The companion uses existing
  display positions without changing or re-estimating them.

## Taxonomy and common names

[species_taxonomy.csv](species_taxonomy.csv) contains one row per displayed species:
`species`, catalog `order` and `family`, `common_name`,
`common_name_source_species` and `common_name_match_status`. Catalog ranks are
linked through audit row IDs with catalog-number verification; conflicting labels
stop generation. FishBase common names come from cached `source_records/species.csv`
using the existing curated species matches. Missing and withheld names remain blank.
[taxonomy_input_checksums.csv](taxonomy_input_checksums.csv) fingerprints these
sources and the R attachment module. No new taxonomic resolution is performed.

## Life-history tables

- [life_history_traits.csv](life_history_traits.csv): exact species-key attachment
  of the requested traits and taxonomic/source metadata from the existing
  `Output/LifeHistory/life_history_80_species.csv`. No new taxonomy decisions or
  missing-value imputation are made.
- [life_history_lengths.csv](life_history_lengths.csv): largest reported length
  across sexes within each length type, in cm. Types are never converted or averaged.
- [life_history_evidence.csv](life_history_evidence.csv),
  [life_history_references.csv](life_history_references.csv), and
  [life_history_dictionary.csv](life_history_dictionary.csv): copied evidence,
  citations and definitions for the attached trait source.
- [life_history_input_checksums.csv](life_history_input_checksums.csv): source and
  report-attachment module fingerprints, separate from scientific map provenance.

Model-derived ages remain explicitly identified. Missing values and withheld
taxonomic matches stay missing, not zero. Category filters match individual
semicolon-separated positive tags. See [the viewer guide](../README.md) for
filter semantics and [life-history methods](../../../docs/life_history_workflow.md)
for source limitations.

## Coordinates and counting rules

`longitude`/`latitude`, `mapped` and `dated_mapped` refer to recorded coordinates,
including reviewed manual overrides where applicable. `display_longitude` and
`display_latitude` add estimated positions for visualization; `display_mapped`
describes this combined coverage and `coordinate_approximate` identifies estimates.
The `approximation_*` fields explain their basis. Donor spread describes the
reference positions; it is not a validated positional-error radius.

Species eligibility uses dated specimens through 1930 across stages. Undated lots
remain separate. Blank cells or missing records do not indicate biological absence.
See [full field handling and assumptions](../../../docs/sampling_atlas.md).

## Manifests and reproducibility

- [artifact_manifest.csv](artifact_manifest.csv) lists stage-level GIFs, previews
  and PDFs. [annual_frame_manifest.csv](annual_frame_manifest.csv) lists each year
  PNG with its counts, geographic bounds and grid size.
- [input_checksums.csv](input_checksums.csv) fingerprints analysis inputs and code.
  [report_refresh_checksums.csv](report_refresh_checksums.csv) separately records
  a report-only refresh; [selection_digest_checksums.csv](selection_digest_checksums.csv)
  records the broad selection digest's inputs.

These are generated tables. Correct source interpretation in
[config](../../../config/README.md), then rebuild. For closer site/year/stage
comparisons, use [SpeciesSelection](../../SpeciesSelection/README.md), whose
bounded sites are different from the atlas's 2° grid cells.
