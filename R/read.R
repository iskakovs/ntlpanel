#' Read a Black Marble HDF5 tile
#'
#' Reads the value, observation-count and quality layers of a Black Marble
#' monthly or annual tile (`VNP46A3`, `VNP46A4`, `VJ146A3`, `VJ146A4`) and
#' georeferences it from the tile id in the file name.
#'
#' Tiles are read directly with the hdf5r package rather than through GDAL,
#' because GDAL versions disagree about the row order of these grids (some
#' return them upside down; see blackmarbler issue #17). The fill value
#' (the dataset's `_FillValue` attribute, otherwise 65535 for radiance and
#' counts and 255 for quality) becomes `NA`, and `scale_factor` and
#' `add_offset` attributes are applied when present.
#'
#' **Orientation.** Rows are taken to run from north to south, as in the
#' Black Marble product specification. If the file contains a `lat` dataset
#' that increases with row number, the grid is flipped. Use `flip = TRUE` or
#' `FALSE` to override, and check one tile against a known city before a
#' large run (the validation script in `inst/scripts` does this).
#'
#' @param file Path to an `.h5` file.
#' @param variable Value layer. Defaults to the product's `value_layer`
#'   (`NearNadir_Composite_Snow_Free`). Count and quality layers are
#'   `<variable>_Num` and `<variable>_Quality`.
#' @param layers Which layers to return, renamed to `value`, `nobs` and
#'   `quality`.
#' @param flip `NA` (automatic), `TRUE` (flip the stored grid vertically) or
#'   `FALSE` (use the stored row order as is).
#' @return A `SpatRaster` in EPSG:4326.
#' @examples
#' # A small synthetic tile shipped with the package (real tiles are
#' # 2400 x 2400 pixels)
#' f <- system.file("extdata", "VNP46A3.A2023001.h25v04.002.2023040000000.h5",
#'   package = "ntlpanel"
#' )
#' r <- ntl_read_bm(f)
#' r
#' terra::plot(log1p(r$value))
#' @export
ntl_read_bm <- function(file, variable = NULL,
                        layers = c("value", "nobs", "quality"), flip = NA) {
  p <- .parse_bm_name(file)
  if (!p$ok) .stop("Not a Black Marble file name: ", basename(file))
  layers <- match.arg(layers, several.ok = TRUE)
  default_var <- "NearNadir_Composite_Snow_Free"
  if (p$product %in% .registry()$id) {
    default_var <- .source_info(p$product)$value_layer
  }
  variable <- variable %||% default_var
  wanted <- c(value = variable, nobs = paste0(variable, "_Num"),
              quality = paste0(variable, "_Quality"))[layers]
  fill <- c(value = 65535, nobs = 65535, quality = 255)

  h <- hdf5r::H5File$new(file, mode = "r")
  on.exit(h$close_all(), add = TRUE)
  paths <- .h5_datasets(h)
  if (!variable %in% names(paths)) {
    .stop("Layer '", variable, "' not found in ", basename(file),
          ". Available layers: ", paste(names(paths), collapse = ", "))
  }
  wanted <- wanted[wanted %in% names(paths)]
  grids <- lapply(names(wanted), function(ly) {
    .h5_grid(h[[paths[[wanted[[ly]]]]]], fill[[ly]])
  })
  names(grids) <- names(wanted)
  if (is.na(flip)) flip <- .h5_south_up(h, paths)

  tile_ext <- .bm_tile_extent(p$tile)
  r <- terra::rast(
    nrows = grids[[1]]$nrow, ncols = grids[[1]]$ncol, nlyrs = length(grids),
    xmin = tile_ext$xmin, xmax = tile_ext$xmax,
    ymin = tile_ext$ymin, ymax = tile_ext$ymax, crs = "EPSG:4326"
  )
  terra::values(r) <- do.call(cbind, lapply(grids, `[[`, "values"))
  names(r) <- names(grids)
  if (isTRUE(flip)) r <- terra::flip(r, direction = "vertical")
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
    target <- .floor_period(.parse_period(period), freq)
    m <- m[m$period == target, , drop = FALSE]
  }
  if (nrow(m) == 0) {
    .stop("No files left in the manifest for this series/period.")
  }
  if (length(unique(m$series)) != 1 || length(unique(m$period)) != 1) {
    .stop("ntl_read() reads one series and one period at a time. ",
          "Pass `series` ",
          "and `period`, or use ntl_extract() for many periods.")
  }
  ext <- if (is.null(aoi)) NULL else .aoi_extent(aoi)
  r <- .read_group(m, ext, variable, flip)
  if (is.null(r)) .stop("The files do not overlap the area of interest.")
  r
}

# Internals --------------------------------------------------------------------

# Named vector: dataset basename -> full path, for all datasets in a file.
.h5_datasets <- function(h) {
  info <- h$ls(recursive = TRUE)
  ds <- info$name[info$obj_type == "H5I_DATASET"]
  stats::setNames(ds, basename(ds))
}

# Read one 2-D dataset into a row-major value vector (north-west first as
# stored), applying fill value, scale and offset.
.h5_grid <- function(ds, default_fill) {
  x <- ds$read()
  if (length(dim(x)) != 2) {
    .stop("Dataset '", ds$get_obj_name(), "' is not a 2-D grid.")
  }
  attr_num <- function(name) {
    if (!name %in% ds$attr_names) return(NA_real_)
    as.numeric(hdf5r::h5attr(ds, name))[1]
  }
  fill <- attr_num("_FillValue")
  if (is.na(fill)) fill <- default_fill
  scale <- attr_num("scale_factor")
  offset <- attr_num("add_offset")
  # hdf5r returns HDF5 (row-major) arrays with their dimensions reversed, so
  # as.vector() walks the grid row by row, which is terra's cell order.
  v <- as.vector(x)
  v[v == fill] <- NA
  if (!is.na(scale)) v <- v * scale
  if (!is.na(offset)) v <- v + offset
  list(values = as.numeric(v), nrow = dim(x)[2], ncol = dim(x)[1])
}

# TRUE if the file's 1-D 'lat' dataset increases with row number.
.h5_south_up <- function(h, paths) {
  hit <- paths[tolower(names(paths)) == "lat"]
  if (length(hit) == 0) return(FALSE)
  lat <- tryCatch(h[[hit[[1]]]]$read(), error = function(e) NULL)
  if (is.null(lat) || length(lat) < 2 || !is.null(dim(lat))) return(FALSE)
  lat[length(lat)] > lat[1]
}

.aoi_extent <- function(aoi, pad = 1 / 240) {
  a <- .to_lonlat(.as_sf(aoi, "aoi"))
  bb <- sf::st_bbox(a)
  terra::ext(bb[["xmin"]] - pad, bb[["xmax"]] + pad,
             bb[["ymin"]] - pad, bb[["ymax"]] + pad)
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
    if (!terra::compareGeom(v, n, stopOnError = FALSE)) {
      n <- terra::resample(n, v, method = "near")
    }
    v <- c(v, n)
  }
  if (is.na(terra::crs(v)) || !nzchar(terra::crs(v))) {
    terra::crs(v) <- "EPSG:4326"
  }
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
  r <- pieces[[1]]
  if (length(pieces) > 1) r <- terra::merge(terra::sprc(pieces))
  if (!is.null(ext)) r <- terra::extend(r, ext, snap = "out")
  r
}
