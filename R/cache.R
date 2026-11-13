#' Cache directory, cache management and credentials
#'
#' `ntl_cache_dir()` returns the folder where downloaded tiles, LAADS
#' listings and manifests are stored. By default this is a temporary folder
#' that is deleted when the R session ends, so nothing is left on disk
#' unless you ask for it. To keep downloads between sessions, set a
#' permanent folder in one of two ways:
#' * add `NTLPANEL_CACHE=/path/to/folder` to `~/.Renviron`
#'   (`tools::R_user_dir("ntlpanel", "cache")` is a good choice), or
#' * set `options(ntlpanel.cache_dir = "/path/to/folder")` in a script.
#'
#' `ntl_cache_info()` reports how much space the cache uses.
#' `ntl_cache_clear()` deletes the files listed in a manifest, which lets
#' you process large areas period by period without keeping every `.h5`
#' file, or with `all = TRUE` empties the whole cache.
#'
#' `ntl_token()` returns the NASA Earthdata bearer token from the
#' `EARTHDATA_TOKEN` environment variable. Store it in `~/.Renviron` as
#' `EARTHDATA_TOKEN=...` (no quotes, no `Bearer` prefix) and never
#' hard-code it in scripts. A token alone is not enough for LAADS; once per
#' account:
#' 1. At <https://urs.earthdata.nasa.gov/users>, complete the profile,
#'    including Study Area, User Type and Organization.
#' 2. Under EULAs, Accept New EULAs, accept the MERIS and Sentinel EULAs.
#' 3. Log in at <https://ladsweb.modaps.eosdis.nasa.gov> with your
#'    Earthdata account and click Authorize when asked.
#' 4. Generate a token (Generate Token) after these steps.
#'
#' If downloads return a login page instead of data, one of these steps is
#' missing.
#'
#' @param create Create the directory if it does not exist.
#' @param manifest A manifest returned by [ntl_fetch()] or [ntl_files()].
#' @param all Delete everything in the cache directory.
#' @param cache_dir Cache directory to inspect or clear.
#' @param required If `TRUE`, error when no token is set.
#' @return `ntl_cache_dir()` returns a path. `ntl_cache_info()` returns a
#'   one-row data frame with `path`, `n_files` and `size_mb`.
#'   `ntl_cache_clear()` returns the number of deleted files, invisibly.
#'   `ntl_token()` returns the token as a string (`""` if unset and
#'   `required = FALSE`).
#' @examples
#' old <- options(ntlpanel.cache_dir = file.path(tempdir(), "ntl-cache"))
#' ntl_cache_dir()
#' ntl_cache_info()
#' ntl_cache_clear(all = TRUE)
#' options(old)
#' @export
ntl_cache_dir <- function(create = TRUE) {
  dir <- getOption("ntlpanel.cache_dir", Sys.getenv("NTLPANEL_CACHE", ""))
  if (!nzchar(dir)) dir <- file.path(tempdir(), "ntlpanel-cache")
  if (isTRUE(create) && !dir.exists(dir)) dir.create(dir, recursive = TRUE)
  normalizePath(dir, winslash = "/", mustWork = FALSE)
}

#' @rdname ntl_cache_dir
#' @export
ntl_cache_info <- function(cache_dir = ntl_cache_dir(create = FALSE)) {
  files <- if (dir.exists(cache_dir)) {
    list.files(cache_dir, recursive = TRUE, full.names = TRUE)
  } else {
    character(0)
  }
  data.frame(path = cache_dir, n_files = length(files),
             size_mb = round(sum(file.size(files)) / 1024^2, 1),
             stringsAsFactors = FALSE)
}

#' @rdname ntl_cache_dir
#' @export
ntl_cache_clear <- function(manifest = NULL, all = FALSE,
                            cache_dir = ntl_cache_dir(create = FALSE)) {
  if (isTRUE(all)) {
    files <- if (dir.exists(cache_dir)) {
      list.files(cache_dir, recursive = TRUE, full.names = TRUE)
    } else {
      character(0)
    }
    n <- length(files)
    unlink(cache_dir, recursive = TRUE)
    return(invisible(n))
  }
  if (is.null(manifest)) .stop("Pass a `manifest`, or use `all = TRUE`.")
  .check_cols(manifest, "file", "manifest")
  files <- unique(c(manifest$file, manifest$nobs_file %||% character()))
  files <- files[!is.na(files) & file.exists(files)]
  invisible(sum(file.remove(files)))
}

#' @rdname ntl_cache_dir
#' @export
ntl_token <- function(required = TRUE) {
  tok <- Sys.getenv("EARTHDATA_TOKEN", "")
  if (!nzchar(tok) && isTRUE(required)) {
    .stop(
      "No NASA Earthdata token found. Create one at ",
      "https://urs.earthdata.nasa.gov (Generate Token), then add ",
      "EARTHDATA_TOKEN=<token> to ~/.Renviron and restart R. ",
      "See ?ntl_token for the one-time account setup LAADS requires."
    )
  }
  tok
}

.ntl_state <- new.env(parent = emptyenv())

# Tell the user once per session that downloads go to a temporary folder.
.note_temporary_cache <- function(cache_dir, quiet = FALSE) {
  tmp <- normalizePath(tempdir(), winslash = "/", mustWork = FALSE)
  in_tmp <- startsWith(normalizePath(cache_dir, winslash = "/",
                                     mustWork = FALSE), tmp)
  if (in_tmp && !isTRUE(.ntl_state$noted) && !isTRUE(quiet)) {
    message(
      "Downloads are stored in a temporary folder and deleted when R ",
      "closes. Set NTLPANEL_CACHE in ~/.Renviron to keep them ",
      "(see ?ntl_cache_dir)."
    )
    .ntl_state$noted <- TRUE
  }
  invisible(in_tmp)
}
