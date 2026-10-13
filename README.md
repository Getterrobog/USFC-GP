![USFC_GP Logo](https://github.com/Getterrobog/USFC-GP/raw/main/USFC-GP.jpeg)  
# **USFC-GP**  
## The United State Fish Commission Genomics Project
### Comparative genomic analysis of historical 1880s USFC collections stored at USNM, and modern Western Atlantic coastal fishes to evaluate century-scale evolutionary shifts.

The U.S. Fish Commission Genomics Project (USFC-GP) is an integrative evolutionary genomics initiative examining century-scale spatial and temporal genomic shifts in Western Atlantic coastal fish species. We are using historical specimens collected by the U.S. Fish Commission vessels USS *Albatross*, USFC *Fish Hawk*, and USFC *Grampus* and housed at the U.S. National Museum.  These collections started in 1871 and continued to the present.  We will conduct a comparative analysis of the genomes of target species across temporal and spatial scales.  This repository houses analytical pipelines, bioinformatic workflows, genomic dataset metadata, and documentation supporting the project.

### **Project Personnel**  

**Principal Investigators:**  
Michelles Gaither, PhD, University of Central Florida  
Chris Bird, PhD, Texas A&M Corpus Christi  
Malin Pinsky, PhD, University of California Santa Cruz  

**Project Architect and Doctoral Student:**  
Iván R. López, MS, University of Central Florida  

**Collaborators:**  
Elizabeth Wallace, PhD, Florida Fish and Wildlife Conservation Commission  
Dianne Pitassy, MS, Museum Specialist, Division of Fishes, Smithsonian Institution  

### Historical sampling atlas

The reproducible R workflow in `Scripts/build_sampling_atlas.R` inventories species
with at least **50 dated specimens through 1930** across the western Atlantic,
Caribbean, and Gulf of Mexico. It separates larvae, adult/non-larval lots, and
unsplit mixed-stage lots, and produces annual geographic heatmaps, animated GIFs,
per-year geographic PNGs, and candidate-selection tables. The atlas page provides
year selection and Play/Stop GIF controls with a fixed map extent for every frame.
Filter candidates jointly by species name, specimen count, life stage, region,
sampled years, and whether coordinates are recorded.
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
