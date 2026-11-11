#' Mask low-quality, under-observed and gas-flare pixels
#'
#' Applies explicit, recorded masking rules to a raster returned by
#' [ntl_read()] or [ntl_read_bm()]. Every pixel that had a value but was
#' removed is marked in an extra `masked` layer, so [ntl_aggregate()] can
#' report the share of each unit lost to masking.
#'
#' Black Marble monthly and annual quality flags are: `0` good (more than
#' three observations), `1` poor (three or fewer observations), `2`
#' gap-filled from earlier data. The default `quality_max = 1` drops
#' gap-filled pixels: they carry past values forward and would bias
#' estimated effects toward zero.
#'
#' Pixels with zero cloud-free observations (`nobs == 0`) are always
#' treated as unobserved, whatever their stored value: EOG monthly
#' composites store 0 radiance there, which would otherwise be read as
#' "dark". They lower `share_valid` but are not counted as masked.
#'
#' @param x A `SpatRaster` with a `value` layer and optionally `nobs` and
#'   `quality` layers.
#' @param quality_max Keep pixels with `quality <= quality_max`. `NULL`
#'   disables the rule. Ignored if there is no `quality` layer.
#' @param min_obs Keep pixels with at least this many cloud-free
#'   observations. `NULL` disables the rule. Ignored if there is no `nobs`
#'   layer.
#' @param flares Optional gas-flare mask: an `sf`/`SpatVector` of polygons
#'   or a `SpatRaster` whose non-zero cells are flares. Pixels touching a
#'   flare polygon are removed.
#' @param cap Optional upper bound; values above it are set to `cap`
#'   (top-coding of extreme outliers, applied after masking).
#' @return `x` with masked pixels set to `NA` in `value` and an added
#'   `masked` layer (1 = removed by a rule, 0 = kept, `NA` = no data).
#' @examples
#' ex <- ntl_example()
#' m <- ntl_files(ex$dir, "eog_vnl_monthly")
#' r <- ntl_read(m, period = "2022-06", series = "eog_vnl_monthly_npp")
#' rm <- ntl_mask(r, min_obs = 2)
#' terra::global(rm$masked, "sum", na.rm = TRUE)
#' @export
ntl_mask <- function(x, quality_max = 1, min_obs = NULL, flares = NULL, cap = NULL) {
  if (!inherits(x, "SpatRaster") || !"value" %in% names(x)) {
    .stop("`x` must be a SpatRaster with a 'value' layer (see ntl_read()).")
  }
  v <- x[["value"]]
  # Pixels with zero cloud-free observations are unobserved, whatever their
  # value says (EOG composites store 0 there). This is not counted as masking.
  if ("nobs" %in% names(x)) v <- terra::ifel(!is.na(x[["nobs"]]) & x[["nobs"]] == 0, NA, v)
  drop <- NULL
  add_rule <- function(cond) {
    cond <- terra::ifel(is.na(cond), 0, cond)
    if (is.null(drop)) cond else (drop + cond) > 0
  }
  if (!is.null(quality_max) && "quality" %in% names(x)) {
    drop <- add_rule(x[["quality"]] > quality_max)
  }
  if (!is.null(min_obs) && "nobs" %in% names(x)) {
    drop <- add_rule(x[["nobs"]] < min_obs)
  }
  if (!is.null(flares)) {
    drop <- add_rule(.flare_raster(flares, v))
  }
  if (is.null(drop)) {
    masked <- terra::ifel(is.na(v), NA, 0)
  } else {
    masked <- terra::ifel(is.na(v), NA, drop)
    v <- terra::ifel(drop > 0, NA, v)
  }
  if (!is.null(cap)) v <- terra::ifel(v > cap, cap, v)
  names(v) <- "value"
  names(masked) <- "masked"
  others <- setdiff(names(x), c("value", "masked"))
  out <- c(v, masked)
  if (length(others) > 0) out <- c(out, x[[others]])
  out
}

.flare_raster <- function(flares, template) {
  if (inherits(flares, "SpatRaster")) {
    f <- terra::resample(flares[[1]], template, method = "near")
    return(terra::ifel(is.na(f), 0, f != 0))
  }
  fl <- .as_sf(flares, "flares")
  fl <- sf::st_transform(fl, terra::crs(template))
  terra::rasterize(terra::vect(fl), template, field = 1, background = 0, touches = TRUE)
}
