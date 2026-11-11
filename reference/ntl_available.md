# Check which periods and tiles are available on NASA LAADS

Reads the public LAADS file listings for a Black Marble product and
counts available tiles per period. Listings are cached in
`cache_dir/listings`; listings for the last 180 days are refreshed after
seven days because recent periods can still be reprocessed.

## Usage

``` r
ntl_available(
  product,
  years,
  tiles = NULL,
  cache_dir = ntl_cache_dir(),
  refresh = FALSE
)
```

## Arguments

- product:

  A product id with `backend == "laads"`, e.g. `"VNP46A3"` or
  `"VJ146A3"` (see
  [`ntl_sources()`](https://iskakovs.github.io/ntlpanel/reference/ntl_sources.md)).

- years:

  Integer vector of years to check.

- tiles:

  Optional tile ids (see
  [`ntl_tiles()`](https://iskakovs.github.io/ntlpanel/reference/ntl_tiles.md));
  `NULL` counts all tiles.

- cache_dir:

  Cache directory (see
  [`ntl_cache_dir()`](https://iskakovs.github.io/ntlpanel/reference/ntl_cache_dir.md)).

- refresh:

  Re-download listings even if cached.

## Value

A data frame with `product`, `period`, `period_label` and `n_tiles`.

## Examples

``` r
if (FALSE) { # interactive()
# Is NOAA-20 monthly data available for Kazakhstan in 2018?
kz_tiles <- ntl_tiles(c(46.4, 40.5, 87.4, 55.5))$tile
ntl_available("VJ146A3", 2018, tiles = kz_tiles)
}
```
