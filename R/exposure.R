#' Distance-ring treatment exposure
#'
#' Assigns each unit its distance to the nearest treatment site, a ring
#' (e.g. 0-10, 10-25, 25-50, >50 km), the number of sites within the
#' largest ring and, if sites are dated, the first treatment date among
#' sites within the largest ring. That date can serve as the cohort
#' variable of staggered difference-in-differences estimators.
#'
#' Distances are great-circle distances (sf with s2) in kilometres.
#' Network distances are not computed here; use dodgr or sfnetworks for
#' those.
#'
#' @param units Unit polygons (`sf` or `SpatVector`).
#' @param sites Treatment sites: points, lines or polygons (e.g. earthquake
#'   epicentres, Belt and Road projects, new plants).
#' @param rings Ring boundaries in kilometres, increasing.
#' @param id_col Unit identifier column.
#' @param site_id_col Optional site identifier column, reported for the
#'   nearest site.
#' @param site_time_col Optional column of site dates (or periods); the
#'   earliest one within `max(rings)` km is returned as `first_treat`.
#' @param from Measure distance from the unit's `"centroid"` (a point on its
#'   surface) or from its `"boundary"` (0 if the site is inside the unit).
#' @return A data frame with the id column, `nearest_site`, `dist_km`,
#'   `ring`, one logical `within_<r>km` column per ring, `n_sites_within`
#'   and, if `site_time_col` is given, `first_treat`.
#' @examples
#' ex <- ntl_example()
#' ntl_exposure(ex$units_old, ex$sites, rings = c(50, 100, 200),
#'              id_col = "district", site_id_col = "site",
#'              site_time_col = "start")
#' @export
ntl_exposure <- function(units, sites, rings = c(10, 25, 50), id_col = NULL,
                         site_id_col = NULL, site_time_col = NULL,
                         from = c("centroid", "boundary")) {
  from <- match.arg(from)
  rings <- sort(unique(as.numeric(rings)))
  if (length(rings) == 0 || any(rings <= 0)) {
    .stop("`rings` must be positive distances in km.")
  }
  units <- .to_lonlat(.as_sf(units, "units"))
  sites <- .to_lonlat(.as_sf(sites, "sites"))
  if (nrow(sites) == 0) .stop("`sites` is empty.")
  ids <- .unit_ids(units, id_col)
  if (!is.null(site_id_col)) .check_cols(sites, site_id_col, "sites")
  if (!is.null(site_time_col)) .check_cols(sites, site_time_col, "sites")

  geom <- sf::st_geometry(units)
  if (from == "centroid") {
    geom <- suppressWarnings(sf::st_point_on_surface(geom))
  }
  sgeom <- sf::st_geometry(sites)
  nearest <- sf::st_nearest_feature(geom, sgeom)
  dist_m <- sf::st_distance(geom, sgeom[nearest], by_element = TRUE)
  dist_km <- as.numeric(dist_m) / 1000

  labels <- c(paste0(c(0, utils::head(rings, -1)), "-", rings),
              paste0(">", max(rings)))
  ring <- cut(dist_km, breaks = c(-Inf, rings, Inf), labels = labels,
              right = TRUE)

  within <- sf::st_is_within_distance(geom, sgeom, dist = max(rings) * 1000)
  out <- data.frame(id = ids, stringsAsFactors = FALSE)
  names(out) <- id_col %||% "unit_id"
  out$nearest_site <- nearest
  if (!is.null(site_id_col)) out$nearest_site <- sites[[site_id_col]][nearest]
  out$dist_km <- dist_km
  out$ring <- ring
  for (r in rings) out[[paste0("within_", r, "km")]] <- dist_km <= r
  out$n_sites_within <- lengths(within)
  if (!is.null(site_time_col)) {
    times <- sites[[site_time_col]]
    first <- lapply(within, function(j) if (length(j)) min(times[j]) else NA)
    out$first_treat <- do.call(c, first)
    if (inherits(times, "Date")) out$first_treat <- as.Date(out$first_treat)
  }
  out
}
