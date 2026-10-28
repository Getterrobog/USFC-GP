# All-year, all-stage maps from the saved atlas audit; no location re-estimation.
overview_cell_summary <- function(records, species) {
  d <- records[records$included & records$species %in% species, ]
  cells <- display_cell_counts(d, "species")
  cells <- cells[order(match(cells$species, species), -cells$cell_lat, cells$cell_lon), ]
  cells$cell_label <- character(nrow(cells))
  cells$years <- character(nrow(cells))
  cells$year_specimens <- character(nrow(cells))
  cells$undated_specimens <- numeric(nrow(cells))
  for (sp in species) {
    idx <- which(cells$species == sp)
    cells$cell_label[idx] <- sprintf("%02d", seq_along(idx))
    for (i in idx) {
      z <- d[d$species == sp & d$display_mapped & d$display_cell_id == cells$cell_id[i], ]
      years <- sort(unique(z$year[!is.na(z$year)]))
      cells$years[i] <- paste(years, collapse = ";")
      cells$year_specimens[i] <- paste(vapply(years, function(year)
        sum(z$specimen_count[!is.na(z$year) & z$year == year]), numeric(1)), collapse = ";")
      cells$undated_specimens[i] <- sum(z$specimen_count[is.na(z$year)])
    }
  }
  rownames(cells) <- NULL
  cells
}

overview_year_label <- function(years, undated, year_specimens) {
  parts <- if (nzchar(years)) strsplit(years, ";", fixed = TRUE)[[1]] else character()
  counts <- if (nzchar(year_specimens)) strsplit(as.character(year_specimens), ";", fixed = TRUE)[[1]] else character()
  stopifnot(length(parts) == length(counts))
  if (length(parts)) parts <- paste0(parts, " (", counts, ")")
  if (undated > 0) parts <- c(parts, paste0("Undated (", undated, ")"))
  paste(parts, collapse = ", ")
}

# Wrap between year/count pairs, never between a year and its specimen count.
overview_wrap_year_label <- function(label, width = 36) {
  lines <- character(); current <- ""
  for (part in strsplit(label, ", ", fixed = TRUE)[[1]]) {
    candidate <- if (nzchar(current)) paste(current, part, sep = ", ") else part
    if (nzchar(current) && nchar(candidate) > width) {
      lines <- c(lines, paste0(current, ",")); current <- part
    } else current <- candidate
  }
  c(lines, current)
}

# Keep the north-to-south label ordering while separating multiline callouts.
overview_label_positions <- function(desired, heights, top, bottom, gap = 7) {
  if (!length(desired)) return(numeric())
  if (sum(heights) + gap * (length(heights) - 1) > bottom - top)
    stop("Too many year labels to fit the overview map; increase its fixed canvas height.")
  y <- desired - heights / 2
  y[1] <- max(top, y[1])
  if (length(y) > 1) for (i in 2:length(y)) y[i] <- max(y[i], y[i - 1] + heights[i - 1] + gap)
  y[length(y)] <- min(y[length(y)], bottom - tail(heights, 1))
  if (length(y) > 1) for (i in (length(y) - 1):1) y[i] <- min(y[i], y[i + 1] - heights[i] - gap)
  stopifnot(min(y) >= top, max(y + heights) <= bottom)
  y
}

write_overview_svg <- function(cells, records, species, config, coast, path) {
  # Every species uses this same canvas and geographic transform.
  left <- 70; top <- 105; map_width <- 740
  b <- config$bounds
  aspect <- 1 / cos(mean(b[c("south", "north")]) * pi / 180)
  map_height <- map_width * (b['north'] - b['south']) * aspect / (b['east'] - b['west'])
  right <- left + map_width; bottom <- top + map_height
  px <- function(lon) left + (lon - b['west']) / (b['east'] - b['west']) * map_width
  py <- function(lat) top + (b['north'] - lat) / (b['north'] - b['south']) * map_height
  text_svg <- function(x, y, label, size = 16, extra = "") sprintf(
    '<text x="%.2f" y="%.2f" font-size="%s" %s>%s</text>', x, y, size, extra, html_escape(label))
  years <- vapply(seq_len(nrow(cells)), function(i) overview_year_label(cells$years[i], cells$undated_specimens[i], cells$year_specimens[i]), character(1))
  labels <- lapply(years, overview_wrap_year_label)
  label_heights <- pmax(22, lengths(labels) * 20)
  cx <- px(cells$cell_lon + config$cell_degrees / 2)
  cy <- py(cells$cell_lat + config$cell_degrees / 2)
  label_y <- overview_label_positions(cy, label_heights, top + 8, bottom - 8)
  total <- sum(records$specimen_count)
  mapped <- sum(cells$specimens)
  maximum <- max(1, cells$specimens)
  lines <- c('<?xml version="1.0" encoding="UTF-8"?>',
    '<svg xmlns="http://www.w3.org/2000/svg" width="1250" height="1220" viewBox="0 0 1250 1220" role="img" aria-labelledby="title description">',
    sprintf('<title id="title">%s — all years and life stages</title>', html_escape(species)),
    '<desc id="description">Geographic specimen-count heatmap. Numbered grid cells connect to collection-year labels with specimen counts in parentheses for each cell and year. Hatched cells include approximate positions; Undated marks specimens without an assigned year.</desc>',
    '<style>text{font-family:Arial,sans-serif;fill:#233342}.cell-number{font-weight:bold;paint-order:stroke;stroke:white;stroke-width:3px;stroke-linejoin:round}</style>',
    sprintf('<defs><clipPath id="extent"><rect x="%s" y="%s" width="%s" height="%.2f"/></clipPath><pattern id="estimated" width="8" height="8" patternUnits="userSpaceOnUse"><path d="M-2 2L2-2M0 8L8 0M6 10L10 6" stroke="#233342" stroke-opacity=".45" stroke-width="1"/></pattern></defs>', left, top, map_width, map_height),
    '<rect width="1250" height="1220" fill="white"/>',
    text_svg(left, 35, species, 25, 'font-style="italic"'),
    text_svg(left, 62, sprintf("All years and stages · %s specimens · %s plotted · %s without a usable location", total, mapped, total - mapped), 17),
    text_svg(left, 85, sprintf("%s recorded-coordinate specimens + %s approximate positions plotted; labels list collection years", sum(cells$recorded_specimens), sum(cells$approximate_specimens)), 15),
    text_svg(855, 85, "Cell · Year (specimens)", 17, 'font-weight="bold"'),
    sprintf('<rect x="%s" y="%s" width="%s" height="%.2f" fill="#eef5f8" stroke="#a9b1b3"/>', left, top, map_width, map_height),
    '<g clip-path="url(#extent)">')
  pieces <- split(seq_along(coast$x), cumsum(is.na(coast$x)))
  for (idx in pieces) {
    idx <- idx[!is.na(coast$x[idx]) & !is.na(coast$y[idx])]
    if (length(idx) < 3) next
    coords <- paste(sprintf("%.2f,%.2f", px(coast$x[idx]), py(coast$y[idx])), collapse = " ")
    lines <- c(lines, sprintf('<polygon points="%s" fill="#e0e3df" stroke="#839196" stroke-width=".6"/>', coords))
  }
  for (lon in seq(ceiling(b['west'] / 10) * 10, b['east'], 10)) lines <- c(lines,
    sprintf('<path d="M%.2f %sV%.2f" stroke="#cad9df" stroke-dasharray="3 5"/>', px(lon), top, bottom))
  for (lat in seq(ceiling(b['south'] / 10) * 10, b['north'], 10)) lines <- c(lines,
    sprintf('<path d="M%s %.2fH%s" stroke="#cad9df" stroke-dasharray="3 5"/>', left, py(lat), right))
  lines <- c(lines, '</g>')
  for (i in seq_len(nrow(cells))) {
    mid <- label_y[i] + label_heights[i] / 2
    lines <- c(lines, sprintf('<path d="M%.2f %.2fL830 %.2fH850" fill="none" stroke="#7893a2" stroke-opacity=".65" stroke-width="1"/>', cx[i], cy[i], mid))
  }
  lines <- c(lines, '<g clip-path="url(#extent)">')
  for (i in seq_len(nrow(cells))) {
    x <- px(cells$cell_lon[i]); y <- py(cells$cell_lat[i] + config$cell_degrees)
    width <- px(cells$cell_lon[i] + config$cell_degrees) - x
    height <- py(cells$cell_lat[i]) - y
    lines <- c(lines, sprintf('<g class="sample-cell" data-cell="%s"><title>Cell %s: %s specimens; years %s</title><rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" fill="%s" stroke="#665646"/>',
      cells$cell_label[i], cells$cell_label[i], cells$specimens[i], html_escape(years[i]), x, y, width, height, palette_counts(cells$specimens[i], maximum)))
    if (cells$approximate_specimens[i] > 0) lines <- c(lines, sprintf('<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" fill="url(#estimated)"/>', x, y, width, height))
    lines <- c(lines, text_svg(cx[i], cy[i] + 4, cells$cell_label[i], 12, 'class="cell-number" text-anchor="middle"'), '</g>')
  }
  lines <- c(lines, '</g>')
  for (i in seq_len(nrow(cells))) {
    lines <- c(lines, sprintf('<g class="year-label" data-cell="%s">', cells$cell_label[i]),
      text_svg(855, label_y[i] + 16, cells$cell_label[i], 15, 'font-weight="bold"'))
    for (j in seq_along(labels[[i]])) lines <- c(lines, text_svg(887, label_y[i] + 16 + (j - 1) * 20, labels[[i]][j], 16))
    lines <- c(lines, '</g>')
  }
  if (!nrow(cells)) lines <- c(lines, text_svg(left + map_width / 2, top + map_height / 2,
    "No specimens have usable display locations", 19, 'text-anchor="middle"'))
  for (lon in seq(ceiling(b['west'] / 10) * 10, b['east'], 10)) lines <- c(lines,
    text_svg(px(lon), bottom + 23, paste0(abs(lon), "°W"), 14, 'text-anchor="middle"'))
  for (lat in seq(ceiling(b['south'] / 10) * 10, b['north'], 10)) lines <- c(lines,
    text_svg(left - 12, py(lat) + 5, paste0(lat, "°N"), 14, 'text-anchor="end"'))
  legend_y <- bottom + 49
  edges <- seq(0, 1, length.out = 129)
  for (i in 1:128) lines <- c(lines, sprintf('<rect x="%.2f" y="%.2f" width="%.2f" height="14" fill="%s"/>',
    left + edges[i] * map_width, legend_y, map_width / 128 + 0.1, palette_counts(expm1(edges[i] * log1p(maximum)), maximum)))
  ticks <- sort(unique(c(1, 10, 100, maximum))); ticks <- ticks[ticks <= maximum]
  for (n in ticks) lines <- c(lines, text_svg(left + log1p(n) / log1p(maximum) * map_width, legend_y + 33, n, 14, 'text-anchor="middle"'))
  lines <- c(lines, text_svg(left, legend_y + 58, sprintf("Specimens per %s° × %s° cell · log color scale · colors are scaled separately for each species", config$cell_degrees, config$cell_degrees), 15),
    text_svg(left, legend_y + 80, "Hatching includes approximate locations. Blank cells indicate no plotted sampling, not biological absence.", 15), '</svg>')
  writeLines(lines, path, useBytes = TRUE)
}

atlas_overview_card_html <- function(species, overview) {
  m <- overview$manifest[overview$manifest$species == species, ]
  cells <- overview$cells[overview$cells$species == species, ]
  lines <- c('<section class="species-overview"><h3>All years and life stages</h3>',
    sprintf('<p>%s specimens plotted in %s grid cells · %s specimens without a usable location. Parentheses give specimens for that cell and year, including Undated where present.</p>', m$display_mapped_specimens, m$cells, m$unmapped_specimens),
    '<button class="overview-zoom" type="button" aria-pressed="false">Enlarge labels</button>',
    sprintf('<div class="overview-viewport" tabindex="0" role="region" aria-label="Scrollable all-year map for %s"><img class="overview-map" loading="lazy" width="1250" height="1220" src="%s" alt="%s: all-year specimen heatmap with collection-year callouts for each numbered grid cell"></div><p><a href="%s">Open full-size map (SVG)</a></p>', html_escape(species), m$svg, html_escape(species), m$svg),
    '<details><summary>Grid-cell years and counts</summary><div class="overview-table"><table><thead><tr><th>Cell</th><th>Longitude / latitude bounds</th><th>Year (specimens)</th><th>Specimens</th><th>Approximate</th></tr></thead><tbody>')
  for (i in seq_len(nrow(cells))) {
    z <- cells[i, ]
    lines <- c(lines, sprintf('<tr><th scope="row">%s</th><td>%g to %g° lon; %g to %g° lat</td><td>%s</td><td>%s</td><td>%s</td></tr>', z$cell_label, z$cell_lon, z$cell_lon + m$cell_degrees, z$cell_lat, z$cell_lat + m$cell_degrees,
      html_escape(overview_year_label(z$years, z$undated_specimens, z$year_specimens)), z$specimens, z$approximate_specimens))
  }
  c(lines, '</tbody></table></div></details></section>')
}
