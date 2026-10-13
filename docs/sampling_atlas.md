# Historical geographic sampling atlas

This R workflow starts from the original museum export, counts physical specimen
lots once, and produces an auditable inventory for sampling design. Default species
eligibility is **at least 50 specimens with an assigned collection year through
1930**, summed across life stages and the study area. It is not 50 lots, 50 per
year, or 50 per stage. Undated specimens never confer eligibility. Records after
1930 remain in the audit but are excluded from the atlas. Undated records may
ultimately prove to be later collections; their separate panels make no claim
that they belong to the historical window.

## Run

From the repository root:

```bash
Rscript Scripts/install_atlas_dependencies.R
Rscript tests/test_sampling_atlas.R
Rscript Scripts/build_sampling_atlas.R
Rscript tests/validate_sampling_atlas.R
Rscript Scripts/summarize_sampling_candidates.R
```

Install ImageMagick separately using your system's package manager. The R renderer
uses its `magick` or `convert` executable for GIF encoding. The only non-base R
dependency is `maps`, installed into the ignored project-local `.R-library`.
No packages are installed and no remote taxonomy services are queried during a
normal analysis run. Coastlines come from the installed `maps` database; its
[reference manual](https://cran.r-project.org/web/packages/maps/maps.pdf) describes
the underlying map data and drawing interface.

The runner finds the repository relative to its own path, so it can also be called
from another directory. Other useful commands:

```bash
# Rebuild data and screening tables without rendering.
Rscript Scripts/build_sampling_atlas.R --data-only --output=Output/AtlasDataOnly

# Render a small preview without changing species eligibility calculations.
Rscript Scripts/build_sampling_atlas.R --species=Menidia_menidia,Anchoa_mitchilli --output=Output/AtlasPreview

# PDFs and PNGs without an ImageMagick requirement.
Rscript Scripts/build_sampling_atlas.R --no-gifs --output=Output/AtlasNoGIF

# A separate, versionable configuration for sensitivity analysis.
Rscript Scripts/build_sampling_atlas.R --config=config/sampling_atlas.R

# Interruptible rendering in batches; repeat until all eligible species finish.
Rscript Scripts/build_sampling_atlas.R --resume --limit=20

# Refresh the map viewer and recover year PNGs from existing GIFs (no analysis rerun).
Rscript Scripts/refresh_sampling_atlas_index.R
```

Change parameters in `config/sampling_atlas.R`. Use a separate output directory for
each changed configuration or preview. The output directory is a generated build,
not a source of curated data; reruns replace files with matching names. The current
index and artifact manifest define the current run; unrelated old files are not
deleted. A data-only run does not refresh previously rendered graphics.

The analysis has no random component. Each run records its resolved configuration,
input/code MD5 checksums, R session information, and rendering versions. Scripts,
configuration, reviewed overrides and the main `Output/SamplingAtlas/` build are
eligible for version control. Preview/data-only builds, the local R library,
render caches and superseded matrix/PDF-page previews are ignored. The shared
atlas retains its linked annual PDFs, year PNGs, GIFs and audit tables; keep its
directory structure intact. See the [output guide](../Output/README.md).
The workflow never edits existing inputs or legacy outputs.
Completed species receive rendering checkpoints. `--resume` reuses a checkpoint
only when input/code hashes, configuration and R/maps versions match and all its
files still exist. `--limit` bounds newly rendered species per invocation. The full
build validation intentionally fails on an incomplete batch.

## Record handling and uncertainty

**Physical lots.** Only `Kind of Object = Specimen/Lot` contributes specimens.
Images and genetic-sample entries are excluded; many genetic samples share a
catalog number with a physical lot. Duplicate physical lot IDs stop the run rather
than being silently added. Nonpositive/noninteger counts, unresolved species and
Amphioxiformes are excluded. Count conservation is checked in the annual and
undated geographic aggregates.

**Taxonomy.** Binomials are extracted conservatively. Family/genus-only names,
`cf.`, `aff.`, `sp.`, and question-mark identifications do not become species.
Cached Eschmeyer name validation is applied, then the repository's catalog-specific
curated names and manual corrections. The latter supply taxonomy only. A binomial
without cached validation is retained but flagged for review, especially important
for larvae excluded from the previous pipeline. `taxonomy_status` distinguishes
these records. No new taxonomic verification is claimed.

The existing name cleaning is the baseline for species selection; it is reused
without new live lookups. Subspecies are pooled under their accepted species,
while `identification` retains the original catalog name. Raw trinomials are
already reduced to species by the atlas, and the current cached/curated accepted
names are binomials. Existing accepted-name corrections take precedence over the
original catalog binomial, including when a historical subspecies has been
reassigned to a different accepted species. Taxonomic pooling leaves site, year
and life-stage groupings intact.

**Stages.** Explicit larval preparation or specific larval notes assign `larva`.
Unlabeled specimens and known juveniles are shown as `adult`, displayed everywhere
as **Adult / non-larval (maturity unverified)**. `stage_evidence` preserves whether
the record is a known juvenile, an explicit adult, or unlabeled. A narrative mention
of a larval curation contract alone is not stage evidence. Mixed larval/juvenile
lots are a separate `mixed` group, with their full lot count assigned once. They
are not arbitrarily split into adults and larvae. `unknown_stage = "unknown"`
supports a stricter alternative. Preparation component counts are not treated as
independent specimens or substituted for the museum's lot count.

**Years.** A unique explicit four-digit year is used even when month/day is absent.
Ranges confined to one year are usable for annual maps; ranges spanning multiple
years remain undated/ambiguous. For `DD-Mon-YY`, only the final token is the year.
Century assignment uses explicit vessel windows inherited from the existing
project script: Albatross 1882–1921, II 1926–1932, III 1948–1959, IV 1963–2008,
Fish Hawk 1880–1926, and Grampus 1886–1917. A unique compatible century is required.
These inferred years are labeled `century_inferred_from_vessel` and remain
reviewable; unsupported vessel names are not guessed. Explicit years are preserved
without forcibly fitting those windows. Dates are never borrowed from neighboring
lots. Eligibility includes these explicitly flagged vessel-inferred years.

**Coordinates.** Original numeric coordinates and reasoned manual overrides remain
in `longitude`/`latitude`; `mapped` and `dated_mapped` continue to mean recorded
coordinates suitable for the existing screening workflow. The source calls these
positions centroids: decimal places do not establish accuracy.

For display, missing or invalid positions receive separate `display_longitude`
and `display_latitude` estimates. Matching proceeds through vessel/year/station,
exact locality and administrative context, named-place rules, island, county,
state within basin, country within basin, and finally basin. Station matches
with donor spread above 25 km are rejected. Donor pools contain original physical
lot positions only; estimates and manual overrides never become donors. Medians
are calculated across unique coordinate pairs, without weighting by specimen or
lot counts, and rounded to two decimals. Two decimals are a storage convention,
not a claim of precision. Existing valid positions are never replaced, including
those outside the map extent; excluded records are not imputed.

`config/sampling_locality_anchors.csv` contains ordered, editable place-name rules
and frozen city proxies from `maps::world.cities`, with package version and source
links. These improve island and locality assignments where the catalog has no
nearby reference positions. A city can represent a named island; that does not
claim the collection occurred in that city. Historic names and market localities
also require review before resampling. The old pipeline's imputed coordinates
are not reused, and no dates are inferred from these spatial matches.

Every estimate records its resolution level, matching basis, reference catalog
IDs or gazetteer source, number of distinct reference positions and maximum donor
distance from their median. Donor spread is descriptive, **not an uncertainty
radius**: state, country and basin estimates can be much less precise than 2°.
Hatched map cells include estimates. `display_mapped` describes the combined
display coverage; `coordinate_approximate` distinguishes estimates. Original
coordinate filters and precise-location candidate screens exclude estimates.
Set `approximate_locations = FALSE` to render recorded coordinates alone.

**Study region.** The default mapped window is 100–50°W and 5–60°N. Pacific and
Adriatic/Mediterranean labels are excluded. Without coordinates, explicit
Caribbean/Gulf labels, or Atlantic ocean plus a supported western Atlantic country,
can establish inventory scope; otherwise geography remains unresolved. Coordinates
outside the window do not enter the default atlas. The audit retains the source
ocean, sea and country fields.

Recorded Gulf of Mexico/Caribbean sea labels determine region first. Otherwise,
small, explicitly coded approximate polygons divide the map into Gulf, Caribbean,
and remaining Atlantic sectors. These are screening partitions, not authoritative
marine boundaries. Coastal transition zones, countries spanning both oceans and
records without positions require review. Region assignments preserve their source
and can be overridden. Species totals count inventory lots even when coordinates
are missing; mapped completeness is reported separately.

**Availability.** Type specimens remain visible in the inventory and contribute
to the requested catalog-count threshold, but types, depleted lots and records
flagged as not found are excluded from assemblage/repeated-sampling screening.
The source export has no populated `Preservation Method`. A pre-1931 collection
date does not establish fixation history, DNA quality, accessibility, or permission
for destructive sampling. These must be verified before selecting study material.

## Reviewed corrections

Use `config/sampling_overrides.csv`, one row per catalog number. Supported fields:
`species`, `life_stage`, `year`, `longitude`, `latitude`, `region`, and required
`reason`. Blank fields leave original values unchanged. Stage values are `adult`,
`larva`, `mixed`, `unknown`; region values are `Atlantic`, `Caribbean`,
`Gulf of Mexico`, `Outside or unresolved`. Every correction is exposed in the audit.
Do not edit a generated CSV to make a lasting correction.

The initial override file contains two source-supported stage corrections:
USNM 105434 and 133799 explicitly describe larvae in their notes although their
preparation fields are empty. Each retains its catalog count of one specimen.

## Visualizations

Open `Output/SamplingAtlas/index.html` locally. This is a geographic map viewer with
species filtering, a recorded-year selector, previous/next year buttons, and
Play/Stop GIF controls for each populated life stage. No server or internet is
needed. Every selected year appears directly on a geographic map; the former
latitude/longitude-row matrices are no longer displayed. Expand “Show all year
maps” to see the individual PNGs together. PDFs remain optional downloads.

Combine species name, minimum dated specimens, life stage, region, minimum
distinct sampled years, and a coordinates-only checkbox to refine candidates.
Counts and years are recalculated for the selected stage and region together;
years shared by several lots or stages count once. Undated records never satisfy
these thresholds. The default is 50 dated specimens and one sampled year across
all stages and regions. Lowering the threshold only refines the original eligible
species pool; it does not admit species with fewer than 50 historical specimens.
The matching counts appear on each species card, and Reset restores the defaults.
Selecting a stage displays its maps. Region and coordinate filters select species;
the maps still display that stage’s full sampling distribution. Filter aggregates
are exported in `tables/filter_counts.csv` for inspection.

The viewer also attaches the existing life-history outputs by exact project
species name. Expand **Life-history filters** for water types, habitat tags,
water-column habitat, migration, fisheries importance, sexual system,
fertilization, reproductive guild, generation time, lifespan, maturity age and
maximum reported length. Numeric filters use inclusive ranges; missing values
only disappear when the relevant filter requires data. The availability selector
can instead show missing/withheld values. When it selects missing values, numeric
bounds are disabled. Category filters test complete tokens, not substrings.

Age traits retain their FishBase model labels. Maximum lengths pool sexes by
taking the largest reported value separately for each source length type; TL,
SL, FL and other source codes are never converted. Selecting a length type applies
both ranges and missingness to that type. With “Any type,” one matching
type-specific maximum suffices. Display rounding is three significant digits;
numeric comparisons use unrounded values with relative tolerance `1e-7` (scaled
by at least one unit) for source floating-point serialization.

The attachment lives in `Scripts/sampling_atlas_traits.R` and uses
`Output/LifeHistory/life_history_80_species.csv` by default. A custom configuration
may set `life_history` to an alternative CSV with the same fields and accompanying
evidence tables. Duplicate keys, invalid positive numeric traits, or traits
attached to a withheld match stop report generation. Unmatched species retain
their inventory rows with missing traits; project names are never replaced by
FishBase aliases. Source aliases and withheld matches are noted on species cards.

Trait snapshots, pooled lengths, evidence, references and input hashes are copied
into the atlas's `tables/` for standalone sharing. The normal index refresh updates
these without recalculating specimen counts or regenerating media. If the trait
source is absent on a first build, sampling outputs still work and the viewer
reports traits as not loaded. Build the downstream life-history outputs and refresh
to attach them. Primary-source review and regional applicability are pending;
read [life-history methods](life_history_workflow.md) before using traits to select
the final comparative design.

Each eligible species has:

- **Annual map PDFs per stage:** six geographic sample-size heatmaps per page;
  one panel per sampled year and a separate undated panel when needed.
- **GIFs per stage:** discrete frames with year, inventory count, mapped count,
  and a complete sampling timeline. The default skips unsampled years explicitly;
  `animation_years = "all"` instead inserts every calendar year. There is no
  interpolation. Empty stages have a text notice in the viewer.
- **Geographic PNGs per year and stage:** permanent files such as
  `species/Menidia_menidia/adult_frames/year_1892.png`, with a prominently printed
  year. The R renderer saves these PNGs before combining them into a GIF. Undated
  specimens have a separate `undated.png`; empty-stage placeholders are named
  `no_records.png`, never assigned a fabricated year.
- **PNG previews:** the first animation frame for quick inspection.

For older builds that discarded their temporary PNGs, the refresh script recovers
the displayed full-canvas frames from the existing GIFs using ImageMagick coalescing.
It retains original colors, years and geographic extent, and records report-only
provenance separately from the original analysis. Existing matrix PDFs may remain
on disk but are not part of the map viewer or new default builds.

Maps use a **2° longitude × 2° latitude grid** by default. This is specimen count
per cell, not equal-area density, survey effort, geographic occupancy, or abundance.
Cells are globally anchored using the floor of each coordinate divided by cell
width, so a given position always enters the same cell. Geographic cells and coarse
regions are not biological populations. Geographic extent is fixed at
**100–50°W and 5–60°N** across every species, stage and year; map color scales are
fixed across all years and stages of each species,
including undated records. Log-scaled colors reveal small and large counts together.
Unfilled cells mean no plotted sampling, not an observed biological absence.
Dark cell outlines improve visibility; hatching marks cells containing approximate
display positions. Frame totals separate recorded, approximate and still-unmapped
specimens. Colors count recorded plus estimated specimens in each display cell.

## Output tables and candidate selection

- `approximate_locations.csv` and `approximation_summary.csv`: estimated display
  coordinates for eligible lots, their evidence and counts by resolution level.
- `annual_display_geographic_counts.csv` and `undated_display_geographic_counts.csv`:
  the actual map counts, with recorded/approximate contributions separated. The
  existing `annual_geographic_counts.csv` and `undated_geographic_counts.csv`
  retain recorded-coordinate counts used for scientific screening.

- `records_audit.csv`: all original records with identity, counts, source fields,
  taxonomy/stage/date/coordinate provenance, inclusion reasons and eligibility.
- `species_summary.csv`: all included species, threshold status, date and map
  completeness, stage totals, geographic coverage and availability concerns.
- `candidate_screening.csv`: eligible species ordered by qualified historical
  regions, repeated historical cells, then dated/mapped specimen count. This is
  an explicit screening order, not an inferred biological suitability score.
- `annual_geographic_counts.csv` and `undated_geographic_counts.csv`: exact map
  values, summed specimens and contributing lot counts.
- `regional_stage_period_counts.csv`: inventories split by species, stage, region
  and period, including undated specimens separately.
- `regional_candidates.csv` and `selection_digest.txt`: generated by the downstream
  `summarize_sampling_candidates.R` script. These compare dated, mapped,
  availability-screened candidates within each basin and stage, report dependence
  on single lots/years, and highlight actual same-year multispecies opportunities.
- `cell_period_sampling.csv`: dated, mapped, availability-screened specimens by
  species/stage/cell/region/period.
- `repeated_historical_cells.csv`: species/stage/cells with at least 10 specimens
  in **each** of the pre-1900 and 1900–1930 periods by default; includes the smaller
  of the two sample sizes as a balance measure.
- `shared_assemblages.csv`: species co-occurring within each geographic cell,
  life stage and historical period, with at least 10 specimens per species.
  Shared period membership does not demonstrate collection in the same year.
- `shared_year_assemblages.csv`: the stricter counterpart requiring at least 10
  specimens per species in the same geographic cell, stage and collection year.
  This still requires checking exact dates and stations for true co-collection.
- `date_quality_counts.csv`, `stage_evidence_counts.csv`, `review_queue.csv`, and
  `excluded_records.csv`: uncertainty and exclusion audits.
- `artifact_manifest.csv`: every rendered species/stage, frame count, status,
  counts and relative file paths.
- `annual_frame_manifest.csv` and each species' `adult_frames.csv`/`larva_frames.csv`:
  each year PNG, specimen counts, geographic bounds and cell size. These make the
  fixed map extent and year-to-frame correspondence auditable.

Useful next selection criteria are directly supported by these tables:

1. **Choose replicated regional assemblages.** Start with shared cells in each
   basin, then find species present across several cells or regions. Inspect exact
   years/stations for genuine common collection events before calling them matched
   assemblages. Aim for the proposal's replicated assemblage design, not simply
   the species with the greatest pooled specimen totals.
2. **Favor temporal replication and balanced sample sizes.** Inspect the smaller
   period count in repeated cells and the year-by-year geographic maps. Multiple time points
   at one locality can be more useful than many specimens from one cruise.
3. **Keep stages comparable.** Evaluate adult/non-larval and larval opportunities
   separately. Pooling them could mask ontogenetic differences in location or
   sampling methods; maturity of unlabeled lots still needs checking.
4. **Discount uncertain feasibility.** Inspect types, unavailable specimens,
   uncertain taxonomy, missing locations/dates, and counts dominated by a single
   lot. Verify fixation history and pilot DNA recovery before final prioritization.
5. **Add biological contrast after sampling feasibility.** Build a curated traits
   table covering generation length, dispersal, habitat and exploitation history,
   plus modern resampling access and reference-genome availability. These fields
   are not in the current export, so the workflow does not invent them.
6. **Test sensitivity.** Compare 0.5°, 1°, and 2° cells, alternate historical period
   boundaries, and stricter year/stage/coordinate evidence. Retain candidates whose
   usefulness survives plausible choices. Grid results require a later locality-
   and habitat-aware check, especially around coastlines and regional boundaries.

The automated checks cover century handling, ambiguous date intervals, stage
classification, region assignment, duplicate genetic entries, threshold boundaries
and specimen conservation. Graphic review and GIF frame checks complement those
data checks; the workflow does not claim to validate the original museum records.
