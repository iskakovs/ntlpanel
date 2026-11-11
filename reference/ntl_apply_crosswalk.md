# Apply a boundary crosswalk to tabular data

Re-expresses variables measured on the `from` vintage on the `to`
vintage using an
[`ntl_crosswalk()`](https://iskakovs.github.io/ntlpanel/reference/ntl_crosswalk.md).

## Usage

``` r
ntl_apply_crosswalk(
  data,
  xw,
  id_col,
  vars,
  type = c("extensive", "intensive"),
  by = NULL,
  na_rm = FALSE
)
```

## Arguments

- data:

  A data frame keyed by the `from` identifier.

- xw:

  An `ntl_crosswalk`.

- id_col:

  Column of `data` holding `from` identifiers.

- vars:

  Variables to convert.

- type:

  `"extensive"` or `"intensive"`, recycled along `vars`.

- by:

  Additional grouping columns kept in the output, typically `"period"`
  or `"year"`.

- na_rm:

  Ignore missing contributors instead of returning `NA`.

## Value

A data frame keyed by the `to` identifier (named as in `xw`) and `by`.

## Details

- Extensive variables (totals: output, population, sum of lights):
  `x_to = sum(x_from * w_from)`.

- Intensive variables (rates, means, shares):
  `x_to = sum(x_from * w_to) / sum(w_to)` over contributing units.

By default a result is `NA` if any contributing unit is `NA`, because a
partial sum would understate the total.

## Examples

``` r
ex <- ntl_example()
xw <- ntl_crosswalk(ex$units_old, ex$units_new, "district", "district_new")
stats <- data.frame(district = ex$units_old$district, year = 2022,
                    employment = c(120, 80, 60, 150, 90, 40),
                    unemployment_rate = c(5, 7, 6, 4, 8, 9))
ntl_apply_crosswalk(stats, xw, "district",
                    vars = c("employment", "unemployment_rate"),
                    type = c("extensive", "intensive"), by = "year")
#>   district_new year employment unemployment_rate
#> 1          D1a 2022         60               5.0
#> 2          D1b 2022         60               5.0
#> 3           D2 2022         80               7.0
#> 4           D3 2022         60               6.0
#> 5           D4 2022        150               4.0
#> 6          D56 2022        130               8.5
```
