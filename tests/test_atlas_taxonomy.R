#!/usr/bin/env Rscript
# Protect scientific-name linkage when attaching display metadata.
source("Scripts/sampling_atlas_functions.R")
config <- dget("Output/SamplingAtlas/resolved_config.R")
records <- read.csv("Output/SamplingAtlas/tables/records_audit.csv", stringsAsFactors = FALSE)
species <- unique(read.csv("Output/SamplingAtlas/tables/artifact_manifest.csv")$species)
tax <- read_atlas_taxonomy(species, records, config)
stopifnot(identical(tax$species, species), nrow(tax) == 80L,
  all(nzchar(tax$order)), all(nzchar(tax$family)),
  length(unique(tax$order)) == 15L, length(unique(tax$family)) == 44L)
menidia <- tax[tax$species == "Menidia menidia", ]
stopifnot(menidia$order == "Atheriniformes", menidia$family == "Atherinopsidae",
  menidia$common_name == "Atlantic silverside")
withheld <- tax[tax$species == "Myctophum opalinum", ]
stopifnot(withheld$common_name == "", withheld$common_name_source_species == "")
alias <- tax[tax$species == "Atherina harringtonensis", ]
stopifnot(alias$common_name_source_species == "Hypoatherina harringtonensis",
  alias$common_name_match_status == "documented_combination")
# Independent SpecCode linkage must agree with the exact-name attachment.
matches <- read.csv(atlas_trait_source(config), stringsAsFactors = FALSE)
cache <- read.csv("Output/LifeHistory/source_records/species.csv", stringsAsFactors = FALSE)
expected <- cache$FBname[match(matches$fishbase_spec_code[match(species, matches$species)], cache$SpecCode)]
expected[is.na(expected)] <- ""
stopifnot(identical(tax$common_name, expected))
# Audit ordering is immaterial; stale source-row/catalog linkage is rejected.
stopifnot(identical(read_atlas_taxonomy(species, records[nrow(records):1, ], config), tax))
bad <- records; bad$catalog_number[1] <- "wrong catalog"
stopifnot(inherits(try(read_atlas_taxonomy(species, bad, config), silent = TRUE), "try-error"))
missing_config <- config; missing_config$life_history <- tempfile(fileext = ".csv")
missing <- read_atlas_taxonomy(species, records, missing_config)
stopifnot(identical(missing$species, species), all(missing$common_name == ""), identical(missing$order, tax$order))
message("Atlas taxonomy checks passed: catalog linkage, curated common names, aliases, withheld and missing sources.")
