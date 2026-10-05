# PRfixinator
# The purpose of this scrip is to add PR manual plots to Fish data.frame
# Author: Iván R. López Martínez. 10 Sep 2026.
# I used R version 4.6.1 (2026-06-24) -- "Happy Hop"
# I used Gemini AI to troubleshoot.
library(readxl)
library(dplyr)
library(tibble)
library(lubridate)

PR_plots <- read_xlsx("Data/Plotted.xlsx", skip =3)[,-c(2,4,5,7:17,20:24)]
# Standardize column names to prevent space/special character issues
# Adjust indices if your column positions shifted after subsetting:
# PR_plots should contain: Station.No, "Station.No.","Locality.and.exact.position.α",
# "Dredging.instruments.","Lat.dec","Long.dec","Index.Date"    
colnames(PR_plots) <- make.names(colnames(PR_plots))
# Insert ISO 8601 column after Long.dec
PR_plots <- add_column(PR_plots, Date.ISO.8601 = "", .after = "Long.dec")
# Parse Index.Date into Date.ISO.8601
PR_plots <- PR_plots %>%
  mutate(
    Date.ISO.8601 = format(dmy(Index.Date), "%Y-%m-%d")
  )

# ==============================================================================
# I.C.1 Integration of PR_plots Reference Data (Empty Strings Preserved)
# ==============================================================================

# 1. Clean and standardize PR_plots reference keys
PR_plots_clean <- PR_plots %>%
  mutate(
    Station_Key = trimws(as.character(as.integer(Station.No.))),
    Date.ISO.8601_PR = format(lubridate::dmy(Index.Date), "%Y-%m-%d"),
    Lat_PR  = as.numeric(Lat.dec),
    Long_PR = as.numeric(Long.dec)
  ) %>%
  filter(!is.na(Station_Key) & Station_Key != "") %>%
  select(Station_Key, Lat_PR, Long_PR, Date.ISO.8601_PR) %>%
  distinct(Station_Key, .keep_all = TRUE)

# 2. Join PR_plots reference data non-destructively onto Fish
Fish <- Fish %>%
  mutate(temp_station_key = trimws(as.character(Station))) %>%
  left_join(PR_plots_clean, by = c("temp_station_key" = "Station_Key")) %>%
  mutate(
    # Impute Latitude; preserve NA or retain prior numeric value
    Centroid.Latitude = case_when(
      (is.na(Centroid.Latitude) | Centroid.Latitude == "") & !is.na(Lat_PR) ~ Lat_PR,
      TRUE ~ Centroid.Latitude
    ),
    # Impute Longitude; preserve NA or retain prior numeric value
    Centroid.Longitude = case_when(
      (is.na(Centroid.Longitude) | Centroid.Longitude == "") & !is.na(Long_PR) ~ Long_PR,
      TRUE ~ Centroid.Longitude
    ),
    # Impute Date.ISO.8601; force ALL missing, NA, or unmapped dates to ""
    Date.ISO.8601 = case_when(
      !is.na(Date.ISO.8601) & Date.ISO.8601 != "" ~ as.character(Date.ISO.8601),
      !is.na(Date.ISO.8601_PR) & Date.ISO.8601_PR != "" ~ as.character(Date.ISO.8601_PR),
      TRUE ~ ""
    )
  ) %>%
  # Explicitly replace any remaining NA in Date.ISO.8601 with ""
  mutate(Date.ISO.8601 = ifelse(is.na(Date.ISO.8601), "", Date.ISO.8601)) %>%
  # Remove temporary joining keys and auxiliary reference columns
  select(-temp_station_key, -Lat_PR, -Long_PR, -Date.ISO.8601_PR)