test_that("distance rings and first treatment dates are assigned", {
  units <- sf::st_sf(id = c("u1", "u2", "u3"),
                     geometry = sf::st_sfc(
                       sf::st_buffer(sf::st_point(c(70, 45.00)), 0.01),
                       sf::st_buffer(sf::st_point(c(70, 45.20)), 0.01),
                       sf::st_buffer(sf::st_point(c(70, 46.00)), 0.01),
                       crs = 4326))
  sites <- sf::st_sf(site = c("A", "B"), start = as.Date(c("2021-01-01", "2019-06-01")),
                     geometry = sf::st_sfc(sf::st_point(c(70, 45.0)),
                                           sf::st_point(c(70, 45.3)), crs = 4326))
  e <- ntl_exposure(units, sites, rings = c(10, 25, 50), id_col = "id",
                    site_id_col = "site", site_time_col = "start")
  expect_equal(e$nearest_site, c("A", "B", "B"))
  # 0.1 degree of latitude is about 11.1 km; 0.7 degree about 77.8 km
  expect_equal(e$dist_km, c(0, 11.1, 77.8), tolerance = 0.01)
  expect_equal(as.character(e$ring), c("0-10", "10-25", ">50"))
  expect_equal(e$within_10km, c(TRUE, FALSE, FALSE))
  expect_equal(e$n_sites_within, c(2, 2, 0))
  expect_equal(e$first_treat, as.Date(c("2019-06-01", "2019-06-01", NA)))
  expect_error(ntl_exposure(units, sites, rings = -1), "positive")
})

test_that("crosswalks capture splits and merges", {
  ex <- example_data()
  xw <- ntl_crosswalk(ex$units_old, ex$units_new, "district", "district_new")
  expect_s3_class(xw, "ntl_crosswalk")
  expect_equal(nrow(xw), 7)
  expect_equal(xw$relation[xw$from_id == "D1"], c("split", "split"))
  expect_equal(xw$relation[xw$to_id == "D56"], c("merge", "merge"))
  expect_equal(xw$w_from[xw$from_id == "D1"], c(0.5, 0.5), tolerance = 1e-6)
  sums_from <- tapply(xw$w_from, xw$from_id, sum)
  sums_to <- tapply(xw$w_to, xw$to_id, sum)
  expect_true(all(abs(sums_from - 1) < 1e-9))
  expect_true(all(abs(sums_to - 1) < 1e-9))
})

test_that("raster weights shift shares toward lit areas", {
  ex <- example_data()
  m <- ntl_files(ex$dir, "eog_vnl_monthly")
  lights <- ntl_read(m, period = "2022-01", series = "eog_vnl_monthly_npp")$value
  xw <- ntl_crosswalk(ex$units_old, ex$units_new, "district", "district_new",
                      weight_raster = lights)
  # The city in D1 sits at 67.5 E, i.e. in the eastern half D1b
  expect_gt(xw$w_from[xw$from_id == "D1" & xw$to_id == "D1b"], 0.8)
  expect_true(all(xw$weight_source == "raster"))
})

test_that("applying a crosswalk handles totals, rates and missing data", {
  ex <- example_data()
  xw <- ntl_crosswalk(ex$units_old, ex$units_new, "district", "district_new")
  d <- data.frame(district = rep(paste0("D", 1:6), 2), year = rep(2021:2022, each = 6),
                  jobs = c(120, 80, 60, 150, 90, 40, 120, 80, 60, 150, NA, 40),
                  rate = c(5, 7, 6, 4, 8, 10, 5, 7, 6, 4, 8, 10))
  out <- ntl_apply_crosswalk(d, xw, "district", vars = c("jobs", "rate"),
                             type = c("extensive", "intensive"), by = "year")
  expect_equal(names(out), c("district_new", "year", "jobs", "rate"))
  r21 <- out[out$year == 2021, ]
  expect_equal(r21$jobs[r21$district_new == "D56"], 130)
  expect_equal(r21$jobs[r21$district_new == "D1a"], 60)
  expect_equal(r21$rate[r21$district_new == "D56"], 9)
  expect_equal(sum(r21$jobs), sum(d$jobs[d$year == 2021]))
  r22 <- out[out$year == 2022, ]
  expect_true(is.na(r22$jobs[r22$district_new == "D56"]))
  out2 <- ntl_apply_crosswalk(d, xw, "district", vars = "jobs", by = "year", na_rm = TRUE)
  expect_equal(out2$jobs[out2$year == 2022 & out2$district_new == "D56"], 40)
  bad <- rbind(d, data.frame(district = "D9", year = 2021, jobs = 1, rate = 1))
  expect_warning(ntl_apply_crosswalk(bad, xw, "district", vars = "jobs"), "not in the crosswalk")
})
