laads <- "https://ladsweb.modaps.eosdis.nasa.gov/archive/allData/5200"
listing_header <- paste0(
  "name,last_modified,size,mtime,cksum,md5sum,resourceType,downloadsLink"
)

test_that("Black Marble file names are parsed", {
  p <- ntlpanel:::.parse_bm_name(c(
    "VNP46A3.A2023032.h25v04.002.2023070123456.h5",
    "VJ146A4.A2022001.h22v03.002.2023101000000.h5",
    "not_a_file.h5"
  ))
  expect_equal(p$ok, c(TRUE, TRUE, FALSE))
  expect_equal(p$product[1:2], c("VNP46A3", "VJ146A4"))
  expect_equal(p$tile[1:2], c("h25v04", "h22v03"))
  expect_equal(p$period[1:2], as.Date(c("2023-02-01", "2022-01-01")))
})

test_that("LAADS URLs follow the archive layout", {
  u <- ntlpanel:::.laads_url("VJ146A3", as.Date("2024-03-01"))
  expect_equal(u, paste0(laads, "/VJ146A3/2024/061.csv"))
  f <- ntlpanel:::.laads_url("VNP46A4", as.Date("2020-01-01"), "x.h5")
  expect_equal(f, paste0(laads, "/VNP46A4/2020/001/x.h5"))
})

test_that("LAADS listings are read, and missing links are rebuilt", {
  csv <- withr::local_tempfile(fileext = ".csv")
  writeLines(c(
    listing_header,
    paste0("VJ146A3.A2024001.h25v03.002.2025148133447.h5,",
           "2025-05-28 13:35,101139159,1,null,null,File,")
  ), csv)
  l <- ntlpanel:::.read_listing(csv, "VJ146A3", as.Date("2024-01-01"))
  expect_equal(l$size, 101139159)
  expect_match(l$url, "5200/VJ146A3/2024/001/VJ146A3.A2024001.h25v03")
})

test_that("cached valid files are not downloaded again", {
  dir <- withr::local_tempdir()
  f <- make_bm_h5(dir)
  st <- ntlpanel:::.download_one("https://invalid.example/x.h5", f,
                                 token = "", expected_size = file.size(f))
  expect_equal(st, "cached")
})

test_that("ntl_fetch refuses products it cannot download", {
  expect_error(
    ntl_fetch("eog_vnl_monthly", aoi = c(0, 0, 1, 1), start = 2020,
              end = 2020, token = "x"),
    "ntl_files"
  )
})

test_that("local EOG files are indexed with coverage companions", {
  ex <- example_data()
  m <- ntl_files(ex$dir, "eog_vnl_monthly")
  expect_s3_class(m, "ntl_manifest")
  expect_equal(nrow(m), 54)
  expect_setequal(unique(m$series),
                  c("eog_vnl_monthly_npp", "eog_vnl_monthly_j01"))
  expect_true(all(!is.na(m$nobs_file)))
  j01 <- m$series == "eog_vnl_monthly_j01"
  expect_equal(unique(m$platform[j01]), "NOAA-20")
  expect_equal(min(m$period), as.Date("2021-01-01"))
  expect_output(print(m), "54 file")
})

test_that("annual EOG and harmonized names are parsed", {
  dir <- withr::local_tempdir()
  r <- terra::rast(nrows = 2, ncols = 2, vals = 1:4)
  f1 <- file.path(dir, paste0("VNL_v22_npp-j01_2022_global_vcmslcfg_",
                              "c202303062300.average_masked.dat.tif"))
  f2 <- file.path(dir, paste0("VNL_npp_2023_global_vcmslcfg_v2_",
                              "c202402081600.average_masked.dat.tif"))
  f3 <- file.path(dir, "Harmonized_DN_NTL_2018_simVIIRS.tif")
  for (f in c(f1, f2, f3)) terra::writeRaster(r, f)
  a <- ntl_files(c(f1, f2), "eog_vnl_annual")
  expect_setequal(format(a$period, "%Y"), c("2022", "2023"))
  expect_setequal(a$series,
                  c("eog_vnl_annual_npp-j01", "eog_vnl_annual_npp"))
  h <- ntl_files(dir, "dmsp_viirs_li")
  expect_equal(h$period, as.Date("2018-01-01"))
  expect_error(
    ntl_files(f3, "viirs_like_chen", period = c("2001", "2002")),
    "one value per file"
  )
})

test_that("network access to LAADS works when a token is available", {
  skip_on_cran()
  skip_if_offline("ladsweb.modaps.eosdis.nasa.gov")
  skip_if(!nzchar(Sys.getenv("EARTHDATA_TOKEN")), "No EARTHDATA_TOKEN set")
  withr::local_options(ntlpanel.cache_dir = withr::local_tempdir())
  a <- ntl_available("VJ146A4", 2023, tiles = "h25v03")
  expect_equal(a$n_tiles, 1)
})

test_that("ntl_fetch downloads, verifies and records tiles (mocked)", {
  src <- withr::local_tempdir()
  fixture <- make_bm_h5(src, product = "VNP46A3", date = "2023001",
                        tile = "h25v04")
  listing <- paste0(
    listing_header, "\n",
    "VNP46A3.A2023001.h00v00.002.2023040000000.h5,",
    "2023-02-09 00:00,10,1,null,null,File,\n",
    basename(fixture), ",2023-02-09 00:00,", file.size(fixture),
    ",1,null,null,File,\n"
  )
  calls <- character()
  mock <- function(req) {
    calls <<- c(calls, req$url)
    if (grepl("\\.csv$", req$url)) {
      return(httr2::response(200, url = req$url, body = charToRaw(listing)))
    }
    httr2::response(200, url = req$url,
                    body = readBin(fixture, "raw", file.size(fixture)))
  }
  cache <- withr::local_tempdir()
  m <- httr2::with_mocked_responses(mock, ntl_fetch(
    "VNP46A3", tiles = c("h25v04", "h26v04"), start = "2023-01",
    end = "2023-01", token = "fake-token", cache_dir = cache, quiet = TRUE
  ))
  expect_s3_class(m, "ntl_manifest")
  expect_equal(m$status, c("downloaded", "missing"))
  expect_equal(m$tile, c("h25v04", "h26v04"))
  expect_true(file.exists(m$file[1]))
  expect_equal(unname(m$md5[1]), unname(tools::md5sum(fixture)))
  expect_true(file.exists(attr(m, "manifest_file")))
  # the h00v00 tile was not requested
  expect_equal(sum(grepl("\\.h5$", calls)), 1)
  r <- ntl_read(m)
  expect_equal(as.vector(terra::ext(r)),
               c(xmin = 70, xmax = 80, ymin = 40, ymax = 50))
  # A second call uses the cache and the stored listing: no new requests
  n_before <- length(calls)
  m2 <- httr2::with_mocked_responses(mock, ntl_fetch(
    "VNP46A3", tiles = "h25v04", start = "2023-01", end = "2023-01",
    token = "fake-token", cache_dir = cache, quiet = TRUE
  ))
  expect_equal(m2$status, "cached")
  expect_equal(length(calls), n_before)
  expect_equal(ntl_cache_clear(m2), 1)
})

test_that("an HTML login page instead of HDF5 gives a token error", {
  fname <- "VNP46A4.A2022001.h25v04.002.2023040000000.h5"
  listing <- paste0(listing_header, "\n", fname,
                    ",2023-02-09 00:00,,1,null,null,File,\n")
  mock <- function(req) {
    if (grepl("\\.csv$", req$url)) {
      return(httr2::response(200, url = req$url, body = charToRaw(listing)))
    }
    httr2::response(200, url = req$url,
                    body = charToRaw("<html>Earthdata Login</html>"))
  }
  expect_error(
    httr2::with_mocked_responses(mock, ntl_fetch(
      "VNP46A4", tiles = "h25v04", start = 2022, end = 2022,
      token = "expired", cache_dir = withr::local_tempdir(), quiet = TRUE
    )),
    "EARTHDATA_TOKEN"
  )
})
