#!/usr/bin/env Rscript
# Report attachment checks; run from the repository root.
source("Scripts/sampling_atlas_functions.R")
source("config/sampling_atlas.R")
roster <- read.csv("Output/SamplingAtlas/tables/species_summary.csv", stringsAsFactors = FALSE)
species <- roster$species[roster$eligible]
bundle <- read_atlas_traits(species, atlas_config)
stopifnot(identical(bundle$traits$species, species), nrow(bundle$traits) == 80L,
  sum(!is.na(bundle$traits$generation_time_model_years)) == 75L,
  identical(trait_tokens("Estuaries; Oceanic; Estuaries"), c("Estuaries", "Oceanic")))
lengths <- bundle$lengths
stopifnot(bundle$integrated,bundle$source=="Output/SpeciesTraits/species_summary.csv",
  sum(!is.na(bundle$traits$trophic_level_preferred))==67L,
  sum(nzchar(bundle$traits$body_shape))==79L,
  !anyDuplicated(paste(bundle$evidence$species,bundle$evidence$field,bundle$evidence$evidence_id)),
  all(c("positive_water_types","positive_habitat_tags","lifespan_model_years","migration_best_available") %in% bundle$evidence$field),
  identical(trait_category_values("yes; source life-stage context retained","schooling_reported"),"reported"),
  length(trait_category_values("","schooling_reported"))==0L)
menidia <- bundle$traits[bundle$traits$species=="Menidia menidia",]
stopifnot(menidia$depth_shallow_m==0,menidia$trophic_level_preferred==3.19,menidia$trophic_level_method=="diet",
  all(c("maturity_age_model_years","lifespan_model_years") %in% bundle$evidence$field[bundle$evidence$species=="Menidia menidia"]))
card <- paste(atlas_trait_card_html(menidia,bundle),collapse="\n")
stopifnot(grepl("diet estimate",card,fixed=TRUE),grepl("latest status unverified",card,fixed=TRUE),
  grepl("Menidia menidia|ecology|131|DietTroph",card,fixed=TRUE))
stopifnot(lengths$cm[lengths$species == "Gambusia affinis" & lengths$type == "TL"] == 7,
  lengths$cm[lengths$species == "Fenestraja plutonia" & lengths$type == "TL"] > 25,
  setequal(lengths$type[lengths$species == "Cyclopterus lumpus"], c("TL", "SL")),
  lengths$cm[lengths$species == "Cyclopterus lumpus" & lengths$type == "TL"] == 61)
withheld <- bundle$traits[bundle$traits$species == "Myctophum opalinum", ]
stopifnot(is.na(withheld$generation_time_model_years), !nzchar(withheld$positive_water_types),
  !any(lengths$species == "Myctophum opalinum"),
  any(grepl("Traits withheld", atlas_trait_card_html(withheld), fixed = TRUE)))
absent <- read_atlas_traits(c("Absent species", "Gambusia affinis"), atlas_config)$traits
stopifnot(identical(absent$species, c("Absent species", "Gambusia affinis")),
  absent$taxon_match_status[1] == "not_in_trait_output", is.na(absent$generation_time_model_years[1]))

# Reject ambiguous joins, negative numbers and accidental attachment to withheld taxa.
raw <- read.csv(atlas_trait_source(atlas_config), colClasses = "character", na.strings = "")
temp <- tempfile(fileext = ".csv")
cfg <- atlas_config; cfg$life_history <- temp
fails <- function(z) {
  write.csv(z, temp, row.names = FALSE, na = "")
  inherits(try(read_atlas_traits(species, cfg), silent = TRUE), "try-error")
}
stopifnot(fails(rbind(raw, raw[1, ])))
invalid <- raw; invalid$generation_time_model_years[1] <- "-1"
stopifnot(fails(invalid))
invalid <- raw; invalid$positive_water_types[invalid$species == "Myctophum opalinum"] <- "Saltwater"
stopifnot(fails(invalid))
unlink(temp)
empty <- read_atlas_traits(species, cfg)
stopifnot(!empty$available, identical(empty$traits$species, species),
  all(is.na(empty$traits$generation_time_model_years)), nrow(empty$lengths) == 0)
message("Atlas trait checks passed: exact joins, missingness, withheld taxonomy, numeric validation and length-type pooling.")
