#' Handle missing and low-coverage observations explicitly
#'
#' Applies one documented rule to the missing cells of an [ntl_panel()],
#' and flags unit-months at risk of summer stray-light gaps. VIIRS cannot
#' observe at night when the sun barely sets, so units north of about 45
#' degrees have missing or contaminated values around the June solstice
#' (in northern Kazakhstan typically May to August). Silently averaging
#' whatever pixels remain creates spurious seasonal swings; this function
#' makes the choice visible.
#'
#' Rules:
#' * `"none"`: only add flags.
#' * `"drop"`: remove missing rows (the panel becomes unbalanced).
#' * `"interp"`: linear interpolation within each unit for interior runs of
#'   at most `max_gap` missing periods.
#' * `"seasonal"` (monthly panels): multiplicative fill
#'   `value = S[unit, month] * L[unit, year]`, where `S` is the unit's
#'   seasonal index (median ratio of a month to the deseasonalised annual
#'   level) and `L` is the unit's deseasonalised level in that year. A
#'   calendar month that is never observed for a unit cannot be filled and
#'   stays `NA`; consider annual data or dropping those months.
#'
#' Filled values are marked with `imputed = TRUE` and `impute_method`, so
#' you can run robustness checks with and without them.
#'
#' @param panel An `ntl_panel`.
#' @param rule One of `"interp"`, `"seasonal"`, `"drop"`, `"none"`.
#' @param max_gap Longest run of missing periods to interpolate
#'   (`rule = "interp"`).
#' @param units Optional unit polygons (with the panel's id column), used
#'   with `lat_threshold` to flag stray-light risk.
#' @param lat_threshold Latitude (degrees north) from which units are
#'   flagged during `months`. A unit's latitude is that of a point on its
#'   surface.
#' @param months Calendar months flagged as stray-light risk.
#' @return The panel with columns `imputed`, `impute_method` and, if
#'   `units` and `lat_threshold` are given, `lat` and `stray_light_risk`.
#'   The attribute `gap_report` counts missing cells by month before and
#'   after filling.
#' @examples
#' ex <- ntl_example()
#' m <- ntl_files(ex$dir, "eog_vnl_monthly")
#' m <- m[m$series == "eog_vnl_monthly_npp" & m$period < as.Date("2022-01-01"), ]
#' long <- ntl_extract(m, ex$units_old,
#'                     id_col = "district", quiet = TRUE)
#' p <- ntl_panel(long, min_share_valid = 0.5)
#' p2 <- ntl_gapfill(p, rule = "interp", max_gap = 2,
#'                   units = ex$units_old, lat_threshold = 48)
#' attr(p2, "gap_report")
#' @export
ntl_gapfill <- function(panel, rule = c("interp", "seasonal", "drop", "none"),
                        max_gap = 2, units = NULL, lat_threshold = NULL,
                        months = 5:8) {
  rule <- match.arg(rule)
  a <- .panel_attrs(panel)
  df <- panel
  class(df) <- "data.frame"
  .check_cols(df, c(a$id_col, "period", a$value), "panel")
  df <- df[order(df[[a$id_col]], df$period), , drop = FALSE]
  if (!"month" %in% names(df)) df$month <- as.integer(format(df$period, "%m"))
  if (!"year" %in% names(df)) df$year <- as.integer(format(df$period, "%Y"))

  if (!is.null(units) && !is.null(lat_threshold)) {
    u <- .to_lonlat(.as_sf(units, "units"))
    ids <- .unit_ids(u, a$id_col)
    pts <- suppressWarnings(sf::st_point_on_surface(sf::st_geometry(u)))
    lat <- sf::st_coordinates(pts)[, "Y"]
    df$lat <- lat[match(df[[a$id_col]], ids)]
    df$stray_light_risk <- !is.na(df$lat) & df$lat >= lat_threshold &
      a$frequency == "month" & df$month %in% months
  }

  before <- .gap_counts(df, a$value)
  if (!"imputed" %in% names(df)) df$imputed <- FALSE
  if (!"impute_method" %in% names(df)) df$impute_method <- NA_character_

  if (rule == "drop") {
    df <- df[!is.na(df[[a$value]]), , drop = FALSE]
  } else if (rule %in% c("interp", "seasonal")) {
    if (rule == "seasonal" && a$frequency != "month") {
      .stop("rule = 'seasonal' needs a monthly panel.")
    }
    idx <- split(seq_len(nrow(df)), df[[a$id_col]])
    for (ii in idx) {
      v <- df[[a$value]][ii]
      filled <- if (rule == "interp") {
        .interp_gaps(v, max_gap)
      } else {
        .seasonal_fill(v, df$year[ii], df$month[ii])
      }
      new <- is.na(v) & !is.na(filled)
      if (any(new)) {
        df[[a$value]][ii[new]] <- filled[new]
        df$imputed[ii[new]] <- TRUE
        df$impute_method[ii[new]] <- rule
      }
    }
  }
  df$ntl <- .transform_values(df[[a$value]], a$transform)
  df$ntl_missing <- is.na(df[[a$value]])
  after <- .gap_counts(df, a$value)
  rownames(df) <- NULL
  out <- .new_panel(df, a$id_col, a$value, a$frequency, a$transform)
  rep <- merge(before, after, by = "month", all = TRUE, suffixes = c("_before", "_after"))
  attr(out, "gap_report") <- rep
  out
}

.gap_counts <- function(df, value) {
  mo <- as.integer(format(df$period, "%m"))
  out <- stats::aggregate(list(missing = is.na(df[[value]])), list(month = mo), sum)
  out
}

.interp_gaps <- function(v, max_gap) {
  n <- length(v)
  out <- v
  na <- is.na(v)
  if (!any(na) || all(na)) return(out)
  r <- rle(na)
  ends <- cumsum(r$lengths)
  starts <- ends - r$lengths + 1
  for (k in which(r$values)) {
    s <- starts[k]
    e <- ends[k]
    if (s == 1 || e == n || (e - s + 1) > max_gap) next
    out[s:e] <- stats::approx(c(s - 1, e + 1), v[c(s - 1, e + 1)], xout = s:e)$y
  }
  out
}

# Multiplicative seasonal fill: value = S[month] * L[year], estimated from the
# observed cells of one unit by alternating between the seasonal index S
# (median ratio to the annual level, normalised to mean 1) and the
# deseasonalised annual level L.
.seasonal_fill <- function(v, year, month, max_iter = 200, tol = 1e-12) {
  ok <- !is.na(v)
  if (sum(ok) < 3) return(v)
  mk <- as.character(month)
  yk <- as.character(year)
  S <- stats::setNames(rep(1, 12), as.character(1:12))
  for (it in seq_len(max_iter)) {
    S_prev <- S
    L <- tapply(v[ok] / S[mk[ok]], yk[ok], mean, na.rm = TRUE)
    ratio <- v[ok] / L[yk[ok]]
    ratio[!is.finite(ratio)] <- NA
    Sm <- tapply(ratio, mk[ok], stats::median, na.rm = TRUE)
    S <- stats::setNames(rep(NA_real_, 12), as.character(1:12))
    S[names(Sm)] <- Sm
    S[!is.finite(S)] <- NA
    if (all(is.na(S))) return(v)
    S <- S / mean(S, na.rm = TRUE)
    S[!is.na(S) & S == 0] <- NA
    delta <- abs(S - S_prev)
    if (it > 1 && all(is.na(delta) | delta < tol)) break
  }
  L <- tapply(v[ok] / S[mk[ok]], yk[ok], mean, na.rm = TRUE)
  fill <- unname(S[mk] * L[yk])
  out <- v
  out[!ok] <- fill[!ok]
  out
}
