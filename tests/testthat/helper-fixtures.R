# Fixtures shared by tests -----------------------------------------------------

# A north-up 4 x 5 grid of known values.
fixture_grid <- function() matrix(c(1:19, 65535L), 4, 5, byrow = TRUE)

# Write a minimal Black Marble-like HDF5 file. `south_up = TRUE` stores rows
# bottom-up and writes an increasing `lat` dataset, as some files/GDAL builds
# present them.
make_bm_h5 <- function(dir, product = "VNP46A3", date = "2023001",
                       tile = "h25v04", south_up = FALSE, with_lat = TRUE,
                       quality = NULL, nobs = NULL) {
  testthat::skip_if_not_installed("hdf5r")
  name <- sprintf("%s.A%s.%s.002.2023040000000.h5", product, date, tile)
  f <- file.path(dir, name)
  if (file.exists(f)) file.remove(f)
  vals <- fixture_grid()
  qual <- quality %||% matrix(c(0L, 1L, 2L, 255L), 4, 5)
  cnt <- nobs %||% matrix(c(5L, 2L, 0L, 9L), 4, 5)
  lat <- seq(48.75, 41.25, length.out = 4)
  if (south_up) {
    vals <- vals[4:1, ]
    qual <- qual[4:1, ]
    cnt <- cnt[4:1, ]
    lat <- rev(lat)
  }
  h <- hdf5r::H5File$new(f, mode = "w")
  g <- h$create_group("HDFEOS")$create_group("GRIDS")$
    create_group("VIIRS_Grid_DNB_2d")$create_group("Data Fields")
  g[["NearNadir_Composite_Snow_Free"]] <- t(vals)
  g[["NearNadir_Composite_Snow_Free_Num"]] <- t(cnt)
  g[["NearNadir_Composite_Snow_Free_Quality"]] <- t(qual)
  if (with_lat) g[["lat"]] <- lat
  h$close_all()
  f
}

`%||%` <- function(x, y) if (is.null(x)) y else x

rect <- function(x0, x1, y0, y1) {
  sf::st_polygon(list(matrix(c(x0, y0, x1, y0, x1, y1, x0, y1, x0, y0),
                             ncol = 2, byrow = TRUE)))
}

# A tiny raster with known values over a 2 x 2 degree box, split into two
# units.
toy_raster <- function() {
  r <- terra::rast(xmin = 0, xmax = 2, ymin = 0, ymax = 2, resolution = 0.5,
                   crs = "EPSG:4326")
  terra::values(r) <- c(1, 2, 3, 4,
                        5, 6, 7, 8,
                        NA, NA, 0, 0,
                        1, 1, 0, 0)
  names(r) <- "value"
  r
}

toy_units <- function() {
  geom <- sf::st_sfc(rect(0, 1, 0, 2), rect(1, 2, 0, 2), crs = 4326)
  sf::st_sf(id = c("west", "east"), geometry = geom)
}

example_data <- function() {
  ntl_example(dir = file.path(tempdir(), "ntlpanel-test-example"))
}
