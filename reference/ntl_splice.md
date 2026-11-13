# Splice two sensors into one consistent series

Puts an older series (`from`, e.g. Suomi NPP `VNP46A3`) on the scale of
a newer one (`to`, e.g. NOAA-20 `VJ146A3`) using the periods both
observe, and reports level shifts per unit so you can judge whether the
splice is innocuous or a research problem in itself.

## Usage

``` r
ntl_splice(
  x,
  from,
  to,
  value = "ntl_sum",
  id_col = NULL,
  method = c("ratio", "regression", "none"),
  overlap = NULL,
  by_month = FALSE,
  switch_at = NULL,
  fill_gaps = FALSE,
  min_overlap = 3,
  min_share_valid = NULL
)
```

## Arguments

- x:

  An `ntl_long` data frame (from
  [`ntl_extract()`](https://iskakovs.github.io/ntlpanel/reference/ntl_extract.md))
  holding both series, e.g.
  [`rbind()`](https://rdrr.io/r/base/cbind.html) of two extractions.

- from, to:

  Series names (column `series`).

- value:

  Outcome column to calibrate.

- id_col:

  Unit identifier column.

- method:

  `"ratio"`, `"regression"` or `"none"`.

- overlap:

  Optional overlap window used for estimation: two periods (start and
  end) or a vector of periods. Defaults to every period both series
  observe.

- by_month:

  Estimate a separate calibration for each calendar month (monthly
  data). Useful at high latitude, where the two satellites' summer
  coverage differs. Needs several years of overlap: with fewer, each
  factor rests on one or two months per unit.

- switch_at:

  First period taken from `to`. Defaults to the first period in which
  `to` has data.

- fill_gaps:

  Fill missing `to` values after the switch with adjusted `from` values.

- min_overlap:

  Minimum overlap observations per calibration group.

- min_share_valid:

  Only use overlap observations where both series have at least this
  coverage share for estimation.

## Value

An `ntl_long` data frame with one series named `"<from>+<to>"` and a
column `origin` saying where each value came from. The calibration
diagnostics are in
[`ntl_splice_report()`](https://iskakovs.github.io/ntlpanel/reference/ntl_splice_report.md).

## Details

Calibration is estimated per unit (and per calendar month if
`by_month = TRUE`) on overlap periods where both series are observed:

- `"ratio"`: `to = k * from`, with `k = sum(to) / sum(from)`.
  Multiplicative, so it also applies to means and adjusted sums.

- `"regression"`: `to = a + b * from` by OLS; adjusted values are
  floored at zero.

- `"none"`: no adjustment; series are simply stacked.

Units with fewer than `min_overlap` overlap observations (or no light in
`from`) fall back to the pooled calibration and are flagged in the
diagnostics.

The spliced series uses adjusted `from` values before `switch_at` and
`to` values from `switch_at` on, so the sensor never alternates from one
period to the next. With `fill_gaps = TRUE`, missing `to` values after
the switch are filled with adjusted `from` values where available.

## Examples

``` r
ex <- ntl_example()
m <- ntl_files(ex$dir, "eog_vnl_monthly")
m <- m[m$period >= as.Date("2022-04-01") &
         m$period <= as.Date("2023-03-01"), ]
long <- ntl_extract(m, ex$units_old, id_col = "district", quiet = TRUE)
sp <- ntl_splice(long,
  from = "eog_vnl_monthly_npp", to = "eog_vnl_monthly_j01"
)
head(sp)
#> <ntl_long> 1 unit(s) x 6 period(s); series: eog_vnl_monthly_npp+eog_vnl_monthly_j01
#>  district                                  series product       platform
#>        D1 eog_vnl_monthly_npp+eog_vnl_monthly_j01 spliced SNPP + NOAA-20
#>        D1 eog_vnl_monthly_npp+eog_vnl_monthly_j01 spliced SNPP + NOAA-20
#>        D1 eog_vnl_monthly_npp+eog_vnl_monthly_j01 spliced SNPP + NOAA-20
#>        D1 eog_vnl_monthly_npp+eog_vnl_monthly_j01 spliced SNPP + NOAA-20
#>        D1 eog_vnl_monthly_npp+eog_vnl_monthly_j01 spliced SNPP + NOAA-20
#>        D1 eog_vnl_monthly_npp+eog_vnl_monthly_j01 spliced SNPP + NOAA-20
#>      period period_label  ntl_sum ntl_sum_adj ntl_mean share_valid share_masked
#>  2022-04-01      2022-04 10749.08    10749.08 4.478782           1            0
#>  2022-05-01      2022-05 10792.31    10792.31 4.496796           1            0
#>  2022-06-01      2022-06       NA          NA       NA           0            0
#>  2022-07-01      2022-07       NA          NA       NA           0            0
#>  2022-08-01      2022-08 10922.10    10922.10 4.550875           1            0
#>  2022-09-01      2022-09 10966.02    10966.02 4.569175           1            0
#>  mean_obs n_pixels                         origin
#>         8     2400 eog_vnl_monthly_npp (adjusted)
#>         2     2400 eog_vnl_monthly_npp (adjusted)
#>         0     2400 eog_vnl_monthly_npp (adjusted)
#>         0     2400            eog_vnl_monthly_j01
#>         2     2400            eog_vnl_monthly_j01
#>         8     2400            eog_vnl_monthly_j01
```
