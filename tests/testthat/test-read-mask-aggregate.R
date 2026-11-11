test_that("Black Marble tiles are read, georeferenced and cleaned", {
  dir <- withr::local_tempdir()
  f <- make_bm_h5(dir)
  r <- ntl_read_bm(f)
  expect_equal(names(r), c("value", "nobs", "quality"))
  expect_equal(as.vector(terra::ext(r)),
               c(xmin = 70, xmax = 80, ymin = 40, ymax = 50))
  expect_true(terra::same.crs(r, "EPSG:4326"))
  v <- terra::as.matrix(r$value, wide = TRUE)
  expected <- fixture_grid()
  expected[expected == 65535] <- NA
  expect_equal(unname(v), unname(expected * 1.0))
  q <- terra::as.matrix(r$quality, wide = TRUE)
  expect_true(all(is.na(q[4, ])))
  expect_error(ntl_read_bm(f, variable = "Nope"), "not found")
})

test_that("south-up tiles are flipped automatically, and flips can be forced", {
  dir <- withr::local_tempdir()
  up <- make_bm_h5(dir, south_up = TRUE)
  r <- ntl_read_bm(up)
  v <- terra::as.matrix(r$value, wide = TRUE)
  expect_equal(v[1, 1], 1)
  expect_equal(v[4, 4], 19)
  dir2 <- withr::local_tempdir()
  normal <- make_bm_h5(dir2)
  forced <- ntl_read_bm(normal, flip = TRUE)$value
  forced <- terra::as.matrix(forced, wide = TRUE)
  expect_equal(forced[1, 1], 16)
})

test_that("ntl_read mosaics tiles and extends to the area of interest", {
  dir <- withr::local_tempdir()
  make_bm_h5(dir, tile = "h25v04")
  make_bm_h5(dir, tile = "h26v04")
  m <- ntl_files(dir, "VNP46A3")
  expect_equal(nrow(m), 2)
  r <- ntl_read(m, aoi = c(72, 42, 88, 52))
  e <- as.vector(terra::ext(r))
  expect_lte(e[["xmin"]], 72)
  expect_gte(e[["xmax"]], 88)
  expect_gte(e[["ymax"]], 52) # beyond the tiles: filled with NA
  expect_true(anyNA(terra::values(r$value)))
})

test_that("masking rules are applied and recorded", {
  dir <- withr::local_tempdir()
  r <- ntl_read_bm(make_bm_h5(dir))
  # quality: rows cycle 0,1,2,NA by row; nobs: 5,2,0,9 by row
  m0 <- ntl_mask(r, quality_max = NULL)
  v0 <- terra::as.matrix(m0$value, wide = TRUE)
  expect_true(all(is.na(v0[3, ]))) # nobs == 0 => unobserved
  expect_true(all(terra::as.matrix(m0$masked, wide = TRUE)[1:2, ] == 0))
  m1 <- ntl_mask(r, quality_max = 1, min_obs = 3)
  v1 <- terra::as.matrix(m1$value, wide = TRUE)
  k1 <- terra::as.matrix(m1$masked, wide = TRUE)
  expect_false(anyNA(v1[1, ]))
  expect_true(all(is.na(v1[2, ]))) # nobs 2 < 3
  expect_true(all(k1[2, ] == 1))
  expect_true(all(is.na(k1[3, ]))) # unobserved, not masked
  m2 <- ntl_mask(r, quality_max = NULL, cap = 3)
  expect_lte(max(terra::values(m2$value), na.rm = TRUE), 3)
})

test_that("gas-flare polygons are masked", {
  r <- toy_raster()
  flare <- sf::st_buffer(sf::st_point(c(0.25, 1.75)), 0.1)
  flare <- sf::st_sfc(flare, crs = 4326)
  m <- ntl_mask(r, flares = flare)
  expect_true(is.na(terra::values(m$value)[1]))
  expect_equal(terra::values(m$masked)[1], 1)
  expect_equal(terra::values(m$value)[2], 2)
})

test_that("zonal statistics distinguish dark from unobserved", {
  r <- toy_raster()
  a <- ntl_aggregate(r, toy_units(), id_col = "id")
  expect_equal(a$id, c("west", "east"))
  # west: cols 1-2 -> 1,2,5,6,NA,NA,1,1 ; east: 3,4,7,8,0,0,0,0
  expect_equal(a$ntl_sum, c(16, 22))
  expect_equal(a$share_valid, c(6 / 8, 1))
  expect_equal(a$ntl_mean, c(16 / 6, 22 / 8))
  expect_equal(a$ntl_sum_adj, c(16 * 8 / 6, 22))
  dark <- r
  terra::values(dark) <- 0
  expect_equal(ntl_aggregate(dark, toy_units())$ntl_sum, c(0, 0))
  none <- r
  terra::values(none) <- NA
  b <- ntl_aggregate(none, toy_units())
  expect_true(all(is.na(b$ntl_sum)))
  expect_equal(b$share_valid, c(0, 0))
  expect_equal(names(b)[1], "unit_id")
})

test_that("extraction runs over all periods with coverage diagnostics", {
  ex <- example_data()
  m <- ntl_files(ex$dir, "eog_vnl_monthly")
  long <- ntl_extract(m, ex$units_old, id_col = "district", quiet = TRUE)
  expect_s3_class(long, "ntl_long")
  expect_equal(nrow(long), 6 * 54)
  jun <- long[long$period == as.Date("2022-06-01") &
                long$series == "eog_vnl_monthly_npp", ]
  north <- jun$district %in% c("D1", "D2", "D3")
  expect_true(all(jun$share_valid[north] == 0))
  expect_true(all(is.na(jun$ntl_sum[north])))
  expect_true(all(jun$share_valid[!north] == 1))
  expect_output(print(long), "ntl_long")
})

test_that("the shipped example tile reads correctly", {
  skip_if_not("HDF5" %in% terra::gdal(drivers = TRUE)$name)
  f <- system.file("extdata", "VNP46A3.A2023001.h25v04.002.2023040000000.h5",
                   package = "ntlpanel")
  r <- ntl_read_bm(f)
  expect_equal(dim(r), c(40, 40, 3))
  xy <- terra::xyFromCell(r, which.max(terra::values(r$value)))
  expect_equal(unname(xy[1, ]), c(76.875, 43.375)) # Almaty
  expect_true(is.na(terra::values(r$value)[1600]))
})
