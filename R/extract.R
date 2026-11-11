#' Zonal statistics with coverage diagnostics
#'
#' Summarises a (masked) nighttime lights raster over polygons using exact
#' pixel coverage fractions (exactextractr), and reports how much of each
#' unit was actually observed.
#'
#' @param x A `SpatRaster` with a `value` layer and optionally `masked` and
#'   `nobs` layers (see [ntl_mask()]).
#' @param units Polygons: `sf` or `SpatVector`.
#' @param id_col Column of `units` with unique identifiers. If `NULL`, row
#'   numbers are used and the output column is called `unit_id`.
#' @return A data frame with one row per unit:
#' \describe{
#'   \item{ntl_sum}{Sum of lights over observed pixels (coverage-weighted).
#'     `NA` when nothing was observed, so "dark" (0) and "unobserved" (`NA`)
#'     stay distinct.}
#'   \item{ntl_sum_adj}{`ntl_sum / share_valid`: the sum scaled up to the
#'     full unit, assuming unobserved pixels resemble observed ones.}
#'   \item{ntl_mean}{Mean radiance of observed pixels.}
#'   \item{share_valid}{Share of the unit's pixels with a valid value.}
#'   \item{share_masked}{Share removed by [ntl_mask()] rules.}
#'   \item{mean_obs}{Mean number of cloud-free observations per pixel.}
#'   \item{n_pixels}{Number of pixels covering the unit (fractional).}
#' }
#' @examples
#' ex <- ntl_example()
#' m <- ntl_files(ex$dir, "eog_vnl_monthly")
#' r <- ntl_read(m, period = "2022-06", series = "eog_vnl_monthly_npp")
#' r <- ntl_mask(r)
#' ntl_aggregate(r, ex$units_old, id_col = "district")
#' @export
ntl_aggregate <- function(x, units, id_col = NULL) {
  if (!inherits(x, "SpatRaster") || !"value" %in% names(x)) {
    .stop("`x` must be a SpatRaster with a 'value' layer.")
  }
  units <- .as_sf(units, "units")
  ids <- .unit_ids(units, id_col)
  units <- sf::st_transform(units, terra::crs(x))
  lyr <- intersect(c("value", "masked", "nobs"), names(x))
  res <- exactextractr::exact_extract(x[[lyr]], units, fun = .zonal_summary,
                                      summarize_df = TRUE, progress = FALSE)
  if (!is.data.frame(res)) res <- do.call(rbind, res)
  out <- data.frame(id = ids, res, stringsAsFactors = FALSE)
  names(out)[1] <- id_col %||% "unit_id"
  rownames(out) <- NULL
  out
}

# Coverage-aware summary of one unit's pixels (used by exact_extract).
.zonal_summary <- function(df) {
  # Drop numerical slivers: polygon edges that coincide with pixel edges get
  # coverage fractions of ~1e-15 on neighbouring pixels.
  df <- df[df$coverage_fraction > 1e-9, , drop = FALSE]
  cf <- df$coverage_fraction
  v <- df$value
  tot <- sum(cf)
  ok <- !is.na(v)
  valid <- sum(cf[ok])
  observed <- valid > 0
  s <- if (observed) sum(v[ok] * cf[ok]) else NA_real_
  share_masked <- NA_real_
  if ("masked" %in% names(df) && tot > 0) {
    share_masked <- sum(cf * (df$masked %in% 1)) / tot
  }
  mean_obs <- NA_real_
  if ("nobs" %in% names(df) && any(!is.na(df$nobs))) {
    okn <- !is.na(df$nobs)
    mean_obs <- sum(df$nobs[okn] * cf[okn]) / sum(cf[okn])
  }
  data.frame(
    ntl_sum = s,
    ntl_sum_adj = if (observed) s * tot / valid else NA_real_,
    ntl_mean = if (observed) s / valid else NA_real_,
    share_valid = if (tot > 0) valid / tot else NA_real_,
    share_masked = share_masked,
    mean_obs = mean_obs,
    n_pixels = tot
  )
}

#' Extract nighttime lights for many periods
#'
#' The workhorse of the package: for every series and period in a manifest
#' it reads the files ([ntl_read()]), applies masking rules ([ntl_mask()])
#' and computes zonal statistics with coverage diagnostics
#' ([ntl_aggregate()]). Periods are processed one at a time, so memory use
#' does not grow with the length of the series.
#'
#' Pixels belonging to tiles missing from the archive are treated as
#' unobserved, so they lower `share_valid` instead of silently changing the
#' area being summed.
#'
#' @param manifest A manifest from [ntl_fetch()] or [ntl_files()]. Several
#'   manifests can be combined with `rbind()`.
#' @inheritParams ntl_aggregate
#' @inheritParams ntl_mask
#' @inheritParams ntl_read_bm
#' @param quiet Suppress progress messages.
#' @return An `ntl_long` data frame: one row per unit, series and period,
#'   with the columns described in [ntl_aggregate()] plus `series`,
#'   `product`, `platform`, `period` and `period_label`.
#' @examples
#' ex <- ntl_example()
#' m <- ntl_files(ex$dir, "eog_vnl_monthly")
#' m <- m[m$period <= as.Date("2021-06-01"), ] # keep the example fast
#' long <- ntl_extract(m, ex$units_old, id_col = "district", min_obs = 1)
#' head(long)
#' @export
ntl_extract <- function(manifest, units, id_col = NULL, quality_max = 1,
                        min_obs = NULL, flares = NULL, cap = NULL,
                        variable = NULL, flip = NA, quiet = FALSE) {
  .check_cols(manifest, c("product", "series", "period", "file"), "manifest")
  units <- .to_lonlat(.as_sf(units, "units"))
  .unit_ids(units, id_col)
  ext <- .aoi_extent(units)
  m <- manifest[!is.na(manifest$file), , drop = FALSE]
  if (nrow(m) == 0) .stop("The manifest has no files.")
  key <- paste(m$series, format(m$period), sep = "|")
  groups <- split(seq_len(nrow(m)), factor(key, levels = unique(key)))
  out <- vector("list", length(groups))
  for (k in seq_along(groups)) {
    g <- m[groups[[k]], , drop = FALSE]
    .msg(quiet, "Extracting ", g$series[1], " ", g$period_label[1],
         " (", k, "/", length(groups), ")")
    r <- .read_group(g, ext, variable, flip)
    if (is.null(r)) next
    r <- ntl_mask(r, quality_max = quality_max, min_obs = min_obs,
                  flares = flares, cap = cap)
    a <- ntl_aggregate(r, units, id_col)
    a$series <- g$series[1]
    a$product <- g$product[1]
    a$platform <- g$platform[1]
    a$period <- g$period[1]
    a$period_label <- g$period_label[1]
    out[[k]] <- a
  }
  res <- do.call(rbind, out)
  if (is.null(res)) .stop("No file overlapped the units.")
  idn <- id_col %||% "unit_id"
  front <- c(idn, "series", "product", "platform", "period", "period_label")
  res <- res[, c(front, setdiff(names(res), front)), drop = FALSE]
  res <- res[order(res$series, res[[idn]], res$period), , drop = FALSE]
  rownames(res) <- NULL
  .new_long(res, idn, unique(m$frequency)[1])
}

.new_long <- function(df, id_col, frequency) {
  attr(df, "id_col") <- id_col
  attr(df, "frequency") <- frequency
  class(df) <- c("ntl_long", "data.frame")
  df
}

.keep_attrs <- c("id_col", "frequency", "splice", "value", "transform",
                 "gap_report")

#' @export
`[.ntl_long` <- function(x, ...) {
  a <- attributes(x)[intersect(.keep_attrs, names(attributes(x)))]
  out <- NextMethod()
  if (is.data.frame(out)) for (n in names(a)) attr(out, n) <- a[[n]]
  out
}

#' @export
print.ntl_long <- function(x, ...) {
  y <- x
  class(y) <- "data.frame"
  idn <- attr(x, "id_col") %||% "unit_id"
  if (!all(c(idn, "period", "series") %in% names(y))) {
    print(y, ...)
    return(invisible(x))
  }
  cat("<ntl_long> ", length(unique(y[[idn]])), " unit(s) x ",
      length(unique(y$period)), " period(s); series: ",
      paste(unique(y$series), collapse = ", "), "\n", sep = "")
  print(utils::head(y, 10), row.names = FALSE)
  if (nrow(y) > 10) cat("... ", nrow(y) - 10, " more row(s)\n", sep = "")
  invisible(x)
}
