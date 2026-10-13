# Species selection plan for USFC GP

Draft for scientific review, 12 October 2026. This protocol translates the [proposal](../background/one_page_proposal.txt) into a documented process for selecting approximately **12–20 species across 4–6 regional assemblages**. It does not designate final species. Numerical targets below are proposed starting points unless attributed to the proposal; freeze them after feasibility and power assessment and before analysis of temporal genomic responses.

**Select assemblages and species jointly.** Establish credible historical sampling events and contemporary sampling opportunities, then choose a portfolio supporting biological contrasts within regions and replication of species across regions. Large pooled museum counts alone establish neither property.

**Build on the completed curation.** Reuse the existing cleaned species names,
catalog-specific corrections, atlas inventory and screening tables. New work should
resolve missing or conflicting evidence and add the comparisons needed by the
proposal. The selection unit is the accepted species: pool subspecies under that
species while retaining their original identifications in the audit trail.

## Requirements of the three aims

| Aim | Required contrast | Consequence for selection |
| --- | --- | --- |
| 1 Reconstruct trajectories | Historical and modern samples of the same taxon and comparable population; extra historical intervals where available | Count usable independent individuals separately by species, locality and time; require a practical modern match |
| 2 Separate drift and selection | Temporal change interpretable under demographic, migration and technical uncertainty | Require an appropriate assay, pilot recovery and simulations of neutral and alternative models; assess ancestry and kinship |
| 3 Predict differences among species and regions | Contrasting generation times and biology under comparable regional change | Optimize a crossed species-by-region design and held-out prediction; never select for an observed direction or significance of genomic change |

The strongest feature is comparison of co-occurring species with different biology. The principal vulnerability is confusing collection richness with comparative replication. A regional label does not guarantee shared exposure: habitat, depth, migration and season matter. Historical diversity and effective population size must be estimated from genomic evidence, not collection counts. Two time points establish net change; more detailed trajectories require repeated historical samples. Regional forcing is observational, not a randomized treatment.

## Current evidence and the atlas

Implementation update: the [historical evidence screen](species_selection_workflow.md)
now reuses the atlas to evaluate bounded sites and same-year species overlap under
72 scenarios. It identifies 27 species for investigation, including a connected
21-species set across six adult/non-larval sites. See the
[generated results](../Output/SpeciesSelection/selection_report.md). This completes
the first downstream screening analysis; event/habitat validation, museum and modern
access, traits, laboratory recovery and power remain pending. The screen does not
declare those later gates complete.

The [repository review](repository_review.md) and [audit](../Output/SelectionAudit/audit_summary.json) establish the legacy baseline. Its 96 candidate species occur in 1,027 rows representing 1,017 catalog numbers. Of 168 legacy spatial clusters, 36 have recorded diameters greater than 40 km, with a maximum of 249.43 km. Preservation method is blank in all 7,166 raw records. These species are a discovery list, not an eligible sampling frame.

Use the new [sampling atlas](sampling_atlas.md) as an exploratory inventory and visualization layer. Its documented default is at least 50 dated specimens per species through 1930, with geographic grids and separate stage categories. That threshold is a catalog-inventory screen, not a per-population genomic sample-size requirement. Its broad early/late historical periods and three coarse regions do not establish the proposal's final sampling intervals or 4–6 assemblages. Preserve its flagged vessel-inferred dates and unverified maturity labels when importing tables.

Use the existing atlas audit records, review queues and overlap tables as the working inventory. Consult the raw export for provenance and targeted gap resolution. Review excluded or below-threshold taxa only where a documented selection requirement warrants it, preserving completed cleaning and correction decisions. Add event-level evidence and inferential feasibility to this inventory; do not recreate the taxonomy or atlas workflows.

## Stage 1 Reuse curation and resolve remaining gaps

Archive the original export with query, download date, institution, rights and checksum. Recover unknown acquisition details from the original investigator; filesystem dates are not substitutes. Retain original field text and persistent museum identifiers.

Establish the relationships among database rows, catalogued lots, collection events and individual specimens before summing counts. Repeated catalog numbers may represent images, genetic preparations, duplicate exports or genuine subrecords. Neither summing nor deleting them blindly is justified. The atlas already separates physical lots and flags duplicate physical identifiers; validate that reconciliation against museum records. Record each resolution, supporting evidence, reviewer and date. Assign individual identifiers during physical inventory; do not fabricate independent individuals from a lot count.

Reuse the completed species-name cleaning as the taxonomic baseline. The existing
atlas already applies `Output/Files/species_validation_results.csv`, then
catalog-specific `Valid.Name` assignments from
`Output/Files/All_Ships_Updated.csv` and `Output/Files/HumanSearch.csv`, with reviewed
`config/sampling_overrides.csv` entries taking final precedence. Preserve that
order and fingerprint the source files. Do not rerun the live scraper or replace
reviewed names merely because the original catalog uses a different name. Record
the chosen name's source; review only unresolved names, incompatible assignments
or new records lacking a reusable match. Recover authority/version information
where available and label missing provenance without repeating the cleaning.

**Pool subspecies at the accepted species level.** Apply existing accepted-name
mapping first, then reduce any remaining accepted trinomial to its genus and
species. All subspecies of that accepted species share one species key for counts,
eligibility, maps and selection; they are not separate candidate taxa. Retain the
verbatim identification, existing cleaned name and source mapping so the pooling
is reversible and reviewable. For example, subspecies still accepted within
`Anchoa mitchilli` contribute to the same species total. If existing curation has
assigned a historical subspecies to a different accepted species, preserve that
decision rather than undoing it by truncating the original catalog name. Pooling
taxonomic labels does not collapse separate sites, events, periods or life stages.

Parse dates once into lower and upper bounds, precision and evidence. Preserve ranges and partial dates. Two-digit years require vessel/voyage/station evidence; unresolved centuries remain unresolved. Use **1880–1929 as a proposed primary historical window**, with sensitivity through 1930 to align with the atlas. Assess earlier collections and 1931–1947 separately as possible extensions. A year cutoff is not evidence of fixation chemistry. Undated records stay pending and cannot satisfy temporal replication.

Georeference events with original coordinates or documented corrections, datum, uncertainty and method. Country/ocean centroids cannot establish site-level replication. Require unique vessel/voyage/station/date matches for log corrections, not station number alone. Adopt interoperable event, location and uncertainty fields from [Darwin Core](https://dwc.tdwg.org/terms/), alongside project-specific evidence and review fields.

**Deliverable and gate:** a reconciled record/event inventory and correction ledger. Every input row is retained, excluded or pending with reasons. Unresolved identity, date or location uncertainty cannot count toward a confident historical sampling cell.

## Stage 2 Define assemblages and temporal sampling cells

Explore the northeastern US shelf and estuaries, Mid-Atlantic, southeastern US, Gulf of Mexico and Caribbean as search strata. These are not five predetermined assemblages. Delimit the eventual 4–6 assemblages using verified localities, ecological boundaries and modern access, with versioned polygons.

Use a common event/site system across species. A sampling cell is **species × local sampling unit × time interval**, nested within an assemblage. Distinguish species from the same collection event from species collected nearby at different times. Retain vessel, voyage, station, season, habitat, depth, gear and life stage. Lots from one event are not independent spatial replicates. Call these sampling units until demographic connectivity is supported; grids and distance clusters are not biological populations.

Compare proposed maximum within-unit diameters of 10, 20 and 40 km, respecting ecological boundaries and taxon-specific population biology. Do not use unconstrained single-linkage chains or interchange radius and diameter. If coordinate uncertainty crosses unit boundaries, propagate plausible membership or leave assignment pending. Include a sensitivity analysis using only directly documented positions.

Explore 5-, 10- and 20-year historical intervals before response analysis. Choose intervals compatible with generation times and model assumptions, or model individual sampling dates explicitly. Fifty fish accumulated over four decades are not fifty fish from one temporal snapshot. Match season and life stage, especially for migration and schooling cohorts; the atlas's adult/non-larval category does not establish sexual maturity.

Build an assemblage-by-species matrix showing distinct lots, events, catalogued individuals, curator-confirmed available individuals and eventually independent genomes passing quality criteria. Separate eras and show uncertainty. Map event locations with uncertainty and plot date intervals. Missing cells indicate unavailable or unknown evidence, not zero natural abundance.

**Deliverable and gate:** verified multispecies historical overlap and plausible contemporary matches for each proposed assemblage. The matrix must expose whether species, region, era and preservation/technical batch can be distinguished.

## Stage 3 Apply feasibility gates

Use `pass`, `fail` and `pending`; optional components may be `not_applicable`. Missing required evidence is pending. Apply decisions at specimen, cell or species level as appropriate: one failed specimen need not exclude a species with adequate alternatives.

| Gate | Evidence needed |
| --- | --- |
| Identity and scope | Reviewed taxon; compatible habitat and Western Atlantic geographic scope |
| Historical match | Dated and georeferenced sampling cell within explicit uncertainty tolerances |
| Museum availability | Verified individuals/tissues, curator-reviewed availability and destructive allowance; type/depleted material handled explicitly |
| Contemporary match | Locality, season, gear, field lead/partner, access and permit pathway, budget, existing-tissue compatibility and contingency |
| Genomic recovery | Pilot evidence of adequate endogenous sequence, library complexity and comparable usable sites for the chosen assay |
| Sample size and inference | Independent genomes expected to meet endpoint-specific simulation criteria |
| Comparative predictors | Traceable generation-time and environmental-exposure evidence at an appropriate scale, with uncertainty |

Document institution-specific arrangements using the [NMNH collections access guidance](https://naturalhistory.si.edu/research/vertebrate-zoology/fishes/collections-access). Catalog counts are upper bounds until availability is verified. No requests have been sent as part of this review.

Track otolith and phenotype feasibility separately: individual identity, preservation effects, tissue integrity, measurement protocol and destructive conflicts. This is a complementary component, not an automatic exclusion of otherwise useful genomic taxa unless the team makes it a core requirement before selection.

**Deliverable and gate:** evidence dossiers for candidate cells, with explicit pending items and a feasible modern sampling route. No candidate passes by assuming unknown preservation or unconfirmed access.

## Stage 4 Pilot recovery and determine sample sizes

An initial pilot of **3–5 individuals per major preservation/collection stratum** among leading cells, across at least two lots/events where available, is a proposed discovery design. It does not establish that every lot of a species shares one recovery rate. Estimate uncertainty, use hierarchical pooling only when justified, and retain failed extractions and low-success strata.

Record tissue quantity, extraction/library methods, blanks and controls, endogenous fraction, fragment length, damage, contamination, duplicate rate, library complexity, projected coverage, callable sequence and cost per usable genome. Pilot modern libraries too. Balance species and eras across technical batches where protocols permit; retain unavoidable protocol differences. Decide between low-coverage whole genomes and standardized capture after endpoint-specific benchmarking. Genotype likelihoods address depth uncertainty but do not remove reference or damage bias, concerns emphasized in [temporal genomics](https://pmc.ncbi.nlm.nih.gov/articles/PMC12142728/).

Compare **10, 20 and 30 independent genomes per species/site/time cell** as initial simulation and cost scenarios, not validated adequate sample sizes. Estimate the probability of obtaining the required number from the permitted inventory. Under independent recovery with known probability `p`, use `Pr[Binomial(n_attempted, p) >= n_required]`. Use a beta-binomial or lot-level model for uncertain/correlated recovery. `n_required / p` is only an expected-value calculation. A completion probability of 0.90 is a proposed review target, subject to the destructive allowance.

Simulate the planned analyses using sampling times, generation-time uncertainty, overlapping generations, plausible effective sizes, migration/admixture, kinship, coverage, missingness, damage, reference bias and realistic linkage. Include null and biologically meaningful alternatives. Archive seeds, parameters, failures and Monte Carlo uncertainty. Start with 1,000 replicates for critical null scenarios and increase when simulation error affects decisions.

Evaluate separately: precision and bias of diversity changes; identifiability and interval coverage of effective size; false positives and power for selection under demographic misspecification; and comparative effect recovery/prediction under the actual crossed design. Investigators should specify minimum meaningful effects and acceptable interval widths before response analysis. Consider 80% power and a prespecified 5% error/FDR target as initial proposals requiring validation; genome-scan multiplicity needs its own control. Large effective sizes may permit only bounds. An uninformative estimate is not evidence of stability.

Use compatible callable-site definitions, invariant sites where needed, matched filtering and downsampling checks across eras. Reference availability is an explicit feasibility/cost factor, not a silent preference for well-studied species. Record assembly accession/version, quality, divergence and resources for any new reference.

**Deliverable and gate:** per-cell permitted sample counts, recovery uncertainty, cost and endpoint-specific adequacy. Core comparisons require support for their intended inference; extra endpoints may remain exploratory.

## Stage 5 Choose a portfolio of species and assemblages

Collect biological predictors independently of temporal genomic responses. For generation time, age at maturity, longevity, body size, habitat, migration and exploitation, retain units, population context, uncertainty, source and measured/inferred status. [FishBase](https://www.fishbase.se/search.php) can identify sources; trace consequential values to their underlying studies. Do not equate maturity age with generation time. Audit missingness across taxa/regions before imputation.

Implementation update: the [life-history workbook](../Output/LifeHistory/life_history_80_species.xlsx)
now retains all 80 project species, with sourced traits attached to 79 and model
generation times for 75. The [extraction methods and audit](life_history_workflow.md)
document source snapshots, taxon aliases, units, missingness and quality flags.
Primary-study verification and local applicability remain pending; this database
extraction does not pass the traits-and-habitat feasibility gate.

Extract environmental exposure over the actual interval and habitat. [NOAA ERSST](https://www.ncei.noaa.gov/products/extended-reconstructed-sst) is a possible broad-scale temperature source, not automatic evidence for estuarine or bottom-temperature exposure. Evaluate local/depth-relevant observations and fisheries histories separately, preserving product version and uncertainty. Avoid fitting several regional drivers that covary across only 4–6 assemblages.

Represent eligible species and assemblages as a bipartite graph: an edge requires an adequate historical–modern comparison. Evaluate portfolios of 12–20 species and 4–6 assemblages under the actual budget. Proposed design goals are at least three focal species per assemblage, at least half the species represented in two or more assemblages, and a connected graph. Report achieved values and explicit exceptions. Connectivity alone does not guarantee estimability: inspect predictor overlap, design-matrix confounding and dependence on individual species/regions.

Use a transparent constrained search. First satisfy hard feasibility and budget constraints, then maximize adequately powered paired comparisons, cross-region links and prespecified biological contrasts. Among scientifically comparable designs, favor temporal replication and lower cost. Freeze ordering and tie-breaks before response analysis. Publish feasible alternatives, including a conservative portfolio using high-confidence metadata and lower-bound recovery. If weighted scores are adopted, disclose formula, normalization, missing-data treatment and weight sensitivity.

Seek biological contrasts within assemblages and repeated species across environmental contrasts. Do not confound short-generation taxa with one region and long-generation taxa with another. Account for shared ancestry when assessing comparative replication. With 12–20 species and 4–6 assemblages, use a small prespecified predictor set and regularization; more SNPs or fish do not increase independent species or regional replication.

Budget the complete design. An illustrative 16 species averaging two assemblages, two eras and 20 usable individuals per cell requires **1,280 usable genomes**, before failures, reference genomes or extra historical intervals. This is scale arithmetic, not a recommended allocation. Include curation, fieldwork, assays, sequencing, analysis and contingency. If no portfolio satisfies scientific and budget constraints, document the tradeoff and revise scope before freezing selection.

Choose alternates for the same design function. A replacement must preserve specified biological contrasts, regional links and assay feasibility where possible. Substitution is allowed for prespecified feasibility failures, never for an uninteresting response.

**Deliverable and gate:** justified core species and alternates, specimen targets by cell, costs, uncertainties, simulation evidence and reasons for every inclusion, exclusion or pending decision.

## Stage 6 Freeze decisions and protect inference

Preregister final eligibility rules, polygons, date windows, quality criteria, hypotheses, endpoints, neutral models, portfolio, alternates and amendment rules before testing temporal outcomes. Pilot recovery may inform feasibility; disclose any biological pilot outcomes already seen. Do not favor species showing loss, gain or selection.

Keep diversity change and adaptive allele-frequency change as separate responses. Nonsignificance does not establish stability. Estimate both calendar-time and per-generation change with uncertainty. Regressing a change score on the same noisy historical estimate contained in that score creates mathematical coupling; use a joint measurement-error model or validated alternative and simulate this artifact. Distinguish effective size from census size and assess migration/structure in interpretation.

Predefine leave-one-species-out and leave-one-assemblage-out prediction. Withhold all response records for each held-out unit, including repeated times. Fit scaling, imputation, predictor selection and tuning inside training folds. Historical genomic state may be a held-out predictor if that matches the declared task, while the contemporary trajectory remains unavailable during fitting. Describe this as prediction conditional on historical information, not prediction for entirely unmeasured species. Compare simple baselines, interval calibration and predictive error. [Roberts et al.](https://doi.org/10.1111/ecog.02881) explain validation under temporal, spatial and hierarchical dependence. Four to six regional folds provide limited evidence of geographic generality.

Evaluate robustness to location/date tolerances, temporal pooling, independent counts, recovery rates, uncertain traits and omission of species/regions. Publish selection frequencies and design metrics across plausible scenarios. Describe generality to the accessible assemblages rather than claiming representativeness of all Western Atlantic fishes.

## Reproducible implementation and review package

Extend the R-centered atlas with noninteractive stages, project-relative paths and explicit dependencies, for example an R `targets` workflow and Quarto report. Pin R dependencies with `renv`, any Python dependencies separately, and genomic/system tool versions. These are future implementation recommendations; the new descriptive audit needs only Python's standard library.

Separate immutable raw snapshots, derived tables and manual evidence. Version thresholds, polygons, time windows, seeds and analysis choices. Cache external responses with query and retrieval metadata. A clean-checkout run should reproduce derived results without interactive prompts or new queries. Record commit, input/config hashes, software versions, command, logs and output hashes. Use distinct directories for frozen releases; local libraries and credentials do not belong in release artifacts.

| Planned artifact | Required content |
| --- | --- |
| Source manifest | Query/source, retrieval date, rights, version and checksum; unknown provenance flagged |
| Records and correction ledger | Stable row/lot identifiers, original/normalized fields, old/new values, evidence, reviewer/date |
| Events and polygons | Date bounds, coordinates/uncertainty, voyage/station, habitat and versioned assignment |
| Individual inventory | Individual-to-lot linkage, available tissue, access, phenotype/otolith status and laboratory provenance |
| Traits and exposures | Taxon/region/time keys, units, uncertainty, methods and sources |
| Sampling cells | Counts by evidence tier, underlying IDs, recovery estimates and modern match |
| Pilot and simulations | Controls, failures, recovery/cost uncertainty, parameters, seeds and endpoint performance |
| Decision ledger | Entity ID/type, gate, status, reason code, evidence, protocol version, decision date, reviewer and amendment link |
| Portfolio comparison | Evaluated designs, constraints, costs, alternatives, robustness and replacements |
| Review report and archive | Exclusion flow, maps, timelines, overlap matrix, missingness, sensitivity, methods and persistent identifiers |

Use explicit reason codes, including `TAXON_UNRESOLVED`, `DATE_UNRESOLVED`, `LOCATION_UNCERTAIN`, `OUTSIDE_SCOPE`, `DUPLICATE_UNRESOLVED`, `ACCESS_UNCONFIRMED`, `MODERN_MATCH_UNCONFIRMED`, `RECOVERY_INADEQUATE` and `POWER_INADEQUATE`. Retain all reasons and identify a primary gate for nonoverlapping exclusion counts. Publish the rules behind the codes.

Test century ambiguity, date ranges, reused station numbers, duplicate catalog representations, malformed counts, ambiguous taxonomy joins, spatial chains, uncertainty across boundaries and filtering before sample-size qualification. Assert unique specimen allocations and row-disposition conservation. Check agreement among tables, maps and figures. An independent analyst should rerun a frozen release and inspect inclusion/exclusion evidence against primary records.

Archive code, tabular data, dictionaries and workflows with persistent identifiers and appropriate licenses. When generated, link sequence/BioSample accessions to specimen identifiers. Explain access restrictions while preserving public metadata where permitted, following the provenance and reuse principles in [FAIR](https://pmc.ncbi.nlm.nih.gov/articles/PMC4792175/).

## Milestones and responsibilities

These are roles to assign, not commitments from named collaborators.

| Order | Lead roles | Deliverable |
| --- | --- | --- |
| 1 | Data lead and collections specialist | Reconciled identities, dates, locations and correction/exclusion ledger |
| 2 | Spatial analyst and field lead | Shared events/sites, overlap matrix and modern sampling plans |
| 3 | Collections, taxonomy and genomics leads | Candidate dossiers, assay alternatives, traits/exposures and budget |
| 4 | Laboratory and quantitative leads | Recovery pilot and simulation-supported cell targets; revise allocation as needed |
| 5 | Investigators and independent methods reviewer | Portfolio, alternates, documented tradeoffs and prediction design |
| 6 | Data lead and investigators | Versioned protocol and independently reproduced release |

The immediate next step is to use the existing cleaned species assignments and
atlas summaries to assess assemblage overlap at species level, with subspecies
pooled. Resolve the specific event/date/location gaps that affect those comparisons.
Assemble modern access, preservation history, destructive allowances, budget and
generation-time evidence alongside that work. Final selection follows documented
feasibility and design evaluation.

## Sources and their role

Sources consulted on 12 October 2026. Web resources should be captured with versions
and retrieval metadata when they supply actual selection data. Links here support
methods and identify data providers; they do not establish any candidate species'
traits, preservation history or genomic feasibility.

- [The practice and promise of temporal genomics for measuring evolutionary responses to global change](https://pmc.ncbi.nlm.nih.gov/articles/PMC12142728/): temporal genomic inference and technical biases.
- Roberts et al. (2017), [Cross-validation strategies for data with temporal, spatial, hierarchical, or phylogenetic structure](https://doi.org/10.1111/ecog.02881): validation under dependence.
- Wilkinson et al. (2016), [The FAIR Guiding Principles for scientific data management and stewardship](https://pmc.ncbi.nlm.nih.gov/articles/PMC4792175/), DOI `10.1038/sdata.2016.18`: discoverability, provenance and reuse.
- [Darwin Core Quick Reference Guide](https://dwc.tdwg.org/terms/): specimen, event and location metadata vocabulary.
- [NMNH Fishes Collections Access](https://naturalhistory.si.edu/research/vertebrate-zoology/fishes/collections-access): museum access and destructive-analysis procedures.
- [FishBase](https://www.fishbase.se/search.php): discovery of species and life-history evidence; retain original study citations when extracting values.
- [NOAA Extended Reconstructed Sea Surface Temperature](https://www.ncei.noaa.gov/products/extended-reconstructed-sst): candidate regional temperature data; assess habitat, resolution and version before use.
