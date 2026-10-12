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
message("All sampling atlas checks passed.")
