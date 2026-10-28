# Downstream analytical functions; no taxonomy lookup, imputation or atlas rebuild.
join_selection_evidence <- function(records, raw) {
  ids <- records$record_id
  if (anyNA(ids) || any(ids %% 1 != 0) || anyDuplicated(ids) ||
      any(ids < 1 | ids > nrow(raw))) stop("Invalid atlas record IDs.")
  original <- raw[ids, , drop = FALSE]
  if (!identical(as.character(records$catalog_number), as.character(original$Catalog.Number...USNM)))
    stop("Atlas/raw record linkage mismatch; use the matching raw export.")
  fields <- c(station = "Station", cruise = "Cruise", locality = "Precise.Locality",
    province_state = "Province.State", depth_original = "Depth..m.",
    collection_method = "Collection.Method", preservation_original = "Preservation.Method", ezid = "EZID")
  if (!all(fields %in% names(original))) stop("Raw evidence fields missing.")
  for (name in names(fields)) records[[name]] <- original[[fields[[name]]]]
  records
}

distance_km <- function(longitude, latitude) {
  rad <- pi / 180
  lat <- latitude * rad; lon <- longitude * rad
  a <- sin(outer(lat, lat, "-") / 2)^2 +
    outer(cos(lat), cos(lat)) * sin(outer(lon, lon, "-") / 2)^2
  6371.0088 * 2 * asin(sqrt(pmin(pmax(a, 0), 1)))
}

build_site_tree <- function(records) {
  coords <- unique(records[, c("longitude", "latitude")])
  coords <- coords[order(coords$longitude, coords$latitude), , drop = FALSE]
  if (!nrow(coords) || any(!is.finite(as.matrix(coords)))) stop("No valid screening coordinates.")
  distances <- distance_km(coords$longitude, coords$latitude)
  key <- function(x) paste(x$longitude, x$latitude, sep = "|")
  list(coords = coords, distances = distances,
    tree = if (nrow(coords) > 1) hclust(as.dist(distances), method = "complete") else NULL,
    row_coord = match(key(records), key(coords)))
}

assign_sites <- function(records, geometry, diameter) {
  membership <- if (is.null(geometry$tree)) 1L else cutree(geometry$tree, h = diameter)
  # IDs are deterministic for this fixed input coordinate frame, not permanent locality IDs.
  records$site_id <- sprintf("D%02d_S%04d", as.integer(diameter), membership[geometry$row_coord])
  records
}

selection_cells <- function(records, min_specimens, min_lots) {
  fields <- c("species", "site_id", "life_stage", "year")
  empty <- data.frame(species = character(), site_id = character(), life_stage = character(),
    year = integer(), specimens = numeric(), lots = integer(), largest_lot_fraction = numeric(),
    station_recorded_lots = integer(), explicit_year_lots = integer(), stage_unrecorded_lots = integer(),
    taxonomy_unvalidated_lots = integer(), catalog_numbers = character(), qualifies = logical())
  if (!nrow(records)) return(empty)
  groups <- split(seq_len(nrow(records)), interaction(records[fields], drop = TRUE, lex.order = TRUE))
  result <- lapply(groups, function(i) {
    z <- records[i, ]
    data.frame(species = z$species[1], site_id = z$site_id[1], life_stage = z$life_stage[1],
      year = z$year[1], specimens = sum(z$specimen_count), lots = nrow(z),
      largest_lot_fraction = max(z$specimen_count) / sum(z$specimen_count),
      station_recorded_lots = sum(nzchar(z$station)), explicit_year_lots = sum(z$year_status == "explicit_year"),
      stage_unrecorded_lots = sum(z$stage_evidence == "stage_unrecorded"),
      taxonomy_unvalidated_lots = sum(z$taxonomy_status == "catalog_binomial_unvalidated"),
      catalog_numbers = paste(sort(z$catalog_number), collapse = "; "),
      qualifies = sum(z$specimen_count) >= min_specimens && nrow(z) >= min_lots)
  })
  result <- do.call(rbind, result); rownames(result) <- NULL
  result[order(result$site_id, result$life_stage, result$year, result$species), ]
}

selection_assemblages <- function(cells, min_species) {
  qualified <- cells[cells$qualifies, ]
  empty <- data.frame(site_id = character(), life_stage = character(), year = integer(),
    species_count = integer(), specimens = numeric(), single_lot_species = integer(),
    species = character(), meets_multispecies_screen = logical())
  if (!nrow(qualified)) return(empty)
  groups <- split(seq_len(nrow(qualified)), interaction(qualified[c("site_id", "life_stage", "year")], drop = TRUE))
  result <- lapply(groups, function(i) {
    z <- qualified[i, ]
    data.frame(site_id = z$site_id[1], life_stage = z$life_stage[1], year = z$year[1],
      species_count = nrow(z), specimens = sum(z$specimens),
      single_lot_species = sum(z$lots == 1), species = paste(sort(z$species), collapse = "; "),
      meets_multispecies_screen = nrow(z) >= min_species)
  })
  result <- do.call(rbind, result); rownames(result) <- NULL
  result[order(-result$species_count, -result$specimens, result$site_id, result$life_stage, result$year), ]
}

site_evidence <- function(records, geometry, diameter) {
  groups <- split(seq_len(nrow(records)), records$site_id)
  result <- lapply(groups, function(i) {
    z <- records[i, ]; ci <- unique(geometry$row_coord[i])
    locality <- sort(table(z$locality[nzchar(z$locality)]), decreasing = TRUE)
    data.frame(site_id = z$site_id[1], representative_locality = if (length(locality)) names(locality)[1] else "",
      regions = paste(sort(unique(z$region)), collapse = "; "),
      longitude_min = min(z$longitude), longitude_max = max(z$longitude),
      latitude_min = min(z$latitude), latitude_max = max(z$latitude),
      diameter_km = max(geometry$distances[ci, ci, drop = FALSE]),
      lots = nrow(z), species = length(unique(z$species)),
      recorded_localities = paste(sort(unique(z$locality[nzchar(z$locality)])), collapse = " | "))
  })
  result <- do.call(rbind, result); rownames(result) <- NULL
  stopifnot(all(result$diameter_km <= diameter + 1e-8))
  result
}

species_design_summary <- function(cells, assemblages, records, all_species, config) {
  shared <- assemblages[assemblages$meets_multispecies_screen, ]
  key <- function(z) paste(z$site_id, z$life_stage, z$year, sep = "|")
  cells$in_shared_assemblage <- cells$qualifies & key(cells) %in% key(shared)
  result <- lapply(sort(all_species), function(sp) {
    z <- cells[cells$species == sp & cells$qualifies, ]
    good <- cells[cells$species == sp & cells$in_shared_assemblage, ]
    multi <- if (nrow(z)) table(paste(z$site_id, z$life_stage)) else integer()
    robust <- good[good$lots >= 2 & good$explicit_year_lots == good$lots & good$taxonomy_unvalidated_lots == 0, ]
    r <- records[records$species == sp, ]
    tier <- if (length(unique(good$site_id)) >= 2) "cross_site_investigation" else
      if (nrow(good)) "local_assemblage_investigation" else
      if (nrow(z)) "no_multispecies_overlap_at_baseline" else "no_qualifying_cell_at_baseline"
    data.frame(species = sp, investigation_tier = tier,
      candidate_sites = length(unique(good$site_id)), shared_species_site_year_cells = nrow(good),
      qualified_site_year_cells = nrow(z), repeated_site_stage_pairs = sum(multi >= 2),
      multiple_lot_explicit_year_shared_cells = nrow(robust),
      maximum_single_year_cell_specimens = if (nrow(z)) max(z$specimens) else 0,
      screened_lots = nrow(r), screened_specimens = sum(r$specimen_count),
      screened_regions = paste(sort(unique(r$region)), collapse = "; "),
      modern_match = "pending", preservation_history = "pending", museum_access = "pending",
      dna_recovery = "pending", power = "pending", traits_and_habitat = "pending")
  })
  result <- do.call(rbind, result)
  result[order(-result$candidate_sites, -result$multiple_lot_explicit_year_shared_cells,
    -result$repeated_site_stage_pairs, result$species), ]
}

selection_sensitivity <- function(records, geometry, config) {
  grid <- expand.grid(diameter_km = config$sensitivity_diameters,
    min_specimens = config$sensitivity_specimens, min_lots = config$sensitivity_min_lots,
    date_mode = config$sensitivity_date_modes, last_year = config$sensitivity_last_years,
    stringsAsFactors = FALSE)
  summaries <- memberships <- vector("list", nrow(grid))
  cache <- new.env(parent = emptyenv())
  for (i in seq_len(nrow(grid))) {
    g <- grid[i, ]
    cache_key <- paste(g$diameter_km, g$date_mode, g$last_year, sep = "_")
    if (!exists(cache_key, envir = cache, inherits = FALSE)) {
      d <- assign_sites(records, geometry, g$diameter_km)
      d <- d[d$year <= g$last_year & (g$date_mode != "explicit_only" | d$year_status == "explicit_year"), ]
      assign(cache_key, selection_cells(d, 1, 1), envir = cache)
    }
    cells <- get(cache_key, envir = cache, inherits = FALSE)
    cells$qualifies <- cells$specimens >= g$min_specimens & cells$lots >= g$min_lots
    a <- selection_assemblages(cells, config$min_species)
    a <- a[a$meets_multispecies_screen, ]
    key <- function(x) paste(x$site_id, x$life_stage, x$year, sep = "|")
    species <- sort(unique(cells$species[cells$qualifies & key(cells) %in% key(a)]))
    scenario <- sprintf("Q%03d", i)
    summaries[[i]] <- cbind(scenario_id = scenario, g, qualified_cells = sum(cells$qualifies),
      assemblage_site_years = nrow(a), assemblage_sites = length(unique(a$site_id)), species = length(species))
    memberships[[i]] <- data.frame(scenario_id = rep(scenario, length(species)), species = species)
  }
  list(scenarios = do.call(rbind, summaries), species = do.call(rbind, memberships))
}

site_components <- function(incidence) {
  if (!ncol(incidence)) return(data.frame(site_id = character(), component = integer()))
  adjacent <- crossprod(incidence > 0) > 0
  membership <- integer(ncol(incidence)); component <- 0L
  for (i in seq_len(ncol(incidence))) {
    if (membership[i] != 0L) next
    component <- component + 1L; queue <- i; membership[i] <- component
    while (length(queue)) {
      node <- queue[1]; queue <- queue[-1]
      neighbors <- which(adjacent[node, ] & membership == 0L)
      membership[neighbors] <- component; queue <- c(queue, neighbors)
    }
  }
  data.frame(site_id = colnames(incidence), component = membership)
}

assemblage_evidence <- function(records, edges, assemblages) {
  collapse <- function(x) paste(sort(unique(x[nzchar(x)])), collapse = " | ")
  details <- lapply(seq_len(nrow(edges)), function(i) {
    e <- edges[i, ]
    z <- records[records$species == e$species & records$site_id == e$site_id &
      records$year == e$year & records$life_stage == e$life_stage, ]
    data.frame(e, date_labels = collapse(z$date_original), stations = collapse(z$station),
      vessels = collapse(z$vessel), localities = collapse(z$locality),
      depths_original = collapse(z$depth_original), collection_methods = collapse(z$collection_method))
  })
  evidence <- assemblages
  evidence$shared_date_labels <- ""; evidence$shared_station_day_keys <- ""
  for (i in seq_len(nrow(evidence))) {
    a <- evidence[i, ]
    sp <- edges$species[edges$site_id == a$site_id & edges$life_stage == a$life_stage & edges$year == a$year]
    subsets <- lapply(sp, function(s) records[records$species == s & records$site_id == a$site_id &
      records$year == a$year & records$life_stage == a$life_stage, ])
    # Literal source labels only: no century inference or revised atlas dates.
    labels <- lapply(subsets, function(z) unique(trimws(sub("\\s*\\(.*$", "", z$date_original))))
    evidence$shared_date_labels[i] <- collapse(Reduce(intersect, labels))
    station_days <- lapply(subsets, function(z) {
      label <- trimws(sub("\\s*\\(.*$", "", z$date_original))
      day <- grepl("^[0-9]{1,2} [A-Za-z]{3} [0-9]{4}$|^[0-9]{1,2}-[A-Za-z]{3}-[0-9]{2}$", label)
      ok <- day & nzchar(z$station) & nzchar(z$vessel)
      unique(paste(z$vessel[ok], z$station[ok], label[ok], sep = " / "))
    })
    evidence$shared_station_day_keys[i] <- collapse(Reduce(intersect, station_days))
  }
  list(species = if (length(details)) do.call(rbind, details) else edges, groups = evidence)
}
