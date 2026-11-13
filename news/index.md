# Changelog

## ntlpanel (development version)

- [`ntl_fetch()`](https://iskakovs.github.io/ntlpanel/reference/ntl_fetch.md)
  and
  [`ntl_available()`](https://iskakovs.github.io/ntlpanel/reference/ntl_available.md)
  now retry dropped connections and timeouts (`httr2_failure`), not only
  HTTP error responses. A long download no longer stops on a single
  “Connection was reset”; if all attempts fail, the error says that
  running the call again resumes.

- Once a download has worked in a session, an HTTP 401 from LAADS is
  treated as a temporary refusal: it is retried for up to about 15
  minutes and the error no longer blames the token.

- [`?ntl_token`](https://iskakovs.github.io/ntlpanel/reference/ntl_cache_dir.md)
  describes the one-time Earthdata account setup LAADS needs (complete
  profile, accepted EULAs, LAADS authorized), and the token error points
  to it.

- `inst/scripts/validate_splice_kz.R`: a reliable orientation check
  (city light vs. mirrored boxes), parallel downloads (`WORKERS`), tile
  and year subsets (`TILES`, `MONTHLY_TILES`, `ANNUAL_YEARS`), and
  resumable runs that skip files LAADS keeps refusing instead of
  stopping. It no longer prints the token when run with `Rscript`.

- [`ntl_read_bm()`](https://iskakovs.github.io/ntlpanel/reference/ntl_read_bm.md)
  now reads Black Marble tiles with hdf5r instead of GDAL. Recent GDAL
  versions return these grids upside down, which flipped tiles on R 4.5
  and 4.6. hdf5r moves from Suggests to Imports. Fill values,
  `scale_factor` and `add_offset` are taken from the dataset attributes.

- Downloads now go to a temporary folder by default; set
  `NTLPANEL_CACHE` or the `ntlpanel.cache_dir` option to keep them
  between sessions.

- New
  [`ntl_cache_info()`](https://iskakovs.github.io/ntlpanel/reference/ntl_cache_dir.md);
  `ntl_cache_clear(all = TRUE)` empties the cache.

- A small example Black Marble tile ships in `inst/extdata`, so
  [`ntl_read_bm()`](https://iskakovs.github.io/ntlpanel/reference/ntl_read_bm.md)
  has a runnable example.

- Examples that need the internet or a token use `@examplesIf` instead
  of `\dontrun{}`.

- Internal refactoring of
  [`ntl_fetch()`](https://iskakovs.github.io/ntlpanel/reference/ntl_fetch.md),
  [`ntl_splice()`](https://iskakovs.github.io/ntlpanel/reference/ntl_splice.md),
  [`ntl_gapfill()`](https://iskakovs.github.io/ntlpanel/reference/ntl_gapfill.md),
  [`ntl_mask()`](https://iskakovs.github.io/ntlpanel/reference/ntl_mask.md)
  and
  [`ntl_crosswalk()`](https://iskakovs.github.io/ntlpanel/reference/ntl_crosswalk.md)
  into smaller helpers; code follows an 80-character line limit.

- Added `CITATION`, contributing guidelines, a pkgdown configuration and
  GitHub Actions workflows (R CMD check, pkgcheck, pkgdown, coverage).

## ntlpanel 0.1.0

First version.

- Data access:
  [`ntl_sources()`](https://iskakovs.github.io/ntlpanel/reference/ntl_sources.md),
  [`ntl_tiles()`](https://iskakovs.github.io/ntlpanel/reference/ntl_tiles.md),
  [`ntl_available()`](https://iskakovs.github.io/ntlpanel/reference/ntl_available.md),
  [`ntl_fetch()`](https://iskakovs.github.io/ntlpanel/reference/ntl_fetch.md)
  (NASA Black Marble `VNP46A3/A4` and NOAA-20 `VJ146A3/A4` from LAADS,
  with caching, integrity checks and manifests),
  [`ntl_files()`](https://iskakovs.github.io/ntlpanel/reference/ntl_files.md)
  (EOG VNL monthly and annual composites, harmonized DMSP-VIIRS series,
  local Black Marble files).
- Reading and masking:
  [`ntl_read_bm()`](https://iskakovs.github.io/ntlpanel/reference/ntl_read_bm.md)
  (with tile orientation checks),
  [`ntl_read()`](https://iskakovs.github.io/ntlpanel/reference/ntl_read.md),
  [`ntl_mask()`](https://iskakovs.github.io/ntlpanel/reference/ntl_mask.md)
  (quality flags, minimum observations, gas flares, top-coding).
- Extraction:
  [`ntl_aggregate()`](https://iskakovs.github.io/ntlpanel/reference/ntl_aggregate.md)
  and
  [`ntl_extract()`](https://iskakovs.github.io/ntlpanel/reference/ntl_extract.md)
  with coverage diagnostics (`share_valid`, `share_masked`, `mean_obs`).
- Panels:
  [`ntl_panel()`](https://iskakovs.github.io/ntlpanel/reference/ntl_panel.md),
  [`ntl_gapfill()`](https://iskakovs.github.io/ntlpanel/reference/ntl_gapfill.md)
  (interpolation, seasonal fill, drop; stray-light risk flags),
  [`ntl_splice()`](https://iskakovs.github.io/ntlpanel/reference/ntl_splice.md)
  and
  [`ntl_splice_report()`](https://iskakovs.github.io/ntlpanel/reference/ntl_splice_report.md).
- Design variables:
  [`ntl_exposure()`](https://iskakovs.github.io/ntlpanel/reference/ntl_exposure.md),
  [`ntl_crosswalk()`](https://iskakovs.github.io/ntlpanel/reference/ntl_crosswalk.md),
  [`ntl_apply_crosswalk()`](https://iskakovs.github.io/ntlpanel/reference/ntl_apply_crosswalk.md).
- [`ntl_example()`](https://iskakovs.github.io/ntlpanel/reference/ntl_example.md)
  writes synthetic data for examples, tests and the vignette.
- `inst/scripts/validate_splice_kz.R` checks the Suomi NPP to NOAA-20
  splice for Kazakhstan.
