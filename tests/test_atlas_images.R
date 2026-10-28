#!/usr/bin/env Rscript
# Run from the repository root after caching images and refreshing the atlas.
source("Scripts/sampling_atlas_functions.R")
config <- dget("Output/SamplingAtlas/resolved_config.R")
species <- unique(read.csv(file.path(config$output, "tables", "artifact_manifest.csv"))$species)
images <- read_atlas_images(species, config)
catalog <- read_char_csv(atlas_image_catalog())
eligible <- catalog$species[tolower(catalog$eligible_for_noncommercial_embedding) == "true"]
stopifnot(identical(images$species, species), nrow(images) == 80L,
  setequal(images$species[images$display_status == "embedded"], eligible), length(eligible) == 54L,
  sum(images$display_status == "source_link") == 26L)
for (i in seq_len(nrow(images))) {
  row <- images[i, ]; html <- paste(atlas_image_card_html(row), collapse = "\n")
  if (row$display_status == "embedded") {
    stopifnot(grepl(html_escape(row$attribution), html, fixed = TRUE),
      grepl(html_escape(row$license_url), html, fixed = TRUE),
      grepl(html_escape(row$image_page_url), html, fixed = TRUE),
      grepl(row$local_image, html, fixed = TRUE), !grepl('src="https://', html, fixed = TRUE))
  } else stopifnot(!grepl("<img", html, fixed = TRUE), grepl("https://", html, fixed = TRUE))
}
withheld <- images[images$species == "Myctophum opalinum", ]
stopifnot(withheld$local_image == "", grepl("taxonomic identity", atlas_image_card_html(withheld), fixed = TRUE))
proxy <- images[images$species == "Coelorinchus carminatus", ]
stopifnot(grepl("species aggregate proxy", paste(atlas_image_card_html(proxy), collapse = ""), fixed = TRUE))
# Missing local cache produces a source link, not a broken remote embed.
missing_config <- config; missing_config$output <- tempfile("missing_image_cache_")
missing <- read_atlas_images(species, missing_config)
stopifnot(sum(missing$display_status == "not_cached") == 54L, all(missing$local_image == ""))
for (page in c("index.html", "overview.html")) {
  html <- paste(readLines(file.path(config$output, page)), collapse = "\n")
  stopifnot(lengths(regmatches(html, gregexpr('class="species-photo"', html, fixed = TRUE))) == 54L,
    lengths(regmatches(html, gregexpr('class="species-image image-source-only"', html, fixed = TRUE))) == 26L)
}
checksums <- read.csv(file.path(config$output, "tables", "image_input_checksums.csv"))
stopifnot(identical(unname(tools::md5sum(checksums$path)), checksums$md5))
message("Image attachment checks passed: 80 exact species joins, 54 verified local images, 26 source links, attribution, taxonomy notes and missing-cache behavior.")
