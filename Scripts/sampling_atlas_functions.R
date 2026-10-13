# Pure data transformations and rendering helpers for the USFC sampling atlas.
# Base R is used for tabular analysis; maps supplies the offline coastline.

read_char_csv <- function(path) {
  read.csv(path, colClasses = "character", na.strings = NULL,
           check.names = TRUE, fileEncoding = "UTF-8-BOM", stringsAsFactors = FALSE)
}

is_binomial <- function(x) {
  !is.na(x) & grepl("^[A-Z][a-z]+ [a-z][a-z-]+$", x) &
    !grepl(" (sp|spp|cf|aff)$", x)
}

clean_identification <- function(x) {
  x <- trimws(x)
  result <- sub("^([A-Z][a-z]+ [a-z][a-z-]+).*", "\\1", x)
  result[grepl("\\?|\\b(cf|aff)\\.", x) | !is_binomial(result)] <- NA_character_
  result
}

parse_collection_year <- function(date, vessel) {
  # Extract years, not the first two-digit token (which can be a day).
  explicit <- unique(regmatches(date, gregexpr("\\b(18|19|20)[0-9]{2}\\b", date))[[1]])
  if (length(explicit) == 1L)
    return(list(year = as.integer(explicit), year_status = "explicit_year"))
  if (length(explicit) > 1L)
    return(list(year = NA_integer_, year_status = "multiple_years"))
  match <- regmatches(trimws(date), regexec("^[0-9]{1,2}-[A-Za-z]{3}-([0-9]{2})$", trimws(date)))[[1]]
  if (length(match)) {
    # Explicit, auditable disambiguation assumptions inherited from the project.
    windows <- list("Albatross" = c(1882, 1921), "Albatross II" = c(1926, 1932),
                    "Albatross III" = c(1948, 1959), "Albatross IV" = c(1963, 2008),
                    "Fish Hawk" = c(1880, 1926), "Grampus" = c(1886, 1917))
    window <- windows[[trimws(vessel)]]
    candidates <- c(1800L, 1900L, 2000L) + as.integer(match[2])
    if (!is.null(window)) {
      candidates <- candidates[candidates >= window[1] & candidates <= window[2]]
      if (length(candidates) == 1L)
        return(list(year = candidates, year_status = "century_inferred_from_vessel"))
    }
    return(list(year = NA_integer_, year_status = "ambiguous_century"))
  }
  list(year = NA_integer_, year_status = if (trimws(date) == "") "missing" else "unparsed")
}

classify_stage <- function(preparation, notes, unknown_stage = "adult") {
  # Narrative references to a larval curation project alone are NOT stage evidence.
  larval <- grepl("larvae|larval|leptocephal", preparation, ignore.case = TRUE) |
    grepl("larval fishes|larval fish\\.|^larvae[ .]*$|^larval[ .]*$", notes, ignore.case = TRUE)
  juvenile <- grepl("juvenile|\\bjuv\\.", notes, ignore.case = TRUE)
  mixed <- grepl("larv", notes, ignore.case = TRUE) & juvenile
  mixed <- mixed | (larval & juvenile)
  explicit_adult <- grepl("\\badult", preparation, ignore.case = TRUE) |
    grepl("^adult[s .]*$", notes, ignore.case = TRUE)
  stage <- ifelse(mixed, "mixed", ifelse(larval, "larva",
    ifelse(explicit_adult | juvenile, "adult", unknown_stage)))
  evidence <- ifelse(mixed, "mixed_larvae_and_nonlarvae_unsplit",
    ifelse(larval, "explicit_larval_evidence", ifelse(juvenile, "explicit_juvenile",
      ifelse(explicit_adult, "explicit_adult", "stage_unrecorded"))))
  data.frame(life_stage = stage, stage_evidence = evidence)
}

inside_polygon <- function(x, y, polygon) {
  inside <- rep(FALSE, length(x))
  j <- nrow(polygon)
  for (i in seq_len(nrow(polygon))) {
    xi <- polygon[i, 1]; yi <- polygon[i, 2]
    xj <- polygon[j, 1]; yj <- polygon[j, 2]
    hit <- ((yi > y) != (yj > y)) & (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
    hit[is.na(hit)] <- FALSE
    inside <- xor(inside, hit)
    j <- i
  }
  inside[is.na(x) | is.na(y)] <- FALSE
  inside
}

classify_region <- function(longitude, latitude, ocean, sea, country, bounds) {
  valid <- is.finite(longitude) & is.finite(latitude) & abs(longitude) <= 180 &
    abs(latitude) <= 90 & !(longitude == 0 & latitude == 0)
  in_box <- valid & longitude >= bounds['west'] & longitude <= bounds['east'] &
    latitude >= bounds['south'] & latitude <= bounds['north']
  gulf_label <- grepl("gulf of mexico", sea, ignore.case = TRUE)
  carib_label <- grepl("caribbean", sea, ignore.case = TRUE)
  elsewhere <- grepl("pacific|indian", ocean, ignore.case = TRUE) |
    grepl("adriatic|mediterranean", sea, ignore.case = TRUE)
  western_country <- country %in% c("United States", "Canada", "Bahamas", "Bermuda",
    "Cuba", "Mexico", "Jamaica", "Saint Lucia", "Virgin Islands (U.S.)", "Puerto Rico",
    "Netherlands Antilles", "Anguilla", "Dominican Republic", "Barbados", "Panama",
    "Colombia", "Venezuela", "Trinidad and Tobago", "Trinidad And Tobago", "Nicaragua")
  metadata_scope <- gulf_label | carib_label |
    (grepl("atlantic", ocean, ignore.case = TRUE) & western_country)
  in_scope <- (in_box | (!valid & metadata_scope)) & !elsewhere
  gulf <- inside_polygon(longitude, latitude,
    rbind(c(-98,18), c(-90,18), c(-86,21), c(-80.5,25), c(-81,31), c(-98,31)))
  carib <- inside_polygon(longitude, latitude,
    rbind(c(-89,8), c(-59,8), c(-59,23.5), c(-75,23.5), c(-85,22), c(-89,18)))
  region <- ifelse(gulf_label, "Gulf of Mexico", ifelse(carib_label, "Caribbean",
    ifelse(in_box & gulf, "Gulf of Mexico", ifelse(in_box & carib, "Caribbean", "Atlantic"))))
  region[!in_scope] <- "Outside or unresolved"
  source <- ifelse(gulf_label | carib_label, "recorded_sea",
    ifelse(in_box, "approximate_coordinate_partition", "ocean_and_country"))
  source[!in_scope] <- "outside_or_unresolved"
  data.frame(coordinates_valid = valid, in_scope = in_scope, region = region,
             region_source = source)
}

prepare_atlas_records <- function(config) {
  raw <- read_char_csv(config$input)
  required <- c("Catalog.Number...USNM", "Specimen.Count", "Kind.of.Object", "Identification",
    "Preparation.Details..Preparation.Location.Count.", "Notes", "Date.Collected", "Vessel",
    "Centroid.Longitude", "Centroid.Latitude", "Ocean", "Sea.Gulf", "Country", "Type.Status", "Order", "Depleted.",
    "Precise.Locality", "Province.State", "District.County", "Island.Name", "Station", "Cruise")
  stopifnot(all(required %in% names(raw)))
  x <- data.frame(record_id = seq_len(nrow(raw)), catalog_number = raw$Catalog.Number...USNM,
    object_kind = raw$Kind.of.Object, specimen_count = suppressWarnings(as.numeric(raw$Specimen.Count)),
    identification = raw$Identification, cleaned_name = clean_identification(raw$Identification),
    preparation = raw$Preparation.Details..Preparation.Location.Count., notes = raw$Notes,
    date_original = raw$Date.Collected, vessel = raw$Vessel,
    longitude = suppressWarnings(as.numeric(raw$Centroid.Longitude)),
    latitude = suppressWarnings(as.numeric(raw$Centroid.Latitude)),
    coordinate_source = "original_catalog", type_status = raw$Type.Status,
    depleted = raw$Depleted., ocean = raw$Ocean, sea = raw$Sea.Gulf, country = raw$Country,
    locality = raw$Precise.Locality, province_state = raw$Province.State,
    district_county = raw$District.County, island = raw$Island.Name,
    station = raw$Station, cruise = raw$Cruise,
    stringsAsFactors = FALSE)
  x$species <- x$cleaned_name
  x$taxonomy_status <- ifelse(is.na(x$species), "unresolved", "catalog_binomial_unvalidated")
  tax <- read_char_csv(config$taxonomy)
  if (anyDuplicated(tax$Input_Name)) stop("Taxonomy cache contains duplicate input names.")
  match_tax <- match(x$cleaned_name, tax$Input_Name)
  names_tax <- tax$Valid_Name[match_tax]
  good <- is_binomial(names_tax)
  x$species[good] <- names_tax[good]
  x$taxonomy_status[good] <- "cached_valid_name"
  rejected <- !is.na(names_tax) & names_tax %in% c("Uncertain", "No species ID")
  x$species[rejected] <- NA_character_
  x$taxonomy_status[rejected] <- "unresolved"
  # Reuse curated taxonomy only, never legacy imputed coordinates or dates.
  for (path in c(config$curated_names, config$manual_names)) {
    names <- read_char_csv(path)
    names <- unique(names[, c("Catalog.Number...USNM", "Valid.Name")])
    if (anyDuplicated(names$Catalog.Number...USNM)) stop("Conflicting curated names in ", path)
    m <- match(x$catalog_number, names$Catalog.Number...USNM)
    valid <- names$Valid.Name[m]
    good <- is_binomial(valid)
    x$species[good] <- valid[good]
    x$taxonomy_status[good] <- "curated_catalog_name"
    bad <- !is.na(valid) & valid %in% c("Uncertain", "No species ID")
    x$species[bad] <- NA_character_
    x$taxonomy_status[bad] <- "unresolved"
  }
  stages <- classify_stage(x$preparation, x$notes, config$unknown_stage)
  x <- cbind(x, stages)
  dates <- Map(parse_collection_year, x$date_original, x$vessel)
  x$year <- vapply(dates, function(a) a$year, integer(1))
  x$year_status <- vapply(dates, function(a) a$year_status, character(1))
  x$override_reason <- ""
  overrides <- read_char_csv(config$overrides)
  if (anyDuplicated(overrides$catalog_number)) stop("Duplicate override catalog number.")
  if (nrow(overrides)) {
    if (any(!nzchar(overrides$reason))) stop("Each override requires a reason.")
    if (any(!overrides$catalog_number %in% x$catalog_number)) stop("Unknown override catalog number.")
    for (j in seq_len(nrow(overrides))) {
      idx <- which(x$catalog_number == overrides$catalog_number[j])
      for (field in c("species", "life_stage", "year", "longitude", "latitude")) {
        value <- overrides[[field]][j]
        if (!nzchar(value)) next
        if (field %in% c("year", "longitude", "latitude")) {
          value <- suppressWarnings(as.numeric(value))
          if (!is.finite(value)) stop("Invalid numeric override: ", field)
        }
        x[idx, field] <- value
        if (field == "species") x$taxonomy_status[idx] <- "manual_override"
        if (field == "life_stage") x$stage_evidence[idx] <- "manual_override"
        if (field == "year") x$year_status[idx] <- "manual_override"
        if (field %in% c("longitude", "latitude")) x$coordinate_source[idx] <- "manual_override"
      }
      x$override_reason[idx] <- overrides$reason[j]
    }
  }
  if (any(!x$life_stage %in% c("adult", "larva", "unknown", "mixed"))) stop("Invalid stage override.")
  if (any(!is.na(x$species) & !is_binomial(x$species))) stop("Invalid species override.")
  if (any(!is.na(x$year) & (x$year %% 1 != 0 | x$year < 1800 | x$year > 2099))) stop("Invalid year override.")
  x <- cbind(x, classify_region(x$longitude, x$latitude, x$ocean, x$sea, x$country, config$bounds))
  for (j in seq_len(nrow(overrides))) {
    value <- overrides$region[j]
    if (!nzchar(value)) next
    if (!value %in% c("Atlantic", "Caribbean", "Gulf of Mexico", "Outside or unresolved")) stop("Invalid region override.")
    idx <- which(x$catalog_number == overrides$catalog_number[j])
    x$region[idx] <- value
    x$in_scope[idx] <- value != "Outside or unresolved"
    x$region_source[idx] <- "manual_override"
  }
  x$exclusion_reason <- ifelse(x$object_kind != "Specimen/Lot", "not_physical_specimen_lot",
    ifelse(is.na(x$specimen_count) | x$specimen_count <= 0 | x$specimen_count %% 1 != 0, "invalid_count",
      ifelse(raw$Order == "Amphioxiformes", "not_fish",
        ifelse(is.na(x$species), "unresolved_species", ifelse(!x$in_scope, "outside_or_unresolved_geography",
          ifelse(!is.na(x$year) & x$year > config$max_year, "after_year_cutoff", ""))))))
  x$included <- x$exclusion_reason == ""
  if (anyDuplicated(x$catalog_number[x$object_kind == "Specimen/Lot"])) stop("Duplicate physical lot IDs; resolve before counting.")
  x$coordinate_source[!x$coordinates_valid] <- "missing_or_invalid"
  x$mapped <- x$included & x$coordinates_valid & x$longitude >= config$bounds['west'] &
    x$longitude <= config$bounds['east'] & x$latitude >= config$bounds['south'] & x$latitude <= config$bounds['north']
  x$mapped[is.na(x$mapped)] <- FALSE
  x$dated_mapped <- x$mapped & !is.na(x$year)
  x$cell_lon <- floor(x$longitude / config$cell_degrees) * config$cell_degrees
  x$cell_lat <- floor(x$latitude / config$cell_degrees) * config$cell_degrees
  x$cell_id <- ifelse(x$mapped, sprintf("%.3f,%.3f", x$cell_lon, x$cell_lat), NA_character_)
  x$period <- ifelse(is.na(x$year), "Undated", ifelse(x$year < config$early_end,
    "Early historical", ifelse(x$year <= config$historical_end, "Late historical", "Later collections")))
  x$availability_flag <- nzchar(x$type_status) | grepl("yes|true", x$depleted, ignore.case = TRUE) |
    grepl("not found|missing specimen", x$notes, ignore.case = TRUE)
  add_display_locations(x, config)
}

sum_groups <- function(x, groups) {
  if (!nrow(x)) {
    result <- x[FALSE, groups, drop = FALSE]
    result$specimens <- numeric(); result$lots <- integer()
    return(result)
  }
  sums <- aggregate(list(specimens = x$specimen_count), x[groups], sum)
  lots <- aggregate(list(lots = x$specimen_count), x[groups], length)
  merge(sums, lots, by = groups, sort = TRUE)
}

summarize_species <- function(records, config) {
  included <- records[records$included, ]
  out <- lapply(split(included, included$species), function(d) {
    yrs <- d$year[!is.na(d$year)]
    n <- sum(d$specimen_count)
    data.frame(species = d$species[1], specimens = n, lots = nrow(d),
      adult_nonlarval = sum(d$specimen_count[d$life_stage == "adult"]),
      larvae = sum(d$specimen_count[d$life_stage == "larva"]),
      mixed = sum(d$specimen_count[d$life_stage == "mixed"]),
      unknown_stage = sum(d$specimen_count[d$life_stage == "unknown"]),
      stage_unrecorded = sum(d$specimen_count[d$stage_evidence == "stage_unrecorded"]),
      mapped_specimens = sum(d$specimen_count[d$mapped]),
      display_mapped_specimens = sum(d$specimen_count[d$display_mapped]),
      approximate_specimens = sum(d$specimen_count[d$coordinate_approximate]),
      approximate_lots = sum(d$coordinate_approximate),
      dated_mapped_specimens = sum(d$specimen_count[d$dated_mapped]),
      undated_specimens = sum(d$specimen_count[is.na(d$year)]),
      historical_specimens = sum(d$specimen_count[!is.na(d$year) & d$year <= config$historical_end]),
      eligibility_specimens = sum(d$specimen_count[!is.na(d$year) & d$year <= config$max_year]),
      largest_lot_fraction = max(d$specimen_count) / n,
      type_specimens = sum(d$specimen_count[nzchar(d$type_status)]),
      availability_flagged_specimens = sum(d$specimen_count[d$availability_flag]),
      unvalidated_taxonomy_specimens = sum(d$specimen_count[d$taxonomy_status == "catalog_binomial_unvalidated"]),
      first_year = if (length(yrs)) min(yrs) else NA_integer_,
      last_year = if (length(yrs)) max(yrs) else NA_integer_,
      sampled_years = length(unique(yrs)), geographic_cells = length(unique(na.omit(d$cell_id))),
      regions = length(unique(d$region)),
      atlantic_specimens = sum(d$specimen_count[d$region == "Atlantic"]),
      caribbean_specimens = sum(d$specimen_count[d$region == "Caribbean"]),
      gulf_specimens = sum(d$specimen_count[d$region == "Gulf of Mexico"]),
      mapped_fraction = sum(d$specimen_count[d$dated_mapped]) / n,
      eligible = sum(d$specimen_count[!is.na(d$year) & d$year <= config$max_year]) >= config$min_specimens)
  })
  if (!length(out)) stop("No included species; inspect input and configuration.")
  out <- do.call(rbind, out)
  out <- out[order(-out$specimens, out$species), ]
  rownames(out) <- NULL
  out
}

build_screening_tables <- function(records, eligible, config) {
  # Availability exclusions apply to screening only, not the museum inventory atlas.
  d <- records[records$dated_mapped & records$species %in% eligible & !records$availability_flag, ]
  cells <- sum_groups(d, c("species", "life_stage", "region", "cell_id", "cell_lon", "cell_lat", "period"))
  # A cell can straddle region labels: combine its counts before temporal matching.
  historic <- sum_groups(d[d$year <= config$historical_end, ],
    c("species", "life_stage", "cell_id", "cell_lon", "cell_lat", "period"))
  historic$region <- vapply(historic$cell_id, function(id) paste(sort(unique(d$region[d$cell_id == id])), collapse = "; "), character(1))
  early <- historic[historic$period == "Early historical", c("species", "life_stage", "cell_id", "specimens")]
  late <- historic[historic$period == "Late historical", c("species", "life_stage", "cell_id", "specimens")]
  repeated <- merge(early, late, by = c("species", "life_stage", "cell_id"), suffixes = c("_early", "_late"))
  repeated$balanced_specimens <- pmin(repeated$specimens_early, repeated$specimens_late)
  repeated <- repeated[repeated$balanced_specimens >= config$min_cell_period_specimens, ]
  repeated <- repeated[order(-repeated$balanced_specimens), ]
  qualified <- historic[historic$specimens >= config$min_cell_period_specimens, ]
  if (nrow(qualified)) {
    assemblages <- do.call(rbind, lapply(split(qualified, interaction(qualified$cell_id, qualified$life_stage, qualified$period, drop = TRUE)), function(z) {
      data.frame(cell_id = z$cell_id[1], cell_lon = z$cell_lon[1], cell_lat = z$cell_lat[1],
        region = paste(sort(unique(z$region)), collapse = "; "), life_stage = z$life_stage[1],
        period = z$period[1], species_count = length(unique(z$species)),
        specimens = sum(z$specimens), species = paste(sort(unique(z$species)), collapse = "; "))
    }))
    assemblages <- assemblages[order(-assemblages$species_count, -assemblages$specimens), ]
  } else assemblages <- data.frame(cell_id = character(), cell_lon = numeric(), cell_lat = numeric(), region = character(), life_stage = character(), period = character(), species_count = integer(), specimens = numeric(), species = character())
  same_year <- sum_groups(d[d$year <= config$historical_end, ],
    c("species", "life_stage", "cell_id", "cell_lon", "cell_lat", "year"))
  same_year <- same_year[same_year$specimens >= config$min_cell_period_specimens, ]
  if (nrow(same_year)) {
    shared_years <- do.call(rbind, lapply(split(same_year, interaction(same_year$cell_id, same_year$life_stage, same_year$year, drop = TRUE)), function(z) {
      data.frame(cell_id = z$cell_id[1], cell_lon = z$cell_lon[1], cell_lat = z$cell_lat[1],
        region = paste(sort(unique(d$region[d$cell_id == z$cell_id[1]])), collapse = "; "),
        life_stage = z$life_stage[1], year = z$year[1], species_count = length(unique(z$species)),
        specimens = sum(z$specimens), species = paste(sort(unique(z$species)), collapse = "; "))
    }))
    shared_years <- shared_years[order(-shared_years$species_count, -shared_years$specimens), ]
  } else shared_years <- data.frame(cell_id = character(), cell_lon = numeric(), cell_lat = numeric(), region = character(), life_stage = character(), year = integer(), species_count = integer(), specimens = numeric(), species = character())
  list(cell_period_sampling = cells, repeated_historical_cells = repeated,
       shared_assemblages = assemblages, shared_year_assemblages = shared_years)
}

stage_label <- function(stage) {
  c(adult = "Adult / non-larval (maturity unverified)", larva = "Larva",
    mixed = "Mixed larvae + non-larvae (unsplit)", unknown = "Unknown life stage")[[stage]]
}

slug <- function(x) gsub("[^A-Za-z0-9]+", "_", x)
palette_counts <- function(n, maximum) {
  colors <- hcl.colors(128, "YlOrRd", rev = TRUE)
  colors[pmax(1L, pmin(128L, 1L + floor(127 * log1p(n) / log1p(maximum))))]
}

draw_map <- function(cells, bounds, maximum, config, title = "", small = FALSE, coast = NULL) {
  par(mar = if (small) c(2.0, 2.2, 2.7, 0.5) else c(3.3, 3.6, 3.4, 0.6),
      bg = "white", fg = "#273442", col.axis = "#526171", col.lab = "#526171")
  aspect <- 1 / cos(mean(bounds[c("south", "north")]) * pi / 180)
  ratio <- (bounds['east'] - bounds['west']) / ((bounds['north'] - bounds['south']) * aspect)
  plot.new()
  size <- par("pin")
  if (size[1] / size[2] > ratio) size[1] <- size[2] * ratio else size[2] <- size[1] / ratio
  par(pin = size)
  plot.window(xlim = bounds[c("west", "east")], ylim = bounds[c("south", "north")],
       xaxs = "i", yaxs = "i", asp = aspect)
  usr <- par("usr")
  clip(usr[1], usr[2], usr[3], usr[4])
  rect(usr[1], usr[3], usr[2], usr[4], col = "#eef5f8", border = NA)
  if (!is.null(coast)) polygon(coast$x, coast$y, col = "#e0e3df", border = "#a9b1b3", lwd = 0.4)
  abline(v = seq(-100, -50, 10), h = seq(0, 60, 10), col = "#d5e1e6", lty = 3, lwd = 0.5)
  if (nrow(cells)) {
    rect(cells$cell_lon, cells$cell_lat, cells$cell_lon + config$cell_degrees,
         cells$cell_lat + config$cell_degrees, col = palette_counts(cells$specimens, maximum),
         border = "#665646", lwd = if (small) 0.4 else 0.65)
    if ("approximate_specimens" %in% names(cells)) {
      a <- cells[cells$approximate_specimens > 0, ]
      if (nrow(a)) rect(a$cell_lon, a$cell_lat, a$cell_lon + config$cell_degrees,
        a$cell_lat + config$cell_degrees, density = 16, angle = 45,
        col = "#23334299", border = NA, lwd = 0.6)
    }
  }
  if (!is.null(coast)) lines(coast$x, coast$y, col = "#839196", lwd = 0.35)
  axis(1, cex.axis = if (small) 0.65 else 0.8); axis(2, las = 1, cex.axis = if (small) 0.65 else 0.8)
  box(col = "#becbd1")
  title(main = title, cex.main = if (small) 0.9 else 1.15, col.main = "#233342", line = 0.8)
  if (!small) title(xlab = "Longitude", ylab = "Latitude", cex.lab = 0.85, line = 2)
  if (!nrow(cells)) text(mean(usr[1:2]), mean(usr[3:4]), "No mapped specimens", col = "#526171", cex = if (small) 0.8 else 1.1)
}

draw_scale <- function(maximum, caption) {
  par(mar = c(0.5, 3, 0.2, 3))
  plot.new(); plot.window(xlim = c(0, 1), ylim = c(0, 1))
  edges <- seq(0, 1, length.out = 129)
  rect(edges[-129], 0.52, edges[-1], 0.76, col = palette_counts(expm1(edges[-129] * log1p(maximum)), maximum), border = NA)
  ticks <- unique(c(1, 5, 10, 25, 50, 100, 250, 500, 1000, maximum))
  ticks <- sort(ticks[ticks <= maximum])
  if (length(ticks) > 7) ticks <- unique(c(ticks[seq(1, length(ticks), by = 2)], maximum))
  text(log1p(ticks) / log1p(maximum), 0.35, labels = ticks, cex = 0.75)
  text(0.5, 0.03, caption, cex = 0.75, col = "#526171")
}

draw_frame <- function(d, cells, years, year, species, stage, maximum, config, coast) {
  layout(rbind(c(1, 1), c(2, 3), c(4, 4), c(5, 5)),
         widths = c(2.2, 1), heights = c(0.7, 6.3, 1.0, 1.5))
  is_unknown <- is.na(year)
  current <- if (is_unknown) d[is.na(d$year), ] else d[!is.na(d$year) & d$year == year, ]
  label <- if (is_unknown) "UNDATED" else as.character(year)
  total <- sum(current$specimen_count)
  mapped <- sum(current$specimen_count[current$mapped])
  approximate <- sum(current$specimen_count[current$coordinate_approximate])
  par(mar = c(0, 1, 0, 1))
  plot.new()
  text(0.5, 0.65, species, font = 3, cex = 1.6, col = "#233342")
  text(0.5, 0.12, stage_label(stage), cex = 1, col = "#526171")
  draw_map(cells, config$bounds, maximum, config, label, coast = coast)
  par(mar = c(1, 0, 1, 1))
  plot.new(); plot.window(xlim = c(0, 1), ylim = c(0, 1))
  text(0, 0.92, label, adj = 0, cex = 2.3, font = 2, col = "#233342")
  summary <- c(sprintf("%s specimens this frame", total), sprintf("%s recorded coordinates", mapped),
    sprintf("%s approximate positions", approximate), sprintf("%s still unmapped", total - mapped - approximate),
    "Hatching = includes estimates", "",
    "RECORDED REGIONS", vapply(c("Atlantic", "Caribbean", "Gulf of Mexico"), function(r)
      sprintf("%s: %s", r, sum(current$specimen_count[current$region == r])), character(1)), "",
    sprintf("%s specimens across years", sum(d$specimen_count[!is.na(d$year)])),
    sprintf("%s undated specimens", sum(d$specimen_count[is.na(d$year)])),
    sprintf("%s recorded years", length(years)))
  text(0, seq(0.79, 0.17, length.out = length(summary)), summary, adj = 0, cex = 0.87, col = "#526171")
  if (!nrow(d)) text(0, 0.07, "No records for this stage", adj = 0, cex = 0.8, col = "#a12d22")
  draw_scale(maximum, sprintf("Specimens per %s-degree cell | log color scale fixed across this species' stages and years", config$cell_degrees))
  par(mar = c(2.2, 3, 1.4, 1))
  if (length(years)) {
    totals <- vapply(years, function(y) sum(d$specimen_count[!is.na(d$year) & d$year == y]), numeric(1))
    yrange <- range(years) + c(-1, 1)
    plot(years, totals, type = "h", lwd = 2, col = "#adbfc6", xlim = yrange, ylim = c(0, max(1, totals)),
      xlab = "", ylab = "", axes = FALSE)
    axis(1, cex.axis = 0.8); axis(2, las = 1, cex.axis = 0.7)
    if (!is_unknown) abline(v = year, col = "#b72924", lwd = 2)
    mtext(if (config$animation_years == "observed") "Collection years only; gaps are skipped. Counts are not population abundance." else "Every calendar year; blank maps mean no recorded sampling.", side = 3, line = 0.2, cex = 0.73)
  } else {
    plot.new(); text(0.5, 0.6, if (!nrow(d)) "No specimens recorded for this stage." else "No securely assigned collection years for this stage.")
  }
}

encode_gif <- function(frames, path, config) {
  binary <- Sys.which("magick")
  if (!nzchar(binary)) binary <- Sys.which("convert")
  if (!nzchar(binary)) stop("Install ImageMagick (magick or convert), or set render_gifs = FALSE.")
  # Each input is a complete frame; no interpolated locations, counts or years.
  args <- c("-limit", "thread", "1", "-delay", as.character(round(config$frame_seconds * 100)),
            "-loop", "0", vapply(frames, shQuote, character(1)),
            "-layers", "Optimize", shQuote(path))
  result <- system2(binary, args, stdout = TRUE, stderr = TRUE)
  status <- attr(result, "status")
  if ((!is.null(status) && status != 0) || !file.exists(path)) stop("GIF encoding failed: ", paste(result, collapse = "\n"))
}

render_species_stage <- function(d, species, stage, maximum, config, coast) {
  out <- file.path(config$output, "species", slug(species))
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  base <- file.path(out, stage)
  years <- sort(unique(na.omit(d$year)))
  inventory <- geographic_frame_inventory(d, species, stage, config)
  cycle <- inventory$year
  frames <- file.path(config$output, inventory$png)
  dir.create(dirname(frames[1]), recursive = TRUE, showWarnings = FALSE)
  cells_for_year <- function(y) {
    current <- if (is.na(y)) d[is.na(d$year), ] else d[!is.na(d$year) & d$year == y, ]
    display_cell_counts(current)
  }
  # Per-year faceted maps, six panels per PDF page, including an undated panel.
  pdf(paste0(base, "_annual_maps.pdf"), width = 12, height = 10, onefile = TRUE)
  for (start in seq(1, length(cycle), by = 6)) {
    par(mfrow = c(2, 3), oma = c(2.5, 0, 3.5, 0))
    for (i in start:min(start + 5, length(cycle))) {
      cells <- cells_for_year(cycle[i])
      draw_map(cells, config$bounds, maximum, config,
        sprintf("%s | %s mapped specimens", if (is.na(cycle[i])) "Undated" else cycle[i], sum(cells$specimens)), TRUE, coast)
    }
    for (unused in seq_len(6 - min(6, length(cycle) - start + 1))) { plot.new() }
    mtext(paste(species, "|", stage_label(stage)), outer = TRUE, side = 3, line = 1.2, cex = 1.2, font = 2)
    ticks <- unique(pmin(c(1, 10, 50, 100, maximum), maximum))
    legend("bottom", legend = ticks, fill = palette_counts(ticks, maximum), horiz = TRUE, bty = "n", xpd = NA, cex = 0.8, inset = c(0, -0.12))
    mtext(sprintf("Specimens per %s-degree cell; fixed log colors (1-%s). Hatching = includes approximate locations. Blank = no plotted sampling.", config$cell_degrees, maximum), outer = TRUE, side = 1, line = 1, cex = 0.75)
  }
  dev.off()
  for (i in seq_along(cycle)) {
    png(frames[i], width = config$width, height = config$height, res = 105, type = "cairo")
    draw_frame(d, cells_for_year(cycle[i]), years, cycle[i], species, stage, maximum, config, coast)
    dev.off()
  }
  file.copy(frames[1], paste0(base, "_preview.png"), overwrite = TRUE)
  if (config$render_gifs) encode_gif(frames, paste0(base, ".gif"), config)
  write.csv(inventory, paste0(base, "_frames.csv"), row.names = FALSE, na = "")
  data.frame(species = species, life_stage = stage, specimens = sum(d$specimen_count),
    mapped_specimens = sum(d$specimen_count[d$mapped]), sampled_years = length(years),
    approximate_specimens = sum(d$specimen_count[d$coordinate_approximate]),
    display_mapped_specimens = sum(d$specimen_count[d$display_mapped]),
    frames = if (config$render_gifs) length(cycle) else 0L,
    status = if (!nrow(d)) "no_stage_records" else if (!any(d$mapped)) "no_recorded_coordinates" else "rendered",
    gif = if (config$render_gifs) file.path("species", slug(species), paste0(stage, ".gif")) else "",
    pdf = file.path("species", slug(species), paste0(stage, "_annual_maps.pdf")),
    preview = file.path("species", slug(species), paste0(stage, "_preview.png")))
}

render_sampling_matrix <- function(d, species, config) {
  d <- d[d$mapped, ]
  path <- file.path(config$output, "species", slug(species), "sampling_matrix.pdf")
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  pdf(path, width = 14, height = 9)
  if (!nrow(d)) {
    plot.new(); title(species); text(0.5, 0.5, "No recorded coordinates available for geographic cell-by-year heatmap.")
    dev.off()
    return(path)
  }
  for (stage in unique(c("adult", "larva", sort(unique(d$life_stage))))) {
    s <- d[d$life_stage == stage, ]
    if (!nrow(s)) next
    s$year_label <- ifelse(is.na(s$year), "Undated", as.character(s$year))
    counts <- sum_groups(s, c("cell_id", "cell_lat", "cell_lon", "year_label"))
    cells <- unique(counts[c("cell_id", "cell_lat", "cell_lon")])
    cells <- cells[order(cells$cell_lat, cells$cell_lon), ]
    yr <- sort(unique(na.omit(s$year)))
    # Full annual spacing exposes long temporal gaps; undated goes at the right.
    labels <- if (length(yr)) as.character(seq(min(yr), max(yr))) else character()
    if (anyNA(s$year)) labels <- c(labels, "Undated")
    maximum <- max(counts$specimens)
    for (start in seq(1, nrow(cells), by = 35)) {
      subset <- cells[start:min(start + 34, nrow(cells)), ]
      par(mar = c(5, 9, 4, 2))
      plot(NA, xlim = c(0.5, length(labels) + 0.5), ylim = c(0.5, nrow(subset) + 0.5),
        xaxs = "i", yaxs = "i", axes = FALSE, xlab = "Collection year (full calendar spacing)", ylab = "",
        main = paste(species, "|", stage_label(stage)))
      rect(0.5, 0.5, length(labels) + 0.5, nrow(subset) + 0.5, col = "#eff2f4", border = NA)
      idx <- match(counts$cell_id, subset$cell_id)
      keep <- !is.na(idx)
      cx <- match(counts$year_label[keep], labels); cy <- idx[keep]
      rect(cx - 0.5, cy - 0.5, cx + 0.5, cy + 0.5, col = palette_counts(counts$specimens[keep], maximum), border = NA)
      at <- unique(round(seq(1, length(labels), length.out = min(12, length(labels)))))
      axis(1, at = at, labels = labels[at], las = 2, cex.axis = 0.8)
      axis(2, at = seq_len(nrow(subset)), labels = sprintf("%g W / %g N", -subset$cell_lon, subset$cell_lat), las = 1, cex.axis = 0.7)
      ticks <- sort(unique(pmin(c(1, 5, 10, 50, 100, maximum), maximum)))
      legend("topright", legend = ticks, fill = palette_counts(ticks, maximum), horiz = TRUE, bty = "n", cex = 0.75, inset = c(0, -0.10), xpd = NA)
      mtext(sprintf("Cell labels are southwest corners (%s-degree grid). Gray = no recorded sampling; counts are not density. Scale fixed within stage.", config$cell_degrees), side = 1, line = 4, cex = 0.75)
    }
  }
  dev.off()
  path
}

html_escape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  gsub('"', "&quot;", x, fixed = TRUE)
}

# Keep report/UI changes separate from the scientific transformations.
source("Scripts/sampling_atlas_locations.R")
source("Scripts/sampling_atlas_report.R")
