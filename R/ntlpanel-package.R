#' ntlpanel: Nighttime Lights to Analysis-Ready Panels for Econometrics
#'
#' `ntlpanel` turns nighttime lights rasters into balanced unit-by-period
#' panels whose every row says how much of the unit was actually observed.
#'
#' The workflow has five steps:
#'
#' 1. **Find or fetch data.** [ntl_sources()] lists supported products.
#'    [ntl_fetch()] downloads NASA Black Marble tiles (Suomi NPP `VNP46A3/A4`
#'    and NOAA-20 `VJ146A3/A4`) into a cache. [ntl_files()] indexes files
#'    you already have (EOG VNL composites, harmonized DMSP-VIIRS series,
#'    Black Marble `.h5` files). Both return a *manifest*.
#' 2. **Extract.** [ntl_extract()] reads one period at a time, applies
#'    quality, coverage and gas-flare masks ([ntl_mask()]) and computes
#'    zonal statistics with coverage diagnostics ([ntl_aggregate()]).
#' 3. **Splice sensors.** [ntl_splice()] puts Suomi NPP and NOAA-20 (or any
#'    two series) on one scale and reports level shifts per unit.
#' 4. **Build the panel.** [ntl_panel()] balances the unit x period grid and
#'    adds transforms and time indices. [ntl_gapfill()] applies explicit
#'    rules to missing or low-coverage cells, such as the summer stray-light
#'    gaps at high latitudes.
#' 5. **Add design variables.** [ntl_exposure()] assigns distance rings and
#'    first-treatment dates. [ntl_crosswalk()] and [ntl_apply_crosswalk()]
#'    move tabular data between boundary vintages.
#'
#' @keywords internal
"_PACKAGE"
