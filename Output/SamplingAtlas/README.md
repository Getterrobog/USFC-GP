# Historical sampling atlas

**Start by opening [index.html](index.html) in a web browser.** Download or clone
the repository first; browsing an HTML file's source on GitHub does not run the
viewer. No R installation, server or internet connection is needed to browse the
saved atlas. Keep this directory and its subdirectories together.

The atlas answers: **which species have historical specimens, in which places
and years, and at which life stages?** It is an inventory for planning, not a map
of fish abundance or a final list of species approved for sequencing.

## All-year companion page

Open [overview.html](overview.html) for **one map per species**, combining all
included years and life stages. Each numbered 2° cell connects to a label listing
its collection years, with that cell/year’s specimen count in parentheses, e.g.
`1895 (9)`. Counts pool included life stages and recorded/approximate positions.
Undated samples are included and explicitly labeled with their count;
collections without usable display locations are counted above the map.

The same species, taxonomy, sampling and life-history filters select candidates.
On this page, filters **do not subset the map**: it always shows the species'
full included sampling. Use the original atlas for separate stages and years.
**Enlarge labels** provides a scrollable enlarged image; **Fit map to page**
restores its display size. Both retain the same geographic extent. Expand
**Grid-cell years and counts** for an accessible table, or open/download the
standalone SVG map. No network connection or added browser dependencies are needed.

Rebuild this page from the saved atlas audit with:

```bash
Rscript Scripts/build_sampling_overview.R
Rscript tests/test_sampling_overview.R
```

Run this after rebuilding the main atlas if its data or configuration change.
A report-only refresh updates both pages once the companion maps exist.

## Scope and controls

- Species qualify with at least **50 dated specimens through 1930**, summed over
  stages within the western Atlantic, Caribbean and Gulf of Mexico. The threshold
  counts specimens, not lots; it is not required separately in every year or stage.
- Larvae, adult/non-larval lots and unsplit mixed lots are separate. Adult/non-larval
  includes unlabeled lots and juveniles; maturity is unverified.
- Each heading lists catalog order and family before the scientific name, followed
  by the FishBase common name when available.
- Filter by scientific or common name, order, family, minimum dated specimens, stage, region, minimum distinct
  years and recorded-coordinate availability. Thresholds apply jointly within
  the selected stage and region. Undated specimens do not satisfy them.
- Choose a year, use the previous/next buttons, or play a stage's GIF. GIFs advance
  through sampled years rather than implying uninterrupted annual sampling.
- Filters select candidates; maps retain the displayed stage's full distribution.
  Undated lots have separate frames.

Order and family use the museum catalog classification, which may differ from
current classifications. Common names use the existing curated FishBase matches,
including approved synonyms or proxies; unresolved matches stay unreported.
Taxonomy filters combine with every other active filter. The downloadable
[taxonomy snapshot](tables/species_taxonomy.csv) records the common-name source
species and match status.

## Species illustrations

Both pages show locally cached species illustrations with contributor credits,
source links and license links. The image catalog currently approves 54 images
for noncommercial embedding; the other 26 entries link to their sources with
permission or taxonomic-review notes. Images illustrate species rather than the
actual sampled lots; source life stage and any source-name exception are shown.

Keep [images/](images/README.md) with the atlas for offline viewing. The files
retain their original bytes and CC BY-NC 4.0 attribution. For cache/rebuild
commands and download provenance, see the [image directory guide](images/README.md).

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

The timeline below each map counts all specimens in that species and life stage
for each dated year, including specimens that cannot be mapped. The selected
year's red bar ends at its specimen count; other years are gray. Undated frames
do not highlight a year.

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
| [index.html](index.html) | Interactive year-by-year viewer |
| [overview.html](overview.html) | One map per species, with all years and stages pooled |
| [images/](images/README.md) | Cached species illustrations, credits and download manifest |
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
