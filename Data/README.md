# Source data and supporting material

The current atlas starts from [All_collections.csv](All_collections.csv), the
museum export containing catalog numbers, specimen counts, identifications, dates,
localities, coordinates, preparations and record identifiers. One exported row
is not necessarily one physical specimen or lot; the R workflow checks object
types and catalog identity before counting.

| File or group | Role |
| --- | --- |
| [All_collections.csv](All_collections.csv) | Source export for the atlas and record-level evidence |
| `All_Ships_Updated.csv`, `Potential.csv`, `Potential12Sep.csv` | Earlier processing/candidate snapshots; not substitutes for the original export |
| `MissingNamesKey.csv`, `R-species_validation_results.xlsx` | Supporting name-review material |
| `Plotted.xlsx` | Supporting station/location material requiring reviewed linkage before use |
| `USFC_Collection12Sep.kmz` | Saved geographic collection view |

The current workflow also depends on curated taxonomy files in
[Output/Files](../Output/Files/README.md). The similarly named snapshots in this
directory and there are not interchangeable; use the explicit paths in
[config/sampling_atlas.R](../config/sampling_atlas.R).

Preserve source files as evidence. Enter reviewed corrections in
[config](../config/README.md), not in the original export. File modification dates
do not establish when the museum data were acquired. The
[repository review](../docs/repository_review.md) documents known provenance gaps.

[LifeHistory/](LifeHistory/README.md) holds separate external trait-source downloads.
Their presence alone does not mean traits have been incorporated into the atlas
or species-selection screen.

## Genomic metadata

[Genomics](Genomics/README.md) contains compressed original public ENA/NCBI metadata
and transport tables for all 80 atlas species. No sequencing reads or genome FASTAs
are downloaded. Scientific screening is performed in R and written separately to
[Output/Genomics](../Output/Genomics/README.md).
