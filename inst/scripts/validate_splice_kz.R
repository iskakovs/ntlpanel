# Validate the Suomi NPP -> NOAA-20 splice for Kazakhstan --------------------
#
# Purpose: test the riskiest assumption behind a long monthly VIIRS panel for
# Kazakhstan: that NOAA-20 (VJ146) can be spliced onto Suomi NPP (VNP46)
# without large or unstable level breaks at region level, including in the
# high-latitude summer months.
#
# Run from a shell:  Rscript validate_splice_kz.R
# Requirements:
#   * EARTHDATA_TOKEN in ~/.Renviron (https://urs.earthdata.nasa.gov)
#   * Region polygons in the 2022 vintage, path in KZ_ADM1 (gpkg/shp/geojson)
#     and identifier column in KZ_ADM1_ID (default "region").
#   * Disk: the annual step keeps ~10-20 GB in the cache; the monthly step
#     downloads ~1 GB per product-month but deletes files after each year.
#     Set NTLPANEL_CACHE to a folder with enough space.
#
# Outputs (in OUT_DIR, default ./ntl_validation):
#   0_orientation.txt, 1_annual_splice.csv, 2_monthly_long.csv,
#   2_monthly_splice.csv, 2_monthly_by_month.csv, summary.txt

library(ntlpanel)
library(sf)

boundaries <- Sys.getenv("KZ_ADM1", "kz_adm1_2022.gpkg")
id_col <- Sys.getenv("KZ_ADM1_ID", "region")
out_dir <- Sys.getenv("OUT_DIR", "ntl_validation")
monthly_years <- Sys.getenv("MONTHLY_YEARS", "2023,2024,2025")
monthly_years <- as.integer(strsplit(monthly_years, ",")[[1]])
annual_years <- 2018:2025

dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
ntl_token() # fails early with instructions if no token is set
regions <- st_read(boundaries, quiet = TRUE)
stopifnot(id_col %in% names(regions))
regions <- st_transform(regions, 4326)
tiles <- ntl_tiles(regions)$tile
message("Tiles: ", paste(tiles, collapse = ", "))

# Step 0: orientation check --------------------------------------------------
# The brightest pixel of tile h25v04 (70-80 E, 40-50 N) should be Almaty
# (43.24 N, 76.89 E) or Bishkek (42.87 N, 74.59 E), i.e. latitude 42-44 N.
# If tiles were read upside down it would appear near 46-48 N.
m0 <- ntl_fetch("VNP46A4", tiles = "h25v04", start = 2023, end = 2023)
r0 <- ntl_read(m0)
v0 <- terra::values(r0$value, mat = FALSE)
xy <- terra::xyFromCell(r0, which.max(v0))
orient_ok <- xy[2] > 42 && xy[2] < 44.5
verdict <- if (orient_ok) {
  "orientation OK"
} else {
  "CHECK ORIENTATION (try flip = TRUE)"
}
txt <- sprintf("Brightest pixel in h25v04 (2023): lon %.3f, lat %.3f -> %s",
               xy[1], xy[2], verdict)
writeLines(txt, file.path(out_dir, "0_orientation.txt"))
message(txt)
if (!orient_ok) stop("Orientation check failed; inspect the tile first.")

# Step 1: annual overlap -----------------------------------------------------
message("Step 1: annual VNP46A4 vs VJ146A4, ",
        min(annual_years), "-", max(annual_years))
fetch_annual <- function(product) {
  ntl_fetch(product, tiles = tiles, start = min(annual_years),
            end = max(annual_years))
}
ma <- rbind(fetch_annual("VNP46A4"), fetch_annual("VJ146A4"))
la <- ntl_extract(ma, regions, id_col = id_col, quality_max = 1)
sa <- ntl_splice(la, from = "VNP46A4", to = "VJ146A4", min_share_valid = 0.8)
ra <- ntl_splice_report(sa)
write.csv(ra, file.path(out_dir, "1_annual_splice.csv"), row.names = FALSE)

# Step 2: monthly overlap, one year at a time --------------------------------
message("Step 2: monthly VNP46A3 vs VJ146A3 for ",
        paste(monthly_years, collapse = ", "))
pieces <- list()
for (y in monthly_years) {
  for (prod in c("VNP46A3", "VJ146A3")) {
    m <- ntl_fetch(prod, tiles = tiles, start = paste0(y, "-01"),
                   end = paste0(y, "-12"))
    pieces[[paste(prod, y)]] <- ntl_extract(m, regions, id_col = id_col,
                                            quality_max = 1)
    ntl_cache_clear(m)
  }
}
lmon <- do.call(rbind, pieces)
write.csv(as.data.frame(lmon), file.path(out_dir, "2_monthly_long.csv"),
          row.names = FALSE)

sm <- ntl_splice(lmon, from = "VNP46A3", to = "VJ146A3",
                 min_share_valid = 0.8)
sbm <- ntl_splice(lmon, from = "VNP46A3", to = "VJ146A3", by_month = TRUE,
                  min_share_valid = 0.8, min_overlap = 2)
rm_ <- ntl_splice_report(sm)
rbm <- ntl_splice_report(sbm)
write.csv(rm_, file.path(out_dir, "2_monthly_splice.csv"), row.names = FALSE)
write.csv(rbm, file.path(out_dir, "2_monthly_by_month.csv"),
          row.names = FALSE)

# Summary --------------------------------------------------------------------
pts <- suppressWarnings(st_point_on_surface(st_geometry(regions)))
lat <- st_coordinates(pts)[, "Y"]
rbm$lat <- lat[match(rbm[[id_col]], regions[[id_col]])]
ok <- !rbm$fallback
season <- aggregate(b ~ month, data = rbm[ok, ], FUN = median)
north <- aggregate(b ~ month, data = rbm[ok & rbm$lat >= 48, ], FUN = median)

q <- function(x) {
  qs <- stats::quantile(x, c(0.1, 0.5, 0.9), na.rm = TRUE)
  paste(round(qs, 2), collapse = " / ")
}
by_month <- function(d) {
  paste(" ", paste(sprintf("%02d: %.3f", d$month, d$b), collapse = "  "))
}
lines <- c(
  txt,
  "",
  "Annual level shift VJ146A4 vs VNP46A4, %",
  "  (p10 / median / p90 across regions):",
  paste(" ", q(ra$level_shift_pct)),
  "Monthly level shift VJ146A3 vs VNP46A3, % (p10 / median / p90):",
  paste(" ", q(rm_$level_shift_pct)),
  "Monthly ratio instability, ratio_cv (p10 / median / p90):",
  paste(" ", q(rm_$ratio_cv)),
  "",
  "Median calibration factor b by calendar month (all regions):",
  by_month(season),
  "Median calibration factor b by calendar month (regions >= 48 N):",
  by_month(north),
  "",
  "Reading the results:",
  "  * Small, homogeneous shifts (|median| < 5%, p10-p90 range < 5 points)",
  "    and ratio_cv < 0.1: a single ratio splice per region is adequate.",
  "  * Shifts that differ by region: keep region-specific calibration",
  "    (the default).",
  "  * Factors that vary by calendar month, especially in the north: use",
  "    by_month = TRUE, or include region x calendar-month fixed effects."
)
writeLines(lines, file.path(out_dir, "summary.txt"))
cat(lines, sep = "\n")
