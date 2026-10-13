#!/usr/bin/env Rscript
# Refresh geographic year PNGs and the browsing report without rerunning analysis.
# Usage: Rscript Scripts/refresh_sampling_atlas_index.R [Output/SamplingAtlas]
args <- commandArgs(trailingOnly = TRUE)
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])
root <- normalizePath(file.path(dirname(script), ".."))
setwd(root)
source("Scripts/sampling_atlas_functions.R")
out <- if (length(args)) args[1] else "Output/SamplingAtlas"
config <- dget(file.path(out, "resolved_config.R"))
config$output <- out
manifest <- read.csv(file.path(out, "tables", "artifact_manifest.csv"), stringsAsFactors = FALSE)
summaries <- read.csv(file.path(out, "tables", "species_summary.csv"), stringsAsFactors = FALSE)
records <- read.csv(file.path(out, "tables", "records_audit.csv"), stringsAsFactors = FALSE)
recover_geographic_frames(manifest, records, config)
write_atlas_index(manifest, summaries, config)
# Keep the original analysis provenance; record this report-only refresh separately.
inputs <- unique(c("Scripts/refresh_sampling_atlas_index.R", "Scripts/sampling_atlas_functions.R",
  "Scripts/sampling_atlas_report.R", "Scripts/sampling_atlas_locations.R", "Scripts/sampling_atlas_traits.R", "Scripts/sampling_atlas_taxonomy.R", atlas_taxonomy_inputs(config), atlas_trait_inputs(config), file.path(out, "tables", "records_audit.csv"),
  file.path(out, "resolved_config.R"), file.path(out, "tables", c("artifact_manifest.csv", "species_summary.csv")),
  file.path(out, manifest$pdf), file.path(out, manifest$gif[!is.na(manifest$gif) & nzchar(manifest$gif)])))
write.csv(data.frame(path = inputs, md5 = unname(tools::md5sum(inputs))),
  file.path(out, "tables", "report_refresh_checksums.csv"), row.names = FALSE)
message("Updated ", file.path(out, "index.html"))
