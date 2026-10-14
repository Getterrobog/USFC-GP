# Evidence-backed enrichment. Never replace source-archive fields or guess sample links.
g_dms <- function(x) {
  if (!nzchar(x)) return(NA_real_)
  p <- strsplit(trimws(x), " +")[[1]]
  if (length(p) != 4 || !p[4] %in% c("N","S","E","W")) stop("Invalid curated DMS coordinate")
  n <- g_num(p[1:3]); if(any(!is.finite(n)) || any(n<0) || n[2] >= 60 || n[3] >= 60 || n[1]>ifelse(p[4] %in% c("N","S"),90,180)) stop("Invalid DMS values")
  (n[1]+n[2]/60+n[3]/3600)*ifelse(p[4] %in% c("S","W"), -1, 1)
}

g_location_agreement <- function(latitude, longitude, tolerance=0.02) {
  length(latitude) > 0 && length(latitude)==length(longitude) && all(is.finite(latitude)) && all(is.finite(longitude)) && all(abs(latitude)<=90) && all(abs(longitude)<=180) &&
    diff(range(latitude)) <= tolerance && diff(range(longitude)) <= tolerance
}

g_enrich_locations <- function(s, runs, attributes, config) {
  folder <- "Data/Genomics/location_sources"
  manifest <- g_read(file.path(folder, "source_manifest.csv"))
  sites <- g_read("config/genomics_publication_sites.csv")
  sites$latitude <- vapply(sites$latitude_dms, g_dms, 0.0)
  sites$longitude <- vapply(sites$longitude_dms, g_dms, 0.0)
  for (f in c("latitude", "longitude", "locality_raw", "coordinates_raw", "collection_date_raw", "year", "date_status", "coordinate_status")) s[[paste0("archive_",f)]] <- s[[f]]
  s$coordinate_scope <- ifelse(is.finite(s$latitude), "archive_reported_scope_unspecified", "")
  s$location_conflict <- FALSE; s$publication_quality_exclusion <- FALSE
  s$location_source_ids <- ""; s$location_evidence_ids <- ""; s$date_evidence_ids <- ""
  s$publication_individual_event_id <- ""
  s$publication_sample_match <- ""
  attr_index <- split(seq_len(nrow(attributes)), g_key(attributes))
  attr_tags <- g_norm(attributes$attribute)
  archive_files <- c("Data/Genomics/normalized/sample_attributes.csv", "Data/Genomics/normalized/runs.csv")
  archive_hashes <- sub(" .*", "", system2("sha256sum", shQuote(archive_files), stdout=TRUE))
  stopifnot(length(archive_hashes)==2L, all(nchar(archive_hashes)==64L))
  archive_dates <- range(g_read("Data/Genomics/normalized/queries.csv")$retrieved_utc)
  ledger <- list(); counter <- 0L
  add <- function(sp, sid, field, value, value2="", raw_value=value, source_id, source_url,
                  source_record_id=sid, source_locator="", match_method="exact_BioSample_accession",
                  scope="", note="", supporting_source_id="", decision="pending") {
    counter <<- counter+1L
    mid <- match(source_id, manifest$source_id)
    ledger[[counter]] <<- data.frame(evidence_id=sprintf("LOC%06d", counter), species=sp, sample_accession=sid,
      field=field, value=as.character(value), value2=as.character(value2), raw_value=as.character(raw_value),
      source_id=source_id, supporting_source_id=supporting_source_id, source_url=source_url,
      publication_doi=if(!is.na(mid)) manifest$publication_doi[mid] else "",
      source_file=if(!is.na(mid)) paste0(folder,"/",manifest$file[mid]) else "Data/Genomics/normalized/sample_attributes.csv | Data/Genomics/normalized/runs.csv",
      source_sha256=if(!is.na(mid)) manifest$source_sha256[mid] else paste(archive_hashes,collapse=" | "),
      retrieved_utc=if(!is.na(mid)) manifest$retrieved_utc[mid] else paste(archive_dates,collapse=" | "),
      source_record_id=source_record_id, source_locator=source_locator,
      match_method=match_method, coordinate_scope=scope, coordinate_uncertainty_m="",
      decision=decision, note=note, stringsAsFactors=FALSE)
  }
  # Every existing attached coordinate/locality/year gets an explicit evidence entry.
  # Original individual attributes, source URLs, transport checksums and raw request hashes
  # remain independently queryable in sample_attributes / input_checksums / queries.
  for (i in seq_len(nrow(s))) {
    k <- g_key(s[i,]); ix <- attr_index[[k]]
    geoix <- ix[grepl("lat|lon|locality|geoloc|country|location",attr_tags[ix])]
    dateix <- ix[attr_tags[ix] %in% c("collectiondate","collectionyear","datecollected","samplingdate","samplingyear","samplecollectiondate","yearcollected")]
    geo_urls <- g_join(c(attributes$source_url[geoix], s$source_url[i]))
    date_urls <- g_join(c(attributes$source_url[dateix], s$source_url[i]))
    if(is.finite(s$latitude[i])) add(s$species[i],s$sample_accession[i],"coordinates",s$latitude[i],s$longitude[i],s$coordinates_raw[i],
      "archive",geo_urls,scope=s$coordinate_scope[i],source_locator="allowlisted sample/run collection-coordinate fields",decision="archive_original")
    if(nzchar(s$locality_raw[i])) add(s$species[i],s$sample_accession[i],"locality",s$locality_raw[i],source_id="archive",source_url=geo_urls,
      source_locator="allowlisted sample/run collection-locality fields",decision="archive_original")
    if(!is.na(s$year[i])) add(s$species[i],s$sample_accession[i],"collection_year",s$year[i],raw_value=s$collection_date_raw[i],source_id="archive",source_url=date_urls,
      source_locator="allowlisted collection-date attributes; never release dates",decision="archive_original")
  }
  # Repository CSV supplies explicit BioSample accessions: no name/prefix guessing.
  b <- g_read(file.path(folder,"bco854878_samples.csv"))
  known <- paste(s$species,s$sample_accession,sep="::")
  stopifnot(!anyDuplicated(b$biosample_accession))
  for (j in seq_len(nrow(b))) {
    i <- match(paste("Menidia menidia", b$biosample_accession[j],sep="::"),known)
    if(is.na(i)) next
    stopifnot(grepl(b$bioproject_accession[j],s$studies[i],fixed=TRUE))
    src <- manifest[manifest$source_id=="bco854878",]
    for(field in c("coordinates","locality","collection_year")) {
      value <- switch(field, coordinates=b$lat[j],locality=b$geo_loc_name[j],collection_year=b$collection_date[j])
      add(s$species[i],s$sample_accession[i],field,value,if(field=="coordinates") b$lon[j] else "",
        raw_value=if(field=="coordinates") paste(b$lat[j],b$lon[j]) else value,
        source_id="bco854878",source_url=src$landing_url,source_record_id=b$SampleID[j],
        source_locator=paste0(src$file,": row ",j+1),scope=if(field=="coordinates") "reported_population_site" else "",
        note="Site coordinates rounded to two decimal degrees; not individual GPS precision. Original country label retained even where inconsistent with locality (Minas Basin).")
    }
    bad <- b$SampleID[j] %in% c("JekyllIs_1223","JekyllIs_1224",paste0("MagdalenIs_",911:918),"Patchogue_1030")
    if(bad) {
      s$publication_quality_exclusion[i] <- TRUE
      add(s$species[i],s$sample_accession[i],"analysis_exclusion","library_preparation_problem",source_id="bco854878_description",source_url=src$landing_url,
        source_record_id=b$SampleID[j],source_locator="Problem report",
        note="Repository recommends excluding these samples. Jekylls label in report corresponds to JekyllIs in CSV for IDs 1223/1224.",decision="exclusion_applied")
    }
  }
  # Exact individual-event IDs in the supplement link deposits split across Run1..4.
  f <- g_read(file.path(folder,"fundulus_evad123_Table_S3.csv"))
  f <- unique(f[c("unique_id","population","timepoint","source_row","source_member")])
  for(i in which(s$species=="Fundulus heteroclitus" & grepl("PRJNA96762[6]|PRJNA967630|PRJNA967633|PRJNA967634",s$studies))) {
    id <- sub("_Run[0-9]+$","",s$isolate[i],ignore.case=TRUE)
    hit <- which(f$unique_id==id)
    if(!length(hit)) next
    pop <- unique(f$population[hit]); when <- unique(f$timepoint[hit])
    if(length(pop)!=1 || length(when)!=1 || !pop %in% c("NR","SR","TE")) next
    site <- sites[sites$source_id=="fundulus_evad123" & sites$site_id==pop,]
    if(nrow(site)!=1 || !grepl("^[FS][0-9]{2}$",when)) stop("Unreviewed Fundulus table value")
    yr <- 2000L+as.integer(sub("^[FS]","",when))
    src <- manifest[manifest$source_id=="fundulus_evad123_supp",]
    locator <- paste0(f$source_member[hit[1]], "; rows ",paste(f$source_row[hit],collapse=","),"; main article Methods / Sample collection")
    method <- "exact_study_and_isolate_after_removing_Run_suffix_to_Table_S3_unique_id"
    s$publication_individual_event_id[i] <- paste0("10.1093/gbe/evad123::",id)
    s$publication_sample_match[i] <- method
    for(field in c("coordinates","locality","collection_year")) {
      value <- switch(field,coordinates=site$latitude,locality=site$locality,collection_year=yr)
      add(s$species[i],s$sample_accession[i],field,value,if(field=="coordinates") site$longitude else "",
          raw_value=if(field=="coordinates") paste(site$latitude_dms,site$longitude_dms) else if(field=="collection_year") when else value,
          source_id="fundulus_evad123_supp",supporting_source_id="fundulus_evad123",source_url=src$landing_url,
          source_record_id=id,source_locator=locator,match_method=method,scope=if(field=="coordinates") site$coordinate_scope else "",
          note="Coordinates describe the reported population site. Pool column is library multiplexing; not a pool of fish. Run deposits are not independent fish.")
    }
  }
  # Only named populations explicitly linked by Table S4 are attached. M61/M87/M26
  # are not translated to named sites without supporting evidence.
  a <- g_read(file.path(folder,"atherino_evac111_TableS4.csv"))
  asites <- g_read(file.path(folder,"atherino_evac111_TableS3.csv"))
  rr <- unique(runs[runs$species=="Atherinomorus stipes" & runs$study_key=="PRJNA814490",c("sample_accession","sample_alias")])
  for(j in seq_len(nrow(rr))) {
    i <- match(paste("Atherinomorus stipes",rr$sample_accession[j],sep="::"),known)
    hit <- which(a$sample_id==rr$sample_alias[j])
    if(is.na(i) || length(hit)!=1) next
    pop <- a$population[hit]
    if(!pop %in% c("Broad-Key","Crandon-Park")) next
    site <- sites[sites$source_id=="atherino_evac111" & sites$site_id==pop,]
    src <- manifest[manifest$source_id=="atherino_evac111_supp",]
    locator <- paste(a$source_member[hit],"row",a$source_row[hit])
    method <- "exact_study_and_sample_alias_to_Table_S4_sample_id"
    add(s$species[i],s$sample_accession[i],"locality",site$locality,source_id="atherino_evac111_supp",supporting_source_id="atherino_evac111",source_url=src$landing_url,
      source_record_id=rr$sample_alias[j],source_locator=locator,match_method=method)
    add(s$species[i],s$sample_accession[i],"coordinates",site$latitude,site$longitude,paste(site$latitude_dms,site$longitude_dms),
      source_id="atherino_evac111",supporting_source_id="atherino_evac111_supp",source_url=src$landing_url,source_record_id=rr$sample_alias[j],
      source_locator=paste(locator,"and main article Methods"),match_method=method,scope="reported_population_site",note=site$note)
    z <- asites[asites[['Population Name']]==gsub("-"," ",pop),]
    stopifnot(nrow(z)==1)
    add(s$species[i],s$sample_accession[i],"coordinates",z$Latitude,z$Longitude,paste(z$Latitude,z$Longitude),
      source_id="atherino_evac111_supp",source_url=src$landing_url,source_record_id=rr$sample_alias[j],source_locator=paste(locator,"and Table S3 row",z$source_row),
      match_method=method,scope="reported_population_site",note="Retained independently so disagreement with main-text coordinates remains auditable. Collection year not supplied; permit/sequencing years are not collection dates.")
  }
  e <- do.call(rbind,ledger); rownames(e) <- NULL
  grouped <- split(seq_len(nrow(e)),g_key(e))
  for (i in seq_len(nrow(s))) {
    ix <- grouped[[known[i]]]; if(!length(ix)) next
    geo <- ix[e$field[ix]=="coordinates"]
    loc <- ix[e$field[ix]=="locality"]
    dates <- ix[e$field[ix]=="collection_year"]
    external <- ix[e$source_id[ix]!="archive"]
    if(length(geo)) {
      la <- g_num(e$value[geo]); lo <- g_num(e$value2[geo])
      if(s$archive_coordinate_status[i]=="conflicting_coordinates" || !g_location_agreement(la,lo)) {
        s$location_conflict[i] <- TRUE; s$latitude[i] <- NA_real_;s$longitude[i] <- NA_real_
        s$coordinate_status[i] <- "conflicting_coordinates"; e$decision[geo] <- "withheld_coordinate_conflict"
      } else {
        if(!is.finite(s$latitude[i])) {
          s$latitude[i] <- la[1]; s$longitude[i] <- lo[1];s$coordinates_raw[i] <- e$raw_value[geo[1]]
          s$coordinate_status[i] <- "publication_reported_site";s$coordinate_approximate[i] <- TRUE;s$coordinate_scope[i] <- e$coordinate_scope[geo[1]]
          e$decision[geo] <- "accepted_missing_coordinates"
        } else e$decision[geo[e$source_id[geo]!="archive"]] <- "corroborates_archive"
      }
    }
    if(length(loc)) {
      s$locality_raw[i] <- g_join(e$value[loc]);e$decision[loc[e$source_id[loc]!="archive"]] <- "attached_additional_locality_evidence"
    }
    if(length(dates)) {
      years <- unique(g_num(e$value[dates]))
      if(length(years)==1 && is.finite(years) && s$archive_date_status[i] %in% c("missing","single_year")) {
        if(is.na(s$year[i])) {s$year[i]<-as.integer(years);s$year_start[i]<-as.integer(years);s$year_end[i]<-as.integer(years);s$date_status[i]<-"single_year";s$collection_date_raw[i]<-g_join(e$raw_value[dates]);e$decision[dates]<-"accepted_missing_year"}
        else e$decision[dates[e$source_id[dates]!="archive"]] <- "corroborates_archive"
      } else {s$year[i]<-NA_integer_;s$date_status[i]<-"conflicting_or_multiple_dates";s$year_start[i]<-min(c(s$year_start[i],years),na.rm=TRUE);s$year_end[i]<-max(c(s$year_end[i],years),na.rm=TRUE);e$decision[dates]<-"withheld_date_conflict"}
    }
    s$location_evidence_ids[i] <- g_join(e$evidence_id[c(geo,loc)])
    s$date_evidence_ids[i] <- g_join(e$evidence_id[dates])
    s$location_source_ids[i] <- g_join(e$source_id[c(geo,loc)])
  }
  s$within_atlas_bounds <- is.finite(s$latitude) & is.finite(s$longitude) & s$latitude>=config$bounds['south'] & s$latitude<=config$bounds['north'] & s$longitude>=config$bounds['west'] & s$longitude<=config$bounds['east']
  s$post_1930 <- !is.na(s$year) & s$year>config$historical_end
  s$cell_lon <- floor(s$longitude/config$cell_degrees)*config$cell_degrees;s$cell_lat <- floor(s$latitude/config$cell_degrees)*config$cell_degrees
  s$map_candidate <- s$wgs_runs>0 & s$post_1930 & s$within_atlas_bounds & !s$pooled_flag & !s$captive_flag & !s$cell_line_flag & !s$hybrid_flag & !s$possible_duplicate_individual & !s$location_conflict & !s$publication_quality_exclusion
  for(i in seq_len(nrow(s))) {
    reasons <- strsplit(s$review_reason[i]," | ",fixed=TRUE)[[1]]
    if(is.finite(s$latitude[i])) reasons<-setdiff(reasons,"coordinates_unresolved")
    if(!is.na(s$year[i])) reasons<-setdiff(reasons,"collection_year_unresolved")
    if(s$location_conflict[i]) reasons<-c(reasons,"coordinate_sources_disagree")
    if(s$publication_quality_exclusion[i]) reasons<-c(reasons,"publication_library_quality_exclusion")
    s$review_reason[i] <- g_join(reasons)
  }
  stopifnot(!any(e$decision=="pending"))
  coverage <- do.call(rbind,lapply(g_read(config$roster)$species,function(sp) {
    z<-s[s$species==sp & s$wgs_runs>0,]
    data.frame(species=sp,wgs_samples=nrow(z),archive_coordinates=sum(is.finite(z$archive_latitude)),enriched_coordinates=sum(is.finite(z$latitude)),
      newly_georeferenced=sum(!is.finite(z$archive_latitude)&is.finite(z$latitude)),archive_localities=sum(z$archive_locality_raw!=""),enriched_localities=sum(z$locality_raw!=""),
      archive_years=sum(!is.na(z$archive_year)),enriched_years=sum(!is.na(z$year)),coordinate_conflicts=sum(z$location_conflict),quality_exclusions=sum(z$publication_quality_exclusion),mapping_candidates=sum(z$map_candidate))
  }))
  list(samples=s,evidence=e,coverage=coverage,sources=manifest)
}
