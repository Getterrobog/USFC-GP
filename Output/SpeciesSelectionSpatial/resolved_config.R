list(lots = "Output/SpeciesSelection/screened_lots.csv", roster = "Output/SpeciesSelection/species_investigation_queue.csv", 
    original_sensitivity = "Output/SpeciesSelection/sensitivity_scenarios.csv", 
    original_membership = "Output/SpeciesSelection/sensitivity_species_membership.csv", 
    output = "Output/SpeciesSelectionSpatial", sensitivity_diameters = c(20, 
    40, 80, 160, 240), sensitivity_specimens = c(10L, 20L, 30L
    ), sensitivity_min_lots = 1:2, sensitivity_date_modes = c("all_assigned", 
    "explicit_only"), sensitivity_last_years = 1929:1930, min_species = 3L)
