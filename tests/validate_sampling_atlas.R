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
stopifnot(all(file.exists(file.path(out, paths))))
checksums <- read_table("input_checksums")
stopifnot(identical(unname(tools::md5sum(checksums$path)), checksums$md5))
message(sprintf("Validated %s species, %s stage artifacts, %s GIF frames; counts and all report links reconcile.",
                length(eligible), nrow(manifest), sum(manifest$frames)))
