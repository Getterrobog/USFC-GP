# Legacy tables and reused curation

This directory contains products of the earlier museum-processing workflow.
Some are still **inputs** to the current atlas, despite living under `Output/`:

| File | Current role |
| --- | --- |
| [species_validation_results.csv](species_validation_results.csv) | Cached name validation |
| [All_Ships_Updated.csv](All_Ships_Updated.csv) | Catalog-specific curated names |
| [HumanSearch.csv](HumanSearch.csv) | Additional reviewed name assignments |

The atlas reuses names from these files, not their legacy imputed coordinates or
dates. Reviewed overrides in [config](../../config/README.md) take precedence.
Do not delete these three files as disposable outputs or replace them with the
similarly named files in `Data/` without a reviewed configuration change.

`Potential.csv`, `CandidateSpeciesList.csv`, species summaries, removed/missing-lot
tables and the KMZ describe older exploration. They do not define the current
atlas or a final sequencing panel. See the [legacy audit](../SelectionAudit/README.md)
and [repository review](../../docs/repository_review.md) for limitations.

For current results, start with [SamplingAtlas](../SamplingAtlas/README.md) or
[SpeciesSelection](../SpeciesSelection/README.md).
