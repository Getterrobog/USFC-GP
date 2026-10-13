# Life-history characteristics for the 80 candidate species

Initial database extraction, 12 October 2026. Start with the
[Excel workbook](../Output/LifeHistory/life_history_80_species.xlsx) or
[80-row CSV](../Output/LifeHistory/life_history_80_species.csv).
The workbook includes trait coverage, evidence, citations, taxonomy decisions,
field definitions and a review queue. It supports source discovery and design
exploration; primary-study verification and regional applicability remain pending.

## Scope and provenance

The input is the existing, cleaned
[`species_investigation_queue.csv`](../Output/SpeciesSelection/species_investigation_queue.csv).
All 80 project species and their order are retained, including the prior
investigation tiers. Existing accepted-name decisions and subspecies pooling are
reused. No live taxonomic cleaning, fuzzy matching, reranking, imputation or
upstream atlas regeneration occurs.

The source is **FishBase, provider release `26.06`**, distributed as Parquet
snapshots by Carl Boettiger on
[Source Cooperative](https://source.coop/cboettig/fishbase), the data infrastructure
used by [rOpenSci rfishbase](https://github.com/ropensci/rfishbase).
The dataset is attributed to the FishBase team and carries
[CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/).
The release label is pinned, not a claim that all records predate 30 June 2026.
The provider landing-page release label and available object prefixes differed;
exact downloaded URLs and content hashes, rather than a moving “latest” alias,
define this extraction.

Fourteen complete, unmodified source tables are retained in
[`Data/LifeHistory/raw/v26.06/`](../Data/LifeHistory/raw/v26.06/).
Their download manifest records URLs, release, retrieval times, HTTP modification
dates, sizes and SHA-256 hashes. The builder checks every hash before extraction.
Matched source rows retain every column in `Output/LifeHistory/source_records/`.
Selected traits are derived from eight tables: `species`, `matrix`, `maturity`,
`popgrowth`, `reproduc`, `fecundity`, `larvae` and `ecology`. The additional
`estimate`, `stocks`, `spawning`, `larvdyn`, `synonyms` and `refrens` tables provide
archived context and references; not every available field is promoted to a trait.

## Taxonomic attachment, separate from project names

The [crosswalk configuration](../config/life_history_taxon_crosswalk.csv) records
five exceptions to exact matching; the generated crosswalk contains all 80 rows.
Seventy-five names match the pinned accepted-name table exactly. Four documented
aliases permit source attachment:

| Project name retained | FishBase source name | Decision |
| --- | --- | --- |
| Atherina harringtonensis | Hypoatherina harringtonensis | Original combination; FishBase SynCode 59225 |
| Hypoclydonia bella | Synagrops bellus | Original combination; SynCode 5260 |
| Coelorinchus carminatus | Coelorinchus caelorhincus | Species aggregate proxy; SynCode 159549; regional applicability pending |
| Helicolenus maderensis | Helicolenus dactylopterus | Goode & Bean authority matches museum identifications; SynCode 5640; regional applicability pending |

For *Coelorinchus*, [NCBI taxon 1266865](https://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?id=1266865)
records the `carminatus` subspecies, and the pinned FishBase synonym table attaches
it to the parent species. This is consistent with species-level pooling but does
not establish that traits from other regions describe the historical study stock.
For *Helicolenus*, the original `Data/All_collections.csv` includes Goode & Bean
identifications (e.g. catalog 26723); the Valenciennes homonym maps to a different
fish and is not used. The configured source name is an explicit attachment for
trait discovery, not a replacement for the project key.

*Myctophum opalinum* remains a row with traits withheld: FishBase SynCode 135357
labels its proposed synonymy with *M. affine* both ambiguous and questionable.
*M. affine* already has its own project row. Attaching the same species data twice
could create spurious comparative replication. Human taxonomic review is required
before merging or transferring those data. No claim is made that this initial
80-row inventory represents 80 independently resolved biological species.

The builder rejects new unmatched names, mismatched synonym identifiers, ambiguous
synonym transfers and duplicated attached source taxa. New decisions must be
recorded in the configuration with evidence before rebuilding.

## What the values mean

- **Generation time and model lifespan:** `matrix` values come from FishBase Key
  Facts. [FishBase's method](https://www.fishbase.se/manual/key%20facts.htm) uses
  growth relationships and other inputs to derive life-history estimates.
  Generation time is not age at first maturity. All extracted Key Facts values
  are labelled `model_or_derived_keyfacts`; none is presented as an independently
  observed generation length. Source interval endpoints are retained without
  assigning a confidence level. Bounds are not assumed to be 95% intervals.
- **Reported values:** `reported_database_value` means reported in the database,
  not verified against the original study, and not necessarily directly measured.
  Growth coefficients are fitted estimates. Reported wild and captive maximum age
  remain separate from model lifespan and from maximum ages in growth records.
- **Maturity:** following the
  [FishBase MATURITY documentation](https://www.fishbase.se/manual/fishbasethe_maturity_table.htm),
  `tm` and `Lm` refer to mean/median maturity age and length. The other range fields
  accommodate different definitions and are preserved in evidence without
  combining them with `tm`. Wide-table minima and maxima of `tm` describe the
  envelope of source records across populations and sexes, not a confidence
  interval or pooled species estimate. Growth-table maturity ages remain separate.
- **Lengths:** cm, with original TL/SL/FL convention and sex category preserved.
  No conversion or averaging of different length types is performed. Maturity
  length records with unspecified length type remain visible and flagged.
- **Fecundity:** absolute counts retain their per-record batch, annual, total or
  unspecified basis. Unknown bases are flagged. No single combined fecundity
  minimum, maximum or mean is calculated across these definitions. Body size,
  location and source references remain in the evidence context and source rows.
  The [FishBase spawning manual](https://www.fishbase.org/manual/english/FishBaseThe_SPAWNING_Table.htm)
  explains why fecundity interpretation depends on the associated biological data.
- **Habitat and migration:** categories retain database wording. Only positively
  flagged habitat/water-type associations are listed; unchecked fields are not
  evidence of absence. Global species categories have not been matched to local
  populations, seasons, depths or historical eras.
- **Larval duration:** three source records have `LarvalDurationMin` greater than
  `LarvalDurationMax` (*Lutjanus synagris*, *L. apodus*, *Tautogolabrus adspersus*).
  Raw values are preserved, flagged and withheld from numeric summary. Unit and
  developmental-definition verification remains pending. Neither migration class
  nor larval duration is converted into dispersal distance.
- **Fisheries importance:** this category is not exploitation intensity or a
  historical exposure series. Site-specific fishing pressure remains uncollected.

Missing numeric values remain blank; zero record counts mean no extracted
records, not biological zeros. “Not found in snapshot” is not evidence that the
trait is unknown in the literature. Categories from multiple records list unique
values; their combination is not asserted to occur in one population.

`trait_evidence.csv` provides source table, field, row identifier, source species,
units, evidence class, context, QC flags, reference identifiers and snapshot hash
for every extracted value. A field-specific reference is preferred; a table-level
fallback is explicitly labelled `record_fallback`. A fallback does not establish
that the cited paper supports that particular value. `references.csv` includes
citations and DOI/paper links where supplied, including context references from
archived rows. Reference IDs missing from the snapshot are queued for review.
All primary-study review statuses are `not_independently_reviewed`.

## Initial coverage and use in species selection

| Characteristic | Species with extracted values / 80 |
| --- | ---: |
| Any attached traits | 79 |
| Generation-time model estimate | 75 |
| Maximum male/unsexed length with specified length type | 78 |
| Wild maximum age in species summary | 23 |
| Reported maturity age (`maturity.tm`) | 18 |
| Reported growth coefficient (`popgrowth.K`) | 40 |
| Sexual system | 59 |
| Fecundity, including unspecified bases | 27 |
| Water-column habitat | 79 |
| Migration category | 36 |

Exact coverage for every extracted field, including QC exclusions, is in
[`trait_coverage.csv`](../Output/LifeHistory/trait_coverage.csv).
Generation-time estimates were unavailable for *Chlorophthalmus agassizi*,
*Fenestraja plutonia*, *Histrio histrio*, *Hypoclydonia bella* and the withheld
*Myctophum opalinum*.

Use this package to prioritize primary-source review among the 27 species already
identified for investigation, then compare biological contrasts within shared
sites. Before selecting a core portfolio, verify influential values against their
original studies and match population, sex, methods and era to the intended use.
Prioritize the taxonomy exception, missing generation times, unspecified fecundity
bases, missing length conventions and invalid duration bounds. The automated
review queue is a minimum checklist; it does not replace review of all consequential
traits. Store future reviewed values as a separate versioned evidence supplement
with reviewer, date, source page/table, verbatim value, units, context and decision;
do not edit generated CSVs or overwrite archived source records.

Do not prefer well-studied taxa solely because their tables are more complete.
Do not treat several model-derived size, growth, maturity and generation-time
traits as independent biological evidence: shared inputs induce dependence.
Assess sensitivity to excluding model-only estimates and species-aggregate
proxies, and propagate justified generation-time uncertainty in temporal genomic
analyses. No imputation, genomic-response analysis, final species ranking or
feasibility-gate pass is performed by this extraction.

## Reproduce and audit

The tested environment is Python 3.11.5 with dependencies pinned in
[`requirements-life-history.txt`](../requirements-life-history.txt).
From the repository root, use an isolated environment if needed:

```bash
python3 -m venv /tmp/usfc-life-history-env
/tmp/usfc-life-history-env/bin/python -m pip install -r requirements-life-history.txt
/tmp/usfc-life-history-env/bin/python Scripts/build_life_history.py
/tmp/usfc-life-history-env/bin/python -m unittest discover -s tests -p test_life_history.py -v
```

The builder is offline and uses the archived source snapshots. If these have not
been included in a checkout, the explicit acquisition step is:

```bash
python3 Scripts/download_fishbase_traits.py
```

Retain the original download manifest when transferring files. A cached checksum
mismatch fails rather than silently replacing data. Re-downloaded files must
match the archived manifest before claiming replication of this release.

`build_manifest.json` records the command, Python/package versions, Git HEAD and
working-tree status, hashes of code/config/roster/original museum export, raw source
metadata and output checksums. Code hashes identify uncommitted implementations;
Git HEAD alone does not. The CSVs are canonical machine-readable outputs and
rebuild deterministically with the pinned environment. Excel archives can differ
in internal timestamps. Unsupported XML characters in source strings are visibly
escaped as `\uXXXX` in Excel; CSV/source snapshots retain the original content.

Validation covers roster conservation, withheld and invalid synonym transfers,
unreviewed names, evidence keys and references, model labels and missingness,
sex context, heterogeneous fecundity, reversed source bounds, workbook loading,
complete field dictionaries and source checksums. An independent reviewer should
rerun the build and inspect the cited records before treating the traits as ready
for confirmatory analysis.

The initial validation passed 11 tests and reproduced all 21 CSV files byte for
byte across consecutive offline builds. The machine-readable
[`validation_report.json`](../Output/LifeHistory/validation_report.json) preserves
test output and CSV hashes, and links to the validated build-manifest hash.
