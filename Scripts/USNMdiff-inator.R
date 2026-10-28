# USNMdiff-inator.R The purpose of this script is to analyze and process
# two specifically formatted files 'Potential.csv' produced by USNM-R-inator.
# Or why did the script drop the lots.
# I made changes to the script and I want to understand why legitimate lots were dropped.
## Author: Iván R. López Martínez. 10 Sep 2026.
# I used R version 4.6.1 (2026-06-24) -- "Happy Hop"
# I used Gemini AI to troubleshoot.

# 0. Setup Environment and Load Data
library(dplyr)
setwd("/Users/ivanlopez/OneDrive - University of Central Florida/USFCGP/R-USFCGP/")
P1 <- read.csv("./Data/Potential.csv")
P2 <- read.csv("./Data/Potential12Sep.csv")
P1 <- P1 %>% mutate(Catalog.Number...USNM = as.character(Catalog.Number...USNM))
P2 <- P2 %>% mutate(Catalog.Number...USNM = as.character(Catalog.Number...USNM))
Missing_P1 <- anti_join(P2, P1)
Missing_P2 <- anti_join(P1, P2)
Missing_P1 <- P2[!P2$Catalog.Number...USNM %in% P1$Catalog.Number...USNM, ]
Missing_P2 <- P1[!P1$Catalog.Number...USNM %in% P2$Catalog.Number...USNM, ]
sum(duplicated(P1))
sum(duplicated(P2))
P1_dupes <- P1[duplicated(P1) | duplicated(P1, fromLast = TRUE), ]
P1_dupes <- P1_dupes[order(P1_dupes$Catalog.Number...USNM), ]
sum(duplicated(Fish))
sum(duplicated(Fish_kicked))
