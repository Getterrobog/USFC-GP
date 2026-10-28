# Optional species illustrations, joined on exact project names from the catalog.
atlas_image_catalog <- function() "Output/FishImages/fish_images_80_species.csv"

atlas_image_sha256 <- function(path) {
  binary <- Sys.which("sha256sum")
  if (!nzchar(binary)) stop("sha256sum is required to verify cached species images.")
  result <- system2(binary, shQuote(path), stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(result, "status"))) stop("Cannot hash species image: ", path)
  sub(" .*", "", result[1])
}

atlas_image_path <- function(row) {
  extension <- tolower(tools::file_ext(row$picture_filename))
  if (!extension %in% c("jpg", "jpeg", "png", "gif")) stop("Unsupported species-image type.")
  file.path("images", paste0(slug(row$species), "_", row$picture_id, ".", extension))
}

read_atlas_images <- function(species, config) {
  path <- atlas_image_catalog()
  if (!file.exists(path)) return(NULL)
  catalog <- read_char_csv(path)
  if (anyDuplicated(catalog$species) || any(!nzchar(catalog$species))) stop("Species-image keys must be unique and nonblank.")
  if (!all(species %in% catalog$species)) stop("Species-image catalog is missing atlas species.")
  out <- catalog[match(species, catalog$species), ]; rownames(out) <- NULL
  out$local_image <- ""; out$display_status <- "source_link"
  allowed <- tolower(out$eligible_for_noncommercial_embedding) == "true"
  for (i in which(allowed)) {
    r <- out[i, ]
    if (r$image_status != "verified_image_response" || tolower(r$page_image_match) != "true" ||
        !nzchar(r$credit) || !nzchar(r$attribution) || !nzchar(r$license_url) ||
        !r$reuse_status %in% c("attribution_required", "attribution_noncommercial") ||
        grepl("withheld", r$taxon_match_status, fixed = TRUE))
      stop("Inconsistent embedding eligibility in species-image catalog: ", r$species)
    relative <- atlas_image_path(r); local <- file.path(config$output, relative)
    out$display_status[i] <- "not_cached"
    if (!file.exists(local)) next
    if (file.info(local)$size != as.numeric(r$image_bytes) || atlas_image_sha256(local) != r$image_sha256)
      stop("Species image differs from its verified catalog bytes: ", r$species)
    out$local_image[i] <- relative; out$display_status[i] <- "embedded"
  }
  out
}

atlas_image_inputs <- function(config) {
  paths <- c(atlas_image_catalog(), file.path(config$output, "images", "download_manifest.csv"))
  if (dir.exists(file.path(config$output, "images"))) paths <- c(paths,
    list.files(file.path(config$output, "images"), pattern = "\\.(jpg|jpeg|gif|png)$", full.names = TRUE))
  paths[file.exists(paths)]
}

write_atlas_image_table <- function(images, config) {
  if (is.null(images)) return(invisible(NULL))
  write.csv(images, file.path(config$output, "tables", "species_images.csv"), row.names = FALSE, na = "")
  inputs <- c(atlas_image_inputs(config), "Scripts/sampling_atlas_images.R", "Scripts/cache_sampling_atlas_images.R")
  write.csv(data.frame(path = inputs, md5 = unname(tools::md5sum(inputs))),
    file.path(config$output, "tables", "image_input_checksums.csv"), row.names = FALSE)
}

atlas_image_link <- function(url, label) {
  if (!nzchar(url)) return("")
  if (!grepl("^https://", url)) stop("Species-image links must use HTTPS.")
  sprintf('<a href="%s" target="_blank" rel="noopener noreferrer">%s</a>', html_escape(url), html_escape(label))
}

atlas_image_card_html <- function(row) {
  if (is.null(row)) return(character())
  source <- atlas_image_link(row$image_page_url, "Image source")
  if (row$display_status == "embedded") {
    stage <- if (row$life_stage == "unsexed") "Unsexed; maturity unverified" else row$life_stage
    lines <- c('<figure class="species-image">',
      sprintf('<a href="%s"><img class="species-photo" loading="lazy" decoding="async" src="%s" alt="%s — representative species illustration (%s)"></a>',
        html_escape(row$local_image), html_escape(row$local_image), html_escape(row$species), html_escape(row$image_type)),
      '<p class="image-error" hidden>Image unavailable locally. Use the image source link below.</p>',
      sprintf('<figcaption>%s<br>%s · %s<br><span class="image-stage">%s · Source stage: %s</span>',
        html_escape(row$attribution), source, atlas_image_link(row$license_url, row$license), html_escape(row$image_type), html_escape(stage)))
    if (row$taxon_match_status != "exact_accepted_name") lines <- c(lines,
      sprintf('<br>Source identification: <i>%s</i> (%s); project species name retained.',
        html_escape(row$fishbase_name), html_escape(gsub("_", " ", row$taxon_match_status))))
    c(lines, '</figcaption></figure>')
  } else {
    note <- if (row$display_status == "not_cached") "Illustration available; local image has not been cached."
      else if (row$reuse_status == "permission_required" || row$supplemental_reuse_status == "permission_required")
        "Image catalog marks this illustration as requiring permission for reuse."
      else "Historical illustration available; the catalog flags its taxonomic identity for review."
    if (!nzchar(source)) source <- atlas_image_link(row$supplemental_source_url, "View source illustration")
    caption <- if (nzchar(row$attribution)) row$attribution else row$supplemental_caption
    sprintf('<aside class="species-image image-source-only"><p>%s %s</p><p class="image-credit">%s</p></aside>',
      html_escape(note), source, html_escape(caption))
  }
}
