#!/usr/bin/env Rscript
# Run from the repository root: Rscript tests/test_sampling_atlas.R
source("Scripts/sampling_atlas_functions.R")
source("config/sampling_atlas.R")
year <- function(date, vessel) parse_collection_year(date, vessel)$year
stopifnot(year("8-Sep-06", "Albatross IV") == 2006L,
          year("8-Sep-06", "Albatross") == 1906L,
          year("19-Oct-94", "Fish Hawk") == 1894L,
          is.na(year("19-Oct-94", "Unknown vessel")),
          is.na(year("1884 to 1885", "Albatross")),
          year("1 Mar 1884 to 11 Mar 1884 (1884 Mar 01 - 1884 Mar 11)", "Albatross") == 1884L,
          is.na(year("(0000 Nov 22 - 0000 00 00)", "Albatross")))
stage <- classify_stage(c("Larvae:Tank:5", "", "", "", ""),
                        c("", "Larval and juvenile", "", "Juvenile", "Transferred during larval curation contract"))
stopifnot(identical(stage$life_stage, c("larva", "mixed", "adult", "adult", "adult")),
          classify_stage("", "", "unknown")$life_stage == "unknown")
stopifnot(identical(clean_identification(c("Alosa pseudoharengus (Wilson)", "Gobiidae", "Alosa cf. aestivalis", "Alosa sp.")),
                    c("Alosa pseudoharengus", NA_character_, NA_character_, NA_character_)))
region <- classify_region(c(-90, -65, -70, 140, NA, NA), c(27, 17, 42, 35, NA, NA),
  c("North Atlantic Ocean", "North Atlantic Ocean", "North Atlantic Ocean", "North Pacific Ocean", "Atlantic", "Atlantic"),
  c("", "", "", "", "Caribbean Sea", ""), c("United States", "", "United States", "Japan", "", ""), atlas_config$bounds)
stopifnot(identical(region$region[1:3], c("Gulf of Mexico", "Caribbean", "Atlantic")),
          !region$in_scope[4], region$in_scope[5], !region$in_scope[6])
fixture <- data.frame(species = c("A", "A", "B"), year = c(1900, 1900, 1900), specimen_count = c(4, 7, 2))
counts <- sum_groups(fixture, c("species", "year"))
stopifnot(counts$specimens[counts$species == "A"] == 11, counts$lots[counts$species == "A"] == 2)
# Integration checks guard duplicate genetic records, old date parsing and larval loss.
records <- prepare_atlas_records(atlas_config)
stopifnot(nrow(records) == nrow(read_char_csv(atlas_config$input)),
          !anyDuplicated(records$catalog_number[records$included]),
          all(records$object_kind[records$included] == "Specimen/Lot"),
          all(is.na(records$year[records$included]) | records$year[records$included] <= 1930),
          records$life_stage[records$catalog_number == "106208"] == "larva",
          records$life_stage[records$catalog_number == "299576"] == "mixed",
          all(records$life_stage[records$catalog_number %in% c("105434", "133799")] == "larva"),
          all(records$specimen_count[records$catalog_number %in% c("105434", "133799")] == 1),
          all(records$year[records$catalog_number == "433054"] == 2006),
          !any(records$included[records$catalog_number == "433054"]))
# Undated specimens cannot push a species over the historical threshold.
tiny <- records[which(records$included)[1:2], ]
tiny$species <- "Example species"; tiny$year <- c(1900L, NA_integer_)
tiny$specimen_count <- c(49, 1000); tiny$dated_mapped <- c(TRUE, FALSE)
s <- summarize_species(tiny, atlas_config)
stopifnot(!s$eligible, s$eligibility_specimens == 49)
tiny$specimen_count[1] <- 50
stopifnot(summarize_species(tiny, atlas_config)$eligible)
eligible <- summarize_species(records, atlas_config)
eligible <- eligible$species[eligible$eligible]
screen <- build_screening_tables(records, eligible, atlas_config)
stopifnot(all(screen$repeated_historical_cells$balanced_specimens >= atlas_config$min_cell_period_specimens))
# Region labels within a grid cell must not split a temporal replicate or duplicate it.
screen_fixture <- records[rep(which(records$dated_mapped)[1], 4), ]
screen_fixture$species <- "Example species"
screen_fixture$life_stage <- "adult"
screen_fixture$availability_flag <- FALSE
screen_fixture$specimen_count <- c(6, 6, 7, 7)
screen_fixture$year <- c(1890L, 1890L, 1910L, 1910L)
screen_fixture$period <- c("Early historical", "Early historical", "Late historical", "Late historical")
screen_fixture$region <- c("Atlantic", "Caribbean", "Atlantic", "Caribbean")
combined <- build_screening_tables(screen_fixture, "Example species", atlas_config)
stopifnot(nrow(combined$repeated_historical_cells) == 1L,
          combined$repeated_historical_cells$specimens_early == 12,
          combined$repeated_historical_cells$specimens_late == 14,
          nrow(combined$shared_year_assemblages) == 2L)
# Sample distribution must never change map longitude/latitude limits.
extent_plot <- tempfile(fileext = ".png")
png(extent_plot, width = 960, height = 760, type = "cairo")
draw_map(data.frame(cell_lon = -77, cell_lat = 37, specimens = 1),
         atlas_config$bounds, 50, atlas_config)
compact_extent <- par("usr")
draw_map(data.frame(cell_lon = c(-98, -52), cell_lat = c(8, 57), specimens = c(1, 50)),
         atlas_config$bounds, 50, atlas_config)
wide_extent <- par("usr")
dev.off()
unlink(extent_plot)
stopifnot(isTRUE(all.equal(compact_extent, c(-100, -50, 5, 60))),
          isTRUE(all.equal(wide_extent, compact_extent)))
# The selected-year bar ends at that year's total, including unmapped specimens;
# it must not become a full-height reference line or use another year's maximum.
timeline_fixture <- data.frame(year = c(1900L, 1900L, 1902L, NA_integer_),
  specimen_count = c(3, 4, 100, 50), mapped = c(TRUE, FALSE, TRUE, FALSE),
  coordinate_approximate = FALSE, region = "Atlantic")
timeline_env <- new.env(parent = environment(draw_frame))
timeline_env$segments <- function(x0, y0, x1, y1, ...) {
  timeline_env$highlight <- c(x0, y0, x1, y1)
  graphics::segments(x0, y0, x1, y1, ...)
}
timeline_env$abline <- function(..., col = NULL) {
  stopifnot(!identical(col, "#b72924"))
  graphics::abline(..., col = col)
}
timeline_draw <- draw_frame
environment(timeline_draw) <- timeline_env
timeline_plot <- tempfile(fileext = ".png")
png(timeline_plot, width = 960, height = 760, type = "cairo")
for (selected_year in c(1900L, 1902L, 1901L, NA_integer_)) {
  timeline_env$highlight <- NULL
  timeline_draw(timeline_fixture, data.frame(), c(1900L, 1902L), selected_year,
    "Example species", "adult", 100, atlas_config, coast = NULL)
  if (is.na(selected_year)) stopifnot(is.null(timeline_env$highlight))
  else {
    expected <- c(`1900` = 7, `1902` = 100, `1901` = 0)[as.character(selected_year)]
    stopifnot(identical(timeline_env$highlight, c(selected_year, 0, selected_year, unname(expected))))
  }
}
dev.off()
unlink(timeline_plot)
inventory <- geographic_frame_inventory(tiny, "Example species", "adult", atlas_config)
stopifnot(identical(inventory$label, c("1900", "Undated")),
          all(inventory$west == -100), all(inventory$east == -50),
          all(inventory$south == 5), all(inventory$north == 60),
          all(inventory$cell_degrees == 2))
# Approximation uses unique original positions, never specimen-weighted or chained
# imputations. Original coordinates and the precise-location screen stay intact.
location_fixture <- records[rep(which(records$mapped)[1], 6), ]
location_fixture$catalog_number <- as.character(seq_len(6))
location_fixture$longitude <- c(-76.6, -76.4, -76.6, NA, -90, NA)
location_fixture$latitude <- c(34.6, 34.8, 34.6, NA, 40, NA)
location_fixture$coordinates_valid <- c(TRUE, TRUE, TRUE, FALSE, TRUE, FALSE)
location_fixture$mapped <- c(TRUE, TRUE, TRUE, FALSE, TRUE, FALSE)
location_fixture$included <- c(TRUE, TRUE, TRUE, TRUE, TRUE, FALSE)
location_fixture$in_scope <- TRUE
location_fixture$coordinate_source <- c(rep("original_catalog", 3), "missing_or_invalid", "manual_override", "missing_or_invalid")
location_fixture$specimen_count <- c(1, 100, 1, 10, 1000, 1)
location_fixture$locality <- "Example inlet"
location_fixture$country <- "United States"; location_fixture$province_state <- "North Carolina"
location_fixture$station <- ""; location_fixture$region <- "Atlantic"
located <- add_display_locations(location_fixture, atlas_config)
stopifnot(identical(located$longitude, location_fixture$longitude),
          identical(located$latitude, location_fixture$latitude),
          identical(located$mapped, location_fixture$mapped),
          located$display_longitude[4] == -76.5, located$display_latitude[4] == 34.7,
          located$approximation_reference_positions[4] == 2,
          sum(located$coordinate_approximate) == 1,
          !located$display_mapped[6])
disabled_config <- atlas_config; disabled_config$approximate_locations <- FALSE
stopifnot(!any(add_display_locations(location_fixture, disabled_config)$coordinate_approximate))
display_counts <- display_cell_counts(located)
stopifnot(sum(display_counts$approximate_specimens) == 10,
          sum(display_counts$recorded_specimens) == 1102,
          all(display_counts$cell_lon %% 2 == 0), all(display_counts$cell_lat %% 2 == 0))
# Candidate filters exclude undated/out-of-scope records and retain distinct years.
filter_fixture <- records[rep(which(records$included)[1], 6), ]
filter_fixture$species <- "Example species"
filter_fixture$life_stage <- c("adult", "adult", "larva", "larva", "adult", "adult")
filter_fixture$region <- c("Atlantic", "Atlantic", "Atlantic", "Caribbean", "Atlantic", "Atlantic")
filter_fixture$year <- c(1900L, 1900L, 1901L, 1901L, NA_integer_, 1931L)
filter_fixture$specimen_count <- c(10, 20, 5, 7, 1000, 1000)
filter_fixture$mapped <- c(TRUE, FALSE, TRUE, FALSE, TRUE, TRUE)
filtered <- atlas_filter_counts(filter_fixture, "Example species", atlas_config)
stopifnot(sum(filtered$specimens) == 42, sum(filtered$mapped_specimens) == 15,
          filtered$years[filtered$life_stage == "adult"] == "1900",
          filtered$mapped_years[filtered$region == "Caribbean"] == "",
          nrow(atlas_filter_counts(filter_fixture, "Absent species", atlas_config)) == 0)
message("All sampling atlas checks passed.")
