# Species selection first pass

This is a reproducible historical sampling screen, not a final species panel. Existing atlas names and curation are reused; subspecies remain pooled under the atlas's accepted species keys.

## Results

Of 80 atlas inventory species, 73 have records entering this screen (1183 physical lots, 9743 catalogued specimens).

At a maximum site diameter of 20 km and at least 10 specimens per species/site/year/stage, 27 species occur in 12 multispecies site/year/stage groups across 8 candidate sites. Each group contains at least 3 species.

8 species occur at two or more candidate sites. These are site links, not proof of distinct regional replication or population identity.

The candidate-site graph has 3 connected components when sites are linked by shared focal species. Disconnected components require additional shared-species evidence or a design that explicitly accommodates the disconnected comparisons.

## Leading historical assemblage opportunities

Rows are sorted by species count, then specimens. Nearby or repeated rows may belong to one regional assemblage. The full table retains every group, including those below the multispecies threshold.

| Site | Locality label | Stage | Year | Species | Single-lot species |
| --- | --- | --- | --- | --- | --- |
| D20_S0061 | Key West, Florida | adult | 1885 | 5 | 4 |
| D20_S0050 | Florida: Tampa Bay; Gulf of Mexico | adult | 1885 | 5 | 2 |
| D20_S0133 | Chesapeake Bay, Thimble Light east northeast 3/4 east, Bell Buoy #15 southeast 1/8 east | adult | 1921 | 5 | 2 |
| D20_S0133 | Chesapeake Bay, Thimble Light east northeast 3/4 east, Bell Buoy #15 southeast 1/8 east | adult | 1892 | 4 | 1 |
| D20_S0093 | Winyah Bay, South Carolina | adult | 1915 | 3 | 3 |
| D20_S0282 | Hucares, Puerto Rico | adult | 1899 | 3 | 1 |
| D20_S0222 | Vineyard Sound | adult | 1892 | 3 | 1 |
| D20_S0061 | Key West, Florida | adult | 1884 | 3 | 0 |
| D20_S0050 | Florida: Tampa Bay; Gulf of Mexico | adult | 1898 | 3 | 1 |
| D20_S0133 | Chesapeake Bay, Thimble Light east northeast 3/4 east, Bell Buoy #15 southeast 1/8 east | adult | 1916 | 3 | 2 |
| D20_S0132 | 2.75 miles east 0.5 mile south from Point No Point Lighthouse, (Chesapeake Bay) | adult | 1916 | 3 | 0 |
| D20_S0120 | Gulf Stream, off Cape Lookout, North Carolina | larva | 1914 | 3 | 2 |

## Species investigation queue

This ordering prioritizes links among candidate sites, then multiple-lot explicit-year cells and repeated site/stage sampling, with alphabetical ties. It does not evaluate biology or modern availability.

| Species | Candidate sites | Shared cells | Repeated site/stage pairs | Sensitivity scenarios with a shared cell |
| --- | --- | --- | --- | --- |
| Alosa aestivalis | 2 | 3 | 4 | 24/72 |
| Fundulus similis | 2 | 3 | 1 | 48/72 |
| Menidia menidia | 2 | 2 | 0 | 40/72 |
| Alosa pseudoharengus | 2 | 3 | 2 | 24/72 |
| Anchoa cayorum | 2 | 2 | 0 | 44/72 |
| Membras martinica | 2 | 2 | 0 | 56/72 |
| Anchoa mitchilli | 2 | 4 | 1 | 42/72 |
| Brevoortia tyrannus | 2 | 2 | 0 | 24/72 |
| Menidia peninsulae | 1 | 2 | 1 | 48/72 |
| Fundulus heteroclitus | 1 | 2 | 1 | 36/72 |
| Lutjanus synagris | 1 | 2 | 1 | 24/72 |
| Monacanthus ciliatus | 1 | 1 | 1 | 36/72 |
| Centropristis striata | 1 | 1 | 0 | 28/72 |
| Haemulon plumierii | 1 | 1 | 0 | 24/72 |
| Lagodon rhomboides | 1 | 1 | 0 | 24/72 |
| Poecilia vivipara | 1 | 1 | 0 | 12/72 |
| Sparisoma radians | 1 | 1 | 0 | 12/72 |
| Tautogolabrus adspersus | 1 | 1 | 0 | 28/72 |
| Atherinomorus stipes | 1 | 1 | 0 | 32/72 |
| Caranx latus | 1 | 1 | 0 | 12/72 |
| Cheilopogon furcatus | 1 | 1 | 0 | 12/72 |
| Citharichthys spilopterus | 1 | 1 | 0 | 12/72 |
| Eucinostomus gula | 1 | 1 | 0 | 32/72 |
| Exocoetus volitans | 1 | 1 | 0 | 12/72 |
| Jenkinsia stolifera | 1 | 1 | 0 | 24/72 |
| Paralichthys dentatus | 1 | 1 | 0 | 12/72 |
| Stellifer lanceolatus | 1 | 1 | 0 | 36/72 |

## Sensitivity and interpretation

The 72 scenarios vary diameter (10, 20, 40 km), minimum specimens (10, 20, 30), minimum lots (1, 2), explicit-only versus all assigned years, and final year (1929, 1930). The atlas inventory species frame and site coordinate tree are held fixed, so comparisons measure screening choices rather than taxonomy or upstream eligibility changes.

Scenario membership is descriptive sensitivity, not a selection probability. Species outside the baseline queue can enter other scenarios; see sensitivity_species_membership.csv.

| Diameter km | Minimum specimens | Minimum lots | Candidate sites | Species in shared groups |
| --- | --- | --- | --- | --- |
| 20 | 10 | 1 | 8 | 27 |
| 20 | 20 | 1 | 5 | 15 |
| 20 | 30 | 1 | 3 | 9 |
| 20 | 10 | 2 | 4 | 11 |
| 20 | 20 | 2 | 1 | 3 |
| 20 | 30 | 2 | 0 | 0 |

Locations remain catalog centroids with unquantified accuracy. Complete-linkage bounds coordinate spread, but does not validate habitat, station identity, population connectivity or coastline barriers. Same-year proximity is not proof of the same collection event. Adult means non-larval with maturity unverified; stages are never pooled.

Catalog numbers, original names, station/date/locality/depth/gear and persistent record links are in screened_lots.csv. assemblage_species_evidence.csv gathers those source labels for each species contributing to a shared group. assemblage_date_station_review.csv identifies date labels and vessel/station/day labels shared by all qualifying species. These are evidence leads, not verified collection events; empty intersections can also reflect inconsistent formatting. Named locality labels describe the most frequently recorded label in a site, not authoritative site boundaries. No missing positions or dates are imputed.

The targeted record evidence queue contains 310 excluded lots for species represented in baseline multispecies groups. Feasibility requests cover museum access, preservation, modern matching, biological predictors, DNA recovery and statistical power; all remain pending until sourced evidence is entered.

## Reproduction

```bash
Rscript Scripts/build_species_selection.R
```

See [workflow documentation](../../docs/species_selection_workflow.md), [the protocol](../../docs/species_selection_plan.md), and [the species by site figure](species_site_matrix.pdf). Input checksums, the original atlas input manifest, resolved configuration and R session information accompany these results. No live queries, raw-data edits or atlas rebuilds occur.
