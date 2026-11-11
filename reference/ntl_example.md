# Synthetic example data

Writes a small, entirely synthetic nighttime lights dataset in EOG
monthly file format and returns matching vector data, so examples, tests
and the vignette run offline in seconds. **None of it is real data.**

## Usage

``` r
ntl_example(dir = file.path(tempdir(), "ntlpanel-example"), overwrite = FALSE)
```

## Arguments

- dir:

  Directory to write the GeoTIFFs to.

- overwrite:

  Rewrite files that already exist.

## Value

A list with `dir` (path), `units_old` (six districts, column
`district`), `units_new` (a later vintage, column `district_new`, in
which `D1` is split into `D1a`/`D1b` and `D5` and `D6` merge into `D56`)
and `sites` (two dated treatment sites, columns `site` and `start`).

## Details

The area is a 6 x 6 degree box (66-72 E, 46-52 N) at 0.05 degree
resolution, with:

- two cities with steady growth and a winter brightening;

- two "treatment" sites that switch on in June 2022 and March 2023;

- a summer stray-light blackout north of 49 N in June and July (zero
  coverage, stored as 0 radiance as in EOG files) and thin coverage in
  May and August;

- a Suomi NPP series (`npp`, 2021-01 to 2023-12) and a NOAA-20 series
  (`j01`, 2022-07 to 2023-12) that reads about 8% brighter.

## Examples

``` r
ex <- ntl_example()
ex$units_old
#> Simple feature collection with 6 features and 1 field
#> Geometry type: POLYGON
#> Dimension:     XY
#> Bounding box:  xmin: 66 ymin: 46 xmax: 72 ymax: 52
#> Geodetic CRS:  WGS 84
#>   district                       geometry
#> 1       D1 POLYGON ((66 49, 68 49, 68 ...
#> 2       D2 POLYGON ((68 49, 70 49, 70 ...
#> 3       D3 POLYGON ((70 49, 72 49, 72 ...
#> 4       D4 POLYGON ((66 46, 68 46, 68 ...
#> 5       D5 POLYGON ((68 46, 70 46, 70 ...
#> 6       D6 POLYGON ((70 46, 72 46, 72 ...
length(list.files(ex$dir))
#> [1] 108
```
