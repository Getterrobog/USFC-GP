# Analysis settings and reviewed corrections

This directory holds editable inputs controlling the reproducible workflows.
Output folders contain snapshots of the settings used in a particular run;
change the files here to define a new run.

| File | Purpose |
| --- | --- |
| [sampling_atlas.R](sampling_atlas.R) | Input/output paths, eligibility threshold, year cutoff, map extent, grid size and animation settings |
| [sampling_overrides.csv](sampling_overrides.csv) | Catalog-specific reviewed corrections with reasons |
| [sampling_locality_anchors.csv](sampling_locality_anchors.csv) | Ordered named-place rules and sourced coordinate proxies for approximate display locations |
| [species_selection.R](species_selection.R) | Downstream time window, maximum site diameter, specimen/lot/species thresholds and sensitivity grid |

## Important defaults

The atlas requires 50 dated specimens per species through 1930 across the study
area and stages. Maps use 2° cells and a fixed 100–50°W, 5–60°N extent. The
`approximate_locations` switch controls display-only estimates. The `adult`
category means non-larval inventory, with maturity unverified.

The separate selection screen starts at a 20 km maximum within-site distance,
10 specimens per species/site/year/stage and three qualifying species per shared
group. These settings serve different purposes from the atlas's grid and
species-wide eligibility rule.

## Making changes

Paths are relative to the repository root. Runners accept `--config=path` and
`--output=path`, so alternative analyses can retain separate configurations and
outputs. Rebuild the affected workflow after changing settings; refreshing the
HTML alone does not recalculate maps or counts.

Every override requires a `catalog_number` and a nonblank `reason`. Blank correction
fields leave existing values unchanged. Use the documented species, stage, year,
coordinate and region fields; preserve the reason and evidence for each decision.

Named-place rules supply approximate plotting positions, not verified collection
coordinates. Their ordering matters. Original positions remain separate, and
estimates must not silently enter precise-location screening.

See the [atlas methods](../docs/sampling_atlas.md) and
[selection methods](../docs/species_selection_workflow.md) for complete rules.

## Genomic inventory

`genomics.R` controls the public-genomic inventory's roster, input/output paths,
nominal low-depth screening threshold and contemporary mapping bounds/years.
`genomics_assay_overrides.csv` documents accession-specific exceptions to archive
library-strategy labels with evidence URLs and reasons. Original taxonomic project
synonym decisions remain in `life_history_taxon_crosswalk.csv`; genomic-specific
resolution is recorded in `Output/Genomics/taxon_crosswalk.csv`.
