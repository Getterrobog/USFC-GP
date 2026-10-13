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
