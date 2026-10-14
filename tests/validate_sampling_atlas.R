#!/usr/bin/env Rscript
# Validate a COMPLETE rendered build, including GIF frames and relative report links.
# Usage: Rscript tests/validate_sampling_atlas.R [Output/SamplingAtlas]
args <- commandArgs(trailingOnly = TRUE)
out <- if (length(args)) args[1] else "Output/SamplingAtlas"
read_table <- function(name) read.csv(file.path(out, "tables", paste0(name, ".csv")),
                                    stringsAsFactors = FALSE, na.strings = "")
manifest <- read_table("artifact_manifest")
summary <- read_table("species_summary")
records <- read_table("records_audit")
annual <- read_table("annual_geographic_counts")
undated <- read_table("undated_geographic_counts")
display_annual <- read_table("annual_display_geographic_counts")
display_undated <- read_table("undated_display_geographic_counts")
frames <- read_table("annual_frame_manifest")
config <- dget(file.path(out, "resolved_config.R"))
eligible <- summary$species[summary$eligible]
stopifnot(setequal(unique(manifest$species), eligible),
          !anyDuplicated(paste(manifest$species, manifest$life_stage)),
          all(summary$eligibility_specimens[summary$eligible] >= config$min_specimens))
for (sp in eligible) stopifnot(all(c("adult", "larva") %in% manifest$life_stage[manifest$species == sp]))
included <- records[records$included & records$species_eligible, ]
stopifnot(sum(manifest$specimens) == sum(included$specimen_count),
          sum(manifest$mapped_specimens) == sum(included$specimen_count[included$mapped]),
          sum(annual$specimens) == sum(included$specimen_count[included$dated_mapped]),
          sum(undated$specimens) == sum(included$specimen_count[included$mapped & is.na(included$year)]),
          all(annual$year <= config$max_year))
estimated <- included$coordinate_approximate
stopifnot(all(included$display_mapped == (included$mapped | estimated)),
          !any(included$mapped & estimated),
          all(is.finite(included$display_longitude[included$display_mapped])),
          all(is.finite(included$display_latitude[included$display_mapped])),
          sum(display_annual$specimens) == sum(included$specimen_count[included$display_mapped & !is.na(included$year)]),
          sum(display_annual$recorded_specimens) == sum(annual$specimens),
          sum(display_undated$recorded_specimens) == sum(undated$specimens),
          sum(display_annual$approximate_specimens) + sum(display_undated$approximate_specimens) == sum(included$specimen_count[estimated]),
          all(nzchar(included$approximation_basis[estimated])),
          all(nzchar(included$approximation_source[estimated])),
          sum(manifest$approximate_specimens) == sum(included$specimen_count[estimated]),
          all(frames$west == config$bounds['west']), all(frames$east == config$bounds['east']),
          all(frames$south == config$bounds['south']), all(frames$north == config$bounds['north']),
          all(frames$cell_degrees == config$cell_degrees))
for (i in seq_len(nrow(frames))) {
  f <- frames[i, ]
  z <- included[included$species == f$species & included$life_stage == f$life_stage, ]
  z <- if (is.na(f$year)) z[is.na(z$year), ] else z[!is.na(z$year) & z$year == f$year, ]
  stopifnot(f$specimens == sum(z$specimen_count),
            f$mapped_specimens == sum(z$specimen_count[z$mapped]),
            f$approximate_specimens == sum(z$specimen_count[z$coordinate_approximate]))
  path <- file.path(out, f$png)
  stopifnot(file.exists(path), identical(readBin(path, "raw", 8L), as.raw(c(137,80,78,71,13,10,26,10))))
}
identify <- Sys.which("identify")
for (i in seq_len(nrow(manifest))) {
  m <- manifest[i, ]
  for (field in c("pdf", "preview", "gif")) {
    if (is.na(m[[field]]) || !nzchar(m[[field]])) next
    path <- file.path(out, m[[field]])
    stopifnot(file.exists(path), file.info(path)$size > 0)
    if (field == "pdf") stopifnot(rawToChar(readBin(path, "raw", 4L)) == "%PDF")
    if (field == "gif") {
      stopifnot(rawToChar(readBin(path, "raw", 6L)) %in% c("GIF87a", "GIF89a"))
      if (nzchar(identify)) {
        info <- system2(identify, c("-ping", "-format", shQuote("%n %W %H\n"), shQuote(path)), stdout = TRUE)
        info <- read.table(text = info)
        stopifnot(nrow(info) == m$frames, all(info$V1 == m$frames),
                  all(info$V2 == config$width), all(info$V3 == config$height))
      }
    }
  }
}
index <- paste(readLines(file.path(out, "index.html")), collapse = "\n")
links <- regmatches(index, gregexpr('(?:href|src)="[^"]+"', index, perl = TRUE))[[1]]
paths <- sub('^[^=]+="([^"]+)"$', "\\1", links)
local_paths <- sub("#.*$","",paths[!grepl("^https://", paths)])
stopifnot(all(file.exists(file.path(out, local_paths))))
checksums <- read_table("input_checksums")
current_hashes <- unname(tools::md5sum(checksums$path))
changed <- checksums$path[is.na(current_hashes) | current_hashes != checksums$md5]
if (length(changed)) {
  # Report-only refreshes preserve the original scientific/render provenance.
  # Only the separate report module may differ, and its new dependencies and
  # unchanged PDF/GIF inputs must match the refresh's own checksum manifest.
  stopifnot(all(changed %in% "Scripts/sampling_atlas_report.R"))
  refresh <- read_table("report_refresh_checksums")
  stopifnot(all(changed %in% refresh$path),
            identical(unname(tools::md5sum(refresh$path)), refresh$md5))
}
message(sprintf("Validated %s species, %s stage artifacts, %s GIF frames; counts and all report links reconcile.",
                length(eligible), nrow(manifest), sum(manifest$frames)))
