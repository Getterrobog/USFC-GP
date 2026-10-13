#!/usr/bin/env Rscript
# Descriptive spatial sensitivity using the original frozen downstream evidence.
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])
root <- normalizePath(file.path(dirname(script), "..")); setwd(root)
source("config/species_selection_spatial.R"); config <- spatial_config
source("Scripts/species_selection_functions.R")
inputs <- c(config$lots, config$roster, config$original_sensitivity,
  config$original_membership, "config/species_selection_spatial.R",
  "Scripts/compare_selection_spatial_extent.R", "Scripts/species_selection_functions.R",
  "docs/species_selection_spatial_review.md", "tests/test_species_selection.R")
before <- tools::md5sum(inputs)
d <- read.csv(config$lots, stringsAsFactors = FALSE, na.strings = NULL,
  colClasses = c(catalog_number = "character"))
roster <- read.csv(config$roster, stringsAsFactors = FALSE)
stopifnot(nrow(roster) == 80, !anyDuplicated(roster$species), !anyDuplicated(d$catalog_number),
  all(d$species %in% roster$species), all(d$year >= 1880 & d$year <= 1930))
geometry <- build_site_tree(d)
result <- selection_sensitivity(d, geometry, config)
# Reproduce the common scenarios in the original release before adding extents.
old <- read.csv(config$original_sensitivity, stringsAsFactors = FALSE)
keys <- c("diameter_km", "min_specimens", "min_lots", "date_mode", "last_year")
key <- function(x, fields = keys) do.call(paste, c(x[fields], sep = "|"))
idx <- match(key(old), key(result$scenarios)); common <- !is.na(idx)
metrics <- c("qualified_cells", "assemblage_site_years", "assemblage_sites", "species")
stopifnot(all(as.matrix(old[common, metrics]) == as.matrix(result$scenarios[idx[common], metrics])))
old_members <- read.csv(config$original_membership, stringsAsFactors = FALSE)
for (i in which(common)) {
  previous <- sort(old_members$species[old_members$scenario_id == old$scenario_id[i]])
  current <- sort(result$species$species[result$species$scenario_id == result$scenarios$scenario_id[idx[i]]])
  stopifnot(identical(previous, current))
}
# Baseline-like comparisons hold year, stage and specimen thresholds unchanged.
summaries <- memberships <- sites_out <- cells_out <- vector("list", length(config$sensitivity_diameters))
for (i in seq_along(config$sensitivity_diameters)) {
  diameter <- config$sensitivity_diameters[i]
  records <- assign_sites(d, geometry, diameter)
  sites <- site_evidence(records, geometry, diameter)
  cells <- selection_cells(records, 10, 1)
  stopifnot(sum(cells$specimens) == sum(d$specimen_count), sum(cells$lots) == nrow(d))
  groups <- selection_assemblages(cells, config$min_species)
  shared <- groups[groups$meets_multispecies_screen, ]
  cell_key <- function(z) paste(z$site_id, z$life_stage, z$year, sep = "|")
  edges <- cells[cells$qualifies & cell_key(cells) %in% cell_key(shared), ]
  adult <- edges[edges$life_stage == "adult", ]
  shared_adult <- shared[shared$life_stage == "adult", ]
  count_cross <- function(z) if (nrow(z)) sum(table(unique(z[c("species", "site_id")])$species) >= 2) else 0L
  summaries[[i]] <- data.frame(maximum_diameter_km = diameter,
    all_stage_species = length(unique(edges$species)),
    all_stage_candidate_sites = length(unique(edges$site_id)),
    all_stage_shared_year_stage_groups = nrow(shared),
    adult_nonlarval_species = length(unique(adult$species)),
    adult_nonlarval_candidate_sites = length(unique(adult$site_id)),
    adult_nonlarval_shared_year_groups = nrow(shared_adult),
    species_at_multiple_sites = count_cross(edges),
    adult_nonlarval_species_at_multiple_sites = count_cross(adult),
    largest_adult_group_species = if (nrow(shared_adult)) max(shared_adult$species_count) else 0L)
  memberships[[i]] <- data.frame(maximum_diameter_km = diameter, species = roster$species,
    in_any_shared_group = roster$species %in% edges$species,
    in_adult_nonlarval_shared_group = roster$species %in% adult$species)
  candidate_sites <- sites[sites$site_id %in% shared$site_id, ]
  candidate_sites$maximum_diameter_km <- diameter
  candidate_sites$multiple_catalog_regions <- grepl(";", candidate_sites$regions)
  # Preserve raw depth/locality evidence; units are heterogeneous and not inferred.
  candidate_sites$recorded_depth_labels <- vapply(candidate_sites$site_id, function(id)
    paste(sort(unique(records$depth_original[records$site_id == id & nzchar(records$depth_original)])), collapse = " | "), character(1))
  candidate_sites$requires_habitat_and_population_review <- TRUE
  sites_out[[i]] <- candidate_sites
  cells_out[[i]] <- cbind(maximum_diameter_km = diameter, edges)
}
summary <- do.call(rbind, summaries)
membership <- do.call(rbind, memberships)
sites <- do.call(rbind, sites_out)
shared_cells <- do.call(rbind, cells_out)
base_species <- membership$species[membership$maximum_diameter_km == 20 & membership$in_any_shared_group]
membership$new_relative_to_20km <- membership$in_any_shared_group & !membership$species %in% base_species
stopifnot(all(membership$species %in% roster$species), all(sites$diameter_km <= sites$maximum_diameter_km + 1e-8))
out <- config$output; dir.create(out, recursive = TRUE, showWarnings = FALSE)
write_table <- function(x, name) write.csv(x, file.path(out, paste0(name, ".csv")), row.names = FALSE, na = "")
write_table(summary, "extent_summary")
write_table(membership, "species_membership")
write_table(sites, "candidate_site_evidence")
write_table(shared_cells, "shared_species_site_year_cells")
write_table(result$scenarios, "sensitivity_scenarios")
write_table(result$species, "sensitivity_species_membership")
write_table(data.frame(path = inputs, md5 = unname(before)), "input_checksums")
writeLines(capture.output(dput(config)), file.path(out, "resolved_config.R"))
writeLines(capture.output(sessionInfo()), file.path(out, "session_info.txt"))
lines <- c("# Wider spatial extent comparison", "",
  "Exploratory comparison using the frozen first-pass screened lots and all 80 existing species keys. No upstream curation, new species screening, date pooling, coordinate imputation or feasibility decisions.", "",
  "**Distances below are maximum pairwise diameters, not radii around a central point.** The original baseline is 20 km diameter; 40 km was a sensitivity setting. The wider extents are design alternatives, not estimated population boundaries.", "",
  sprintf("The fixed input contains %s lots, %s catalogued specimens and %s of the 80 species, within 1880–1930. Each qualifying species needs at least 10 catalogued specimens in the same year and stage; each shared group needs at least three species. Stages are kept separate.", nrow(d), sum(d$specimen_count), length(unique(d$species))), "",
  "| Maximum diameter km | Species, all stages | Species, adult/non-larval | Candidate sites, all stages | Adult/non-larval sites |",
  "| --- | ---: | ---: | ---: | ---: |")
for (i in seq_len(nrow(summary))) {
  z <- summary[i, ]
  lines <- c(lines, sprintf("| %s | %s | %s | %s | %s |", z$maximum_diameter_km,
    z$all_stage_species, z$adult_nonlarval_species, z$all_stage_candidate_sites, z$adult_nonlarval_candidate_sites))
}
lines <- c(lines, "", "## Stronger count/lot requirement", "",
  "For comparison, the following requires at least 20 specimens from two lots per species/site/year/stage (all assigned years, through 1930). These thresholds are screening settings, not validated genomic sample sizes.", "",
  "| Maximum diameter km | Species in shared groups | Candidate sites |",
  "| --- | ---: | ---: |")
z <- subset(result$scenarios, min_specimens == 20 & min_lots == 2 & date_mode == "all_assigned" & last_year == 1930)
for (i in seq_len(nrow(z))) lines <- c(lines, sprintf("| %s | %s | %s |", z$diameter_km[i], z$species[i], z$assemblage_sites[i]))
lines <- c(lines, "", "## Interpretation", "",
  "Increasing extent can bring more species into shared groups and merge nearby sites. Fewer sites after a merge is not necessarily less biological information, and extra sites are not automatically independent regional replicates. Neither nearby collections nor shared catalog region labels establish a common population or exposure.", "",
  "Use wider groups to discover regional assemblages, then retain nested localities, years and stages for historical–modern comparisons. Review coastlines, bays versus offshore habitat, source depth labels, migration and population structure before pooling specimens. candidate_site_evidence.csv exposes locality/region/depth labels rather than treating enlarged clusters as validated assemblages.", "",
  "The fixed screen excludes unresolved positions, years and availability flags. Widening alone does not recover excluded records. Same-year comparisons remain conservative; any later temporal-window expansion should be evaluated separately so its effects are distinguishable.", "",
  "## Reproducibility and checks", "",
  sprintf("The full grid contains %s scenarios spanning five extents, three specimen thresholds, two lot thresholds, two date-evidence modes and two final years. The %s overlapping original scenarios reproduce both counts and exact species membership. Every extent conserves lot/specimen totals and satisfies the geometric diameter bound. No final species roster is changed.", nrow(result$scenarios), sum(common)), "",
  "Run `Rscript Scripts/compare_selection_spatial_extent.R`. Configuration, input checksums and R session metadata accompany the outputs. See [the spatial review](../../docs/species_selection_spatial_review.md) and [the original protocol](../../docs/species_selection_plan.md).")
writeLines(lines, file.path(out, "spatial_extent_report.md"))
if (!identical(before, tools::md5sum(inputs))) stop("An input changed during the comparison.")
print(summary)
print(z[, c("diameter_km", "species", "assemblage_sites")])
message(sprintf("Validated %s original scenarios; wrote %s exploratory scenarios to %s", sum(common), nrow(result$scenarios), out))
