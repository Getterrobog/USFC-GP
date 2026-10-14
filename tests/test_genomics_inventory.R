#!/usr/bin/env Rscript
source("Scripts/genomics_functions.R")
source("Scripts/genomics_locations.R")
# Population-site reconciliation must reject mismatches, invalid signs/ranges and missing pairs.
stopifnot(abs(g_dms("39 52 28 N") - 39.8744444444) < 1e-8,
          abs(g_dms("74 08 19 W") + 74.1386111111) < 1e-8,
          inherits(try(g_dms("39 60 01 N"), silent=TRUE), "try-error"),
          inherits(try(g_dms("-39 05 01 N"), silent=TRUE), "try-error"),
          g_location_agreement(c(25.351302,25.351306),c(-80.258986,-80.259)),
          !g_location_agreement(c(25.72315,25.72315),c(-80.154616,-80.258986)),
          !g_location_agreement(91,-80), !g_location_agreement(25,NA_real_),
          !g_location_agreement(25,numeric()), !g_location_agreement(numeric(),numeric()))
# Publication/sequencing dates never enter g_date: only allowlisted collection fields.
stopifnot(g_date("not collected")$date_status == "missing",
          g_date(c("2012", "2012-05-01"))$year == 2012,
          is.na(g_date("2012/2014")$year),
          g_date("2012/2014")$year_start == 2012,
          g_date("2012/2014")$year_end == 2014,
          is.na(g_date("before 2012")$year),
          is.na(g_date(c("2012", "2013"))$year),
          is.na(g_date("2099", current_year = 2026)$year))
stopifnot(identical(g_pair("41.32 N 72.02 W"), c(41.32, -72.02)),
          identical(g_pair("N 41.32, W 72.02"), c(41.32, -72.02)),
          identical(g_pair("-15.2, 61.8"), c(-15.2, 61.8)),
          all(is.na(g_pair("91 N 75 W"))), all(is.na(g_pair("-41 N 72 W"))),
          all(is.na(g_pair("0 0"))),
          is.na(g_coords(c("41 N 72 W", "42 N 73 W"))$latitude),
          is.na(g_coords(character(), locality = "USA: Connecticut")$latitude),
          g_coords(character(), locality = "USA: Mumford Cove (N 41.32, W 72.02)")$longitude == -72.02,
          is.finite(g_coords(character(), c("41.3333333333333", "41.333333333333"), "-72")$latitude))
# Mislabelled reduced representation, Hi-C, low-pass WGS, pools and technical repeats.
r <- data.frame(species=rep("Test fish",6), run_accession=paste0("RUN",1:6), sample_accession=c("S1","S1","S2","S3","S4","S5"),
 experiment_title=c("low-coverage WGS", "low-coverage WGS", "Hi-C Arima", "ddRADseq", "3RAD", "Rad-capture of fish"),
 library_name="", library_construction_protocol="", library_strategy=c("WGS","WGS","WGS","WGS","OTHER","OTHER"),
 library_selection=c("RANDOM","RANDOM","RANDOM","Restriction Digest","Reduced Representation","Reduced Representation"),
 instrument_platform="ILLUMINA", base_count="10000", read_count="100", fastq_md5=c("abc;def","def;abc","ghi","jkl","mno","pqr"),
 fastq_ftp="ftp.example.org/reads.gz", sra_ftp="", study_accession="PRJ1", secondary_study_accession="", stringsAsFactors=FALSE)
z <- g_classify_runs(r)
stopifnot(sum(z$wgs_eligible) == 2L, sum(z$duplicate_file_set) == 1L,
 z$assay_class[3] == "HiC_or_proximity", all(z$assay_class[4:6] == "reduced_representation"),
 all(z$explicit_low_coverage_label[1:2]))
cat("Genomics normalization and assay checks passed.\n")
