# Download Black Marble tiles from NASA LAADS

Downloads the HDF5 tiles of a Black Marble product that cover `aoi` for
every period from `start` to `end`, and returns a manifest describing
what was fetched. Works for Suomi NPP (`VNP46A3`, `VNP46A4`) and NOAA-20
(`VJ146A3`, `VJ146A4`) products, which share file naming and layout.

## Usage

``` r
ntl_fetch(
  product,
  aoi = NULL,
  start,
  end,
  tiles = NULL,
  token = ntl_token(),
  cache_dir = ntl_cache_dir(),
  overwrite = FALSE,
  timeout = 600,
  retries = 4,
  quiet = FALSE
)
```

## Arguments

- product:

  A product id with `backend == "laads"`, e.g. `"VNP46A3"` or
  `"VJ146A3"` (see
  [`ntl_sources()`](https://iskakovs.github.io/ntlpanel/reference/ntl_sources.md)).

- aoi:

  Area of interest (see
  [`ntl_tiles()`](https://iskakovs.github.io/ntlpanel/reference/ntl_tiles.md)).
  Ignored if `tiles` is given.

- start, end:

  First and last period: `"YYYY"`, `"YYYY-MM"`, `"YYYY-MM-DD"` or a
  `Date`.

- tiles:

  Optional tile ids (see
  [`ntl_tiles()`](https://iskakovs.github.io/ntlpanel/reference/ntl_tiles.md));
  `NULL` counts all tiles.

- token:

  NASA Earthdata bearer token (see
  [`ntl_token()`](https://iskakovs.github.io/ntlpanel/reference/ntl_cache_dir.md)).

- cache_dir:

  Cache directory (see
  [`ntl_cache_dir()`](https://iskakovs.github.io/ntlpanel/reference/ntl_cache_dir.md)).

- overwrite:

  Re-download files that already exist.

- timeout:

  Timeout in seconds for each file.

- retries:

  Maximum attempts per file. LAADS occasionally returns spurious 401
  errors, which are retried.

- quiet:

  Suppress progress messages.

## Value

An `ntl_manifest` data frame with one row per tile and period. Tiles
absent from the archive get `status = "missing"`.

## Details

Files are stored under `cache_dir/<product>/<year>/<doy>/` and are not
downloaded again if a file of the expected size is already there. By
default `cache_dir` is a temporary folder that disappears with the R
session; see
[`ntl_cache_dir()`](https://iskakovs.github.io/ntlpanel/reference/ntl_cache_dir.md)
to keep downloads between sessions. Every download is checked for an
HDF5 signature, which catches the most common failure (an HTML login
page returned because the token is invalid or the LAADS EULA has not
been accepted). The manifest is also written to `cache_dir/manifests/`
with file sizes and MD5 hashes for reproducibility.

Data volume adds up quickly: a monthly tile is roughly 50-130 MB, so
Kazakhstan (10 tiles) costs about 1 GB per month. To process long
monthly series, fetch and extract one year at a time and call
[`ntl_cache_clear()`](https://iskakovs.github.io/ntlpanel/reference/ntl_cache_dir.md)
in between.

## Examples

``` r
if (FALSE) { # interactive() && nzchar(Sys.getenv("EARTHDATA_TOKEN"))
# Annual tiles for Kazakhstan from both satellites (a few GB)
kz <- c(46.4, 40.5, 87.4, 55.5)
m_snpp <- ntl_fetch("VNP46A4", aoi = kz, start = 2018, end = 2025)
m_j01 <- ntl_fetch("VJ146A4", aoi = kz, start = 2018, end = 2025)
}
```
