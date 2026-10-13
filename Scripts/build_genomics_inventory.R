#!/usr/bin/env Rscript
# Rebuild scientific inventory from cached public metadata. Network is opt-in.
args <- commandArgs(trailingOnly = TRUE)
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])
setwd(normalizePath(file.path(dirname(script), "..")))
if (any(!args %in% c("--download", "--refresh", "--reuse-normalized"))) stop("Unknown argument")
if ("--refresh" %in% args && !"--download" %in% args) stop("--refresh requires --download")
source("config/genomics.R"); config <- genomics_config
source("Scripts/genomics_functions.R")
python <- Sys.which("python3"); if (python == "") python <- Sys.which("python")
if (python == "") stop("Python 3 is required for metadata transport and SQLite export (standard library only).")
if (!"--reuse-normalized" %in% args) {
  flags <- args[args %in% c("--download", "--refresh")]
  if (system2(python, c("Scripts/genomics_archive_io.py", flags)) != 0) stop("Metadata acquisition failed; outputs not rebuilt.")
}
input_files <- list.files(config$input, pattern = "\\.csv$", full.names = TRUE)
inputs <- c(config$roster, "config/genomics.R", "config/life_history_taxon_crosswalk.csv",
            "Scripts/genomics_archive_io.py", "Scripts/genomics_functions.R", "Scripts/build_genomics_inventory.R", input_files)
if (file.exists("config/genomics_assay_overrides.csv")) inputs <- c(inputs, "config/genomics_assay_overrides.csv")
before <- tools::md5sum(inputs)
read <- function(file) g_read(file.path(config$input, paste0(file, ".csv")))
taxa <- read("taxa"); roster <- g_read(config$roster)
stopifnot(nrow(taxa) == 80L, !anyDuplicated(taxa$species), setequal(taxa$species, roster$species), nrow(read("acquisition_errors")) == 0L)
runs <- g_classify_runs(read("runs")); assemblies <- g_assemblies(read("assemblies"))
# Curated assay exceptions must carry an accession-specific evidence URL and rationale.
runs$assay_override_evidence <- ""
if (file.exists("config/genomics_assay_overrides.csv")) {
  overrides <- g_read("config/genomics_assay_overrides.csv")
  for (i in seq_len(nrow(overrides))) {
    z <- overrides[i, ]; hit <- runs$species == z$species & runs$study_key == z$study_accession & runs$library_strategy == z$original_strategy
    if (!any(hit) || z$evidence_url == "" || z$reason == "") stop("Invalid assay override")
    runs$assay_class[hit] <- z$assay_class
    runs$assay_override_evidence[hit] <- paste(z$reason, z$evidence_url, sep = " | ")
    runs$wgs_eligible[hit] <- z$assay_class == "WGS"
    runs$short_read_wgs[hit] <- runs$wgs_eligible[hit] & runs$instrument_platform[hit] %in% c("ILLUMINA", "BGISEQ", "DNBSEQ", "ION_TORRENT", "LS454", "ABI_SOLID")
    runs$explicit_low_coverage_label[hit] <- z$explicit_low_coverage_label == "TRUE"
  }
}
stopifnot(!anyDuplicated(paste(runs$species, runs$run_accession)), !anyDuplicated(paste(assemblies$species, assemblies$assembly_accession)))
attributes <- read("sample_attributes")
message("Normalizing sample identities, dates, coordinates and biological context...")
samples <- g_build_samples(runs, assemblies, attributes, config)
# Species-level query outcomes are explicit: a zero search result is not proof of absence.
summary <- do.call(rbind, lapply(seq_len(nrow(taxa)), function(i) {
  t <- taxa[i, ]; sp <- t$species; r <- runs[runs$species == sp, ]; a <- assemblies[assemblies$species == sp, ]; s <- samples[samples$species == sp, ]
  w <- s[s$wgs_runs > 0, ]
  verified <- t$taxonomy_status %in% c("exact_name", "documented_name_mapping")
  data.frame(species=sp, archive_name=t$archive_name, tax_id=t$tax_id, taxonomy_status=t$taxonomy_status,
    investigation_tier=roster$investigation_tier[match(sp, roster$species)],
    query_status=if(verified) "complete" else "taxonomic_review_required",
    genome_availability=if(!verified) "unknown_taxonomy" else if(nrow(a)) "found" else "not_found_in_search",
    annotation_availability=if(!verified) "unknown_taxonomy" else if(any(a$annotation_available)) "found" else "not_reported_in_search",
    wgs_availability=if(!verified) "unknown_taxonomy" else if(any(r$wgs_eligible)) "found" else "not_found_in_search",
    assembly_records=nrow(a), current_assembly_records=sum(a$assembly_status == "current"), assembly_pairs=length(unique(a$assembly_pair_key)),
    annotated_assemblies=sum(a$annotation_available), annotated_reference_assemblies=sum(a$annotation_available & a$reference_designated),
    genomic_runs=nrow(r), wgs_runs=sum(r$wgs_eligible), wgs_samples=nrow(w),
    wgs_studies=length(g_values(r$study_key[r$wgs_eligible])),
    low_coverage_labeled_samples=sum(w$explicit_low_coverage_label), nominal_low_depth_samples=sum(w$nominal_low_depth_candidate),
    wgs_samples_with_collection_year=sum(!is.na(w$year)), wgs_samples_with_coordinates=sum(is.finite(w$latitude)),
    wgs_samples_with_locality_text=sum(w$locality_raw != ""),
    worldwide_dated_georeferenced_wgs_samples=sum(!is.na(w$year) & is.finite(w$latitude)),
    mapped_dated_samples=sum(w$map_candidate), pooled_wgs_samples=sum(w$pooled_flag), captive_wgs_samples=sum(w$captive_flag),
    collection_years=g_join(w$year), countries_and_localities=g_join(w$locality_raw),
    annotated_accessions=g_join(a$assembly_accession[a$annotation_available]),
    stringsAsFactors=FALSE)
}))
# A study can contain multiple species; unique key is (species, study_accession).
project_meta <- read("studies")
study_keys <- unique(rbind(data.frame(species=runs$species, study_accession=runs$study_key), assemblies[c("species", "study_accession")]))
study_keys <- study_keys[study_keys$study_accession != "", ]
studies <- do.call(rbind, lapply(seq_len(nrow(study_keys)), function(i) {
  sp <- study_keys$species[i]; id <- study_keys$study_accession[i]
  r <- runs[runs$species == sp & runs$study_key == id, ]; a <- assemblies[assemblies$species == sp & assemblies$study_accession == id, ]
  s <- samples[samples$species == sp & samples$sample_accession %in% c(r$sample_accession, a$sample_accession), ]
  m <- project_meta[project_meta$study_accession == id, ]
  w <- s[s$sample_accession %in% r$sample_accession[r$wgs_eligible], ]
  data.frame(species=sp, study_accession=id, study_title=g_join(c(r$study_title, m$study_title)),
    study_description=g_join(m$study_description), publication_references=g_join(m$publication_references),
    genomic_runs=nrow(r), wgs_runs=sum(r$wgs_eligible), wgs_samples=nrow(w), assembly_records=nrow(a),
    assay_classes=g_join(r$assay_class), mapped_dated_samples=sum(w$map_candidate),
    missing_year_samples=sum(is.na(w$year)), missing_coordinates_samples=sum(!is.finite(w$latitude)),
    low_coverage_labeled_samples=sum(w$explicit_low_coverage_label), pooled_samples=sum(w$pooled_flag), captive_samples=sum(w$captive_flag),
    collection_years=g_join(w$year), localities=g_join(w$locality_raw), source_url=paste0("https://www.ebi.ac.uk/ena/browser/view/", id))
}))
studies <- studies[order(-studies$wgs_samples, studies$species, studies$study_accession), ]; rownames(studies) <- NULL
map <- samples[samples$map_candidate, c("species", "sample_accession", "studies", "year", "latitude", "longitude", "cell_lon", "cell_lat", "coordinate_approximate", "coordinate_status", "locality_raw", "life_stage", "wgs_runs", "nominal_depth", "explicit_low_coverage_label", "source_url")]
map$sample_count <- 1L; map$count_unit <- "BioSample_accession"; map$specimen_count <- NA_integer_
map$integration_status <- "candidate_requires_individual_and_population_review"
cell_columns <- c("species", "year", "life_stage", "cell_lon", "cell_lat")
cells <- if(nrow(map)) aggregate(list(cell_sample_count=map$sample_count), map[cell_columns], sum) else data.frame()
if(nrow(cells)) cells$count_unit <- "BioSample_accession"
review <- samples[samples$wgs_runs > 0, c("species", "sample_accession", "studies", "wgs_runs", "map_candidate", "review_reason", "collection_date_raw", "year", "locality_raw", "coordinates_raw", "material_status", "source_url")]
review <- review[order(review$map_candidate, review$species, review$studies, review$sample_accession), ]
stopifnot(!anyDuplicated(g_key(samples)), all(map$year > config$historical_end), all(is.finite(map$latitude)), sum(summary$wgs_runs) == sum(runs$wgs_eligible))
if(!identical(unname(before), unname(tools::md5sum(inputs)))) stop("Inputs changed during build")
dir.create(config$output, recursive=TRUE, showWarnings=FALSE)
write <- function(d, name) write.csv(d, file.path(config$output, paste0(name, ".csv")), row.names=FALSE, na="", fileEncoding="UTF-8")
write(summary, "species_summary"); write(taxa, "taxon_crosswalk"); write(runs, "runs"); write(assemblies, "assemblies")
write(samples, "samples"); write(studies, "studies"); write(map, "atlas_candidates"); write(cells, "atlas_candidate_cells")
write(review, "metadata_review_queue"); write(attributes, "sample_attributes"); write(read("sample_retrieval"), "sample_retrieval")
write(read("queries"), "queries"); write(data.frame(path=inputs, md5=unname(before)), "input_checksums")
dput(config, file=file.path(config$output, "resolved_config.R"))
writeLines(capture.output(sessionInfo()), file.path(config$output, "session_info.txt"))
if (exists("g_report")) g_report(summary, studies, assemblies, config)
if(system2(python, c("Scripts/genomics_archive_io.py", "--sqlite")) != 0) stop("SQLite export failed")
message(sprintf("Complete: %d species; %d WGS runs / %d BioSamples; %d assemblies (%d annotated); %d mapping candidates.", nrow(summary), sum(runs$wgs_eligible), sum(samples$wgs_runs > 0), nrow(assemblies), sum(assemblies$annotation_available), nrow(map)))
