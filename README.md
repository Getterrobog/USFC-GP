![USFC_GP Logo](https://github.com/Getterrobog/USFC-GP/raw/main/USFC-GP.jpeg)  
# **USFC-GP**  
## The United States Fish Commission Genomics Project
### Comparative genomic analysis of historical 1880s USFC collections stored at USNM, and modern Western Atlantic coastal fishes to evaluate century-scale evolutionary shifts.

The U.S. Fish Commission Genomics Project (USFC-GP) is an integrative evolutionary genomics initiative examining century-scale spatial and temporal genomic shifts in Western Atlantic coastal fish species. We are using historical specimens collected by the U.S. Fish Commission vessels USS *Albatross*, USFC *Fish Hawk*, and USFC *Grampus* and housed at the U.S. National Museum.  These collections began in 1871 and continue to the present.  We will conduct a comparative analysis of the genomes of target species across temporal and spatial scales.  This repository houses analytical pipelines, bioinformatic workflows, genomic dataset metadata, and documentation supporting the project.

### Start here

- **Explore historical sampling:** read the [atlas guide](Output/SamplingAtlas/README.md),
  then open `Output/SamplingAtlas/index.html` in a browser after downloading or
  cloning the repository. The filters, annual maps and GIFs work locally.
- **Investigate candidate species and sites:** start with
  [species-selection results](Output/SpeciesSelection/README.md). These are
  historical sampling opportunities; final species selection still requires
  feasibility, laboratory and statistical evidence.
- **Understand the scientific question:** read the
  [proposal](background/one_page_proposal.txt) and
  [species selection plan](docs/species_selection_plan.md).

You do not need R to browse the saved results. R is needed to rebuild the atlas
or selection screen. The two workflows use the same curated museum inventory:
the atlas shows broad coverage, while the selection screen compares recorded
locations, individual years and life stages more closely.

| Directory | What belongs here |
| --- | --- |
| [Data](Data/README.md) | Museum export and supporting source material |
| [Scripts](Scripts/README.md) | Rebuild commands, reusable R functions and legacy tools |
| [config](config/README.md) | Analysis settings, reviewed corrections and approximate-location rules |
| [Output](Output/README.md) | Saved atlas, selection results, audit and legacy products |
| [docs](docs/README.md) | Detailed methods, interpretation and sampling-design protocol |
| [tests](tests/README.md) | Data-transformation and completed-output checks |
| [background](background/README.md) | Scientific proposal motivating the analyses |

The main atlas is included for sharing. Preview builds and rendering caches stay
local under [.gitignore](.gitignore). Keep the atlas's directory structure intact
when sharing it; the HTML page links to its images and tables by relative paths.

### **Project Personnel**  

**Principal Investigators:**  
Michelle Gaither, PhD, University of Central Florida  
Chris Bird, PhD, Texas A&M-Corpus Christi  
Malin Pinsky, PhD, University of California, Santa Cruz  

**Project Architect and Doctoral Student:**  
Iván R. López, MS, University of Central Florida  

**Collaborators:**  
Elizabeth Wallace, PhD, Florida Fish and Wildlife Conservation Commission  
Dianne Pitassy, MS, Museum Specialist, Division of Fishes, Smithsonian Institution  

### Historical sampling atlas

The reproducible R workflow in `Scripts/build_sampling_atlas.R` inventories species
with at least **50 dated specimens through 1930** across the Western Atlantic, the
Caribbean Sea, and the Gulf of Mexico. It separates larvae, adult/non-larval lots, and
unsplit mixed-stage lots, and produces annual geographic heatmaps, animated GIFs,
per-year geographic PNGs, and candidate-selection tables. The atlas page provides
year selection and Play/Stop GIF controls with a fixed map extent for every frame.
Filter candidates jointly by species name, specimen count, life stage, region,
sampled years, and whether coordinates are recorded.
Each species card also shows available life-history characteristics. Additional
filters combine habitat, water type, migration, reproduction, and fisheries
categories with model age estimates and reported maximum lengths by type.
Maps use 2° cells and hatch cells containing approximate display locations derived
from locality metadata. Original coordinates and estimate provenance remain
separate; precise-location candidate screens use recorded coordinates only.

```bash
Rscript Scripts/install_atlas_dependencies.R
Rscript tests/test_sampling_atlas.R
Rscript Scripts/build_sampling_atlas.R
Rscript Scripts/summarize_sampling_candidates.R
```

GIF rendering also requires ImageMagick (`magick` or `convert`). Open
`Output/SamplingAtlas/index.html` after running. See
[the workflow and interpretation guide](docs/sampling_atlas.md) for assumptions,
configuration, output definitions, and sampling-design guidance.

### Species selection protocol

The [species selection plan](docs/species_selection_plan.md) connects the proposal's
three aims to assemblage design, feasibility gates, DNA recovery pilots, power
analysis, portfolio selection and documentation for peer review. The
[repository review](docs/repository_review.md) records limitations of the legacy
candidate tables and explains how to reproduce the accompanying audit:

```bash
python3 Scripts/audit_selection_inputs.py
```

The audit writes to `Output/SelectionAudit/` and requires only Python's standard
library. Its descriptive counts do not establish final species eligibility.

The [implemented historical screen](docs/species_selection_workflow.md) reuses the
completed atlas to compare bounded sites, separate years and life stages, and
evaluate 72 screening scenarios:

```bash
Rscript tests/test_species_selection.R
Rscript Scripts/build_species_selection.R
```

Read the [first-pass results](Output/SpeciesSelection/selection_report.md) for the
species investigation queue, candidate assemblages and outstanding evidence.

## Public genomic data

The [genomic inventory](Output/Genomics/index.html) summarizes public WGS,
low-coverage/genome-skimming records and annotated assemblies for the 80 atlas
species. [Output documentation](Output/Genomics/README.md) explains the SQLite
and CSV tables, collection metadata and candidates for future contemporary maps.
Rebuild with `Rscript Scripts/build_genomics_inventory.R` (offline cached metadata)
and consult [methods](docs/genomics_inventory.md) before interpreting sample
accessions as independent fish. Original responses are in [Data/Genomics](Data/Genomics/README.md).
