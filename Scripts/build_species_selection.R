#!/usr/bin/env Rscript
# Uses a completed atlas; never reruns its curation, taxonomy queries or graphics.
args <- commandArgs(trailingOnly = TRUE)
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])
root <- normalizePath(file.path(dirname(script), "..")); setwd(root)
if (any(!grepl("^--(config|output)=", args))) stop("Unknown argument.")
arg <- function(name, default) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[1]) else default
}
config_path <- arg("config", "config/species_selection.R")
source(config_path); config <- selection_config
config$output <- arg("output", config$output)
source("Scripts/species_selection_functions.R")
stopifnot(config$first_year <= config$last_year, config$min_species >= 2,
  config$min_specimens >= 1, config$min_lots >= 1, config$diameter_km > 0)
atlas_path <- file.path(config$atlas, "tables/records_audit.csv")
manifest_path <- file.path(config$atlas, "tables/input_checksums.csv")
manifest <- read.csv(manifest_path, stringsAsFactors = FALSE)
# Input data must match the atlas run. Code may have changed since that run;
# preserve its original manifest rather than claiming to reproduce that run.
data_paths <- manifest$path[grepl("\\.csv$", manifest$path)]
if (!config$raw %in% data_paths || any(!file.exists(data_paths))) stop("Atlas source files missing.")
if (any(unname(tools::md5sum(data_paths)) != manifest$md5[match(data_paths, manifest$path)]))
  stop("Atlas data inputs have changed. Use matching snapshots or update the atlas first.")
inputs <- unique(c(atlas_path, manifest_path, file.path(config$atlas, "resolved_config.R"),
  data_paths, config_path, "Scripts/build_species_selection.R", "Scripts/species_selection_functions.R"))
before <- tools::md5sum(inputs)
records <- read.csv(atlas_path, stringsAsFactors = FALSE, colClasses = c(catalog_number = "character"))
raw <- read.csv(config$raw, colClasses = "character", fileEncoding = "UTF-8-BOM", na.strings = NULL)
records <- join_selection_evidence(records, raw)
all_species <- sort(unique(records$species[records$species_eligible]))
if (any(!grepl("^[A-Z][a-z]+ [a-z][a-z-]+$", all_species)))
  stop("Atlas species keys must be pooled species-level accepted names.")
# Mutually exclusive primary reasons, retaining the atlas's detailed reasons by reference.
records$selection_reason <- ifelse(!records$included, "ATLAS_EXCLUDED",
  ifelse(!records$species_eligible, "BELOW_ATLAS_INVENTORY_THRESHOLD",
  ifelse(records$availability_flag, "AVAILABILITY_FLAGGED",
  ifelse(is.na(records$year), "DATE_UNRESOLVED",
  ifelse(records$year < config$first_year | records$year > config$last_year, "OUTSIDE_SCREEN_WINDOW",
  ifelse(!records$mapped, "LOCATION_UNRESOLVED", "SCREENED"))))))
d <- records[records$selection_reason == "SCREENED", ]
if (!nrow(d) || anyDuplicated(d$catalog_number) || any(d$object_kind != "Specimen/Lot"))
  stop("Screen requires unique physical lots.")
if (any(!is.finite(d$specimen_count) | d$specimen_count <= 0 | d$specimen_count %% 1 != 0))
  stop("Invalid count in atlas screen.")
geometry <- build_site_tree(d)
d <- assign_sites(d, geometry, config$diameter_km)
cells <- selection_cells(d, config$min_specimens, config$min_lots)
assemblages <- selection_assemblages(cells, config$min_species)
sites <- site_evidence(d, geometry, config$diameter_km)
species <- species_design_summary(cells, assemblages, d, all_species, config)
sensitivity <- selection_sensitivity(d, geometry, config)
species$sensitivity_scenarios_with_shared_cell <- vapply(species$species, function(sp)
  sum(sensitivity$species$species == sp), integer(1))
species$sensitivity_scenarios_total <- nrow(sensitivity$scenarios)
# Join site interpretation without changing ranking or row count.
a <- cbind(assemblages, sites[match(assemblages$site_id, sites$site_id),
  c("representative_locality", "regions", "diameter_km"), drop = FALSE])
rownames(a) <- NULL
shared <- a[a$meets_multispecies_screen, ]
key <- function(z) paste(z$site_id, z$life_stage, z$year, sep = "|")
edges <- cells[cells$qualifies & key(cells) %in% key(shared), ]
event_evidence <- assemblage_evidence(d, edges, shared)
matrix <- if (nrow(edges)) xtabs(~ species + site_id, edges) else matrix(integer(), 0, 0)
connectivity <- site_components(matrix)
incidence <- as.data.frame.matrix(matrix)
incidence <- cbind(species = rownames(incidence), incidence); rownames(incidence) <- NULL
gap_reasons <- c("DATE_UNRESOLVED", "LOCATION_UNRESOLVED", "AVAILABILITY_FLAGGED")
gaps <- records[records$species %in% species$species[species$candidate_sites > 0] & records$selection_reason %in% gap_reasons,
  c("record_id", "catalog_number", "species", "selection_reason", "date_original", "locality", "station", "vessel", "ezid")]
gate_text <- c(museum_access = "Confirm permitted individuals/tissues and destructive allowance by catalog number",
  preservation_history = "Find fixation/storage history by lot; collection year is insufficient",
  modern_match = "Identify matching locality, season, stage, field lead, access and cost",
  traits_and_habitat = "Source generation time, habitat/depth, migration and exploitation with uncertainty",
  dna_recovery = "Pilot endogenous fraction, complexity, contamination and comparable callable sequence",
  power = "Simulate endpoint adequacy from pilot recovery and the proposed paired design")
requests <- expand.grid(species = species$species[species$candidate_sites > 0], gate = names(gate_text), stringsAsFactors = FALSE)
requests$status <- "pending"; requests$required_evidence <- unname(gate_text[requests$gate])
requests$source <- ""; requests$reviewer <- ""
out <- config$output; dir.create(out, recursive = TRUE, showWarnings = FALSE)
write_table <- function(x, name) write.csv(x, file.path(out, paste0(name, ".csv")), row.names = FALSE, na = "")
write_table(records[, c("record_id", "catalog_number", "species", "exclusion_reason", "selection_reason")], "record_disposition")
write_table(d[, c("record_id", "catalog_number", "species", "identification", "taxonomy_status", "site_id", "life_stage", "stage_evidence", "year", "year_status", "specimen_count", "longitude", "latitude", "coordinate_source", "region", "station", "cruise", "date_original", "locality", "depth_original", "collection_method", "preservation_original", "ezid")], "screened_lots")
write_table(sites, "site_evidence"); write_table(cells, "species_site_year_cells")
write_table(a, "assemblage_candidates"); write_table(species, "species_investigation_queue")
write_table(incidence, "species_site_matrix"); write_table(gaps, "record_evidence_gaps")
write_table(connectivity, "site_connectivity")
write_table(event_evidence$species, "assemblage_species_evidence")
write_table(event_evidence$groups, "assemblage_date_station_review")
write_table(requests, "feasibility_requests")
write_table(sensitivity$scenarios, "sensitivity_scenarios")
write_table(sensitivity$species, "sensitivity_species_membership")
write_table(manifest, "atlas_input_manifest")
write_table(data.frame(path = inputs, md5 = unname(before)), "input_checksums")
writeLines(capture.output(dput(config)), file.path(out, "resolved_config.R"))
writeLines(capture.output(sessionInfo()), file.path(out, "session_info.txt"))
stopifnot(sum(cells$specimens) == sum(d$specimen_count), sum(cells$lots) == nrow(d),
  nrow(species) == length(all_species), !anyDuplicated(species$species))
if (!identical(before, tools::md5sum(inputs))) stop("An input changed during the run; rerun against a stable snapshot.")

if (nrow(edges)) {
  pdf(file.path(out, "species_site_matrix.pdf"), width = max(10, ncol(matrix) * .35 + 4),
    height = max(8, nrow(matrix) * .22 + 3), useDingbats = FALSE)
  par(mar = c(8, 15, 4, 2))
  image(seq_len(ncol(matrix)), seq_len(nrow(matrix)), t(matrix[nrow(matrix):1, , drop = FALSE]),
    axes = FALSE, xlab = "", ylab = "", col = c("#f3f3f3", "#add8e6", "#377eb8", "#093b66"),
    breaks = c(-.5, .5, 1.5, 2.5, max(3.5, max(matrix) + .5)))
  axis(1, seq_len(ncol(matrix)), colnames(matrix), las = 2, cex.axis = .65)
  axis(2, seq_len(nrow(matrix)), rev(rownames(matrix)), las = 2, cex.axis = .65)
  title("Species and candidate sampling sites", sub = "Counts of qualifying year × stage cells in multispecies groups; not usable genomes")
  legend("topright", c("No qualifying cell", "1", "2", "3+"), fill = c("#f3f3f3", "#add8e6", "#377eb8", "#093b66"), cex = .7, bg = "white")
  dev.off()
}
fmt <- function(x) format(x, trim = TRUE, scientific = FALSE)
lines <- c("# Species selection first pass", "",
  "This is a reproducible historical sampling screen, not a final species panel. Existing atlas names and curation are reused; subspecies remain pooled under the atlas's accepted species keys.", "",
  "## Results", "",
  sprintf("Of %s atlas inventory species, %s have records entering this screen (%s physical lots, %s catalogued specimens).", length(all_species), length(unique(d$species)), nrow(d), fmt(sum(d$specimen_count))), "",
  sprintf("At a maximum site diameter of %s km and at least %s specimens per species/site/year/stage, %s species occur in %s multispecies site/year/stage groups across %s candidate sites. Each group contains at least %s species.", config$diameter_km, config$min_specimens, sum(species$candidate_sites > 0), nrow(shared), length(unique(shared$site_id)), config$min_species), "",
  sprintf("%s species occur at two or more candidate sites. These are site links, not proof of distinct regional replication or population identity.", sum(species$candidate_sites >= 2)), "",
  sprintf("The candidate-site graph has %s connected components when sites are linked by shared focal species. Disconnected components require additional shared-species evidence or a design that explicitly accommodates the disconnected comparisons.", length(unique(connectivity$component))), "",
  "## Leading historical assemblage opportunities", "",
  "Rows are sorted by species count, then specimens. Nearby or repeated rows may belong to one regional assemblage. The full table retains every group, including those below the multispecies threshold.", "",
  "| Site | Locality label | Stage | Year | Species | Single-lot species |",
  "| --- | --- | --- | --- | --- | --- |")
for (i in seq_len(min(15, nrow(shared)))) {
  z <- shared[i, ]
  label <- gsub("|", "/", z$representative_locality, fixed = TRUE)
  lines <- c(lines, sprintf("| %s | %s | %s | %s | %s | %s |", z$site_id, label, z$life_stage, z$year, z$species_count, z$single_lot_species))
}
lines <- c(lines, "", "## Species investigation queue", "",
  "This ordering prioritizes links among candidate sites, then multiple-lot explicit-year cells and repeated site/stage sampling, with alphabetical ties. It does not evaluate biology or modern availability.", "",
  "| Species | Candidate sites | Shared cells | Repeated site/stage pairs | Sensitivity scenarios with a shared cell |",
  "| --- | --- | --- | --- | --- |")
q <- species[species$candidate_sites > 0, ]
for (i in seq_len(nrow(q))) lines <- c(lines, sprintf("| %s | %s | %s | %s | %s/%s |", q$species[i], q$candidate_sites[i], q$shared_species_site_year_cells[i], q$repeated_site_stage_pairs[i], q$sensitivity_scenarios_with_shared_cell[i], q$sensitivity_scenarios_total[i]))
lines <- c(lines, "", "## Sensitivity and interpretation", "",
  sprintf("The %s scenarios vary diameter (%s km), minimum specimens (%s), minimum lots (%s), explicit-only versus all assigned years, and final year (%s). The atlas inventory species frame and site coordinate tree are held fixed, so comparisons measure screening choices rather than taxonomy or upstream eligibility changes.", nrow(sensitivity$scenarios), paste(config$sensitivity_diameters, collapse = ", "), paste(config$sensitivity_specimens, collapse = ", "), paste(config$sensitivity_min_lots, collapse = ", "), paste(config$sensitivity_last_years, collapse = ", ")), "",
  "Scenario membership is descriptive sensitivity, not a selection probability. Species outside the baseline queue can enter other scenarios; see sensitivity_species_membership.csv.", "",
  "| Diameter km | Minimum specimens | Minimum lots | Candidate sites | Species in shared groups |",
  "| --- | --- | --- | --- | --- |")
scenario_slice <- sensitivity$scenarios[sensitivity$scenarios$diameter_km == config$diameter_km &
  sensitivity$scenarios$date_mode == "all_assigned" & sensitivity$scenarios$last_year == config$last_year, ]
for (i in seq_len(nrow(scenario_slice))) {
  z <- scenario_slice[i, ]
  lines <- c(lines, sprintf("| %s | %s | %s | %s | %s |", z$diameter_km, z$min_specimens, z$min_lots, z$assemblage_sites, z$species))
}
lines <- c(lines, "",
  "Locations remain catalog centroids with unquantified accuracy. Complete-linkage bounds coordinate spread, but does not validate habitat, station identity, population connectivity or coastline barriers. Same-year proximity is not proof of the same collection event. Adult means non-larval with maturity unverified; stages are never pooled.", "",
  "Catalog numbers, original names, station/date/locality/depth/gear and persistent record links are in screened_lots.csv. assemblage_species_evidence.csv gathers those source labels for each species contributing to a shared group. assemblage_date_station_review.csv identifies date labels and vessel/station/day labels shared by all qualifying species. These are evidence leads, not verified collection events; empty intersections can also reflect inconsistent formatting. Named locality labels describe the most frequently recorded label in a site, not authoritative site boundaries. No missing positions or dates are imputed.", "",
  sprintf("The targeted record evidence queue contains %s excluded lots for species represented in baseline multispecies groups. Feasibility requests cover museum access, preservation, modern matching, biological predictors, DNA recovery and statistical power; all remain pending until sourced evidence is entered.", nrow(gaps)), "",
  "## Reproduction", "", "```bash", "Rscript Scripts/build_species_selection.R", "```", "",
  "See [workflow documentation](../../docs/species_selection_workflow.md), [the protocol](../../docs/species_selection_plan.md), and [the species by site figure](species_site_matrix.pdf). Input checksums, the original atlas input manifest, resolved configuration and R session information accompany these results. No live queries, raw-data edits or atlas rebuilds occur.")
writeLines(lines, file.path(out, "selection_report.md"))
outputs <- list.files(out, full.names = TRUE)
outputs <- outputs[basename(outputs) != "output_checksums.csv"]
write_table(data.frame(path = basename(outputs), md5 = unname(tools::md5sum(outputs))), "output_checksums")
message(sprintf("Screened %s atlas species; %s species in %s multispecies groups across %s sites. Wrote %s", length(all_species), sum(species$candidate_sites > 0), nrow(shared), length(unique(shared$site_id)), out))
