#In progress
#I am trying to get the math right before I ask R to do the following
# E = P_species(d) / P_total * S(d) / S_total.
# P_species(d) = Populations/distance. I need to constrain by minimum population siz
# if not I get 1/x behavior
# Where:
# • E is an efficiency score
# • P(d) is is the number of valid populations at distance d where each
# population contains at least twenty specimens.  This must be a function of the 
# change of the size of the population as the distance changes.  Maybe behaves like -x^2
# • S(d) is the total number of specimens included within those valid populations
# at distance d.  This must be another function
# • S_total ^2 (S subscript total squared) is the total number of specimens across the entire dataset
# That's a trash equation because the relationships between P S and d are not considered.
# The denominator is nonsensical to the problem.  Lets start over
# At d = 2500 km,  P = 591 max (P = 1 min), S = 20734, where the P_min is S = 1.  At d = 0 km,  P = 5027, S = 20734, where the P_min is S = 1.
# If I add a condition P_min is where S >= 20, then at d = 0, P < 5027, S < 20734
# As d increases S should increase, P may increase.  There should be a maximum point on a curve that behaves like -x^2
# I could try have a script run pop_kmz-inator setting a value for the radius distance
# and outputting the number of total populations across species and the number of specimens
# If I scatter different color jelly beans
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

sort(table(Fish$Valid.Name), decreasing = T)
length(unique(Fish$Valid.Name)) #591
sum(Fish$Specimen.Count, na.rm = T) #20734
nrow(Fish) #5027
length(unique(Populations$Populations.by.species)) #167 at 40 km
sum(Populations$Specimen.Count, na.rm = T) #12649


# VIII. Process Spatial Clusters and Build 'Populations' Data Frame
pop_list <- lapply(split(Fish, Fish$Valid.Name), function(df_sp) {
  sp_name <- df_sp$Valid.Name[1]
  
  # A. Filter out invalid or zero coordinates upfront
  coords <- as.matrix(df_sp[, c("Centroid.Longitude", "Centroid.Latitude")])
  valid_idx <- complete.cases(coords) & (coords[, 1] != 0 | coords[, 2] != 0)
  df_sp <- df_sp[valid_idx, ]
  n_rows <- nrow(df_sp)
  
  if (n_rows == 0) return(NULL)
  
  if (n_rows == 1) {
    df_sp$cluster <- 1
    df_sp$Spatial.distance <- 0
  } else {
    coords <- as.matrix(df_sp[, c("Centroid.Longitude", "Centroid.Latitude")])
    dist_mat <- distm(coords, fun = distHaversine)
    adj_mat  <- dist_mat <= 40000
    
    g <- graph_from_adjacency_matrix(adj_mat, mode = "undirected", diag = FALSE)
    df_sp$cluster <- components(g)$membership
    
    cluster_dists <- sapply(split(seq_len(n_rows), df_sp$cluster), function(idx) {
      if (length(idx) <= 1) return(0)
      sub_dist <- dist_mat[idx, idx, drop = FALSE]
      round(max(sub_dist) / 1000, 2)
    })
    
    df_sp$Spatial.distance <- as.numeric(cluster_dists[as.character(df_sp$cluster)])
  }
  
  cluster_totals <- tapply(df_sp$Specimen.Count, df_sp$cluster, sum)
  valid_clusters <- names(cluster_totals)[cluster_totals >= 20]
  
  if (length(valid_clusters) == 0) return(NULL)
  
  df_sub <- df_sp[df_sp$cluster %in% valid_clusters, ]
  
  cluster_map <- setNames(seq_along(valid_clusters), valid_clusters)
  pop_indices <- cluster_map[as.character(df_sub$cluster)]
  
  df_sub$Populations.by.species <- paste0("Population ", pop_indices, " of ", sp_name)
  
  res <- df_sub[, c("Populations.by.species", 
                    "Catalog.Number...USNM", 
                    "Specimen.Count", 
                    "Date.ISO.8601",
                    "Vessel", 
                    "Centroid.Latitude", 
                    "Centroid.Longitude",
                    "Spatial.distance")]
  return(res)
})

Populations <- do.call(rbind, pop_list)
rownames(Populations) <- NULL

# End of Script