# Crosswalk between two boundary vintages

Builds the weights needed to move tabular data between two sets of
administrative units, for example Kazakhstan's oblasts before and after
the 2022 reform that created Abai, Zhetysu and Ulytau regions.

## Usage

``` r
ntl_crosswalk(
  from,
  to,
  from_id,
  to_id,
  weight_raster = NULL,
  min_share = 0.001
)
```

## Arguments

- from, to:

  Polygons of the old and new vintage (`sf` or `SpatVector`).

- from_id, to_id:

  Identifier columns in `from` and `to`.

- weight_raster:

  Optional `SpatRaster` used for weighting.

- min_share:

  Pieces holding less than this share of both their `from` and `to` unit
  are treated as digitising slivers and dropped before re-normalising.

## Value

An `ntl_crosswalk` data frame with `from_id`, `to_id`, `area_km2`,
`weight`, `w_from` (share of the `from` unit going to `to`; use for
extensive variables such as totals), `w_to` (share of the `to` unit
coming from `from`; use for intensive variables such as rates) and
`relation` (`unchanged`, `split`, `merge` or `split-merge`).

## Details

Nighttime lights themselves never need a crosswalk: extract them again
with the other boundaries. Crosswalks matter for official statistics
(GRP, employment, tax revenue) that exist only in one vintage and must
be merged with a lights panel built on the other.

Weights come from the area of each intersection piece or, better for
economic variables, from a raster such as nighttime lights or population
summed over each piece (`weight_raster`). Units whose raster total is
zero fall back to area weights.

## Examples

``` r
ex <- ntl_example()
xw <- ntl_crosswalk(ex$units_old, ex$units_new, "district", "district_new")
xw
#>   from_id to_id area_km2   weight weight_source w_from w_to  relation
#> 1      D1   D1a 23674.16 23674.16          area    0.5  1.0     split
#> 2      D1   D1b 23674.16 23674.16          area    0.5  1.0     split
#> 3      D2    D2 47348.33 47348.33          area    1.0  1.0 unchanged
#> 4      D3    D3 47348.33 47348.33          area    1.0  1.0 unchanged
#> 5      D4    D4 50254.53 50254.53          area    1.0  1.0 unchanged
#> 6      D5   D56 50254.53 50254.53          area    1.0  0.5     merge
#> 7      D6   D56 50254.53 50254.53          area    1.0  0.5     merge
```
