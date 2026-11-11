# Zonal statistics with coverage diagnostics

Summarises a (masked) nighttime lights raster over polygons using exact
pixel coverage fractions (exactextractr), and reports how much of each
unit was actually observed.

## Usage

``` r
ntl_aggregate(x, units, id_col = NULL)
```

## Arguments

- x:

  A `SpatRaster` with a `value` layer and optionally `masked` and `nobs`
  layers (see
  [`ntl_mask()`](https://iskakovs.github.io/ntlpanel/reference/ntl_mask.md)).

- units:

  Polygons: `sf` or `SpatVector`.

- id_col:

  Column of `units` with unique identifiers. If `NULL`, row numbers are
  used and the output column is called `unit_id`.

## Value

A data frame with one row per unit:

- ntl_sum:

  Sum of lights over observed pixels (coverage-weighted). `NA` when
  nothing was observed, so "dark" (0) and "unobserved" (`NA`) stay
  distinct.

- ntl_sum_adj:

  `ntl_sum / share_valid`: the sum scaled up to the full unit, assuming
  unobserved pixels resemble observed ones.

- ntl_mean:

  Mean radiance of observed pixels.

- share_valid:

  Share of the unit's pixels with a valid value.

- share_masked:

  Share removed by
  [`ntl_mask()`](https://iskakovs.github.io/ntlpanel/reference/ntl_mask.md)
  rules.

- mean_obs:

  Mean number of cloud-free observations per pixel.

- n_pixels:

  Number of pixels covering the unit (fractional).

## Examples

``` r
ex <- ntl_example()
m <- ntl_files(ex$dir, "eog_vnl_monthly")
r <- ntl_read(m, period = "2022-06", series = "eog_vnl_monthly_npp")
r <- ntl_mask(r)
ntl_aggregate(r, ex$units_old, id_col = "district")
#>   district   ntl_sum ntl_sum_adj  ntl_mean share_valid share_masked mean_obs
#> 1       D1        NA          NA        NA           0            0        0
#> 2       D2        NA          NA        NA           0            0        0
#> 3       D3        NA          NA        NA           0            0        0
#> 4       D4  773.5295    773.5295 0.3223040           1            0        8
#> 5       D5 1734.0659   1734.0659 0.7225275           1            0        8
#> 6       D6 5722.8332   5722.8332 2.3845138           1            0        8
#>   n_pixels
#> 1     2400
#> 2     2400
#> 3     2400
#> 4     2400
#> 5     2400
#> 6     2400
```
