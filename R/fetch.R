#' Check which periods and tiles are available on NASA LAADS
#'
#' Reads the public LAADS file listings for a Black Marble product and
#' counts available tiles per period. Listings are cached in
#' `cache_dir/listings`; listings for the last 180 days are refreshed after
#' seven days because recent periods can still be reprocessed.
#'
#' @param product A product id with `backend == "laads"`, e.g. `"VNP46A3"`
#'   or `"VJ146A3"` (see [ntl_sources()]).
#' @param years Integer vector of years to check.
#' @param tiles Optional tile ids (see [ntl_tiles()]); `NULL` counts all
#'   tiles.
#' @param cache_dir Cache directory (see [ntl_cache_dir()]).
#' @param refresh Re-download listings even if cached.
#' @return A data frame with `product`, `period`, `period_label` and
#'   `n_tiles`.
#' @examplesIf interactive()
#' # Is NOAA-20 monthly data available for Kazakhstan in 2018?
#' kz_tiles <- ntl_tiles(c(46.4, 40.5, 87.4, 55.5))$tile
#' ntl_available("VJ146A3", 2018, tiles = kz_tiles)
#' @export
ntl_available <- function(product, years, tiles = NULL,
                          cache_dir = ntl_cache_dir(), refresh = FALSE) {
  info <- .source_info(product)
  .require_laads(info)
  years <- sort(unique(as.integer(years)))
  periods <- .period_seq(as.character(min(years)), paste0(max(years), "-12"),
                         info$frequency)
  periods <- periods[as.integer(format(periods, "%Y")) %in% years]
  rows <- lapply(periods, function(p) {
    lst <- .laads_listing(product, p, cache_dir, refresh = refresh)
    parsed <- .parse_bm_name(lst$name)
    keep <- parsed$ok
    if (!is.null(tiles)) keep <- keep & parsed$tile %in% tiles
    data.frame(product = product, period = p,
               period_label = .period_label(p, info$frequency),
               n_tiles = sum(keep), stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

#' Download Black Marble tiles from NASA LAADS
#'
#' Downloads the HDF5 tiles of a Black Marble product that cover `aoi` for
#' every period from `start` to `end`, and returns a manifest describing
#' what was fetched. Works for Suomi NPP (`VNP46A3`, `VNP46A4`) and NOAA-20
#' (`VJ146A3`, `VJ146A4`) products, which share file naming and layout.
#'
#' Files are stored under `cache_dir/<product>/<year>/<doy>/` and are not
#' downloaded again if a file of the expected size is already there. By
#' default `cache_dir` is a temporary folder that disappears with the R
#' session; see [ntl_cache_dir()] to keep downloads between sessions. Every
#' download is checked for an HDF5 signature, which catches the most common
#' failure (an HTML login page returned because the token is invalid or the
#' LAADS EULA has not been accepted). The manifest is also written to
#' `cache_dir/manifests/` with file sizes and MD5 hashes for reproducibility.
#'
#' Data volume adds up quickly: a monthly tile is roughly 50-130 MB, so
#' Kazakhstan (10 tiles) costs about 1 GB per month. To process long monthly
#' series, fetch and extract one year at a time and call
#' [ntl_cache_clear()] in between.
#'
#' @inheritParams ntl_available
#' @param aoi Area of interest (see [ntl_tiles()]). Ignored if `tiles` is
#'   given.
#' @param start,end First and last period: `"YYYY"`, `"YYYY-MM"`,
#'   `"YYYY-MM-DD"` or a `Date`.
#' @param token NASA Earthdata bearer token (see [ntl_token()]).
#' @param overwrite Re-download files that already exist.
#' @param timeout Timeout in seconds for each file.
#' @param retries Maximum attempts per file. LAADS occasionally returns
#'   spurious 401 errors, which are retried.
#' @param quiet Suppress progress messages.
#' @return An `ntl_manifest` data frame with one row per tile and period.
#'   Tiles absent from the archive get `status = "missing"`.
#' @examplesIf interactive() && nzchar(Sys.getenv("EARTHDATA_TOKEN"))
#' # Annual tiles for Kazakhstan from both satellites (a few GB)
#' kz <- c(46.4, 40.5, 87.4, 55.5)
#' m_snpp <- ntl_fetch("VNP46A4", aoi = kz, start = 2018, end = 2025)
#' m_j01 <- ntl_fetch("VJ146A4", aoi = kz, start = 2018, end = 2025)
#' @export
ntl_fetch <- function(product, aoi = NULL, start, end, tiles = NULL,
                      token = ntl_token(), cache_dir = ntl_cache_dir(),
                      overwrite = FALSE, timeout = 600, retries = 4,
                      quiet = FALSE) {
  info <- .source_info(product)
  .require_laads(info)
  if (is.null(tiles)) {
    if (is.null(aoi)) .stop("Provide `aoi` or `tiles`.")
    tiles <- ntl_tiles(aoi)$tile
  }
  .note_temporary_cache(cache_dir, quiet)
  periods <- .period_seq(start, end, info$frequency)
  dl <- list(token = token, overwrite = overwrite, timeout = timeout,
             retries = retries, quiet = quiet)
  rows <- lapply(as.list(periods), function(p) {
    .fetch_period(info, p, tiles, cache_dir, dl)
  })
  rows <- do.call(rbind, rows)
  manifest <- .new_manifest(rows)
  if (nrow(manifest) > 0) {
    attr(manifest, "manifest_file") <- .write_manifest(manifest, cache_dir)
  }
  manifest
}

# Internals --------------------------------------------------------------------

# Download all tiles of one period; return manifest rows, including rows for
# tiles absent from the archive.
.fetch_period <- function(info, p, tiles, cache_dir, dl) {
  product <- info$id
  lab <- .period_label(p, info$frequency)
  lst <- .laads_listing(product, p, cache_dir)
  parsed <- .parse_bm_name(lst$name)
  keep <- parsed$ok & parsed$tile %in% tiles
  lst <- lst[keep, , drop = FALSE]
  parsed <- parsed[keep, , drop = FALSE]
  .msg(dl$quiet, product, " ", lab, ": ", nrow(lst), "/", length(tiles),
       " tile(s)")
  base <- data.frame(product = product, series = product,
                     platform = info$platform, frequency = info$frequency,
                     period = p, period_label = lab, stringsAsFactors = FALSE)
  got <- lapply(seq_len(nrow(lst)), function(j) {
    dest <- file.path(cache_dir, product, format(p, "%Y"), format(p, "%j"),
                      lst$name[j])
    status <- .download_one(lst$url[j], dest, dl$token, lst$size[j],
                            dl$overwrite, dl$timeout, dl$retries, dl$quiet)
    cbind(base, data.frame(
      tile = parsed$tile[j], file = normalizePath(dest, winslash = "/"),
      nobs_file = NA_character_, url = lst$url[j],
      size_bytes = file.size(dest), md5 = unname(tools::md5sum(dest)),
      status = status, stringsAsFactors = FALSE
    ))
  })
  missing <- setdiff(tiles, parsed$tile)
  if (length(missing) > 0) {
    got[[length(got) + 1]] <- cbind(base, data.frame(
      tile = missing, file = NA_character_, nobs_file = NA_character_,
      url = NA_character_, size_bytes = NA_real_, md5 = NA_character_,
      status = "missing", stringsAsFactors = FALSE
    ))
  }
  do.call(rbind, got)
}

.require_laads <- function(info) {
  if (!identical(info$backend, "laads")) {
    .stop("Product '", info$id, "' cannot be downloaded by ntlpanel (",
          info$url, "). Download it yourself and index it with ntl_files().")
  }
}

.laads_url <- function(product, period, file = NULL) {
  info <- .source_info(product)
  base <- paste(
    "https://ladsweb.modaps.eosdis.nasa.gov/archive/allData",
    info$laads_collection, product, format(period, "%Y"), format(period, "%j"),
    sep = "/"
  )
  if (is.null(file)) paste0(base, ".csv") else paste0(base, "/", file)
}

.empty_listing <- function() {
  data.frame(name = character(0), size = numeric(0), url = character(0),
             stringsAsFactors = FALSE)
}

.read_listing <- function(path, product, period) {
  lst <- utils::read.csv(path, stringsAsFactors = FALSE)
  if (!"name" %in% names(lst)) {
    .stop("Unexpected LAADS listing format in ", path)
  }
  size <- NA_real_
  if ("size" %in% names(lst)) size <- suppressWarnings(as.numeric(lst$size))
  url <- NA_character_
  if ("downloadsLink" %in% names(lst)) url <- lst$downloadsLink
  rebuilt <- vapply(lst$name, function(f) .laads_url(product, period, f), "")
  url <- ifelse(is.na(url) | !nzchar(url), rebuilt, url)
  data.frame(name = lst$name, size = size, url = unname(url),
             stringsAsFactors = FALSE)
}

.laads_listing <- function(product, period, cache_dir, refresh = FALSE,
                           timeout = 60) {
  dest <- file.path(cache_dir, "listings", product, format(period, "%Y"),
                    paste0(format(period, "%j"), ".csv"))
  recent <- as.numeric(Sys.Date() - period) < 180
  age <- as.numeric(difftime(Sys.time(), file.mtime(dest), units = "days"))
  stale <- file.exists(dest) && recent && age > 7
  if (!file.exists(dest) || isTRUE(refresh) || stale) {
    url <- .laads_url(product, period)
    req <- httr2::request(url)
    req <- httr2::req_timeout(req, timeout)
    req <- httr2::req_retry(req, max_tries = 3)
    req <- httr2::req_error(req, is_error = function(resp) FALSE)
    resp <- httr2::req_perform(req)
    status <- httr2::resp_status(resp)
    if (status == 404) return(.empty_listing())
    if (status >= 400) {
      .stop("LAADS listing request failed (HTTP ", status, "): ", url)
    }
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    writeBin(httr2::resp_body_raw(resp), dest)
  }
  .read_listing(dest, product, period)
}

.is_cached <- function(dest, expected_size, overwrite) {
  if (!file.exists(dest) || isTRUE(overwrite)) return(FALSE)
  size_ok <- is.na(expected_size) || file.size(dest) == expected_size
  size_ok && .is_hdf5(dest)
}

.download_one <- function(url, dest, token, expected_size = NA,
                          overwrite = FALSE, timeout = 600, retries = 4,
                          quiet = FALSE) {
  if (.is_cached(dest, expected_size, overwrite)) return("cached")
  if (!nzchar(token)) ntl_token(required = TRUE)
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(dest, ".part")
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  .msg(quiet, "  downloading ", basename(dest))
  req <- httr2::request(url)
  req <- httr2::req_auth_bearer_token(req, token)
  req <- httr2::req_timeout(req, timeout)
  transient <- function(resp) {
    httr2::resp_status(resp) %in% c(401, 429, 500, 502, 503, 504)
  }
  req <- httr2::req_retry(req, max_tries = retries, is_transient = transient)
  req <- httr2::req_error(req, is_error = function(resp) FALSE)
  resp <- httr2::req_perform(req, path = tmp)
  if (!file.exists(tmp) && is.raw(resp$body)) writeBin(resp$body, tmp)
  .check_download(httr2::resp_status(resp), tmp, dest, url, expected_size)
  if (file.exists(dest)) unlink(dest)
  file.rename(tmp, dest)
  "downloaded"
}

.check_download <- function(status, tmp, dest, url, expected_size) {
  if (status %in% c(401, 403) || (status < 400 && !.is_hdf5(tmp))) {
    .stop(
      "LAADS did not return an HDF5 file for ", basename(dest),
      " (HTTP ", status, "). Check that EARTHDATA_TOKEN is valid and not ",
      "expired, and that the LAADS DAAC data-use agreement is accepted in ",
      "your Earthdata profile."
    )
  }
  if (status >= 400) .stop("Download failed (HTTP ", status, "): ", url)
  if (!is.na(expected_size) && file.size(tmp) != expected_size) {
    .stop("Incomplete download for ", basename(dest), ": expected ",
          expected_size, " bytes, got ", file.size(tmp), ".")
  }
  invisible(TRUE)
}

.parse_bm_name <- function(x) {
  b <- basename(as.character(x))
  rx <- paste0(
    "^([A-Z0-9]+)\\.A([0-9]{4})([0-9]{3})\\.(h[0-9]{2}v[0-9]{2})",
    "\\.([0-9]{3})\\.([0-9]+)\\.h5$"
  )
  ok <- grepl(rx, b)
  get <- function(i) ifelse(ok, sub(rx, paste0("\\", i), b), NA_character_)
  year <- as.integer(get(2))
  doy <- as.integer(get(3))
  period <- as.Date(rep(NA_character_, length(b)))
  period[ok] <- as.Date(paste0(year[ok], "-01-01")) + doy[ok] - 1L
  data.frame(name = b, ok = ok, product = get(1), year = year, doy = doy,
             tile = get(4), version = get(5), period = period,
             stringsAsFactors = FALSE)
}
