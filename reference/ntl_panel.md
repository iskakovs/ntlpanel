# Build a balanced, analysis-ready panel

Turns the long output of
[`ntl_extract()`](https://iskakovs.github.io/ntlpanel/reference/ntl_extract.md)
or
[`ntl_splice()`](https://iskakovs.github.io/ntlpanel/reference/ntl_splice.md)
into a balanced unit x period panel. Unit-periods that were never
extracted (for example because no file existed) are added with `NA`
values instead of disappearing, and low-coverage observations can be set
to `NA` with an explicit threshold.

## Usage

``` r
ntl_panel(
  x,
  value = "ntl_sum",
  id_col = NULL,
  min_share_valid = NULL,
  transform = c("log1p", "asinh", "log", "none"),
  balance = TRUE,
  frequency = NULL
)
```

## Arguments

- x:

  An `ntl_long` data frame with a single series.

- value:

  Column holding the outcome (default `"ntl_sum"`).

- id_col:

  Unit identifier column. Defaults to the one recorded by
  [`ntl_extract()`](https://iskakovs.github.io/ntlpanel/reference/ntl_extract.md).

- min_share_valid:

  If set, observations with `share_valid` below this threshold get `NA`
  values and `low_coverage = TRUE`.

- transform:

  Transformation stored in column `ntl`: `"log1p"` (default), `"asinh"`,
  `"log"` (zeros become `NA`) or `"none"`.

- balance:

  Complete the unit x period grid.

- frequency:

  `"month"` or `"year"`. Defaults to the frequency recorded by
  [`ntl_extract()`](https://iskakovs.github.io/ntlpanel/reference/ntl_extract.md).

## Value

An `ntl_panel` data frame with the id column, `period`, `year`, `month`
(monthly panels), `t` (consecutive integer time index), the outcome,
`ntl` (transformed outcome), `ntl_missing`, `low_coverage` and the
coverage diagnostics. The columns `t` and the id work directly with
`fixest::feols(ntl ~ ... | id + t)`.

## Examples

``` r
ex <- ntl_example()
m <- ntl_files(ex$dir, "eog_vnl_monthly")
m <- m[m$series == "eog_vnl_monthly_npp" &
         m$period < as.Date("2022-01-01"), ]
long <- ntl_extract(m, ex$units_old,
                    id_col = "district", quiet = TRUE)
p <- ntl_panel(long, min_share_valid = 0.5)
table(p$month, p$ntl_missing)
#>     
#>      FALSE TRUE
#>   1      6    0
#>   2      6    0
#>   3      6    0
#>   4      6    0
#>   5      6    0
#>   6      3    3
#>   7      3    3
#>   8      6    0
#>   9      6    0
#>   10     6    0
#>   11     6    0
#>   12     6    0
```
