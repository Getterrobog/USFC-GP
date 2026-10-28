#!/usr/bin/env Rscript
# Run from the repository root. Installation is explicit, never part of analysis.
dir.create(".R-library", showWarnings = FALSE)
install.packages("maps", lib = ".R-library", repos = "https://cloud.r-project.org")
message("Also install ImageMagick (magick or convert) to render GIFs.")
