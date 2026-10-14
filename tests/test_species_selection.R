#!/usr/bin/env Rscript
source("Scripts/species_selection_functions.R")
fails <- function(expr) inherits(try(force(expr), silent = TRUE), "try-error")

# At the equator, adjacent coordinates are about 16.7 km apart, but the chain
# spans about 33.4 km. Complete linkage must not put all three in a 20 km site.
coords <- data.frame(longitude = c(0, .15, .30), latitude = c(0, 0, 0))
g <- build_site_tree(coords)
stopifnot(identical(dim(g$distances), c(3L, 3L)),
  max(abs(g$distances - t(g$distances))) < 1e-10,
  abs(g$distances[1, 2] - 16.67926) < .001)
assigned <- assign_sites(coords, g, 20)
stopifnot(length(unique(assigned$site_id)) == 2L)
for (i in split(seq_len(nrow(coords)), assigned$site_id))
  stopifnot(max(g$distances[i, i, drop = FALSE]) <= 20)
reverse <- coords[3:1, ]; gr <- build_site_tree(reverse)
stopifnot(identical(assign_sites(reverse, gr, 20)$site_id[3:1], assigned$site_id))
one <- data.frame(longitude = 1, latitude = 2)
stopifnot(nrow(assign_sites(one, build_site_tree(one), 20)) == 1L)

# Two catalogued subspecies have already been mapped to the same accepted
# species by the atlas. Aggregate that species, preserving separate stages/years.
r <- data.frame(species = rep("Example species", 4), site_id = rep("S1", 4),
  life_stage = c("adult", "adult", "larva", "adult"), year = c(1890L, 1890L, 1890L, 1891L),
  specimen_count = c(6, 5, 30, 40), station = c("1", "1", "2", "3"),
  year_status = rep("explicit_year", 4), stage_evidence = rep("stage_unrecorded", 4),
  taxonomy_status = rep("curated_catalog_name", 4), catalog_number = as.character(1:4))
cells <- selection_cells(r, 10, 2)
stopifnot(nrow(cells) == 3L, sum(cells$specimens) == 81, sum(cells$lots) == 4L,
  sum(cells$qualifies) == 1L, cells$specimens[cells$qualifies] == 11,
  cells$catalog_numbers[cells$qualifies] == "1; 2")

# A large count for one species or another year cannot create co-occurrence.
r2 <- r[1, ]; r2$species <- "Second species"; r2$specimen_count <- 10
r3 <- r2; r3$species <- "Third species"; r3$year <- 1891L
all <- rbind(r, r2, r3)
a <- selection_assemblages(selection_cells(all, 10, 1), 3)
stopifnot(!any(a$meets_multispecies_screen))
r3$year <- 1890L
a <- selection_assemblages(selection_cells(rbind(r, r2, r3), 10, 1), 3)
stopifnot(sum(a$meets_multispecies_screen) == 1L,
  a$species_count[a$meets_multispecies_screen] == 3L)
empty <- selection_cells(r[FALSE, ], 10, 1)
stopifnot(nrow(empty) == 0L, nrow(selection_assemblages(empty, 3)) == 0L)

# Record order alone cannot silently link the wrong catalogued object.
raw <- data.frame(Catalog.Number...USNM = "1", Station = "", Cruise = "", Precise.Locality = "",
  Province.State = "", Depth..m. = "", Collection.Method = "", Preservation.Method = "", EZID = "example")
record <- data.frame(record_id = 1L, catalog_number = "1", species = "Curated species")
stopifnot(join_selection_evidence(record, raw)$species == "Curated species")
record$catalog_number <- "2"
stopifnot(fails(join_selection_evidence(record, raw)))

# Two disconnected sets must not be reported as one crossed design.
incidence <- matrix(c(1, 0, 1, 0, 0, 1), nrow = 2,
  dimnames = list(c("Species a", "Species b"), c("S1", "S2", "S3")))
components <- site_components(incidence)
stopifnot(components$component[1] == components$component[2],
  components$component[1] != components$component[3])

events <- rbind(r, r2, r3)
events$date_original <- ifelse(events$year == 1890L, "28 Jun 1890 (1890 Jun 28 - 0000 00 00)", "29 Jun 1891")
events$station <- "7"; events$vessel <- "Fish Hawk"
events$locality <- "Example locality"; events$depth_original <- ""
events$collection_method <- ""
ec <- selection_cells(events, 10, 1)
ea <- selection_assemblages(ec, 3); ea <- ea[ea$meets_multispecies_screen, ]
ee <- ec[ec$qualifies & ec$year == 1890L & ec$life_stage == "adult", ]
ev <- assemblage_evidence(events, ee, ea)
stopifnot(ev$groups$shared_date_labels == "28 Jun 1890",
  ev$groups$shared_station_day_keys == "Fish Hawk / 7 / 28 Jun 1890")
events$date_original[events$species == "Third species"] <- "29 Jun 1890"
ev <- assemblage_evidence(events, ee, ea)
stopifnot(ev$groups$shared_date_labels == "", ev$groups$shared_station_day_keys == "")
events$date_original <- "1890"
ev <- assemblage_evidence(events, ee, ea)
stopifnot(ev$groups$shared_date_labels == "1890", ev$groups$shared_station_day_keys == "")
message("Species selection boundary and conservation checks passed.")
