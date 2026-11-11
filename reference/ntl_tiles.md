# Black Marble tiles covering an area of interest

Black Marble products are distributed on a fixed 10 x 10 degree
longitude/latitude grid with 36 horizontal (`h00`-`h35`) and 18 vertical
(`v00`-`v17`) tiles. Tile `hHHvVV` spans longitude `-180 + 10 * HH` to
`-170 + 10 * HH` and latitude `90 - 10 * VV` down to `80 - 10 * VV`.

## Usage

``` r
ntl_tiles(aoi, refine = TRUE)
```

## Arguments

- aoi:

  Area of interest: an `sf`/`sfc` object, a terra `SpatVector`, or a
  numeric bounding box `c(xmin, ymin, xmax, ymax)` in degrees.

- refine:

  If `TRUE` (default), keep only tiles that intersect the geometry
  itself, not just its bounding box.

## Value

A data frame with columns `tile`, `h`, `v`, `xmin`, `xmax`, `ymin` and
`ymax`.

## Examples

``` r
# Bounding box of Kazakhstan
ntl_tiles(c(46.4, 40.5, 87.4, 55.5))
#>      tile  h v xmin xmax ymin ymax
#> 1  h22v03 22 3   40   50   50   60
#> 2  h23v03 23 3   50   60   50   60
#> 3  h24v03 24 3   60   70   50   60
#> 4  h25v03 25 3   70   80   50   60
#> 5  h26v03 26 3   80   90   50   60
#> 6  h22v04 22 4   40   50   40   50
#> 7  h23v04 23 4   50   60   40   50
#> 8  h24v04 24 4   60   70   40   50
#> 9  h25v04 25 4   70   80   40   50
#> 10 h26v04 26 4   80   90   40   50
```
