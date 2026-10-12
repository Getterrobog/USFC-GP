# All paths are relative to the repository root. No source data are modified.
atlas_config <- list(
  input = "Data/All_collections.csv",
  taxonomy = "Output/Files/species_validation_results.csv",
  curated_names = "Output/Files/All_Ships_Updated.csv",
  manual_names = "Output/Files/HumanSearch.csv",
  overrides = "config/sampling_overrides.csv",
  output = "Output/SamplingAtlas",
  min_specimens = 50L,             # DATED species total <= max_year, summed over stages
  max_year = 1930L,                # Undated lots shown separately; do NOT confer eligibility
  historical_end = 1930L,          # Descriptive sampling period, NOT a preservation test
  early_end = 1900L,
  cell_degrees = 1,                # Counts per geographic cell, not density per unit area
  min_cell_period_specimens = 10L, # Screening threshold for repeated historical sampling
  unknown_stage = "adult",         # 'adult' means non-larval / maturity unverified
  bounds = c(west = -100, east = -50, south = 5, north = 60),
  animation_years = "observed",    # 'observed' skips gaps explicitly; 'all' includes them
  frame_seconds = 0.65,
  width = 960L,
  height = 760L,
  render_gifs = TRUE,
  render_species = NULL            # Optional subset for previews; eligibility is unchanged
)
