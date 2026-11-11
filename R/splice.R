#' Splice two sensors into one consistent series
#'
#' Puts an older series (`from`, e.g. Suomi NPP `VNP46A3`) on the scale of a
#' newer one (`to`, e.g. NOAA-20 `VJ146A3`) using the periods both observe,
#' and reports level shifts per unit so you can judge whether the splice is
#' innocuous or a research problem in itself.
#'
#' Calibration is estimated per unit (and per calendar month if
#' `by_month = TRUE`) on overlap periods where both series are observed:
#' * `"ratio"`: `to = k * from`, with `k = sum(to) / sum(from)`.
#'   Multiplicative, so it also applies to means and adjusted sums.
#' * `"regression"`: `to = a + b * from` by OLS; adjusted values are
#'   floored at zero.
#' * `"none"`: no adjustment; series are simply stacked.
#'
#' Units with fewer than `min_overlap` overlap observations (or no light in
#' `from`) fall back to the pooled calibration and are flagged in the
#' diagnostics.
#'
#' The spliced series uses adjusted `from` values before `switch_at` and
#' `to` values from `switch_at` on, so the sensor never alternates from one
#' period to the next. With `fill_gaps = TRUE`, missing `to` values after
#' the switch are filled with adjusted `from` values where available.
#'
#' @param x An `ntl_long` data frame (from [ntl_extract()]) holding both
#'   series, e.g. `rbind()` of two extractions.
#' @param from,to Series names (column `series`).
#' @param value Outcome column to calibrate.
#' @param id_col Unit identifier column.
#' @param method `"ratio"`, `"regression"` or `"none"`.
#' @param overlap Optional overlap window used for estimation: two periods
#'   (start and end) or a vector of periods. Defaults to every period both
#'   series observe.
#' @param by_month Estimate a separate calibration for each calendar month
#'   (monthly data). Useful at high latitude, where the two satellites'
#'   summer coverage differs.
#' @param switch_at First period taken from `to`. Defaults to the first
#'   period in which `to` has data.
#' @param fill_gaps Fill missing `to` values after the switch with adjusted
#'   `from` values.
#' @param min_overlap Minimum overlap observations per calibration group.
#' @param min_share_valid Only use overlap observations where both series
#'   have at least this coverage share for estimation.
#' @return An `ntl_long` data frame with one series named `"<from>+<to>"`
#'   and a column `origin` saying where each value came from. The
#'   calibration diagnostics are in `ntl_splice_report()`.
#' @examples
#' ex <- ntl_example()
#' m <- ntl_files(ex$dir, "eog_vnl_monthly")
#' m <- m[m$period >= as.Date("2022-04-01") &
#'          m$period <= as.Date("2023-03-01"), ]
#' long <- ntl_extract(m, ex$units_old, id_col = "district", quiet = TRUE)
#' sp <- ntl_splice(long,
#'   from = "eog_vnl_monthly_npp", to = "eog_vnl_monthly_j01"
#' )
#' head(sp)
#' @export
ntl_splice <- function(x, from, to, value = "ntl_sum", id_col = NULL,
                       method = c("ratio", "regression", "none"),
                       overlap = NULL, by_month = FALSE, switch_at = NULL,
                       fill_gaps = FALSE, min_overlap = 3,
                       min_share_valid = NULL) {
  method <- match.arg(method)
  id_col <- id_col %||% attr(x, "id_col") %||% "unit_id"
  df <- x
  class(df) <- "data.frame"
  .check_cols(df, c(id_col, "series", "period", value), "x")
  for (s in c(from, to)) {
    if (!s %in% df$series) .stop("Series '", s, "' not found in `x$series`.")
  }
  df$period <- as.Date(df$period)
  freq <- attr(x, "frequency") %||% .infer_frequency(df$period)
  from_df <- df[df$series == from, , drop = FALSE]
  to_df <- df[df$series == to, , drop = FALSE]

  pair <- .splice_pairs(from_df, to_df, id_col, value, min_share_valid,
                        overlap, freq)
  if (method != "none" && nrow(pair) == 0) {
    .stop("No period with both '", from, "' and '", to,
          "' observed; cannot calibrate.")
  }
  group_of <- function(id, period) {
    if (isTRUE(by_month)) {
      paste(id, format(period, "%m"), sep = "|")
    } else {
      as.character(id)
    }
  }
  pair$group <- group_of(pair[[id_col]], pair$period)
  groups <- unique(c(group_of(from_df[[id_col]], from_df$period), pair$group))
  pooled <- .calibrate(pair$v_from, pair$v_to, method)
  diag <- .splice_diagnostics(pair, groups, pooled, method, min_overlap)

  from_adj <- .splice_adjust(from_df, diag,
                             group_of(from_df[[id_col]], from_df$period),
                             value, method)
  switch_at <- .splice_switch(switch_at, to_df, value, df$period, freq)
  out <- .splice_combine(from_adj, to_df, switch_at, id_col, value, from, to,
                         method, fill_gaps)
  out$series <- paste0(from, "+", to)
  out$product <- "spliced"
  if ("platform" %in% names(out)) {
    platforms <- unique(stats::na.omit(c(from_df$platform, to_df$platform)))
    out$platform <- paste(platforms, collapse = " + ")
  }
  out <- out[order(out[[id_col]], out$period), , drop = FALSE]
  rownames(out) <- NULL
  res <- .new_long(out, id_col, freq)
  attr(res, "splice") <- list(
    from = from, to = to, method = method, by_month = by_month,
    switch_at = switch_at, pooled = pooled,
    diagnostics = .splice_tidy_diag(diag, id_col, by_month, method, df)
  )
  res
}

#' Diagnostics of a splice
#'
#' Returns the calibration table computed by [ntl_splice()]: for each unit
#' (and calendar month if `by_month = TRUE`) the number of overlap
#' observations, mean levels of both series, the level shift in percent,
#' their correlation, the coefficient of variation of the period-by-period
#' ratio (`ratio_cv`; large values mean an unstable relationship), the
#' calibration coefficients `a` and `b` (for `"ratio"`, `a = 0` and `b = k`)
#' and whether the pooled calibration was used as a fallback.
#'
#' @param x Output of [ntl_splice()].
#' @return A data frame with one row per unit (and calendar month).
#' @examples
#' ex <- ntl_example()
#' m <- ntl_files(ex$dir, "eog_vnl_monthly")
#' m <- m[m$period >= as.Date("2022-04-01") &
#'          m$period <= as.Date("2023-03-01"), ]
#' long <- ntl_extract(m, ex$units_old, id_col = "district", quiet = TRUE)
#' sp <- ntl_splice(long,
#'   from = "eog_vnl_monthly_npp", to = "eog_vnl_monthly_j01"
#' )
#' ntl_splice_report(sp)
#' @export
ntl_splice_report <- function(x) {
  s <- attr(x, "splice")
  if (is.null(s)) .stop("`x` was not produced by ntl_splice().")
  s$diagnostics
}

# Internals --------------------------------------------------------------------

# Overlap observations with both series observed, renamed v_from / v_to.
.splice_pairs <- function(from_df, to_df, id_col, value, min_share_valid,
                          overlap, freq) {
  has_sv <- "share_valid" %in% names(from_df)
  keep <- c(id_col, "period", value, if (has_sv) "share_valid")
  pair <- merge(from_df[, keep, drop = FALSE], to_df[, keep, drop = FALSE],
                by = c(id_col, "period"), suffixes = c("_from", "_to"))
  pair$v_from <- pair[[paste0(value, "_from")]]
  pair$v_to <- pair[[paste0(value, "_to")]]
  pair <- pair[!is.na(pair$v_from) & !is.na(pair$v_to), , drop = FALSE]
  if (!is.null(min_share_valid) && has_sv) {
    ok <- pair$share_valid_from >= min_share_valid &
      pair$share_valid_to >= min_share_valid
    pair <- pair[ok, , drop = FALSE]
  }
  if (!is.null(overlap)) {
    o <- .floor_period(.parse_period(overlap), freq)
    keep_rows <- if (length(o) == 2) {
      pair$period >= min(o) & pair$period <= max(o)
    } else {
      pair$period %in% o
    }
    pair <- pair[keep_rows, , drop = FALSE]
  }
  pair
}

.splice_diagnostics <- function(pair, groups, pooled, method, min_overlap) {
  rows <- lapply(groups, function(gk) {
    p <- pair[pair$group == gk, , drop = FALSE]
    n <- nrow(p)
    est <- if (n >= min_overlap) .calibrate(p$v_from, p$v_to, method)
    fallback <- is.null(est) || !all(is.finite(c(est$a, est$b)))
    if (fallback) est <- pooled
    data.frame(group = gk, n_overlap = n, .overlap_stats(p$v_from, p$v_to),
               a = est$a, b = est$b, fallback = fallback,
               stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

.overlap_stats <- function(vf, vt) {
  n <- length(vf)
  mf <- if (n) mean(vf) else NA_real_
  mt <- if (n) mean(vt) else NA_real_
  shift <- if (n && mf > 0) 100 * (mt / mf - 1) else NA_real_
  varies <- n >= 3 && stats::sd(vf) > 0 && stats::sd(vt) > 0
  r <- vt / vf
  r <- r[is.finite(r)]
  cv <- if (length(r) >= 2 && mean(r) != 0) stats::sd(r) / mean(r) else NA_real_
  data.frame(mean_from = mf, mean_to = mt, level_shift_pct = shift,
             cor = if (varies) stats::cor(vf, vt) else NA_real_,
             ratio_cv = cv)
}

.splice_adjust <- function(from_df, diag, groups, value, method) {
  a <- diag$a[match(groups, diag$group)]
  b <- diag$b[match(groups, diag$group)]
  out <- from_df
  adj <- a + b * from_df[[value]]
  if (method == "regression") adj <- pmax(adj, 0)
  out[[value]] <- adj
  others <- intersect(c("ntl_sum", "ntl_sum_adj", "ntl_mean"), names(out))
  for (oc in setdiff(others, value)) {
    out[[oc]] <- if (method == "regression") NA_real_ else from_df[[oc]] * b
  }
  out
}

.splice_switch <- function(switch_at, to_df, value, periods, freq) {
  if (!is.null(switch_at)) {
    return(.floor_period(.parse_period(switch_at), freq))
  }
  observed <- to_df$period[!is.na(to_df[[value]])]
  if (length(observed)) min(observed) else max(periods) + 1
}

.splice_combine <- function(from_adj, to_df, switch_at, id_col, value, from,
                            to, method, fill_gaps) {
  early <- from_adj[from_adj$period < switch_at, , drop = FALSE]
  label <- if (method == "none") from else paste0(from, " (adjusted)")
  early$origin <- rep(label, nrow(early))
  late <- to_df[to_df$period >= switch_at, , drop = FALSE]
  late$origin <- rep(to, nrow(late))
  if (isTRUE(fill_gaps)) {
    late <- .splice_fill(late, from_adj[from_adj$period >= switch_at, ,
                                        drop = FALSE],
                         id_col, value, from)
  }
  rbind(early, late)
}

.splice_fill <- function(late, late_from, id_col, value, from) {
  k_to <- paste(late[[id_col]], late$period)
  k_from <- paste(late_from[[id_col]], late_from$period)
  gap <- is.na(late[[value]]) & k_to %in% k_from
  if (!any(gap)) return(late)
  src <- late_from[match(k_to[gap], k_from), , drop = FALSE]
  src$origin <- rep(paste0(from, " (adjusted, gap fill)"), nrow(src))
  has_src <- !is.na(src[[value]])
  still_gap <- late[gap, , drop = FALSE][!has_src, , drop = FALSE]
  rbind(late[!gap, , drop = FALSE], src[has_src, , drop = FALSE], still_gap)
}

.splice_tidy_diag <- function(diag, id_col, by_month, method, df) {
  parts <- strsplit(diag$group, "|", fixed = TRUE)
  diag[[id_col]] <- vapply(parts, `[`, "", 1)
  if (is.numeric(df[[id_col]])) diag[[id_col]] <- as.numeric(diag[[id_col]])
  if (isTRUE(by_month)) diag$month <- as.integer(vapply(parts, `[`, "", 2))
  diag$method <- method
  diag$group <- NULL
  front <- c(id_col, if (isTRUE(by_month)) "month")
  diag[, c(front, setdiff(names(diag), front)), drop = FALSE]
}

.calibrate <- function(from, to, method) {
  if (method == "none") return(list(a = 0, b = 1))
  if (method == "ratio") {
    den <- sum(from)
    if (!is.finite(den) || den <= 0) return(list(a = 0, b = NA_real_))
    return(list(a = 0, b = sum(to) / den))
  }
  if (length(from) < 2 || stats::var(from) == 0) {
    return(list(a = NA_real_, b = NA_real_))
  }
  co <- stats::coef(stats::lm.fit(cbind(1, from), to))
  list(a = unname(co[1]), b = unname(co[2]))
}
