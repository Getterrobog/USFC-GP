# Approximate display positions, never replacements for original catalog positions.
# Reference pools contain original physical-lot coordinates only: no chained imputation.
location_key <- function(x) {
  x[is.na(x)] <- ""
  x <- iconv(x, from = "UTF-8", to = "ASCII//TRANSLIT")
  x[is.na(x)] <- ""
  trimws(gsub("[^a-z0-9]+", " ", tolower(x)))
}

add_display_locations <- function(x, config) {
  x$display_longitude <- x$longitude
  x$display_latitude <- x$latitude
  x$display_mapped <- x$mapped
  x$coordinate_approximate <- FALSE
  x$approximation_level <- ""
  x$approximation_basis <- ""
  x$approximation_reference_ids <- ""
  x$approximation_reference_positions <- 0L
  x$approximation_reference_spread_km <- NA_real_
  x$approximation_source <- ""
  if (isTRUE(config$approximate_locations)) {
    fields <- c("country", "province_state", "district_county", "island", "locality", "station", "vessel", "region")
    keys <- as.data.frame(lapply(x[fields], location_key), stringsAsFactors = FALSE)
    keys$year <- ifelse(is.na(x$year), "", as.character(x$year))
    # No reference coordinates from derivative pipelines, even if they look numeric.
    donors <- which(x$object_kind == "Specimen/Lot" & x$coordinate_source == "original_catalog" &
      x$coordinates_valid & x$in_scope & x$longitude >= config$bounds['west'] &
      x$longitude <= config$bounds['east'] & x$latitude >= config$bounds['south'] & x$latitude <= config$bounds['north'])
    anchors <- read_char_csv(config$locality_anchors)
    stopifnot(!anyDuplicated(anchors$rule_id))
    pools <- list()
    pool <- function(ids) {
      if (!length(ids)) return(NULL)
      points <- unique(x[ids, c("longitude", "latitude")])
      lon <- median(points$longitude); lat <- median(points$latitude)
      # Maximum distance to the donor positions is descriptive, NOT an error radius.
      rad <- pi / 180
      a <- sin((points$latitude - lat) * rad / 2)^2 + cos(lat * rad) *
        cos(points$latitude * rad) * sin((points$longitude - lon) * rad / 2)^2
      list(lon = round(lon, 2), lat = round(lat, 2), n = nrow(points),
        spread = round(max(6371.0088 * 2 * asin(sqrt(pmin(1, a)))), 1),
        ids = paste(sort(unique(x$catalog_number[ids])), collapse = ";"),
        source = "Data/All_collections.csv: original physical-lot coordinates")
    }
    match_pool <- function(i, columns, required = tail(columns, 1)) {
      if (any(!nzchar(unlist(keys[i, required, drop = FALSE])))) return(NULL)
      cache_key <- paste(c(columns, unlist(keys[i, columns, drop = FALSE])), collapse = "|")
      if (!is.null(pools[[cache_key]])) return(pools[[cache_key]])
      ids <- donors
      for (field in columns) ids <- ids[keys[[field]][ids] == keys[[field]][i]]
      p <- pool(ids)
      if (!is.null(p)) pools[[cache_key]] <<- p
      p
    }
    anchor_pool <- function(i) {
      label <- paste(keys$locality[i], keys$island[i], keys$province_state[i])
      for (j in seq_len(nrow(anchors))) {
        a <- anchors[j, ]
        if (nzchar(a$country) && location_key(a$country) != keys$country[i]) next
        if (nzchar(a$province_pattern) && !grepl(a$province_pattern, keys$province_state[i])) next
        if (!grepl(a$pattern, label, perl = TRUE)) next
        if (nzchar(a$longitude) && nzchar(a$latitude)) {
          p <- list(lon = as.numeric(a$longitude), lat = as.numeric(a$latitude), n = 1L,
            spread = NA_real_, ids = "", source = a$source)
        } else {
          ids <- donors[keys$country[donors] == keys$country[i]]
          if (nzchar(a$province_pattern)) ids <- ids[grepl(a$province_pattern, keys$province_state[ids])]
          ids <- ids[grepl(a$pattern, paste(keys$locality[ids], keys$island[ids]), perl = TRUE)]
          p <- pool(ids)
        }
        if (!is.null(p)) return(list(point = p, level = a$level, basis = paste("Named place:", a$rule_id)))
      }
      NULL
    }
    for (i in which(x$included & !x$mapped & !x$coordinates_valid)) {
      p <- match_pool(i, c("country", "vessel", "year", "station"), c("vessel", "year", "station"))
      level <- "station"; basis <- "Same country, vessel, year and station"
      # Reused station identifiers must not send a lot to a broad average of stations.
      if (!is.null(p) && p$spread > 25) p <- NULL
      if (is.null(p)) {
        p <- match_pool(i, c("country", "province_state", "locality"))
        level <- "locality"; basis <- paste("Exact locality label:", x$locality[i])
      }
      if (is.null(p)) {
        anchor <- anchor_pool(i)
        if (!is.null(anchor)) { p <- anchor$point; level <- anchor$level; basis <- anchor$basis }
      }
      hierarchy <- list(island = c("country", "island"),
        county = c("country", "province_state", "district_county"),
        state = c("region", "country", "province_state"), country = c("region", "country"), basin = "region")
      for (name in names(hierarchy)) {
        if (!is.null(p)) break
        columns <- hierarchy[[name]]
        p <- match_pool(i, columns)
        level <- name
        basis <- paste(paste(columns, unlist(x[i, columns, drop = FALSE]), sep = "="), collapse = "; ")
      }
      if (is.null(p)) next
      if (!is.finite(p$lon) || !is.finite(p$lat) || p$lon < config$bounds['west'] ||
          p$lon > config$bounds['east'] || p$lat < config$bounds['south'] || p$lat > config$bounds['north']) next
      x$display_longitude[i] <- p$lon; x$display_latitude[i] <- p$lat
      x$display_mapped[i] <- TRUE; x$coordinate_approximate[i] <- TRUE
      x$approximation_level[i] <- level; x$approximation_basis[i] <- basis
      x$approximation_reference_ids[i] <- p$ids
      x$approximation_reference_positions[i] <- p$n
      x$approximation_reference_spread_km[i] <- p$spread
      x$approximation_source[i] <- p$source
    }
  }
  x$display_cell_lon <- floor(x$display_longitude / config$cell_degrees) * config$cell_degrees
  x$display_cell_lat <- floor(x$display_latitude / config$cell_degrees) * config$cell_degrees
  x$display_cell_id <- ifelse(x$display_mapped,
    sprintf("%.3f,%.3f", x$display_cell_lon, x$display_cell_lat), NA_character_)
  x
}

display_cell_counts <- function(d, groups = character()) {
  d <- d[d$display_mapped, ]
  d$cell_lon <- d$display_cell_lon; d$cell_lat <- d$display_cell_lat
  d$cell_id <- d$display_cell_id
  by <- unique(c(groups, "cell_id", "cell_lon", "cell_lat"))
  cells <- sum_groups(d, by)
  estimates <- sum_groups(d[d$coordinate_approximate, ], by)
  names(estimates)[names(estimates) == "specimens"] <- "approximate_specimens"
  names(estimates)[names(estimates) == "lots"] <- "approximate_lots"
  result <- merge(cells, estimates, by = by, all.x = TRUE, sort = TRUE)
  result$approximate_specimens[is.na(result$approximate_specimens)] <- 0
  result$approximate_lots[is.na(result$approximate_lots)] <- 0
  result$recorded_specimens <- result$specimens - result$approximate_specimens
  result
}
