#' Synthetic example data
#'
#' Writes a small, entirely synthetic nighttime lights dataset in EOG
#' monthly file format and returns matching vector data, so examples, tests
#' and the vignette run offline in seconds. **None of it is real data.**
#'
#' The area is a 6 x 6 degree box (66-72 E, 46-52 N) at 0.05 degree
#' resolution, with:
#' * two cities with steady growth and a winter brightening;
#' * two "treatment" sites that switch on in June 2022 and March 2023;
#' * a summer stray-light blackout north of 49 N in June and July (zero
#'   coverage, stored as 0 radiance as in EOG files) and thin coverage in
#'   May and August;
#' * a Suomi NPP series (`npp`, 2021-01 to 2023-12) and a NOAA-20 series
#'   (`j01`, 2022-07 to 2023-12) that reads about 8% brighter.
#'
#' @param dir Directory to write the GeoTIFFs to.
#' @param overwrite Rewrite files that already exist.
#' @return A list with `dir` (path), `units_old` (six districts, column
#'   `district`), `units_new` (a later vintage, column `district_new`, in
#'   which `D1` is split into `D1a`/`D1b` and `D5` and `D6` merge into
#'   `D56`) and `sites` (two dated treatment sites, columns `site` and
#'   `start`).
#' @examples
#' ex <- ntl_example()
#' ex$units_old
#' length(list.files(ex$dir))
#' @export
ntl_example <- function(dir = file.path(tempdir(), "ntlpanel-example"), overwrite = FALSE) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  res <- 0.05
  template <- terra::rast(xmin = 66, xmax = 72, ymin = 46, ymax = 52,
                          resolution = res, crs = "EPSG:4326")
  xy <- terra::xyFromCell(template, seq_len(terra::ncell(template)))
  lon <- xy[, 1]
  lat <- xy[, 2]
  cell <- seq_len(terra::ncell(template))
  blob <- function(x0, y0, peak, sd) peak * exp(-((lon - x0)^2 + (lat - y0)^2) / (2 * sd^2))
  base <- 0.3 + blob(67.5, 50.5, 40, 0.30) + blob(70.5, 47.5, 30, 0.25)
  site1 <- blob(69.2, 47.3, 15, 0.15)
  site2 <- blob(71.3, 50.8, 10, 0.15)
  pseudo_noise <- function(t, k) 1 + 0.04 * sin(cell * 12.9898 + t * 78.233 + k)

  north <- lat > 49
  month_layer <- function(date, scale, k) {
    t <- (as.integer(format(date, "%Y")) - 2021) * 12 + as.integer(format(date, "%m"))
    mo <- as.integer(format(date, "%m"))
    true <- base * (1.004^t) * (1 + 0.15 * (mo %in% c(12, 1, 2)))
    if (date >= as.Date("2022-06-01")) true <- true + site1
    if (date >= as.Date("2023-03-01")) true <- true + site2
    val <- true * scale * pseudo_noise(t, k)
    cov <- rep(8, length(cell))
    if (mo %in% c(6, 7)) cov[north] <- 0
    if (mo %in% c(5, 8)) cov[north] <- 2
    val[cov == 0] <- 0
    list(val = val, cov = cov)
  }
  stem <- function(platform, date) {
    end <- seq(date, by = "month", length.out = 2)[2] - 1
    sprintf("SVDNB_%s_%s-%s_75N060E_vcmslcfg_v10_c000000000000", platform,
            format(date, "%Y%m%d"), format(end, "%Y%m%d"))
  }
  plan <- rbind(
    data.frame(platform = "npp", scale = 1, k = 0,
               date = seq(as.Date("2021-01-01"), as.Date("2023-12-01"), by = "month")),
    data.frame(platform = "j01", scale = 1.08, k = 1,
               date = seq(as.Date("2022-07-01"), as.Date("2023-12-01"), by = "month"))
  )
  stems <- vapply(seq_len(nrow(plan)), function(i) stem(plan$platform[i], plan$date[i]), "")
  f_val <- file.path(dir, paste0(stems, ".avg_rade9h.tif"))
  f_cov <- file.path(dir, paste0(stems, ".cf_cvg.tif"))
  todo <- overwrite | !file.exists(f_val) | !file.exists(f_cov)
  if (any(todo)) {
    layers <- lapply(which(todo), function(i) month_layer(plan$date[i], plan$scale[i], plan$k[i]))
    vals <- terra::rast(template, nlyrs = sum(todo))
    covs <- terra::rast(template, nlyrs = sum(todo))
    vals <- terra::setValues(vals, do.call(cbind, lapply(layers, `[[`, "val")))
    covs <- terra::setValues(covs, do.call(cbind, lapply(layers, `[[`, "cov")))
    terra::writeRaster(vals, f_val[todo], overwrite = TRUE, datatype = "FLT4S")
    terra::writeRaster(covs, f_cov[todo], overwrite = TRUE, datatype = "INT2U")
  }

  rect <- function(x0, x1, y0, y1) {
    sf::st_polygon(list(matrix(c(x0, y0, x1, y0, x1, y1, x0, y1, x0, y0),
                               ncol = 2, byrow = TRUE)))
  }
  old <- sf::st_sf(
    district = paste0("D", 1:6),
    geometry = sf::st_sfc(
      rect(66, 68, 49, 52), rect(68, 70, 49, 52), rect(70, 72, 49, 52),
      rect(66, 68, 46, 49), rect(68, 70, 46, 49), rect(70, 72, 46, 49),
      crs = 4326
    )
  )
  new <- sf::st_sf(
    district_new = c("D1a", "D1b", "D2", "D3", "D4", "D56"),
    geometry = sf::st_sfc(
      rect(66, 67, 49, 52), rect(67, 68, 49, 52), rect(68, 70, 49, 52),
      rect(70, 72, 49, 52), rect(66, 68, 46, 49), rect(68, 72, 46, 49),
      crs = 4326
    )
  )
  sites <- sf::st_sf(
    site = c("S1", "S2"),
    start = as.Date(c("2022-06-01", "2023-03-01")),
    geometry = sf::st_sfc(sf::st_point(c(69.2, 47.3)), sf::st_point(c(71.3, 50.8)),
                          crs = 4326)
  )
  list(dir = normalizePath(dir, winslash = "/"), units_old = old,
       units_new = new, sites = sites)
}
