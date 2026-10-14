# Geographic map frames and the local map-first browsing report.
source("Scripts/sampling_atlas_traits.R")
source("Scripts/sampling_atlas_taxonomy.R")
source("Scripts/sampling_atlas_overview.R")
source("Scripts/sampling_atlas_images.R")
source("Scripts/sampling_atlas_genomics.R")
geographic_frame_inventory <- function(d, species, stage, config) {
  years <- sort(unique(na.omit(d$year)))
  cycle <- if (length(years) && config$animation_years == "all") seq(min(years), max(years)) else years
  if (anyNA(d$year) || !length(cycle)) cycle <- c(cycle, NA_integer_)
  label <- ifelse(is.na(cycle), if (nrow(d)) "Undated" else "No records", as.character(cycle))
  filename <- ifelse(is.na(cycle), if (nrow(d)) "undated.png" else "no_records.png", paste0("year_", cycle, ".png"))
  counts <- lapply(cycle, function(y) {
    z <- if (is.na(y)) d[is.na(d$year), ] else d[!is.na(d$year) & d$year == y, ]
    c(specimens = sum(z$specimen_count), mapped_specimens = sum(z$specimen_count[z$mapped]),
      approximate_specimens = sum(z$specimen_count[z$coordinate_approximate]))
  })
  data.frame(species = species, life_stage = stage, year = cycle, label = label,
    specimens = vapply(counts, function(z) z[1], numeric(1)),
    mapped_specimens = vapply(counts, function(z) z[2], numeric(1)),
    approximate_specimens = vapply(counts, function(z) z[3], numeric(1)),
    west = unname(config$bounds['west']), east = unname(config$bounds['east']),
    south = unname(config$bounds['south']), north = unname(config$bounds['north']),
    cell_degrees = config$cell_degrees,
    png = file.path("species", slug(species), paste0(stage, "_frames"), filename),
    row.names = NULL)
}

# Older builds discarded temporary PNGs. Recover the displayed, full-canvas frames
# from their existing GIFs without changing counts, extent, colors or year labels.
recover_geographic_frames <- function(manifest, records, config) {
  binary <- Sys.which("magick")
  if (!nzchar(binary)) binary <- Sys.which("convert")
  for (i in seq_len(nrow(manifest))) {
    m <- manifest[i, ]
    d <- records[records$included & records$species %in% m$species & records$life_stage == m$life_stage, ]
    inventory <- geographic_frame_inventory(d, m$species, m$life_stage, config)
    table_path <- file.path(config$output, "species", slug(m$species), paste0(m$life_stage, "_frames.csv"))
    paths <- file.path(config$output, inventory$png)
    if (file.exists(table_path) && all(file.exists(paths)) && all(file.info(paths)$size > 0)) {
      old <- read.csv(table_path, stringsAsFactors = FALSE,
        colClasses = c(year = "integer", label = "character"))
      if (isTRUE(all.equal(old, inventory, check.attributes = FALSE))) next
      stop("Frame inventory differs from current counts/configuration; rebuild the atlas before refreshing: ", m$species, "/", m$life_stage)
    }
    if (!nzchar(binary) || is.na(m$gif) || !nzchar(m$gif))
      stop("Rebuild the atlas to create missing year PNGs, or install ImageMagick to recover existing GIF frames.")
    if (nrow(inventory) != m$frames) stop("Year inventory does not match GIF frame count for ", m$species, "/", m$life_stage)
    message("Geographic PNGs: ", m$species, " / ", m$life_stage)
    temp <- tempfile("atlas_recover_")
    dir.create(temp)
    tryCatch({
      result <- system2(binary, c("-limit", "thread", "1", shQuote(file.path(config$output, m$gif)),
        "-coalesce", shQuote(file.path(temp, "frame_%04d.png"))), stdout = TRUE, stderr = TRUE)
      status <- attr(result, "status")
      files <- sort(list.files(temp, pattern = "^frame_[0-9]+\\.png$", full.names = TRUE))
      if ((!is.null(status) && status != 0) || length(files) != nrow(inventory))
        stop("Could not recover all frames: ", paste(result, collapse = "\n"))
      dir.create(dirname(paths[1]), recursive = TRUE, showWarnings = FALSE)
      if (!all(file.copy(files, paths, overwrite = TRUE))) stop("Could not save geographic PNGs.")
      write.csv(inventory, table_path, row.names = FALSE, na = "")
    }, finally = unlink(temp, recursive = TRUE))
  }
}

atlas_filter_counts <- function(records, species, config) {
  d <- records[records$included & records$species %in% species &
    !is.na(records$year) & records$year <= config$max_year, ]
  groups <- split(d, interaction(d$species, d$life_stage, d$region, drop = TRUE))
  result <- lapply(groups, function(z) data.frame(
    species = z$species[1], life_stage = z$life_stage[1], region = z$region[1],
    specimens = sum(z$specimen_count), mapped_specimens = sum(z$specimen_count[z$mapped]),
    years = paste(sort(unique(z$year)), collapse = ","),
    mapped_years = paste(sort(unique(z$year[z$mapped])), collapse = ",")))
  if (!length(result)) return(data.frame(species = character(), life_stage = character(),
    region = character(), specimens = numeric(), mapped_specimens = numeric(),
    years = character(), mapped_years = character()))
  do.call(rbind, result)
}

write_atlas_index <- function(manifest, summaries, config, overview = NULL) {
  overview_mode <- !is.null(overview)
  records <- read.csv(file.path(config$output, "tables", "records_audit.csv"), stringsAsFactors = FALSE)
  filter_counts <- atlas_filter_counts(records, unique(manifest$species), config)
  traits <- read_atlas_traits(unique(manifest$species), config)
  write_atlas_trait_tables(traits, config)
  taxonomy <- read_atlas_taxonomy(unique(manifest$species), records, config)
  write_atlas_taxonomy_tables(taxonomy, config)
  images <- read_atlas_images(unique(manifest$species), config)
  write_atlas_image_table(images, config)
  genomics <- read_atlas_genomics(unique(manifest$species),config)
  write_atlas_genomics_tables(genomics,config)
  lines <- c('<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>USFC geographic sampling atlas</title>',
    '<style>body{font:16px system-ui;margin:40px auto;max-width:1100px;padding:0 24px;color:#233342;background:#f5f7f8}h1{font-size:36px}article{background:white;padding:20px 28px;margin:20px 0;border:1px solid #d5dfe4;border-radius:8px}a{color:#175b88}img{max-width:100%;height:auto}.map-view{display:block;width:100%;background:#fff}.map-controls{display:flex;flex-wrap:wrap;align-items:center;gap:10px;padding:12px 0}.year-label{font-size:24px;font-weight:700;margin-right:auto}.map-controls button,.map-controls select{font:inherit;padding:8px 12px;border:1px solid #aabac5;border-radius:5px;background:#f7fafb;color:#233342}.map-controls button{cursor:pointer}.map-controls button:disabled{opacity:.45;cursor:default}.year-gallery{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:16px}.year-gallery figure{margin:0}.year-gallery figcaption{font-size:14px}summary{cursor:pointer;padding:12px 0}small,.map-status{color:#526171}input{font:inherit;padding:10px;width:90%}.stage{border-top:1px solid #d5dfe4;padding-top:8px;margin-top:24px}.extent{padding:12px;background:#e7f0f5;border-radius:5px}</style>',
    if (overview_mode) '<h1>USFC all-year sampling maps</h1>' else '<h1>USFC geographic sampling atlas</h1>',
    if (overview_mode) '<nav><a href="index.html">Year-by-year atlas and animations</a> · <strong>All-year species maps</strong></nav>'
      else if (file.exists(file.path(config$output, "overview.html"))) '<nav><strong>Year-by-year atlas and animations</strong> · <a href="overview.html">All-year species maps</a></nav>',
    '<p><a href="../Genomics/maps.html">Genomic sampling maps</a> · <a href="../Genomics/index.html">Public genomic inventory</a> · <a href="tables/genomic_summary.csv">Genomic summary for these species</a></p>',
    sprintf('<p>%s species with at least %s dated specimens through %s in the western Atlantic, Caribbean and Gulf of Mexico. Eligibility sums specimens across stages. Undated specimens do not confer eligibility.</p>', sum(summaries$eligible), config$min_specimens, config$max_year),
    sprintf('<p class="extent"><strong>Every map uses the same extent:</strong> %g°W to %g°W longitude, %g°N to %g°N latitude. Grid: %g° × %g°. No zooming or cropping between species, stages or years.</p>', -config$bounds['west'], -config$bounds['east'], config$bounds['south'], config$bounds['north'], config$cell_degrees, config$cell_degrees),
    if (overview_mode) '<p>One map per species combines all eligible years and all life stages, including undated lots. Numbered cells connect to their collection-year labels; parentheses show specimen counts for that cell and year. Colors show total specimens per cell, not abundance. Enlarge labels for a scrollable view; the geographic extent stays fixed.</p>' else '<p>Choose a recorded year to inspect its geographic sample-size heatmap, or play the GIF; the year is printed prominently inside each frame. Colors are fixed across years and stages within each species. Counts are specimens per grid cell, not population abundance. Blank cells mean no plotted sampling.</p>',
    '<p><strong>Hatched cells include approximate locations.</strong> Missing coordinates are estimated from station, locality, island or broader location labels. These display positions can be much less precise than a grid cell; they are not verified collecting sites. Frame counts separate recorded coordinates from estimates. Original coordinates remain unchanged, and estimates are excluded from precise-location candidate screens.</p>',
    if (overview_mode) '<p>Adults / non-larval, larvae and mixed lots are pooled on these maps. Undated samples are included and labeled Undated in their cells. Use the year-by-year atlas to inspect stages separately.</p>' else '<p>Adult / non-larval includes juveniles and unlabeled lots; maturity is unverified. Mixed lots stay separate. Undated lots have a separate frame.</p>',
    '<p><a href="tables/approximate_locations.csv">Estimated locations and their evidence</a> · <a href="tables/approximation_summary.csv">Estimates by species and location detail</a></p>',
    if (!overview_mode) sprintf('<p>GIF timing: %s years; gaps are visible on each frame’s timeline.</p>', config$animation_years),
    '<p><a href="tables/species_summary.csv">Species inventory</a> · <a href="tables/candidate_screening.csv">Candidate screening</a> · <a href="tables/shared_year_assemblages.csv">Same-year assemblages</a> · <a href="tables/repeated_historical_cells.csv">Repeated historical sampling</a> · <a href="tables/annual_frame_manifest.csv">Year PNG inventory</a> · <a href="tables/records_audit.csv">Record audit</a></p>')
  if (file.exists(file.path(config$output, "selection_digest.txt")))
    lines <- c(lines, '<p><a href="selection_digest.txt">Selection digest by basin and stage</a> · <a href="tables/regional_candidates.csv">Regional candidate comparison</a></p>')
  if (traits$available) lines <- c(lines, sprintf('<p><strong>Species traits:</strong> curated life-history, trophic and functional summaries, including FishBase release %s, supplementary literature and source-specific reef classifications where available. Model-derived ages are labeled separately from reported ages. Independent scientific review remains pending. Source citations and evidence are expandable within each species card. FishBase-derived content: FishBase team; CC BY-NC 4.0; other sources retain their own terms.</p>', html_escape(paste(unique(traits$traits$fishbase_version[nzchar(traits$traits$fishbase_version)]), collapse = ", "))),
    '<p><a href="tables/life_history_traits.csv">Species traits</a> · <a href="tables/life_history_lengths.csv">Lengths by type</a> · <a href="tables/life_history_evidence.csv">Trait evidence</a> · <a href="tables/life_history_references.csv">References</a> · <a href="tables/life_history_dictionary.csv">Trait definitions</a></p>')
  else lines <- c(lines, '<p>Life-history traits have not been loaded for this build. The sampling inventory remains available.</p>')
  if(traits$integrated) lines <- c(lines,'<p><a href="../SpeciesTraits/species_summary.csv">Integrated species traits</a> · <a href="tables/species_traits_trait_provenance.csv">Trait provenance</a> · <a href="tables/species_traits_summary_evidence.csv">Summary-to-evidence links</a></p>')
  lines <- c(lines,'<style>',readLines("Scripts/trait_styles.css",warn=FALSE),'</style>')
  if (!is.null(images)) lines <- c(lines,
    sprintf('<p><strong>Species illustrations:</strong> %s locally saved images with credits and noncommercial reuse terms; other entries link to their sources with review notes. Illustrations are representative of the species, not the sampled museum lots. <a href="tables/species_images.csv">Image sources and credits</a></p>', sum(images$display_status == "embedded")),
    '<style>.species-image{box-sizing:border-box;max-width:560px;margin:18px 0;padding:16px;border:1px solid #d5dfe4;border-radius:6px;background:#fff}.species-photo{display:block;max-width:100%;max-height:240px;width:auto;height:auto;margin:0 auto 12px}.species-image figcaption,.image-credit{font-size:13px;line-height:1.5;color:#526171;overflow-wrap:anywhere}.image-stage{color:#526171}.image-source-only{background:#f5f8fa}.image-source-only p{margin:0 0 6px}</style>')
  lines <- c(lines,
    '<p>Order and family follow the museum catalog labels, which may differ from current classifications. Common names come from cached FishBase records using the existing curated species matches, including approved synonyms or proxies; unresolved matches remain unreported. <a href="tables/species_taxonomy.csv">Taxonomy and common-name sources</a></p>',
    '<style>.taxonomy-line{color:#526171;font-size:14px;margin-bottom:4px}article h2{margin-top:4px;overflow-wrap:anywhere}.common-name{font-weight:400;font-size:.85em}</style>',
    '<style>[hidden]{display:none!important}.filters{padding:20px;background:#e7f0f5;border:0;border-radius:8px}.filter-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:16px}.filter-grid label{display:flex;flex-direction:column;gap:6px}.filter-grid input,.filter-grid select{box-sizing:border-box;width:100%;font:inherit;padding:9px;border:1px solid #aabac5;border-radius:4px;background:white}.filter-check{display:block;margin:18px 0}.filter-check input{width:auto}.filters button{font:inherit;padding:8px 12px;cursor:pointer}.filter-match{color:#175b88;font-weight:600}</style>',
    '<style>.map-controls label{display:flex;align-items:center;gap:8px;max-width:100%;min-width:0}.map-controls select{min-width:0;max-width:100%}</style>',
    '<style>.trait-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(210px,100%),1fr));gap:14px;margin:12px 0}.trait-grid dt{font-size:13px;color:#526171}.trait-grid dd{margin:5px 0 0;overflow-wrap:anywhere}.life-history{background:#f5f8fa;border-radius:6px;padding:16px;margin:18px 0}.life-history h3{margin:0}.trait-source-note{font-size:14px;color:#69501f}.trait-ranges{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(240px,100%),1fr));gap:16px;margin-top:20px}.trait-range{min-width:0;border:1px solid #aabac5;border-radius:5px;padding:12px}.trait-range legend{font-weight:600}.trait-range label{display:flex;flex-direction:column;gap:5px}.trait-range input,.trait-range select{box-sizing:border-box;min-width:0;width:100%;font:inherit;padding:8px;border:1px solid #aabac5;border-radius:4px;background:white}.range-pair{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin:10px 0}#trait-filters{border-top:1px solid #aabac5;margin-top:16px}#trait-filter-count{color:#526171;font-size:14px}#trait-range-error{color:#9b2923}.trait-range input:disabled{opacity:.5}</style>',
    '<form id="filters"><fieldset class="filters"><legend><strong>Find candidate species</strong></legend><div class="filter-grid">',
    '<label>Scientific or common name<input id="search" type="search" placeholder="Filter species by name"></label>',
    atlas_taxonomy_filter_html(taxonomy),
    sprintf('<label>Minimum dated specimens<input id="min-specimens" type="number" min="0" step="1" value="%s"></label>', config$min_specimens),
    '<label>Life stage<select id="life-stage"><option value="">All stages</option><option value="adult">Adult / non-larval</option><option value="larva">Larva</option><option value="mixed">Mixed</option></select></label>',
    '<label>Region<select id="region"><option value="">All regions</option><option>Atlantic</option><option>Caribbean</option><option>Gulf of Mexico</option></select></label>',
    '<label>Minimum sampled years<input id="min-years" type="number" min="1" step="1" value="1"></label></div>',
    '<label class="filter-check"><input id="mapped-only" type="checkbox"> Count only specimens with recorded coordinates</label>',
    atlas_genomics_filter_html(), atlas_trait_filter_html(traits), '<button type="reset">Reset all filters</button>',
    sprintf('<p>Filters refine the %s eligible species using dated records through %s. Specimen counts and distinct years must meet the thresholds within the selected stage and region together. Undated specimens do not count toward these filters.</p>', sum(summaries$eligible), config$max_year),
    if (overview_mode) '<p><strong>Filters select species; maps always show all their included years, regions and life stages.</strong> The stage, region and coordinate controls only affect the candidate thresholds. Undated lots appear on maps but do not count toward those thresholds.</p>' else '<p>Maps show the full sampling distribution for each displayed stage, including other regions and undated frames; filtering does not change their geographic extent. Adult / non-larval maturity is unverified.</p>',
    '</fieldset></form>',
    '<p id="result-count" role="status" aria-live="polite"></p><p id="no-results" hidden>No species match these filters. Lower the thresholds or reset the filters.</p>')
  if (overview_mode) lines <- c(lines,
    '<style>.overview-viewport{overflow:auto;border:1px solid #d5dfe4;border-radius:6px;background:white;margin-top:12px}.overview-map{display:block;width:100%;max-width:none;height:auto}.overview-viewport.enlarged .overview-map{width:1600px}.overview-zoom{font:inherit;padding:8px 12px;cursor:pointer}.overview-table{overflow:auto}table{border-collapse:collapse;width:100%}th,td{padding:9px;text-align:left;border-bottom:1px solid #d5dfe4}.species-overview{border-top:1px solid #d5dfe4;margin-top:20px;padding-top:8px}</style>',
    '<p><a href="tables/overview_cells.csv">All-year grid-cell counts and years</a> · <a href="tables/overview_manifest.csv">Species map inventory</a></p>')
  inventories <- list()
  for (species in unique(manifest$species)) {
    s <- summaries[summaries$species == species, ]
    tax <- taxonomy[match(species, taxonomy$species), ]
    lines <- c(lines, sprintf('<article data-species="%s" data-search="%s" data-order="%s" data-family="%s">%s<p>%s dated specimens through %s + %s undated · %s lots · %s sampled years · %s regions · %.0f%% dated with recorded coordinates</p><p>%s specimens in %s lots use approximate display positions.</p>', html_escape(tolower(species)), html_escape(tolower(paste(species, tax$common_name))), html_escape(tax$order), html_escape(tax$family), atlas_taxonomy_heading_html(tax), s$eligibility_specimens, config$max_year, s$undated_specimens, s$lots, s$sampled_years, s$regions, 100 * s$mapped_fraction, s$approximate_specimens, s$approximate_lots))
    if (!is.null(images)) lines <- c(lines, atlas_image_card_html(images[match(species, images$species), ]))
    lines <- c(lines, '<p class="filter-match"></p>')
    lines <- c(lines,atlas_genomics_card_html(genomics$summary[match(species,genomics$summary$species),]))
    lines <- c(lines, atlas_trait_card_html(traits$traits[match(species, traits$traits$species), ],traits))
    for (j in which(filter_counts$species == species)) {
      f <- filter_counts[j, ]
      lines <- c(lines, sprintf('<span class="filter-record" hidden data-stage="%s" data-region="%s" data-specimens="%s" data-mapped="%s" data-years="%s" data-mapped-years="%s"></span>',
        f$life_stage, html_escape(f$region), f$specimens, f$mapped_specimens, f$years, f$mapped_years))
    }
    if (overview_mode) {
      lines <- c(lines, atlas_overview_card_html(species, overview), '</article>')
      next
    }
    for (i in which(manifest$species == species)) {
      m <- manifest[i, ]
      inventory <- read.csv(file.path(config$output, "species", slug(species), paste0(m$life_stage, "_frames.csv")), stringsAsFactors = FALSE)
      inventories[[length(inventories) + 1L]] <- inventory
      if (m$specimens == 0) {
        lines <- c(lines, sprintf('<p class="empty-stage" data-stage="%s"><strong>%s:</strong> no specimens recorded.</p>', m$life_stage, stage_label(m$life_stage)))
        next
      }
      first <- inventory[1, ]
      gif <- if (is.na(m$gif)) "" else m$gif
      lines <- c(lines, sprintf('<section class="stage" data-stage="%s" data-gif="%s"><h3>%s</h3><p>%s specimens · %s recorded coordinates · %s approximate positions</p><div class="map-controls"><output class="year-label">%s</output><button class="play" type="button"%s>Play GIF</button><button class="previous" type="button" aria-label="Previous recorded year">←</button><label>Year <select class="year-select" aria-label="Recorded year">', m$life_stage, html_escape(gif), stage_label(m$life_stage), m$specimens, m$mapped_specimens, m$approximate_specimens, first$label, if (nzchar(gif)) "" else " disabled"))
      for (j in seq_len(nrow(inventory))) lines <- c(lines, sprintf('<option value="%s" data-label="%s">%s — %s specimens (%s approximate)</option>', html_escape(inventory$png[j]), inventory$label[j], inventory$label[j], inventory$specimens[j], inventory$approximate_specimens[j]))
      lines <- c(lines, '</select></label><button class="next" type="button" aria-label="Next recorded year">→</button></div>',
        sprintf('<p class="map-status" aria-live="polite">Static geographic map · %s</p><img class="map-view" loading="lazy" width="%s" height="%s" src="%s" alt="%s — %s geographic sampling map"><p><a class="png-download" href="%s">Open selected year PNG</a> · <a href="%s">Annual map PDF</a>%s</p>', first$label, config$width, config$height, first$png, species, stage_label(m$life_stage), first$png, m$pdf, if (nzchar(gif)) sprintf(' · <a href="%s">Download GIF</a>', gif) else ""),
        '<details><summary>Show all year maps</summary><div class="year-gallery">')
      for (j in seq_len(nrow(inventory))) lines <- c(lines, sprintf('<figure><a href="%s"><img loading="lazy" width="%s" height="%s" src="%s" alt="%s — %s — %s geographic heatmap"></a><figcaption><strong>%s</strong> · %s specimens: %s recorded coordinates, %s approximate</figcaption></figure>', inventory$png[j], config$width, config$height, inventory$png[j], species, stage_label(m$life_stage), inventory$label[j], inventory$label[j], inventory$specimens[j], inventory$mapped_specimens[j], inventory$approximate_specimens[j]))
      lines <- c(lines, '</div></details></section>')
    }
    lines <- c(lines, '</article>')
  }
  lines <- c(lines, '<script>',readLines("Scripts/genomics_filters.js",warn=FALSE),readLines("Scripts/trait_filters.js",warn=FALSE),'</script>','<script>
document.querySelectorAll(".species-photo").forEach(img=>{
  const failed=()=>{img.hidden=true;img.closest("figure").querySelector(".image-error").hidden=false;};
  img.addEventListener("error",failed);if(img.complete&&!img.naturalWidth)failed();
});
document.querySelectorAll(".overview-zoom").forEach(button=>button.addEventListener("click",()=>{
  const viewport=button.nextElementSibling, enlarged=viewport.classList.toggle("enlarged");
  button.setAttribute("aria-pressed",String(enlarged));button.textContent=enlarged?"Fit map to page":"Enlarge labels";
}));
document.querySelectorAll(".stage").forEach(stage=>{
  const select=stage.querySelector("select"), img=stage.querySelector(".map-view"), play=stage.querySelector(".play"), status=stage.querySelector(".map-status"), year=stage.querySelector(".year-label");
  let playing=false;
  const showYear=()=>{const option=select.selectedOptions[0];playing=false;play.textContent="Play GIF";img.src=option.value;year.textContent=option.dataset.label;status.textContent="Static geographic map · "+option.dataset.label;stage.querySelector(".png-download").href=option.value;stage.querySelector(".previous").disabled=select.selectedIndex===0;stage.querySelector(".next").disabled=select.selectedIndex===select.options.length-1;};
  select.addEventListener("change",showYear);
  stage.querySelector(".previous").addEventListener("click",()=>{select.selectedIndex=Math.max(0,select.selectedIndex-1);showYear();});
  stage.querySelector(".next").addEventListener("click",()=>{select.selectedIndex=Math.min(select.options.length-1,select.selectedIndex+1);showYear();});
  play.addEventListener("click",()=>{if(playing){showYear();return;}playing=true;img.src=stage.dataset.gif;play.textContent="Stop GIF";year.textContent="Animation";status.textContent="Playing sampled years — see the year inside each map. Stop returns to the selected year.";});
  stage.showYear=showYear;showYear();
});
const form=document.getElementById("filters"), articles=Array.from(document.querySelectorAll("article"));
const candidateData=articles.map(article=>({article,records:Array.from(article.querySelectorAll(".filter-record"),node=>node.dataset),traits:Object.fromEntries(Array.from(article.querySelectorAll(".trait-value"),node=>[node.dataset.trait,node.dataset])),lengths:Array.from(article.querySelectorAll(".trait-length"),node=>({type:node.dataset.type,value:Number(node.dataset.value)}))}));
function applyFilters(){
  const q=document.getElementById("search").value.trim().toLowerCase(), selectedStage=document.getElementById("life-stage").value, region=document.getElementById("region").value;
  const minimum=Math.max(0,Number(document.getElementById("min-specimens").value)||0), minimumYears=Math.max(1,Number(document.getElementById("min-years").value)||1), mapped=document.getElementById("mapped-only").checked;
  const criteria=traitCriteria();
  const ranks=["order","family"].map(field=>({field,value:document.getElementById("taxonomy-"+field).value}));
  let visible=0;
  candidateData.forEach(candidate=>{
    const {article,records}=candidate;
    let count=0;const years=new Set();
    records.filter(r=>(!selectedStage||r.stage===selectedStage)&&(!region||r.region===region)).forEach(r=>{
      count+=Number(mapped?r.mapped:r.specimens);
      (mapped?r.mappedYears:r.years).split(",").filter(Boolean).forEach(y=>years.add(y));
    });
    article.hidden=!(article.dataset.search.includes(q)&&ranks.every(r=>!r.value||(r.value==="__missing__"?!article.dataset[r.field]:article.dataset[r.field]===r.value))&&count>0&&count>=minimum&&years.size>=minimumYears&&matchesTraits(candidate,criteria)&&matchesGenomics(article));
    if(!article.hidden)visible++;
    article.querySelector(".filter-match").textContent=count.toLocaleString()+" dated "+(mapped?"mapped ":"")+"specimens across "+years.size+" distinct year"+(years.size===1?"":"s")+" match the selected stage and region.";
    article.querySelectorAll(".stage,.empty-stage").forEach(stage=>{
      stage.hidden=!!selectedStage&&stage.dataset.stage!==selectedStage;
      if((stage.hidden||article.hidden)&&stage.showYear)stage.showYear();
    });
  });
  document.getElementById("result-count").textContent=visible+" of "+articles.length+" eligible species match";
  document.getElementById("no-results").hidden=visible!==0;
}
form.addEventListener("input",applyFilters);
form.addEventListener("change",applyFilters);
form.addEventListener("submit",event=>event.preventDefault());
form.addEventListener("reset",()=>setTimeout(applyFilters,0));
applyFilters();
</script></html>')
  write.csv(filter_counts, file.path(config$output, "tables", "filter_counts.csv"), row.names = FALSE, na = "")
  if (!overview_mode) write.csv(do.call(rbind, inventories), file.path(config$output, "tables", "annual_frame_manifest.csv"), row.names = FALSE, na = "")
  if (overview_mode) lines[1] <- sub("USFC geographic sampling atlas", "USFC all-year sampling maps", lines[1], fixed = TRUE)
  writeLines(lines, file.path(config$output, if (overview_mode) "overview.html" else "index.html"))
}
