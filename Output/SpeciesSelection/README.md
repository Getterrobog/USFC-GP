# Historical species and site screening

**Read [selection_report.md](selection_report.md) first.** This workflow asks which
atlas species have enough specimens in the same provisional site, year and stage
to warrant investigating a comparative genomic study. Its queue is not a final
species panel or proof of DNA recovery, museum availability or a common haul.

The baseline uses sites with at most 20 km between recorded positions, at least
10 specimens per species/site/year/stage and at least three qualifying species
per shared group. These are exploration settings, not powered genomic sample-size
requirements. The atlas's approximate display positions do not enter this screen.

## Suggested reading order

| File | Question it answers |
| --- | --- |
| [selection_report.md](selection_report.md) | What opportunities and limitations emerged? |
| [species_investigation_queue.csv](species_investigation_queue.csv) | Which species connect candidate sites and survive alternative thresholds? |
| [species_site_matrix.pdf](species_site_matrix.pdf), [CSV](species_site_matrix.csv) | Where does the proposed crossed sampling design have evidence or gaps? |
| [assemblage_candidates.csv](assemblage_candidates.csv), [site_evidence.csv](site_evidence.csv) | Which sites, years and stages support shared-species comparisons? |
| [assemblage_species_evidence.csv](assemblage_species_evidence.csv), [assemblage_date_station_review.csv](assemblage_date_station_review.csv) | Do the source dates, stations and localities support the apparent overlap? |
| [screened_lots.csv](screened_lots.csv), [species_site_year_cells.csv](species_site_year_cells.csv) | Which catalog lots and counts support each result? |
| [record_evidence_gaps.csv](record_evidence_gaps.csv), [feasibility_requests.csv](feasibility_requests.csv) | What missing evidence needs to be resolved next? |
| [sensitivity_scenarios.csv](sensitivity_scenarios.csv), [sensitivity_species_membership.csv](sensitivity_species_membership.csv) | How do conclusions depend on count, lot, date and distance settings? |
| [site_connectivity.csv](site_connectivity.csv) | Which sites are linked by shared candidate species? |
| [record_disposition.csv](record_disposition.csv) | Why did each source record enter or leave the downstream screen? |

`site_id` is a provisional group identifier for the saved coordinate snapshot,
not a permanent place or population name. Same-year proximity does not prove
same-event sampling. Adult/non-larval maturity remains unverified.

## Reproduce or change settings

From the repository root, after the atlas's audit tables exist:

```bash
Rscript tests/test_species_selection.R
Rscript Scripts/build_species_selection.R
```

This uses base R, the completed atlas and original locality evidence. It does not
re-query taxonomy or rebuild atlas graphics. Settings are in
[config/species_selection.R](../../config/species_selection.R). Reruns overwrite
generated files; maintain lasting corrections upstream rather than in these CSVs.

[resolved_config.R](resolved_config.R), [session_info.txt](session_info.txt),
[input_checksums.csv](input_checksums.csv), [output_checksums.csv](output_checksums.csv)
and [atlas_input_manifest.csv](atlas_input_manifest.csv) describe the saved run.
Results are a snapshot: rebuilding the atlas does not automatically rebuild this
directory. See the [implemented methods](../../docs/species_selection_workflow.md)
and the broader [selection protocol](../../docs/species_selection_plan.md).
