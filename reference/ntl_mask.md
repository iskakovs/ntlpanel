# Mask low-quality, under-observed and gas-flare pixels

Applies explicit, recorded masking rules to a raster returned by
[`ntl_read()`](https://iskakovs.github.io/ntlpanel/reference/ntl_read.md)
or
[`ntl_read_bm()`](https://iskakovs.github.io/ntlpanel/reference/ntl_read_bm.md).
Every pixel that had a value but was removed is marked in an extra
`masked` layer, so
[`ntl_aggregate()`](https://iskakovs.github.io/ntlpanel/reference/ntl_aggregate.md)
can report the share of each unit lost to masking.

## Usage

``` r
ntl_mask(x, quality_max = 1, min_obs = NULL, flares = NULL, cap = NULL)
```

## Arguments

- x:

  A `SpatRaster` with a `value` layer and optionally `nobs` and
  `quality` layers.

- quality_max:

  Keep pixels with `quality <= quality_max`. `NULL` disables the rule.
  Ignored if there is no `quality` layer.

- min_obs:

  Keep pixels with at least this many cloud-free observations. `NULL`
  disables the rule. Ignored if there is no `nobs` layer.

- flares:

  Optional gas-flare mask: an `sf`/`SpatVector` of polygons or a
  `SpatRaster` whose non-zero cells are flares. Pixels touching a flare
  polygon are removed.

- cap:

  Optional upper bound; values above it are set to `cap` (top-coding of
  extreme outliers, applied after masking).

## Value

`x` with masked pixels set to `NA` in `value` and an added `masked`
layer (1 = removed by a rule, 0 = kept, `NA` = no data).

## Details

Black Marble monthly and annual quality flags are: `0` good (more than
three observations), `1` poor (three or fewer observations), `2`
gap-filled from earlier data. The default `quality_max = 1` drops
gap-filled pixels: they carry past values forward and would bias
estimated effects toward zero.

Pixels with zero cloud-free observations (`nobs == 0`) are always
treated as unobserved, whatever their stored value: EOG monthly
composites store 0 radiance there, which would otherwise be read as
"dark". They lower `share_valid` but are not counted as masked.

## Examples

``` r
ex <- ntl_example()
m <- ntl_files(ex$dir, "eog_vnl_monthly")
r <- ntl_read(m, period = "2022-06", series = "eog_vnl_monthly_npp")
rm <- ntl_mask(r, min_obs = 2)
terra::global(rm$masked, "sum", na.rm = TRUE)
#>        sum
#> masked   0
```
