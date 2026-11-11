# Diagnostics of a splice

Returns the calibration table computed by
[`ntl_splice()`](https://iskakovs.github.io/ntlpanel/reference/ntl_splice.md):
for each unit (and calendar month if `by_month = TRUE`) the number of
overlap observations, mean levels of both series, the level shift in
percent, their correlation, the coefficient of variation of the
period-by-period ratio (`ratio_cv`; large values mean an unstable
relationship), the calibration coefficients `a` and `b` (for `"ratio"`,
`a = 0` and `b = k`) and whether the pooled calibration was used as a
fallback.

## Usage

``` r
ntl_splice_report(x)
```

## Arguments

- x:

  Output of
  [`ntl_splice()`](https://iskakovs.github.io/ntlpanel/reference/ntl_splice.md).

## Value

A data frame with one row per unit (and calendar month).

## Examples

``` r
ex <- ntl_example()
m <- ntl_files(ex$dir, "eog_vnl_monthly")
m <- m[m$period >= as.Date("2022-04-01") &
         m$period <= as.Date("2023-03-01"), ]
long <- ntl_extract(m, ex$units_old, id_col = "district", quiet = TRUE)
sp <- ntl_splice(long,
  from = "eog_vnl_monthly_npp", to = "eog_vnl_monthly_j01"
)
ntl_splice_report(sp)
#>   district n_overlap mean_from    mean_to level_shift_pct       cor
#> 1       D1         8 10836.217 11703.1113        7.999970 1.0000000
#> 2       D2         8  1335.415  1442.2380        7.999223 0.9999997
#> 3       D3         8   906.470   978.6624        7.964123 0.9999990
#> 4       D4         9   829.062   895.3872        8.000030 0.9999990
#> 5       D5         9  1799.689  1943.7435        8.004395 0.9992366
#> 6       D6         9  6132.765  6623.3804        7.999901 0.9999997
#>       ratio_cv a        b fallback method
#> 1 9.031793e-06 0 1.080000    FALSE  ratio
#> 2 6.321193e-05 0 1.079992    FALSE  ratio
#> 3 6.306923e-04 0 1.079641    FALSE  ratio
#> 4 1.085723e-04 0 1.080000    FALSE  ratio
#> 5 1.678574e-03 0 1.080044    FALSE  ratio
#> 6 6.705101e-05 0 1.079999    FALSE  ratio
```
