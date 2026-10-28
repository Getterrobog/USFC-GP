#!/usr/bin/env Rscript
# Validate the saved one-map explorer against the record audit and original overview.
source("Scripts/sampling_atlas_functions.R")
source("Scripts/sampling_explorer.R")
out <- "Output/SamplingAtlas"
config <- dget(file.path(out,"resolved_config.R"))
records <- read.csv(file.path(out,"tables/records_audit.csv"),stringsAsFactors=FALSE)
read_cells <- function(name) read.csv(file.path(out,"tables",name),stringsAsFactors=FALSE,
  colClasses=c(cell_label="character",years="character",year_specimens="character"))
cells <- read_cells("explorer_cells.csv")
original <- read_cells("overview_cells.csv")
pooled <- cells[cells$map_stage=="all",names(original)]
pooled <- pooled[match(paste(original$species,original$cell_id),paste(pooled$species,pooled$cell_id)),]
totals <- read.csv(file.path(out,"tables/explorer_summary.csv"),stringsAsFactors=FALSE)
stopifnot(nrow(totals)==80*4,
  isTRUE(all.equal(pooled,original,check.attributes=FALSE)),
  all(totals$west==-100),all(totals$east==-50),all(totals$south==5),all(totals$north==60),all(totals$cell_degrees==2))
for(i in seq_len(nrow(totals))) {
  t <- totals[i,]
  d <- records[records$included & records$species==t$species & (t$map_stage=="all" | records$life_stage==t$map_stage),]
  c <- cells[cells$species==t$species & cells$map_stage==t$map_stage,]
  stopifnot(t$specimens==sum(d$specimen_count),t$lots==nrow(d),
    t$mapped_specimens==sum(d$specimen_count[d$display_mapped]),
    t$recorded_specimens==sum(d$specimen_count[d$mapped]),
    t$approximate_specimens==sum(d$specimen_count[d$coordinate_approximate]),
    t$unmapped_specimens==sum(d$specimen_count[!d$display_mapped]),
    t$undated_specimens==sum(d$specimen_count[is.na(d$year)]),
    t$specimens==t$mapped_specimens+t$unmapped_specimens,
    t$mapped_specimens==t$recorded_specimens+t$approximate_specimens,t$cells==nrow(c))
  for(j in seq_len(nrow(c))) {
    raw <- d[d$display_mapped & d$display_cell_id==c$cell_id[j],]
    by_year <- tapply(raw$specimen_count[!is.na(raw$year)],raw$year[!is.na(raw$year)],sum)
    stopifnot(c$specimens[j]==sum(raw$specimen_count),
      c$years[j]==paste(names(by_year),collapse=";"),
      c$year_specimens[j]==paste(by_year,collapse=";"),
      c$undated_specimens[j]==sum(raw$specimen_count[is.na(raw$year)]))
  }
}
for(sp in unique(totals$species)) {
  d <- totals[totals$species==sp,]
  stopifnot(d$specimens[d$map_stage=="all"]==sum(d$specimens[d$map_stage!="all"]),length(unique(d$color_maximum))==1)
}
# A stage with no records, plus a stage with records but no usable locations.
fixture <- records[rep(which(records$included & records$display_mapped)[1],3),]
fixture$species <- "Example species";fixture$life_stage <- c("adult","larva","mixed")
fixture$specimen_count <- c(2,3,5);fixture$year <- c(1900L,1900L,NA_integer_)
fixture$mapped <- c(TRUE,FALSE,FALSE);fixture$display_mapped <- c(TRUE,TRUE,FALSE)
fixture$coordinate_approximate <- c(FALSE,TRUE,FALSE)
z <- explorer_summaries(fixture,c("Example species","Empty species"),config)
stopifnot(z$summary$specimens[z$summary$species=="Example species" & z$summary$map_stage=="all"]==10,
  all(z$summary$specimens[z$summary$species=="Empty species"]==0),
  !any(z$cells$map_stage=="mixed"),
  z$cells$year_specimens[z$cells$map_stage=="all"]=="5")
checks <- read.csv(file.path(out,"tables/explorer_input_checksums.csv"))
stopifnot(identical(unname(tools::md5sum(checks$path)),checks$md5))
message("Explorer verified: 80 species × 4 stages, original overview agreement, per-cell year counts, approximate/undated/unmapped records, fixed extent/scales, and input provenance.")
