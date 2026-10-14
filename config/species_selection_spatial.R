# Exploratory extent comparison; these are maximum pairwise distances, NOT radii.
# Reuses the frozen first-pass lot screen and never overwrites its 80-species queue.
spatial_config <- list(
  lots = "Output/SpeciesSelection/screened_lots.csv",
  roster = "Output/SpeciesSelection/species_investigation_queue.csv",
  original_sensitivity = "Output/SpeciesSelection/sensitivity_scenarios.csv",
  original_membership = "Output/SpeciesSelection/sensitivity_species_membership.csv",
  output = "Output/SpeciesSelectionSpatial",
  sensitivity_diameters = c(20, 40, 80, 160, 240),
  sensitivity_specimens = c(10L, 20L, 30L),
  sensitivity_min_lots = c(1L, 2L),
  sensitivity_date_modes = c("all_assigned", "explicit_only"),
  sensitivity_last_years = c(1929L, 1930L),
  min_species = 3L
)
