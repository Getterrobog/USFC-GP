# Script: nmnhsearchinator.R
# Purpose: The purpose of this script is to analyze and process USNM collections data to:
# • Add valid names from Eschmeyer's catalog of fishes
# • species_checkinator.py must:
# - be given permissions ("chmod u+x species_checkinator.py")
# - be placed in the active R working directory OR in a directory listed in your shell initialization script
# - example: export PATH="$PATH:$HOME/[dir_containing_script]"
# • use data from the file as a dictionary to fill in centroids and missing dates if possible under the assumptions
# - that samples collected by the same ship on the same date occurred close to each other
# - that samples collected by the same ship close to each other share the same date
# • Add common names from FishBase
# It will handle a *.csv file downloaded from https://collections.nmnh.si.edu/search/fishes/t.
# Author: Iván R. López Martínez
# I used R version 4.6.1 (2026-06-24) -- "Happy Hop"
# I used Gemini AI to troubleshoot.
# Save your original USNM.csv file prior to processing and do not modify it.
# In your working Directory create the following directory structure:
# Data/ (place the USNM.csv here)
# Output/Figures
# Output/Files
# Scripts/ (place your R script here.)

#I. Setup Environment and Load Libraries

# A. Set your working directory
setwd("/Users/ivanlopez/OneDrive - University of Central Florida/USFCGP/R-USFCGP/")

# B. Load required packages
library(readxl)
library(dplyr)
library(stringr)
library(tibble)
library(lubridate)
library(rfishbase)
library(geosphere)
library(igraph)

# C. Initialize directory structure.  I would do this prior to running the script
# dir.create has built in no-clobber, which means your existing dir will not be overwritten.
#dir.create("./Data", recursive = TRUE, showWarnings = FALSE)
#dir.create("./Scripts", recursive = TRUE, showWarnings = FALSE)
#dir.create("./Output/Files", recursive = TRUE, showWarnings = FALSE)
#dir.create("./Output/Figures", recursive = TRUE, showWarnings = FALSE)

# II. Prepare file for processing
# A. Read USNM *.csv file.  I renamed mine to preserve the original download elsewhere
Fish <- read.csv("./Data/All_collections.csv", stringsAsFactors = FALSE, encoding = "UTF-8-BOM")
original_row_count <- nrow(Fish)
# A. Add columns.
Fish <- Fish %>%
  add_column(Valid.Name = "", Common.Name = "", Name.Cleaned = "", .after = "Specimen.Count") %>%
  add_column(Date.ISO.8601 = "", .after = "Subfamily") %>%
  mutate(Vessel = if_else(Vessel == "Grampus (Bache)", "Grampus", Vessel))

# III. Fix the date regex nightmare to standardize dates
# A. Define Vessel commissioning range helper for 2-digit year disambiguation
extract_collection_year <- function(date_str, vessel_str) {
  if (is.na(date_str) || trimws(date_str) == "") return(NA_integer_)
  
  # 1. Match explicit 4-digit years (1800-2099)
  m4 <- str_extract(date_str, "(?<!\\d)(18|19|20)\\d{2}(?!\\d)")
  if (!is.na(m4)) return(as.integer(m4))
  
  # 2. Extract isolated 2-digit year
  m2 <- str_extract(date_str, "(?<!\\d)\\d{2}(?!\\d)")
  if (is.na(m2)) return(NA_integer_)
  
  yy <- as.integer(m2)
  vessel <- if (is.na(vessel_str)) "" else trimws(vessel_str)
  
  # 3. Disambiguate century based on Vessel commissioning parameters
  if (grepl("Albatross IV", vessel, ignore.case = TRUE)) {
    if (yy <= 8)  return(2000L + yy)
    if (yy >= 63) return(1900L + yy)
  } else if (grepl("Fish Hawk", vessel, ignore.case = TRUE)) {
    if (yy >= 80) return(1800L + yy)
    if (yy <= 26) return(1900L + yy)
  } else if (grepl("Grampus", vessel, ignore.case = TRUE)) {
    if (yy >= 86) return(1800L + yy)
    if (yy <= 17) return(1900L + yy)
  } else if (grepl("Albatross II", vessel, ignore.case = TRUE)) {
    if (yy >= 26 && yy <= 32) return(1900L + yy)
  } else if (grepl("Albatross III", vessel, ignore.case = TRUE)) {
    if (yy >= 48 && yy <= 59) return(1900L + yy)
  } else if (grepl("Albatross", vessel, ignore.case = TRUE)) {
    if (yy >= 82) return(1800L + yy)
    if (yy <= 21) return(1900L + yy)
  }
  
  return(1900L + yy)
}

# B. Pre-clean raw string artifacts: strip parentheses and everything inside them first
date_clean <- trimws(Fish$Date.Collected)
date_clean <- gsub("\\s*\\([^)]*\\)", "", date_clean)
date_clean <- gsub("\\s+to\\s+.*$", "", date_clean, ignore.case = TRUE)
date_clean <- trimws(date_clean)

# C. Set lookup map for 3-letter month abbreviations
months_map <- setNames(sprintf("%02d", 1:12), 
                       c("Jan", "Feb", "Mar", "Apr", "May", "Jun", 
                         "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"))

# D. Vectorized ISO 8601 string parsing function leveraging extract_collection_year
parse_iso_date <- function(x, vessel_str) {
  if (is.na(x) || x == "") return("")
  
  full_yr <- extract_collection_year(x, vessel_str)
  
  if (str_detect(x, "^\\d{1,2}-[A-Za-z]{3}-\\d{2}$") || str_detect(x, "^\\d{1,2}-[A-Za-z]{3}-\\d{4}$")) {
    parts <- unlist(strsplit(x, "-"))
    day <- sprintf("%02d", as.integer(parts[1]))
    mon_key <- paste0(toupper(substr(parts[2], 1, 1)), tolower(substr(parts[2], 2, 3)))
    mon <- months_map[mon_key]
    yr <- if (!is.na(full_yr)) as.character(full_yr) else ""
    if (yr != "" && !is.na(mon)) return(paste(yr, mon, day, sep = "-"))
  }
  
  if (str_detect(x, "^\\d{1,2}\\s+[A-Za-z]{3}\\s+\\d{2,4}$")) {
    parts <- unlist(strsplit(x, "\\s+"))
    day <- sprintf("%02d", as.integer(parts[1]))
    mon_key <- paste0(toupper(substr(parts[2], 1, 1)), tolower(substr(parts[2], 2, 3)))
    mon <- months_map[mon_key]
    yr <- if (!is.na(full_yr)) as.character(full_yr) else ""
    if (yr != "" && !is.na(mon)) return(paste(yr, mon, day, sep = "-"))
  }
  
  if (str_detect(x, "^[A-Za-z]{3}\\s+\\d{2,4}$")) {
    parts <- unlist(strsplit(x, "\\s+"))
    mon_key <- paste0(toupper(substr(parts[1], 1, 1)), tolower(substr(parts[1], 2, 3)))
    mon <- months_map[mon_key]
    yr <- if (!is.na(full_yr)) as.character(full_yr) else ""
    if (yr != "" && !is.na(mon)) return(paste(yr, mon, sep = "-"))
  }
  
  if (!is.na(full_yr)) return(as.character(full_yr))
  
  return("")
}

# E. Execute date parsing incorporating vessel context
Fish$Date.ISO.8601 <- mapply(parse_iso_date, date_clean, Fish$Vessel, USE.NAMES = FALSE)

# F. Correct date by existing centroid coordinates
valid_date_rows <- Fish$Date.ISO.8601 != ""

if (any(!valid_date_rows) && any(valid_date_rows)) {
  lookup_df <- Fish[valid_date_rows, c("Centroid.Latitude", "Centroid.Longitude", "Vessel", "Date.ISO.8601")]
  lookup_df <- lookup_df[!duplicated(lookup_df[, c("Centroid.Latitude", "Centroid.Longitude", "Vessel")]), ]
  
  missing_idx <- which(Fish$Date.ISO.8601 == "")
  
  for (i in missing_idx) {
    lat <- Fish$Centroid.Latitude[i]
    lon <- Fish$Centroid.Longitude[i]
    ves <- Fish$Vessel[i]
    
    if (!is.na(lat) && !is.na(lon) && !is.na(ves) && ves != "") {
      match_row <- lookup_df[
        lookup_df$Centroid.Latitude == lat &
          lookup_df$Centroid.Longitude == lon &
          lookup_df$Vessel == ves,
      ]
      
      if (nrow(match_row) > 0) {
        Fish$Date.ISO.8601[i] <- match_row$Date.ISO.8601[1]
      }
    }
  }
}

# IV. Fill in missing coordinates
# A. Hierarchical centroid imputation within single Fish data frame
locality_hierarchy <- c("Precise.Locality", "Island.Name", "District.County",
                        "Province.State", "Country", "Island.Grouping",
                        "Archipelago", "Sea.Gulf", "Ocean")

fill_centroids_internal <- function(target_df, hierarchy) {
  for (loc in hierarchy) {
    if (!any(is.na(target_df$Centroid.Latitude))) break
    if (!loc %in% names(target_df)) next
    
    lat_map <- tapply(target_df$Centroid.Latitude, target_df[[loc]], mean, na.rm = TRUE)
    lon_map <- tapply(target_df$Centroid.Longitude, target_df[[loc]], mean, na.rm = TRUE)
    
    na_idx <- which(is.na(target_df$Centroid.Latitude) & 
                      !is.na(target_df[[loc]]) & 
                      trimws(as.character(target_df[[loc]])) != "")
    
    if (length(na_idx) > 0) {
      loc_keys <- as.character(target_df[[loc]][na_idx])
      matched_lats <- lat_map[loc_keys]
      matched_lons <- lon_map[loc_keys]
      valid_match  <- !is.na(matched_lats) & !is.nan(matched_lats)
      
      target_df$Centroid.Latitude[na_idx[valid_match]]  <- matched_lats[valid_match]
      target_df$Centroid.Longitude[na_idx[valid_match]] <- matched_lons[valid_match]
    }
  }
  return(target_df)
}

Fish <- fill_centroids_internal(target_df = Fish, hierarchy = locality_hierarchy)

# B. Temporal Spatial-Vessel Matching Imputation
is_missing_date <- is.na(Fish$Date.Collected) | trimws(Fish$Date.Collected) == ""

has_known_date <- !is.na(Fish$Date.Collected) & trimws(Fish$Date.Collected) != ""
has_valid_key  <- !is.na(Fish$Vessel) & Fish$Vessel != "" &
  !is.na(Fish$Centroid.Latitude) & 
  !is.na(Fish$Centroid.Longitude)

known_dates_df <- Fish[has_known_date & has_valid_key, ]
known_dates_df$match_key <- paste(known_dates_df$Vessel, known_dates_df$Centroid.Latitude, known_dates_df$Centroid.Longitude, sep = "_")
key_date_unique <- lapply(split(known_dates_df$Date.Collected, known_dates_df$match_key), unique)

missing_indices <- which(is_missing_date)
error_rows_list <- list()

for (idx in missing_indices) {
  target_key <- paste(Fish$Vessel[idx], Fish$Centroid.Latitude[idx], Fish$Centroid.Longitude[idx], sep = "_")
  matched_dates <- key_date_unique[[target_key]]
  
  if (!is.null(matched_dates)) {
    if (length(matched_dates) == 1) {
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

# C. High-Precision Station Log Correction (PR_plots Execution)
PR_plots <- read_xlsx("Data/Plotted.xlsx", skip = 3)[, -c(2, 4, 5, 7:17, 20:24)]
colnames(PR_plots) <- make.names(colnames(PR_plots))

PR_plots_clean <- PR_plots %>%
  mutate(
    Station_Key      = trimws(as.character(as.integer(Station.No.))),
    Date.ISO.8601_PR = format(dmy(Index.Date), "%Y-%m-%d"),
    Lat_PR           = as.numeric(Lat.dec),
    Long_PR          = as.numeric(Long.dec)
  ) %>%
  filter(!is.na(Station_Key) & Station_Key != "") %>%
  select(Station_Key, Lat_PR, Long_PR, Date.ISO.8601_PR) %>%
  distinct(Station_Key, .keep_all = TRUE)

Fish <- Fish %>%
  mutate(temp_station_key = trimws(as.character(Station))) %>%
  left_join(PR_plots_clean, by = c("temp_station_key" = "Station_Key")) %>%
  mutate(
    Centroid.Latitude  = if_else(!is.na(Lat_PR), Lat_PR, as.numeric(Centroid.Latitude)),
    Centroid.Longitude = if_else(!is.na(Long_PR), Long_PR, as.numeric(Centroid.Longitude)),
    Date.ISO.8601      = if_else(!is.na(Date.ISO.8601_PR) & Date.ISO.8601_PR != "", Date.ISO.8601_PR, Date.ISO.8601)
  ) %>%
  select(-temp_station_key, -Lat_PR, -Long_PR, -Date.ISO.8601_PR)

# Export records still missing spatial coordinates
Fish_missing_centroid <- Fish[is.na(Fish$Centroid.Latitude) | is.na(Fish$Centroid.Longitude), ]

# V. Taxonomic Cleaning, Validation, and Common Name Querying
# A. Identification string cleaning
id_trim <- trimws(Fish$Identification)
invalid_idx <- grepl("\\?", id_trim) | !grepl(" ", id_trim) | grepl(" cf\\. ", id_trim)

cleaned_names <- sub("^(\\S+\\s+\\S+).*", "\\1", id_trim)
cleaned_names[invalid_idx] <- "No species ID"
Fish$Name.Cleaned <- cleaned_names

# B. Eschmeyer's Catalog system call execution
writeLines(sort(unique(Fish$Name.Cleaned)), con = "species_list.txt")

#This runs the python script
system2("/Users/ivanlopez/Scripts/species_checkinator.py")

Valid_species <- read.csv("species_validation_results.csv", stringsAsFactors = FALSE, encoding = "UTF-8")
file.rename(from = "species_list.txt", to = "./Output/Files/species_list.txt")
file.rename(from = "species_validation_results.csv", to = "./Output/Files/species_validation_results.csv")

# C. Update Fish with Valid_species
lookup_map <- setNames(Valid_species$Valid_Name, Valid_species$Input_Name)
Fish$Valid.Name <- lookup_map[Fish$Name.Cleaned]

# Overwrite "Human search" with "No species ID" where Name.Cleaned is "No species ID"
Fish$Valid.Name <- if_else(Fish$Name.Cleaned == "No species ID", "No species ID", Fish$Valid.Name)

if (sum(is.na(Fish$Valid.Name)) > 0) {
  stop("Stop: There are species in Fish$Valid.Name that were not assigned a valid name.")
}

# D. Query FishBase for official common names via rfishbase
taxa_vector <- as.character(unique(Valid_species$Valid_Name))
taxa_vector <- taxa_vector[taxa_vector != "Human search" & taxa_vector != "No species ID" & !is.na(taxa_vector)]

primary_names <- rfishbase::species(species_list = taxa_vector) %>%
  select(Valid_Name = Species, Common_Name = FBname)

# Map FBname into Fish$Common.Name using Fish$Valid.Name
common_lookup <- setNames(primary_names$Common_Name, primary_names$Valid_Name)
Fish$Common.Name <- common_lookup[Fish$Valid.Name]
Fish$Common.Name[is.na(Fish$Common.Name)] <- ""

# VI. Interactive Taxonomic Resolution and Edits
# A. Isolate records requiring manual human resolution
Human_search <- Fish[Fish$Valid.Name == "Human search", ]

if (nrow(Human_search) > 0) {
  print(unique(Human_search[, c("Name.Cleaned", "Valid.Name")])[order(unique(Human_search$Name.Cleaned)), ])
  cat("You can edit junior synonyms on the console or via file. Would you like to output a file?\n")
  ans <- readline(prompt = "[yes/NO]: ")
  
  if (tolower(trimws(ans)) %in% c("y", "yes")) {
    write.csv(Human_search, "HumanSearch.csv", row.names = FALSE)
    go_signal <- ""
    while (trimws(go_signal) != "GO") {
      cat("Edit 'HumanSearch.csv' in 'Valid.Name'. Replace 'Human search' with valid name or 'No species ID'.\n")
      go_signal <- readline(prompt = "Type GO when ready to push the file: ")
    }
    updated_hs <- read.csv("HumanSearch.csv", stringsAsFactors = FALSE, encoding = "UTF-8-BOM")
    file.rename(from = "HumanSearch.csv", to = "./Output/Files/HumanSearch.csv")
    
    lookup_corrected <- setNames(updated_hs$Valid.Name, updated_hs$Catalog.Number...USNM)
    Human_search$Valid.Name <- lookup_corrected[as.character(Human_search$Catalog.Number...USNM)]
  } else {
    unique_names <- sort(unique(Human_search$Name.Cleaned))
    corrections  <- character(length(unique_names))
    names(corrections) <- unique_names
    for (nm in unique_names) {
      input_val <- readline(prompt = sprintf("Enter valid name, or No species ID, for '%s': ", nm))
      corrections[nm] <- trimws(input_val)
    }
    Human_search$Valid.Name <- corrections[Human_search$Name.Cleaned]
  }
  
  hs_map <- setNames(Human_search$Valid.Name, Human_search$Catalog.Number...USNM)
  hs_idx <- which(Fish$Valid.Name == "Human search")
  Fish$Valid.Name[hs_idx] <- hs_map[as.character(Fish$Catalog.Number...USNM[hs_idx])]
}

# VII. Final Record Segregation and Master Output Serialization
# A. Keep good rows and kick out bad
# 1. Identify species that appear exactly once in the dataset
name_freqs <- table(Fish$Valid.Name)
single_species <- names(name_freqs)[name_freqs == 1]

# 2. Condition: valid name appears only once AND specimen count is less than 20
is_single_low_count <- Fish$Valid.Name %in% single_species & Fish$Specimen.Count < 20

# 3. Segregate non-target records
is_invalid_lot <- Fish$Kind.of.Object == "Image" |
  is.na(Fish$Specimen.Count) |
  Fish$Specimen.Count == 0 |
  Fish$Valid.Name == "Uncertain" |
  Fish$Valid.Name == "No species ID" |
  Fish$Order == "Amphioxiformes" |
  Fish$Type.Status != "" |
  Fish$Ocean == "North Pacific Ocean" |
  Fish$Country == "Japan" |
  grepl("Philippines", Fish$Precise.Locality, ignore.case = TRUE) |
  grepl("California", Fish$Precise.Locality, ignore.case = TRUE) |
  (Fish$Specimen.Count == 1 & (grepl("^Glycerin", Fish$Preparation.Details..Preparation.Location.Count.) | 
                                 grepl("^Dry", Fish$Preparation.Details..Preparation.Location.Count.))) |
  startsWith(as.character(Fish$Preparation.Details..Preparation.Location.Count.), "Larvae:") |
  is_single_low_count

# 4. Update Fish create and create a data.frame with unusable lots
Fish_kicked <- Fish[is_invalid_lot, ]
Fish        <- Fish[!is_invalid_lot, ]

# B. Row reconciliation audit verification
retained_count <- nrow(Fish)
kicked_count   <- nrow(Fish_kicked)
accounted_rows <- retained_count + kicked_count

if (accounted_rows != original_row_count) {
  unaccounted <- original_row_count - accounted_rows
  err_msg <- sprintf(
    "Baseline Records: %d | Retained: %d | Kicked: %d | Unaccounted: %d\nScript stopped due to audit mismatch.",
    original_row_count, retained_count, kicked_count, unaccounted
  )
  stop(err_msg, call. = FALSE)
} else {
  cat(sprintf(
    "Row reconciliation successful.\nBaseline: %d | Retained (Valid): %d | Total Kicked: %d\n",
    original_row_count, retained_count, kicked_count
  ))
}

# C. Consolidate diagnostic correction records into Fish_to_fix
# 1. Standardize and align column structures prior to binding
common_fix_cols <- intersect(names(Dating_errors), names(Fish_missing_centroid))

if (nrow(Dating_errors) > 0 || nrow(Fish_missing_centroid) > 0) {
  Fish_to_fix <- rbind(
    if (nrow(Dating_errors) > 0) Dating_errors[, common_fix_cols, drop = FALSE] else data.frame(),
    if (nrow(Fish_missing_centroid) > 0) Fish_missing_centroid[, common_fix_cols, drop = FALSE] else data.frame()
  )
  
  # 2. Deduplicate records by Catalog.Number...USNM primary key
  Fish_to_fix <- Fish_to_fix %>%
    distinct(Catalog.Number...USNM, .keep_all = TRUE)
  
  # 3. Strip any catalog numbers that exist in Fish_kicked (unusable/rejected lots)
  kicked_catalogs <- unique(Fish_kicked$Catalog.Number...USNM)
  Fish_to_fix     <- Fish_to_fix %>%
    filter(!Catalog.Number...USNM %in% kicked_catalogs)
} else {
  Fish_to_fix <- data.frame()
}

# D. Master data serialization
write.csv(Fish_kicked, "./Output/Files/Removed_lots.csv", row.names = FALSE)
write.csv(Fish, "./Output/Files/All_Ships_Updated.csv", row.names = FALSE)
write.csv(Fish_to_fix, "./Output/Files/Fish_to_fix.csv", row.names = FALSE)

# VIII. Process Spatial Clusters and Build 'Populations' Data Frame
pop_list <- lapply(split(Fish, Fish$Valid.Name), function(df_sp) {
  sp_name <- df_sp$Valid.Name[1]
  
  # A. Filter out invalid or zero coordinates upfront
  coords <- as.matrix(df_sp[, c("Centroid.Longitude", "Centroid.Latitude")])
  valid_idx <- complete.cases(coords) & (coords[, 1] != 0 | coords[, 2] != 0)
  df_sp <- df_sp[valid_idx, ]
  n_rows <- nrow(df_sp)
  
  if (n_rows == 0) return(NULL)
  
  if (n_rows == 1) {
    df_sp$cluster <- 1
    df_sp$Spatial.distance <- 0
  } else {
    coords <- as.matrix(df_sp[, c("Centroid.Longitude", "Centroid.Latitude")])
    dist_mat <- distm(coords, fun = distHaversine)
    adj_mat  <- dist_mat <= 40000
    
    g <- graph_from_adjacency_matrix(adj_mat, mode = "undirected", diag = FALSE)
    df_sp$cluster <- components(g)$membership
    
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
                    "Date.ISO.8601",
                    "Vessel", 
                    "Centroid.Latitude", 
                    "Centroid.Longitude",
                    "Spatial.distance")]
  return(res)
})

Populations <- do.call(rbind, pop_list)
rownames(Populations) <- NULL

# End of Script