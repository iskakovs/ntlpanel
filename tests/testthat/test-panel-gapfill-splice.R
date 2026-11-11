make_long <- function(ids = c("a", "b"), periods = seq(as.Date("2020-01-01"), by = "month",
                                                          length.out = 24),
                      series = "s1", f = function(i, t) 10 * i + t) {
  g <- expand.grid(unit_id = ids, period = periods, stringsAsFactors = FALSE)
  g$series <- series
  g$ntl_sum <- f(match(g$unit_id, ids), match(g$period, periods))
  g$share_valid <- 1
  ntlpanel:::.new_long(g, "unit_id", "month")
}

test_that("panels are balanced and transformed", {
  x <- make_long()
  x <- x[!(x$unit_id == "a" & x$period == as.Date("2020-05-01")), ]
  p <- ntl_panel(x)
  expect_s3_class(p, "ntl_panel")
  expect_equal(nrow(p), 48)
  gap <- p[p$unit_id == "a" & p$period == as.Date("2020-05-01"), ]
  expect_true(gap$ntl_missing)
  expect_equal(p$ntl[1], log1p(p$ntl_sum[1]))
  expect_equal(range(p$t), c(1, 24))
  expect_equal(attr(p, "frequency"), "month")
  expect_output(print(p), "ntl_panel")
})

test_that("low coverage is turned into explicit missingness", {
  x <- make_long()
  x$share_valid[1:3] <- 0.2
  p <- ntl_panel(x, min_share_valid = 0.5, transform = "asinh")
  expect_equal(sum(p$low_coverage), 3)
  expect_true(all(is.na(p$ntl_sum[p$low_coverage])))
  expect_equal(attr(p, "transform"), "asinh")
})

test_that("panels refuse mixed series and duplicates", {
  x <- rbind(make_long(series = "s1"), make_long(series = "s2"))
  expect_error(ntl_panel(x), "several series")
  y <- make_long()
  expect_error(ntl_panel(rbind(y, y[1, ])), "duplicated")
})

test_that("linear interpolation fills only short interior gaps", {
  f <- ntlpanel:::.interp_gaps
  expect_equal(f(c(1, NA, 3), 1), c(1, 2, 3))
  expect_equal(f(c(1, NA, NA, NA, 5), 2), c(1, NA, NA, NA, 5))
  expect_equal(f(c(NA, 2, 3), 2), c(NA, 2, 3))
  expect_equal(f(c(1, NA, NA, 4), 2), c(1, 2, 3, 4))
})

test_that("seasonal fill recovers a multiplicative series", {
  months <- rep(1:12, 3)
  years <- rep(2020:2022, each = 12)
  S <- 1 + 0.3 * cos(2 * pi * (1:12) / 12)
  S <- S / mean(S)
  L <- c(100, 110, 121)
  v <- S[months] * L[years - 2019]
  w <- v
  w[c(6, 19, 32)] <- NA # one June-ish gap per year, different months
  filled <- ntlpanel:::.seasonal_fill(w, years, months)
  expect_equal(filled, v, tolerance = 1e-8)
  never <- v
  never[months == 6] <- NA
  expect_true(all(is.na(ntlpanel:::.seasonal_fill(never, years, months)[months == 6])))
})

test_that("gap filling marks imputed values and flags stray-light risk", {
  ex <- example_data()
  m <- ntl_files(ex$dir, "eog_vnl_monthly")
  long <- ntl_extract(m[m$series == "eog_vnl_monthly_npp", ], ex$units_old,
                      id_col = "district", quiet = TRUE)
  sub <- long[long$period >= as.Date("2021-01-01"), ]
  expect_equal(attr(sub, "id_col"), "district") # subsetting keeps metadata
  p <- ntl_panel(sub, min_share_valid = 0.5)
  expect_equal(attr(p[p$year == 2021, ], "id_col"), "district")
  n_missing <- sum(p$ntl_missing)
  expect_equal(n_missing, 3 * 2 * 3) # 3 northern units x Jun-Jul x 3 years
  pi <- ntl_gapfill(p, rule = "interp", max_gap = 2, units = ex$units_old,
                    lat_threshold = 49)
  expect_equal(sum(pi$imputed), n_missing)
  expect_true(all(pi$impute_method[pi$imputed] == "interp"))
  expect_true(all(pi$stray_light_risk[pi$imputed]))
  expect_false(any(pi$stray_light_risk[pi$district %in% c("D4", "D5", "D6")]))
  pd <- ntl_gapfill(p, rule = "drop")
  expect_equal(nrow(pd), nrow(p) - n_missing)
  ps <- ntl_gapfill(p, rule = "seasonal")
  expect_equal(sum(ps$imputed), 0) # Jun/Jul never observed in the north
  rep <- attr(pi, "gap_report")
  expect_equal(rep$missing_before[rep$month == 6], 9)
  expect_equal(rep$missing_after[rep$month == 6], 0)
})

test_that("ratio splicing recovers a known level shift", {
  per <- seq(as.Date("2020-01-01"), by = "month", length.out = 24)
  a <- make_long(periods = per, series = "old")
  b <- make_long(periods = per[13:24], series = "new", f = function(i, t) 1.1 * (10 * i + t + 12))
  sp <- ntl_splice(rbind(a, b), from = "old", to = "new")
  d <- ntl_splice_report(sp)
  expect_equal(d$b, c(1.1, 1.1), tolerance = 1e-10)
  expect_equal(d$level_shift_pct, c(10, 10), tolerance = 1e-8)
  expect_false(any(d$fallback))
  expect_equal(nrow(sp), 48)
  early <- sp[sp$period < per[13], ]
  expect_true(all(early$origin == "old (adjusted)"))
  expect_equal(early$ntl_sum[early$unit_id == "a"], 1.1 * (10 + 1:12))
  expect_equal(unique(sp$series), "old+new")
  # The spliced series is continuous at the switch
  pa <- sp[sp$unit_id == "a", ]
  expect_equal(diff(pa$ntl_sum), rep(1.1, 23), tolerance = 1e-10)
})

test_that("regression splicing, switch dates and fallbacks work", {
  per <- seq(as.Date("2020-01-01"), by = "month", length.out = 12)
  a <- make_long(periods = per, series = "old")
  b <- make_long(periods = per, series = "new", f = function(i, t) 2 + 0.5 * (10 * i + t))
  sp <- ntl_splice(rbind(a, b), from = "old", to = "new", method = "regression",
                   switch_at = "2020-07")
  d <- ntl_splice_report(sp)
  expect_equal(d$a, c(2, 2), tolerance = 1e-8)
  expect_equal(d$b, c(0.5, 0.5), tolerance = 1e-8)
  expect_equal(sum(sp$origin == "new"), 12)
  few <- ntl_splice(rbind(a, b), from = "old", to = "new", overlap = c("2020-01", "2020-02"))
  expect_true(all(ntl_splice_report(few)$fallback))
  expect_error(ntl_splice(a, from = "old", to = "nope"), "not found")
})

test_that("gap filling after the switch uses the adjusted old series", {
  per <- seq(as.Date("2020-01-01"), by = "month", length.out = 12)
  a <- make_long(periods = per, series = "old")
  b <- make_long(periods = per[7:12], series = "new", f = function(i, t) 2 * (10 * i + t + 6))
  b$ntl_sum[b$unit_id == "a" & b$period == per[9]] <- NA
  sp <- ntl_splice(rbind(a, b), from = "old", to = "new", fill_gaps = TRUE, min_overlap = 2)
  filled <- sp[sp$unit_id == "a" & sp$period == per[9], ]
  expect_equal(filled$origin, "old (adjusted, gap fill)")
  expect_equal(filled$ntl_sum, 2 * (10 + 9), tolerance = 1e-8)
})
