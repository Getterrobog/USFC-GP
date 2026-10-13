# Historical sampling atlas

**Start by opening [index.html](index.html) in a web browser.** Download or clone
the repository first; browsing an HTML file's source on GitHub does not run the
viewer. No R installation, server or internet connection is needed to browse the
saved atlas. Keep this directory and its subdirectories together.

The atlas answers: **which species have historical specimens, in which places
and years, and at which life stages?** It is an inventory for planning, not a map
of fish abundance or a final list of species approved for sequencing.

## Scope and controls

- Species qualify with at least **50 dated specimens through 1930**, summed over
  stages within the western Atlantic, Caribbean and Gulf of Mexico. The threshold
  counts specimens, not lots; it is not required separately in every year or stage.
- Larvae, adult/non-larval lots and unsplit mixed lots are separate. Adult/non-larval
  includes unlabeled lots and juveniles; maturity is unverified.
- Filter by species name, minimum dated specimens, stage, region, minimum distinct
  years and recorded-coordinate availability. Thresholds apply jointly within
  the selected stage and region. Undated specimens do not satisfy them.
- Choose a year, use the previous/next buttons, or play a stage's GIF. GIFs advance
  through sampled years rather than implying uninterrupted annual sampling.
- Filters select candidates; maps retain the displayed stage's full distribution.
  Undated lots have separate frames.

## Life-history information and filters

Each species card shows positive water types and habitat tags, water-column
habitat, migration, fisheries importance, sexual system, fertilization,
reproductive guild, model generation time, model lifespan, model maturity age,
and maximum reported length by type.

Expand **Life-history filters** to select categories and minimum/maximum values.
These combine with the sampling filters; all selected fields must match. Each
numeric trait can also be restricted to available or missing/withheld values.
Unfiltered traits do not exclude species with missing data. Reset all filters
restores the full eligible inventory.

Model ages are estimates, not observations. Positive habitat/water tags are
reported associations, not exhaustive habitat limits. Primary studies and regional
applicability remain unreviewed. Missing data are shown explicitly; traits remain
withheld for unresolved taxonomic matches.

Lengths use the largest reported value across sexes **within each type**, without
sex-specific display or conversion between TL (total), SL (standard) and FL (fork)
length. Other source codes are preserved. A length range matches if at least one
maximum of the selected type falls inside it. Values on cards are rounded to three
significant digits; filtering uses the underlying values with a small tolerance
for floating-point serialization noise.

The atlas carries its own [trait snapshot](tables/life_history_traits.csv),
[lengths by type](tables/life_history_lengths.csv),
[evidence](tables/life_history_evidence.csv) and
[references](tables/life_history_references.csv), so these downloads work when
this directory is shared alone. See [trait-source methods](../../docs/life_history_workflow.md).

## Reading the maps

Every map uses **2° × 2° cells** and the same extent: **100–50°W, 5–60°N**.
Colors count specimens per cell, with a logarithmic scale fixed across years and
stages within each species. Color scales may differ between species.

**Hatched cells contain estimated locations.** When coordinates were missing,
other record fields supplied approximate display positions. Some refer to a named
locality or island; others only to a state, country or basin. A 2° cell does not
make a coarse estimate accurate to 2°. Frame counts distinguish recorded and
estimated positions. Original coordinates remain unchanged; estimates are excluded
from precise-location sampling screens and the recorded-coordinate filter counts.

See [estimated lots and their evidence](tables/approximate_locations.csv) and
[the methods](../../docs/sampling_atlas.md) before interpreting geographic overlap.

## Files and folders

| Location | Contents |
| --- | --- |
| [index.html](index.html) | Interactive local viewer |
| [species/](species/README.md) | One directory per species, with stage GIFs, annual PNGs and PDF downloads |
| [tables/](tables/README.md) | Record audit, counts, screening summaries, location evidence and manifests |
| [run_summary.txt](run_summary.txt) | Counts and caveats from the saved build |
| [selection_digest.txt](selection_digest.txt) | Broad basin/stage leads for further investigation |
| [resolved_config.R](resolved_config.R) | Settings used for this saved atlas |
| [session_info.txt](session_info.txt), [render_versions.txt](render_versions.txt) | R and rendering environment |

The current index and manifests identify the current build. Old files can remain
locally after a rerun; their presence alone does not make them current results.

## Rebuild

From the repository root, after installing the dependencies described in
[Scripts/README.md](../../Scripts/README.md):

```bash
Rscript Scripts/build_sampling_atlas.R
Rscript Scripts/summarize_sampling_candidates.R
Rscript tests/validate_sampling_atlas.R
```

For report-only changes, use `Rscript Scripts/refresh_sampling_atlas_index.R`.
Changes to counts, coordinates, grid size or map styling require rebuilding.
When life-history outputs change, refresh the index to update traits and filters;
the geographic PNGs and GIFs do not need rebuilding. An initial atlas can be
built before the optional trait outputs exist, avoiding a dependency cycle with
the downstream species-selection and life-history workflows.
Edit [configuration and corrections](../../config/README.md), not the generated
tables. Continue to [SpeciesSelection](../SpeciesSelection/README.md) for the
more detailed site/year/stage screen.
