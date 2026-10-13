# Scripts and workflow entry points

Run the commands below from the repository root. To explore existing results,
start with [Output](../Output/README.md); rebuilding is unnecessary for browsing.

## Current R workflows

| Script | Role |
| --- | --- |
| [install_atlas_dependencies.R](install_atlas_dependencies.R) | Explicitly install `maps` into the ignored local `.R-library`; requires network access |
| [build_sampling_atlas.R](build_sampling_atlas.R) | Read the museum export and cached curation; write audits, counts, annual geographic maps and GIFs |
| [summarize_sampling_candidates.R](summarize_sampling_candidates.R) | Produce the atlas's broad basin/stage candidate digest |
| [cache_sampling_atlas_images.R](cache_sampling_atlas_images.R) | Verify cached species illustrations; `--download` explicitly retrieves catalog-approved images, then refresh the pages |
| [build_sampling_overview.R](build_sampling_overview.R) | Create the all-year companion page and annotated SVG maps from a saved atlas |
| [refresh_sampling_atlas_index.R](refresh_sampling_atlas_index.R) | Refresh the local HTML viewer from saved outputs; does not redo scientific analysis |
| [build_species_selection.R](build_species_selection.R) | Reuse atlas records for bounded-site, year and stage comparisons, sensitivity and evidence queues |

One-time atlas setup also requires ImageMagick (`magick` or `convert`) installed
through your operating system for GIF encoding. The normal atlas run is offline;
it reuses cached taxonomy and the installed coastline data. The downstream
species-selection screen uses base R.

```bash
# Setup, then rebuild and validate the main atlas.
Rscript Scripts/install_atlas_dependencies.R
Rscript tests/test_sampling_atlas.R
Rscript Scripts/build_sampling_atlas.R
Rscript Scripts/summarize_sampling_candidates.R
Rscript tests/validate_sampling_atlas.R

# Rebuild the separate species/site investigation screen.
Rscript tests/test_species_selection.R
Rscript Scripts/build_species_selection.R
```

For a smaller local build:

```bash
Rscript Scripts/build_sampling_atlas.R --species=Menidia_menidia --output=Output/AtlasPreview
Rscript Scripts/build_sampling_atlas.R --data-only --output=Output/AtlasDataOnly
```

These output directories are ignored by Git. Read [atlas methods and options](../docs/sampling_atlas.md)
and [selection methods](../docs/species_selection_workflow.md) before changing
thresholds. Settings and reviewed corrections belong in [config](../config/README.md).

## Reusable R modules

These files are sourced by the runners rather than invoked as standalone builds:

- [sampling_atlas_functions.R](sampling_atlas_functions.R): record preparation,
  counting, screening and geographic rendering.
- [sampling_atlas_locations.R](sampling_atlas_locations.R): auditable approximate
  display positions, kept separate from original coordinates.
- [sampling_atlas_report.R](sampling_atlas_report.R): annual frame inventories,
  HTML viewer and combined candidate filters.
- [sampling_atlas_taxonomy.R](sampling_atlas_taxonomy.R): catalog order/family,
  cached common-name attachment, taxonomy headings, filters and provenance tables.
- [sampling_atlas_images.R](sampling_atlas_images.R): exact species-image joins,
  file verification, credited image cards and source-link fallbacks.
- [sampling_atlas_overview.R](sampling_atlas_overview.R): all-stage/all-year
  cell summaries, collision-free year callouts and standalone SVG rendering.
- [sampling_atlas_traits.R](sampling_atlas_traits.R): exact-key attachment of
  life-history outputs, length pooling by type, trait cards and filter controls.
  Refresh the atlas index after updating the trait outputs; media need not change.
- [species_selection_functions.R](species_selection_functions.R): bounded sites,
  year/stage cells, shared-species evidence and sensitivity calculations.

## Legacy audit and other tools

[download_fishbase_traits.py](download_fishbase_traits.py) is a separate, explicit
network step for pinned FishBase tables in [Data/LifeHistory](../Data/LifeHistory/README.md).
It is not required by the atlas or historical sampling screen.

[audit_selection_inputs.py](audit_selection_inputs.py) uses Python's standard
library to inventory the older inputs without altering them:

```bash
python3 Scripts/audit_selection_inputs.py
```

Its output is documented in [SelectionAudit](../Output/SelectionAudit/README.md).

The older `USNM-R-inator.R`, `PRfixinator.R`, `species_checkinator.py`,
`FishBaseinator.R` and `USNMdiff-inator.R` support earlier cleaning, lookup and
exploration. `Populinator.R` is an exploratory simulation. They are not required
to rebuild the current atlas or selection screen; some depend on interactive
objects, additional packages or live services. Consult the
[repository review](../docs/repository_review.md) before rerunning them.

`Gitpushinator.sh` performs Git publication operations and is not an analysis
dependency. Run Git adding, committing and pushing separately when intended.

## Public genomic inventory

`build_genomics_inventory.R` builds the separate [genomic database and viewer](../Output/Genomics/README.md)
from cached ENA and NCBI metadata. `genomics_functions.R` implements scientific
classification, date/coordinate interpretation, sample screening and reporting
in base R. `genomics_archive_io.py` uses Python 3's standard library for HTTP,
JSON/XML transport, compressed-response verification and SQLite export.
`genomics_locations.R` attaches and reconciles publication-backed locations/years
and writes the sample-level provenance ledger. `genomics_location_io.py` caches
publication supplements and GEOME metadata and extracts spreadsheet values;
it does not infer sample locations. The R runner invokes both helpers offline by
default. Location sources are documented in
[Data/Genomics/location_sources](../Data/Genomics/location_sources/README.md).

```bash
Rscript Scripts/build_genomics_inventory.R              # offline
Rscript Scripts/build_genomics_inventory.R --download   # allow cache misses
Rscript Scripts/build_genomics_maps.R                    # offline maps + atlas summary refresh
Rscript tests/test_genomics_inventory.R
python3 tests/validate_genomics_inventory.py
```

Add `--refresh` with `--download` only when intentionally replacing the archive
snapshot. Configuration is in `config/genomics.R`; evidence-backed assay exceptions
are in `config/genomics_assay_overrides.csv`. [Methods](../docs/genomics_inventory.md)
document location source registration, exact sample joins and unresolved conflicts.
`--refresh` affects ENA/NCBI; the location helper retains its pinned snapshots.
The methods also
explain counts, taxonomy, data gaps and limitations. This workflow does not modify
the historical atlas or selection outputs.

`build_genomics_maps.R` and `genomics_maps.R` build the separate geographic viewer
and its record/cell exports from completed genomic outputs. `genomics_maps.js`
provides local SVG maps, year playback, sample inspection and export;
`genomics_maps.css` provides its styling. `sampling_atlas_genomics.R` attaches exact
species summaries to both historical pages, and `genomics_filters.js` shares the
availability filters across viewers. Refreshing these reports changes HTML and
report metadata only; museum map counts and rendered historical media are retained.
