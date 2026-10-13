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

## Supplementary sources and attribution requirements

Source assessment and first supplementary extraction, 12 October 2026 (local
America/Chicago date; retrieval timestamps are UTC). The original extraction has
migration categories for 36 of 80 project rows; 44 are blank. These are missing
database assignments, not evidence of non-migration. The separate supplement below
adds four regional route interpretations and documents the remaining gaps.

The project requires attribution **for every characterization**, not merely a
bibliography for the combined table. Supplementary extraction must retain one
evidence record per species, trait, source and applicable population/life stage.
Each populated supplementary summary value must link to its evidence IDs. A
derived category must additionally record its mapping rule and supporting evidence
IDs. A source attached to another trait in the same row does not support that value.

### Sources to prioritize

| Source | Useful information | Scope and interpretation |
| --- | --- | --- |
| [IUCN Red List movement classification](https://nrl.iucnredlist.org/resources/movement-patterns-classification-scheme) and individual assessments | Migration and congregation categories; assessment narratives and references | Cross-taxon definitions differ from FishBase's salinity-route categories. Preserve both vocabularies. Individual assessment coverage and supporting references require checking; the classification guide itself is not species evidence. |
| [NOAA Estuarine Living Marine Resources: Gulf species life-history summaries](https://library.oarcloud.noaa.gov/noaa_documents.lib/NOS/ORCA/ELMR_report/ELMR_11.pdf), plus regional Essential Fish Habitat reports and underlying studies | Seasonal and life-stage movements, reproduction, growth and habitat | Regional literature synthesis, requiring species-by-species extraction and original-study review. Especially useful for the coastal and estuarine portion of this roster. |
| [North American Freshwater Migratory Fish Database](https://doi.org/10.5066/P9WDLLP0), documented by [Dean et al. (2022)](https://repository.library.noaa.gov/view/noaa/50037/noaa_50037_DS1.pdf) | Migratory status, pattern and behaviour, with supporting sources | The paper describes 1,250 freshwater-using species, including diadromous fishes; not a comprehensive marine database. The archived release matches 15 project species; see version-specific counts below. |
| [Smithsonian Shorefishes of the Greater Caribbean](https://biogeodb.stri.si.edu/caribbean/en/pages) and [Atlantic reef-fish trait dataset, version 1](https://zenodo.org/records/13655554) | Habitat, size, diet and reproductive information for relevant marine taxa | The Atlantic dataset's seven traits include depth, size, rafting, habitat use, diet, group size and spawning, but no migration-type field. Some inputs derive from FishBase; they are not independent corroboration. Geographic residency and rafting are not interchangeable with migration or adult site fidelity. |
| [FishLife](https://james-thorson-noaa.github.io/FishLife/) | Compiled life-history measurements and model-based predictions with uncertainty | Useful to investigate other missing traits. FishBase contributes inputs, and imputed outputs must remain explicitly modelled. Do not treat predictions as new observations or assume this supplies the missing migration categories. |

Recommended first pass: IUCN assessments and regional NOAA literature for movement,
the freshwater database where taxa overlap, and Smithsonian/Atlantic reef datasets
for other traits. This is a source-discovery priority, not a rule that one database
automatically overrides better population-specific evidence.

### Verified source lead: Gulf menhaden

*Brevoortia patronus* has no migration category in the current FishBase extraction.
NOAA's **1997** Gulf life-history report, printed page **137** (PDF page **142**),
describes adults and maturing juveniles moving from estuaries to offshore waters
for overwintering or spawning, with seasonal and geographic variation. It also
discusses limited east-west movement and localized populations. This supports
collecting seasonal estuary/offshore movement evidence; it does not by itself
establish a universal FishBase category, movement radius or genetically homogeneous
sampling region. The synthesis and the original Tagatz and Wilkens (1973) sampling
study have now been inspected. They support the supplement's regional
`oceano-estuarine` interpretation. Other underlying studies remain unreviewed;
the two inspected documents share evidence and are not independent replicates.

### Required evidence fields and checks

For every supplementary characterization, retain:

- Stable `evidence_id`, project species key, source taxon name/identifier, and the
  explicit crosswalk decision. Reuse existing cleaning and species-level pooling;
  preserve subspecies/population context and withhold unresolved transfers.
- Trait, original value or category, units/definition, a short supporting excerpt
  or precise paraphrase, and page/table/section/record locator. Label paraphrases;
  do not present them as quotations.
- Full citation, DOI or persistent source URL, source version/assessment date,
  retrieval time, archived file identifier and SHA-256 where archiving is permitted.
  For a live record, preserve its stable ID and an auditable retrieved representation.
- Population/location, life stage, sex, season and study period when supplied;
  explicitly record unspecified context rather than inferring it.
- Evidence type (original study, database/report synthesis, model prediction),
  upstream citation if the source relies on another publication, whether that
  publication was actually inspected, extractor/reviewer and review dates/status.
- Normalized value, versioned mapping/derivation rule, applicability decision and
  conflict status. Preserve competing evidence records; document any choice used
  in the summary rather than silently overwriting the alternative.

Before promotion into an analysis-ready table, validate that every nonmissing
supplementary value resolves to evidence records with source and locator, the
taxon transfer is justified, and the evidence supports that particular claim.
Summary exports and webpages must expose these citations through evidence IDs or
source links. A bibliography alone does not satisfy this requirement. Existing
FishBase field-specific references and explicitly labelled record-level fallbacks
remain intact; fallback references still require verification before being treated
as trait-specific support.

Keep migration route, seasonal habitat movements, diel vertical migration, adult
site fidelity/home range and larval dispersal as separate traits. Missing values
remain unknown. Do not infer non-migration from an absent entry, infer movement
distance from migration class, or use genus/family averages as observed species
traits. Compare shared upstream references to avoid counting copied database
entries as independent evidence. Report observed/synthesized and modelled coverage
separately, and retain unresolved and conflicting cases in the review queue.

Acquisition should archive versioned source snapshots and manifests, followed by
an offline build using explicit crosswalks. Supplementary evidence must be stored
separately from the original FishBase snapshot and linked into regenerated outputs;
generated CSVs must not be hand-edited. These requirements extend the existing
pipeline and are implemented in the separate supplementary extraction below.

### Supplement implementation and first-pass results

The [supplemented workbook](../Output/LifeHistorySupplement/life_history_80_species_supplemented.xlsx)
contains the frozen 80-species table, supplementary evidence, sources, all 44 gap
assessments, search queries, matched NAFMFD records and original FishBase evidence.
The canonical [CSV](../Output/LifeHistorySupplement/life_history_80_species_supplemented.csv)
retains **every original column and value**, including original blank migration
fields. Added trait columns link to evidence IDs. `migration_best_available`
combines original FishBase categories with four **project-derived regional**
interpretations; its basis and scope columns must accompany it in reports.

| Species | Additional route interpretation | Inspected support and scope |
| --- | --- | --- |
| *Brevoortia patronus* | oceano-estuarine | Tagatz and Wilkens (1973), p. 1, and Pattillo et al. (1997), p. 137; northwestern Florida/Gulf estuary–sea movements, with regional timing differences. |
| *Lagodon rhomboides* | oceano-estuarine | Pattillo et al. (1997), p. 243; Gulf estuary–sea movements with resident components. Underlying original movement studies remain unreviewed. |
| *Haemulon aurolineatum* | oceanodromous | Darcy (1983), section 3.51, p. 23; seasonal marine movements on Campeche Bank and in the South Atlantic Bight, with different seasonal directions. Underlying original studies remain unreviewed. |
| *Lutjanus synagris* | oceanodromous | Claro and Lindeman (2003), pp. 94, 98; historical spawning migrations on the Cuban shelf, drawing on fishers, field observations and earlier work. |

Coverage rises from 36/80 to **40/80** when these regional interpretations are
included; **40 route classifications remain unknown**. None of the supplementary
extractions has yet received independent scientific review. These additions must
not be advertised as new FishBase assignments or universal population attributes.

The [evidence table](../Output/LifeHistorySupplement/trait_evidence.csv) contains
**22 records across 14 species**: 17 contextual records included in summaries and
five held records. Additional characteristics include diel habitat movements,
estuarine use, sex-specific territoriality, vertical migration, maturation size/age
and observed longevity. Blackcheek tonguefish age remains `5+` years; maturation
lengths retain TL versus SL and reported definitions. These are separate contextual
fields, not replacements for incompatible FishBase measures.

The archived NAFMFD workbook has 2,198 reference-level rows and 1,242 distinct
nonblank names after whitespace trimming. Its version-specific count differs
from the 1,250 species described in the paper; do not conflate them. It contributes
34 matched records for 15 project species, including three original migration
gaps. *Membras martinica* and *Symphurus plagiusa* are explicitly undetermined.
*Eucinostomus gula* is classified as semi-anadromous, citing Stoner (1986), but a
NOAA synthesis of that study describes an estuarine resident. Different trait
vocabularies may explain this; it is not an established biological contradiction.
Both statements are retained and the migration assignment is held pending review
of the original study. No semi-anadromous-to-anadromous conversion is made.
Existing FishBase assignments remain unchanged when NAFMFD terminology differs.

Daily feeding movements, speculative offshore departures and larval drift do not
qualify for seasonal route assignment. Held records remain visible in the
evidence/review tables and do not populate summaries. Taxonomic transfers retain
existing project decisions; subspecies are not split into new rows and the
unresolved *Myctophum opalinum* transfer stays withheld.

This is a **targeted, machine-assisted first pass**, not an exhaustive systematic
review. Every original gap has an archived targeted query, results and assessment
note in the [gap review](../Output/LifeHistorySupplement/migration_gap_review.csv).
Absence of supporting results does not establish absence of published evidence.
Short search snippets are discovery records, not stand-alone evidence for an
assignment. The broader integration below separately labels substantial indexed
IUCN assessment sections; these are not authenticated API records or complete PDFs.
Two full-source acquisitions (cunner and sand-lance leads) returned HTTP 403;
those leads remain unavailable in the registry and support no imported trait.
Next review priorities are the Stoner interpretation, blocked source leads, and
primary studies underlying the NOAA syntheses.

### Supplement reproduction and provenance

Using the existing pinned environment, from the repository root:

```bash
python3 Scripts/build_life_history_supplement.py
python3 -m unittest discover -s tests -p 'test_life_history*.py' -v
```

Acquisition is separate, needed only when permitted source snapshots are absent:

```bash
python3 Scripts/download_life_history_supplement.py
```

The downloader only requests registry entries marked `download`; unavailable
leads remain documented. Cached checksum or URL mismatches fail. Keep metadata
sidecars with the archives. A changed live source is not replication: compare
downloaded hashes with the archived build manifest before claiming the same release.

Editable inputs are `config/life_history_supplement_{sources,evidence,policy,gap_review}.json`.
The policy pins the baseline checksum and versioned mapping definitions. Original
source snapshots and acquisition metadata are in `Data/LifeHistorySupplement/sources/`;
`searches/` preserves queries, UTC retrieval times and tool-returned results.
PDF text conversions are inspection aids; original documents and locators are
the evidence of record.

Each evidence row includes citation, URL, source version, retrieval time, archived
path/hash, original and normalized values, locator, population/life stage/sex,
study context, upstream-source inspection status, interpretation and review status.
Unspecified context is recorded explicitly. NAFMFD matches retain Excel row numbers,
flags, reference assignments and shared FishBase-reference warnings; they must not
be counted as independent observations without checking upstream sources.

The offline builder validates source hashes, attribution, taxon matches, mappings,
held classifications and all 44 assessments. Its `build_manifest.json` hashes code,
config, baseline, original evidence, taxonomy crosswalk, source snapshots/metadata,
search archives and outputs, and records Python/pandas/openpyxl versions. Tests
check unchanged original values, trait-specific evidence links, unknown/held cases,
units and age qualifiers, rejection of missing attribution/conflicts/tampered sources,
all-gap audit coverage and deterministic CSV/coverage rebuilds. Excel ZIP timestamps
can vary. This supplement does not modify the atlas, spatial thresholds or rankings.

## Integrated conservation, trophic and functional-trait database

Implemented 12–13 October 2026. The scope now covers all available life-history
domains, rather than prioritizing migration alone. The frozen roster, species
pooling and existing taxonomic crosswalk remain unchanged.

Use the [80-species workbook](../Output/SpeciesTraits/species_traits_80.xlsx),
[SQLite database](../Output/SpeciesTraits/species_traits.sqlite), or canonical
[species summary CSV](../Output/SpeciesTraits/species_summary.csv). These outputs
extend the previous extraction; they do not overwrite it. The database contains
one species record per project name and normalized, individually attributed
evidence linked to conservation, trophic, functional and contextual trait tables.

### Coverage and interpretation

| Component | Current coverage | Interpretation |
| --- | --- | --- |
| Red List assessment categories carried by FishBase | 72/80: 67 LC, 4 VU, 1 NT | Attributed snapshot categories, not a completed audit of current global status. |
| Other Red List rows | 7 source-coded `N.E.`; 1 unresolved taxon | Preserve `N.E.` as FishBase's report. The current IUCN evaluation status remains unverified; unresolved taxonomy stays separate. |
| Numerical trophic level | 67/80 | 44 species have species-level diet-composition estimates; 65 have food-item estimates, with overlap. Prefer diet-composition estimates without averaging methods. |
| Broad feeding class or diet guild | 69/80 | 68 FishBase broad classes; 16 finer reef-dataset guilds, including one additional species. Contextual diet evidence is also retained. |
| Body shape and reported maximum size | 79/80 | One ambiguous taxon remains withheld. Other functional dimensions have their own coverage. |
| Atlantic reef-fish dataset matches | 18/80 | Partial, source-specific coverage; no extrapolation to unlisted marine or freshwater species. |

The integrated database contains 3,165 evidence records: the original 2,670
FishBase records, 22 prior supplemental records, 348 newly exposed FishBase
fields, 112 reef-dataset trait records and 13 newly curated assessment/narrative
records. These are **characterizations, not independent studies**. Repeated
references and inherited database information must not be counted as replication.
Independent scientific review remains pending.

### IUCN status and assessment biology

The user confirmed that no API token is available and authorized using available
sources. `iucn_status` retains all 80 species, original FishBase category strings,
assessment dates, criteria when supplied, IUCN taxon/assessment IDs, assessment
URLs, taxon-match decisions and verification status. Only the FishBase
`species in general` stock is used for this table; population-specific stocks
are not substituted. Source taxon names make transfers to accepted species or
species aggregates visible. Geographic assessment scope is explicitly unverified
unless inspected in assessment text. No failed request or absent match becomes
Least Concern, Data Deficient or Not Evaluated.

None of the 80 records is labeled as authenticated **current/latest** verification.
Category dates can substantially precede both the FishBase release and our retrieval
date. Regional, national and global conservation categories are not interchangeable.
For example, the Canadian COSEWIC or Baltic HELCOM classification of lumpfish must
not fill its missing global IUCN assessment. A future authorized API/export update
must retain assessment history, scope and taxon identity and identify corrections
or superseded assessments before changing the preferred status.

IUCN is also a biological source. The substantial publicly indexed text of
[Cadrin et al. (2022), witch flounder assessment](https://doi.org/10.2305/IUCN.UK.2022-2.RLTS.T18214757A162704857.en)
is archived with its URL, retrieval timestamp, representation type and checksum.
The inspected sections supply a generation-length estimate of 16–17 years,
regional/sex-specific maturation ages, reported maximum age, an upper larval-period
estimate, spawning aggregation, egg and diet information. The generation-length
estimate is assessment-derived; it is not a direct observation or equivalent to
the FishBase growth-derived generation-time model. The larval period is a reported
upper value, not a mean dispersal duration. Regional maturation records are retained
individually and not combined into a universal maturity age. Original publications
cited by the assessment have not been independently checked.

This representation contains substantive assessment sections, rather than an
isolated search snippet, but it can omit material. Its inclusion is explicitly
marked `public_indexed_assessment_text`; it is not presented as a downloaded
complete assessment or API response. Short snippets from other assessments remain
source leads. The workflow can therefore benefit from available IUCN biology
while keeping the access and verification limits visible.

### Trophic information and functional connections

FishBase `DietTroph` and `FoodTroph` are **estimates**, with their respective SEs,
remarks, references and source stock retained. `trophic_level_preferred` uses
the species-level diet estimate when available, otherwise the species-level
food-item estimate. It does not average the two, borrow an SE from the other
method, derive a value from taxonomy, or impute a missing value from a guild.
An explicitly recorded zero SE is retained as a source value, not treated as
proof of zero biological variation. The archive contains additional contextual
records; a population-specific record is not silently promoted to a global value.

FishBase's broad `Herbivory2` class, feeding mechanism and the Atlantic dataset's
diet guild are separate columns. The broad class already incorporates trophic
information, so it must not be treated as an independent measurement alongside
the numerical trophic level. The reef guilds distinguish generalized carnivores,
mobile/sessile invertivores, herbivores/detritivores, omnivores and planktivores.
They come from [Cord et al., version v2, June 2025](https://doi.org/10.5281/zenodo.15636151),
whose sources include FishBase, Smithsonian records and literature; per-cell
upstream citations are not supplied. Attribution therefore honestly stops at the
dataset when the original source is unidentified.

`functional_traits` connects the species to body size and shape, water-column
position, depth, generation time, growth, maturation, longevity, migration,
reproductive traits, social grouping, habitat breadth and rafting. Trophic traits
join on the same species key; `contextual_traits` adds region-specific literature
values with units, sex/life stage and evidence IDs. These describe potential
differences in resource use, habitat exposure, movement and reproductive schedules
relevant to Aim 3. They are trait profiles, not measured ecosystem-process rates
or precomputed functional-diversity scores.

Source definitions constrain interpretation:

- TL, SL, FL and unspecified lengths remain distinct; no silent conversion or
  pooling of maximum body size, maturation size, L50 and length at first maturity.
- Reef rafting codes are often assigned at genus level. They are retained as
  compiled classifications, never relabeled as species-level observations.
- Reef spawning categories remain separate from FishBase parental care and egg
  traits. The pipefish `live` category requires interpretation before equating it
  with physiological viviparity.
- Source-coded reef binary zeros are retained under their explicit codebook.
  FishBase zero habitat/behavior flags are not used as evidence of absence;
  only positive schooling, batch-spawning and aggregation flags are promoted.
- Pinfish has documented ontogenetic feeding changes. NOAA's adult-omnivory
  description is retained beside the reef mobile-invertivore guild, whose life
  stage is unspecified. A universal single guild would conceal this distinction.

For later analysis, predefine ecological domains and weights; do not count several
correlated size/growth/generation-time estimates as independent predictors. Mixed
categorical/continuous traits require suitable distance methods and explicit
scaling, length conventions and missing-data rules before functional-space or
diversity calculations. Test sensitivity to model-only values, genus-level
classifications, taxon proxies and uncertain regional transfers. Conservation
status is a separate response/risk descriptor, not an intrinsic functional trait;
using a modern decline-based status to predict historical demographic change
requires particular care about temporal ordering and circularity. No such model,
imputation or final species ranking is performed here.

### Full gap inventory and source-quality audit

`trait_gaps` has **2,320 rows: 80 species × 29 domains**. `trait_field_gaps` also
enumerates each individual evidence field for every species, so domain coverage
does not conceal missing subtraits. Both distinguish available contextual evidence,
model-only evidence, held-only evidence and missing information. Availability does
not mean that all populations, life stages or trait definitions are covered.

The reef workbook has 1,637 rows and 1,636 distinct names after mechanical removal
of padding/underscores. Two *Cerdale floridana* rows differ; neither matches our
roster. They are retained in `source_issues`, and multiple matches to any project
species cause the build to fail. Source `NA` strings are missing, not categories.
The *Dibranchus atlanticus* 1-cm size entry is retained but held after a large
disagreement with the FishBase size; it does not replace the existing value.

Some inherited FishBase reference IDs lack bibliography rows in the frozen source.
Their source record, reference ID and link remain available, with an explicit
`upstream_bibliographic_record_missing` flag. No author/title is invented. One
reference's malformed `PaperURL` is removed from the usable URL field and preserved
as escaped JSON with a quality flag. The original parquet remains unchanged.
Excel-only escaping/truncation, if needed, is recorded in `excel_export_notes`;
complete canonical values remain in CSV/SQLite or the explicit raw-JSON field.

### Rebuild and query

Using the same pinned environment as the earlier extraction:

```bash
# Explicit acquisition of configured public sources, if absent:
python3 Scripts/download_species_traits.py

# Offline construction and validation:
python3 Scripts/build_species_traits.py
python3 -m unittest discover -s tests -p test_species_traits.py -v
```

Configuration lives in `config/species_traits_{sources,policy,curated_evidence}.json`.
New archives, metadata and discovery logs are under `Data/SpeciesTraits/`.
The builder verifies the frozen baseline, existing supplement outputs and source
checksums, then writes a manifest of input/output hashes and software versions.
It uses the existing crosswalk without fuzzy matching, new taxonomy cleaning or
subspecies expansion. Files in earlier output directories remain unchanged.

SQLite contains `species`, `sources`, `trait_evidence`, `iucn_status`,
`trophic_traits`, `functional_traits`, `contextual_traits`, `summary_evidence`,
`trait_gaps`, `trait_field_gaps`, `references` and audit tables. Evidence has
species/source foreign keys, numeric values/bounds where meaningful and a context
JSON field for population, sex, stage and source details. `trait_provenance` joins
each characterization to its source citation, version, URL and archive hash.
`summary_evidence` links individual summary fields back to supporting records.

For example:

```sql
SELECT species, iucn_category_reported, assessment_date,
       assessment_url, verification
FROM iucn_status;

SELECT species, trophic_level_preferred, trophic_level_method,
       trophic_level_se, fishbase_feeding_group, reef_diet_guild
FROM trophic_traits;

SELECT species, trait, value, unit, citation, locator,
       upstream_citation, reference_scope, qc_flags
FROM trait_provenance
WHERE species = 'Glyptocephalus cynoglossus';

SELECT species, trait, coverage_status
FROM trait_field_gaps
WHERE coverage_status IN ('missing', 'held_only', 'model_only');
```

Tests check preservation of all original values, unresolved taxonomy, Red List
scope/missingness, trophic-method/SE pairing, source and summary links, source
disagreements, contextual bounds, complete gap enumeration, SQLite integrity and
numeric types, Excel display changes and deterministic offline CSV rebuilds.

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
