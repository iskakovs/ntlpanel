#' Read a Black Marble HDF5 tile
#'
#' Reads the value, observation-count and quality layers of a Black Marble
#' monthly or annual tile (`VNP46A3`, `VNP46A4`, `VJ146A3`, `VJ146A4`) and
#' georeferences it from the tile id in the file name.
#'
#' Fill values (65535 for radiance and counts, 255 for quality) become
#' `NA`. Values are returned as stored in Collection 2 (nW/cm2/sr); no extra
#' scale factor is applied.
#'
#' **Orientation.** Some GDAL builds return Black Marble grids bottom-up,
#' which makes tiles appear upside down (reported in blackmarbler issue
#' #17). `ntl_read_bm()` therefore (1) keeps GDAL's own georeferencing when
#' it matches the tile, (2) otherwise checks the file's `lat` dataset with
#' the hdf5r package, if installed, and flips the grid when latitude
#' increases with row number, and (3) otherwise assumes north-up rows. Use
#' `flip` to force the choice, and check one tile against a known city
#' before a large run.
#'
#' @param file Path to an `.h5` file.
#' @param variable Value layer. Defaults to the product's `value_layer`
#'   (`NearNadir_Composite_Snow_Free`). Count and quality layers are
#'   `<variable>_Num` and `<variable>_Quality`.
#' @param layers Which layers to return, renamed to `value`, `nobs` and
#'   `quality`.
#' @param flip `NA` (automatic), `TRUE` or `FALSE`.
#' @return A `SpatRaster` in EPSG:4326.
#' @examples
#' \dontrun{
#' r <- ntl_read_bm("VNP46A3.A2023001.h25v04.002.2023040123456.h5")
#' terra::plot(log1p(r$value))
#' }
#' @export
ntl_read_bm <- function(file, variable = NULL, layers = c("value", "nobs", "quality"),
                        flip = NA) {
  p <- .parse_bm_name(file)
  if (!p$ok) .stop("Not a Black Marble file name: ", basename(file))
  layers <- match.arg(layers, several.ok = TRUE)
  default_var <- if (p$product %in% .registry()$id) .source_info(p$product)$value_layer else
    "NearNadir_Composite_Snow_Free"
  variable <- variable %||% default_var
  wanted <- c(value = variable, nobs = paste0(variable, "_Num"),
              quality = paste0(variable, "_Quality"))[layers]

  r_all <- .quiet_extent(terra::rast(file))
  avail <- names(r_all)
  if (!variable %in% avail) {
    .stop("Layer '", variable, "' not found in ", basename(file),
          ". Available layers: ", paste(avail, collapse = ", "))
  }
  wanted <- wanted[wanted %in% avail]
  r <- r_all[[unname(wanted)]]
  names(r) <- names(wanted)

  tile_ext <- .bm_tile_extent(p$tile)
  expected <- terra::ext(tile_ext$xmin, tile_ext$xmax, tile_ext$ymin, tile_ext$ymax)
  georef_ok <- .extent_close(terra::ext(r), expected)
  if (!georef_ok) {
    if (is.na(flip)) flip <- .bm_rows_south_up(file)
    if (isTRUE(flip)) r <- terra::flip(r, direction = "vertical")
    terra::ext(r) <- expected
  } else if (isTRUE(flip)) {
    r <- terra::flip(r, direction = "vertical")
  }
  terra::crs(r) <- "EPSG:4326"

  if ("value" %in% names(r)) r[["value"]] <- terra::classify(r[["value"]], cbind(65535, NA))
  if ("nobs" %in% names(r)) r[["nobs"]] <- terra::classify(r[["nobs"]], cbind(65535, NA))
  if ("quality" %in% names(r)) r[["quality"]] <- terra::classify(r[["quality"]], cbind(255, NA))
  r
}

#' Read one period of a manifest as a raster
#'
#' Reads all files of one series and one period from a manifest, crops each
#' to the area of interest, mosaics them and extends the result to the full
#' area so that missing tiles show up as `NA` instead of silently shrinking
#' the coverage.
#'
#' @param manifest A manifest from [ntl_fetch()] or [ntl_files()].
#' @param period Period to read (`"YYYY-MM"`, `"YYYY"` or `Date`). May be
#'   omitted if the manifest holds a single period.
#' @param series Series to read. May be omitted if the manifest holds a
#'   single series.
#' @param aoi Optional area of interest (see [ntl_tiles()]).
#' @inheritParams ntl_read_bm
#' @return A `SpatRaster` with layers `value` and, where available, `nobs`
#'   and `quality`.
#' @examples
#' ex <- ntl_example()
#' m <- ntl_files(ex$dir, "eog_vnl_monthly")
#' r <- ntl_read(m, period = "2022-03", series = "eog_vnl_monthly_npp")
#' r
#' @export
ntl_read <- function(manifest, period = NULL, series = NULL, aoi = NULL,
                     variable = NULL, flip = NA) {
  .check_cols(manifest, c("series", "period", "file"), "manifest")
  m <- manifest[!is.na(manifest$file), , drop = FALSE]
  if (!is.null(series)) m <- m[m$series %in% series, , drop = FALSE]
  if (!is.null(period)) {
    freq <- unique(m$frequency)[1] %||% "month"
    m <- m[m$period == .floor_period(.parse_period(period), freq), , drop = FALSE]
  }
  if (nrow(m) == 0) .stop("No files left in the manifest for this series/period.")
  if (length(unique(m$series)) != 1 || length(unique(m$period)) != 1) {
    .stop("ntl_read() reads one series and one period at a time. Pass `series` ",
          "and `period`, or use ntl_extract() for many periods.")
  }
  ext <- if (is.null(aoi)) NULL else .aoi_extent(aoi)
  r <- .read_group(m, ext, variable, flip)
  if (is.null(r)) .stop("The files do not overlap the area of interest.")
  r
}

# Internals --------------------------------------------------------------------

.quiet_extent <- function(expr) {
  withCallingHandlers(expr, warning = function(w) {
    if (grepl("unknown extent", conditionMessage(w), fixed = TRUE)) {
      invokeRestart("muffleWarning")
    }
  })
}

.extent_close <- function(a, b, tol = 1e-3) {
  all(abs(as.vector(a) - as.vector(b)) < tol)
}

# TRUE if row 1 of the grid is the southern edge. Uses the 'lat' dataset when
# hdf5r is available; otherwise assumes north-up (FALSE).
.bm_rows_south_up <- function(file) {
  if (!requireNamespace("hdf5r", quietly = TRUE)) return(FALSE)
  lat <- tryCatch({
    h <- hdf5r::H5File$new(file, mode = "r")
    on.exit(h$close_all(), add = TRUE)
    nm <- h$ls(recursive = TRUE)$name
    hit <- nm[tolower(basename(nm)) == "lat"]
    if (length(hit) == 0) NULL else h[[hit[1]]][]
  }, error = function(e) NULL)
  if (is.null(lat) || length(lat) < 2 || !is.null(dim(lat))) return(FALSE)
  lat[length(lat)] > lat[1]
}

.aoi_extent <- function(aoi, pad = 1 / 240) {
  a <- .to_lonlat(.as_sf(aoi, "aoi"))
  bb <- sf::st_bbox(a)
  terra::ext(bb[["xmin"]] - pad, bb[["xmax"]] + pad, bb[["ymin"]] - pad, bb[["ymax"]] + pad)
}

.read_file <- function(row, variable, flip) {
  info <- .source_info(row$product)
  if (identical(info$family, "black_marble")) {
    return(ntl_read_bm(row$file, variable = variable, flip = flip))
  }
  v <- terra::rast(row$file)[[1]]
  names(v) <- "value"
  if (!is.na(row$nobs_file)) {
    n <- terra::rast(row$nobs_file)[[1]]
    names(n) <- "nobs"
    if (!terra::compareGeom(v, n, stopOnError = FALSE)) n <- terra::resample(n, v, method = "near")
    v <- c(v, n)
  }
  if (is.na(terra::crs(v)) || !nzchar(terra::crs(v))) terra::crs(v) <- "EPSG:4326"
  v
}

# Read, crop, mosaic and extend all files of one series-period group.
.read_group <- function(g, ext = NULL, variable = NULL, flip = NA) {
  pieces <- list()
  for (i in seq_len(nrow(g))) {
    r <- .read_file(g[i, , drop = FALSE], variable, flip)
    if (!is.null(ext)) {
      ov <- terra::intersect(terra::ext(r), ext)
      if (is.null(ov)) next
      r <- terra::crop(r, ext, snap = "out")
    }
    pieces[[length(pieces) + 1]] <- r
  }
  if (length(pieces) == 0) return(NULL)
  lyr <- Reduce(intersect, lapply(pieces, names))
  pieces <- lapply(pieces, function(p) p[[lyr]])
  r <- if (length(pieces) == 1) pieces[[1]] else terra::merge(terra::sprc(pieces))
  if (!is.null(ext)) r <- terra::extend(r, ext, snap = "out")
  r
}
