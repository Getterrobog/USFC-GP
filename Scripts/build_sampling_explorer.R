#!/usr/bin/env Rscript
# A separate one-map viewer. Never writes the existing atlas pages or media.
args <- commandArgs(trailingOnly=TRUE)
script <- sub("^--file=","",grep("^--file=",commandArgs(),value=TRUE)[1])
setwd(normalizePath(file.path(dirname(script),"..")))
if(length(args)>1) stop("Usage: Rscript Scripts/build_sampling_explorer.R [Output/SamplingAtlas]")
if(dir.exists(".R-library")) .libPaths(c(normalizePath(".R-library"),.libPaths()))
source("Scripts/sampling_atlas_functions.R")
source("Scripts/genomics_maps.R") # Shared safe JSON serialization; does not run a build.
source("Scripts/sampling_explorer.R")
if(!requireNamespace("maps",quietly=TRUE)) stop("Run Scripts/install_atlas_dependencies.R first.")
out <- if(length(args)) args[1] else "Output/SamplingAtlas"
config <- dget(file.path(out,"resolved_config.R"));config$output <- out
build_sampling_explorer(config)
message("Built ",file.path(out,"explorer.html"),"; existing pages and maps retained unchanged.")
