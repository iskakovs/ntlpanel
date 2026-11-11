# Internal helpers -------------------------------------------------------------

`%||%` <- function(x, y) if (is.null(x)) y else x

.stop <- function(...) stop(paste0(...), call. = FALSE)
.warn <- function(...) warning(paste0(...), call. = FALSE)

.msg <- function(quiet, ...) if (!isTRUE(quiet)) message(paste0(...))

.check_cols <- function(df, cols, arg = "data") {
  miss <- setdiff(cols, names(df))
  if (length(miss) > 0) {
    .stop("`", arg, "` is missing column(s): ", paste(miss, collapse = ", "))
  }
  invisible(TRUE)
}

.match_frequency <- function(frequency) {
  frequency <- match.arg(frequency, c("month", "year"))
  frequency
}

# Parse "YYYY", "YYYY-MM", "YYYY-MM-DD", numeric years or Dates into Dates.
.parse_period <- function(x) {
  if (inherits(x, "Date")) return(x)
  if (inherits(x, "POSIXt")) return(as.Date(x))
  x <- as.character(x)
  out <- rep(as.Date(NA), length(x))
  is_y <- grepl("^[0-9]{4}$", x)
  is_ym <- grepl("^[0-9]{4}-[0-9]{2}$", x)
  is_ymd <- grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", x)
  if (any(is_y)) out[is_y] <- as.Date(paste0(x[is_y], "-01-01"))
  if (any(is_ym)) out[is_ym] <- as.Date(paste0(x[is_ym], "-01"))
  if (any(is_ymd)) out[is_ymd] <- as.Date(x[is_ymd])
  if (anyNA(out[!is.na(x)])) {
    bad <- x[is.na(out) & !is.na(x)]
    .stop("Could not parse period(s): ", .first_few(bad, 5),
          ". Use 'YYYY', 'YYYY-MM', 'YYYY-MM-DD' or a Date.")
  }
  out
}

.floor_period <- function(d, frequency) {
  if (identical(frequency, "month")) {
    as.Date(format(d, "%Y-%m-01"))
  } else {
    as.Date(format(d, "%Y-01-01"))
  }
}

.period_seq <- function(start, end, frequency) {
  s <- .floor_period(.parse_period(start), frequency)
  e <- .floor_period(.parse_period(end), frequency)
  if (length(s) != 1 || length(e) != 1) {
    .stop("`start` and `end` must be single values.")
  }
  if (e < s) .stop("`end` is before `start`.")
  seq(s, e, by = frequency)
}

.period_label <- function(d, frequency) {
  if (identical(frequency, "month")) format(d, "%Y-%m") else format(d, "%Y")
}

# Coerce a spatial input to sf with a CRS.
.as_sf <- function(x, arg = "x") {
  if (inherits(x, "SpatVector")) x <- sf::st_as_sf(x)
  if (inherits(x, "bbox")) x <- sf::st_as_sfc(x)
  if (inherits(x, "sfc")) x <- sf::st_sf(geometry = x)
  if (is.numeric(x) && length(x) == 4 && !inherits(x, "sf")) {
    bb <- sf::st_bbox(
      c(xmin = x[[1]], ymin = x[[2]], xmax = x[[3]], ymax = x[[4]]),
      crs = sf::st_crs(4326)
    )
    x <- sf::st_sf(geometry = sf::st_as_sfc(bb))
  }
  if (!inherits(x, "sf")) {
    .stop("`", arg, "` must be an sf/sfc object, a terra SpatVector or a ",
          "numeric bbox c(xmin, ymin, xmax, ymax) in longitude/latitude.")
  }
  if (is.na(sf::st_crs(x))) {
    .stop("`", arg, "` has no coordinate reference system.")
  }
  x
}

.to_lonlat <- function(x) {
  if (isTRUE(sf::st_crs(x) == sf::st_crs(4326))) return(x)
  sf::st_transform(x, 4326)
}

# Run code with s2 switched off (planar operations on lon/lat rectangles).
.without_s2 <- function(expr) {
  old <- suppressMessages(sf::sf_use_s2())
  suppressMessages(sf::sf_use_s2(FALSE))
  on.exit(suppressMessages(sf::sf_use_s2(old)), add = TRUE)
  suppressMessages(force(expr))
}

.unit_ids <- function(units, id_col) {
  if (is.null(id_col)) {
    ids <- seq_len(nrow(units))
  } else {
    .check_cols(units, id_col, "units")
    ids <- units[[id_col]]
  }
  if (anyDuplicated(ids)) {
    .stop("Unit identifiers in `", id_col %||% "row number",
          "` must be unique.")
  }
  ids
}

.transform_values <- function(x, transform) {
  switch(transform,
    none = x,
    log1p = log1p(x),
    asinh = asinh(x),
    log = ifelse(x > 0, log(x), NA_real_),
    .stop("Unknown transform '", transform, "'.")
  )
}

.drop_geometry <- function(x) {
  if (inherits(x, "sf")) sf::st_drop_geometry(x) else x
}

.first_few <- function(x, n = 3) {
  paste(utils::head(x, n), collapse = ", ")
}
