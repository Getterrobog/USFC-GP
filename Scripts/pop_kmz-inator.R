# pop_kmz-inator.R
# Purpose: The purpose of this script is to produce *.kmz to allow the
# visualization of spatial distance and population clusters.
# Author: Iván R. López Martínez. 10 Sep 2026.
# email: ivan.r.lopez@hotmail.com
# I used R version 4.6.1 (2026-06-24) -- "Happy Hop"
# I used Gemini AI to troubleshoot.

library(dplyr)
library(utils)

# I. Temporal Filtering for Spatial Mapping using Date.ISO.8601
filter_kmz_by_year <- TRUE
max_kmz_year       <- 1947

Populations_kmz <- Populations %>%
  mutate(Extracted_Year = suppressWarnings(as.integer(substr(Date.ISO.8601, 1, 4))))

if (filter_kmz_by_year) {
  Populations_kmz <- Populations_kmz %>%
    filter(is.na(Extracted_Year) | Date.ISO.8601 == "" | Extracted_Year <= max_kmz_year)
}

# III. Generate KMZ Map Visualization
kml_palette <- c(
  "ff0000ff", "ff000000", "ff00ff00", "ffff0000", "ffff00ff", "ffffa500", 
  "ff00ffff", "ff800080", "ff0080ff", "ff008000", "ff800000", "ff808000", 
  "ff000080", "ff808080", "ff00a5ff", "ff13eac7", "ffda70d6", "ff4763ff", 
  "ffd2b48c", "ff228b22"
)

Populations_kmz$Valid.Name <- sub("^Population \\d+ of ", "", Populations_kmz$Populations.by.species)
unique_taxa <- sort(unique(Populations_kmz$Valid.Name))
taxon_color_map <- setNames(kml_palette[(seq_along(unique_taxa) - 1) %% length(kml_palette) + 1], unique_taxa)

sp_pop_totals <- tapply(Populations_kmz$Populations.by.species, Populations_kmz$Valid.Name, function(x) length(unique(x)))

generate_kml_content <- function(df, color_map, pop_totals) {
  kml_header <- c(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<kml xmlns="http://www.opengis.net/kml/2.2">',
    '<Document>',
    '  <name>USFC Collection Populations to 1947 and Undated</name>'
  )
  
  style_nodes <- sapply(names(color_map), function(sp) {
    color_hex <- color_map[[sp]]
    style_id  <- paste0("style_", gsub("[^A-Za-z0-9]", "_", sp))
    paste0(
      '  <Style id="', style_id, '">\n',
      '    <IconStyle>\n',
      '      <color>', color_hex, '</color>\n',
      '      <scale>0.9</scale>\n',
      '      <Icon><href>http://maps.google.com/mapfiles/kml/paddle/wht-blank.png</href></Icon>\n',
      '    </IconStyle>\n',
      '  </Style>'
    )
  })
  
  distinct_counts <- unname(sort(unique(pop_totals), decreasing = TRUE))
  
  folder_nodes <- unlist(lapply(distinct_counts, function(cnt) {
    folder_label   <- paste0(cnt, if (cnt == 1) " pop" else " pops")
    species_in_cnt <- sort(names(pop_totals)[pop_totals == cnt])
    
    f_open <- paste0('  <Folder>\n    <name>', folder_label, '</name>')
    
    subfolders <- unlist(lapply(species_in_cnt, function(sp_name) {
      df_sp <- df[df$Valid.Name == sp_name, ]
      style_id <- paste0("style_", gsub("[^A-Za-z0-9]", "_", sp_name))
      
      sub_open <- paste0('    <Folder>\n      <name>', sp_name, '</name>')
      
      placemarks <- apply(df_sp, 1, function(row) {
        pop_label <- gsub("^Population ([0-9]+) of ", "P\\1 ", row["Populations.by.species"])
        
        usnm_cat   <- row["Catalog.Number...USNM"]
        count_val  <- row["Specimen.Count"]
        date_val   <- row["Date.ISO.8601"]
        vessel_val <- row["Vessel"]
        lat_val    <- row["Centroid.Latitude"]
        lon_val    <- row["Centroid.Longitude"]
        
        paste0(
          '      <Placemark>\n',
          '        <name>', pop_label, '</name>\n',
          '        <styleUrl>#', style_id, '</styleUrl>\n',
          '        <ExtendedData>\n',
          '          <Data name="Species"><value>', sp_name, '</value></Data>\n',
          '          <Data name="USNM Catalog Number"><value>', usnm_cat, '</value></Data>\n',
          '          <Data name="Specimen Count"><value>', count_val, '</value></Data>\n',
          '          <Data name="Date Collected"><value>', date_val, '</value></Data>\n',
          '          <Data name="Vessel"><value>', vessel_val, '</value></Data>\n',
          '        </ExtendedData>\n',
          '        <Point>\n',
          '          <coordinates>', lon_val, ',', lat_val, ',0</coordinates>\n',
          '        </Point>\n',
          '      </Placemark>'
        )
      })
      
      sub_close <- '    </Folder>'
      return(c(sub_open, placemarks, sub_close))
    }))
    
    f_close <- '  </Folder>'
    return(c(f_open, subfolders, f_close))
  }))
  
  return(c(kml_header, unname(style_nodes), folder_nodes, '</Document>', '</kml>'))
}

kml_lines <- generate_kml_content(Populations_kmz, taxon_color_map, sp_pop_totals)
writeLines(kml_lines, "doc.kml")
zip("USFC_Collection.kmz", files = "doc.kml", flags = "-q")
file.rename(from = "USFC_Collection.kmz", to = "./Output/Files/USFC_Collection.kmz")
file.remove("doc.kml")

# End of Script