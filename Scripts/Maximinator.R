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