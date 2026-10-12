#!/usr/bin/env Rscript
# Usage: Rscript Scripts/build_sampling_atlas.R [--config=path] [--data-only]
#        [--species=Menidia_menidia,Anchoa_mitchilli] [--output=path] [--no-gifs]
#        [--resume] [--limit=20]
# Paths are resolved from this script, so invocation works outside the repository.
args <- commandArgs(trailingOnly = TRUE)
script_arg <- grep("^--file=", commandArgs(), value = TRUE)
root <- normalizePath(file.path(dirname(sub("^--file=", "", script_arg[1])), ".."))
setwd(root)
if (dir.exists(".R-library")) .libPaths(c(normalizePath(".R-library"), .libPaths()))
source("Scripts/sampling_atlas_functions.R")
value_arg <- function(name, default) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[1]) else default
}
known <- grepl("^--(config|species|output|limit)=", args) | args %in% c("--data-only", "--no-gifs", "--resume")
if (any(!known)) stop("Unknown arguments: ", paste(args[!known], collapse = " "))
config_file <- value_arg("config", "config/sampling_atlas.R")
source(config_file)
config <- atlas_config
config$output <- value_arg("output", config$output)
species_arg <- value_arg("species", "")
if (nzchar(species_arg)) config$render_species <- gsub("_", " ", strsplit(species_arg, ",", fixed = TRUE)[[1]])
if ("--no-gifs" %in% args) config$render_gifs <- FALSE
stopifnot(config$cell_degrees > 0, config$min_specimens >= 1,
          config$unknown_stage %in% c("adult", "unknown"),
          config$animation_years %in% c("observed", "all"),
          config$early_end <= config$historical_end, config$historical_end <= config$max_year,
          config$bounds['west'] < config$bounds['east'], config$bounds['south'] < config$bounds['north'])
data_only <- "--data-only" %in% args
resume <- "--resume" %in% args
render_limit <- as.numeric(value_arg("limit", "Inf"))
stopifnot(!is.na(render_limit), render_limit >= 1)
if (!data_only) {
  if (!requireNamespace("maps", quietly = TRUE)) stop("Run Rscript Scripts/install_atlas_dependencies.R first.")
  if (config$render_gifs && !any(nzchar(Sys.which(c("magick", "convert"))))) stop("Install ImageMagick, or use --no-gifs.")
}
dir.create(file.path(config$output, "tables"), recursive = TRUE, showWarnings = FALSE)
write_table <- function(x, name) write.csv(x, file.path(config$output, "tables", paste0(name, ".csv")), row.names = FALSE, na = "", fileEncoding = "UTF-8")
message("Reading original museum records and cached taxonomy...")
records <- prepare_atlas_records(config)
summaries <- summarize_species(records, config)
eligible <- summaries$species[summaries$eligible]
if (!length(eligible)) stop("No species meet the configured dated-specimen threshold.")
records$species_eligible <- records$species %in% eligible
atlas <- records[records$included & records$species_eligible, ]
annual <- atlas[atlas$dated_mapped, ]
annual_cells <- sum_groups(annual, c("species", "life_stage", "year", "cell_id", "cell_lon", "cell_lat"))
unknown_cells <- sum_groups(atlas[atlas$mapped & is.na(atlas$year), ], c("species", "life_stage", "cell_id", "cell_lon", "cell_lat"))
screen <- build_screening_tables(records, eligible, config)
candidates <- summaries[summaries$eligible, ]
candidates$repeated_historical_cells <- vapply(candidates$species, function(sp) length(unique(screen$repeated_historical_cells$cell_id[screen$repeated_historical_cells$species == sp])), integer(1))
cell_table <- screen$cell_period_sampling
candidates$qualified_historical_regions <- vapply(candidates$species, function(sp) {
  z <- cell_table[cell_table$species == sp & cell_table$period != "Later collections" & cell_table$specimens >= config$min_cell_period_specimens, ]
  length(unique(z$region))
}, integer(1))
candidates <- candidates[order(-candidates$qualified_historical_regions, -candidates$repeated_historical_cells,
  -candidates$dated_mapped_specimens, candidates$species), ]
write_table(records, "records_audit")
write_table(summaries, "species_summary")
write_table(candidates, "candidate_screening")
write_table(annual_cells, "annual_geographic_counts")
write_table(unknown_cells, "undated_geographic_counts")
for (name in names(screen)) write_table(screen[[name]], name)
write_table(sum_groups(atlas, c("species", "life_stage", "region", "period")), "regional_stage_period_counts")
write_table(sum_groups(atlas, c("species", "life_stage", "year_status")), "date_quality_counts")
write_table(sum_groups(atlas, c("species", "life_stage", "stage_evidence")), "stage_evidence_counts")
write_table(records[!records$included, ], "excluded_records")
issues <- records$included & (is.na(records$year) | !records$mapped | records$life_stage == "mixed" |
  records$taxonomy_status == "catalog_binomial_unvalidated" | records$availability_flag)
write_table(records[issues, ], "review_queue")
audit_counts <- as.data.frame(table(ifelse(records$included, "included", records$exclusion_reason)), stringsAsFactors = FALSE)
names(audit_counts) <- c("disposition", "records")
write_table(audit_counts, "record_disposition")
# Reconcile specimens at every aggregate; physical lot identity is checked upstream.
stopifnot(sum(annual_cells$specimens) == sum(atlas$specimen_count[atlas$dated_mapped]),
          sum(unknown_cells$specimens) == sum(atlas$specimen_count[atlas$mapped & is.na(atlas$year)]),
          all(summaries$eligibility_specimens[summaries$eligible] >= config$min_specimens),
          all(is.na(atlas$year) | atlas$year <= config$max_year))
writeLines(capture.output(dput(config)), file.path(config$output, "resolved_config.R"))
inputs <- unique(c(config$input, config$taxonomy, config$curated_names, config$manual_names, config$overrides,
                   config_file, "Scripts/build_sampling_atlas.R", "Scripts/sampling_atlas_functions.R"))
write_table(data.frame(path = inputs, md5 = unname(tools::md5sum(inputs))), "input_checksums")
writeLines(capture.output(sessionInfo()), file.path(config$output, "session_info.txt"))
if (!data_only) {
  coast <- maps::map("world", plot = FALSE, fill = TRUE,
    xlim = config$bounds[c("west", "east")], ylim = config$bounds[c("south", "north")])
  species_to_render <- if (is.null(config$render_species)) eligible else config$render_species
  if (any(!species_to_render %in% eligible)) stop("Requested preview species do not meet eligibility: ", paste(setdiff(species_to_render, eligible), collapse = ", "))
  manifest <- list()
  rendered_now <- 0L
  signature_config <- config
  signature_config$output <- NULL
  signature_config$render_species <- NULL
  signature <- list(config = signature_config, inputs = tools::md5sum(inputs),
                    R = R.version.string, maps = as.character(packageVersion("maps")))
  for (i in seq_along(species_to_render)) {
    sp <- species_to_render[i]
    checkpoint_path <- file.path(config$output, "species", slug(sp), "render_checkpoint.rds")
    if (resume && file.exists(checkpoint_path)) {
      checkpoint <- readRDS(checkpoint_path)
      paths <- unlist(checkpoint$manifest[c("pdf", "preview", "gif")], use.names = FALSE)
      paths <- file.path(config$output, paths[nzchar(paths)])
      paths <- c(paths, file.path(config$output, "species", slug(sp), "sampling_matrix.pdf"))
      if (identical(checkpoint$signature, signature) && all(file.exists(paths)) &&
          all(file.info(paths)$size > 0)) {
        manifest[[length(manifest) + 1L]] <- checkpoint$manifest
        message(sprintf("[%s/%s] Cached: %s", i, length(species_to_render), sp))
        next
      }
    }
    if (rendered_now >= render_limit) next
    message(sprintf("[%s/%s] Rendering: %s", i, length(species_to_render), sp))
    d <- atlas[atlas$species == sp, ]
    maximum <- max(1, annual_cells$specimens[annual_cells$species == sp], unknown_cells$specimens[unknown_cells$species == sp])
    stages <- unique(c("adult", "larva", sort(unique(d$life_stage))))
    species_manifest <- do.call(rbind, lapply(stages, function(stage)
      render_species_stage(d[d$life_stage == stage, ], sp, stage, maximum, config, coast)))
    render_sampling_matrix(d, sp, config)
    saveRDS(list(signature = signature, manifest = species_manifest), checkpoint_path)
    manifest[[length(manifest) + 1L]] <- species_manifest
    rendered_now <- rendered_now + 1L
  }
  manifest <- do.call(rbind, manifest)
  write_table(manifest, "artifact_manifest")
  write_atlas_index(manifest, summaries, config)
  if (length(unique(manifest$species)) < length(species_to_render)) {
    message("Partial render: rerun with --resume to complete the remaining species.")
  }
  identify <- Sys.which("identify")
  versions <- c(paste("maps", as.character(packageVersion("maps"))),
    if (nzchar(identify)) system2(identify, "-version", stdout = TRUE) else "ImageMagick identify not installed")
  writeLines(versions, file.path(config$output, "render_versions.txt"))
}
run_summary <- c(
  sprintf("Eligible species: %s (>= %s assigned-year specimens through %s, across stages)", length(eligible), config$min_specimens, config$max_year),
  sprintf("Original export records: %s; physical lots: %s", nrow(records), sum(records$object_kind == "Specimen/Lot")),
  sprintf("Eligible species inventory: %s lots; %s dated specimens; %s undated specimens", nrow(atlas), sum(atlas$specimen_count[!is.na(atlas$year)]), sum(atlas$specimen_count[is.na(atlas$year)])),
  sprintf("Dated and mapped specimens: %s; undated and mapped specimens: %s", sum(annual_cells$specimens), sum(unknown_cells$specimens)),
  sprintf("Stage totals: %s", paste(names(tapply(atlas$specimen_count, atlas$life_stage, sum)), tapply(atlas$specimen_count, atlas$life_stage, sum), collapse = "; ")),
  sprintf("Repeated historical species/stage/cells with >= %s specimens in each period: %s", config$min_cell_period_specimens, nrow(screen$repeated_historical_cells)),
  "Adults are non-larval inventory, not a claim of verified maturity. Mixed lots are not split without evidence.",
  "Unlabeled maturity, unvalidated taxonomy, missing coordinates/dates and availability concerns remain auditable.",
  "Broad regional partitions and 1-degree cells are screening units, not biological population boundaries.",
  "Types and availability-flagged lots are shown in the atlas but excluded from repeated-sampling/assemblage screening.",
  "Preservation Method is absent from the source export: year is not a DNA preservation or sequencing-feasibility test.",
  "No centroid imputation or date borrowing; approved corrections belong in config/sampling_overrides.csv.",
  "Shared early/late period membership is not proof of simultaneous collection. Inspect exact years, stations and lots before selecting assemblages.",
  if (data_only) "Mode: data-only (no visualization generated)." else sprintf("Rendered %s species-stage artifacts for %s species.", nrow(manifest), length(unique(manifest$species)))
)
writeLines(run_summary, file.path(config$output, "run_summary.txt"))
message(paste(run_summary[1:6], collapse = "\n"))
message("Finished: ", normalizePath(config$output))
