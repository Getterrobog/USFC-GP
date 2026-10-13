# Report metadata only: catalog ranks and common names from curated FishBase matches.
atlas_taxonomy_inputs <- function(config) {
  paths <- c(config$input, atlas_trait_source(config),
    file.path(dirname(atlas_trait_source(config)), "source_records", "species.csv"))
  paths[file.exists(paths)]
}

read_atlas_taxonomy <- function(species, records, config) {
  raw <- read_char_csv(config$input)
  ids <- suppressWarnings(as.integer(records$record_id))
  if (anyNA(ids) || any(ids < 1L | ids > nrow(raw)) || anyDuplicated(ids) ||
      anyNA(records$catalog_number) ||
      !identical(as.character(raw$Catalog.Number...USNM[ids]), as.character(records$catalog_number)))
    stop("Catalog taxonomy cannot be linked to audit record IDs and catalog numbers.")
  out <- data.frame(species = species, order = "", family = "", common_name = "",
    common_name_source_species = "", common_name_match_status = "", stringsAsFactors = FALSE)
  for (field in c("order", "family")) {
    values <- trimws(raw[[if (field == "order") "Order" else "Family"]][ids])
    out[[field]] <- vapply(species, function(name) {
      labels <- unique(values[!is.na(records$species) & records$species == name & !is.na(values) & nzchar(values)])
      if (length(labels) > 1L) stop("Conflicting catalog ", field, " labels for ", name)
      if (length(labels)) labels else ""
    }, character(1))
  }
  path <- atlas_trait_source(config)
  cached <- file.path(dirname(path), "source_records", "species.csv")
  if (file.exists(path) && file.exists(cached)) {
    matches <- read_char_csv(path)
    source <- read_char_csv(cached)
    source_name <- paste(source$Genus, source$Species)
    if (anyDuplicated(matches$species) || anyDuplicated(source_name))
      stop("Common-name source keys must be unique.")
    match_rows <- match(species, matches$species)
    names <- matches$fishbase_name[match_rows]
    status <- matches$taxon_match_status[match_rows]
    allowed <- !is.na(names) & nzchar(names) & !is.na(status) & !grepl("withheld", status, fixed = TRUE)
    selected <- match(names, source_name)
    common <- trimws(source$FBname[selected])
    attached <- allowed & !is.na(common) & nzchar(common)
    out$common_name[attached] <- common[attached]
    out$common_name_source_species[attached] <- names[attached]
    out$common_name_match_status[!is.na(status)] <- status[!is.na(status)]
  }
  out
}

write_atlas_taxonomy_tables <- function(taxonomy, config) {
  write.csv(taxonomy, file.path(config$output, "tables", "species_taxonomy.csv"), row.names = FALSE, na = "")
  inputs <- c(atlas_taxonomy_inputs(config), "Scripts/sampling_atlas_taxonomy.R")
  write.csv(data.frame(path = inputs, md5 = unname(tools::md5sum(inputs))),
    file.path(config$output, "tables", "taxonomy_input_checksums.csv"), row.names = FALSE)
}

atlas_taxonomy_filter_html <- function(taxonomy) {
  unlist(lapply(c("order", "family"), function(field) {
    values <- sort(unique(taxonomy[[field]][nzchar(taxonomy[[field]])]))
    c(sprintf('<label>%s<select id="taxonomy-%s"><option value="">All %s</option>',
      if (field == "order") "Order" else "Family", field, if (field == "order") "orders" else "families"),
      if (any(!nzchar(taxonomy[[field]]))) '<option value="__missing__">Not reported</option>',
      sprintf('<option value="%s">%s</option>', html_escape(values), html_escape(values)), '</select></label>')
  }))
}

atlas_taxonomy_heading_html <- function(row) {
  label <- function(x) if (nzchar(x)) html_escape(x) else "Not reported"
  sprintf('<p class="taxonomy-line">Order: %s · Family: %s</p><h2><i>%s</i> <span class="common-name">— %s</span></h2>',
    label(row$order), label(row$family), html_escape(row$species),
    if (nzchar(row$common_name)) html_escape(row$common_name) else "Common name not reported")
}
