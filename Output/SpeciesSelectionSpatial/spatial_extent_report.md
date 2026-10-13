# Wider spatial extent comparison

Exploratory comparison using the frozen first-pass screened lots and all 80 existing species keys. No upstream curation, new species screening, date pooling, coordinate imputation or feasibility decisions.

**Distances below are maximum pairwise diameters, not radii around a central point.** The original baseline is 20 km diameter; 40 km was a sensitivity setting. The wider extents are design alternatives, not estimated population boundaries.

The fixed input contains 1183 lots, 9743 catalogued specimens and 73 of the 80 species, within 1880–1930. Each qualifying species needs at least 10 catalogued specimens in the same year and stage; each shared group needs at least three species. Stages are kept separate.

| Maximum diameter km | Species, all stages | Species, adult/non-larval | Candidate sites, all stages | Adult/non-larval sites |
| --- | ---: | ---: | ---: | ---: |
| 20 | 27 | 24 | 8 | 7 |
| 40 | 32 | 29 | 9 | 8 |
| 80 | 43 | 41 | 13 | 12 |
| 160 | 50 | 47 | 11 | 11 |
| 240 | 56 | 53 | 12 | 12 |

## Stronger count/lot requirement

For comparison, the following requires at least 20 specimens from two lots per species/site/year/stage (all assigned years, through 1930). These thresholds are screening settings, not validated genomic sample sizes.

| Maximum diameter km | Species in shared groups | Candidate sites |
| --- | ---: | ---: |
| 20 | 3 | 1 |
| 40 | 3 | 1 |
| 80 | 10 | 3 |
| 160 | 15 | 3 |
| 240 | 16 | 3 |

## Interpretation

Increasing extent can bring more species into shared groups and merge nearby sites. Fewer sites after a merge is not necessarily less biological information, and extra sites are not automatically independent regional replicates. Neither nearby collections nor shared catalog region labels establish a common population or exposure.

Use wider groups to discover regional assemblages, then retain nested localities, years and stages for historical–modern comparisons. Review coastlines, bays versus offshore habitat, source depth labels, migration and population structure before pooling specimens. candidate_site_evidence.csv exposes locality/region/depth labels rather than treating enlarged clusters as validated assemblages.

The fixed screen excludes unresolved positions, years and availability flags. Widening alone does not recover excluded records. Same-year comparisons remain conservative; any later temporal-window expansion should be evaluated separately so its effects are distinguishable.

## Reproducibility and checks

The full grid contains 120 scenarios spanning five extents, three specimen thresholds, two lot thresholds, two date-evidence modes and two final years. The 48 overlapping original scenarios reproduce both counts and exact species membership. Every extent conserves lot/specimen totals and satisfies the geometric diameter bound. No final species roster is changed.

Run `Rscript Scripts/compare_selection_spatial_extent.R`. Configuration, input checksums and R session metadata accompany the outputs. See [the spatial review](../../docs/species_selection_spatial_review.md) and [the original protocol](../../docs/species_selection_plan.md).
