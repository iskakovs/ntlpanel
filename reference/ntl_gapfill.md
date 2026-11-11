# Handle missing and low-coverage observations explicitly

Applies one documented rule to the missing cells of an
[`ntl_panel()`](https://iskakovs.github.io/ntlpanel/reference/ntl_panel.md),
and flags unit-months at risk of summer stray-light gaps. VIIRS cannot
observe at night when the sun barely sets, so units north of about 45
degrees have missing or contaminated values around the June solstice (in
northern Kazakhstan typically May to August). Silently averaging
whatever pixels remain creates spurious seasonal swings; this function
makes the choice visible.

## Usage

``` r
ntl_gapfill(
  panel,
  rule = c("interp", "seasonal", "drop", "none"),
  max_gap = 2,
  units = NULL,
  lat_threshold = NULL,
  months = 5:8
)
```

## Arguments

- panel:

  An `ntl_panel`.

- rule:

  One of `"interp"`, `"seasonal"`, `"drop"`, `"none"`.

- max_gap:

  Longest run of missing periods to interpolate (`rule = "interp"`).

- units:

  Optional unit polygons (with the panel's id column), used with
  `lat_threshold` to flag stray-light risk.

- lat_threshold:

  Latitude (degrees north) from which units are flagged during `months`.
  A unit's latitude is that of a point on its surface.

- months:

  Calendar months flagged as stray-light risk.

## Value

The panel with columns `imputed`, `impute_method` and, if `units` and
`lat_threshold` are given, `lat` and `stray_light_risk`. The attribute
`gap_report` counts missing cells by month before and after filling.

## Details

Rules:

- `"none"`: only add flags.

- `"drop"`: remove missing rows (the panel becomes unbalanced).

- `"interp"`: linear interpolation within each unit for interior runs of
  at most `max_gap` missing periods.

- `"seasonal"` (monthly panels): multiplicative fill
  `value = S[unit, month] * L[unit, year]`, where `S` is the unit's
  seasonal index (median ratio of a month to the deseasonalised annual
  level) and `L` is the unit's deseasonalised level in that year. A
  calendar month that is never observed for a unit cannot be filled and
  stays `NA`; consider annual data or dropping those months.

Filled values are marked with `imputed = TRUE` and `impute_method`, so
you can run robustness checks with and without them.

## Examples

``` r
ex <- ntl_example()
m <- ntl_files(ex$dir, "eog_vnl_monthly")
m <- m[m$series == "eog_vnl_monthly_npp" &
         m$period < as.Date("2022-01-01"), ]
long <- ntl_extract(m, ex$units_old, id_col = "district", quiet = TRUE)
p <- ntl_panel(long, min_share_valid = 0.5)
p2 <- ntl_gapfill(p,
  rule = "interp", max_gap = 2,
  units = ex$units_old, lat_threshold = 48
)
attr(p2, "gap_report")
#>    month missing_before missing_after
#> 1      1              0             0
#> 2      2              0             0
#> 3      3              0             0
#> 4      4              0             0
#> 5      5              0             0
#> 6      6              3             0
#> 7      7              3             0
#> 8      8              0             0
#> 9      9              0             0
#> 10    10              0             0
#> 11    11              0             0
#> 12    12              0             0
```
