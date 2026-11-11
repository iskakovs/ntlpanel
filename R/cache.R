#' Cache directory and credentials
#'
#' `ntl_cache_dir()` returns the directory where downloaded files, LAADS
#' listings and manifests are stored. It is taken, in order, from the
#' `ntlpanel.cache_dir` option, the `NTLPANEL_CACHE` environment variable,
#' or `tools::R_user_dir("ntlpanel", "cache")`.
#'
#' `ntl_token()` returns the NASA Earthdata bearer token from the
#' `EARTHDATA_TOKEN` environment variable. Generate a token at
#' <https://urs.earthdata.nasa.gov> (Generate Token) and store it in
#' `~/.Renviron` as `EARTHDATA_TOKEN=...`; never hard-code it in scripts.
#'
#' `ntl_cache_clear()` deletes the files listed in a manifest, which lets you
#' process large areas period by period without keeping every `.h5` file.
#'
#' @param create Create the directory if it does not exist.
#' @param required If `TRUE`, error when no token is set.
#' @param manifest A manifest returned by [ntl_fetch()] or [ntl_files()].
#' @return `ntl_cache_dir()` returns a path, `ntl_token()` a string (or `""`),
#'   `ntl_cache_clear()` the number of deleted files, invisibly.
#' @examples
#' old <- options(ntlpanel.cache_dir = file.path(tempdir(), "ntl-cache"))
#' ntl_cache_dir()
#' options(old)
#' @export
ntl_cache_dir <- function(create = TRUE) {
  dir <- getOption("ntlpanel.cache_dir", Sys.getenv("NTLPANEL_CACHE", ""))
  if (!nzchar(dir)) dir <- tools::R_user_dir("ntlpanel", which = "cache")
  if (isTRUE(create) && !dir.exists(dir)) dir.create(dir, recursive = TRUE)
  normalizePath(dir, winslash = "/", mustWork = FALSE)
}

#' @rdname ntl_cache_dir
#' @export
ntl_token <- function(required = TRUE) {
  tok <- Sys.getenv("EARTHDATA_TOKEN", "")
  if (!nzchar(tok) && isTRUE(required)) {
    .stop(
      "No NASA Earthdata token found. Create one at https://urs.earthdata.nasa.gov ",
      "(Generate Token), then add EARTHDATA_TOKEN=<token> to ~/.Renviron and ",
      "restart R."
    )
  }
  tok
}

#' @rdname ntl_cache_dir
#' @export
ntl_cache_clear <- function(manifest) {
  .check_cols(manifest, "file", "manifest")
  files <- unique(c(manifest$file, manifest$nobs_file %||% character()))
  files <- files[!is.na(files) & file.exists(files)]
  n <- sum(file.remove(files))
  invisible(n)
}
