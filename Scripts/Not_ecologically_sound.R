# This is a trash script
# E = P(d) * S(d) / S_total ^2
# Where:
# • E is an efficiency score
# • P(d) is is the number of valid populations at distance d where each
# population contains at least twenty specimens
# • S(d) is the total number of specimens included within those valid populations
# at distance d
# • S_total ^2 (S subscript total squared) is the total number of specimens across the entire dataset

library(dplyr)
library(geosphere)
library(cluster)

# Filter rows with valid coordinates and specimen counts
fish_max <- Fish %>%
  filter(!is.na(Centroid.Latitude) & !is.na(Centroid.Longitude) & !is.na(Specimen.Count))

s_total <- sum(fish_max$Specimen.Count)

# Pre-calculate distance matrices and hierarchical clustering trees for each species
species_list <- split(fish_max, fish_max$Valid.Name)

species_data <- lapply(species_list, function(df_sp) {
  n <- nrow(df_sp)
  rownames(df_sp) <- NULL
  if (n > 1) {
    coords <- df_sp[, c("Centroid.Longitude", "Centroid.Latitude")]
    dist_mat <- distm(coords, fun = distHaversine)
    hc <- hclust(as.dist(dist_mat), method = "complete")
    list(df = df_sp, hc = hc, n = n, single = FALSE)
  } else {
    list(df = df_sp, n = n, single = TRUE)
  }
})

# Define search sequence for distance thresholds d (e.g., 5 km to 500 km in 5 km steps)
distances <- seq(5000, 2500000, by = 5000)

results <- data.frame(Distance = numeric(), Pops = numeric(), Specs = numeric(), Efficiency = numeric())

for (d in distances) {
  total_pops <- 0
  total_specs <- 0
  
  for (sp in species_data) {
    if (sp$single) {
      if (sp$df$Specimen.Count[1] >= 20) {
        total_pops <- total_pops + 1
        total_specs <- total_specs + sp$df$Specimen.Count[1]
      }
    } else {
      clusters <- cutree(sp$hc, h = d)
      df_sp <- sp$df
      df_sp$Cluster <- clusters
      
      cluster_sums <- df_sp %>%
        group_by(Cluster) %>%
        summarise(GroupCount = sum(Specimen.Count), .groups = 'drop')
      
      valid_clusters <- cluster_sums %>% filter(GroupCount >= 20)
      
      total_pops <- total_pops + nrow(valid_clusters)
      total_specs <- total_specs + sum(valid_clusters$GroupCount)
    }
  }
  
  # Calculate efficiency score E(d)
  efficiency <- (total_pops * total_specs) / (s_total ^ 2)
  results <- rbind(results, data.frame(Distance = d, Pops = total_pops, Specs = total_specs, Efficiency = efficiency))
}

# Identify the optimal row maximizing efficiency
optimal_row <- results[which.max(results$Efficiency), ]
best_distance <- optimal_row$Distance

cat("Optimal Distance:", best_distance, "meters\n")

# Plot and save efficiency curve
pdf(file = "Efficiency_Curve.pdf", width = 8, height = 6)
plot(results$Distance / 1000, results$Efficiency, type = "l", col = "darkblue", lwd = 2,
     main = paste("Efficiency Optimization Curve (Optimal:", best_distance / 1000, "km)"),
     xlab = "Distance Threshold (km)", ylab = "Efficiency Score E(d)")
abline(v = best_distance / 1000, col = "red", lty = 2)
dev.off()