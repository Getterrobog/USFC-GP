# Wider spatial comparison for species selection

Start with [spatial_extent_report.md](spatial_extent_report.md).
This comparison holds the original cleaned roster and screened lots fixed and
compares **maximum diameters**, not radii, of 20, 40, 80, 160 and 240 km.

- `extent_summary.csv`: species/sites at the original 10-specimen count setting,
  including a separate adult/non-larval summary.
- `species_membership.csv`: all 80 species at every extent, including new entries
  relative to the 20 km baseline.
- `candidate_site_evidence.csv`: locality/region/depth labels and actual spread.
- `shared_species_site_year_cells.csv`: qualifying shared cells and catalog IDs.
- `sensitivity_scenarios.csv`, `sensitivity_species_membership.csv`: all 120 scenarios.
- `input_checksums.csv`, `resolved_config.R`, `session_info.txt`: reproducibility.

Run `Rscript Scripts/compare_selection_spatial_extent.R` from the repository root.
The original selection and curation are preserved. These groups are discovery
units needing habitat/population review, not finalized assemblages or species.
See [interpretation and next steps](../../docs/species_selection_spatial_review.md).
