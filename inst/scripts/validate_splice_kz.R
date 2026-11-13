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
#   * Time: the number of files is (tiles) x (2 x annual years + 24 x
#     monthly years); at about 1 minute per file, all 10 tiles of
#     Kazakhstan with the defaults take ~15 hours one file at a time.
#     Results of the annual step are written first.
#   * Interruptions: files LAADS refuses or drops are retried after 1, 3
#     and 10 minutes, then skipped and listed in summary.txt. If the run
#     stops, start it again: downloaded files and finished monthly years
#     are kept and not fetched again.
#
# Optional settings (environment variables, e.g. in ~/.Renviron):
#   WORKERS        Parallel downloads (default 1). Helps only if one
#                  download does not already fill your internet line.
#   TILES          Comma-separated subset of tiles, e.g.
#                  "h24v03,h25v03,h24v04,h25v04". Only regions lying
#                  entirely within these tiles are used.
#   MONTHLY_TILES  Like TILES, for the monthly step only (default: same
#                  as TILES). The monthly step is ~85% of all downloads,
#                  so this is the main way to shorten a run.
#   ANNUAL_YEARS   Comma-separated years (default 2018-2025).
#   MONTHLY_YEARS  Comma-separated years (default 2023,2024,2025). One
#                  year shows the seasonal pattern; a second year checks
#                  that it repeats. Years can be added in a later run.
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
annual_years <- Sys.getenv("ANNUAL_YEARS", paste(2018:2025, collapse = ","))
annual_years <- as.integer(strsplit(annual_years, ",")[[1]])
workers <- max(1L, as.integer(Sys.getenv("WORKERS", "1")))
tiles_env <- Sys.getenv("TILES", "")
monthly_tiles_env <- Sys.getenv("MONTHLY_TILES", tiles_env)

dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
invisible(ntl_token()) # fails early with instructions if no token is set
regions <- st_read(boundaries, quiet = TRUE)
stopifnot(id_col %in% names(regions))
regions_all <- st_transform(regions, 4326)
needs <- lapply(seq_len(nrow(regions_all)),
                function(i) ntl_tiles(regions_all[i, ])$tile)
# Tiles to download and the regions lying entirely within them
pick <- function(env, label) {
  if (!nzchar(env)) {
    return(list(tiles = sort(unique(unlist(needs))), regions = regions_all))
  }
  tiles <- trimws(strsplit(env, ",")[[1]])
  inside <- vapply(needs, function(t) all(t %in% tiles), logical(1))
  if (!any(inside)) stop("No region lies entirely within ", label, ".")
  list(tiles = tiles, regions = regions_all[inside, ])
}
annual_set <- pick(tiles_env, "TILES")
monthly_set <- pick(monthly_tiles_env, "MONTHLY_TILES")
show_set <- function(label, set) {
  message(label, " tiles: ", paste(set$tiles, collapse = ", "))
  message(label, " regions: ", paste(set$regions[[id_col]], collapse = ", "))
}
show_set("Annual", annual_set)
show_set("Monthly", monthly_set)

# Download one product for a set of periods ("YYYY" or "YYYY-MM"), one file
# per tile and period, with up to WORKERS downloads at a time.
# LAADS now and then drops a connection or refuses a request (HTTP 401) in
# the middle of a long run although the token is fine. Such files are tried
# again after 1, 3 and 10 minutes; if they still fail they are skipped and
# listed in summary.txt, and running the script again fetches them. Three
# skipped files in a row stop the run (LAADS down or token expired).
fetch_one <- function(i, jobs, product, token, cache_dir, quiet) {
  waits <- c(60, 180, 600)
  temporary <- paste0("HTTP (401|403|429|5[0-9][0-9])|Incomplete download|",
                      "Connection to LAADS failed|kept refusing")
  for (attempt in seq_len(length(waits) + 1)) {
    res <- tryCatch(
      ntlpanel::ntl_fetch(product, tiles = jobs$tile[i],
                          start = jobs$period[i], end = jobs$period[i],
                          token = token, cache_dir = cache_dir,
                          quiet = quiet),
      error = function(e) e
    )
    if (!inherits(res, "error")) return(res)
    is_temp <- inherits(res, "httr2_failure") ||
      grepl(temporary, conditionMessage(res))
    if (!is_temp) stop(res)
    if (attempt > length(waits)) break
    message("  ", product, " ", jobs$tile[i], " ", jobs$period[i],
            ": LAADS refused or dropped the download; retrying in ",
            waits[attempt] / 60, " min")
    Sys.sleep(waits[attempt])
  }
  message("  ", product, " ", jobs$tile[i], " ", jobs$period[i],
          ": skipped for now (", conditionMessage(res), ")")
  structure(list(product = product, tile = jobs$tile[i],
                 period = jobs$period[i]), class = "fetch_failure")
}
failed_files <- data.frame()
fetch_grid <- function(product, periods, tiles) {
  years <- unique(as.integer(substr(periods, 1, 4)))
  invisible(ntl_available(product, years, tiles = tiles)) # cache file lists
  jobs <- expand.grid(tile = tiles, period = periods,
                      stringsAsFactors = FALSE)
  n <- min(workers, nrow(jobs))
  message("  ", product, ": ", nrow(jobs), " files, ", n, " at a time")
  token <- ntl_token()
  cache_dir <- ntl_cache_dir()
  if (n > 1) {
    cl <- parallel::makeCluster(n)
    on.exit(parallel::stopCluster(cl), add = TRUE)
    parts <- parallel::parLapplyLB(cl, seq_len(nrow(jobs)), fetch_one,
                                   jobs = jobs, product = product,
                                   token = token, cache_dir = cache_dir,
                                   quiet = TRUE)
  } else {
    parts <- vector("list", nrow(jobs))
    streak <- 0
    for (i in seq_len(nrow(jobs))) {
      parts[[i]] <- fetch_one(i, jobs, product, token, cache_dir,
                              quiet = FALSE)
      failed <- inherits(parts[[i]], "fetch_failure")
      streak <- if (failed) streak + 1 else 0
      if (streak >= 3) {
        stop("Three files in a row could not be downloaded: LAADS may be ",
             "down or the token may have expired. Run the script again ",
             "later; finished work is kept.")
      }
    }
  }
  bad <- vapply(parts, inherits, logical(1), "fetch_failure")
  if (all(bad)) stop("No ", product, " file could be downloaded.")
  if (any(bad)) {
    failed_files <<- rbind(failed_files,
                           do.call(rbind, lapply(parts[bad], function(x) {
                             as.data.frame(unclass(x))
                           })))
  }
  out <- do.call(rbind, parts[!bad])
  attr(out, "complete") <- !any(bad)
  out
}

# Step 0: orientation check --------------------------------------------------
# Tile h25v04 covers 70-80 E, 40-50 N. Compare the total light in boxes
# around Almaty and Bishkek with the same boxes mirrored north-south within
# the tile (lat -> 90 - lat), which fall in dark steppe. Read the right way
# up, the city boxes are many times brighter; upside down, the reverse.
# (The single brightest pixel is not a reliable test: in 2023 it is the
# Topar power station at 49.5 N, 72.8 E, not a city.)
m0 <- ntl_fetch("VNP46A4", tiles = "h25v04", start = 2023, end = 2023)
r0 <- ntl_read(m0)
box_sum <- function(lon, lat, d = 0.25) {
  e <- terra::ext(lon - d, lon + d, lat - d, lat + d)
  terra::global(terra::crop(r0$value, e), "sum", na.rm = TRUE)[[1]]
}
city_lon <- c(almaty = 76.92, bishkek = 74.60)
city_lat <- c(almaty = 43.25, bishkek = 42.87)
lit <- sum(mapply(box_sum, city_lon, city_lat))
mirror <- sum(mapply(box_sum, city_lon, 90 - city_lat))
ratio <- lit / max(mirror, 1e-9)
orient_ok <- ratio > 3
verdict <- if (orient_ok) {
  "orientation OK"
} else if (ratio < 1 / 3) {
  "tiles look UPSIDE DOWN"
} else {
  "inconclusive, inspect the tile"
}
txt <- sprintf(paste("Light around Almaty and Bishkek vs mirrored boxes",
                     "(h25v04, 2023): ratio %.1f -> %s"), ratio, verdict)
writeLines(txt, file.path(out_dir, "0_orientation.txt"))
message(txt)
if (!orient_ok) stop("Orientation check failed; inspect the tile first.")

# Step 1: annual overlap -----------------------------------------------------
message("Step 1: annual VNP46A4 vs VJ146A4, ",
        min(annual_years), "-", max(annual_years))
annual_saved <- file.path(out_dir, sprintf(
  "1_annual_long_%d-%d_t%dr%d.rds", min(annual_years), max(annual_years),
  length(annual_set$tiles), nrow(annual_set$regions)
))
if (file.exists(annual_saved)) {
  message("  already done, using saved results")
  la <- readRDS(annual_saved)
} else {
  ma <- rbind(
    fetch_grid("VNP46A4", as.character(annual_years), annual_set$tiles),
    fetch_grid("VJ146A4", as.character(annual_years), annual_set$tiles)
  )
  la <- ntl_extract(ma, annual_set$regions, id_col = id_col,
                    quality_max = 1)
  if (isTRUE(attr(ma, "complete"))) saveRDS(la, annual_saved)
}
sa <- ntl_splice(la, from = "VNP46A4", to = "VJ146A4", min_share_valid = 0.8)
ra <- ntl_splice_report(sa)
write.csv(ra, file.path(out_dir, "1_annual_splice.csv"), row.names = FALSE)

# Step 2: monthly overlap, one year at a time --------------------------------
message("Step 2: monthly VNP46A3 vs VJ146A3 for ",
        paste(monthly_years, collapse = ", "))
# Each finished product-year is saved, so a rerun skips it instead of
# downloading it again; incomplete years keep their files in the cache.
run_key <- sprintf("t%dr%d", length(monthly_set$tiles),
                   nrow(monthly_set$regions))
pieces <- list()
for (y in monthly_years) {
  for (prod in c("VNP46A3", "VJ146A3")) {
    key <- paste(prod, y)
    saved <- file.path(out_dir, sprintf("2_monthly_%s_%d_%s.rds", prod, y,
                                        run_key))
    if (file.exists(saved)) {
      message("  ", key, ": already done, using saved results")
      pieces[[key]] <- readRDS(saved)
      next
    }
    m <- fetch_grid(prod, sprintf("%d-%02d", y, 1:12), monthly_set$tiles)
    pieces[[key]] <- ntl_extract(m, monthly_set$regions, id_col = id_col,
                                 quality_max = 1)
    if (isTRUE(attr(m, "complete"))) {
      saveRDS(pieces[[key]], saved)
      ntl_cache_clear(m)
    }
  }
}
lmon <- do.call(rbind, pieces)
write.csv(as.data.frame(lmon), file.path(out_dir, "2_monthly_long.csv"),
          row.names = FALSE)

sm <- ntl_splice(lmon, from = "VNP46A3", to = "VJ146A3",
                 min_share_valid = 0.8)
sbm <- ntl_splice(lmon, from = "VNP46A3", to = "VJ146A3", by_month = TRUE,
                  min_share_valid = 0.8,
                  min_overlap = min(2, length(monthly_years)))
rm_ <- ntl_splice_report(sm)
rbm <- ntl_splice_report(sbm)
write.csv(rm_, file.path(out_dir, "2_monthly_splice.csv"), row.names = FALSE)
write.csv(rbm, file.path(out_dir, "2_monthly_by_month.csv"),
          row.names = FALSE)

# Summary --------------------------------------------------------------------
pts <- suppressWarnings(st_point_on_surface(st_geometry(regions_all)))
lat <- st_coordinates(pts)[, "Y"]
rbm$lat <- lat[match(rbm[[id_col]], regions_all[[id_col]])]
ok <- rbm$fallback %in% FALSE
median_b <- function(keep) {
  d <- rbm[keep %in% TRUE, ]
  if (nrow(d) == 0) return(NULL)
  aggregate(b ~ month, data = d, FUN = median)
}
season <- median_b(ok)
north <- median_b(ok & rbm$lat >= 48)

q <- function(x) {
  qs <- stats::quantile(x, c(0.1, 0.5, 0.9), na.rm = TRUE)
  paste(round(qs, 2), collapse = " / ")
}
by_month <- function(d) {
  if (is.null(d)) return("  (no regions)")
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
if (length(monthly_years) == 1) {
  lines <- c(
    lines, "",
    "Only one monthly year: each calendar-month factor rests on a single",
    "month per region. Add a year to MONTHLY_YEARS and run again to check",
    "that the pattern repeats (finished years are not downloaded again)."
  )
}
if (nrow(failed_files) > 0) {
  lines <- c(
    lines, "",
    paste0("Skipped files (", nrow(failed_files), "); the results above ",
           "lack these tile-periods. Run the script again to fetch them:"),
    paste(" ", failed_files$product, failed_files$tile, failed_files$period)
  )
}
writeLines(lines, file.path(out_dir, "summary.txt"))
cat(lines, sep = "\n")
