# This is a trash script. Do not run it.  I asked AI for help on a math problem
# which it was unable to understand.  If I scatter different color jelly beans
# on a table and say let's place the jelly beans into groups by color.  If I say
# one jelly bean is a population the nPop_max = N_jelly_max and my distance can be zero.
# But if I say 2 jelly beans of the same color is a population, then I have to
# set a distance value. What radius circle will include the most jelly beans and
# the most populations. That is the output of three functions.
# Population P(x) = the number of populations/the total number of populations
# possible [where the relationship of the number of jellybeans required to meet
# the minimum population parameter to distance is considered ](I think my bracketed statement might be an exponential component).
# Jelly bean S(x) = the summation of number of jelly beans included in the
# populations/the total number of Jelly beans
# I will find the ideal distance to measure E(x) where E(x) = P(x) * S(x)
# is the maximum value. Then I solve for d in the P(x) equation.


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