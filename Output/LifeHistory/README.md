# Life-history table for the 80 candidate species

Open [life_history_80_species.xlsx](life_history_80_species.xlsx) for the populated
workbook, including evidence, citations, coverage, taxonomy decisions and review
flags. [life_history_80_species.csv](life_history_80_species.csv) is the canonical
80-row table. All existing project names and subspecies pooling are retained.

Traits attach to 79 rows; *Myctophum opalinum* is withheld because its proposed
synonymy is ambiguous. Generation time is available for 75 rows **as FishBase model
estimates**, not observed generation lengths. Primary studies and regional
applicability have not yet been independently reviewed.

- `trait_evidence.csv`: values, units, source row IDs, references, context and QC.
- `references.csv`: cited sources and available DOI/paper links.
- `taxon_crosswalk.csv`: all project-to-source mappings and attachment decisions.
- `trait_coverage.csv`: per-trait completeness before/after automated QC.
- `review_queue.csv`: taxonomy, source-data issues and missing generation times.
- `table_dictionary.csv`, `trait_dictionary.csv`: definitions and source fields.
- `source_records/`: full source rows for matched taxa, with study context retained.
- `build_manifest.json`: input/output hashes, source metadata and software versions.
- `validation_report.json`: test results and CSV hashes from repeated offline builds.

Rebuild with `python3 Scripts/build_life_history.py`. Do not manually edit generated
tables. Read the [documented workflow](../../docs/life_history_workflow.md) before
using these traits for selection or analysis. Data attribution: FishBase team,
release 26.06, snapshots curated by Carl Boettiger at
[Source Cooperative](https://source.coop/cboettig/fishbase), CC BY-NC 4.0.
