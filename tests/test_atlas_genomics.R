#!/usr/bin/env Rscript
source("Scripts/sampling_atlas_functions.R")
source("Scripts/genomics_maps.R")
source("config/genomics.R")
roster <- read.csv("Output/Genomics/species_summary.csv",stringsAsFactors=FALSE)
bundle <- read_atlas_genomics(roster$species,list())
stopifnot(identical(bundle$summary$species,roster$species),nrow(bundle$summary)==80L)
unknown <- bundle$summary[bundle$summary$species=="Myctophum opalinum",]
stopifnot(is.na(unknown$wgs_samples),unknown$query_status=="taxonomic_review_required",
  grepl('data-known="FALSE"',atlas_genomics_card_html(unknown)[1],fixed=TRUE))
missing <- read_atlas_genomics("Absent species",list())$summary
stopifnot(missing$query_status=="not_loaded",is.na(missing$wgs_samples))
s <- read.csv("Output/Genomics/samples.csv",stringsAsFactors=FALSE)
wgs <- s[s$wgs_runs>0,]
stopifnot(sum(bundle$summary$contemporary_wgs_samples,na.rm=TRUE)==sum(wgs$post_1930),
  sum(bundle$summary$mapped_dated_samples,na.rm=TRUE)==sum(wgs$map_candidate))
# One accession per record, mixed stages/years, undated and no-location cases.
fixture <- wgs[rep(which(wgs$map_candidate)[1],5),]
fixture$sample_accession <- paste0("S",1:5);fixture$species <- "Fixture fish"
fixture$life_stage <- c("adult","adult","larva","unknown","adult")
fixture$year <- c(2001,2001,2002,NA,2003)
fixture$latitude[5] <- NA;fixture$longitude[5] <- NA
fixture$map_candidate <- c(TRUE,TRUE,TRUE,FALSE,FALSE)
fixture$coordinate_approximate <- c(FALSE,TRUE,FALSE,FALSE,FALSE)
cells <- gm_cells(fixture,genomics_config)
stopifnot(sum(cells$sample_accessions[cells$cohort=="candidates"])==3,
  sum(cells$sample_accessions[cells$cohort=="all_wgs"])==4,
  sum(cells$sample_accessions[cells$year_label=="Undated"])==1,
  all(cells$sample_accessions[cells$year_label=="2001"]==2),
  all(cells$approximate_accessions[cells$year_label=="2001"]==1))
stopifnot(!grepl("</script>",gm_json(list(x="</script>\n\"\\")),fixed=TRUE),gm_json(NA_real_)=="null")
# Completed exports preserve source keys and reconcile to both independent source screens.
records <- read.csv("Output/Genomics/map_records.csv",stringsAsFactors=FALSE)
saved <- read.csv("Output/Genomics/map_cells.csv",stringsAsFactors=FALSE)
stopifnot(identical(records$sample_accession,wgs$sample_accession),
  isTRUE(all.equal(saved,gm_cells(wgs,genomics_config),check.attributes=FALSE)),
  sum(saved$sample_accessions[saved$cohort=="candidates"])==sum(wgs$map_candidate),
  sum(saved$sample_accessions[saved$cohort=="all_wgs"])==sum(is.finite(wgs$latitude)))
for(path in c("Output/Genomics/map_input_checksums.csv","Output/SamplingAtlas/tables/genomic_input_checksums.csv")) {
  checks <- read.csv(path);stopifnot(identical(unname(tools::md5sum(checks$path)),checks$md5))
}
message("Genomic atlas checks passed: exact joins, unknowns, contemporary counts, stage/year cells, source exports and fingerprints.")
