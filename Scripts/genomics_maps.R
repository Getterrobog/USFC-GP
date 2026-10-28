# Scientific selection and map-cell export in base R; browser interaction is local.
gm_json <- function(x) {
  quote_string <- function(z) {
    z <- gsub("\\", "\\\\", enc2utf8(z), fixed=TRUE)
    z <- gsub('"','\\"',z,fixed=TRUE)
    for(i in c(1:31,60,62,38)) z <- gsub(intToUtf8(i),sprintf("\\u%04x",i),z,fixed=TRUE)
    paste0('"',z,'"')
  }
  if(is.data.frame(x)) return(gm_json(lapply(seq_len(nrow(x)),function(i) as.list(x[i,,drop=FALSE]))))
  if(is.list(x)) {
    values <- vapply(x,gm_json,"")
    if(!is.null(names(x))) return(paste0("{",paste(paste0(vapply(names(x),quote_string,""),":",values),collapse=","),"}"))
    return(paste0("[",paste(values,collapse=","),"]"))
  }
  if(length(x)!=1) return(paste0("[",paste(vapply(as.list(x),gm_json,""),collapse=","),"]"))
  if(is.na(x)) return("null")
  if(is.logical(x)) return(if(x) "true" else "false")
  if(is.numeric(x)) return(if(is.finite(x)) format(x,scientific=FALSE,trim=TRUE,digits=12) else "null")
  quote_string(as.character(x))
}
gm_cells <- function(samples,config) {
  valid <- is.finite(samples$latitude)&is.finite(samples$longitude)
  result <- lapply(c("candidates","all_wgs"),function(cohort) {
    z <- samples[valid & if(cohort=="candidates") samples$map_candidate else TRUE,]
    z$year_label <- ifelse(is.na(z$year),"Undated",as.character(z$year))
    groups <- c("species","life_stage","year_label","cell_lon","cell_lat")
    if(!nrow(z)) return(NULL)
    a <- aggregate(list(sample_accessions=rep(1L,nrow(z)),approximate_accessions=as.integer(z$coordinate_approximate)),z[groups],sum)
    a$cohort <- cohort;a$count_unit <- "BioSample_accession";a$cell_degrees <- config$cell_degrees;a
  })
  do.call(rbind,result)
}
build_genomics_maps <- function(config) {
  out <- config$output
  inputs <- c(file.path(out,c("species_summary.csv","samples.csv","location_sources.csv","location_provenance.csv","resolved_config.R")),
    "Output/SamplingAtlas/tables/species_taxonomy.csv","Output/SamplingAtlas/tables/species_images.csv",
    "Scripts/build_genomics_maps.R","Scripts/genomics_maps.R","Scripts/genomics_maps.js","Scripts/genomics_maps.css",
    "Scripts/sampling_atlas_genomics.R","Scripts/genomics_filters.js","Scripts/sampling_atlas_taxonomy.R","Scripts/sampling_atlas_images.R","config/genomics.R",
    "Scripts/sampling_atlas_traits.R","Scripts/trait_filters.js","Scripts/trait_styles.css",atlas_trait_inputs(list()))
  before <- tools::md5sum(inputs);if(anyNA(before)) stop("Missing genomic map input")
  archived_config <- dget(file.path(out,"resolved_config.R"))
  stopifnot(identical(config$bounds,archived_config$bounds),identical(config$cell_degrees,archived_config$cell_degrees),identical(config$historical_end,archived_config$historical_end))
  bundle <- read_atlas_genomics(read.csv(file.path(out,"species_summary.csv"))$species,list(genomics=out))
  traits <- read_atlas_traits(bundle$summary$species,list())
  tax <- read.csv("Output/SamplingAtlas/tables/species_taxonomy.csv",stringsAsFactors=FALSE,na.strings="")
  tax[is.na(tax)] <- ""
  images <- read.csv("Output/SamplingAtlas/tables/species_images.csv",stringsAsFactors=FALSE,na.strings="")
  images[is.na(images)] <- "";images$local_image <- paste0("../SamplingAtlas/",images$local_image)
  s <- read.csv(file.path(out,"samples.csv"),stringsAsFactors=FALSE)
  s <- s[s$wgs_runs>0,]
  stopifnot(!anyDuplicated(paste(s$species,s$sample_accession)),!anyDuplicated(tax$species),setequal(tax$species,bundle$summary$species),
    all(s$map_candidate == (s$post_1930 & s$within_atlas_bounds & !s$pooled_flag & !s$captive_flag & !s$cell_line_flag & !s$hybrid_flag & !s$possible_duplicate_individual & !s$location_conflict & !s$publication_quality_exclusion)))
  cells <- gm_cells(s,config)
  columns <- c("species","sample_accession","year","latitude","longitude","cell_lon","cell_lat","life_stage","map_candidate", "coordinate_approximate",
    "coordinate_scope","location_source_ids","location_evidence_ids","date_evidence_ids","studies","locality_raw","review_reason","explicit_low_coverage_label")
  export <- s[columns]
  coast <- maps::map("world",plot=FALSE,fill=TRUE)
  pieces <- split(seq_along(coast$x),cumsum(is.na(coast$x)))
  polygons <- lapply(pieces,function(ix) {
    ix <- ix[is.finite(coast$x[ix]) & is.finite(coast$y[ix])]
    if(length(ix)<3) return(NULL)
    lapply(ix,function(j) round(c(coast$x[j],coast$y[j]),4))
  })
  polygons <- unname(Filter(Negate(is.null),polygons))
  # Arrays avoid repeating column names in every embedded record; no server/fetch needed.
  payload <- list(columns=columns,records=lapply(seq_len(nrow(export)),function(i) unname(as.list(export[i,]))),
    coast=polygons,bounds=as.list(config$bounds),cellDegrees=config$cell_degrees,historicalEnd=config$historical_end,
    sources=read.csv(file.path(out,"location_sources.csv"),stringsAsFactors=FALSE))
  lines <- c('<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Genomic sampling maps</title><style>',
    readLines("Scripts/genomics_maps.css"),readLines("Scripts/trait_styles.css"),'</style><body><h1>Genomic sampling maps</h1>',
    '<nav><a href="../SamplingAtlas/index.html">Historical annual atlas</a> · <a href="../SamplingAtlas/overview.html">Historical all-year maps</a> · <a href="index.html">Genomic inventory</a></nav>',
    '<p>Explore public whole-genome sequencing records for the 80 atlas species. Cell colors and labels count <strong>BioSample accessions, not verified independent fish</strong>. All-year labels use year (accessions); choose a year or play the dated frames.</p>',
    '<p class="extent">Every map uses the same extent and 2° × 2° cells. The default window is 100–50°W, 5–60°N. The worldwide option changes every map together; changing species or year never crops a map.</p>',
    '<p>The default cohort contains regional mapping candidates with a reported collection year after 1930, usable coordinates and no detected pool, captive, hybrid, cell-line, duplicate or publication-quality exclusion. Identity and habitat still need review. The review cohort includes all WGS accessions, including flagged and undated records. Records without coordinates are counted but cannot be placed. GEOME leads without a verified WGS sample link are excluded.</p>',
    '<p><a href="map_records.csv">Map record export</a> · <a href="map_cells.csv">Grid-cell export</a> · <a href="location_provenance.csv">Location/date provenance</a> · <a href="location_sources.csv">Source files and checksums</a> · <a href="README.md">Methods and documentation</a></p>',
    '<p>Species traits use the integrated curated summary; model ages, source-specific guilds and dated conservation snapshots remain distinct. <a href="../SpeciesTraits/species_summary.csv">Trait summary</a> · <a href="../SpeciesTraits/trait_provenance.csv">Trait provenance</a> · <a href="../SpeciesTraits/README.md">Trait definitions and limitations</a>. FishBase-derived content: FishBase team, CC BY-NC 4.0; other sources retain their own terms.</p>',
    '<form id="filters"><fieldset class="filters"><legend>Find species and records</legend><div class="filter-grid">',
    '<label>Scientific or common name<input id="search" type="search" placeholder="Filter species by name"></label>',atlas_taxonomy_filter_html(tax),
    '<label>Record cohort<select id="cohort"><option value="candidates">Regional mapping candidates</option><option value="all_wgs">All WGS records · review flags included</option></select></label>',
    '<label>Geographic extent<select id="extent"><option value="atlas">Atlantic, Caribbean and Gulf</option><option value="world">Worldwide</option></select></label>',
    '<label>Life stage<select id="life-stage"><option value="">All stages</option>',
    sprintf('<option value="%s">%s</option>',html_escape(sort(unique(s$life_stage))),html_escape(sort(unique(s$life_stage)))),'</select></label>',
    '<label>Collection year from<input id="year-min" type="number" step="1" placeholder="Any"></label><label>Collection year through<input id="year-max" type="number" step="1" placeholder="Any"></label></div>',
    '<label class="filter-check"><input id="exclude-approximate" type="checkbox"> Exclude approximate positions</label>',
    '<label class="filter-check"><input id="include-undated" type="checkbox" checked> Include undated records in the review cohort (even with year bounds)</label>',
    '<label class="filter-check"><input id="plotted-only" type="checkbox" checked> Show only species with records plotted in the chosen extent</label>',
    atlas_genomics_filter_html(),atlas_trait_filter_html(traits),'<p>Stage and year controls select genomic records here. Genomic availability and species-trait filters select species independently of those controls. Unlabeled genomic stages remain unknown; they are not assigned to adults.</p>',
    '<button type="reset">Reset filters</button></fieldset></form><p id="filter-error" role="alert" hidden>Start year must not exceed end year.</p><p id="result-count" role="status"></p><p id="no-results" hidden>No species match. Reset or relax the filters; turn off “only species with records plotted” to inspect metadata gaps.</p>')
  for(sp in bundle$summary$species) {
    t <- tax[match(sp,tax$species),]
    lines <- c(lines,sprintf('<article id="%s" data-species="%s" data-search="%s" data-order="%s" data-family="%s">',gsub(" ","_",sp),html_escape(sp),html_escape(tolower(paste(sp,t$common_name))),html_escape(t$order),html_escape(t$family)),
      atlas_taxonomy_heading_html(t),atlas_image_card_html(images[match(sp,images$species),]),
      atlas_genomics_card_html(bundle$summary[bundle$summary$species==sp,],"."),
      atlas_trait_card_html(traits$traits[traits$traits$species==sp,],traits),
      '<p class="record-summary"></p><div class="map-controls"><strong class="year-label">All years</strong><button class="previous" type="button" aria-label="Previous year">←</button><label>Collection year <select class="year-select"></select></label><button class="next" type="button" aria-label="Next year">→</button><button class="play" type="button">Play years</button><button class="download-map" type="button">Download SVG</button></div>',
      '<div class="map-host"></div><p class="frame-summary" aria-live="polite"></p><div class="legend"></div><div class="timeline-host"></div>',
      '<p>Click or focus a colored cell to inspect its accessions and source evidence. Hatching marks cells with approximate positions, including shared sampling-site coordinates. Blank cells mean no plotted records. Colors use a log scale fixed across displayed years for this species and filter selection.</p>',
      '<details class="cell-details"><summary>Selected cell: samples and provenance</summary><div class="cell-records"></div></details>',
      '<details class="grid-details"><summary>Grid cells: years and counts</summary><div class="grid-records"></div></details></article>')
  }
  lines <- c(lines,'<script id="genomic-data" type="application/json">',gm_json(payload),'</script><script>',readLines("Scripts/genomics_filters.js"),readLines("Scripts/trait_filters.js"),readLines("Scripts/genomics_maps.js"),'</script></body></html>')
  stopifnot(identical(unname(before),unname(tools::md5sum(inputs))))
  write.csv(export,file.path(out,"map_records.csv"),row.names=FALSE,na="")
  write.csv(cells,file.path(out,"map_cells.csv"),row.names=FALSE,na="")
  writeLines(lines,file.path(out,"maps.html"),useBytes=TRUE)
  write.csv(data.frame(path=inputs,md5=unname(before)),file.path(out,"map_input_checksums.csv"),row.names=FALSE)
  writeLines(capture.output(sessionInfo()),file.path(out,"map_session_info.txt"))
}
