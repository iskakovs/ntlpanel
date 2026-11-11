#' Supported nighttime lights products
#'
#' Returns the registry of products that `ntlpanel` can fetch or read, with
#' the metadata the rest of the package relies on: temporal frequency,
#' resolution, the layers holding values, observation counts and quality
#' flags, access method and caveats.
#'
#' Products with `backend == "laads"` can be downloaded with [ntl_fetch()]
#' (a NASA Earthdata token is required). Products with `backend == "local"`
#' must be downloaded by the user (EOG requires a free account; the
#' harmonized series are distributed through figshare, Harvard Dataverse or
#' GitHub) and are indexed with [ntl_files()]. Black Marble products can also
#' be read from local `.h5` files with [ntl_files()].
#'
#' URL patterns and file-name conventions are kept in this single registry so
#' that a change upstream needs only one fix.
#'
#' @param id Optional product id(s) to return. `NULL` returns all.
#' @return A data frame with one row per product and these columns:
#' \describe{
#'   \item{id}{Product identifier used throughout the package.}
#'   \item{family}{`black_marble`, `eog_vnl` or `harmonized`.}
#'   \item{platform}{Satellite platform(s).}
#'   \item{frequency}{`month` or `year`.}
#'   \item{resolution_arcsec}{Nominal pixel size in arc-seconds.}
#'   \item{start, end}{First and last period known to the registry
#'     (`NA` = check availability; see [ntl_available()]).}
#'   \item{backend}{`laads` (downloadable) or `local`.}
#'   \item{laads_collection}{LAADS archive collection number.}
#'   \item{value_layer, nobs_layer, quality_layer}{HDF5 dataset names
#'     (Black Marble) or file-name tokens (EOG).}
#'   \item{units}{Units of the value layer.}
#'   \item{file_pattern}{Regular expression matching product files.}
#'   \item{url}{Where the data live.}
#'   \item{notes}{Caveats that matter for panel construction.}
#' }
#' @examples
#' ntl_sources()
#' ntl_sources("VJ146A3")[, c("id", "platform", "frequency", "notes")]
#' @export
ntl_sources <- function(id = NULL) {
  reg <- .registry()
  if (!is.null(id)) {
    bad <- setdiff(id, reg$id)
    if (length(bad) > 0) {
      .stop("Unknown product id(s): ", paste(bad, collapse = ", "),
            ". See ntl_sources()$id.")
    }
    reg <- reg[match(id, reg$id), , drop = FALSE]
  }
  rownames(reg) <- NULL
  reg
}

.source_info <- function(id) {
  if (length(id) != 1) .stop("Exactly one product id is required.")
  ntl_sources(id)
}

.bm_row <- function(id, platform, frequency, start, end, notes) {
  list(
    id = id, family = "black_marble", platform = platform,
    frequency = frequency, resolution_arcsec = 15,
    start = start, end = end, backend = "laads", laads_collection = "5200",
    value_layer = "NearNadir_Composite_Snow_Free",
    nobs_layer = "NearNadir_Composite_Snow_Free_Num",
    quality_layer = "NearNadir_Composite_Snow_Free_Quality",
    units = "nW/cm2/sr",
    file_pattern = paste0(
      "^", id, "\\.A[0-9]{7}\\.h[0-9]{2}v[0-9]{2}\\..*\\.h5$"
    ),
    url = paste0(
      "https://ladsweb.modaps.eosdis.nasa.gov/archive/allData/5200/", id, "/"
    ),
    notes = notes
  )
}

.registry <- function() {
  snpp_note <- paste(
    "Suomi NPP. NOAA ended Suomi NPP data delivery on 2026-11-02;",
    "splice onto the NOAA-20 product for later periods (see ntl_splice())."
  )
  j01_note <- paste(
    "NOAA-20. Same file naming and HDF5 layout as the Suomi NPP product.",
    "Check the first available period with ntl_available()."
  )
  rows <- list(
    .bm_row("VNP46A3", "SNPP", "month", "2012-01", "2026-10", snpp_note),
    .bm_row("VNP46A4", "SNPP", "year", "2012", "2025", snpp_note),
    .bm_row("VJ146A3", "NOAA-20", "month", NA, NA, j01_note),
    .bm_row("VJ146A4", "NOAA-20", "year", NA, NA, j01_note),
    list(
      id = "eog_vnl_monthly", family = "eog_vnl",
      platform = "SNPP (npp), NOAA-20 (j01); parsed from file name",
      frequency = "month", resolution_arcsec = 15, start = "2012-04", end = NA,
      backend = "local", laads_collection = NA,
      value_layer = "avg_rade9h", nobs_layer = "cf_cvg", quality_layer = NA,
      units = "nW/cm2/sr",
      file_pattern = "^SVDNB_[a-z0-9]+_[0-9]{8}-[0-9]{8}_.*avg_rade9h.*\\.tif$",
      url = "https://eogdata.mines.edu/products/vnl/",
      notes = paste(
        "Download requires a free EOG account. Prefer the stray-light",
        "corrected",
        "'vcmslcfg' files at high latitude; matching 'cf_cvg' files give",
        "cloud-free observation counts and are picked up automatically."
      )
    ),
    list(
      id = "eog_vnl_annual", family = "eog_vnl",
      platform = "SNPP (npp), NOAA-20 (j01); parsed from file name",
      frequency = "year", resolution_arcsec = 15, start = "2012", end = NA,
      backend = "local", laads_collection = NA,
      value_layer = "average_masked", nobs_layer = "cf_cvg", quality_layer = NA,
      units = "nW/cm2/sr",
      file_pattern = "^VNL_.*(19|20)[0-9]{2}.*average_masked.*\\.tif$",
      url = "https://eogdata.mines.edu/products/vnl/",
      notes = paste(
        "Annual VNL composites. Download requires a free EOG account.",
        "Check EOG documentation for the stray-light configuration used."
      )
    ),
    list(
      id = "dmsp_viirs_li", family = "harmonized",
      platform = "DMSP + SNPP (harmonized to DMSP scale)",
      frequency = "year", resolution_arcsec = 30, start = "1992", end = NA,
      backend = "local", laads_collection = NA,
      value_layer = "DN", nobs_layer = NA, quality_layer = NA,
      units = "DN (0-63)",
      file_pattern = "^Harmonized_DN_NTL_(19|20)[0-9]{2}_.*\\.tif$",
      url = "https://doi.org/10.6084/m9.figshare.9828827",
      notes = paste(
        "Li, Zhou, Zhao and Zhao (2020, Scientific Data). The authors suggest",
        "using pixels with DN > 7. DMSP-scale values are top-coded at 63."
      )
    ),
    list(
      id = "viirs_like_chen", family = "harmonized",
      platform = "DMSP + SNPP (harmonized to VIIRS scale)",
      frequency = "year", resolution_arcsec = 15, start = "2000", end = NA,
      backend = "local", laads_collection = NA,
      value_layer = "radiance", nobs_layer = NA, quality_layer = NA,
      units = "nW/cm2/sr (VIIRS-like)",
      file_pattern = "(19|20)[0-9]{2}.*\\.tif$",
      url = "https://doi.org/10.7910/DVN/YGIVCD",
      notes = paste(
        "Chen et al. (2021, Earth System Science Data) extended NPP-VIIRS-like",
        "series. File names vary by release; pass `period` to ntl_files() if",
        "the year cannot be parsed."
      )
    ),
    list(
      id = "world_nightlights_regan", family = "harmonized",
      platform = "DMSP + SNPP (corrected)",
      frequency = "year", resolution_arcsec = NA, start = "1992", end = NA,
      backend = "local", laads_collection = NA,
      value_layer = "radiance", nobs_layer = NA, quality_layer = NA,
      units = "see source documentation",
      file_pattern = "(19|20)[0-9]{2}.*\\.tif$",
      url = "https://github.com/tannerregan/world_nightlights",
      notes = paste(
        "Corrected for blooming, top-coding and cross-sensor calibration.",
        "For post-2013-only analyses the authors recommend VIIRS directly."
      )
    )
  )
  out <- do.call(rbind, lapply(rows, function(r) {
    as.data.frame(r, stringsAsFactors = FALSE)
  }))
  out$resolution_arcsec <- as.numeric(out$resolution_arcsec)
  out
}

.platform_from_token <- function(token) {
  map <- c(npp = "SNPP", j01 = "NOAA-20", j02 = "NOAA-21")
  out <- unname(map[tolower(token)])
  out[is.na(out)] <- token[is.na(out)]
  out
}
