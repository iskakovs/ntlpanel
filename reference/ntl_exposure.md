# Distance-ring treatment exposure

Assigns each unit its distance to the nearest treatment site, a ring
(e.g. 0-10, 10-25, 25-50, \>50 km), the number of sites within the
largest ring and, if sites are dated, the first treatment date among
sites within the largest ring. That date can serve as the cohort
variable of staggered difference-in-differences estimators.

## Usage

``` r
ntl_exposure(
  units,
  sites,
  rings = c(10, 25, 50),
  id_col = NULL,
  site_id_col = NULL,
  site_time_col = NULL,
  from = c("centroid", "boundary")
)
```

## Arguments

- units:

  Unit polygons (`sf` or `SpatVector`).

- sites:

  Treatment sites: points, lines or polygons (e.g. earthquake
  epicentres, Belt and Road projects, new plants).

- rings:

  Ring boundaries in kilometres, increasing.

- id_col:

  Unit identifier column.

- site_id_col:

  Optional site identifier column, reported for the nearest site.

- site_time_col:

  Optional column of site dates (or periods); the earliest one within
  `max(rings)` km is returned as `first_treat`.

- from:

  Measure distance from the unit's `"centroid"` (a point on its surface)
  or from its `"boundary"` (0 if the site is inside the unit).

## Value

A data frame with the id column, `nearest_site`, `dist_km`, `ring`, one
logical `within_<r>km` column per ring, `n_sites_within` and, if
`site_time_col` is given, `first_treat`.

## Details

Distances are great-circle distances (sf with s2) in kilometres. Network
distances are not computed here; use dodgr or sfnetworks for those.

## Examples

``` r
ex <- ntl_example()
ntl_exposure(ex$units_old, ex$sites, rings = c(50, 100, 200),
             id_col = "district", site_id_col = "site",
             site_time_col = "start")
#>   district nearest_site   dist_km    ring within_50km within_100km within_200km
#> 1       D1           S2 304.95241    >200       FALSE        FALSE        FALSE
#> 2       D2           S2 165.54726 100-200       FALSE        FALSE         TRUE
#> 3       D3           S2  39.49883    0-50        TRUE         TRUE         TRUE
#> 4       D4           S1 167.06455 100-200       FALSE        FALSE         TRUE
#> 5       D5           S1  26.85456    0-50        TRUE         TRUE         TRUE
#> 6       D6           S1 137.28740 100-200       FALSE        FALSE         TRUE
#>   n_sites_within first_treat
#> 1              0        <NA>
#> 2              1  2023-03-01
#> 3              1  2023-03-01
#> 4              1  2022-06-01
#> 5              1  2022-06-01
#> 6              1  2022-06-01
```
