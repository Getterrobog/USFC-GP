# I. Create Species_table.pdf
# A. Temporal Filtering for Species Table using mapply over Date.Collected and Vessel
filter_table_by_year <- TRUE
max_table_year       <- 1947

Populations_table_input <- Populations %>%
  mutate(
    Extracted_Year = mapply(extract_collection_year, Date.Collected, Vessel)
  ) %>%
  filter(
    if (filter_table_by_year) {
      is.na(Extracted_Year) | Extracted_Year <= max_table_year
    } else {
      TRUE
    }
  )
# B. Extract species name from Populations.by.species
Populations_table_input$Valid.Name <- sub("^Population \\d+ of ", "", Populations_table_input$Populations.by.species)
Populations_table_input$Valid.Name <- trimws(Populations_table_input$Valid.Name)
Populations_table_input$Valid.Name <- gsub("\\.$", "", Populations_table_input$Valid.Name)

# C. Ensure numeric data types for spatial processing using actual column names
Populations_table_input$Centroid.Longitude <- as.numeric(as.character(Populations_table_input$Centroid.Longitude))
Populations_table_input$Centroid.Latitude  <- as.numeric(as.character(Populations_table_input$Centroid.Latitude))

# D. Map total qualifying populations per species (post-filter)
sp_pop_counts <- tapply(Populations_table_input$Populations.by.species, Populations_table_input$Valid.Name, function(x) length(unique(x)))

# E. Compute true maximum pairwise spatial distance (in km) across ALL lots for each species
sp_max_distance <- tapply(seq_len(nrow(Populations_table_input)), Populations_table_input$Valid.Name, function(idx) {
  sub_df <- Populations_table_input[idx, c("Centroid.Longitude", "Centroid.Latitude")]
  coords <- unique(sub_df[complete.cases(sub_df), , drop = FALSE])
  if (nrow(coords) < 2) return(0)
  dist_matrix <- geosphere::distm(as.matrix(coords[, c("Centroid.Longitude", "Centroid.Latitude")]), fun = geosphere::distHaversine)
  return(round(max(dist_matrix, na.rm = TRUE) / 1000, 2))
})

# F. Compute temporal range (in years) across ALL lots for each species
sp_temp_range <- tapply(Populations_table_input$Extracted_Year, Populations_table_input$Valid.Name, function(years) {
  valid_years <- years[!is.na(years)]
  if (length(valid_years) == 0) return("UNDATED")
  return(sprintf("%.1f", max(valid_years) - min(valid_years)))
})

# G. Vector Mapping Steps
sp_max_dist_vec  <- unname(sp_max_distance[Populations_table_input$Valid.Name])
sp_temp_rang_vec <- unname(sp_temp_range[Populations_table_input$Valid.Name])
sp_total_specs   <- ave(Populations_table_input$Specimen.Count, Populations_table_input$Valid.Name, FUN = function(x) sum(x, na.rm = TRUE))

# H. Construct final data.frame from retained populations
Species_table <- data.frame(
  Valid.Name               = Populations_table_input$Valid.Name,
  Specimen.Count           = Populations_table_input$Specimen.Count,
  Lot                      = Populations_table_input$Catalog.Number...USNM,
  Total_Populations_40km_r = unname(sp_pop_counts[Populations_table_input$Valid.Name]),
  Spatial.distance         = sp_max_dist_vec,
  Temporal.range           = sp_temp_rang_vec,
  sp_total_specs           = sp_total_specs,
  stringsAsFactors         = FALSE
)

# I. Hierarchical species and lot sorting
Species_table <- Species_table[order(
  -Species_table$Total_Populations_40km_r, 
  -Species_table$sp_total_specs,
  Species_table$Valid.Name, 
  -Species_table$Specimen.Count
), ]

# J. Drop helper vector
Species_table$sp_total_specs <- NULL

# K. Blank out species-level metrics for duplicate species lot rows (retaining values on row 1 only)
dup_mask <- duplicated(Species_table$Valid.Name)

Species_table$Total_Populations_40km_r[dup_mask] <- ""
Species_table$Spatial.distance[dup_mask]         <- ""
Species_table$Temporal.range[dup_mask]           <- ""

# L. Convert numeric metrics to character for clean rendering prior to CSV / PDF write
Species_table$Total_Populations_40km_r <- as.character(Species_table$Total_Populations_40km_r)
Species_table$Spatial.distance         <- as.character(Species_table$Spatial.distance)
Species_table$Temporal.range           <- as.character(Species_table$Temporal.range)

# M. Apply requested PDF display column headers (using "Span (yr)")
colnames(Species_table) <- c(
  "Species",
  "Specimens",
  "Lot #",
  "Pops. (40 km R)",
  "Range (km)",
  "Span (yr)"
)

write.csv(Species_table, "./Output/Files/Species_table.csv", row.names = FALSE)

# N. PDF Table Rendering (1-Inch Header and Footer Margins)
page_width     <- 8.5
page_height    <- 11
top_margin     <- 1.0
bot_margin     <- 1.0
content_height <- page_height - top_margin - bot_margin

table_theme <- ttheme_default(
  core = list(
    bg_params = list(fill = c("white", "grey95")),
    fg_params = list(fontsize = 7),
    border    = list(col = "black", lwd = 0.5)
  ),
  colhead = list(
    bg_params = list(fill = "grey80"),
    fg_params = list(fontsize = 8, fontface = "bold"),
    border    = list(col = "black", lwd = 1)
  )
)

rows_per_page <- 25
total_rows    <- nrow(Species_table)
total_pages   <- ceiling(total_rows / rows_per_page)

pdf("./Output/Figures/Species_table.pdf", width = page_width, height = page_height)

for (p in seq_len(total_pages)) {
  start_idx <- (p - 1) * rows_per_page + 1
  end_idx   <- min(p * rows_per_page, total_rows)
  
  sub_table <- Species_table[start_idx:end_idx, ]
  g <- tableGrob(sub_table, theme = table_theme, rows = NULL)
  g$heights <- unit(rep(1 / nrow(g), nrow(g)), "npc")
  
  grid.newpage()
  
  vp <- viewport(
    x      = unit(0.5, "npc"),
    y      = unit(bot_margin, "inches"),
    width  = unit(0.9, "npc"),
    height = unit(content_height, "inches"),
    just   = c("center", "bottom")
  )
  
  pushViewport(vp)
  grid.draw(g)
  popViewport()
}

dev.off()

# II. Construct Species-Level Summary Data Frame (1 Row Per Species)

# A.Extract canonical list of unique species present in filtered dataset
unique_species <- sort(unique(Populations_table_input$Valid.Name))

# B. Aggregate specimen counts across all retained populations
sp_total_specimens <- tapply(
  Populations_table_input$Specimen.Count, 
  Populations_table_input$Valid.Name, 
  sum, 
  na.rm = TRUE
)

# C. Safe lookup function for common names (handles unmapped species and empty cells)
get_common_name <- function(sp_name, ref_df) {
  if (!"Valid_Name" %in% colnames(ref_df) || !"Common_name" %in% colnames(ref_df)) return("")
  idx <- match(sp_name, ref_df$Valid_Name)
  if (is.na(idx)) return("")
  val <- ref_df$Common_name[idx]
  if (is.na(val) || trimws(as.character(val)) == "") return("")
  return(as.character(val))
}

# Apply lookup across all target species
matched_common_names <- sapply(unique_species, get_common_name, ref_df = Valid_species, USE.NAMES = FALSE)

# Safely extract metrics using exact vector name matching
val_pops  <- as.numeric(sp_pop_counts[unique_species])
val_range <- as.numeric(sp_max_distance[unique_species])
val_span  <- as.character(sp_temp_range[unique_species])
val_specs <- as.numeric(sp_total_specimens[unique_species])

Species_summary_table <- data.frame(
  Species           = unique_species,
  Common_Name       = matched_common_names,
  Total_Populations = val_pops,
  Range_km          = val_range,
  Span_yr           = val_span,
  Total_Specimens   = val_specs,
  stringsAsFactors  = FALSE
)

# Hierarchical species sorting: Total Populations (desc), Total Specimens (desc), Species Name (asc)
Species_summary_table <- Species_summary_table[order(
  -Species_summary_table$Total_Populations,
  -Species_summary_table$Total_Specimens,
  Species_summary_table$Species
), ]

# Drop helper sorting column
Species_summary_table$Total_Specimens <- NULL

# Format numeric metrics to character for tableGrob rendering
Species_summary_table$Total_Populations <- as.character(Species_summary_table$Total_Populations)
Species_summary_table$Range_km          <- as.character(Species_summary_table$Range_km)

# Apply PDF display column headers
colnames(Species_summary_table) <- c(
  "Species",
  "Common Name",
  "Total Pops",
  "Range (km)",
  "Span (yr)"
)

write.csv(Species_summary_table, "./Output/Files/Species_summary_table.csv", row.names = FALSE)

# K. Render Summary PDF Table (Matching Page Layout)

total_summary_rows  <- nrow(Species_summary_table)
total_summary_pages <- ceiling(total_summary_rows / rows_per_page)

pdf("./Output/Figures/Species_summary_table.pdf", width = page_width, height = page_height)

for (p in seq_len(total_summary_pages)) {
  start_idx <- (p - 1) * rows_per_page + 1
  end_idx   <- min(p * rows_per_page, total_summary_rows)
  
  sub_table <- Species_summary_table[start_idx:end_idx, ]
  g <- tableGrob(sub_table, theme = table_theme, rows = NULL)
  g$heights <- unit(rep(1 / nrow(g), nrow(g)), "npc")
  
  grid.newpage()
  
  vp <- viewport(
    x      = unit(0.5, "npc"),
    y      = unit(bot_margin, "inches"),
    width  = unit(0.9, "npc"),
    height = unit(content_height, "inches"),
    just   = c("center", "bottom")
  )
  
  pushViewport(vp)
  grid.draw(g)
  popViewport()
}

dev.off()

# End of Script