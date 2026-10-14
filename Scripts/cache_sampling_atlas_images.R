#!/usr/bin/env Rscript
# Cache only catalog-approved noncommercial illustrations, preserving exact bytes.
# Usage: Rscript Scripts/cache_sampling_atlas_images.R [--download] [Output/SamplingAtlas]
args <- commandArgs(trailingOnly = TRUE)
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])
setwd(normalizePath(file.path(dirname(script), "..")))
source("Scripts/sampling_atlas_functions.R")
download <- "--download" %in% args
positional <- args[args != "--download"]
if (length(positional) > 1 || any(grepl("^--", positional))) stop("Unexpected argument.")
out <- if (length(positional)) positional else "Output/SamplingAtlas"
catalog <- read_char_csv(atlas_image_catalog())
config <- list(output = out)
# Validate catalog eligibility before accessing any images.
images <- read_atlas_images(catalog$species, config)
selected <- images[tolower(images$eligible_for_noncommercial_embedding) == "true", ]
dir.create(file.path(out, "images"), recursive = TRUE, showWarnings = FALSE)
manifest_path <- file.path(out, "images", "download_manifest.csv")
old <- if (file.exists(manifest_path)) read_char_csv(manifest_path) else NULL
options(timeout = max(60, getOption("timeout")))
manifest <- lapply(seq_len(nrow(selected)), function(i) {
  row <- selected[i, ]; relative <- atlas_image_path(row); path <- file.path(out, relative)
  retrieved <- if (!is.null(old) && row$species %in% old$species) old$retrieved_utc[match(row$species, old$species)] else ""
  if (!file.exists(path)) {
    if (!download) stop("Image not cached for ", row$species, ". Use --download to retrieve approved images.")
    if (!grepl("^https://www[.]fishbase[.]se/images/species/", row$image_url)) stop("Unexpected source-image host.")
    message(sprintf("[%s/%s] Downloading %s", i, nrow(selected), row$species))
    temp <- tempfile("image_", tmpdir = file.path(out, "images"))
    tryCatch({
      status <- download.file(row$image_url, temp, method = "libcurl", mode = "wb", quiet = TRUE)
      if (status != 0 || file.info(temp)$size != as.numeric(row$image_bytes) || atlas_image_sha256(temp) != row$image_sha256)
        stop("Downloaded image does not match the catalog: ", row$species)
      if (!file.rename(temp, path)) stop("Could not save image: ", path)
    }, finally = if (file.exists(temp)) unlink(temp))
    retrieved <- format(Sys.time(), tz = "UTC", usetz = TRUE)
  }
  if (!nzchar(retrieved)) retrieved <- format(file.info(path)$mtime, tz = "UTC", usetz = TRUE)
  data.frame(species = row$species, local_image = relative, source_url = row$image_url,
    image_sha256 = atlas_image_sha256(path), bytes = file.info(path)$size,
    retrieved_utc = retrieved, changes = "None; original source bytes preserved")
})
write.csv(do.call(rbind, manifest), manifest_path, row.names = FALSE)
message("Verified ", nrow(selected), " cached illustrations. Run Scripts/refresh_sampling_atlas_index.R to update both pages.")
