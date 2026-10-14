#!/usr/bin/env Rscript
# Downstream selection digest. Run after build_sampling_atlas.R (data-only also works).
# Usage: Rscript Scripts/summarize_sampling_candidates.R [Output/SamplingAtlas]
args <- commandArgs(trailingOnly = TRUE)
out <- if (length(args)) args[1] else "Output/SamplingAtlas"
input <- file.path(out, "tables", "records_audit.csv")
r <- read.csv(input, stringsAsFactors = FALSE, na.strings = "")
config <- dget(file.path(out, "resolved_config.R"))
d <- r[r$included & r$species_eligible & r$dated_mapped & !r$availability_flag, ]
groups <- split(d, interaction(d$species, d$life_stage, d$region, drop = TRUE))
regional <- do.call(rbind, lapply(groups, function(z) {
  years <- tapply(z$specimen_count, z$year, sum)
  cells <- tapply(z$specimen_count, z$cell_id, sum)
  data.frame(species = z$species[1], life_stage = z$life_stage[1], region = z$region[1],
    dated_mapped_specimens = sum(z$specimen_count), lots = nrow(z),
    sampled_years = length(years), first_year = min(z$year), last_year = max(z$year),
    cells = length(cells), cells_meeting_threshold = sum(cells >= config$min_cell_period_specimens),
    strongest_year = as.integer(names(years)[which.max(years)]),
    strongest_year_specimens = max(years),
    largest_lot_fraction = max(z$specimen_count) / sum(z$specimen_count),
    unvalidated_taxonomy_specimens = sum(z$specimen_count[z$taxonomy_status == "catalog_binomial_unvalidated"]),
    stage_unrecorded_specimens = sum(z$specimen_count[z$stage_evidence == "stage_unrecorded"]))
}))
regional <- regional[order(regional$region, regional$life_stage, -regional$dated_mapped_specimens), ]
write.csv(regional, file.path(out, "tables", "regional_candidates.csv"), row.names = FALSE)
lines <- c("USFC HISTORICAL SAMPLING SELECTION DIGEST", "",
  sprintf("Species eligibility: >= %s dated specimens through %s, across stages and the study area.", config$min_specimens, config$max_year),
  "Below: dated, mapped physical specimens only; type/depleted/not-found flags excluded.",
  "Adult means non-larval; maturity is unverified. Counts are availability screens, not approved DNA samples.",
  "Regional totals are not automatically sufficient sample sizes at a single locality or time.", "")
for (region in c("Atlantic", "Caribbean", "Gulf of Mexico")) {
  for (stage in c("adult", "larva")) {
    z <- regional[regional$region == region & regional$life_stage == stage, ]
    z <- head(z, 10)
    lines <- c(lines, paste(toupper(region), "|", if (stage == "adult") "ADULT / NON-LARVAL" else "LARVAE"))
    for (i in seq_len(nrow(z))) lines <- c(lines, sprintf(
      "  %s: %s specimens, %s lots, %s years (%s-%s), %s cells; largest lot %.0f%%",
      z$species[i], z$dated_mapped_specimens[i], z$lots[i], z$sampled_years[i],
      z$first_year[i], z$last_year[i], z$cells[i], 100 * z$largest_lot_fraction[i]))
    if (!nrow(z)) lines <- c(lines, "  No eligible records.")
    lines <- c(lines, "")
  }
}
shared <- read.csv(file.path(out, "tables", "shared_year_assemblages.csv"), stringsAsFactors = FALSE)
lines <- c(lines, "SHARED SPECIES IN THE SAME CELL AND YEAR", "Each species has at least the configured cell-period threshold in that year.")
for (region in c("Atlantic", "Caribbean", "Gulf of Mexico")) {
  z <- head(shared[shared$region == region & shared$species_count >= 2, ], 3)
  for (i in seq_len(nrow(z))) lines <- c(lines,
    sprintf("  %s | %s | %s | southwest cell corner %s W, %s N | %s species, %s specimens",
      region, z$life_stage[i], z$year[i], -z$cell_lon[i], z$cell_lat[i], z$species_count[i], z$specimens[i]),
    paste("    ", z$species[i]))
}
lines <- c(lines, "", "NEXT SELECTION STEPS",
  "1. Start with shared-year cells in each basin; verify station, exact date, habitat and coordinate precision.",
  "2. Favor repeated localities and balanced time points over pooled species totals; inspect repeated_historical_cells.csv.",
  "3. Check dependence on one lot/year and keep larval/non-larval comparisons separate.",
  "4. Confirm taxonomy, museum availability, fixation history and pilot DNA recovery before final selection.",
  "5. Add generation length, dispersal, habitat, exploitation and modern resampling feasibility as curated traits.",
  "6. Repeat screening at alternative grid sizes and time windows before fixing 4-6 regional assemblages.")
writeLines(lines, file.path(out, "selection_digest.txt"))
index_path <- file.path(out, "index.html")
if (file.exists(index_path)) {
  index <- readLines(index_path)
  if (!any(grepl('href="selection_digest.txt"', index, fixed = TRUE))) {
    index <- sub('<input id="search"',
      '<p><a href="selection_digest.txt">Selection digest by basin and stage</a> · <a href="tables/regional_candidates.csv">Regional candidate comparison</a></p><input id="search"',
      index, fixed = TRUE)
    writeLines(index, index_path)
  }
}
write.csv(data.frame(path = c(input, "Scripts/summarize_sampling_candidates.R"),
  md5 = unname(tools::md5sum(c(input, "Scripts/summarize_sampling_candidates.R")))),
  file.path(out, "tables", "selection_digest_checksums.csv"), row.names = FALSE)
message("Wrote ", file.path(out, "selection_digest.txt"), " and tables/regional_candidates.csv")
