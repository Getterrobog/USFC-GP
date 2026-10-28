# Species selection progress and wider spatial review

Review prompted by concern that a 40 km radius was too restrictive, 12 October 2026.

## Where selection stands

The project has a frozen inventory of 80 species using existing cleaned names and
species-level subspecies pooling. The first historical screen identified 27
species in 12 shared year/stage groups at eight provisional sites. Its main
connected component has 21 adult/non-larval species across six sites; this is not
six independent regional assemblages. No final panel of 12–20 species has been
selected.

The [life-history extraction](life_history_workflow.md) attaches traits to 79 of
the 80 rows, including FishBase model generation times for 75. Original-study
verification and local applicability remain pending. The
[image catalog](fish_image_catalog.md) supports communication and source discovery;
image availability is not a species selection criterion. Museum-record Order and
Family are available for all 80 but are not independently modernized taxonomy.

The original feasibility register still records museum access, preservation
history, modern matching, traits/habitat validation, DNA recovery and power as
pending. The trait extraction is progress toward its evidence requirement, not a
completed pass. Most consequential next work is geographic/habitat review and
historical–modern matching, followed by confirmed access and a recovery pilot.
No requests to museums or collaborators have been sent by this workflow.

## Correct spatial interpretation

The existing baseline is **20 km maximum diameter**, with sensitivity cuts at
10, 20 and 40 km. None is a radius. The implementation uses complete-linkage
clustering of catalog coordinates; the cut bounds the maximum great-circle
distance between any two coordinates in a group. It does not draw circular
buffers about chosen centers. A 40 km radius circle can span 80 km, but a
pairwise-diameter threshold is not equivalent to a fixed-radius buffering method.

The original tight cuts tested local overlap. They were not supplied by the
proposal, nor established as ecological or population boundaries. They should not
serve as hard limits on discovering regional assemblages.

## New extent comparison

[The reproducible report](../Output/SpeciesSelectionSpatial/spatial_extent_report.md)
compares maximum diameters of 20, 40, 80, 160 and 240 km. It reuses the original
screened-lot table: 1,183 physical lots, 9,743 catalogued specimens and 73 of the 80
species. The other seven have no records passing that frozen screen. Broadening
spatial grouping alone does not reinstate excluded dates, positions or
availability flags. No new taxonomy cleaning or atlas rebuild occurs.

For the baseline count setting, each species must have at least 10 specimens in
the same site, year and stage; each shared group must contain at least three
species. The first and last year remain 1880 and 1930, and different stages remain
separate.

| Maximum diameter (km) | Species across all stage-specific groups | Adult/non-larval species | Provisional sites, all stages |
| --- | ---: | ---: | ---: |
| 20 | 27 | 24 | 8 |
| 40 | 32 | 29 | 9 |
| 80 | 43 | 41 | 13 |
| 160 | 50 | 47 | 11 |
| 240 | 56 | 53 | 12 |

The initial connected adult group of 21 is a subset of the 24 adult/non-larval
species at 20 km. These quantities should not be interchanged. Adult means the
atlas non-larval category, with maturity unverified.

Requiring at least **20 specimens from two lots** per species/site/year/stage
leaves 3, 3, 10, 15 and 16 species at the respective diameters above. Those are
all-stage results with stages still separate, not validated genomic sample sizes.
Wider groupings both recruit additional historical comparisons and merge nearby
sites, so site count need not increase monotonically. Multiple geographic sites
within Chesapeake Bay or Puerto Rico do not automatically provide independent
regional replication.

The 160 km setting adds 23 species relative to the original 27, including winter
flounder (*Pseudopleuronectes americanus*), witch flounder (*Glyptocephalus
cynoglossus*), schoolmaster snapper (*Lutjanus apodus*) and northern pipefish
(*Syngnathus fuscus*). These are investigation leads, not nominations for the final
panel. Full membership is retained for all 80 species at each extent.

Candidate-site evidence records coordinate spread, source locality labels,
recorded depth labels and catalog regions. At 240 km, one candidate cluster spans
more than one catalog region. Absence of this flag at smaller extents does not
establish habitat homogeneity: catalog region labels are coarse, and depth units
are not standardized or inferred here.

## Recommended design revision

Use **broad regional discovery units with nested local sampling units**. The new
160 and 240 km comparisons are useful discovery scales to carry into review;
neither is an automatically accepted biological radius or pooling rule. Define
named regional assemblages from coastal geography, habitat/depth, environmental
exposure and practical modern resampling, then retain localities and collection
events inside them. Examples already supported as search areas include Chesapeake
Bay, southern New England, the Carolinas, Florida and Puerto Rico; subdivisions
must follow evidence rather than a fixed count of regions.

For each promising species-by-region comparison, review whether historical and
modern samples can represent comparable populations and habitats. Keep estuarine,
coastal and offshore/deep-water records distinguishable. Broad geographic pooling
can change what population is being compared. Spatial and temporal population
structure has been observed in marine fishes; the primary empirical study
[Spatial and temporal genetic variation in an exploited reef fish](https://pmc.ncbi.nlm.nih.gov/articles/PMC8127707/)
illustrates why proximity or a regional name cannot alone establish equivalent
sampling units. This source supports the need for review, not any particular km
threshold.

Prioritize overlap among species with contrasting life histories **within the
same reviewed region**, and repeated species across reviewed regions. Then assess
modern access, museum availability, preservation, recovery and power before
choosing the proposal's 12–20 species across 4–6 assemblages. Keep the complete 80
as the candidate universe. Missing traits or images should not silently exclude
poorly studied species.

The current screen still demands same-year overlap. Test any proposed multi-year
historical windows separately after geographic review, retaining original dates
and generation-time context. Changing space and time together would obscure
which choice creates an apparent improvement.

## Reproduction and validation

```bash
Rscript Scripts/compare_selection_spatial_extent.R
Rscript tests/test_species_selection.R
```

[Configuration](../config/species_selection_spatial.R) and the analysis script are
versioned. Outputs are isolated in `Output/SpeciesSelectionSpatial/`; the original
27-species queue, 80-species roster and associated trait/image tables are unchanged.
The full grid has 120 scenarios: five extents, three count thresholds, two lot
thresholds, two date-evidence modes and two final years. All 48 scenarios shared
with the original release reproduce both original counts and exact species
membership. Every baseline-like extent conserves input lots/specimens and satisfies
its declared diameter bound. Input checksums and R session metadata are retained.

These are descriptive sensitivity results. Scenario frequencies are not selection
probabilities, and wider cutoffs have not been optimized against genomic outcomes.
