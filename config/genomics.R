# Public genomic metadata inventory. Worldwide discovery; atlas window is a filter.
genomics_config <- list(
  roster = "Output/SpeciesSelection/species_investigation_queue.csv",
  input = "Data/Genomics/normalized",
  output = "Output/Genomics",
  nominal_low_depth_max = 10, # Screening estimate only, never measured mapped coverage
  historical_end = 1930L,
  bounds = c(west = -100, east = -50, south = 5, north = 60),
  cell_degrees = 2
)
