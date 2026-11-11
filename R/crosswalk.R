#' Crosswalk between two boundary vintages
#'
#' Builds the weights needed to move tabular data between two sets of
#' administrative units, for example Kazakhstan's oblasts before and after
#' the 2022 reform that created Abai, Zhetysu and Ulytau regions.
#'
#' Nighttime lights themselves never need a crosswalk: extract them again
#' with the other boundaries. Crosswalks matter for official statistics
#' (GRP, employment, tax revenue) that exist only in one vintage and must be
#' merged with a lights panel built on the other.
#'
#' Weights come from the area of each intersection piece or, better for
#' economic variables, from a raster such as nighttime lights or
#' population summed over each piece (`weight_raster`). Units whose raster
#' total is zero fall back to area weights.
#'
#' @param from,to Polygons of the old and new vintage (`sf` or
#'   `SpatVector`).
#' @param from_id,to_id Identifier columns in `from` and `to`.
#' @param weight_raster Optional `SpatRaster` used for weighting.
#' @param min_share Pieces holding less than this share of both their
#'   `from` and `to` unit are treated as digitising slivers and dropped
#'   before re-normalising.
#' @return An `ntl_crosswalk` data frame with `from_id`, `to_id`,
#'   `area_km2`, `weight`, `w_from` (share of the `from` unit going to
#'   `to`; use for extensive variables such as totals), `w_to` (share of the
#'   `to` unit coming from `from`; use for intensive variables such as rates)
#'   and `relation` (`unchanged`, `split`, `merge` or `split-merge`).
#' @examples
#' ex <- ntl_example()
#' xw <- ntl_crosswalk(ex$units_old, ex$units_new, "district", "district_new")
#' xw
#' @export
ntl_crosswalk <- function(from, to, from_id, to_id, weight_raster = NULL,
                          min_share = 1e-3) {
  from <- .as_sf(from, "from")
  to <- .as_sf(to, "to")
  .unit_ids(from, from_id)
  .unit_ids(to, to_id)
  pieces <- .xw_pieces(from, to, from_id, to_id)
  area <- as.numeric(sf::st_area(pieces)) / 1e6
  df <- data.frame(from_id = pieces$from_id, to_id = pieces$to_id,
                   area_km2 = area, stringsAsFactors = FALSE)
  df <- stats::aggregate(area_km2 ~ from_id + to_id, data = df, FUN = sum)
  df$weight <- df$area_km2
  df$weight_source <- "area"
  if (!is.null(weight_raster)) {
    df <- .xw_raster_weights(df, pieces, weight_raster)
  }
  df <- .xw_shares(df)
  sliver <- df$w_from < min_share & df$w_to < min_share
  if (any(sliver)) df <- .xw_shares(df[!sliver, , drop = FALSE])
  df$relation <- .xw_relation(df)
  cols <- c("from_id", "to_id", "area_km2", "weight", "weight_source",
            "w_from", "w_to", "relation")
  df <- df[order(df$from_id, df$to_id), cols]
  rownames(df) <- NULL
  attr(df, "from_id") <- from_id
  attr(df, "to_id") <- to_id
  class(df) <- c("ntl_crosswalk", "data.frame")
  df
}

# Intersection pieces of the two vintages in an equal-area projection.
.xw_pieces <- function(from, to, from_id, to_id) {
  ea <- sf::st_crs("EPSG:6933")
  f <- sf::st_transform(sf::st_make_valid(from[, from_id]), ea)
  t <- sf::st_transform(sf::st_make_valid(to[, to_id]), ea)
  names(f)[names(f) == from_id] <- "from_id"
  names(t)[names(t) == to_id] <- "to_id"
  sf::st_agr(f) <- "constant"
  sf::st_agr(t) <- "constant"
  pieces <- sf::st_intersection(f, t)
  pieces <- pieces[!sf::st_is_empty(pieces), , drop = FALSE]
  pieces <- suppressWarnings(sf::st_collection_extract(pieces, "POLYGON"))
  if (nrow(pieces) == 0) .stop("The two vintages do not overlap.")
  pieces
}

.xw_raster_weights <- function(df, pieces, weight_raster) {
  pr <- sf::st_transform(pieces, terra::crs(weight_raster))
  w <- exactextractr::exact_extract(weight_raster[[1]], pr, "sum",
                                    progress = FALSE)
  keys <- list(from_id = pieces$from_id, to_id = pieces$to_id)
  wdf <- stats::aggregate(list(w = w), keys, sum, na.rm = TRUE)
  df <- merge(df, wdf, by = c("from_id", "to_id"), all.x = TRUE)
  tot <- stats::ave(df$w, df$from_id, FUN = function(z) sum(z, na.rm = TRUE))
  use <- !is.na(tot) & tot > 0
  df$weight[use] <- df$w[use]
  df$weight[is.na(df$weight)] <- 0
  df$weight_source[use] <- "raster"
  df$w <- NULL
  df
}

.xw_relation <- function(df) {
  n_to <- stats::ave(seq_along(df$from_id), df$from_id, FUN = length)
  n_from <- stats::ave(seq_along(df$to_id), df$to_id, FUN = length)
  out <- rep("split-merge", nrow(df))
  out[n_to == 1 & n_from > 1] <- "merge"
  out[n_to > 1 & n_from == 1] <- "split"
  out[n_to == 1 & n_from == 1] <- "unchanged"
  out
}

.xw_shares <- function(df) {
  sum_from <- stats::ave(df$weight, df$from_id, FUN = sum)
  sum_to <- stats::ave(df$weight, df$to_id, FUN = sum)
  area_from <- stats::ave(df$area_km2, df$from_id, FUN = sum)
  area_to <- stats::ave(df$area_km2, df$to_id, FUN = sum)
  df$w_from <- ifelse(sum_from > 0, df$weight / sum_from,
                      df$area_km2 / area_from)
  df$w_to <- ifelse(sum_to > 0, df$weight / sum_to, df$area_km2 / area_to)
  df
}

#' Apply a boundary crosswalk to tabular data
#'
#' Re-expresses variables measured on the `from` vintage on the `to`
#' vintage using an [ntl_crosswalk()].
#'
#' * Extensive variables (totals: output, population, sum of lights):
#'   `x_to = sum(x_from * w_from)`.
#' * Intensive variables (rates, means, shares):
#'   `x_to = sum(x_from * w_to) / sum(w_to)` over contributing units.
#'
#' By default a result is `NA` if any contributing unit is `NA`, because a
#' partial sum would understate the total.
#'
#' @param data A data frame keyed by the `from` identifier.
#' @param xw An `ntl_crosswalk`.
#' @param id_col Column of `data` holding `from` identifiers.
#' @param vars Variables to convert.
#' @param type `"extensive"` or `"intensive"`, recycled along `vars`.
#' @param by Additional grouping columns kept in the output, typically
#'   `"period"` or `"year"`.
#' @param na_rm Ignore missing contributors instead of returning `NA`.
#' @return A data frame keyed by the `to` identifier (named as in `xw`) and
#'   `by`.
#' @examples
#' ex <- ntl_example()
#' xw <- ntl_crosswalk(ex$units_old, ex$units_new, "district", "district_new")
#' stats <- data.frame(district = ex$units_old$district, year = 2022,
#'                     employment = c(120, 80, 60, 150, 90, 40),
#'                     unemployment_rate = c(5, 7, 6, 4, 8, 9))
#' ntl_apply_crosswalk(stats, xw, "district",
#'                     vars = c("employment", "unemployment_rate"),
#'                     type = c("extensive", "intensive"), by = "year")
#' @export
ntl_apply_crosswalk <- function(data, xw, id_col, vars,
                                type = c("extensive", "intensive"),
                                by = NULL, na_rm = FALSE) {
  if (!inherits(xw, "ntl_crosswalk")) {
    .stop("`xw` must come from ntl_crosswalk().")
  }
  data <- .drop_geometry(data)
  .check_cols(data, c(id_col, vars, by), "data")
  if (missing(type)) type <- "extensive"
  type <- vapply(type, match.arg, "", choices = c("extensive", "intensive"))
  type <- rep_len(unname(type), length(vars))
  unmatched <- setdiff(unique(data[[id_col]]), xw$from_id)
  if (length(unmatched) > 0) {
    .warn(length(unmatched), " identifier(s) in `data` are not in the ",
          "crosswalk and are ignored.")
  }
  x <- xw
  class(x) <- "data.frame"
  j <- merge(data[, c(id_col, by, vars), drop = FALSE],
             x[, c("from_id", "to_id", "w_from", "w_to")],
             by.x = id_col, by.y = "from_id")
  key_df <- j[, c("to_id", by), drop = FALSE]
  key <- do.call(paste, c(key_df, sep = "\r"))
  first <- !duplicated(key)
  out <- key_df[first, , drop = FALSE]
  for (k in seq_along(vars)) {
    res <- .xw_aggregate(j[[vars[k]]], j, key, key[first], type[k])
    if (!isTRUE(na_rm)) res[res$n_na > 0, "value"] <- NA
    out[[vars[k]]] <- res$value
  }
  names(out)[1] <- attr(xw, "to_id") %||% "to_id"
  rownames(out) <- NULL
  out
}

.xw_aggregate <- function(v, j, key, ukey, type) {
  isna <- is.na(v)
  group_sum <- function(z) unname(rowsum(z, key, reorder = FALSE)[ukey, 1])
  n_na <- group_sum(as.integer(isna))
  if (type == "extensive") {
    value <- group_sum(ifelse(isna, 0, v * j$w_from))
  } else {
    num <- group_sum(ifelse(isna, 0, v * j$w_to))
    den <- group_sum(ifelse(isna, 0, j$w_to))
    value <- ifelse(den > 0, num / den, NA_real_)
  }
  data.frame(value = value, n_na = n_na)
}
