# Read a Black Marble HDF5 tile

Reads the value, observation-count and quality layers of a Black Marble
monthly or annual tile (`VNP46A3`, `VNP46A4`, `VJ146A3`, `VJ146A4`) and
georeferences it from the tile id in the file name.

## Usage

``` r
ntl_read_bm(
  file,
  variable = NULL,
  layers = c("value", "nobs", "quality"),
  flip = NA
)
```

## Arguments

- file:

  Path to an `.h5` file.

- variable:

  Value layer. Defaults to the product's `value_layer`
  (`NearNadir_Composite_Snow_Free`). Count and quality layers are
  `<variable>_Num` and `<variable>_Quality`.

- layers:

  Which layers to return, renamed to `value`, `nobs` and `quality`.

- flip:

  `NA` (automatic), `TRUE` or `FALSE`.

## Value

A `SpatRaster` in EPSG:4326.

## Details

Fill values (65535 for radiance and counts, 255 for quality) become
`NA`. Values are returned as stored in Collection 2 (nW/cm2/sr); no
extra scale factor is applied.

**Orientation.** Some GDAL builds return Black Marble grids bottom-up,
which makes tiles appear upside down (reported in blackmarbler issue
\#17). `ntl_read_bm()` therefore (1) keeps GDAL's own georeferencing
when it matches the tile, (2) otherwise checks the file's `lat` dataset
with the hdf5r package, if installed, and flips the grid when latitude
increases with row number, and (3) otherwise assumes north-up rows. Use
`flip` to force the choice, and check one tile against a known city
before a large run.

## Examples

``` r
# A small synthetic tile shipped with the package (real tiles are
# 2400 x 2400 pixels)
f <- system.file("extdata", "VNP46A3.A2023001.h25v04.002.2023040000000.h5",
  package = "ntlpanel"
)
r <- ntl_read_bm(f)
#> Warning: [rast] guessed crs
r
#> class       : SpatRaster
#> size        : 40, 40, 3  (nrow, ncol, nlyr)
#> resolution  : 0.25, 0.25  (x, y)
#> extent      : 70, 80, 40, 50  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (EPSG:4326)
#> source(s)   : memory
#> varnames    : HDFEOS/GRIDS/VIIRS_Grid_DNB_2d/Data Fields/NearNadir_Composite_Snow_Free
#>               HDFEOS/GRIDS/VIIRS_Grid_DNB_2d/Data Fields/NearNadir_Composite_Snow_Free_Num
#>               HDFEOS/GRIDS/VIIRS_Grid_DNB_2d/Data Fields/NearNadir_Composite_Snow_Free_Quality
#> names       : value, nobs, quality
#> min values  :     0,    3,       0
#> max values  :   352,   12,       2
terra::plot(log1p(r$value))
```
