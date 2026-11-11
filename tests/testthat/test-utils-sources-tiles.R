test_that("periods parse from several formats", {
  p <- ntlpanel:::.parse_period(c("2023", "2023-04", "2023-04-15"))
  expect_equal(p, as.Date(c("2023-01-01", "2023-04-01", "2023-04-15")))
  d <- as.Date("2020-02-02")
  expect_equal(ntlpanel:::.parse_period(d), d)
  expect_error(ntlpanel:::.parse_period("April 2023"), "Could not parse")
})

test_that("period sequences respect frequency", {
  s <- ntlpanel:::.period_seq("2022-11", "2023-02", "month")
  expect_equal(format(s, "%Y-%m"),
               c("2022-11", "2022-12", "2023-01", "2023-02"))
  y <- ntlpanel:::.period_seq("2019-06", "2021", "year")
  expect_equal(format(y, "%Y"), c("2019", "2020", "2021"))
  expect_error(ntlpanel:::.period_seq("2023", "2022", "year"), "before")
})

test_that("the registry is complete and consistent", {
  s <- ntl_sources()
  ids <- c("VNP46A3", "VNP46A4", "VJ146A3", "VJ146A4", "eog_vnl_monthly",
           "dmsp_viirs_li")
  expect_true(all(ids %in% s$id))
  expect_false(anyDuplicated(s$id) > 0)
  expect_true(all(s$frequency %in% c("month", "year")))
  expect_true(all(s$backend[s$family == "black_marble"] == "laads"))
  expect_error(ntl_sources("VNP99"), "Unknown product")
  expect_match("VJ146A3.A2024001.h25v03.002.2025148133447.h5",
               ntl_sources("VJ146A3")$file_pattern)
  eog <- paste0("SVDNB_npp_20230101-20230131_75N060E_vcmslcfg_v10_",
                "c202302080600.avg_rade9h.tif")
  expect_match(eog, ntl_sources("eog_vnl_monthly")$file_pattern)
  expect_match("Harmonized_DN_NTL_2020_simVIIRS.tif",
               ntl_sources("dmsp_viirs_li")$file_pattern)
})

test_that("tiles cover Kazakhstan's bounding box", {
  t <- ntl_tiles(c(46.4, 40.5, 87.4, 55.5))
  expect_equal(nrow(t), 10)
  expected <- c(sprintf("h%02dv03", 22:26), sprintf("h%02dv04", 22:26))
  expect_setequal(t$tile, expected)
  one <- ntl_tiles(c(71.4, 51.1, 71.5, 51.2)) # Astana
  expect_equal(one$tile, "h25v03")
  expect_equal(unlist(one[, c("xmin", "xmax", "ymin", "ymax")]),
               c(xmin = 70, xmax = 80, ymin = 50, ymax = 60))
})

test_that("tile refinement drops tiles outside the geometry", {
  # An L-shaped polygon whose bounding box touches four tiles but covers
  # three.
  l <- sf::st_sfc(sf::st_polygon(list(matrix(c(
    1, 1, 19, 1, 19, 9, 9, 9, 9, 19, 1, 19, 1, 1
  ), ncol = 2, byrow = TRUE))), crs = 4326)
  expect_equal(nrow(ntl_tiles(l, refine = FALSE)), 4)
  expect_equal(nrow(ntl_tiles(l, refine = TRUE)), 3)
})

test_that("the cache follows the option, else lives in tempdir()", {
  withr::local_options(ntlpanel.cache_dir = NULL)
  withr::local_envvar(NTLPANEL_CACHE = "")
  tmp <- normalizePath(tempdir(), winslash = "/")
  expect_true(startsWith(ntl_cache_dir(), tmp))
  d <- file.path(tempdir(), "ntl-cache-test")
  withr::local_options(ntlpanel.cache_dir = d)
  expect_equal(ntl_cache_dir(),
               normalizePath(d, winslash = "/", mustWork = FALSE))
  expect_true(dir.exists(d))
})

test_that("the cache can be inspected and emptied", {
  d <- withr::local_tempdir()
  writeLines("x", file.path(d, "a.txt"))
  dir.create(file.path(d, "sub"))
  writeLines("y", file.path(d, "sub", "b.txt"))
  info <- ntl_cache_info(d)
  expect_equal(info$n_files, 2)
  expect_error(ntl_cache_clear(cache_dir = d), "all = TRUE")
  expect_equal(ntl_cache_clear(all = TRUE, cache_dir = d), 2)
  expect_false(dir.exists(d))
  expect_equal(ntl_cache_info(d)$n_files, 0)
})

test_that("users hear once that downloads are temporary", {
  state <- ntlpanel:::.ntl_state
  state$noted <- NULL
  d <- file.path(tempdir(), "ntlpanel-cache")
  expect_message(ntlpanel:::.note_temporary_cache(d), "temporary folder")
  expect_silent(ntlpanel:::.note_temporary_cache(d))
  state$noted <- NULL
  expect_silent(ntlpanel:::.note_temporary_cache(withr::local_tempdir(),
                                                 quiet = TRUE))
})

test_that("missing token gives an actionable error", {
  withr::local_envvar(EARTHDATA_TOKEN = "")
  expect_error(ntl_token(), "EARTHDATA_TOKEN")
  expect_equal(ntl_token(required = FALSE), "")
})
