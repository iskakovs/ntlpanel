# Cache directory, cache management and credentials

`ntl_cache_dir()` returns the folder where downloaded tiles, LAADS
listings and manifests are stored. By default this is a temporary folder
that is deleted when the R session ends, so nothing is left on disk
unless you ask for it. To keep downloads between sessions, set a
permanent folder in one of two ways:

- add `NTLPANEL_CACHE=/path/to/folder` to `~/.Renviron`
  (`tools::R_user_dir("ntlpanel", "cache")` is a good choice), or

- set `options(ntlpanel.cache_dir = "/path/to/folder")` in a script.

## Usage

``` r
ntl_cache_dir(create = TRUE)

ntl_cache_info(cache_dir = ntl_cache_dir(create = FALSE))

ntl_cache_clear(
  manifest = NULL,
  all = FALSE,
  cache_dir = ntl_cache_dir(create = FALSE)
)

ntl_token(required = TRUE)
```

## Arguments

- create:

  Create the directory if it does not exist.

- cache_dir:

  Cache directory to inspect or clear.

- manifest:

  A manifest returned by
  [`ntl_fetch()`](https://iskakovs.github.io/ntlpanel/reference/ntl_fetch.md)
  or
  [`ntl_files()`](https://iskakovs.github.io/ntlpanel/reference/ntl_files.md).

- all:

  Delete everything in the cache directory.

- required:

  If `TRUE`, error when no token is set.

## Value

`ntl_cache_dir()` returns a path. `ntl_cache_info()` returns a one-row
data frame with `path`, `n_files` and `size_mb`. `ntl_cache_clear()`
returns the number of deleted files, invisibly. `ntl_token()` returns
the token as a string (`""` if unset and `required = FALSE`).

## Details

`ntl_cache_info()` reports how much space the cache uses.
`ntl_cache_clear()` deletes the files listed in a manifest, which lets
you process large areas period by period without keeping every `.h5`
file, or with `all = TRUE` empties the whole cache.

`ntl_token()` returns the NASA Earthdata bearer token from the
`EARTHDATA_TOKEN` environment variable. Generate a token at
<https://urs.earthdata.nasa.gov> (Generate Token) and store it in
`~/.Renviron` as `EARTHDATA_TOKEN=...`; never hard-code it in scripts.

## Examples

``` r
old <- options(ntlpanel.cache_dir = file.path(tempdir(), "ntl-cache"))
ntl_cache_dir()
#> [1] "/tmp/RtmpgmloQt/ntl-cache"
ntl_cache_info()
#>                        path n_files size_mb
#> 1 /tmp/RtmpgmloQt/ntl-cache       0       0
ntl_cache_clear(all = TRUE)
options(old)
```
