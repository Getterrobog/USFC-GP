# Curated species traits for the 80 atlas species

Start with [species_summary.csv](species_summary.csv), the combined species table,
or [species_traits_80.xlsx](species_traits_80.xlsx). The [SQLite database](species_traits.sqlite)
contains the component tables and evidence. These are compiled source snapshots;
independent scientific review remains pending.

| Files | Purpose |
| --- | --- |
| `species_summary.csv`, `species.csv` | Combined traits and exact project-species/taxonomic decisions |
| `functional_traits.csv`, `trophic_traits.csv` | Life history, movement, body shape, reproduction and source-specific trophic information |
| `contextual_traits.csv` | Population, sex and life-stage-specific records; values retain context rather than becoming universal species estimates |
| `iucn_status.csv` | Reported assessment category, date, scope and verification; not a current/latest status audit |
| `summary_evidence.csv` | Field-level links from summary tables to evidence IDs |
| `trait_evidence.csv`, `trait_provenance.csv` | Individual assertions, source values, citation/URL, locator, context, review/QC status and archive provenance |
| `sources.csv`, `references.csv` | Source registry and references |
| `trait_dictionary.csv` | Definitions, units and interpretation |
| `trait_gaps.csv`, `trait_field_gaps.csv`, `coverage.json` | Explicit coverage and missingness audits |
| `build_manifest.json`, `source_issues.csv`, `excel_export_notes.csv` | Build provenance, source limitations and workbook notes |

The [historical annual atlas](../SamplingAtlas/index.html),
[historical overview](../SamplingAtlas/overview.html) and
[genomic maps](../Genomics/maps.html) use this summary for species-trait cards and
filters. Each card has key traits above the map, expandable additional traits,
and source/evidence rows. Filtering selects species; it does not change their
underlying specimen or accession counts.

Important distinctions:

- Model generation time/lifespan/maturity remain separate from reported ages.
- Trophic level prefers the diet estimate, otherwise food items, retaining the
  corresponding method and SE. FishBase broad feeding classes and reef diet guilds
  are separate fields; contextual diet information remains visible beside them.
- `migration_best_available` includes sourced supplementary classifications and
  withheld/unknown results. Blank does not mean non-migratory.
- Length types TL/SL/FL are not converted. Habitat/behavior non-reporting is not
  evidence of absence. Unknown taxonomic matches do not acquire borrowed traits.
- IUCN categories retain assessment dates; current/latest status is unverified.

Rebuild the trait outputs and then the geographic pages from the repository root:

```bash
python3 Scripts/build_species_traits.py
Rscript Scripts/build_genomics_maps.R
```

The second command refreshes all three map pages without redrawing historical
PNG/GIF/SVG maps. The atlas attachment and filtering code is in
`Scripts/sampling_atlas_traits.R` and `Scripts/trait_filters.js`. Source compilation
and interpretation are documented in [life-history methods](../../docs/life_history_workflow.md).
Edit curated inputs under `config/`, not these generated data files.
