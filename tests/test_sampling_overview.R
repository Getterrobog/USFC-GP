#!/usr/bin/env Rscript
# Run after Scripts/build_sampling_overview.R, from the repository root.
source("Scripts/sampling_atlas_functions.R")
out <- "Output/SamplingAtlas"
config <- dget(file.path(out, "resolved_config.R"))
records <- read.csv(file.path(out, "tables", "records_audit.csv"), stringsAsFactors = FALSE)
manifest <- read.csv(file.path(out, "tables", "overview_manifest.csv"), stringsAsFactors = FALSE)
saved <- read.csv(file.path(out, "tables", "overview_cells.csv"),
  colClasses = c(cell_label = "character", years = "character", year_specimens = "character"), stringsAsFactors = FALSE)
computed <- overview_cell_summary(records, manifest$species)
stopifnot(isTRUE(all.equal(saved, computed, check.attributes = FALSE)), nrow(manifest) == 80L,
  all(manifest$west == -100), all(manifest$east == -50),
  all(manifest$south == 5), all(manifest$north == 60), all(manifest$cell_degrees == 2))
for (sp in manifest$species) {
  d <- records[records$included & records$species %in% sp, ]
  m <- manifest[manifest$species == sp, ]; z <- saved[saved$species == sp, ]
  stopifnot(m$specimens == sum(d$specimen_count),
    m$display_mapped_specimens == sum(d$specimen_count[d$display_mapped]),
    m$recorded_specimens == sum(d$specimen_count[d$mapped]),
    m$approximate_specimens == sum(d$specimen_count[d$coordinate_approximate]),
    m$specimens == m$display_mapped_specimens + m$unmapped_specimens,
    m$undated_specimens == sum(d$specimen_count[is.na(d$year)]), m$cells == nrow(z))
  svg <- readLines(file.path(out, m$svg))
  stopifnot(sum(grepl('class="sample-cell"', svg, fixed = TRUE)) == nrow(z),
    sum(grepl('class="year-label"', svg, fixed = TRUE)) == nrow(z))
  for (i in seq_len(nrow(z))) {
    selected <- d[d$display_mapped & d$display_cell_id == z$cell_id[i], ]
    stopifnot(z$years[i] == paste(sort(unique(na.omit(selected$year))), collapse = ";"),
      z$undated_specimens[i] == sum(selected$specimen_count[is.na(selected$year)]))
    expected <- tapply(selected$specimen_count[!is.na(selected$year)],
      selected$year[!is.na(selected$year)], sum)
    counts <- if (nzchar(z$year_specimens[i])) as.numeric(strsplit(z$year_specimens[i], ";", fixed = TRUE)[[1]]) else numeric()
    stopifnot(identical(counts, as.numeric(expected)),
      sum(counts) + z$undated_specimens[i] == z$specimens[i])
  }
}
# Same year in multiple stages/lots appears once; undated counts remain separate.
fixture <- records[rep(which(records$display_mapped & records$included)[1], 5), ]
fixture$species <- "Example species"; fixture$life_stage <- c("adult", "larva", "mixed", "adult", "adult")
fixture$year <- c(1900L, 1900L, NA_integer_, 1902L, 1899L)
fixture$specimen_count <- c(2, 3, 5, 7, 999)
fixture$included[5] <- FALSE
fixture$mapped <- c(TRUE, FALSE, TRUE, FALSE, TRUE)
fixture$coordinate_approximate <- !fixture$mapped
z <- overview_cell_summary(fixture, "Example species")
stopifnot(nrow(z) == 1, z$specimens == 17, z$years == "1900;1902", z$undated_specimens == 5,
  z$year_specimens == "5;7", z$approximate_specimens == 10,
  overview_year_label(z$years, z$undated_specimens, z$year_specimens) == "1900 (5), 1902 (7), Undated (5)",
  overview_year_label("", 5, "") == "Undated (5)",
  identical(overview_wrap_year_label("1900 (5), 1902 (7), Undated (5)", width = 20),
    c("1900 (5), 1902 (7),", "Undated (5)")))
fixture$display_mapped <- FALSE
stopifnot(nrow(overview_cell_summary(fixture, "Example species")) == 0)
y <- overview_label_positions(rep(200, 4), c(22, 60, 40, 22), 100, 400)
stopifnot(all(diff(y) >= c(22, 60, 40) + 7), min(y) >= 100, tail(y, 1) + 22 <= 400)
stopifnot(inherits(try(overview_label_positions(c(0, 1), c(100, 100), 0, 100), silent = TRUE), "try-error"))
stopifnot(identical(unname(tools::md5sum(file.path(out, manifest$svg))), manifest$md5))
checksums <- read.csv(file.path(out, "tables", "overview_input_checksums.csv"))
stopifnot(identical(unname(tools::md5sum(checksums$path)), checksums$md5))
html <- paste(readLines(file.path(out, "overview.html")), collapse = "\n")
stopifnot(regexpr("</form>", html, fixed = TRUE)[1] < regexpr("<article ", html, fixed = TRUE)[1])
links <- regmatches(html, gregexpr('(?:href|src)="[^"]+"', html, perl = TRUE))[[1]]
paths <- sub('^[^=]+="([^"]+)"$', "\\1", links)
local_paths <- paths[!grepl("^https://", paths)]
stopifnot(all(file.exists(file.path(out, local_paths))))
message("Overview checks passed: 80 species, pooled counts, exact cell years, undated and approximate counts, label spacing, links and provenance.")
