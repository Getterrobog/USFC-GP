# All scientific grouping is performed in R from the existing record audit.
explorer_summaries <- function(records,species,config) {
  stages <- c("all","adult","larva","mixed")
  cells <- list();totals <- list()
  for(stage in stages) {
    d <- records[records$included & records$species %in% species & (stage=="all" | records$life_stage==stage),]
    z <- overview_cell_summary(d,species);z$map_stage <- rep(stage,nrow(z))
    cells[[stage]] <- z
    totals[[stage]] <- do.call(rbind,lapply(species,function(sp) {
      s <- d[d$species==sp,];c <- z[z$species==sp,]
      data.frame(species=sp,map_stage=stage,specimens=sum(s$specimen_count),lots=nrow(s),
        mapped_specimens=sum(c$specimens),recorded_specimens=sum(c$recorded_specimens),
        approximate_specimens=sum(c$approximate_specimens),unmapped_specimens=sum(s$specimen_count[!s$display_mapped]),
        undated_specimens=sum(s$specimen_count[is.na(s$year)]),cells=nrow(c),
        west=unname(config$bounds['west']),east=unname(config$bounds['east']),south=unname(config$bounds['south']),north=unname(config$bounds['north']),cell_degrees=config$cell_degrees)
    }))
  }
  c <- do.call(rbind,cells);rownames(c)<-NULL
  t <- do.call(rbind,totals);rownames(t)<-NULL
  c$fill <- rep(NA_character_,nrow(c));t$color_maximum <- rep(NA_real_,nrow(t))
  for(sp in species) {
    ix <- which(c$species==sp);maximum <- max(1,c$specimens[ix])
    c$fill[ix] <- palette_counts(c$specimens[ix],maximum)
    t$color_maximum[t$species==sp] <- maximum
  }
  list(cells=c,summary=t)
}

explorer_background <- function(coast,config) {
  b <- config$bounds;left<-70;top<-105;width<-740
  height <- width*(b['north']-b['south'])/(b['east']-b['west'])/cos(mean(b[c('south','north')])*pi/180)
  px <- function(lon) left+(lon-b['west'])/(b['east']-b['west'])*width
  py <- function(lat) top+(b['north']-lat)/(b['north']-b['south'])*height
  result <- c(sprintf('<rect x="70" y="105" width="740" height="%.2f" fill="#eef5f8" stroke="#a9b1b3"/>',height),'<g clip-path="url(#extent)">')
  for(ix in split(seq_along(coast$x),cumsum(is.na(coast$x)))) {
    ix <- ix[is.finite(coast$x[ix]) & is.finite(coast$y[ix])]
    if(length(ix)<3) next
    result <- c(result,sprintf('<polygon points="%s" fill="#e0e3df" stroke="#839196" stroke-width=".6"/>',paste(sprintf("%.2f,%.2f",px(coast$x[ix]),py(coast$y[ix])),collapse=" ")))
  }
  for(lon in seq(ceiling(b['west']/10)*10,b['east'],10)) result <- c(result,sprintf('<path d="M%.2f 105V%.2f" stroke="#cad9df" stroke-dasharray="3 5"/>',px(lon),top+height))
  for(lat in seq(ceiling(b['south']/10)*10,b['north'],10)) result <- c(result,sprintf('<path d="M70 %.2fH810" stroke="#cad9df" stroke-dasharray="3 5"/>',py(lat)))
  result <- c(result,'</g>')
  for(lon in seq(ceiling(b['west']/10)*10,b['east'],10)) result <- c(result,sprintf('<text x="%.2f" y="%.2f" font-size="14" text-anchor="middle">%g°W</text>',px(lon),top+height+23,abs(lon)))
  for(lat in seq(ceiling(b['south']/10)*10,b['north'],10)) result <- c(result,sprintf('<text x="58" y="%.2f" font-size="14" text-anchor="end">%g°N</text>',py(lat)+5,lat))
  paste(result,collapse="\n")
}

build_sampling_explorer <- function(config) {
  out <- config$output
  inputs <- unique(c(file.path(out,c("resolved_config.R","overview.html","index.html","tables/records_audit.csv","tables/artifact_manifest.csv","tables/overview_cells.csv")),
    "Scripts/build_sampling_explorer.R","Scripts/sampling_explorer.R","Scripts/sampling_explorer.js","Scripts/sampling_explorer_map.js","Scripts/sampling_explorer.css",
    "Scripts/sampling_atlas_functions.R","Scripts/sampling_atlas_locations.R","Scripts/sampling_atlas_report.R","Scripts/sampling_atlas_overview.R",
    "Scripts/sampling_atlas_traits.R","Scripts/sampling_atlas_taxonomy.R","Scripts/sampling_atlas_images.R","Scripts/sampling_atlas_genomics.R",
    "Scripts/genomics_maps.R","Scripts/genomics_filters.js","Scripts/trait_filters.js","Scripts/trait_styles.css",
    atlas_trait_inputs(config),atlas_taxonomy_inputs(config),atlas_genomics_inputs(config),atlas_image_inputs(config)))
  before <- tools::md5sum(inputs);if(anyNA(before))stop("Missing explorer input")
  records <- read.csv(file.path(out,"tables/records_audit.csv"),stringsAsFactors=FALSE)
  manifest <- read.csv(file.path(out,"tables/artifact_manifest.csv"),stringsAsFactors=FALSE)
  species <- sort(unique(manifest$species))
  summaries <- explorer_summaries(records,species,config)
  taxonomy <- read_atlas_taxonomy(species,records,config)
  traits <- read_atlas_traits(species,config)
  genomics <- read_atlas_genomics(species,config)
  images <- read_atlas_images(species,config)
  filters <- atlas_filter_counts(records,species,config)
  coast <- maps::map("world",plot=FALSE,fill=TRUE,xlim=config$bounds[c('west','east')],ylim=config$bounds[c('south','north')])
  payload <- list(species=species,cells=summaries$cells,summary=summaries$summary,filters=filters,
    bounds=as.list(config$bounds),cellDegrees=config$cell_degrees,
    legend=data.frame(position=seq(0,1,length.out=128),fill=palette_counts(expm1(seq(0,1,length.out=128)*log1p(100)),100)))
  lines <- c('<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Historical sampling explorer</title><style>',
    readLines("Scripts/sampling_explorer.css"),readLines("Scripts/trait_styles.css"),'</style><body>',
    '<h1>Historical sampling explorer</h1><nav><a href="overview.html">Original all-species overview</a> · <a href="index.html">Annual maps and animations</a> · <a href="../Genomics/maps.html">Genomic sampling maps</a></nav>',
    '<noscript><p>This interactive explorer requires JavaScript. Open the <a href="overview.html">original overview</a> to browse saved maps without JavaScript.</p></noscript>',
    '<p>One fish, one map. Search for a species, then select the life stage to plot. Numbered grid cells connect to labels showing year (specimens), including undated lots.</p>',
    '<form id="filters"><details class="filters"><summary><strong>Filter selectable species</strong> <span id="filter-count"></span></summary><div class="filter-grid">',
    atlas_taxonomy_filter_html(taxonomy),
    sprintf('<label>Minimum dated specimens<input id="min-specimens" type="number" min="0" step="1" value="%s"></label>',config$min_specimens),
    '<label>Minimum sampled years<input id="min-years" type="number" min="1" step="1" value="1"></label><label>Region for specimen thresholds<select id="region"><option value="">All regions</option><option>Atlantic</option><option>Caribbean</option><option>Gulf of Mexico</option></select></label></div>',
    '<label class="filter-check"><input id="mapped-only" type="checkbox"> Thresholds count only specimens with recorded coordinates</label>',
    atlas_genomics_filter_html(),atlas_trait_filter_html(traits),
    sprintf('<p>Filters determine which of the %s eligible species can be selected. Specimen/year thresholds use dated records through %s across all life stages within the chosen region. Trait and genomic filters select species. Only the separate map life-stage control changes the plotted data; maps retain all included regions and years, including undated lots.</p>',length(species),config$max_year),
    '<button type="reset">Reset species filters</button></details></form>',
    '<section class="selection" aria-label="Map selection"><div class="species-picker"><label for="species-search">Species — search scientific or common name</label><div class="combo"><input id="species-search" type="text" role="combobox" aria-autocomplete="list" aria-controls="species-options" aria-expanded="false" autocomplete="off" placeholder="Search or choose a fish"><button id="species-toggle" type="button" aria-label="Show selectable species" aria-controls="species-options" aria-expanded="false">▾</button></div><ul id="species-options" role="listbox" aria-label="Selectable species" hidden></ul><p id="search-status" role="status"></p></div>',
    '<label for="map-stage">Map life stage<select id="map-stage"><option value="all">All life stages</option><option value="adult">Adult / non-larval</option><option value="larva">Larva</option><option value="mixed">Mixed lots</option></select></label></section>',
    '<p id="selection-status" role="status" aria-live="polite"></p><p id="empty-results" hidden>No species match these filters. Reset or relax the filters to select a fish.</p>',
    '<main id="selected-view"><div id="species-heading"></div><p id="map-summary"></p>',
    sprintf('<p class="extent">Fixed extent: %g–%g°W, %g–%g°N · %g° cells. Hatching marks approximate positions. Adult / non-larval includes juveniles and unlabeled lots; maturity is unverified.</p>',-config$bounds['west'],-config$bounds['east'],config$bounds['south'],config$bounds['north'],config$cell_degrees),
    '<div class="map-tools"><button id="enlarge-map" type="button" aria-pressed="false">Enlarge labels</button><button id="download-map" type="button">Download selected map (SVG)</button></div>',
    '<div class="map-viewport" tabindex="0" role="region" aria-label="Selected species geographic heatmap"><div id="map-host"></div></div>',
    '<p>Colors count specimens, not abundance, and use one scale across life stages within the selected species. Blank cells mean no plotted sampling. Approximate positions are display estimates, not verified sites.</p>',
    '<details><summary>Grid-cell years and specimen counts</summary><div id="cell-table" class="table-scroll"></div></details>',
    '<div id="species-details"></div></main>',
    '<footer><a href="tables/explorer_summary.csv">Species/stage totals</a> · <a href="tables/explorer_cells.csv">Species/stage grid cells</a> · <a href="tables/records_audit.csv">Original record audit</a> · <a href="tables/approximate_locations.csv">Location evidence</a> · <a href="README.md">Documentation</a></footer>')
  for(sp in species) {
    tax <- taxonomy[taxonomy$species==sp,]
    label <- paste0(sp,if(nzchar(tax$common_name))paste0(" — ",tax$common_name)else "")
    lines <- c(lines,sprintf('<template class="species-template" id="%s" data-species="%s" data-label="%s" data-order="%s" data-family="%s">',slug(sp),html_escape(sp),html_escape(label),html_escape(tax$order),html_escape(tax$family)),
      '<div class="identity">',atlas_taxonomy_heading_html(tax),if(!is.null(images)) atlas_image_card_html(images[images$species==sp,]),'</div>',
      '<details class="species-information"><summary>Species traits, genomic availability and sources</summary>',
      atlas_trait_card_html(traits$traits[traits$traits$species==sp,],traits),atlas_genomics_card_html(genomics$summary[genomics$summary$species==sp,]),'</details></template>')
  }
  lines <- c(lines,'<template id="map-background"><svg xmlns="http://www.w3.org/2000/svg">',explorer_background(coast,config),'</svg></template>',
    '<script id="explorer-data" type="application/json">',gm_json(payload),'</script><script>',
    readLines("Scripts/genomics_filters.js"),readLines("Scripts/trait_filters.js"),readLines("Scripts/sampling_explorer_map.js"),readLines("Scripts/sampling_explorer.js"),'</script></body></html>')
  stopifnot(identical(unname(before),unname(tools::md5sum(inputs))))
  writeLines(lines,file.path(out,"explorer.html"),useBytes=TRUE)
  write.csv(summaries$cells,file.path(out,"tables/explorer_cells.csv"),row.names=FALSE,na="")
  write.csv(summaries$summary,file.path(out,"tables/explorer_summary.csv"),row.names=FALSE,na="")
  write.csv(data.frame(path=inputs,md5=unname(before)),file.path(out,"tables/explorer_input_checksums.csv"),row.names=FALSE)
  writeLines(capture.output(sessionInfo()),file.path(out,"explorer_session_info.txt"))
}
