library(dplyr)
library(stringr)
library(purrr)
library(openxlsx)

# 1. Species-level Sampling Region Classification

# Define geographic evaluation columns by name or index
geo_cols <- c(
  "Ocean", "Sea.Gulf", "Archipelago", "Island.Grouping", "Island.Name",
  "Continent", "Country", "Province.State", "District.County", 
  "Precise.Locality", "Centroid.Latitude", "Centroid.Longitude"
)

# Classify species regional occupancy based on concatenated geographic records
species_region_map <- Fish %>%
  group_by(Valid.Name) %>%
  summarise(
    # Concatenate all geographic strings per species into a single lower-case character string
    geo_text = paste(
      unlist(across(all_of(geo_cols), ~ as.character(.x))), 
      collapse = " "
    ) %>% str_to_lower(),
    .groups = "drop"
  ) %>%
  mutate(
    # Identify explicit geographic mentions via pattern matching
    has_gulf = str_detect(geo_text, "gulf of mexico|g. of mexico|gulf"),
    has_caribbean = str_detect(geo_text, "caribbean|carib|puerto rico|west indies|lesser antilles|greater antilles"),
    # Atlantic detection excludes explicit 'gulf' or 'caribbean' strings to prevent false positives
    has_atlantic = str_detect(geo_text, "atlantic") | (
      !has_gulf & !has_caribbean & str_detect(geo_text, "ocean|usa|united states|florida|virginia|north carolina|south carolina|georgia")
    ),
    
    # Classify into specific categorical outputs based on Boolean combinations
    Sampling_region = case_when(
      is.na(geo_text) | geo_text == "" | geo_text == "na" ~ "None",
      has_atlantic & has_gulf & has_caribbean            ~ "All",
      has_atlantic & has_gulf                            ~ "Atlantic and Gulf",
      has_atlantic & has_caribbean                       ~ "Atlantic and Caribbean",
      has_gulf & has_caribbean                           ~ "Gulf and Caribbean",
      has_atlantic                                       ~ "Atlantic",
      has_gulf                                           ~ "Gulf",
      has_caribbean                                      ~ "Caribbean",
      TRUE                                               ~ "None"
    )
  ) %>%
  select(Valid.Name, Sampling_region)

# 2. Construct CandidateTable_df

CandidateTable_df <- Fish %>%
  # Select and rename baseline attributes from Fish
  select(
    Catalog.Number...USNM = Catalog.Number...USNM,
    Order                = Order,
    Family               = Family,
    Species              = Valid.Name,
    `Common Name`        = Common.Name,
    Ocean                = Ocean,
    Location             = Precise.Locality
  ) %>%
  # Left join species-level region classification
  left_join(species_region_map, by = c("Species" = "Valid.Name")) %>%
  # Left join total population metrics from Species_summary_table
  left_join(
    Species_summary_table %>% 
      select(Species, Total_number_of_populations = `Total Pops`),
    by = "Species"
  ) %>%
  # Filter out records where total populations could not be mapped
  filter(!is.na(Total_number_of_populations),
         Catalog.Number...USNM %in% Populations_kmz$Catalog.Number...USNM) %>%
  # Instantiate explicit empty character vector for Chesapeake Bay populations
  mutate(
    `Populations in Chesapeake Bay` = ""
  ) %>%
  # Hierarchical Sorting
  arrange(
    desc(Total_number_of_populations),
    Order,
    Family,
    Species
  )

# Initialize workbook object with custom styles
wb <- createWorkbook()
addWorksheet(wb, "Candidate Table")

# Write data frame with bold header formatting
header_style <- createStyle(textDecoration = "bold", fgFill = "#D3D3D3")
writeData(wb, "Candidate Table", CandidateTable_df, headerStyle = header_style)

# Auto-adjust column widths based on content length
setColWidths(wb, "Candidate Table", cols = 1:ncol(CandidateTable_df), widths = "auto")

# Save workbook
saveWorkbook(wb, "./Output/Files/CandidateTable.xlsx", overwrite = TRUE)
