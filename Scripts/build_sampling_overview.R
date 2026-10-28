#!/usr/bin/env Rscript
# Build the all-year companion page from an existing complete atlas.
# Usage: Rscript Scripts/build_sampling_overview.R [Output/SamplingAtlas]
args <- commandArgs(trailingOnly = TRUE)
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])
setwd(normalizePath(file.path(dirname(script), "..")))
if (dir.exists(".R-library")) .libPaths(c(normalizePath(".R-library"), .libPaths()))
source("Scripts/sampling_atlas_functions.R")
if (!requireNamespace("maps", quietly = TRUE)) stop("Run Scripts/install_atlas_dependencies.R first.")
out <- if (length(args)) args[1] else "Output/SamplingAtlas"
config <- dget(file.path(out, "resolved_config.R")); config$output <- out
records <- read.csv(file.path(out, "tables", "records_audit.csv"), stringsAsFactors = FALSE)
artifacts <- read.csv(file.path(out, "tables", "artifact_manifest.csv"), stringsAsFactors = FALSE)
species <- unique(artifacts$species)
cells <- overview_cell_summary(records, species)
coast <- maps::map("world", plot = FALSE, fill = TRUE,
  xlim = config$bounds[c("west", "east")], ylim = config$bounds[c("south", "north")])
manifest <- lapply(species, function(sp) {
  d <- records[records$included & records$species %in% sp, ]
  z <- cells[cells$species == sp, ]
  path <- file.path("species", slug(sp), "all_years.svg")
  write_overview_svg(z, d, sp, config, coast, file.path(out, path))
  data.frame(species = sp, specimens = sum(d$specimen_count),
    display_mapped_specimens = sum(z$specimens), recorded_specimens = sum(z$recorded_specimens),
    approximate_specimens = sum(z$approximate_specimens),
    unmapped_specimens = sum(d$specimen_count[!d$display_mapped]),
    undated_specimens = sum(d$specimen_count[is.na(d$year)]), cells = nrow(z),
    west = unname(config$bounds['west']), east = unname(config$bounds['east']),
    south = unname(config$bounds['south']), north = unname(config$bounds['north']),
    cell_degrees = config$cell_degrees, svg = path,
    md5 = unname(tools::md5sum(file.path(out, path))))
})
write.csv(cells, file.path(out, "tables", "overview_cells.csv"), row.names = FALSE, na = "")
write.csv(do.call(rbind, manifest), file.path(out, "tables", "overview_manifest.csv"), row.names = FALSE)
inputs <- c("Scripts/build_sampling_overview.R", "Scripts/sampling_atlas_overview.R",
  "Scripts/sampling_atlas_functions.R", "Scripts/sampling_atlas_locations.R",
  file.path(out, "resolved_config.R"), file.path(out, "tables", c("records_audit.csv", "artifact_manifest.csv")))
write.csv(data.frame(path = inputs, md5 = unname(tools::md5sum(inputs))),
  file.path(out, "tables", "overview_input_checksums.csv"), row.names = FALSE)
writeLines(capture.output(sessionInfo()), file.path(out, "overview_session_info.txt"))
status <- system2(file.path(R.home("bin"), "Rscript"),
  c("Scripts/refresh_sampling_atlas_index.R", shQuote(out)))
if (status != 0) stop("Maps were built, but the page refresh failed.")
message("Built ", length(species), " all-year maps: ", file.path(out, "overview.html"))
