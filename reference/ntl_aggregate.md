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
# A 4 x 4 raster with one unobserved pixel pair, split into two units
r <- terra::rast(xmin = 0, xmax = 2, ymin = 0, ymax = 2, nrows = 4,
                 ncols = 4, crs = "EPSG:4326", names = "value")
terra::values(r) <- c(1, 2, 3, 4, 5, 6, 7, 8, NA, NA, 0, 0, 1, 1, 0, 0)
units <- sf::st_as_sf(terra::vect(c(
  "POLYGON ((0 0, 1 0, 1 2, 0 2, 0 0))",
  "POLYGON ((1 0, 2 0, 2 2, 1 2, 1 0))"
), crs = "EPSG:4326"))
units$id <- c("west", "east")
ntl_aggregate(r, units, id_col = "id")
#>     id ntl_sum ntl_sum_adj ntl_mean share_valid share_masked mean_obs n_pixels
#> 1 west      16    21.33333 2.666667        0.75           NA       NA        8
#> 2 east      22    22.00000 2.750000        1.00           NA       NA        8
```
