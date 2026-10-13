# Base-R scientific transformations for public genomic metadata.
g_read <- function(path) read.csv(path, colClasses = "character", na.strings = NULL,
                                  check.names = FALSE, stringsAsFactors = FALSE)
g_num <- function(x) suppressWarnings(as.numeric(x))
g_missing <- function(x) is.na(x) | tolower(trimws(x)) %in% c("", "na", "n/a", "missing", "not provided", "not collected", "not applicable", "not available", "unknown", "none", "null", "unspecified", "restricted access")
g_values <- function(x) sort(unique(trimws(x[!g_missing(x)])))
g_join <- function(x) paste(g_values(x), collapse = " | ")
g_key <- function(x) paste(x$species, x$sample_accession, sep = "::")
g_norm <- function(x) gsub("[^a-z0-9]", "", tolower(x))
g_escape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE); x <- gsub(">", "&gt;", x, fixed = TRUE)
  gsub('"', "&quot;", x, fixed = TRUE)
}

g_date <- function(values, current_year = as.integer(format(Sys.Date(), "%Y"))) {
  values <- g_values(values)
  out <- list(collection_date_raw = g_join(values), year_start = NA_integer_, year_end = NA_integer_,
              year = NA_integer_, date_status = "missing")
  if (!length(values)) return(out)
  parsed <- lapply(values, function(v) {
    # Dates/ranges in collection fields only. Never parse titles, release or sequencing dates.
    years <- regmatches(v, gregexpr("(?<![0-9])(?:18|19|20)[0-9]{2}(?![0-9])", v, perl = TRUE))[[1]]
    if (!length(years)) return(integer())
    as.integer(years)
  })
  yrs <- unlist(parsed)
  if (!length(yrs) || any(lengths(parsed) == 0) || any(yrs > current_year)) {
    out$date_status <- "unparsed_or_invalid"; return(out)
  }
  out$year_start <- min(yrs); out$year_end <- max(yrs)
  uncertain <- any(grepl("before|after|circa|approx|\\?|[<>]", values, ignore.case = TRUE))
  if (uncertain) out$date_status <- "uncertain"
  else if (length(unique(yrs)) == 1) { out$year <- yrs[1]; out$date_status <- "single_year" }
  else if (length(values) > 1 && length(unique(vapply(parsed, function(z) paste(range(z), collapse = ":"), ""))) > 1)
    out$date_status <- "conflicting_or_multiple_dates"
  else out$date_status <- "multi_year_interval"
  out
}

g_pair <- function(value) {
  # Accepted explicit lat/lon formats; do not geocode country/city names.
  v <- toupper(trimws(value)); v <- gsub("[(),]", " ", v)
  patterns <- c(
    "^\\s*([+-]?[0-9]+(?:\\.[0-9]+)?)\\s*([NS])\\s+([+-]?[0-9]+(?:\\.[0-9]+)?)\\s*([EW])\\s*$",
    "^\\s*([NS])\\s*([0-9]+(?:\\.[0-9]+)?)\\s+([EW])\\s*([0-9]+(?:\\.[0-9]+)?)\\s*$",
    "^\\s*([+-]?[0-9]+(?:\\.[0-9]+)?)\\s+([+-]?[0-9]+(?:\\.[0-9]+)?)\\s*$")
  for (i in seq_along(patterns)) {
    m <- regmatches(v, regexec(patterns[i], v, perl = TRUE))[[1]]
    if (!length(m)) next
    if (i == 1) {
      lat <- abs(as.numeric(m[2])) * ifelse(m[3] == "S", -1, 1)
      lon <- abs(as.numeric(m[4])) * ifelse(m[5] == "W", -1, 1)
      if ((as.numeric(m[2]) < 0 && m[3] == "N") || (as.numeric(m[4]) < 0 && m[5] == "E")) return(c(NA_real_,NA_real_))
    } else if (i == 2) {
      lat <- as.numeric(m[3]) * ifelse(m[2] == "S", -1, 1)
      lon <- as.numeric(m[5]) * ifelse(m[4] == "W", -1, 1)
    } else { lat <- as.numeric(m[2]); lon <- as.numeric(m[3]) }
    if (abs(lat) <= 90 && abs(lon) <= 180 && !(lat == 0 && lon == 0)) return(c(lat, lon))
  }
  c(NA_real_, NA_real_)
}

g_coords <- function(pairs, latitudes = character(), longitudes = character(), locality = character()) {
  pairs <- g_values(pairs); la <- g_values(latitudes); lo <- g_values(longitudes)
  collapse_numeric <- function(z) if(length(z) && all(is.finite(g_num(z))) && diff(range(g_num(z))) < 1e-5) as.character(g_num(z[1])) else z
  la <- collapse_numeric(la); lo <- collapse_numeric(lo)
  raw <- pairs
  if (length(la) == 1 && length(lo) == 1) raw <- c(raw, paste(la, lo))
  out <- list(coordinates_raw = g_join(raw), latitude = NA_real_, longitude = NA_real_, coordinate_status = "missing")
  parsed <- lapply(raw, g_pair)
  good <- Filter(function(z) all(is.finite(z)), parsed)
  if (!length(good)) {
    # Explicit hemisphere-marked coordinates embedded in collection-locality text are evidence.
    pattern <- "[NS]\\s*[0-9]+(?:\\.[0-9]+)?\\s*[,; ]+\\s*[EW]\\s*[0-9]+(?:\\.[0-9]+)?|[0-9]+(?:\\.[0-9]+)?\\s*[NS]\\s*[,; ]+\\s*[0-9]+(?:\\.[0-9]+)?\\s*[EW]"
    embedded <- unlist(regmatches(toupper(locality), gregexpr(pattern, toupper(locality), perl = TRUE)))
    good <- Filter(function(z) all(is.finite(z)), lapply(embedded, g_pair))
    if (length(good)) { out$coordinates_raw <- g_join(embedded); out$coordinate_status <- "explicit_coordinates_in_locality" }
  } else out$coordinate_status <- "reported_coordinates"
  if (!length(good)) { if(length(raw)) out$coordinate_status <- "unparsed_or_invalid"; return(out) }
  m <- do.call(rbind, good)
  if (length(la) > 1 || length(lo) > 1 || diff(range(m[,1])) > 0.02 || diff(range(m[,2])) > 0.02) {
    out$coordinate_status <- "conflicting_coordinates"; return(out)
  }
  out$latitude <- m[1,1]; out$longitude <- m[1,2]
  out
}

g_classify_runs <- function(r) {
  text <- tolower(paste(r$experiment_title, r$library_name, r$library_construction_protocol))
  strategy <- toupper(r$library_strategy)
  r$assay_class <- ifelse(strategy == "WGS", "WGS", "other_genomic_assay")
  r$assay_class[strategy %in% c("RAD-SEQ", "GBS") | tolower(r$library_selection) %in% c("reduced representation", "restriction digest") | grepl("\\b(ddrad|radseq|rad-seq|rad seq|ezrad|2brad|3rad|gbs)\\b|restriction.site.associated|genotyping.by.sequencing|double.digest.rad|rad.capture", text, perl = TRUE)] <- "reduced_representation"
  r$assay_class[strategy %in% c("HI-C", "CHIA-PET") | grepl("\\bhi[ -]?c\\b|chromatin.conformation", text, perl = TRUE)] <- "HiC_or_proximity"
  r$assay_class[strategy %in% c("AMPLICON", "TARGETED-CAPTURE", "WXS") | grepl("ultraconserved|ultra.conserved|exome.capture|target.capture|hybrid.capture|\\buce[s]?\\b", text, perl = TRUE)] <- "targeted_or_amplicon"
  r$assay_class[strategy %in% c("BISULFITE-SEQ", "METHYL-SEQ")] <- "bisulfite_or_methylation"
  r$assay_class[strategy == "WGA"] <- "whole_genome_amplification_review"
  r$assay_class[grepl("mitochondri(al|on)|mitogenome", tolower(r$experiment_title)) & strategy == "WGS"] <- "organelle_target_review"
  r$assay_class[strategy == "OTHER" & r$assay_class == "other_genomic_assay"] <- "other_genomic_review"
  r$wgs_eligible <- r$assay_class == "WGS"
  r$short_read_wgs <- r$wgs_eligible & r$instrument_platform %in% c("ILLUMINA", "BGISEQ", "DNBSEQ", "ION_TORRENT", "LS454", "ABI_SOLID")
  r$explicit_low_coverage_label <- r$wgs_eligible & grepl("low[ -]?(coverage|depth|pass)|\\blc[ -]?wgs\\b|genome skim", text, perl = TRUE)
  r$base_count <- g_num(r$base_count); r$read_count <- g_num(r$read_count)
  # Same file checksums repeated under multiple accessions cannot contribute yield twice.
  file_key <- vapply(strsplit(r$fastq_md5, ";", fixed = TRUE), function(z) paste(sort(z), collapse = ";"), "")
  r$duplicate_file_set <- file_key != "" & duplicated(paste(r$species, file_key))
  r$source_url <- paste0("https://www.ebi.ac.uk/ena/browser/view/", r$run_accession)
  r$study_key <- ifelse(r$study_accession != "", r$study_accession, r$secondary_study_accession)
  r$read_files_listed <- r$fastq_ftp != "" | r$sra_ftp != ""
  r
}

g_assemblies <- function(a) {
  for (col in c("total_sequence_length", "gene_count", "protein_coding_gene_count", "contig_n50", "scaffold_n50")) a[[col]] <- g_num(a[[col]])
  a$annotation_recorded <- !g_missing(a$annotation_name) | (!is.na(a$gene_count) & a$gene_count > 0)
  a$annotation_available <- a$annotation_recorded & a$assembly_status == "current"
  a$reference_designated <- tolower(a$refseq_category) %in% c("reference genome", "representative genome")
  a$annotation_evidence <- ifelse(a$annotation_recorded, "NCBI_annotation_info_present", "not_reported_in_NCBI_Datasets")
  a$assembly_pair_key <- ifelse(a$paired_accession == "", a$assembly_accession,
                                pmin(a$assembly_accession, a$paired_accession))
  a
}

g_build_samples <- function(r, a, attr, config) {
  keys <- unique(rbind(r[c("species", "sample_accession")], a[c("species", "sample_accession")]))
  keys <- keys[keys$sample_accession != "", ]; keys <- keys[order(keys$species, keys$sample_accession), ]
  ri <- split(seq_len(nrow(r)), g_key(r)); ai <- split(seq_len(nrow(a)), g_key(a)); ti <- split(seq_len(nrow(attr)), g_key(attr))
  attr$normalized_attribute <- g_norm(attr$attribute)
  reference <- lapply(split(a, a$species), function(z) {
    z <- z[is.finite(z$total_sequence_length) & z$total_sequence_length > 1e7 & z$assembly_status == "current", ]
    if (!nrow(z)) return(NULL)
    z <- z[order(!z$reference_designated, !z$annotation_available, z$assembly_level != "Chromosome", -z$scaffold_n50, z$assembly_accession, na.last = TRUE), ]
    z[1, ]
  })
  result <- lapply(seq_len(nrow(keys)), function(i) {
    if (i %% 2000L == 0L) message("Processed ", i, "/", nrow(keys), " sample accessions")
    sp <- keys$species[i]; sid <- keys$sample_accession[i]; k <- g_key(keys[i, ])
    rr <- r[ri[[k]], , drop = FALSE]; aa <- a[ai[[k]], , drop = FALSE]; tt <- attr[ti[[k]], , drop = FALSE]
    values <- function(tags) g_values(tt$value[tt$normalized_attribute %in% tags])
    dates <- c(values(c("collectiondate", "collectionyear", "datecollected", "samplingdate", "samplingyear", "samplecollectiondate", "yearcollected")), rr$collection_date)
    localities <- c(values(c("geolocname", "country", "geographiclocation", "geographiclocationcountryandorsea", "locality", "collectionsite", "samplinglocation", "localityname", "verbatimlocality", "geographiclocationregionandlocality", "location")), rr$country)
    geo <- g_coords(c(values(c("latlon", "latitudelongitude", "geographiclocationlatitudelongitude")), rr$location),
                    c(values(c("latitude", "decimallatitude", "samplelat", "geographiclocationlatitude")), rr$lat),
                    c(values(c("longitude", "decimallongitude", "samplelong", "geographiclocationlongitude")), rr$lon), localities)
    dates <- g_date(dates)
    stage <- g_join(c(values(c("devstage", "developmentalstage", "lifestage", "age")), rr$dev_stage))
    stage_l <- tolower(stage)
    life_stage <- if (grepl("larv", stage_l) && grepl("\\badult\\b", stage_l, perl=TRUE)) "mixed" else if (grepl("larv", stage_l)) "larva" else if (grepl("\\badult\\b|\\bmature\\b", stage_l, perl = TRUE)) "adult" else if (grepl("juven", stage_l)) "juvenile" else if (grepl("embryo|egg", stage_l)) "embryo_or_egg" else "unknown"
    # Biology fields only: a pooled sequencing library is not evidence of pooled animals.
    biology <- tolower(g_join(c(values(c("breed", "strain", "breedingmethod", "breedinghistory", "sampledescription", "sampletitle", "isolation_source", "isolationsource", "sampletype", "population", "ecotype", "growthcondition", "cellline", "tissue", "tissuetype", "specimentype", "pooledsample", "poolsize", "individualcount")), rr$sample_title, rr$sample_description)))
    pooled <- grepl("pool[ -]?seq|pooled (sample|individual|fish|specimen|animal|dna|sequencing)|pool of |dna pool|\\bpool[0-9]+\\b", biology, perl = TRUE) || any(g_num(values(c("poolsize", "individualcount"))) > 1, na.rm = TRUE)
    captive <- grepl("lab[ -]?(bred|reared)|laboratory[ -]?(bred|reared)|f[1-9][0-9]* (lab|wild parents)|captive|aquarium|aquaculture|hatchery|domesticated|full[ -]?sib|half[ -]?sib|experimental cross", biology, perl = TRUE)
    cell_line <- length(values("cellline")) > 0 || grepl("cell line|cell culture", biology)
    hybrid <- grepl("\\bhybrid\\b|interspecific cross", biology, perl = TRUE)
    material <- if (pooled) "pool_flagged" else if (cell_line) "cell_line_flagged" else if (captive) "captive_or_cross_flagged" else if (hybrid) "hybrid_flagged" else "individual_origin_unverified"
    w <- rr[rr$wgs_eligible & !rr$duplicate_file_set, , drop = FALSE]
    sr <- w[w$short_read_wgs, , drop = FALSE]
    ref <- reference[[sp]]
    length_bp <- if (!is.null(ref)) ref$total_sequence_length else NA_real_
    nominal <- if (nrow(sr) && all(is.finite(sr$base_count)) && is.finite(length_bp)) sum(sr$base_count) / length_bp else NA_real_
    sum_bases <- function(z) if (!nrow(z) || any(!is.finite(z$base_count))) NA_real_ else sum(z$base_count)
    row <- c(list(species = sp, sample_accession = sid, sample_title = g_join(c(rr$sample_title, aa$sample_title, values("sampletitle"))),
      studies = g_join(c(rr$study_key, aa$study_accession)), genomic_runs = nrow(rr), wgs_runs = sum(rr$wgs_eligible),
      assembly_records = nrow(aa), assembly_accessions = g_join(aa$assembly_accession),
      run_accessions = g_join(rr$run_accession[rr$wgs_eligible]), locality_raw = g_join(localities)), dates, geo,
      list(life_stage = life_stage, life_stage_raw = stage, population_label_raw = g_join(values(c("population", "subpopulation", "ecotype"))), material_status = material,
      pooled_flag = pooled, captive_flag = captive, cell_line_flag = cell_line, hybrid_flag = hybrid,
      specimen_voucher = g_join(c(rr$specimen_voucher, values(c("specimenvoucher", "biomaterial")))),
      isolate = g_join(c(rr$isolate, values(c("isolate", "tolid", "yggdrasilindividualid")))),
      wgs_bases = sum_bases(w), short_read_wgs_bases = sum_bases(sr), nominal_depth = nominal,
      depth_reference_accession = if (!is.null(ref)) ref$assembly_accession else "",
      explicit_low_coverage_label = any(rr$explicit_low_coverage_label),
      nominal_low_depth_candidate = is.finite(nominal) && nominal <= config$nominal_low_depth_max,
      source_url = paste0("https://www.ebi.ac.uk/ena/browser/view/", sid)))
    as.data.frame(row, stringsAsFactors = FALSE)
  })
  s <- do.call(rbind, result); rownames(s) <- NULL
  s$within_atlas_bounds <- is.finite(s$latitude) & is.finite(s$longitude) & s$latitude >= config$bounds['south'] & s$latitude <= config$bounds['north'] & s$longitude >= config$bounds['west'] & s$longitude <= config$bounds['east']
  s$post_1930 <- !is.na(s$year) & s$year > config$historical_end
  s$coordinate_approximate <- FALSE
  s$cell_lon <- floor(s$longitude / config$cell_degrees) * config$cell_degrees
  s$cell_lat <- floor(s$latitude / config$cell_degrees) * config$cell_degrees
  # Repeated voucher/isolate within a project is a duplicate-individual lead, not an automatic merge.
  identity <- ifelse(s$specimen_voucher != "", s$specimen_voucher, s$isolate)
  identity_key <- paste(s$species, s$studies, identity, sep = "::")
  s$possible_duplicate_individual <- identity != "" & (duplicated(identity_key) | duplicated(identity_key, fromLast = TRUE))
  # Explicit run-suffixed isolates can identify repeat deposits across split projects.
  s$replicate_identity_hint <- ifelse(grepl("_Run[0-9]+$", s$isolate, ignore.case=TRUE),
    paste(s$species, sub("_Run[0-9]+$", "", s$isolate, ignore.case=TRUE), sep="::"), "")
  hint <- s$replicate_identity_hint
  s$possible_duplicate_individual <- s$possible_duplicate_individual | (hint != "" & (duplicated(hint) | duplicated(hint, fromLast=TRUE)))
  s$map_candidate <- s$wgs_runs > 0 & s$post_1930 & s$within_atlas_bounds &
    !s$pooled_flag & !s$captive_flag & !s$cell_line_flag & !s$hybrid_flag & !s$possible_duplicate_individual
  s$review_reason <- vapply(seq_len(nrow(s)), function(i) g_join(c(
    if(s$wgs_runs[i] == 0) "no_confirmed_WGS", if(is.na(s$year[i])) "collection_year_unresolved",
    if(!is.finite(s$latitude[i])) "coordinates_unresolved", if(is.finite(s$latitude[i]) && !s$within_atlas_bounds[i]) "outside_atlas_bounds",
    if(!is.na(s$year[i]) && !s$post_1930[i]) "historical_collection", if(s$pooled_flag[i]) "pooled_samples",
    if(s$captive_flag[i]) "captive_or_cross", if(s$cell_line_flag[i]) "cell_line", if(s$hybrid_flag[i]) "hybrid",
    if(s$possible_duplicate_individual[i]) "possible_duplicate_individual",
    "individual_count_and_population_identity_unverified")), "")
  s
}

g_report <- function(summary, studies, assemblies, config) {
  n <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
  head <- sprintf('<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Public genomic data inventory</title>
<style>body{font:16px/1.5 system-ui,sans-serif;color:#193348;background:#f6f8fa;max-width:1300px;margin:2rem auto;padding:0 1rem}h1,h2{line-height:1.2}a{color:#076781}input,select{font:inherit;padding:.4rem;border:1px solid #9bafb9;border-radius:4px}label{display:inline-block;margin:.5rem 1rem .5rem 0}table{border-collapse:collapse;width:100%%;background:white;margin:1rem 0}th,td{text-align:left;padding:.6rem;border-bottom:1px solid #d9e2e7;vertical-align:top}th{background:#e1edf2;position:sticky;top:0}.scroll{overflow:auto}details{margin:.6rem 0;padding:.7rem;background:white;border:1px solid #d9e2e7;border-radius:6px}summary{cursor:pointer;font-weight:600}.muted{color:#506674}.stats{background:#dfedf1;padding:1rem;border-radius:6px}small{font-size:.85rem}[hidden]{display:none!important}</style>
<h1>Public genomic data inventory</h1><p>All 80 historical-atlas species. Worldwide discovery in ENA and NCBI; mapping candidates use the atlas window (100–50°W, 5–60°N) and collection years after 1930.</p>
<p class="stats"><strong>%s species with WGS · %s with annotated assemblies · %s WGS runs · %s WGS sample accessions · %s mapping candidates</strong></p>
<p>Counts are archive sample accessions, not confirmed independent fish. Mapping candidates have archive or publication-reported coordinates and a single collection year; individual identity, population and habitat still require review. Missing metadata and zero search results do not establish absence. Low-depth estimates are unaligned sequencing yield per assembly length, not measured coverage.</p>
<p><a href="genomics.sqlite">SQLite database</a> · <a href="species_summary.csv">Species CSV</a> · <a href="studies.csv">Study CSV</a> · <a href="samples.csv">Samples CSV</a> · <a href="assemblies.csv">Assemblies CSV</a> · <a href="atlas_candidates.csv">Mapping candidates</a> · <a href="metadata_review_queue.csv">Metadata review queue</a> · <a href="location_provenance.csv">Location provenance</a> · <a href="location_coverage.csv">Location coverage</a> · <a href="publication_location_review.csv">Publication review</a> · <a href="geome_records.csv">GEOME records</a> · <a href="../../docs/genomics_inventory.md">Methods and dictionary</a></p>
<form id="filters"><label>Species <input id="search" type="search" placeholder="Scientific name"></label><label>Minimum WGS samples <input id="minimum" type="number" min="0" value="0" style="width:6rem"></label><label>Assembly <select id="annotation"><option value="all">All species</option><option value="annotated">Annotated assembly found</option><option value="reference">Annotated reference found</option><option value="missing">Annotation not reported</option></select></label><label><input type="checkbox" id="mapped"> Has mapping candidates</label><label><input type="checkbox" id="low"> Has labeled low-coverage WGS</label><button type="reset">Reset</button></form><p id="status" role="status"></p>
<div class="scroll"><table><thead><tr><th>Species</th><th>Assembly records</th><th>Annotated</th><th>Annotated reference</th><th>WGS runs</th><th>WGS samples</th><th>Labeled low coverage</th><th>Mapping candidates</th></tr></thead><tbody>',
    n(sum(summary$wgs_samples > 0)), n(sum(summary$annotated_assemblies > 0)), n(sum(summary$wgs_runs)), n(sum(summary$wgs_samples)), n(sum(summary$mapped_dated_samples)))
  rows <- vapply(seq_len(nrow(summary)), function(i) {
    z <- summary[i, ]; id <- gsub(" ", "_", z$species)
    numbers <- unlist(z[c("assembly_records", "annotated_assemblies", "annotated_reference_assemblies", "wgs_runs", "wgs_samples", "low_coverage_labeled_samples", "mapped_dated_samples")])
    if (z$query_status != "complete") numbers[] <- NA
    cells <- paste0("<td>", ifelse(is.na(numbers), "Unknown", n(numbers)), "</td>", collapse = "")
    sprintf('<tr class="species-row" data-name="%s" data-samples="%s" data-annotated="%s" data-reference="%s" data-mapped="%s" data-low="%s" data-known="%s"><td><a href="#%s"><i>%s</i></a></td>%s</tr>',
      g_escape(tolower(z$species)), z$wgs_samples, z$annotated_assemblies, z$annotated_reference_assemblies, z$mapped_dated_samples, z$low_coverage_labeled_samples, z$query_status == "complete", id, g_escape(z$species), cells)
  }, "")
  cards <- vapply(seq_len(nrow(summary)), function(i) {
    z <- summary[i, ]; sp <- z$species; a <- assemblies[assemblies$species == sp, ]; p <- studies[studies$species == sp, ]
    assembly_rows <- if(nrow(a)) paste(vapply(seq_len(nrow(a)), function(j) sprintf('<tr><td><a href="%s">%s</a></td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>', g_escape(a$source_url[j]), a$assembly_accession[j], paste(a$assembly_level[j], a$assembly_status[j]), ifelse(a$annotation_recorded[j], g_escape(a$annotation_name[j]), 'Not reported'), g_escape(a$refseq_category[j]), g_escape(a$sample_accession[j])), ""), collapse="") else '<tr><td colspan="5">No assembly returned, or taxonomy unresolved.</td></tr>'
    study_rows <- if(nrow(p)) paste(vapply(seq_len(nrow(p)), function(j) sprintf('<tr><td><a href="%s">%s</a><br><small>%s</small></td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>', g_escape(p$source_url[j]), p$study_accession[j], g_escape(p$study_title[j]), n(p$wgs_samples[j]), n(p$mapped_dated_samples[j]), g_escape(p$collection_years[j]), g_escape(p$localities[j])), ""), collapse="") else '<tr><td colspan="5">No genomic study returned, or taxonomy unresolved.</td></tr>'
    sprintf('<details id="%s" class="species-card" data-name="%s"><summary><i>%s</i> — %s WGS samples; %s map candidates</summary><p>Taxonomy: %s. Archive name: %s. %s of %s WGS samples have a collection year; %s have coordinates worldwide. Source attributes and flags are preserved in the database.</p><div class="scroll"><table><thead><tr><th>Assembly</th><th>Level</th><th>Annotation</th><th>Reference designation</th><th>BioSample</th></tr></thead><tbody>%s</tbody></table><table><thead><tr><th>Study</th><th>WGS samples</th><th>Map candidates</th><th>Collection years</th><th>Reported localities</th></tr></thead><tbody>%s</tbody></table></div></details>',
      gsub(" ", "_", sp), g_escape(tolower(sp)), g_escape(sp), n(z$wgs_samples), n(z$mapped_dated_samples), g_escape(z$taxonomy_status), g_escape(z$archive_name), n(z$wgs_samples_with_collection_year), n(z$wgs_samples), n(z$wgs_samples_with_coordinates), assembly_rows, study_rows)
  }, "")
  tail <- '<script>
const rows=[...document.querySelectorAll(".species-row")], cards=[...document.querySelectorAll(".species-card")];
function filter(){let count=0;const q=document.querySelector("#search").value.trim().toLowerCase(), min=Number(document.querySelector("#minimum").value)||0, ann=document.querySelector("#annotation").value;
rows.forEach((row,i)=>{const d=row.dataset;const visible=d.name.includes(q)&&Number(d.samples)>=min&&(!document.querySelector("#mapped").checked||Number(d.mapped)>0)&&(!document.querySelector("#low").checked||Number(d.low)>0)&&(ann==="all"||ann==="annotated"&&Number(d.annotated)>0||ann==="reference"&&Number(d.reference)>0||ann==="missing"&&d.known==="TRUE"&&Number(d.annotated)===0);row.hidden=!visible;cards[i].hidden=!visible;if(visible)count++;});document.querySelector("#status").textContent=`${count} of ${rows.length} species shown`;}
document.querySelector("#filters").addEventListener("input",filter);document.querySelector("#filters").addEventListener("reset",()=>setTimeout(filter,0));
function reveal(){const id=decodeURIComponent(location.hash.slice(1)),card=document.getElementById(id);if(card?.tagName==="DETAILS"){card.open=true;card.scrollIntoView();}}window.addEventListener("hashchange",reveal);filter();reveal();
</script></html>'
  writeLines(c(head, rows, '</tbody></table></div><h2>Assemblies and studies by species</h2>', cards, tail), file.path(config$output, "index.html"), useBytes=TRUE)
}
