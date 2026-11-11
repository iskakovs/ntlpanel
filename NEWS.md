# ntlpanel (development version)

* `ntl_read_bm()` now reads Black Marble tiles with hdf5r instead of GDAL.
  Recent GDAL versions return these grids upside down, which flipped tiles
  on R 4.5 and 4.6. hdf5r moves from Suggests to Imports. Fill values,
  `scale_factor` and `add_offset` are taken from the dataset attributes.
* Downloads now go to a temporary folder by default; set `NTLPANEL_CACHE` or
  the `ntlpanel.cache_dir` option to keep them between sessions.
* New `ntl_cache_info()`; `ntl_cache_clear(all = TRUE)` empties the cache.
* A small example Black Marble tile ships in `inst/extdata`, so
  `ntl_read_bm()` has a runnable example.
* Examples that need the internet or a token use `@examplesIf` instead of
  `\dontrun{}`.
* Internal refactoring of `ntl_fetch()`, `ntl_splice()`, `ntl_gapfill()`,
  `ntl_mask()` and `ntl_crosswalk()` into smaller helpers; code follows an
  80-character line limit.
* Added `CITATION`, contributing guidelines, a pkgdown configuration and
  GitHub Actions workflows (R CMD check, pkgcheck, pkgdown, coverage).

# ntlpanel 0.1.0

First version.

* Data access: `ntl_sources()`, `ntl_tiles()`, `ntl_available()`, `ntl_fetch()`
  (NASA Black Marble `VNP46A3/A4` and NOAA-20 `VJ146A3/A4` from LAADS, with
  caching, integrity checks and manifests), `ntl_files()` (EOG VNL monthly and
  annual composites, harmonized DMSP-VIIRS series, local Black Marble files).
* Reading and masking: `ntl_read_bm()` (with tile orientation checks),
  `ntl_read()`, `ntl_mask()` (quality flags, minimum observations, gas flares,
  top-coding).
* Extraction: `ntl_aggregate()` and `ntl_extract()` with coverage diagnostics
  (`share_valid`, `share_masked`, `mean_obs`).
* Panels: `ntl_panel()`, `ntl_gapfill()` (interpolation, seasonal fill, drop;
  stray-light risk flags), `ntl_splice()` and `ntl_splice_report()`.
* Design variables: `ntl_exposure()`, `ntl_crosswalk()`, `ntl_apply_crosswalk()`.
* `ntl_example()` writes synthetic data for examples, tests and the vignette.
* `inst/scripts/validate_splice_kz.R` checks the Suomi NPP to NOAA-20 splice
  for Kazakhstan.
