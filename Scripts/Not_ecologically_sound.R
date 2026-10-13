# This is a trash script
# E = P(d) * S(d) / S_total ^2
# Where:
# • E is an efficiency score
# • P(d) is is the number of valid populations at distance d where each
# population contains at least twenty specimens
# • S(d) is the total number of specimens included within those valid populations
# at distance d
# • S_total ^2 (S subscript total squared) is the total number of specimens across the entire dataset
# That's a trash equation because the relationships between P S and d are not considered.
# The denominator is nonsensical to the problem.  Lets start over
# At d = 2500 km,  P = 591 max (P = 1 min), S = 20734, where the P_min is S = 1.  At d = 0 km,  P = 5027, S = 20734, where the P_min is S = 1.
# If I add a condition P_min is where S >= 20, then at d = 0, P < 5027, S < 20734
# As d increases S should increase, P may increase.  There should be a maximum point on a curve that behaves like -x^2
# I could try have a script run pop_kmz-inator setting a value for the radius distance
# and outputting the number of total populations across species and the number of specimens

sort(table(Fish$Valid.Name), decreasing = T)
length(unique(Fish$Valid.Name)) #591
sum(Fish$Specimen.Count, na.rm = T) #20734
nrow(Fish) #5027

# Start of garbage in
library(dplyr)
library(geosphere)
library(cluster)

# Filter rows with valid coordinates and specimen counts
fish_max <- Fish %>%
  filter(!is.na(Centroid.Latitude) & !is.na(Centroid.Longitude) & !is.na(Specimen.Count))

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

# Define search sequence (e.g., 1 km up to 300 km in 1 km steps, or your target range)
distances <- seq(1000, 300000, by = 1000)

results <- data.frame(Distance = numeric(), Pops = numeric(), Specs = numeric())

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
  
  results <- rbind(results, data.frame(Distance = d, Pops = total_pops, Specs = total_specs))
}

# Apply min-max normalization across the evaluated range to equally weight Pops and Specs
p_min <- min(results$Pops)
p_max <- max(results$Pops)
s_min <- min(results$Specs)
s_max <- max(results$Specs)

results <- results %>%
  mutate(
    Norm_Pops = (Pops - p_min) / (p_max - p_min),
    Norm_Specs = (Specs - s_min) / (s_max - s_min),
    Balanced_Score = Norm_Pops * Norm_Specs
  )

# Identify the optimal row maximizing the balanced score
optimal_row <- results[which.max(results$Balanced_Score), ]
best_distance <- optimal_row$Distance

cat("Optimal Balanced Distance:", best_distance / 1000, "km\n")

# Plot and save curve
pdf(file = "Balanced_Range.pdf", width = 8, height = 6)
plot(results$Distance / 1000, results$Balanced_Score, type = "l", col = "darkblue", lwd = 2,
     main = paste("Balanced Optimization Curve (Optimal:", best_distance / 1000, "km)"),
     xlab = "Distance Threshold (km)", ylab = "Balanced Score")
abline(v = best_distance / 1000, col = "red", lty = 2)
dev.off()

#End of garbage out