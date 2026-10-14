# Audit of legacy selection inputs

Start with [audit_summary.json](audit_summary.json), then read the
[repository review](../../docs/repository_review.md) for interpretation.

This directory inventories the older museum-processing files and candidate list.
It identifies duplication, date ambiguity, spatial-cluster spread and provenance
gaps. It does not repair records or determine current atlas eligibility.

| File | Contents |
| --- | --- |
| [input_inventory.csv](input_inventory.csv) | Source CSV paths, hashes, row/column counts, encoding and repeated catalog keys |
| [audit_summary.json](audit_summary.json) | Aggregate findings and reconciliations |
| [legacy_candidate_diagnostics.csv](legacy_candidate_diagnostics.csv) | Legacy candidate rows and uniquely matched raw evidence |
| [legacy_species_summary.csv](legacy_species_summary.csv) | Descriptive species summaries of the legacy candidate list |
| [source_sha256.json](source_sha256.json) | Source and supporting-file fingerprints for the audited snapshot |

From the repository root, using Python 3.10+ and the standard library:

```bash
python3 Scripts/audit_selection_inputs.py
python3 -m unittest discover -s tests -p 'test_selection_audit.py'
```

The script reads source files without editing them and replaces these generated
audit products. Saved findings describe the fingerprinted snapshot, not necessarily
later changes to source files. For current historical sampling, use the
[atlas](../SamplingAtlas/README.md); for candidate design opportunities, use the
[species-selection screen](../SpeciesSelection/README.md).
