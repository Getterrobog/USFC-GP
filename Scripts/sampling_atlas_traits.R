# Report-only attachment of curated life-history outputs to unchanged atlas keys.
atlas_trait_categories <- c(positive_water_types = "Water types (positive records)",
  positive_habitat_tags = "Habitat tags (positive records)", water_column_habitat = "Water-column habitat",
  migration_best_available = "Migration — best available", fisheries_importance = "Fisheries importance",
  sexual_system = "Sexual system", fertilization = "Fertilization", reproductive_guild_1 = "Reproductive guild",
  parental_care="Parental care", spawning_pattern="Spawning pattern", larval_development_place="Larval development",
  fishbase_feeding_group="Broad feeding class — FishBase",reef_diet_guild="Diet guild — reef dataset",
  body_shape="Body shape",schooling_reported="Schooling — reported",mating_system="Mating system",
  batch_spawning_reported="Batch spawning — reported",spawning_aggregation_reported="Spawning aggregation — reported",
  iucn_category_reported="IUCN category — source snapshot")
atlas_trait_numbers <- c(generation_time_model_years = "Generation time — model (years)",
  lifespan_model_years = "Lifespan — model (years)", maturity_age_model_years = "Maturity age — model (years)",
  maximum_age_wild_years="Maximum age — reported in wild (years)",
  maturity_age_reported_years_min="Reported maturity age — minimum (years)",
  maturity_age_reported_years_max="Reported maturity age — maximum (years)",
  trophic_level_preferred="Trophic level — preferred estimate",depth_shallow_m="Shallowest reported depth (m)",
  depth_deep_m="Deepest reported depth (m)")

atlas_trait_source <- function(config) {
  if (is.null(config$life_history)) "Output/LifeHistory/life_history_80_species.csv" else config$life_history
}

# Keep the original taxonomy source separate from the curated display summary.
atlas_display_trait_source <- function(config) {
  if(!is.null(config$species_traits)) return(config$species_traits)
  baseline <- atlas_trait_source(config)
  if(baseline!="Output/LifeHistory/life_history_80_species.csv") return(baseline)
  integrated <- "Output/SpeciesTraits/species_summary.csv"
  if(file.exists(integrated)) integrated else baseline
}

atlas_trait_inputs <- function(config) {
  path <- atlas_display_trait_source(config)
  if (!file.exists(path)) return(character())
  paths <- c(path, file.path(dirname(path), c("trait_evidence.csv", "references.csv", "trait_dictionary.csv", "build_manifest.json",
    "summary_evidence.csv","trait_provenance.csv","sources.csv","contextual_traits.csv")))
  paths[file.exists(paths)]
}

trait_tokens <- function(value) {
  if (is.na(value) || !nzchar(trimws(value))) return(character())
  sort(unique(trimws(strsplit(value, ";", fixed = TRUE)[[1]])))
}

trait_category_values <- function(value,field) {
  if(field %in% c("schooling_reported","batch_spawning_reported","spawning_aggregation_reported"))
    return(if(is.na(value) || !nzchar(value)) character() else "reported")
  trait_tokens(value)
}

trait_label <- function(value) {
  labels <- c(Brack = "Brackish", Fresh = "Freshwater", Saltwater = "Saltwater",
    SeaGrassBeds = "Seagrass beds", CoralReefs = "Coral reefs", TL = "TL (total length)",
    SL = "SL (standard length)", FL = "FL (fork length)", NG = "NG (source code)",
    Unspecified = "Unspecified type",reported="Reported (positive evidence)",
    LC="LC — Least Concern",VU="VU — Vulnerable",NT="NT — Near Threatened",EN="EN — Endangered",CR="CR — Critically Endangered",DD="DD — Data Deficient")
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
  path <- atlas_display_trait_source(config)
  metadata <- c("fishbase_name", "fishbase_version", "taxon_match_status", "primary_source_review", "regional_applicability",
    "migration","migration_best_available_basis","migration_scope","trophic_level_method","trophic_level_se","trophic_level_context",
    "contextual_diet_guild","assessment_date","verification","assessment_scope","assessment_url")
  length_fields <- c("maximum_length_male_unsexed_cm", "maximum_length_female_cm")
  type_fields <- c("maximum_length_male_unsexed_type", "maximum_length_female_type")
  fields <- c("species", metadata, names(atlas_trait_numbers), names(atlas_trait_categories), length_fields, type_fields)
  available <- file.exists(path)
  source <- if (available) read.csv(path, colClasses = "character", na.strings = "", stringsAsFactors = FALSE)
    else as.data.frame(setNames(rep(list(character()), length(fields)), fields), stringsAsFactors = FALSE)
  if (!available) message("No life-history output found; build it and refresh the atlas to attach traits.")
  required <- c("species","taxon_match_status","generation_time_model_years",length_fields,type_fields)
  if (!all(required %in% names(source))) stop("Trait output lacks required fields.")
  integrated <- available && file.exists(file.path(dirname(path),"summary_evidence.csv"))
  if(!integrated && "migration" %in% names(source)) source$migration_best_available <- source$migration
  for(field in setdiff(fields,names(source))) source[[field]] <- rep(NA_character_,nrow(source))
  if (anyNA(source$species) || anyDuplicated(source$species)) stop("Life-history species keys must be unique and nonblank.")
  out <- source[match(species, source$species), fields, drop = FALSE]
  out$species <- species; rownames(out) <- NULL
  for (field in c(names(atlas_trait_numbers), length_fields)) {
    values <- suppressWarnings(as.numeric(out[[field]]))
    if (any(!is.na(out[[field]]) & (!is.finite(values) | values < 0 | (values==0 & !field %in% c("depth_shallow_m","depth_deep_m"))))) stop("Invalid life-history value: ", field)
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
  evidence <- data.frame()
  if(integrated) {
    links <- read.csv(file.path(dirname(path),"summary_evidence.csv"),colClasses="character",stringsAsFactors=FALSE)
    provenance <- read.csv(file.path(dirname(path),"trait_provenance.csv"),colClasses="character",stringsAsFactors=FALSE)
    stopifnot(!anyDuplicated(provenance$evidence_id))
    links <- unique(links[links$species %in% species,c("species","field","evidence_id")])
    # Link inherited baseline fields that the newer summary_evidence export omits.
    inherited <- c(lifespan_model_years="lifespan_model",maturity_age_model_years="maturity_age_model",
      fisheries_importance="fisheries_importance",reproductive_guild_1="RepGuild1",
      maximum_length_female_cm="maximum_length_female")
    for(i in seq_len(nrow(out))) {
      p <- provenance[provenance$species==out$species[i],]
      for(field in c(names(inherited),"positive_habitat_tags","positive_water_types")) {
        if(any(links$species==out$species[i] & links$field==field) || is.na(out[[field]][i]) || !nzchar(as.character(out[[field]][i]))) next
        hits <- if(field=="positive_habitat_tags") p$trait %in% paste0("habitat_flag_",trait_tokens(out[[field]][i]))
          else if(field=="positive_water_types") p$trait %in% paste0("water_type_",tolower(trait_tokens(out[[field]][i])))
          else p$trait==inherited[[field]]
        if(any(hits)) links <- rbind(links,data.frame(species=out$species[i],field=field,evidence_id=p$evidence_id[hits]))
      }
    }
    ix <- match(links$evidence_id,provenance$evidence_id)
    stopifnot(!anyNA(ix),all(links$species==provenance$species[ix]))
    evidence <- cbind(links,provenance[ix,setdiff(names(provenance),c("species","evidence_id")),drop=FALSE])
  }
  list(traits = out, lengths = lengths, available = available, integrated=integrated, source=path,evidence=evidence)
}

write_atlas_trait_tables <- function(bundle, config) {
  out <- file.path(config$output, "tables")
  write.csv(bundle$traits, file.path(out, "life_history_traits.csv"), row.names = FALSE, na = "")
  write.csv(bundle$lengths, file.path(out, "life_history_lengths.csv"), row.names = FALSE, na = "")
  copied <- c(trait_evidence.csv = "life_history_evidence.csv", references.csv = "life_history_references.csv",
    trait_dictionary.csv = "life_history_dictionary.csv")
  for (name in if (bundle$available) names(copied) else character()) {
    from <- file.path(dirname(atlas_display_trait_source(config)), name)
    if (!file.exists(from) || !file.copy(from, file.path(out, copied[[name]]), overwrite = TRUE))
      stop("Could not copy life-history evidence: ", from)
  }
  if(bundle$integrated) for(name in c("summary_evidence.csv","trait_provenance.csv","sources.csv"))
    stopifnot(file.copy(file.path(dirname(bundle$source),name),file.path(out,paste0("species_traits_",name)),overwrite=TRUE))
  if(bundle$integrated) write.csv(bundle$evidence[c("species","field","evidence_id","source_id","locator","decision")],
    file.path(out,"species_traits_display_evidence.csv"),row.names=FALSE,na="")
  inputs <- c(atlas_trait_inputs(config), "Scripts/sampling_atlas_traits.R","Scripts/trait_filters.js","Scripts/trait_styles.css")
  write.csv(data.frame(path = inputs, md5 = unname(tools::md5sum(inputs))),
    file.path(out, "life_history_input_checksums.csv"), row.names = FALSE)
}

atlas_trait_filter_html <- function(bundle) {
  lines <- c('<details id="trait-filters"><summary><strong>Species trait filters</strong> <span id="trait-filter-count"></span></summary>',
    '<p>Combine traits with the sampling filters above. Different fields must all match. Water types and habitat tags test membership in positive records; an unlisted tag is not evidence of absence. Missing or withheld values remain visible until an active trait filter excludes them.</p>',
    '<div class="filter-grid">')
  for (field in names(atlas_trait_categories)) {
    values <- sort(unique(unlist(lapply(bundle$traits[[field]], trait_category_values,field=field))))
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
  c(lines, '</div><p id="trait-range-error" role="alert" hidden>A minimum exceeds its maximum. Correct the range to show matching species.</p><p>Model ages and reported ages are separate fields. Trophic level prefers the diet estimate, then food items; methods are not averaged. Source-specific feeding classes and reef guilds remain separate. Missing traits do not mean biological absence. IUCN categories are dated source snapshots, not verified latest status. Lengths take the largest reported value across sexes separately for each type; TL, SL and FL are not converted. Numeric bounds apply to the named summary field, not to all population-level observations.</p></details>')
}

atlas_trait_card_html <- function(row, bundle=NULL) {
  fmt <- function(n) format(signif(n, 3), scientific = FALSE, trim = TRUE)
  missing <- if (grepl("withheld", row$taxon_match_status, fixed = TRUE)) "Withheld — taxonomy unresolved" else "Not reported"
  pieces <- list()
  for (field in names(atlas_trait_numbers)) {
    n <- row[[field]]; label <- if(is.na(n)) missing else fmt(n)
    if(field=="trophic_level_preferred" && !is.na(n)) label <- paste0(label," · ",row$trophic_level_method," estimate",
      if(nzchar(row$trophic_level_se)) paste0("; SE ",row$trophic_level_se) else "")
    pieces[[field]] <- sprintf('<div class="trait-value" data-trait="%s" data-value="%s"><dt>%s</dt><dd>%s</dd></div>',
      field, if (is.na(n)) "" else sprintf("%.17g", n), atlas_trait_numbers[[field]], html_escape(label))
  }
  lengths <- atlas_length_values(row)
  label <- if (!nrow(lengths)) missing else paste(paste(vapply(lengths$cm, fmt, character(1)), "cm", lengths$type), collapse = "; ")
  pieces$maximum_length <- c(sprintf('<div><dt>Maximum reported length</dt><dd>%s</dd>', html_escape(label)),
    vapply(seq_len(nrow(lengths)),function(i) sprintf('<span class="trait-length" hidden data-type="%s" data-value="%.17g"></span>', html_escape(lengths$type[i]), lengths$cm[i]),""),'</div>')
  for (field in names(atlas_trait_categories)) {
    values <- trait_category_values(row[[field]],field)
    label <- if(length(values)) paste(vapply(values, trait_label, character(1)), collapse = "; ") else missing
    if(field=="iucn_category_reported" && length(values)) label <- paste0(label," · assessment ",if(nzchar(row$assessment_date)) row$assessment_date else "date not reported","; latest status unverified")
    pieces[[field]] <- sprintf('<div class="trait-value" data-trait="%s" data-values="%s"><dt>%s</dt><dd>%s</dd></div>', field,
      html_escape(paste(values, collapse = ";")), atlas_trait_categories[[field]],
      html_escape(label))
  }
  priority <- c("generation_time_model_years","maximum_age_wild_years","maximum_length","water_column_habitat",
    "positive_water_types","migration_best_available","trophic_level_preferred","fishbase_feeding_group","reproductive_guild_1","larval_development_place")
  lines <- c('<section class="life-history species-traits"><h3>Species traits</h3><dl class="trait-grid">',unlist(pieces[priority]),'</dl>',
    '<details class="additional-traits"><summary>More traits: reported ages, habitat, diet, reproduction and conservation</summary><dl class="trait-grid">',
    unlist(pieces[setdiff(names(pieces),priority)]),'</dl>')
  if(nzchar(row$contextual_diet_guild)) lines <- c(lines,sprintf('<p><strong>Contextual diet evidence:</strong> %s. Population and life-stage descriptions remain distinct from the reef guild.</p>',html_escape(row$contextual_diet_guild)))
  if(nzchar(row$migration_best_available_basis)) lines <- c(lines,sprintf('<p><strong>Migration basis:</strong> %s. %s</p>',html_escape(row$migration_best_available_basis),html_escape(row$migration_scope)))
  if(nzchar(row$trophic_level_context)) lines <- c(lines,sprintf('<p><strong>Trophic estimate context:</strong> %s</p>',html_escape(row$trophic_level_context)))
  lines <- c(lines,'<p class="trait-source-note">Model-derived ages are estimates. Reported ages and classifications can be population-specific; independent scientific review remains pending. Positive habitat and behavior records do not establish absence of unlisted traits.</p>','</details>')
  if (row$taxon_match_status != "exact_accepted_name") {
    note <- if (grepl("withheld", row$taxon_match_status, fixed = TRUE)) "Traits withheld because the proposed synonym match is ambiguous."
      else if (row$taxon_match_status == "not_in_trait_output") "This species is absent from the current trait output."
      else paste0("Traits attached from ", row$fishbase_name, " (", gsub("_", " ", row$taxon_match_status), "); project species name retained. Regional applicability is unreviewed.")
    lines <- c(lines, sprintf('<p class="trait-source-note">%s</p>', html_escape(note)))
  }
  if(!is.null(bundle) && bundle$integrated) {
    e <- bundle$evidence[bundle$evidence$species==row$species & bundle$evidence$field %in% c(names(pieces),"maximum_length_male_unsexed_cm","maximum_length_female_cm","contextual_diet_guild"),]
    if(nrow(e)) {
      lines <- c(lines,'<details class="trait-evidence"><summary>Trait sources and evidence for this species</summary><div style="overflow:auto"><table><thead><tr><th>Trait / source value</th><th>Source</th><th>Evidence / scope</th></tr></thead><tbody>')
      for(i in seq_len(nrow(e))) {
        cite <- if(nzchar(e$upstream_citation[i])) e$upstream_citation[i] else e$citation[i]
        url <- if(nzchar(e$upstream_url[i])) e$upstream_url[i] else e$url[i]
        link <- if(grepl("^https?://",url)) sprintf('<a href="%s" target="_blank" rel="noopener noreferrer">%s</a>',html_escape(url),html_escape(cite)) else html_escape(cite)
        lines <- c(lines,sprintf('<tr><td>%s<br>%s %s</td><td>%s</td><td>%s<br>%s · %s<br>%s</td></tr>',
          html_escape(e$field[i]),html_escape(e$value[i]),html_escape(e$unit[i]),link,html_escape(e$evidence_id[i]),html_escape(e$evidence_type[i]),html_escape(e$reference_scope[i]),html_escape(e$locator[i])))
      }
      lines <- c(lines,'</tbody></table></div></details>')
    }
  }
  c(lines, '</section>')
}
