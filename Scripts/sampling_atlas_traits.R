# Report-only attachment of curated life-history outputs to unchanged atlas keys.
atlas_trait_categories <- c(positive_water_types = "Water types (positive records)",
  positive_habitat_tags = "Habitat tags (positive records)", water_column_habitat = "Water-column habitat",
  migration = "Migration", fisheries_importance = "Fisheries importance",
  sexual_system = "Sexual system", fertilization = "Fertilization", reproductive_guild_1 = "Reproductive guild")
atlas_trait_numbers <- c(generation_time_model_years = "Generation time — model (years)",
  lifespan_model_years = "Lifespan — model (years)", maturity_age_model_years = "Maturity age — model (years)")

atlas_trait_source <- function(config) {
  if (is.null(config$life_history)) "Output/LifeHistory/life_history_80_species.csv" else config$life_history
}

atlas_trait_inputs <- function(config) {
  path <- atlas_trait_source(config)
  if (!file.exists(path)) return(character())
  paths <- c(path, file.path(dirname(path), c("trait_evidence.csv", "references.csv", "trait_dictionary.csv", "build_manifest.json")))
  paths[file.exists(paths)]
}

trait_tokens <- function(value) {
  if (is.na(value) || !nzchar(trimws(value))) return(character())
  sort(unique(trimws(strsplit(value, ";", fixed = TRUE)[[1]])))
}

trait_label <- function(value) {
  labels <- c(Brack = "Brackish", Fresh = "Freshwater", Saltwater = "Saltwater",
    SeaGrassBeds = "Seagrass beds", CoralReefs = "Coral reefs", TL = "TL (total length)",
    SL = "SL (standard length)", FL = "FL (fork length)", NG = "NG (source code)",
    Unspecified = "Unspecified type")
  if (value %in% names(labels)) unname(labels[value]) else value
}

atlas_length_values <- function(row) {
  values <- list()
  for (sex in c("male_unsexed", "female")) {
    n <- row[[paste0("maximum_length_", sex, "_cm")]]
    if (is.na(n)) next
    type <- row[[paste0("maximum_length_", sex, "_type")]]
    if (!nzchar(type)) type <- "Unspecified"
    values[[type]] <- max(c(values[[type]], n))
  }
  if (!length(values)) return(data.frame(type = character(), cm = numeric()))
  data.frame(type = sort(names(values)), cm = unlist(values[sort(names(values))], use.names = FALSE))
}

read_atlas_traits <- function(species, config) {
  path <- atlas_trait_source(config)
  metadata <- c("fishbase_name", "fishbase_version", "taxon_match_status", "primary_source_review", "regional_applicability")
  length_fields <- c("maximum_length_male_unsexed_cm", "maximum_length_female_cm")
  type_fields <- c("maximum_length_male_unsexed_type", "maximum_length_female_type")
  fields <- c("species", metadata, names(atlas_trait_numbers), names(atlas_trait_categories), length_fields, type_fields)
  available <- file.exists(path)
  source <- if (available) read.csv(path, colClasses = "character", na.strings = "", stringsAsFactors = FALSE)
    else as.data.frame(setNames(rep(list(character()), length(fields)), fields), stringsAsFactors = FALSE)
  if (!available) message("No life-history output found; build it and refresh the atlas to attach traits.")
  if (!all(fields %in% names(source))) stop("Life-history output lacks required fields.")
  if (anyNA(source$species) || anyDuplicated(source$species)) stop("Life-history species keys must be unique and nonblank.")
  out <- source[match(species, source$species), fields, drop = FALSE]
  out$species <- species; rownames(out) <- NULL
  for (field in c(names(atlas_trait_numbers), length_fields)) {
    values <- suppressWarnings(as.numeric(out[[field]]))
    if (any(!is.na(out[[field]]) & (!is.finite(values) | values <= 0))) stop("Invalid life-history value: ", field)
    out[[field]] <- values
  }
  for (field in c(metadata, names(atlas_trait_categories), type_fields)) out[[field]][is.na(out[[field]])] <- ""
  out$taxon_match_status[!species %in% source$species] <- "not_in_trait_output"
  withheld <- grepl("withheld", out$taxon_match_status, fixed = TRUE)
  if (any(withheld)) {
    if (any(!is.na(as.matrix(out[withheld, c(names(atlas_trait_numbers), length_fields), drop = FALSE]))) ||
        any(nzchar(as.matrix(out[withheld, names(atlas_trait_categories), drop = FALSE]))))
      stop("Withheld taxonomic matches must not contain attached traits.")
  }
  lengths <- do.call(rbind, lapply(seq_len(nrow(out)), function(i) {
    z <- atlas_length_values(out[i, ])
    data.frame(species = rep(out$species[i], nrow(z)), z)
  }))
  list(traits = out, lengths = lengths, available = available)
}

write_atlas_trait_tables <- function(bundle, config) {
  out <- file.path(config$output, "tables")
  write.csv(bundle$traits, file.path(out, "life_history_traits.csv"), row.names = FALSE, na = "")
  write.csv(bundle$lengths, file.path(out, "life_history_lengths.csv"), row.names = FALSE, na = "")
  copied <- c(trait_evidence.csv = "life_history_evidence.csv", references.csv = "life_history_references.csv",
    trait_dictionary.csv = "life_history_dictionary.csv")
  for (name in if (bundle$available) names(copied) else character()) {
    from <- file.path(dirname(atlas_trait_source(config)), name)
    if (!file.exists(from) || !file.copy(from, file.path(out, copied[[name]]), overwrite = TRUE))
      stop("Could not copy life-history evidence: ", from)
  }
  inputs <- c(atlas_trait_inputs(config), "Scripts/sampling_atlas_traits.R")
  write.csv(data.frame(path = inputs, md5 = unname(tools::md5sum(inputs))),
    file.path(out, "life_history_input_checksums.csv"), row.names = FALSE)
}

atlas_trait_filter_html <- function(bundle) {
  lines <- c('<details id="trait-filters"><summary><strong>Life-history filters</strong> <span id="trait-filter-count"></span></summary>',
    '<p>Combine traits with the sampling filters above. Different fields must all match. Water types and habitat tags test membership in positive records; an unlisted tag is not evidence of absence. Missing or withheld values remain visible until an active trait filter excludes them.</p>',
    '<div class="filter-grid">')
  for (field in names(atlas_trait_categories)) {
    values <- sort(unique(unlist(lapply(bundle$traits[[field]], trait_tokens))))
    lines <- c(lines, sprintf('<label>%s<select class="trait-category" id="trait-%s" data-trait="%s"><option value="">Any</option><option value="__missing__">Not reported / withheld</option>', atlas_trait_categories[[field]], field, field))
    for (value in values) lines <- c(lines, sprintf('<option value="%s">%s</option>', html_escape(value), html_escape(trait_label(value))))
    lines <- c(lines, '</select></label>')
  }
  lines <- c(lines, '</div><div class="trait-ranges">')
  numbers <- c(atlas_trait_numbers, maximum_length = "Maximum reported length (cm)")
  for (field in names(numbers)) {
    lines <- c(lines, sprintf('<fieldset class="trait-range" data-trait="%s"><legend>%s</legend><label>Data availability<select class="trait-availability" aria-label="%s availability"><option value="">Any</option><option value="available">Available</option><option value="missing">Not reported / withheld</option></select></label><div class="range-pair"><label>Minimum<input class="trait-min" type="number" min="0" step="any" placeholder="Any" aria-label="%s minimum"></label><label>Maximum<input class="trait-max" type="number" min="0" step="any" placeholder="Any" aria-label="%s maximum"></label></div>', field, numbers[[field]], numbers[[field]], numbers[[field]], numbers[[field]]))
    if (field == "maximum_length") {
      lines <- c(lines, '<label>Length type<select id="length-type"><option value="">Any type (no conversion)</option>')
      for (type in sort(unique(bundle$lengths$type))) lines <- c(lines, sprintf('<option value="%s">%s</option>', html_escape(type), html_escape(trait_label(type))))
      lines <- c(lines, '</select></label>')
    }
    lines <- c(lines, '</fieldset>')
  }
  c(lines, '</div><p id="trait-range-error" role="alert" hidden>A minimum exceeds its maximum. Correct the range to show matching species.</p><p>Generation time, lifespan and maturity age are model estimates, not observations. Lengths take the largest reported value across sexes separately for each type; a species matches a length range if at least one selected-type maximum is within it. TL, SL and FL are not converted.</p></details>')
}

atlas_trait_card_html <- function(row) {
  fmt <- function(n) format(signif(n, 3), scientific = FALSE, trim = TRUE)
  missing <- if (grepl("withheld", row$taxon_match_status, fixed = TRUE)) "Withheld — taxonomy unresolved" else "Not reported"
  lines <- c('<section class="life-history"><h3>Life history</h3><dl class="trait-grid">')
  for (field in names(atlas_trait_numbers)) {
    n <- row[[field]]
    lines <- c(lines, sprintf('<div class="trait-value" data-trait="%s" data-value="%s"><dt>%s</dt><dd>%s</dd></div>',
      field, if (is.na(n)) "" else sprintf("%.17g", n), atlas_trait_numbers[[field]], if (is.na(n)) missing else fmt(n)))
  }
  lengths <- atlas_length_values(row)
  label <- if (!nrow(lengths)) missing else paste(paste(vapply(lengths$cm, fmt, character(1)), "cm", lengths$type), collapse = "; ")
  lines <- c(lines, sprintf('<div><dt>Maximum reported length</dt><dd>%s</dd>', html_escape(label)))
  for (i in seq_len(nrow(lengths))) lines <- c(lines, sprintf('<span class="trait-length" hidden data-type="%s" data-value="%.17g"></span>', html_escape(lengths$type[i]), lengths$cm[i]))
  lines <- c(lines, '</div>')
  for (field in names(atlas_trait_categories)) {
    values <- trait_tokens(row[[field]])
    lines <- c(lines, sprintf('<div class="trait-value" data-trait="%s" data-values="%s"><dt>%s</dt><dd>%s</dd></div>', field,
      html_escape(paste(values, collapse = ";")), atlas_trait_categories[[field]],
      if (length(values)) html_escape(paste(vapply(values, trait_label, character(1)), collapse = "; ")) else missing))
  }
  lines <- c(lines, '</dl>')
  if (row$taxon_match_status != "exact_accepted_name") {
    note <- if (grepl("withheld", row$taxon_match_status, fixed = TRUE)) "Traits withheld because the proposed synonym match is ambiguous."
      else if (row$taxon_match_status == "not_in_trait_output") "This species is absent from the current trait output."
      else paste0("Traits attached from ", row$fishbase_name, " (", gsub("_", " ", row$taxon_match_status), "); project species name retained. Regional applicability is unreviewed.")
    lines <- c(lines, sprintf('<p class="trait-source-note">%s</p>', html_escape(note)))
  }
  c(lines, '</section>')
}
