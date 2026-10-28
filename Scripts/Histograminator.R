# Histograminator.R
# Purpose: The purpose of this script is to produce histograms to allow the
# visualization of the temporal span of species collections.
# Author: Iván R. López Martínez. 10 Sep 2026.
# email: ivan.r.lopez@hotmail.com
# I used R version 4.6.1 (2026-06-24) -- "Happy Hop"
# I used Gemini AI to troubleshoot.
# Adds Populations_plot df, Populations_plot_filtered df, species_list vector

library(dplyr)
library(ggplot2)

# I. Create Histograms
# A. Extract Year directly from standardized Date.ISO.8601 or assign UNDATED
raw_years_vec <- ifelse(
  is.na(Populations$Date.ISO.8601) | Populations$Date.ISO.8601 == "", 
  "UNDATED", 
  substr(Populations$Date.ISO.8601, 1, 4)
)

# B. Determine timeline boundaries 1880 and 2025 are defaults
numeric_years <- suppressWarnings(as.numeric(raw_years_vec))
valid_years   <- numeric_years[!is.na(numeric_years)]

if (length(valid_years) == 0) {
  earliest_year <- 1880
  latest_year   <- 2025
} else {
  earliest_year <- min(valid_years)
  latest_year   <- max(valid_years)
}

# C. Build Populations_plot
Populations_plot <- Populations %>%
  mutate(
    Raw_Year   = raw_years_vec,
    Valid.Name = sub("^Population \\d+ of ", "", Populations.by.species),
    Lot_ID     = as.character(Catalog.Number...USNM),
    Num_Year   = suppressWarnings(as.numeric(Raw_Year)),
    X_Bin      = case_when(
      Raw_Year == "UNDATED" ~ -1,
      TRUE ~ Num_Year - earliest_year
    )
  )

# D. Configure Dataset Cutoff Filter
cutoff_year <- 1947
cutoff_type <- "upper" # Options: "upper" (keep <= cutoff_year) or "lower" (keep >= cutoff_year)
include_undated <- TRUE # Keep UNDATED records when applying upper cutoff

Populations_plot_filtered <- if (!is.null(cutoff_year)) {
  if (cutoff_type == "upper") {
    Populations_plot %>% 
      filter((include_undated & Raw_Year == "UNDATED") | (!is.na(Num_Year) & Num_Year <= cutoff_year))
  } else if (cutoff_type == "lower") {
    Populations_plot %>% 
      filter(!is.na(Num_Year) & Num_Year >= cutoff_year)
  } else {
    Populations_plot
  }
} else {
  Populations_plot
}

# E. Construct bins and axis breaks based on filtered dataset
filtered_num_years <- suppressWarnings(as.numeric(Populations_plot_filtered$Raw_Year))
filtered_valid_years <- filtered_num_years[!is.na(filtered_num_years)]

if (length(filtered_valid_years) == 0) {
  plot_earliest <- earliest_year
  plot_latest   <- latest_year
} else {
  plot_earliest <- min(filtered_valid_years)
  plot_latest   <- max(filtered_valid_years)
}

if (plot_earliest == plot_latest) {
  seq_years <- plot_earliest
} else {
  seq_years <- seq(plot_earliest, plot_latest, by = 1)
}

# F. Check if UNDATED exists in filtered output to include -1 bin
has_undated  <- "UNDATED" %in% Populations_plot_filtered$Raw_Year

if (has_undated) {
  year_bins    <- unique(sort(c(-1.5, -0.5, seq_years - earliest_year + 0.5)))
  year_labels  <- c("UNDATED", as.character(seq_years))
  break_points <- c(-1, seq_years - earliest_year)
} else {
  year_bins    <- unique(sort(seq_years - earliest_year + 0.5))
  year_bins    <- c(min(seq_years - earliest_year) - 0.5, year_bins)
  year_labels  <- as.character(seq_years)
  break_points <- seq_years - earliest_year
}

if (length(seq_years) > 1) {
  display_mask <- if (has_undated) {
    c(TRUE, (seq_years %% 5 == 0 | seq_years == plot_earliest | seq_years == plot_latest))
  } else {
    (seq_years %% 5 == 0 | seq_years == plot_earliest | seq_years == plot_latest)
  }
} else {
  display_mask <- if (has_undated) c(TRUE, TRUE) else TRUE
}

break_points_sub <- break_points[display_mask]
year_labels_sub  <- year_labels[display_mask]

# G. Plot Combined Histogram by Vessel
p_all_vessel <- ggplot(Populations_plot_filtered, aes(x = X_Bin, weight = Specimen.Count, fill = Vessel)) +
  geom_histogram(breaks = year_bins, color = "black", linewidth = 0.2) +
  scale_x_continuous(breaks = break_points_sub, labels = year_labels_sub) +
  labs(
    title = paste0("USFC Collections: Specimen Count by Vessel", 
                   if(!is.null(cutoff_year)) paste0(" (", cutoff_type, " bound is ", cutoff_year, ")") else ""),
    x = "Collection Year",
    y = "Specimen Count",
    fill = "Vessel"
  ) +
  theme_bw() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "bottom"
  )

ggsave("./Output/Figures/Histogram_All_Species_By_Vessel.png", p_all_vessel, width = 10, height = 6, dpi = 300)

# H. Plot Individual Species Histograms (Sorted by Pops, then Specimen Count)
species_list <- Populations_plot_filtered %>%
  group_by(Valid.Name) %>%
  summarize(
    total_pops  = n_distinct(Populations.by.species),
    total_specs = sum(Specimen.Count, na.rm = TRUE),
    .groups     = "drop"
  ) %>%
  arrange(desc(total_pops), desc(total_specs), Valid.Name) %>%
  pull(Valid.Name)

vessel_colors <- c(
  "Fish Hawk"    = "#FF9999",
  "Grampus"      = "#87CEFA",
  "Albatross"    = "#FFFACD",
  "Albatross II" = "#00FF00",
  "Albatross III"= "#0000FF",
  "Albatross IV" = "#FF0000"
)


pdf("./Output/Figures/Histograms_By_Species.pdf", width = 10, height = 6)

for (sp in species_list) {
  df_sp <- Populations_plot_filtered %>% filter(Valid.Name == sp)
  
  if (nrow(df_sp) == 0) next
  
  total_sp_specs <- sum(df_sp$Specimen.Count, na.rm = TRUE)
  total_sp_pops  <- length(unique(df_sp$Populations.by.species))
  
  p_sp <- ggplot(df_sp, aes(x = X_Bin, weight = Specimen.Count, fill = Vessel)) +
    geom_histogram(breaks = year_bins, color = "black", linewidth = 0.3) +
    scale_x_continuous(breaks = break_points_sub, labels = year_labels_sub) +
    scale_fill_manual(values = vessel_colors, drop = FALSE) +
    labs(
      title    = bquote(italic(.(sp))),
      subtitle = paste0("Total Specimens: ", total_sp_specs, " | Total Populations (40 km R): ", total_sp_pops),
      x        = "Collection Year",
      y        = "Specimen Count",
      fill     = "Vessel"
    ) +
    theme_bw() +
    theme(
      axis.text.x      = element_text(angle = 45, hjust = 1),
      legend.position = "right",
      plot.title      = element_text(face = "bold", size = 12),
      plot.subtitle   = element_text(size = 10)
    )
  
  print(p_sp)
}

dev.off()

# End of Script