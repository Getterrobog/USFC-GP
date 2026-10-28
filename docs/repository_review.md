# Repository evidence for species selection

Review date: 12 October 2026. Baseline commit: `89db0a2`. The proposal and `.R-library/` were untracked at review start. A sampling-atlas workflow appeared during the review and is addressed separately below. No existing data or analysis scripts were modified or rerun for the legacy audit. Saved artifacts do not by themselves establish the execution history that produced them.

## Repository structure

| Location | Observed role |
| --- | --- |
| `background/one_page_proposal.txt` | Scientific aims, 4–6 assemblages and approximately 12–20 focal species |
| `Data/All_collections.csv` | Raw-style museum export with 49 fields, including catalog numbers, dates, localities, preparations and persistent EZIDs |
| `Data/All_Ships_Updated.csv`, `Potential.csv`, `Potential12Sep.csv` | Different processing snapshots with unestablished acquisition/run provenance |
| `Data/Plotted.xlsx`, `MissingNamesKey.csv`, validation workbook | Supporting coordinate/taxonomy material; workbooks are fingerprinted but individual entries are not adjudicated here |
| `Scripts/USNM-R-inator.R` | Main legacy cleaning, name mapping, imputation, spatial clustering, listing and plotting workflow |
| `Scripts/species_checkinator.py` | Live Eschmeyer lookup with HTML parsing and fallback matching |
| `Scripts/PRfixinator.R` | Manual station-derived coordinate/date supplementation from `Plotted.xlsx` |
| `Scripts/FishBaseinator.R` | Common-name lookup; not a life-history predictor table |
| `Scripts/USNMdiff-inator.R` | Interactive comparison of potential tables |
| `Scripts/Populinator.R` | Exploratory population simulation; not genomic power assessment for this proposal |
| `Scripts/Gitpushinator.sh` | Pull/add/commit/push convenience script; not an analysis dependency |
| `Output/Files`, `Output/Figures` | Legacy products |
| `R-USFCGP.Rproj` | RStudio configuration using default workspace/history settings |
| `Scripts/build_sampling_atlas.R`, `sampling_atlas_functions.R`, `config/`, `tests/test_sampling_atlas.R` | Newly added configurable inventory, maps, screening and checks; see [atlas guide](sampling_atlas.md) |

No project `AGENTS.md` or dependency lockfile was found. The atlas adds reproducible processing and tests beyond the legacy scripts. The local R library is not a portable dependency specification. Atlas documentation, configuration and processing entry points were inspected; its full implementation and graphics were not independently validated as part of this review.

## Reproduce the descriptive audit

Run with Python 3.10 or later; no third-party packages or network access are required:

```bash
python3 Scripts/audit_selection_inputs.py
```

For a separate output directory:

```bash
python3 Scripts/audit_selection_inputs.py --output /tmp/usfc-selection-audit
```

The audit ran with Python 3.11.5. Its five products are in [Output/SelectionAudit](../Output/SelectionAudit/):

- `input_inventory.csv`: SHA-256, CSV record/column counts, encoding hypothesis and catalog-key duplication statistics.
- `audit_summary.json`: reconciliation and aggregate findings.
- `legacy_candidate_diagnostics.csv`: one row per legacy candidate row, joined to raw evidence only when the catalog key has exactly one match.
- `legacy_species_summary.csv`: alphabetical species summaries with explicitly unverified legacy counts.
- `source_sha256.json`: audited CSV, R/Python script, proposal, R project and supporting workbook fingerprints.

Validation: all five outputs reproduced byte-for-byte when the script was invoked
from `/tmp` with a separate output directory. The recorded source hashes matched
the reviewed files. Eight boundary tests passed for ambiguous centuries, temporal
boundaries/ranges, missing dates, annotations, embedded CSV newlines, provisional
encoding and malformed input. Reproduce the tests with:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p test_selection_audit.py -v
```

These checks validate the descriptive audit's behavior, not the museum records or
the proposed future selection pipeline.

Record counts use CSV parsing, not line counts. `Data/All_Ships_Updated.csv` fails UTF-8 decoding; the audit uses CP1252 as a provisional reversible hypothesis for inventory only. Confirm the source encoding before reusing its text. The raw export and current `Output/Files` CSVs decode as UTF-8.

Date categories recognize explicit four-digit years before parenthetical annotations. They do not validate calendar dates, resolve centuries or establish eligibility. For date ranges, all explicit years must be within 1880–1929 to receive that category. Repeated raw keys produce `ambiguous_or_missing_raw_join`; the audit never picks an arbitrary row. Missing original coordinates do not prove replacements incorrect, but require provenance. Recorded cluster diameters are read from the legacy file, not recomputed from validated positions.

| Check | Observed result |
| --- | --- |
| Raw export | 7,166 rows; 6,972 distinct nonempty catalog keys; 88 repeated keys |
| Retained plus removed | 5,260 + 1,906 = 7,166 rows; catalog-number multisets also reconcile |
| Legacy potential | 1,027 rows; 1,017 catalog keys; five repeated keys |
| Candidate versus summary species | 96 versus 94; `Helicolenus dactylopterus` and `Hippoglossoides platessoides` absent from summary |
| Legacy spatial clusters | 168; 36 with recorded diameter >40 km; maximum 249.43 km |
| Candidate raw dates on unique joins | 732 rows with explicit years within 1880–1929; 45 outside; 113 missing; 122 lacking an explicit four-digit year |
| Candidate raw joins unresolved | 15 rows, additional to those four date categories |
| Candidate original coordinates missing | 236 rows among unique raw joins |
| Raw preservation method | Empty in all 7,166 rows |
| Other potential snapshots | 1,414 rows in `Data/Potential.csv`; 1,115 in `Data/Potential12Sep.csv` |

Count reconciliation does not prove specimen independence, historical eligibility or reproduction of the original analysis. Age alone cannot fill unknown fixation history.

## Legacy issues affecting selection

These findings concern the legacy workflow, not a claim that the new atlas repeats them.

They also do not call for repeating completed species-name cleaning. The existing
cached validation and catalog-specific corrected names remain the baseline, with
new review limited to gaps or conflicts. Selection pools subspecies under their
accepted species and retains original identifications and source mappings.

| Finding and code location | Consequence and response |
| --- | --- |
| `USNM-R-inator.R` sections II–IV use locality averages extending to country/ocean, and vessel/coordinate date matches | Potential artificial co-occurrence and temporal certainty. Preserve source and uncertainty; require event-level evidence |
| Section VI uses connected components of pairwise distances ≤40 km | Chains span much farther than 40 km. Replace the misleading “40 km R” interpretation with explicit extent and ecological boundaries |
| Section VI requires ≥20 specimens pooled across dates before later date filtering | Retained cells may no longer meet a threshold; pooled counts are not temporal sample sizes. Filter dates first and qualify each cell |
| Multiple date functions for preparation, maps, histograms and summary | Two-digit years handled inconsistently; first isolated two-digit token can be a day. Use one tested interval parser |
| Summary parser checks unanchored `Albatross II` before `Albatross III` | The latter can match the earlier branch. Resolve vessel identities exactly |
| Section IV edits `Date.Collected` after `Date.ISO.8601` creation | Normalized date can become stale. Derive it from the final versioned evidence |
| Maps/histograms/summary use a 1947 cutoff and retain undated records; candidates exported earlier | Products have different universes. Use an authoritative cell table with explicit views and count reconciliation |
| Repeated catalog numbers remain in retained/potential tables | Repeated representations may inflate counts. Resolve object kind and physical specimen identity before summing |
| Name scraper permits a global valid-name fallback | Preserve the completed cached and curated assignments; inspect unresolved or specifically conflicting cases rather than rerunning all name validation |
| `PRfixinator.R` joins station number alone and keeps the first duplicate | Reused stations can map to the wrong voyage. Validate composite event keys and cardinality |
| Manual PR step, session-dependent FishBase objects, absolute paths, interactive corrections and live scraping | Clean-checkout reconstruction requires undocumented state. Make dependencies explicit and cache inputs/corrections |
| Geographic and ecological scope not explicitly enforced | Raw labels include North Pacific and Adriatic records. Apply scope gates with a full ledger |

These are static code findings and descriptive observations, not proof that every affected record is incorrect. Manual navigation work may be valuable once evidence and uncertainty are linked to events. The main script also computes `valid_coord_idx` without applying it before distances; coordinate validation should become an asserted preprocessing step.

## Initial investigation queue

Start dossier checks with taxa showing substantial legacy spatial replication while exploring complementary taxa across the full frame. The table shows the first four under descending legacy cluster count with alphabetical tie-breaking. **These are investigation priorities, not a selected panel or evidence of usable genomes.**

| Species | Legacy clusters | Distinct candidate catalog keys | Rows with explicit raw years within 1880–1929 | Rows missing original coordinates |
| --- | --- | --- | --- | --- |
| *Menidia menidia* | 9 | 50 | 48 | 11 |
| *Alosa pseudoharengus* | 7 | 89 | 36 | 31 |
| *Atherinomorus stipes* | 6 | 18 | 17 | 11 |
| *Alosa aestivalis* | 5 | 77 | 39 | 32 |

`Ammodytes dubius` also has five legacy clusters, but only two of its nine candidate rows have explicit raw years in that window. Spatial rank alone is insufficient. Modern accessibility, generation times, population matching, preservation and assay suitability remain to be established. No species-specific external trait or reference-genome claims are assumed here.

## Proposal refinements

The [selection plan](species_selection_plan.md) specifies units of replication, contemporary matching, pilot/power criteria, calendar-time versus generation-time comparisons and protection against selecting on genomic outcomes. The final proposal should demonstrate both within-region biological contrasts and connected replication across regions, along with realistic sequencing costs and replacement species that preserve those contrasts.

Keep the 12–20 species and 4–6 assemblages as design targets subject to documented feasibility. Avoid using collection counts as historical abundance or effective size. The full proposal bibliography and preliminary laboratory claims were not independently verified here; check them against original publications and laboratory records for final submission. Methodological sources are linked beside their use in the plan.
