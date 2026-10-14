list(atlas = "Output/SamplingAtlas", raw = "Data/All_collections.csv", 
    output = "Output/SpeciesSelection", first_year = 1880L, last_year = 1930L, 
    diameter_km = 20, min_specimens = 10L, min_lots = 1L, min_species = 3L, 
    sensitivity_diameters = c(10, 20, 40), sensitivity_specimens = c(10L, 
    20L, 30L), sensitivity_min_lots = 1:2, sensitivity_date_modes = c("all_assigned", 
    "explicit_only"), sensitivity_last_years = 1929:1930)
