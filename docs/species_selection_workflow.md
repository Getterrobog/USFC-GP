# Historical evidence screening for species selection

This is the first implemented step of the [selection protocol](species_selection_plan.md).
It reuses the completed sampling atlas and cleaned accepted species names, with
subspecies pooled under those species. It adds bounded geographic comparisons,
same-year multispecies screening, sensitivity analysis and evidence requests.
The resulting investigation queue is not a final panel or a claim of DNA feasibility.

## Run and review

From the repository root, using base R only:

```bash
Rscript tests/test_species_selection.R
Rscript Scripts/build_species_selection.R
```

The runner also resolves paths correctly when called from another directory.
Read [the generated report](../Output/SpeciesSelection/selection_report.md),
[species investigation queue](../Output/SpeciesSelection/species_investigation_queue.csv)
and [species by site figure](../Output/SpeciesSelection/species_site_matrix.pdf).
Configure the analysis in [config/species_selection.R](../config/species_selection.R).
Separate configurations and outputs can be supplied with `--config=path` and
`--output=path`. Reruns replace generated files of the same name; enter lasting
corrections in the existing reviewed atlas override workflow, not generated CSVs.

The analysis reads `Output/SamplingAtlas/tables/records_audit.csv` directly. It
does not call `prepare_atlas_records`, repeat species cleaning, query taxonomy
services, install packages or regenerate the atlas's graphics. The original export
is read only to append station, cruise, locality, depth, gear, preservation and EZID
evidence. Row ID and catalog number must both agree with the atlas. Source CSV
checksums must match the atlas's manifest; a changed source stops the run.

## Frozen names and the screening frame

Every name is the atlas's accepted species key. Original identifications and
taxonomy status are retained. No new synonym decisions are made. Current atlas
keys must be binomials; a future atlas containing unpooled trinomials stops with an
explicit message instead of silently treating subspecies as different species.

The first pass holds the existing 80-species atlas inventory frame fixed. Its
upstream rule is at least 50 dated specimens through 1930 across stages and the
study area. For this downstream screen, retain only atlas-included physical lots
with mapped coordinates, assigned year in 1880–1930, and no atlas availability flag.
Each physical catalog number must occur once. This gives 1,183 lots of 73 species
and 9,743 catalogued specimens for the reviewed snapshot.

The 1930 endpoint preserves the existing atlas scope; sensitivity through 1929
tests the protocol's proposed narrower window. Holding atlas eligibility fixed is
intentional reuse: this analysis does not infer that the other taxa in the raw
export are scientifically unsuitable. Targeted reconsideration of excluded taxa
remains possible if needed to fill a documented design gap.

## Geography and sample units

Construct one common tree of unique coordinates, sorted by longitude and latitude,
using spherical great-circle distances with Earth radius 6371.0088 km and complete
linkage. Cut that tree at 20 km for the baseline and at 10 and 40 km for sensitivity.
Complete linkage guarantees that the largest distance between any two retained
coordinates within a group is at most the cut distance. This avoids the chain
effect of the old connected-component clustering. Coordinates with identical
values appear once in the tree, regardless of specimen or species count.

`site_id` identifies a provisional geographic group for the fixed snapshot and
diameter. It is deterministic, but not a permanent biological locality identifier.
The same tree is used across count, date and lot-count scenarios; those scenarios
remove evidence from fixed groups rather than redefining group boundaries.

Coordinate spread is not coordinate accuracy. The source positions are centroids
without quantified uncertainty. Clustering does not enforce habitat, depth,
coastline barriers or population connectivity. Different atlas region labels may
occur in one group and are retained. A group's display locality is the most
frequently recorded nonblank locality label across its screened lots, not a new
georeferencing decision. All constituent labels and coordinate bounds are exported.

Aggregate counts within **accepted species × site × life stage × individual year**.
Never combine eras or life stages to meet a threshold. Adult means adult/non-larval
inventory, with maturity unverified. Same-year spatial proximity supports an
investigation opportunity, not proof of a common haul, habitat or exposure.

A baseline species cell qualifies with at least 10 catalogued specimens and one
lot. A multispecies group requires at least three independently qualifying species
in the same site, stage and year. Thresholds are exploration settings, not powered
sample-size requirements. Two lots do not necessarily represent two independent
collection events; station/date/gear review is still needed.

## Ranking and sensitivity

All 80 atlas species remain in `species_investigation_queue.csv`, including those
without qualifying or multispecies cells. Order by number of baseline shared
sites, then shared cells with multiple lots and explicit years and validated/corrected
taxonomy, then repeated site/stage pairs, then alphabetically. No biological trait,
genomic outcome or modern availability is inferred from this ordering.

`repeated_site_stage_pairs` counts species/site/stage combinations with qualifying
samples in at least two individual years anywhere in the screened frame. It does
not require that all those years qualify as multispecies groups. Matrix entries
count qualifying year/stage cells within multispecies groups; zeros indicate no
qualifying collection evidence, not natural absence.

The 72 scenarios cross three diameters (10/20/40 km), three count thresholds
(10/20/30), one/two lots, all assigned/explicit-only years, and last year 1929/1930.
Explicit-only excludes vessel-inferred and manually overridden years from that
scenario; it does not imply those dates are incorrect. Membership frequencies are
counts across this chosen grid, not probabilities or statistical confidence.

`site_connectivity.csv` labels graph components, linking candidate sites when they
share a qualifying species. Inspect stages and geography before interpreting links
as regional replication. In particular, two Chesapeake sampling groups are not
automatically two independent regional assemblages.

## Evidence products and next decisions

| File | Use |
| --- | --- |
| `record_disposition.csv` | Every atlas row with one primary downstream reason; consult the atlas for all upstream flags |
| `screened_lots.csv` | Species keys, original names, provenance, dates, stations, localities, gear/depth and museum links for every counted lot |
| `site_evidence.csv` | Bounds, verified coordinate diameter, recorded region/locality labels for all geographic groups |
| `species_site_year_cells.csv` | Full cell counts, lot concentration, date/taxonomy/stage flags, catalog numbers and threshold result |
| `assemblage_candidates.csv` | All qualifying-species groups, including groups below three species |
| `assemblage_species_evidence.csv` | Source dates, stations, vessels, depths, gear and localities for each qualifying species in each shared group |
| `assemblage_date_station_review.csv` | Literal date and vessel/station/day labels common to all qualifying species in each shared group |
| `species_investigation_queue.csv` | All atlas species, baseline design utility, scenario membership and pending feasibility gates |
| `species_site_matrix.csv` and PDF | Crossed historical sampling design and its gaps |
| `site_connectivity.csv` | Connected components of the shared-species site graph |
| `record_evidence_gaps.csv` | Unresolved dates/locations or availability flags for baseline investigation species |
| `feasibility_requests.csv` | Species-specific museum, preservation, contemporary access, trait, recovery and power evidence needed |
| `sensitivity_scenarios.csv` | Complete parameter grid and resulting cell/site/species counts |
| `sensitivity_species_membership.csv` | Species entering multispecies groups in each scenario, including alternatives to the baseline queue |

The first pass yields 27 species in 12 groups at eight provisional sites. Eight
species link two or more sites. The evidence queue identifies 227 lots with
unresolved locations and 83 with unresolved dates for these investigation species;
these are mutually exclusive primary reasons and may conceal additional missing
fields. Review the underlying records before treating a repaired field as sufficient.

The shared-species graph separates into three components. Its largest contains
**21 adult/non-larval species at six sites**: Tampa Bay, Key West, Winyah Bay,
Vineyard Sound and two Chesapeake groups. This is the first connected set to
investigate for the main design. The other components are three larval species
off Cape Lookout and three adult/non-larval species near Hucares, Puerto Rico.
They need additional connecting comparisons or an explicitly separate design.
Two Chesapeake sites do not establish two regional replicates; the six sites
suggest five named regional leads requiring ecological review. The 21 species
are still an investigation set, not an approved panel of 12–20.

The date/station review only removes trailing parenthetical annotations when
comparing date labels; it does not parse new dates or infer centuries. Common
date labels can be ranges or partial dates. Common station/day keys require a
day-shaped date string and nonblank vessel/station. Different formats can give
false negatives, while a common station/day still needs haul/voyage/habitat checks.
For example, Winyah Bay's three species in 1915 were not all recorded on the same
day, and the southern Chesapeake group's three species in 1916 span January and
March. Their same-year counts should not be described as one collection event.

The largest design constraint is sensitivity to per-cell sample size and lot
replication. At 20 km, increasing the minimum count from 10 to 20 retains 15 species
at five sites; requiring two lots as well leaves three species at one site. This
does not establish that a two-lot rule is necessary or that one-lot samples fail.
It identifies a dependence that the pilot, kinship analysis and sampling-event
review must address.

Proceed with station/date/habitat review of the eight sites and targeted resolution
of the 310 record gaps, then collect modern-match and museum-availability evidence
for the 27 species. Treat the two Chesapeake sites as a regional design question,
and keep the Cape Lookout larval opportunity separate from the adult/non-larval
comparisons. Choose 4–6 regional assemblages and 12–20 species only after those
checks and pilot/power assessment. Every feasibility gate remains explicitly
pending; the workflow does not simulate laboratory results or send requests.

## Reproducibility and validation

The run saves its configuration, R session, original atlas input manifest, input
checksums and output checksums. It checks that inputs do not change during the run,
that lot and specimen totals reconcile across cells, that all 80 species remain in
the queue, and that within-site diameters satisfy the declared limit. MD5 here is
an integrity/reproduction fingerprint, not an authentication mechanism.

Tests cover geographic chains, distance symmetry and scale, deterministic grouping,
single-coordinate groups, separate years/stages, count conservation, minimum-lot
requirements, multispecies co-occurrence, empty groups, raw-record linkage and
disconnected site graphs, shared date labels and distinct days. All checks passed
for this implementation. An independent invocation from `/tmp` reproduced all 16
analytical/provenance CSVs and the generated report byte-for-byte; input and output
checksums also matched. The matrix figure was visually inspected. Compare CSV
analytical outputs for repeatability; PDF
metadata and run environment records can vary even when results are identical.
