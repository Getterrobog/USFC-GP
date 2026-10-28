# Analysis outputs

Start with the [sampling atlas](SamplingAtlas/README.md) to see where and when fish
were collected, or the [species-selection screen](SpeciesSelection/README.md) to
investigate species and sites for the proposed genomic study.

For one historical map at a time, open the [sampling explorer](SamplingAtlas/explorer.html):
searchable species selection, filters and an independent map life-stage control.

| Directory | Purpose | First file to open |
| --- | --- | --- |
| [SamplingAtlas](SamplingAtlas/README.md) | Geographic inventory, annual maps, GIFs and record-level evidence | `SamplingAtlas/index.html` in a browser |
| [SpeciesSelection](SpeciesSelection/README.md) | Same-year, same-stage sampling opportunities at bounded sites; sensitivity and evidence gaps | [selection_report.md](SpeciesSelection/selection_report.md) |
| [SelectionAudit](SelectionAudit/README.md) | Descriptive audit of the older inputs and candidate lists | [audit_summary.json](SelectionAudit/audit_summary.json) |
| [Files](Files/README.md) | Legacy tables, including curated names reused by the current atlas | Directory guide |
| [Figures](Figures/README.md) | Legacy figures and tabulated summaries | Directory guide |

`AtlasPreview/`, `AtlasDataOnly/` and, if generated, `AtlasNoGIF/` are local test or
intermediate builds. They are ignored by Git and are not the shared atlas.

## How the outputs relate

The atlas reads the original museum export and existing name curation. Its
selection tables provide broad geographic summaries. The separate
`SpeciesSelection/` workflow reads the atlas's record audit and evaluates closer
site/year/stage comparisons. `SelectionAudit/` documents the legacy baseline;
it does not supply the current species eligibility decisions.

Approximate atlas display coordinates improve visualization, but the selection
screen uses recorded coordinates. Catalog counts do not establish available
genomes, verified collection events or a final species panel.

## Rebuilding and sharing

Run commands from the repository root; see [Scripts](../Scripts/README.md).
Generated files with matching names are replaced on rerun. Put lasting corrections
in [config](../config/README.md), rather than editing generated CSVs.

Share the entire `SamplingAtlas/` directory so its relative image and download
links work. Annual PDFs are still linked from the viewer. The ignored render
caches and obsolete matrix previews are unnecessary for browsing. The main atlas,
selection results and audit are eligible for version control; adding these files
is a separate Git operation.

Despite its name, `Files/` contains curated inputs required by the current atlas.
Do not treat every file under `Output/` as disposable.

## Genomic data for contemporary comparisons

[Genomics](Genomics/README.md) contains a [filterable viewer](Genomics/index.html),
SQLite database and CSV tables covering public WGS, genome skimming, annotated
assemblies, collection dates and geographic metadata for the 80-species roster.
Mapping candidates count BioSample accessions and still require independent-fish
and population review before integration with historical specimen heatmaps.
