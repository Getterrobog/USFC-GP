library(rfishbase)
library(dplyr)

# 1. rfishbase can't handle by row iteration from a data.frame.  It needs a vector
taxa_vector <- as.character(Valid_species$Valid_Name)

# 2. Query species() to retrieve the single official FishBase common name (FBname)
primary_names <- species(species_list = taxa_vector) %>%
  select(Valid_Name = Species, Common_name = FBname)

# 3. Join back to your original 853-row data frame
Valid_species <- left_join(Valid_species, primary_names, by = "Valid_Name")