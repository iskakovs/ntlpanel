# Read one period of a manifest as a raster

Reads all files of one series and one period from a manifest, crops each
to the area of interest, mosaics them and extends the result to the full
area so that missing tiles show up as `NA` instead of silently shrinking
the coverage.

## Usage

``` r
ntl_read(
  manifest,
  period = NULL,
  series = NULL,
  aoi = NULL,
  variable = NULL,
  flip = NA
)
```

## Arguments

- manifest:

  A manifest from
  [`ntl_fetch()`](https://iskakovs.github.io/ntlpanel/reference/ntl_fetch.md)
  or
  [`ntl_files()`](https://iskakovs.github.io/ntlpanel/reference/ntl_files.md).

- period:

  Period to read (`"YYYY-MM"`, `"YYYY"` or `Date`). May be omitted if
  the manifest holds a single period.

- series:

  Series to read. May be omitted if the manifest holds a single series.

- aoi:

  Optional area of interest (see
  [`ntl_tiles()`](https://iskakovs.github.io/ntlpanel/reference/ntl_tiles.md)).

- variable:

  Value layer. Defaults to the product's `value_layer`
  (`NearNadir_Composite_Snow_Free`). Count and quality layers are
  `<variable>_Num` and `<variable>_Quality`.

- flip:

  `NA` (automatic), `TRUE` (flip the stored grid vertically) or `FALSE`
  (use the stored row order as is).

## Value

A `SpatRaster` with layers `value` and, where available, `nobs` and
`quality`.

## Examples

``` r
ex <- ntl_example()
m <- ntl_files(ex$dir, "eog_vnl_monthly")
r <- ntl_read(m, period = "2022-03", series = "eog_vnl_monthly_npp")
r
#> class       : SpatRaster
#> size        : 120, 120, 2  (nrow, ncol, nlyr)
#> resolution  : 0.05, 0.05  (x, y)
#> extent      : 66, 72, 46, 52  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (EPSG:4326)
#> sources     : SVDNB_npp_20220301-20220331_75N060E_vcmslcfg_v10_c000000000000.avg_rade9h.tif
#>               SVDNB_npp_20220301-20220331_75N060E_vcmslcfg_v10_c000000000000.cf_cvg.tif
#> names       :     value, nobs
#> min values  :  0.305772,    8
#> max values  : 44.075241,    8
```
