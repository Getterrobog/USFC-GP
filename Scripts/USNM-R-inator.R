# USNM-R-inator.R The purpose of this script is to analyze and process USNM collections data to:
# • Add valid names from Eschmeyer's catalog of fishes
# • species_checkinator.py must:
# - be given permissions ("chmod u+x species_checkinator.py")
# - be placed in the active R working directory OR in a directory listed in your shell initialization script
#  - example: export PATH="$PATH:$HOME/[dir_containing_script]"
# • use data from the file as a dictionary to fill in centroids and missing dates if possible un the assumptions
# - that samples collected by the same ship on the same date occurred close to each other
# - that samples collected by the same ship on the same close to each other share the same date
# It will handle a *.csv file downloaded from https://collections.nmnh.si.edu/search/fishes/
# Author: Iván R. López Martínez. 10 Sep 2026.
# email: ivan.r.lopez@hotmail.com
# I used R version 4.6.1 (2026-06-24) -- "Happy Hop"
# I used Gemini AI to troubleshoot.
# Save your original USNM.csv file prior to processing and do not modify it.
# In your working Directory create the following directory structure:
# Data/ (place the USNM.csv here)
# Output/Figures
# Output/Files
# Scripts/ (place your R script here.)
# 0. Setup Environment and Load Data
setwd("/Users/ivanlopez/OneDrive - University of Central Florida/USFCGP/R-USFCGP/")

library(geosphere)
library(ggplot2)
library(dplyr)
library(stringr)
library(tibble)
library(gridExtra)
library(grid)

Fish <- read.csv("./Data/All_collections.csv", stringsAsFactors = FALSE, encoding = "UTF-8-BOM")
original_row_count <- nrow(Fish)

# I. Prepare file for processing
# A. Add Valid.Name column
Fish <- Fish %>%
  add_column(Valid.Name = "", Name.Cleaned = "", .after = "Specimen.Count") %>%
  add_column(Date.ISO.8601 = "", .after = "Subfamily") %>%
  mutate(Vessel = if_else(Vessel == "Gampus (Bache)", "Grampus", Vessel))
  

# B. Remove regex problems from species and mark species with no identification
# 1. Trim leading and trailing whitespace
id_trim <- trimws(Fish$Identification)

# 2. Evaluate conditions for invalid/incomplete species identifications
cond_question <- grepl("\\?", id_trim)
cond_no_space <- !grepl(" ", id_trim)
cond_cf       <- grepl(" cf\\. ", id_trim, fixed = FALSE)

# 3. Combined boolean vector for "No species ID"
invalid_idx <- cond_question | cond_no_space | cond_cf

# a. Extract first two words (Genus species) using regular expressions
cleaned_names <- sub("^(\\S+\\s+\\S+).*", "\\1", id_trim)

# b. Assign "No species ID" where conditions are met
cleaned_names[invalid_idx] <- "No species ID"

# d. Output to Name.Cleaned column
Fish$Name.Cleaned <- cleaned_names

# e. Clean parenthetical artifacts and parse Date.Collected into Date.ISO.8601
# 1. Pre-clean strings by removing parenthetical metadata and date-range extensions
date_clean <- trimws(Fish$Date.Collected)
date_clean <- gsub("\\s*\\(.*$", "", date_clean)
date_clean <- gsub("\\s+to\\s+.*$", "", date_clean, ignore.case = TRUE)
date_clean <- trimws(date_clean)

# Lookup map for 3-letter month abbreviations
months_map <- setNames(sprintf("%02d", 1:12), 
                       c("Jan", "Feb", "Mar", "Apr", "May", "Jun", 
                         "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"))

# Helper function to parse ISO 8601 dates without lubridate evaluation warnings
parse_iso_date <- function(x) {
  if (is.na(x) || x == "") return("")
  
  # a. Parse DD-MMM-YY (assigns century based on two-digit year threshold)
  if (str_detect(x, "^\\d{1,2}-[A-Za-z]{3}-\\d{2}$")) {
    parts <- unlist(strsplit(x, "-"))
    day <- sprintf("%02d", as.integer(parts[1]))
    mon_key <- paste0(toupper(substr(parts[2], 1, 1)), tolower(substr(parts[2], 2, 3)))
    mon <- months_map[mon_key]
    yr_two <- as.integer(parts[3])
    yr <- if (yr_two >= 80) paste0("18", parts[3]) else paste0("19", parts[3])
    return(paste(yr, mon, day, sep = "-"))
  }
  
  # b. Parse full DD MMM YYYY -> YYYY-MM-DD
  if (str_detect(x, "^\\d{1,2}\\s+[A-Za-z]{3}\\s+\\d{4}$")) {
    parts <- unlist(strsplit(x, "\\s+"))
    day <- sprintf("%02d", as.integer(parts[1]))
    mon_key <- paste0(toupper(substr(parts[2], 1, 1)), tolower(substr(parts[2], 2, 3)))
    mon <- months_map[mon_key]
    return(paste(parts[3], mon, day, sep = "-"))
  }
  
  # c. Parse partial MMM YYYY -> YYYY-MM
  if (str_detect(x, "^[A-Za-z]{3}\\s+\\d{4}$")) {
    parts <- unlist(strsplit(x, "\\s+"))
    mon_key <- paste0(toupper(substr(parts[1], 1, 1)), tolower(substr(parts[1], 2, 3)))
    mon <- months_map[mon_key]
    return(paste(parts[2], mon, sep = "-"))
  }
  
  # d. Parse standalone YYYY -> YYYY
  if (str_detect(x, "^\\d{4}$")) {
    return(x)
  }
  
  # e. Fallback: extract standalone 4-digit year if extraneous text remains
  yr_match <- str_extract(x, "\\b(18|19|20)\\d{2}\\b")
  if (!is.na(yr_match)) {
    return(yr_match)
  }
  
  return("")
}

# 2. Vectorized application across dataset
Fish$Date.ISO.8601 <- sapply(date_clean, parse_iso_date, USE.NAMES = FALSE)

# Run PRfixinator.R.  If you are not using this specific dataset you do not need
# this script.  I am an experienced naval navigator.  I used orginal logs to correct
# plotted positions.  Because I am not expecting my mail box to blow up: if you would
# like help processing historical data or acquiring it, contact me via email.

# C. Kick out bad rows, keep good rows
# Bad rows images, Null or 0 number of specimens, No species ID label, not a fish order,
# no Holotype etc. label, no larval lots
Fish_kicked <- Fish[Fish$Kind.of.Object == "Image" |
                      is.na(Fish$Specimen.Count) |
                      Fish$Specimen.Count == 0 |
                      Fish$Name.Cleaned == "No species ID" |
                      Fish$Order == "Amphioxiformes" |
                      Fish$Type.Status != "" |
                      startsWith(as.character(Fish$Preparation.Details..Preparation.Location.Count.), "Larvae:"), ]

Fish <- Fish[Fish$Kind.of.Object != "Image" &
               !is.na(Fish$Specimen.Count) &
               Fish$Specimen.Count != 0 &
               Fish$Name.Cleaned != "No species ID" &
               Fish$Order != "Amphioxiformes" &
               Fish$Type.Status == "" &
               !startsWith(as.character(Fish$Preparation.Details..Preparation.Location.Count.), "Larvae:"), ]

# D. Make unique species names list and write out to file
writeLines(sort(unique(Fish$Name.Cleaned)), con = "species_list.txt")

# E. Run Python script
system2("/Users/ivanlopez/Scripts/species_checkinator.py")
# 1. Add the variable
Valid_species <- read.csv("species_validation_results.csv", stringsAsFactors = FALSE, encoding = "UTF-8")
# 2. Move the files to Output Files
file.rename(from = "species_list.txt", to = "./Output/Files/species_list.txt")
file.rename(from = "species_validation_results.csv", to = "./Output/Files/species_validation_results.csv")

# F. Update Fish with Valid_species
lookup_map <- setNames(Valid_species$Valid_Name, Valid_species$Input_Name)
Fish$Valid.Name <- lookup_map[Fish$Name.Cleaned]

# G. Stop to troubleshoot errors
name_check <- sum(is.na(Fish$Valid.Name))
if (name_check > 0) {
  stop("Stop: There are species in Fish$Valid.Name that were not assigned a valid name.")
}

# H. Handle taxonomic inconsistencies
# 1. Isolate records requiring human search
Human_search <- Fish[Fish$Valid.Name == "Human search", ]

# 2. Print the species names that could not be resolved by the Python Script on 
# Eschmeyer's Catalog of Fishes
print(unique(Human_search[, c("Name.Cleaned", "Valid.Name")])[order(unique(Human_search$Name.Cleaned)), ])

# 3. Handle user input to correct those names via a file or console input
if (nrow(Human_search) > 0) {
  cat(strwrap("You can edit junior synonyms on the console or on a file. Would you like to output a file?", width = 60), sep = "\n")
  ans <- readline(prompt = "[yes/NO]: ")

  if (tolower(trimws(ans)) %in% c("y", "yes")) {
    # a. File-based workflow: preserve USNM Catalog Number as primary key
    write.csv(Human_search, "HumanSearch.csv", row.names = FALSE)
    
    go_signal <- ""
    while (trimws(go_signal) != "GO") {
      cat(strwrap("File instructions: You now have a file 'HumanSearch.csv' in your working directory. You must manually edit the file. Open the file and in the 'Valid.Name' column remove 'Human search' and replace that with a valid name or 'No species ID'.", width = 60), sep = "\n")
      go_signal <- readline(prompt = "Type GO when ready to push the file:")
    }
    
    updated_hs <- read.csv("HumanSearch.csv", stringsAsFactors = FALSE, encoding = "UTF-8-BOM")
    file.rename(from = "HumanSearch.csv", to = "./Output/Files/HumanSearch.csv")
    
    # b. Map back by Catalog.Number...USNM to prevent order misalignment
    lookup_corrected <- setNames(updated_hs$Valid.Name, updated_hs$Catalog.Number...USNM)
    Human_search$Valid.Name <- lookup_corrected[as.character(Human_search$Catalog.Number...USNM)]
    
  } else {
    # c. Interactive console interface workflow
    unique_names <- sort(unique(Human_search$Name.Cleaned))
    corrections  <- character(length(unique_names))
    names(corrections) <- unique_names
    
    cat("\n--- Interactive Taxonomic Correction ---\n")
    for (nm in unique_names) {
      prompt_str <- sprintf("Enter valid name, or No species ID, for '%s': ", nm)
      input_val  <- readline(prompt = prompt_str)
      corrections[nm] <- trimws(input_val)
    }
    
    Human_search$Valid.Name <- corrections[Human_search$Name.Cleaned]
  }
  
  # d. Map back into main Fish dataframe by Catalog.Number...USNM key
  hs_map <- setNames(Human_search$Valid.Name, Human_search$Catalog.Number...USNM)
  hs_idx <- which(Fish$Valid.Name == "Human search")
  
  Fish$Valid.Name[hs_idx] <- hs_map[as.character(Fish$Catalog.Number...USNM[hs_idx])]
}

# J. Move Uncertain and No species ID from Fish to Fish_kicked
# 1. Append Uncertain and No species ID rows to Fish_kicked
target_unusable <- Fish$Valid.Name %in% c("Uncertain", "No species ID")

Fish_kicked <- rbind(Fish_kicked, Fish[target_unusable, ])

# 2. Remove Uncertain and No species ID rows from Fish
Fish <- Fish[!target_unusable, ]

# II. Fill in missing coordinates using locality hierarchy
# A. Create search hierarchy for custom function
locality_hierarchy <- c("Precise.Locality", "Island.Name", "District.County",
                        "Province.State", "Country", "Island.Grouping",
                        "Archipelago", "Sea.Gulf", "Ocean")

# B. Custom function to fill missing centroids using combined reference data
fill_centroids_internal <- function(target_df, ref_df, hierarchy) {
  # Extract spatial columns present in both datasets to prevent rbind schema mismatch
  spatial_cols <- unique(c("Centroid.Latitude", "Centroid.Longitude", hierarchy))
  common_cols  <- intersect(spatial_cols, intersect(names(target_df), names(ref_df)))
  
  # Combine target and reference spatial data safely
  combined_df <- rbind(
    target_df[, common_cols, drop = FALSE], 
    ref_df[, common_cols, drop = FALSE]
  )
  
  for (loc in hierarchy) {
    if (!any(is.na(target_df$Centroid.Latitude))) break
    if (!loc %in% names(combined_df)) next
    
    # Generate spatial mean lookup tables from combined reference pool
    lat_map <- tapply(combined_df$Centroid.Latitude, combined_df[[loc]], mean, na.rm = TRUE)
    lon_map <- tapply(combined_df$Centroid.Longitude, combined_df[[loc]], mean, na.rm = TRUE)
    
    # Identify target rows missing coordinates with non-empty locality strings
    na_idx <- which(is.na(target_df$Centroid.Latitude) & 
                      !is.na(target_df[[loc]]) & 
                      trimws(as.character(target_df[[loc]])) != "")
    
    if (length(na_idx) > 0) {
      loc_keys <- as.character(target_df[[loc]][na_idx])
      
      # Assign computed means where lookup matches are valid and non-NaN
      matched_lats <- lat_map[loc_keys]
      matched_lons <- lon_map[loc_keys]
      
      valid_match <- !is.na(matched_lats) & !is.nan(matched_lats)
      
      target_df$Centroid.Latitude[na_idx[valid_match]]  <- matched_lats[valid_match]
      target_df$Centroid.Longitude[na_idx[valid_match]] <- matched_lons[valid_match]
    }
  }
  return(target_df)
}

# C. Apply non-destructive spatial imputation to Fish using Fish_kicked as reference
Fish <- fill_centroids_internal(
  target_df = Fish, 
  ref_df    = Fish_kicked, 
  hierarchy = locality_hierarchy
)

# III. Process centroid records
# A. Remove records with incomplete coordinates
Fish_missing_centroid <- Fish[is.na(Fish$Centroid.Latitude) | is.na(Fish$Centroid.Longitude), ]
Fish_kicked <- rbind(Fish_kicked, Fish_missing_centroid)
write.csv(Fish_missing_centroid, "./Output/Files/Lots_missing_centroid.csv", row.names = FALSE)

# B. Filter records with complete coordinates
Fish <- Fish[!is.na(Fish$Centroid.Latitude) & !is.na(Fish$Centroid.Longitude), ]

# IV. Resolve missing collection dates via spatial/vessel matching
# A. Find missing dates

# B. Identify rows with missing dates in the valid working set
is_missing_date <- is.na(Fish$Date.Collected) | trimws(Fish$Date.Collected) == ""

# C. Combine retained and kicked records to maximize lookup coverage
# 1. Align columns first to prevent rbind structure errors
common_cols <- intersect(names(Fish), names(Fish_kicked))
combined_pool <- rbind(Fish[, common_cols], Fish_kicked[, common_cols])

# 2. Filter combined pool for records with KNOWN dates AND VALID spatial/vessel coordinates
has_known_date <- !is.na(combined_pool$Date.Collected) & trimws(combined_pool$Date.Collected) != ""
has_valid_key  <- !is.na(combined_pool$Vessel) & combined_pool$Vessel != "" &
  !is.na(combined_pool$Centroid.Latitude) & 
  !is.na(combined_pool$Centroid.Longitude)

known_dates_df <- combined_pool[has_known_date & has_valid_key, ]

# D. Construct composite lookup key
known_dates_df$match_key <- paste(
  known_dates_df$Vessel, 
  known_dates_df$Centroid.Latitude, 
  known_dates_df$Centroid.Longitude, 
  sep = "_"
)
# E. Map unique dates to each spatial/vessel key
key_date_unique <- lapply(split(known_dates_df$Date.Collected, known_dates_df$match_key), unique)

# F. Resolve missing dates in Fish
missing_indices  <- which(is_missing_date)
error_rows_list  <- list()

for (idx in missing_indices) {
  target_key <- paste(
    Fish$Vessel[idx], 
    Fish$Centroid.Latitude[idx], 
    Fish$Centroid.Longitude[idx], 
    sep = "_"
  )
  
  matched_dates <- key_date_unique[[target_key]]
  
  if (!is.null(matched_dates)) {
    if (length(matched_dates) == 1) {
      # Impute date only if empty
      Fish$Date.Collected[idx] <- matched_dates[1]
    } else {
      err_record <- Fish[idx, ]
      err_record$Conflicting_Dates <- paste(matched_dates, collapse = " | ")
      err_record$Error_Reason     <- "Multiple conflicting dates found for spatial-vessel key"
      error_rows_list[[length(error_rows_list) + 1]] <- err_record
    }
  } else {
    err_record <- Fish[idx, ]
    err_record$Conflicting_Dates <- NA
    err_record$Error_Reason     <- "No matching spatial-vessel reference record found"
    error_rows_list[[length(error_rows_list) + 1]] <- err_record
  }
}


Dating_errors <- if (length(error_rows_list) > 0) do.call(rbind, error_rows_list) else data.frame()
write.csv(Dating_errors, "./Output/Files/Dating_errors.csv", row.names = FALSE)

write.csv(Fish, "./Output/Files/All_Ships_Updated.csv", row.names = FALSE)

# G. Output a file with lots that were not used
write.csv(Fish_kicked, "./Output/Files/Removed_lots.csv", row.names = FALSE)

# V. Check row counts and audit reconciliation
retained_count <- nrow(Fish)
kicked_count   <- nrow(Fish_kicked)

accounted_rows <- retained_count + kicked_count

if (accounted_rows != original_row_count) {
  unaccounted <- original_row_count - accounted_rows
  err_msg <- sprintf(
    "Baseline Records: %d\nRetained Records (Valid): %d\nTotal Kicked: %d\nUnaccounted Rows: %d\nScript stopped. Output will be inaccurate. Check your rows.",
    original_row_count, retained_count, kicked_count, unaccounted
  )
  stop(err_msg, call. = FALSE)
} else {
  cat(sprintf(
    "Row reconciliation successful.\nBaseline: %d | Retained (Valid): %d | Total Kicked: %d\n",
    original_row_count, retained_count, kicked_count
  ))
}

# VI. Process Spatial Clusters and Build 'Populations' Data Frame
pop_list <- lapply(split(Fish, Fish$Valid.Name), function(df_sp) {
  sp_name <- df_sp$Valid.Name[1]
  n_rows  <- nrow(df_sp)
  
  if (n_rows == 1) {
    df_sp$cluster <- 1
    df_sp$Spatial.distance <- 0
  } else {
    coords   <- as.matrix(df_sp[, c("Centroid.Longitude", "Centroid.Latitude")])
    
    # Filter out invalid or zero coordinates if present
    valid_coord_idx <- !is.na(coords[, 1]) & !is.na(coords[, 2]) & 
      (coords[, 1] != 0 | coords[, 2] != 0)
    
    dist_mat <- geosphere::distm(coords, fun = geosphere::distHaversine)
    adj_mat  <- dist_mat <= 40000
    
    g <- igraph::graph_from_adjacency_matrix(adj_mat, mode = "undirected", diag = FALSE)
    df_sp$cluster <- igraph::components(g)$membership
    
    # Calculate maximum spatial distance WITHIN each cluster independently
    cluster_dists <- sapply(split(seq_len(n_rows), df_sp$cluster), function(idx) {
      if (length(idx) <= 1) return(0)
      sub_dist <- dist_mat[idx, idx, drop = FALSE]
      round(max(sub_dist) / 1000, 2)
    })
    
    df_sp$Spatial.distance <- as.numeric(cluster_dists[as.character(df_sp$cluster)])
  }
  
  cluster_totals <- tapply(df_sp$Specimen.Count, df_sp$cluster, sum)
  valid_clusters <- names(cluster_totals)[cluster_totals >= 20]
  
  if (length(valid_clusters) == 0) return(NULL)
  
  df_sub <- df_sp[df_sp$cluster %in% valid_clusters, ]
  
  cluster_map <- setNames(seq_along(valid_clusters), valid_clusters)
  pop_indices <- cluster_map[as.character(df_sub$cluster)]
  
  df_sub$Populations.by.species <- paste0("Population ", pop_indices, " of ", sp_name)
  
  res <- df_sub[, c("Populations.by.species", 
                    "Catalog.Number...USNM", 
                    "Specimen.Count", 
                    "Date.Collected", 
                    "Vessel", 
                    "Centroid.Latitude", 
                    "Centroid.Longitude",
                    "Spatial.distance")]
  return(res)
})

Populations <- do.call(rbind, pop_list)
rownames(Populations) <- NULL

# VII. Prepare for plots

# A. Export CSV artifacts
write.csv(Populations, "./Output/Files/Potential.csv", row.names = FALSE)

Candidate_list <- sort(unique(sub("^Population \\d+ of ", "", Populations$Populations.by.species)))
write.csv(data.frame(Valid.Name = Candidate_list), "./Output/Files/CandidateSpeciesList.csv", row.names = FALSE)

# B. Temporal Filtering for Spatial Mapping
# 1. Helper function to parse 4-digit year from Date.Collected strings
extract_collection_year <- function(date_str) {
  if (is.na(date_str) || trimws(date_str) == "") return(NA_integer_)
  parsed_dt <- suppressWarnings(lubridate::parse_date_time(date_str, orders = c("Ymd", "dmY", "mdY", "Ym", "Y")))
  if (!is.na(parsed_dt)) return(as.integer(format(parsed_dt, "%Y")))
  m4 <- stringr::str_extract(date_str, "(?<!\\d)(18|19)\\d{2}(?!\\d)")
  if (!is.na(m4)) return(as.integer(m4))
  return(NA_integer_)
}

# 2. Controls to exclude post-1947 lots (high probability of formalin fixation) while retaining undated lots
filter_kmz_by_year <- TRUE
max_kmz_year       <- 1947

# 3. Apply date filter to Populations data frame prior to KML compilation
Populations_kmz <- Populations %>%
  mutate(Extracted_Year = sapply(Date.Collected, extract_collection_year)) %>%
  filter(
    if (filter_kmz_by_year) {
      is.na(Extracted_Year) | Extracted_Year <= max_kmz_year
    } else {
      TRUE
    }
  )

# VIII. Generate KMZ Map Visualization
# A. Define palette and map colors
kml_palette <- c(
  "ff0000ff", "ff000000", "ff00ff00", "ffff0000", "ffff00ff", "ffffa500", 
  "ff00ffff", "ff800080", "ff0080ff", "ff008000", "ff800000", "ff808000", 
  "ff000080", "ff808080", "ff00a5ff", "ff13eac7", "ffda70d6", "ff4763ff", 
  "ffd2b48c", "ff228b22"
)

Populations_kmz$Valid.Name <- sub("^Population \\d+ of ", "", Populations_kmz$Populations.by.species)
unique_taxa <- sort(unique(Populations_kmz$Valid.Name))
taxon_color_map <- setNames(kml_palette[(seq_along(unique_taxa) - 1) %% length(kml_palette) + 1], unique_taxa)

sp_pop_totals <- tapply(Populations_kmz$Populations.by.species, Populations_kmz$Valid.Name, function(x) length(unique(x)))

# B. Define KML content generator function
generate_kml_content <- function(df, color_map, pop_totals) {
  kml_header <- c(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<kml xmlns="http://www.opengis.net/kml/2.2">',
    '<Document>',
    '  <name>USFC Collection Populations to 1947 and Undated)</name>'
  )
  
  style_nodes <- sapply(names(color_map), function(sp) {
    color_hex <- color_map[[sp]]
    style_id  <- paste0("style_", gsub("[^A-Za-z0-9]", "_", sp))
    paste0(
      '  <Style id="', style_id, '">\n',
      '    <IconStyle>\n',
      '      <color>', color_hex, '</color>\n',
      '      <scale>0.9</scale>\n',
      '      <Icon><href>http://maps.google.com/mapfiles/kml/paddle/wht-blank.png</href></Icon>\n',
      '    </IconStyle>\n',
      '  </Style>'
    )
  })
  
  distinct_counts <- unname(sort(unique(pop_totals), decreasing = TRUE))
  
  folder_nodes <- unlist(lapply(distinct_counts, function(cnt) {
    folder_label   <- paste0(cnt, if (cnt == 1) " pop" else " pops")
    species_in_cnt <- sort(names(pop_totals)[pop_totals == cnt])
    
    f_open <- paste0('  <Folder>\n    <name>', folder_label, '</name>')
    
    subfolders <- unlist(lapply(species_in_cnt, function(sp_name) {
      df_sp <- df[df$Valid.Name == sp_name, ]
      style_id <- paste0("style_", gsub("[^A-Za-z0-9]", "_", sp_name))
      
      sub_open <- paste0('    <Folder>\n      <name>', sp_name, '</name>')
      
      placemarks <- apply(df_sp, 1, function(row) {
        pop_label <- gsub("^Population ([0-9]+) of ", "P\\1 ", row["Populations.by.species"])
        
        usnm_cat   <- row["Catalog.Number...USNM"]
        count_val  <- row["Specimen.Count"]
        date_val   <- row["Date.Collected"]
        vessel_val <- row["Vessel"]
        lat_val    <- row["Centroid.Latitude"]
        lon_val    <- row["Centroid.Longitude"]
        
        paste0(
          '      <Placemark>\n',
          '        <name>', pop_label, '</name>\n',
          '        <styleUrl>#', style_id, '</styleUrl>\n',
          '        <ExtendedData>\n',
          '          <Data name="Species"><value>', sp_name, '</value></Data>\n',
          '          <Data name="USNM Catalog Number"><value>', usnm_cat, '</value></Data>\n',
          '          <Data name="Specimen Count"><value>', count_val, '</value></Data>\n',
          '          <Data name="Date Collected"><value>', date_val, '</value></Data>\n',
          '          <Data name="Vessel"><value>', vessel_val, '</value></Data>\n',
          '        </ExtendedData>\n',
          '        <Point>\n',
          '          <coordinates>', lon_val, ',', lat_val, ',0</coordinates>\n',
          '        </Point>\n',
          '      </Placemark>'
        )
      })
      
      sub_close <- '    </Folder>'
      return(c(sub_open, placemarks, sub_close))
    }))
    
    f_close <- '  </Folder>'
    return(c(f_open, subfolders, f_close))
  }))
  
  return(c(kml_header, unname(style_nodes), folder_nodes, '</Document>', '</kml>'))
}

# C. Construct and compress KMZ file
kml_lines <- generate_kml_content(Populations_kmz, taxon_color_map, sp_pop_totals)
writeLines(kml_lines, "doc.kml")
utils::zip("USFC_Collection.kmz", files = "doc.kml", flags = "-q")
file.rename(from = "USFC_Collection.kmz", to = "./Output/Files/USFC_Collection.kmz")
file.remove("doc.kml")

# IX. Create Histograms
# A. Extract 4-Digit Year or Assign UNDATED
extract_year <- function(date_str) {
  if (is.na(date_str) || str_trim(date_str) == "") return("UNDATED")
  
  # 1. Match explicit 4-digit years in 18th, 19th, or 20th centuries (1800-1999)
  m4 <- str_extract(date_str, "\\b(18|19)\\d{2}\\b")
  if (!is.na(m4)) return(as.numeric(m4))
  
  # 2. Match trailing 2-digit years and map strictly to 20th century (19yy)
  m2 <- str_extract(date_str, "(?<=^|[-/\\s])\\d{2}(?=$|[-/\\s])")
  if (!is.na(m2)) {
    yy <- as.numeric(m2)
    return(1900 + yy)
  }
  
  return("UNDATED")
}

# B. Extract raw year vectors from source
raw_years_vec <- sapply(Populations$Date.Collected, extract_year)

# C. Determine timeline boundaries
numeric_years <- suppressWarnings(as.numeric(raw_years_vec))
valid_years   <- numeric_years[!is.na(numeric_years)]

if (length(valid_years) == 0) {
  earliest_year <- 1899
  latest_year   <- 1899
} else {
  earliest_year <- min(valid_years)
  latest_year   <- max(valid_years)
}

# D. Build Populations_plot
Populations_plot <- Populations %>%
  mutate(
    Raw_Year   = raw_years_vec,
    Valid.Name = sub("^Population \\d+ of ", "", Populations.by.species),
    Lot_ID     = as.character(Catalog.Number...USNM),
    Num_Year   = suppressWarnings(as.numeric(Raw_Year)),
    X_Bin      = case_when(
      Raw_Year == "UNDATED" ~ -1,
      TRUE ~ Num_Year - earliest_year
    )
  )

# E. Configure Dataset Cutoff Filter (Comment out cutoff_year or set to NULL to disable)
cutoff_year <- 1947
cutoff_type <- "upper" # Options: "upper" (keep <= cutoff_year) or "lower" (keep >= cutoff_year)
include_undated <- TRUE # Keep UNDATED records when applying upper cutoff

# cutoff_year <- NULL # Un-comment to disable filtering completely

Populations_plot_filtered <- if (!is.null(cutoff_year)) {
  if (cutoff_type == "upper") {
    Populations_plot %>% 
      filter((include_undated & Raw_Year == "UNDATED") | (!is.na(Num_Year) & Num_Year <= cutoff_year))
  } else if (cutoff_type == "lower") {
    Populations_plot %>% 
      filter(!is.na(Num_Year) & Num_Year >= cutoff_year)
  } else {
    Populations_plot
  }
} else {
  Populations_plot
}

# F. Construct bins and axis breaks based on filtered dataset
filtered_num_years <- suppressWarnings(as.numeric(Populations_plot_filtered$Raw_Year))
filtered_valid_years <- filtered_num_years[!is.na(filtered_num_years)]

if (length(filtered_valid_years) == 0) {
  plot_earliest <- earliest_year
  plot_latest   <- latest_year
} else {
  plot_earliest <- min(filtered_valid_years)
  plot_latest   <- max(filtered_valid_years)
}

if (plot_earliest == plot_latest) {
  seq_years <- plot_earliest
} else {
  seq_years <- seq(plot_earliest, plot_latest, by = 1)
}

# Check if UNDATED exists in filtered output to include -1 bin
has_undated  <- "UNDATED" %in% Populations_plot_filtered$Raw_Year

if (has_undated) {
  year_bins    <- unique(sort(c(-1.5, -0.5, seq_years - earliest_year + 0.5)))
  year_labels  <- c("UNDATED", as.character(seq_years))
  break_points <- c(-1, seq_years - earliest_year)
} else {
  year_bins    <- unique(sort(seq_years - earliest_year + 0.5))
  year_bins    <- c(min(seq_years - earliest_year) - 0.5, year_bins)
  year_labels  <- as.character(seq_years)
  break_points <- seq_years - earliest_year
}

if (length(seq_years) > 1) {
  display_mask <- if (has_undated) {
    c(TRUE, (seq_years %% 5 == 0 | seq_years == plot_earliest | seq_years == plot_latest))
  } else {
    (seq_years %% 5 == 0 | seq_years == plot_earliest | seq_years == plot_latest)
  }
} else {
  display_mask <- if (has_undated) c(TRUE, TRUE) else TRUE
}

break_points_sub <- break_points[display_mask]
year_labels_sub  <- year_labels[display_mask]

# G. Plot Combined Histogram by Vessel
p_all_vessel <- ggplot(Populations_plot_filtered, aes(x = X_Bin, weight = Specimen.Count, fill = Vessel)) +
  geom_histogram(breaks = year_bins, color = "black", linewidth = 0.2) +
  scale_x_continuous(breaks = break_points_sub, labels = year_labels_sub) +
  labs(
    title = paste0("USFC Collections: Specimen Count by Vessel", 
                   if(!is.null(cutoff_year)) paste0(" (", cutoff_type, " bound is ", cutoff_year, ")") else ""),
    x = "Collection Year",
    y = "Specimen Count",
    fill = "Vessel"
  ) +
  theme_bw() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "bottom"
  )

ggsave("./Output/Figures/Histogram_All_Species_By_Vessel.png", p_all_vessel, width = 10, height = 6, dpi = 300)

# H. Plot Individual Species Histograms (Sorted by Pops, then Specimen Count)
# 1. Derive species order directly from plot data: highest pops, then highest total specimens
species_list <- Populations_plot_filtered %>%
  group_by(Valid.Name) %>%
  summarize(
    total_pops  = n_distinct(Populations.by.species),
    total_specs = sum(Specimen.Count, na.rm = TRUE),
    .groups     = "drop"
  ) %>%
  arrange(desc(total_pops), desc(total_specs), Valid.Name) %>%
  pull(Valid.Name)

# 2. Define custom hex color map for USFC vessels
vessel_colors <- c(
  "Fish Hawk" = "#FF9999", # Light Red
  "Grampus"   = "#87CEFA", # Light Blue
  "Albatross" = "#FFFACD"  # Light Yellow
)

pdf("./Output/Figures/Histograms_By_Species.pdf", width = 10, height = 6)

for (sp in species_list) {
  df_sp <- Populations_plot_filtered %>% filter(Valid.Name == sp)
  
  if (nrow(df_sp) == 0) next
  
  total_sp_specs <- sum(df_sp$Specimen.Count, na.rm = TRUE)
  total_sp_pops  <- length(unique(df_sp$Populations.by.species))
  
  p_sp <- ggplot(df_sp, aes(x = X_Bin, weight = Specimen.Count, fill = Vessel)) +
    geom_histogram(breaks = year_bins, color = "black", linewidth = 0.3) +
    scale_x_continuous(breaks = break_points_sub, labels = year_labels_sub) +
    scale_fill_manual(values = vessel_colors, drop = FALSE) +
    labs(
      title    = bquote(italic(.(sp))),
      subtitle = paste0("Total Specimens: ", total_sp_specs, " | Total Populations (40 km R): ", total_sp_pops),
      x        = "Collection Year",
      y        = "Specimen Count",
      fill     = "Vessel"
    ) +
    theme_bw() +
    theme(
      axis.text.x     = element_text(angle = 45, hjust = 1),
      legend.position = "right",
      plot.title      = element_text(face = "bold", size = 12),
      plot.subtitle   = element_text(size = 10)
    )
  
  print(p_sp)
}

dev.off()

# X. Create Species_table.pdf
# A. Helper function for collection year extraction with Vessel context
extract_collection_year <- function(date_str, vessel_str) {
  if (is.na(date_str) || trimws(date_str) == "") return(NA_integer_)
  
  # 1. Check for explicit 4-digit year (1800-2099)
  m4 <- stringr::str_extract(date_str, "(?<!\\d)(18|19|20)\\d{2}(?!\\d)")
  if (!is.na(m4)) return(as.integer(m4))
  
  # 2. Extract isolated 2-digit year (YY)
  m2 <- stringr::str_extract(date_str, "(?<!\\d)\\d{2}(?!\\d)")
  if (is.na(m2)) return(NA_integer_)
  
  yy <- as.integer(m2)
  vessel <- if (is.na(vessel_str)) "" else trimws(vessel_str)
  
  # 3. Disambiguate century based on Vessel commissioning parameters
  if (grepl("Albatross IV", vessel, ignore.case = TRUE)) {
    if (yy <= 8)  return(2000L + yy) # 2000-2008
    if (yy >= 63) return(1900L + yy) # 1963-1999
  } else if (grepl("Fish Hawk", vessel, ignore.case = TRUE)) {
    if (yy >= 80) return(1800L + yy) # 1880-1899
    if (yy <= 26) return(1900L + yy) # 1900-1926
  } else if (grepl("Grampus", vessel, ignore.case = TRUE)) {
    if (yy >= 86) return(1800L + yy) # 1886-1899
    if (yy <= 17) return(1900L + yy) # 1900-1917
  } else if (grepl("Albatross II", vessel, ignore.case = TRUE)) {
    if (yy >= 26 && yy <= 32) return(1900L + yy) # 1926-1932
  } else if (grepl("Albatross III", vessel, ignore.case = TRUE)) {
    if (yy >= 48 && yy <= 59) return(1900L + yy) # 1948-1959
  } else if (grepl("Albatross", vessel, ignore.case = TRUE)) {
    # Default USFC Albatross (I)
    if (yy >= 82) return(1800L + yy) # 1882-1899
    if (yy <= 21) return(1900L + yy) # 1900-1921
  }
  
  # Fallback for unmapped vessels with 2-digit years (Default to 1900s)
  return(1900L + yy)
}

# B. Temporal Filtering for Species Table using mapply over Date.Collected and Vessel
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
# C. Extract species name from Populations.by.species
Populations_table_input$Valid.Name <- sub("^Population \\d+ of ", "", Populations_table_input$Populations.by.species)
Populations_table_input$Valid.Name <- trimws(Populations_table_input$Valid.Name)
Populations_table_input$Valid.Name <- gsub("\\.$", "", Populations_table_input$Valid.Name)

# Ensure numeric data types for spatial processing using actual column names
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

# Vector Mapping Steps
sp_max_dist_vec  <- unname(sp_max_distance[Populations_table_input$Valid.Name])
sp_temp_rang_vec <- unname(sp_temp_range[Populations_table_input$Valid.Name])
sp_total_specs   <- ave(Populations_table_input$Specimen.Count, Populations_table_input$Valid.Name, FUN = function(x) sum(x, na.rm = TRUE))

# G. Construct final data.frame from retained populations
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

# Hierarchical species and lot sorting
Species_table <- Species_table[order(
  -Species_table$Total_Populations_40km_r, 
  -Species_table$sp_total_specs,
  Species_table$Valid.Name, 
  -Species_table$Specimen.Count
), ]

# Drop helper vector
Species_table$sp_total_specs <- NULL

# Blank out species-level metrics for duplicate species lot rows (retaining values on row 1 only)
dup_mask <- duplicated(Species_table$Valid.Name)

Species_table$Total_Populations_40km_r[dup_mask] <- ""
Species_table$Spatial.distance[dup_mask]         <- ""
Species_table$Temporal.range[dup_mask]           <- ""

# Convert numeric metrics to character for clean rendering prior to CSV / PDF write
Species_table$Total_Populations_40km_r <- as.character(Species_table$Total_Populations_40km_r)
Species_table$Spatial.distance         <- as.character(Species_table$Spatial.distance)
Species_table$Temporal.range           <- as.character(Species_table$Temporal.range)

# H. Apply requested PDF display column headers (using "Span (yr)")
colnames(Species_table) <- c(
  "Species",
  "Specimens",
  "Lot #",
  "Pops. (40 km R)",
  "Range (km)",
  "Span (yr)"
)

write.csv(Species_table, "./Output/Files/Species_table.csv", row.names = FALSE)

# I. PDF Table Rendering (1-Inch Header and Footer Margins)
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

# J. Construct Species-Level Summary Data Frame (1 Row Per Species)

# Extract canonical list of unique species present in filtered dataset
unique_species <- sort(unique(Populations_table_input$Valid.Name))

# Aggregate specimen counts across all retained populations
sp_total_specimens <- tapply(
  Populations_table_input$Specimen.Count, 
  Populations_table_input$Valid.Name, 
  sum, 
  na.rm = TRUE
)

# Safe lookup function for common names (handles unmapped species and empty cells)
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