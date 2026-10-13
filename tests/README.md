# Validation checks

Run these commands from the repository root:

| Command | What it checks |
| --- | --- |
| `Rscript tests/test_sampling_atlas.R` | Date/stage parsing, eligibility, counting, fixed map extent, approximate-location provenance and filter aggregates |
| `Rscript tests/test_atlas_taxonomy.R` | Catalog row linkage, common-name source agreement, approved aliases and missing/withheld names |
| `Rscript tests/test_atlas_traits.R` | Trait joins, missingness, withheld taxonomy, positive numeric values and length pooling without mixing types |
| `Rscript tests/validate_sampling_atlas.R` | A completed atlas: counts, recorded/estimated contributions, PNGs, GIFs, links and provenance |
| `Rscript tests/test_species_selection.R` | Bounded geographic sites, separate year/stage cells, shared-species evidence, sensitivity and input linkage |
| `python3 -m unittest discover -s tests -p 'test_selection_audit.py'` | Legacy audit boundaries, including ambiguous dates and source CSV handling |

The atlas transformation checks read the repository's source export and curated
name tables. Completed-output validation also requires a fully rendered atlas;
it is not expected to pass on an incomplete batch or data-only build. ImageMagick's
`identify`, when available, checks GIF frame counts and dimensions.

To validate a different completed output directory:

```bash
Rscript tests/validate_sampling_atlas.R Output/SamplingAtlas
```

These checks establish computational consistency, not the truth of every museum
identification, collection date or position. They do not establish DNA recovery,
population identity or statistical power. See [methods](../docs/README.md) for the
assumptions that require scientific review.
