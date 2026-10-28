list(input = "Data/All_collections.csv", taxonomy = "Output/Files/species_validation_results.csv", 
    curated_names = "Output/Files/All_Ships_Updated.csv", manual_names = "Output/Files/HumanSearch.csv", 
    overrides = "config/sampling_overrides.csv", locality_anchors = "config/sampling_locality_anchors.csv", 
    approximate_locations = TRUE, output = "Output/SamplingAtlas", 
    min_specimens = 50L, max_year = 1930L, historical_end = 1930L, 
    early_end = 1900L, cell_degrees = 2, min_cell_period_specimens = 10L, 
    unknown_stage = "adult", bounds = c(west = -100, east = -50, 
    south = 5, north = 60), animation_years = "observed", frame_seconds = 0.65, 
    width = 960L, height = 760L, render_gifs = TRUE, render_species = NULL)
