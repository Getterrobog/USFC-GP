# Per-species maps and animations

Use the [atlas viewer](../index.html) for browsing. This directory stores its
geographic media, with one subdirectory per accepted species. Spaces in species
names become underscores, for example `Menidia_menidia/`.

The same naming scheme applies throughout, so individual species directories do
not need separate instructions:

| Pattern | Meaning |
| --- | --- |
| `all_years.svg` | Combined species map with collection-year callouts for every sampled grid cell; used by the [companion page](../overview.html) |
| `adult.gif`, `larva.gif`, `mixed.gif` | Animation for one life stage; mixed appears where recorded |
| `adult_frames/year_1892.png` | Full geographic map for that stage and year |
| `adult_frames/undated.png` | Separate map for lots without an assigned year, when present |
| `adult_frames/no_records.png` | Explicit placeholder for a stage with no records |
| `adult_frames.csv` | Frame paths, year labels, counts, bounds and cell size |
| `adult_annual_maps.pdf` | Printable collection of annual geographic maps |
| `adult_preview.png` | First frame, also referenced in the artifact manifest |

Replace `adult` with the relevant stage in these examples. Adult means
adult/non-larval, with maturity unverified. Empty-stage GIFs are placeholders,
not sampling observations.

All current maps use the same bounds and 2° grid. Hatching marks cells containing
approximate display positions; see the [atlas interpretation guide](../README.md).
The [frame manifest](../tables/annual_frame_manifest.csv) lists the current PNGs
across all species. Filenames alone are not a substitute for that inventory.

Local `render_checkpoint.rds` and `*.pdf.inline.rds` files are caches. Old
`sampling_matrix.pdf`, `sampling_matrix_page_*.png` and
`*_annual_maps_page_*.png` files are superseded products. These are ignored by Git
and are not needed by the current viewer. Regenerate media through
[the R workflow](../../../Scripts/README.md); do not edit individual images.
