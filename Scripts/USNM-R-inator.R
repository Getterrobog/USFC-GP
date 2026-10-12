# USNM-R-inator.R
# Purpose: The purpose of this script is to run a series of R scripts to process
# a *.csv file downloaded from https://collections.nmnh.si.edu/search/fishes/
# The scripts will analyze and process USNM collections data to:
# • Add valid names from Eschmeyer's catalog of fishes
# • species_checkinator.py must:
# - be given permissions ("chmod u+x species_checkinator.py")
# - be placed in the active R working directory OR in a directory listed in your shell initialization script
# - example: export PATH="$PATH:$HOME/[dir_containing_script]"
# • use data from the file as a key to fill in centroids and missing dates if possible On the assumptions
# - that samples collected by the same ship on the same date occurred close to each other
# - that samples collected by the same ship close to each other share the same date
# • Add common names from FishBase
# • Produce the following products
# - *.kmz to allow the visualization spatial distance
# - Histograms to allow the view of a temporal span
# - Summary tables to sort suitable study species
# Author: Iván R. López Martínez. 10 Sep 2026.
# email: ivan.r.lopez@hotmail.com
# I used R version 4.6.1 (2026-06-24) -- "Happy Hop"
# I used Gemini AI to troubleshoot.
# Save your original USNM.csv file prior to processing and do not modify it.
# In your working Directory create the following directory structure:
# Data/ (place the USNM.csv here)
# Output/Figures
# Output/Files
# Scripts/ (place your R script here.)
# 0. Setup Environment and Load Data
setwd("/Users/ivanlopez/OneDrive - University of Central Florida/USFCGP/R-USFCGP/")

#Process the data
source("./Scripts/nmnhsearchinator.R")
invisible(readline(prompt = "nmnhsearchinator complete. Press [enter] to proceed."))

# Create a *.kmz file for use with mapping software
source("./Scripts/pop_kmz-inator.R")
invisible(readline(prompt = "pop_kmz-inator complete. Press [enter] to proceed."))

# Create Histograms to view a time span
source("./Scripts/Histograminator.R")
invisible(readline(prompt = "Histograminator complete. Press [enter] to proceed."))
