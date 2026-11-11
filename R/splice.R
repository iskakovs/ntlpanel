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
#' m <- m[m$period >= as.Date("2022-04-01") & m$period <= as.Date("2023-03-01"), ]
#' long <- ntl_extract(m, ex$units_old, id_col = "district", quiet = TRUE)
#' sp <- ntl_splice(long, from = "eog_vnl_monthly_npp", to = "eog_vnl_monthly_j01")
#' ntl_splice_report(sp)
#' @export
ntl_splice <- function(x, from, to, value = "ntl_sum", id_col = NULL,
                       method = c("ratio", "regression", "none"),
                       overlap = NULL, by_month = FALSE, switch_at = NULL,
                       fill_gaps = FALSE, min_overlap = 3, min_share_valid = NULL) {
  method <- match.arg(method)
  id_col <- id_col %||% attr(x, "id_col") %||% "unit_id"
  freq <- attr(x, "frequency")
  df <- x
  class(df) <- "data.frame"
  .check_cols(df, c(id_col, "series", "period", value), "x")
  for (s in c(from, to)) {
    if (!s %in% df$series) .stop("Series '", s, "' not found in `x$series`.")
  }
  df$period <- as.Date(df$period)
  A <- df[df$series == from, , drop = FALSE]
  B <- df[df$series == to, , drop = FALSE]
  freq <- freq %||% .infer_frequency(df$period)

  # Overlap pairs ---------------------------------------------------------------
  keep_cols <- c(id_col, "period", value, if ("share_valid" %in% names(df)) "share_valid")
  pair <- merge(A[, keep_cols, drop = FALSE], B[, keep_cols, drop = FALSE],
                by = c(id_col, "period"), suffixes = c("_from", "_to"))
  vf <- paste0(value, "_from")
  vt <- paste0(value, "_to")
  pair <- pair[!is.na(pair[[vf]]) & !is.na(pair[[vt]]), , drop = FALSE]
  if (!is.null(min_share_valid) && "share_valid_from" %in% names(pair)) {
    pair <- pair[pair$share_valid_from >= min_share_valid &
                   pair$share_valid_to >= min_share_valid, , drop = FALSE]
  }
  if (!is.null(overlap)) {
    o <- .floor_period(.parse_period(overlap), freq)
    pair <- if (length(o) == 2) {
      pair[pair$period >= min(o) & pair$period <= max(o), , drop = FALSE]
    } else {
      pair[pair$period %in% o, , drop = FALSE]
    }
  }
  if (method != "none" && nrow(pair) == 0) {
    .stop("No period with both '", from, "' and '", to, "' observed; cannot calibrate.")
  }
  pair$month <- as.integer(format(pair$period, "%m"))

  # Calibration -----------------------------------------------------------------
  group_of <- function(id, period) {
    if (isTRUE(by_month)) paste(id, format(period, "%m"), sep = "|") else as.character(id)
  }
  pooled <- .calibrate(pair[[vf]], pair[[vt]], method)
  pair$group <- group_of(pair[[id_col]], pair$period)
  groups <- unique(c(group_of(A[[id_col]], A$period), pair$group))
  diag <- lapply(groups, function(gk) {
    p <- pair[pair$group == gk, , drop = FALSE]
    n <- nrow(p)
    est <- if (n >= min_overlap) .calibrate(p[[vf]], p[[vt]], method) else NULL
    fallback <- is.null(est) || !all(is.finite(c(est$a, est$b)))
    if (fallback) est <- pooled
    r <- p[[vt]] / p[[vf]]
    r <- r[is.finite(r)]
    data.frame(
      group = gk, n_overlap = n,
      mean_from = if (n) mean(p[[vf]]) else NA_real_,
      mean_to = if (n) mean(p[[vt]]) else NA_real_,
      level_shift_pct = if (n && mean(p[[vf]]) > 0) 100 * (mean(p[[vt]]) / mean(p[[vf]]) - 1) else NA_real_,
      cor = if (n >= 3 && stats::sd(p[[vf]]) > 0 && stats::sd(p[[vt]]) > 0) stats::cor(p[[vf]], p[[vt]]) else NA_real_,
      ratio_cv = if (length(r) >= 2 && mean(r) != 0) stats::sd(r) / mean(r) else NA_real_,
      a = est$a, b = est$b, fallback = fallback,
      stringsAsFactors = FALSE
    )
  })
  diag <- do.call(rbind, diag)
  parts <- strsplit(diag$group, "|", fixed = TRUE)
  diag[[id_col]] <- vapply(parts, `[`, "", 1)
  if (is.numeric(df[[id_col]])) diag[[id_col]] <- as.numeric(diag[[id_col]])
  if (isTRUE(by_month)) diag$month <- as.integer(vapply(parts, `[`, "", 2))
  diag$method <- method
  front <- c(id_col, if (isTRUE(by_month)) "month")
  diag <- diag[, c(front, setdiff(names(diag), front)), drop = FALSE]

  # Apply ---------------------------------------------------------------------
  gA <- group_of(A[[id_col]], A$period)
  aa <- diag$a[match(gA, diag$group)]
  bb <- diag$b[match(gA, diag$group)]
  adjust <- function(v) {
    out <- aa + bb * v
    if (method == "regression") out <- pmax(out, 0)
    out
  }
  A_adj <- A
  A_adj[[value]] <- adjust(A[[value]])
  other <- setdiff(intersect(c("ntl_sum", "ntl_sum_adj", "ntl_mean"), names(A)), value)
  for (oc in other) {
    A_adj[[oc]] <- if (method == "regression") NA_real_ else A[[oc]] * bb
  }

  if (is.null(switch_at)) {
    obs_B <- B$period[!is.na(B[[value]])]
    switch_at <- if (length(obs_B)) min(obs_B) else max(df$period) + 1
  } else {
    switch_at <- .floor_period(.parse_period(switch_at), freq)
  }
  part_A <- A_adj[A_adj$period < switch_at, , drop = FALSE]
  part_A$origin <- rep(if (method == "none") from else paste0(from, " (adjusted)"), nrow(part_A))
  part_B <- B[B$period >= switch_at, , drop = FALSE]
  part_B$origin <- rep(to, nrow(part_B))
  if (isTRUE(fill_gaps)) {
    late_A <- A_adj[A_adj$period >= switch_at, , drop = FALSE]
    kB <- paste(part_B[[id_col]], part_B$period)
    kA <- paste(late_A[[id_col]], late_A$period)
    gap <- is.na(part_B[[value]]) & kB %in% kA
    if (any(gap)) {
      src <- late_A[match(kB[gap], kA), , drop = FALSE]
      src$origin <- rep(paste0(from, " (adjusted, gap fill)"), nrow(src))
      part_B <- rbind(part_B[!gap, , drop = FALSE], src[!is.na(src[[value]]), , drop = FALSE],
                      part_B[gap, , drop = FALSE][is.na(src[[value]]), , drop = FALSE])
    }
  }
  out <- rbind(part_A, part_B)
  out$series <- paste0(from, "+", to)
  out$product <- "spliced"
  if ("platform" %in% names(out)) {
    out$platform <- paste(unique(stats::na.omit(c(A$platform, B$platform))), collapse = " + ")
  }
  out <- out[order(out[[id_col]], out$period), , drop = FALSE]
  rownames(out) <- NULL
  res <- .new_long(out, id_col, freq)
  diag$group <- NULL
  attr(res, "splice") <- list(from = from, to = to, method = method,
                              by_month = by_month, switch_at = switch_at,
                              pooled = pooled, diagnostics = diag)
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
#' @return A data frame.
#' @export
ntl_splice_report <- function(x) {
  s <- attr(x, "splice")
  if (is.null(s)) .stop("`x` was not produced by ntl_splice().")
  s$diagnostics
}

.calibrate <- function(from, to, method) {
  if (method == "none") return(list(a = 0, b = 1))
  if (method == "ratio") {
    den <- sum(from)
    if (!is.finite(den) || den <= 0) return(list(a = 0, b = NA_real_))
    return(list(a = 0, b = sum(to) / den))
  }
  if (length(from) < 2 || stats::var(from) == 0) return(list(a = NA_real_, b = NA_real_))
  co <- stats::coef(stats::lm.fit(cbind(1, from), to))
  list(a = unname(co[1]), b = unname(co[2]))
}
