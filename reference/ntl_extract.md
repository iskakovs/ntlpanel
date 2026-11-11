# Extract nighttime lights for many periods

The workhorse of the package: for every series and period in a manifest
it reads the files
([`ntl_read()`](https://iskakovs.github.io/ntlpanel/reference/ntl_read.md)),
applies masking rules
([`ntl_mask()`](https://iskakovs.github.io/ntlpanel/reference/ntl_mask.md))
and computes zonal statistics with coverage diagnostics
([`ntl_aggregate()`](https://iskakovs.github.io/ntlpanel/reference/ntl_aggregate.md)).
Periods are processed one at a time, so memory use does not grow with
the length of the series.

## Usage

``` r
ntl_extract(
  manifest,
  units,
  id_col = NULL,
  quality_max = 1,
  min_obs = NULL,
  flares = NULL,
  cap = NULL,
  variable = NULL,
  flip = NA,
  quiet = FALSE
)
```

## Arguments

- manifest:

  A manifest from
  [`ntl_fetch()`](https://iskakovs.github.io/ntlpanel/reference/ntl_fetch.md)
  or
  [`ntl_files()`](https://iskakovs.github.io/ntlpanel/reference/ntl_files.md).
  Several manifests can be combined with
  [`rbind()`](https://rdrr.io/r/base/cbind.html).

- units:

  Polygons: `sf` or `SpatVector`.

- id_col:

  Column of `units` with unique identifiers. If `NULL`, row numbers are
  used and the output column is called `unit_id`.

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

- variable:

  Value layer. Defaults to the product's `value_layer`
  (`NearNadir_Composite_Snow_Free`). Count and quality layers are
  `<variable>_Num` and `<variable>_Quality`.

- flip:

  `NA` (automatic), `TRUE` or `FALSE`.

- quiet:

  Suppress progress messages.

## Value

An `ntl_long` data frame: one row per unit, series and period, with the
columns described in
[`ntl_aggregate()`](https://iskakovs.github.io/ntlpanel/reference/ntl_aggregate.md)
plus `series`, `product`, `platform`, `period` and `period_label`.

## Details

Pixels belonging to tiles missing from the archive are treated as
unobserved, so they lower `share_valid` instead of silently changing the
area being summed.

## Examples

``` r
ex <- ntl_example()
m <- ntl_files(ex$dir, "eog_vnl_monthly")
m <- m[m$period <= as.Date("2021-06-01"), ] # keep the example fast
long <- ntl_extract(m, ex$units_old, id_col = "district", min_obs = 1)
#> Extracting eog_vnl_monthly_npp 2021-01 (1/6)
#> Extracting eog_vnl_monthly_npp 2021-02 (2/6)
#> Extracting eog_vnl_monthly_npp 2021-03 (3/6)
#> Extracting eog_vnl_monthly_npp 2021-04 (4/6)
#> Extracting eog_vnl_monthly_npp 2021-05 (5/6)
#> Extracting eog_vnl_monthly_npp 2021-06 (6/6)
head(long)
#> <ntl_long> 1 unit(s) x 6 period(s); series: eog_vnl_monthly_npp
#>  district              series         product platform     period period_label
#>        D1 eog_vnl_monthly_npp eog_vnl_monthly     SNPP 2021-01-01      2021-01
#>        D1 eog_vnl_monthly_npp eog_vnl_monthly     SNPP 2021-02-01      2021-02
#>        D1 eog_vnl_monthly_npp eog_vnl_monthly     SNPP 2021-03-01      2021-03
#>        D1 eog_vnl_monthly_npp eog_vnl_monthly     SNPP 2021-04-01      2021-04
#>        D1 eog_vnl_monthly_npp eog_vnl_monthly     SNPP 2021-05-01      2021-05
#>        D1 eog_vnl_monthly_npp eog_vnl_monthly     SNPP 2021-06-01      2021-06
#>    ntl_sum ntl_sum_adj ntl_mean share_valid share_masked mean_obs n_pixels
#>  10780.638   10780.638 4.491933           1            0        8     2400
#>  10823.796   10823.796 4.509915           1            0        8     2400
#>   9449.553    9449.553 3.937314           1            0        8     2400
#>   9487.496    9487.496 3.953123           1            0        8     2400
#>   9525.262    9525.262 3.968859           1            0        2     2400
#>         NA          NA       NA           0            0        0     2400
```
