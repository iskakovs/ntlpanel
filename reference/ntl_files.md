# Index nighttime lights files you already have

Builds a manifest from local files so they can go through
[`ntl_extract()`](https://iskakovs.github.io/ntlpanel/reference/ntl_extract.md)
like downloaded ones. Use it for products that `ntlpanel` cannot
download (EOG VNL composites, harmonized DMSP-VIIRS series) and for
Black Marble `.h5` files downloaded elsewhere (for example with
blackmarbler's `h5_dir`).

## Usage

``` r
ntl_files(paths, product, period = NULL, series = NULL, recursive = TRUE)
```

## Arguments

- paths:

  Files and/or directories. Directories are searched for files matching
  the product's `file_pattern` (see
  [`ntl_sources()`](https://iskakovs.github.io/ntlpanel/reference/ntl_sources.md)).

- product:

  Product id from
  [`ntl_sources()`](https://iskakovs.github.io/ntlpanel/reference/ntl_sources.md).

- period:

  Optional periods, one per file, overriding the parsed ones.

- series:

  Optional series name overriding the default.

- recursive:

  Search directories recursively.

## Value

An `ntl_manifest` data frame.

## Details

Periods, platforms and tiles are parsed from file names:

- Black Marble: `VNP46A3.A2023001.h25v03.002.<production>.h5`.

- EOG monthly:
  `SVDNB_<platform>_<YYYYMMDD>-<YYYYMMDD>_<tile>_...avg_rade9h.tif`. The
  matching `...cf_cvg...` file, if present in the same folder, is used
  as the observation-count layer. Each platform (`npp`, `j01`) becomes
  its own series, e.g. `eog_vnl_monthly_npp`.

- EOG annual: `VNL_[v22_]<platform>_<YYYY>_...average_masked...tif`.

- Harmonized series: the first four-digit year (1900-2099) in the name.

If a name cannot be parsed, pass `period` explicitly.

## Examples

``` r
ex <- ntl_example()
m <- ntl_files(ex$dir, "eog_vnl_monthly")
table(m$series)
#> 
#> eog_vnl_monthly_j01 eog_vnl_monthly_npp 
#>                  18                  36 
```
