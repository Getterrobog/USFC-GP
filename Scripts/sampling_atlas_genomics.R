# Exact species-key attachment of the separately curated genomic inventory.
atlas_genomics_dir <- function(config) if(is.null(config$genomics)) "Output/Genomics" else config$genomics
atlas_genomics_inputs <- function(config) {
  paths <- file.path(atlas_genomics_dir(config),c("species_summary.csv","samples.csv","resolved_config.R","input_checksums.csv"))
  paths[file.exists(paths)]
}
read_atlas_genomics <- function(species, config) {
  folder <- atlas_genomics_dir(config)
  fields <- c("current_assembly_records","annotated_assemblies","annotated_reference_assemblies","wgs_samples",
    "low_coverage_labeled_samples","wgs_samples_with_coordinates","mapped_dated_samples")
  available <- file.exists(file.path(folder,"species_summary.csv"))
  out <- data.frame(species=species,query_status="not_loaded",stringsAsFactors=FALSE)
  for(f in c(fields,"contemporary_wgs_samples")) out[[f]] <- NA_integer_
  if(available) {
    z <- read.csv(file.path(folder,"species_summary.csv"),stringsAsFactors=FALSE)
    s <- read.csv(file.path(folder,"samples.csv"),stringsAsFactors=FALSE)
    cfg <- dget(file.path(folder,"resolved_config.R"))
    stopifnot(!anyDuplicated(z$species),!anyNA(z$species),all(nzchar(z$species)),
      !anyDuplicated(paste(s$species,s$sample_accession)),all(c(fields,"query_status") %in% names(z)))
    for(f in fields) stopifnot(all(is.finite(z[[f]])),all(z[[f]]>=0),all(z[[f]]==floor(z[[f]])))
    ix <- match(species,z$species); hit <- !is.na(ix)
    out[hit,c("query_status",fields)] <- z[ix[hit],c("query_status",fields)]
    out$contemporary_wgs_samples[hit] <- vapply(species[hit],function(sp)
      sum(s$species==sp & s$wgs_runs>0 & !is.na(s$year) & s$year>cfg$historical_end),integer(1))
    # Unknown taxonomic outcomes must never masquerade as a negative search result.
    out[out$query_status!="complete",c(fields,"contemporary_wgs_samples")] <- NA_integer_
  }
  list(summary=out,available=available)
}
write_atlas_genomics_tables <- function(bundle,config) {
  write.csv(bundle$summary,file.path(config$output,"tables","genomic_summary.csv"),row.names=FALSE,na="")
  inputs <- c(atlas_genomics_inputs(config),"Scripts/sampling_atlas_genomics.R","Scripts/genomics_filters.js")
  write.csv(data.frame(path=inputs,md5=unname(tools::md5sum(inputs))),
    file.path(config$output,"tables","genomic_input_checksums.csv"),row.names=FALSE)
}
atlas_genomics_filter_html <- function() c(
  '<details id="genomic-filters"><summary><strong>Genomic data filters</strong></summary>',
  '<p>Contemporary means a reported collection year after 1930. Worldwide counts include records needing biological review. Regional candidates pass the date, coordinate and biological screens in the Atlantic–Caribbean–Gulf window. These species-level filters are independent of the historical stage and region filters.</p><div class="filter-grid">',
  '<label>Genomic availability<select id="genomics-availability"><option value="">Any / unknown</option><option value="wgs">WGS found worldwide</option><option value="contemporary">Dated contemporary WGS</option><option value="mapped">Regional mapping candidates</option><option value="none">No WGS returned in search</option><option value="unknown">Unknown / unresolved</option></select></label>',
  '<label>Genome assembly<select id="genomics-reference"><option value="">Any / unknown</option><option value="assemblies">Current genome found</option><option value="annotated">Annotated genome found</option><option value="references">Annotated reference found</option></select></label>',
  '<label>Minimum WGS accessions worldwide<input id="genomics-min-wgs" type="number" min="0" step="1" value="0"></label>',
  '<label>Minimum contemporary WGS accessions<input id="genomics-min-contemporary" type="number" min="0" step="1" value="0"></label>',
  '<label>Minimum regional mapping candidates<input id="genomics-min-candidates" type="number" min="0" step="1" value="0"></label></div>',
  '<label class="filter-check"><input id="genomics-low" type="checkbox"> Has explicitly labeled low-coverage WGS</label></details>')
atlas_genomics_card_html <- function(row,base="../Genomics") {
  values <- c(wgs=row$wgs_samples,contemporary=row$contemporary_wgs_samples,candidates=row$mapped_dated_samples,
    assemblies=row$current_assembly_records,annotated=row$annotated_assemblies,references=row$annotated_reference_assemblies,low=row$low_coverage_labeled_samples)
  attrs <- paste(sprintf('data-%s="%s"',names(values),ifelse(is.na(values),"",values)),collapse=" ")
  fmt <- function(x) if(is.na(x)) "Unknown" else format(x,big.mark=",",trim=TRUE,scientific=FALSE)
  labels <- c(wgs="WGS BioSamples · worldwide",contemporary="Dated after 1930 · worldwide",candidates="Regional mapping candidates",
    assemblies="Current assembly records",annotated="Annotated assemblies",references="Annotated references",low="Labeled low-coverage WGS BioSamples")
  lines <- c(sprintf('<section class="genomic-stats life-history" data-known="%s" %s><h3>Public genomic data</h3><dl class="trait-grid">',row$query_status=="complete",attrs),
    vapply(names(values),function(f) sprintf('<div><dt>%s</dt><dd>%s</dd></div>',labels[[f]],fmt(values[[f]])),""),'</dl>',
    '<p><small>Counts are BioSample accessions and assembly records, not confirmed independent fish. Missing collection years do not establish absence of contemporary data. Annotated does not necessarily mean reference-designated.</small></p>',
    sprintf('<p><a href="%s/maps.html#%s">View genomic sampling map</a> · <a href="%s/index.html#%s">Assemblies and studies</a> · <a href="%s/location_provenance.csv">Location provenance</a></p></section>',base,gsub(" ","_",row$species),base,gsub(" ","_",row$species),base))
  lines
}
