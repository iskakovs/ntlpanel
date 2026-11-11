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
