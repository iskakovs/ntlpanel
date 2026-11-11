#' Build a balanced, analysis-ready panel
#'
#' Turns the long output of [ntl_extract()] or [ntl_splice()] into a
#' balanced unit x period panel. Unit-periods that were never extracted
#' (for example because no file existed) are added with `NA` values instead
#' of disappearing, and low-coverage observations can be set to `NA` with
#' an explicit threshold.
#'
#' @param x An `ntl_long` data frame with a single series.
#' @param value Column holding the outcome (default `"ntl_sum"`).
#' @param id_col Unit identifier column. Defaults to the one recorded by
#'   [ntl_extract()].
#' @param min_share_valid If set, observations with `share_valid` below this
#'   threshold get `NA` values and `low_coverage = TRUE`.
#' @param transform Transformation stored in column `ntl`: `"log1p"`
#'   (default), `"asinh"`, `"log"` (zeros become `NA`) or `"none"`.
#' @param balance Complete the unit x period grid.
#' @param frequency `"month"` or `"year"`. Defaults to the frequency
#'   recorded by [ntl_extract()].
#' @return An `ntl_panel` data frame with the id column, `period`, `year`,
#'   `month` (monthly panels), `t` (consecutive integer time index),
#'   the outcome, `ntl` (transformed outcome), `ntl_missing`,
#'   `low_coverage` and the coverage diagnostics. The columns `t` and the id
#'   work directly with `fixest::feols(ntl ~ ... | id + t)`.
#' @examples
#' ex <- ntl_example()
#' m <- ntl_files(ex$dir, "eog_vnl_monthly")
#' m <- m[m$series == "eog_vnl_monthly_npp" & m$period < as.Date("2022-01-01"), ]
#' long <- ntl_extract(m, ex$units_old,
#'                     id_col = "district", quiet = TRUE)
#' p <- ntl_panel(long, min_share_valid = 0.5)
#' table(p$month, p$ntl_missing)
#' @export
ntl_panel <- function(x, value = "ntl_sum", id_col = NULL, min_share_valid = NULL,
                      transform = c("log1p", "asinh", "log", "none"),
                      balance = TRUE, frequency = NULL) {
  transform <- match.arg(transform)
  id_col <- id_col %||% attr(x, "id_col") %||% "unit_id"
  .check_cols(x, c(id_col, "period", value), "x")
  df <- x
  class(df) <- "data.frame"
  if ("series" %in% names(df) && length(unique(df$series)) > 1) {
    .stop("`x` contains several series (", paste(unique(df$series), collapse = ", "),
          "). Combine them with ntl_splice() or filter to one series first.")
  }
  df$period <- as.Date(df$period)
  frequency <- frequency %||% attr(x, "frequency") %||% .infer_frequency(df$period)
  frequency <- .match_frequency(frequency)
  if (anyDuplicated(df[, c(id_col, "period")])) {
    .stop("`x` has duplicated unit-period rows.")
  }
  if (isTRUE(balance)) {
    periods <- seq(min(df$period), max(df$period), by = frequency)
    grid <- expand.grid(id = unique(df[[id_col]]), period = periods,
                        stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE)
    names(grid)[1] <- id_col
    const <- intersect(c("series", "product", "platform"), names(df))
    df <- merge(grid, df, by = c(id_col, "period"), all.x = TRUE, sort = FALSE)
    for (cc in const) {
      vals <- unique(stats::na.omit(df[[cc]]))
      if (length(vals) == 1) df[[cc]][is.na(df[[cc]])] <- vals
    }
  }
  df$period_label <- .period_label(df$period, frequency)
  df$low_coverage <- FALSE
  if (!is.null(min_share_valid)) {
    if (!"share_valid" %in% names(df)) .stop("`x` has no share_valid column.")
    low <- !is.na(df$share_valid) & df$share_valid < min_share_valid
    df$low_coverage <- low
    df[[value]][low] <- NA
  }
  df$year <- as.integer(format(df$period, "%Y"))
  if (frequency == "month") df$month <- as.integer(format(df$period, "%m"))
  all_periods <- sort(unique(df$period))
  df$t <- match(df$period, all_periods)
  df$ntl <- .transform_values(df[[value]], transform)
  df$ntl_missing <- is.na(df[[value]])
  df <- df[order(df[[id_col]], df$period), , drop = FALSE]
  front <- c(id_col, "period", "period_label", "year",
             if (frequency == "month") "month", "t", value, "ntl", "ntl_missing",
             "low_coverage")
  df <- df[, c(front, setdiff(names(df), front)), drop = FALSE]
  rownames(df) <- NULL
  .new_panel(df, id_col, value, frequency, transform)
}

.new_panel <- function(df, id_col, value, frequency, transform) {
  attr(df, "id_col") <- id_col
  attr(df, "value") <- value
  attr(df, "frequency") <- frequency
  attr(df, "transform") <- transform
  class(df) <- c("ntl_panel", "data.frame")
  df
}

.panel_attrs <- function(x) {
  list(id_col = attr(x, "id_col") %||% "unit_id",
       value = attr(x, "value") %||% "ntl_sum",
       frequency = attr(x, "frequency") %||% .infer_frequency(x$period),
       transform = attr(x, "transform") %||% "log1p")
}

.infer_frequency <- function(period) {
  if (any(format(as.Date(period), "%m") != "01")) "month" else "year"
}

#' @export
`[.ntl_panel` <- function(x, ...) {
  a <- attributes(x)[intersect(.keep_attrs, names(attributes(x)))]
  out <- NextMethod()
  if (is.data.frame(out)) for (n in names(a)) attr(out, n) <- a[[n]]
  out
}

#' @export
print.ntl_panel <- function(x, ...) {
  y <- x
  class(y) <- "data.frame"
  a <- .panel_attrs(x)
  if (!all(c(a$id_col, "period", "ntl_missing") %in% names(y))) {
    print(y, ...)
    return(invisible(x))
  }
  n_units <- length(unique(y[[a$id_col]]))
  n_t <- length(unique(y$period))
  cat("<ntl_panel> ", n_units, " unit(s) x ", n_t, " ", a$frequency,
      " period(s); outcome '", a$value, "', transform '", a$transform, "'; ",
      round(100 * mean(y$ntl_missing), 1), "% missing\n", sep = "")
  print(utils::head(y, 10), row.names = FALSE)
  if (nrow(y) > 10) cat("... ", nrow(y) - 10, " more row(s)\n", sep = "")
  invisible(x)
}
