#' Black Marble tiles covering an area of interest
#'
#' Black Marble products are distributed on a fixed 10 x 10 degree
#' longitude/latitude grid with 36 horizontal (`h00`-`h35`) and 18 vertical
#' (`v00`-`v17`) tiles. Tile `hHHvVV` spans longitude
#' `-180 + 10 * HH` to `-170 + 10 * HH` and latitude `90 - 10 * VV` down to
#' `80 - 10 * VV`.
#'
#' @param aoi Area of interest: an `sf`/`sfc` object, a terra `SpatVector`,
#'   or a numeric bounding box `c(xmin, ymin, xmax, ymax)` in degrees.
#' @param refine If `TRUE` (default), keep only tiles that intersect the
#'   geometry itself, not just its bounding box.
#' @return A data frame with columns `tile`, `h`, `v`, `xmin`, `xmax`,
#'   `ymin` and `ymax`.
#' @examples
#' # Bounding box of Kazakhstan
#' ntl_tiles(c(46.4, 40.5, 87.4, 55.5))
#' @export
ntl_tiles <- function(aoi, refine = TRUE) {
  aoi <- .to_lonlat(.as_sf(aoi, "aoi"))
  bb <- sf::st_bbox(aoi)
  h_min <- max(0L, floor((bb[["xmin"]] + 180) / 10))
  h_max <- min(35L, ceiling((bb[["xmax"]] + 180) / 10) - 1L)
  v_min <- max(0L, floor((90 - bb[["ymax"]]) / 10))
  v_max <- min(17L, ceiling((90 - bb[["ymin"]]) / 10) - 1L)
  h_max <- max(h_max, h_min)
  v_max <- max(v_max, v_min)
  grid <- expand.grid(h = seq.int(h_min, h_max), v = seq.int(v_min, v_max))
  grid$tile <- sprintf("h%02dv%02d", grid$h, grid$v)
  ext <- .bm_tile_extent(grid$tile)
  out <- cbind(grid[, c("tile", "h", "v")], ext[, c("xmin", "xmax", "ymin", "ymax")])
  if (isTRUE(refine) && nrow(out) > 1) {
    polys <- lapply(seq_len(nrow(out)), function(i) {
      sf::st_polygon(list(matrix(c(
        out$xmin[i], out$ymin[i], out$xmax[i], out$ymin[i],
        out$xmax[i], out$ymax[i], out$xmin[i], out$ymax[i],
        out$xmin[i], out$ymin[i]
      ), ncol = 2, byrow = TRUE)))
    })
    tiles_sf <- sf::st_sfc(polys, crs = 4326)
    hit <- .without_s2(lengths(sf::st_intersects(
      tiles_sf, sf::st_union(sf::st_make_valid(sf::st_geometry(aoi)))
    )) > 0)
    out <- out[hit, , drop = FALSE]
  }
  out <- out[order(out$v, out$h), , drop = FALSE]
  rownames(out) <- NULL
  out
}

.bm_tile_extent <- function(tile) {
  ok <- grepl("^h[0-9]{2}v[0-9]{2}$", tile)
  if (!all(ok)) .stop("Invalid tile id(s): ", paste(tile[!ok], collapse = ", "))
  h <- as.integer(substr(tile, 2, 3))
  v <- as.integer(substr(tile, 5, 6))
  data.frame(
    tile = tile,
    xmin = -180 + 10 * h, xmax = -170 + 10 * h,
    ymin = 80 - 10 * v, ymax = 90 - 10 * v,
    stringsAsFactors = FALSE
  )
}
