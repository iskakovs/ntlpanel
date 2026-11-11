#' Index nighttime lights files you already have
#'
#' Builds a manifest from local files so they can go through
#' [ntl_extract()] like downloaded ones. Use it for products that
#' `ntlpanel` cannot download (EOG VNL composites, harmonized DMSP-VIIRS
#' series) and for Black Marble `.h5` files downloaded elsewhere (for
#' example with blackmarbler's `h5_dir`).
#'
#' Periods, platforms and tiles are parsed from file names:
#' * Black Marble: `VNP46A3.A2023001.h25v03.002.<production>.h5`.
#' * EOG monthly:
#'   `SVDNB_<platform>_<YYYYMMDD>-<YYYYMMDD>_<tile>_...avg_rade9h.tif`.
#'   The matching `...cf_cvg...` file, if present in the same folder, is
#'   used as the observation-count layer. Each platform (`npp`, `j01`)
#'   becomes its own series, e.g. `eog_vnl_monthly_npp`.
#' * EOG annual: `VNL_[v22_]<platform>_<YYYY>_...average_masked...tif`.
#' * Harmonized series: the first four-digit year (1900-2099) in the name.
#'
#' If a name cannot be parsed, pass `period` explicitly.
#'
#' @param paths Files and/or directories. Directories are searched for
#'   files matching the product's `file_pattern` (see [ntl_sources()]).
#' @param product Product id from [ntl_sources()].
#' @param period Optional periods, one per file, overriding the parsed ones.
#' @param series Optional series name overriding the default.
#' @param recursive Search directories recursively.
#' @return An `ntl_manifest` data frame.
#' @examples
#' ex <- ntl_example()
#' m <- ntl_files(ex$dir, "eog_vnl_monthly")
#' table(m$series)
#' @export
ntl_files <- function(paths, product, period = NULL, series = NULL,
                      recursive = TRUE) {
  info <- .source_info(product)
  files <- unlist(lapply(paths, function(p) {
    if (dir.exists(p)) {
      list.files(p, pattern = info$file_pattern, recursive = recursive,
                 full.names = TRUE)
    } else {
      p
    }
  }), use.names = FALSE)
  if (length(files) == 0) {
    .stop("No files matching the '", product, "' naming pattern were found.")
  }
  absent <- files[!file.exists(files)]
  if (length(absent) > 0) {
    .stop("File(s) not found: ", .first_few(absent))
  }
  files <- normalizePath(files, winslash = "/")

  meta <- switch(info$family,
    black_marble = .meta_black_marble(files, product),
    eog_vnl = .meta_eog(files, info),
    .meta_year(files, product)
  )
  if (!is.null(period)) {
    if (length(period) != length(files)) {
      .stop("`period` must have one value per file.")
    }
    meta$period <- .floor_period(.parse_period(period), info$frequency)
  }
  if (anyNA(meta$period)) {
    bad <- basename(files[is.na(meta$period)])
    .stop("Could not parse the period from: ", .first_few(bad),
          ". Pass `period` explicitly.")
  }
  if (!is.null(series)) meta$series <- series
  df <- data.frame(
    product = product, series = meta$series, platform = meta$platform,
    frequency = info$frequency, period = meta$period,
    period_label = .period_label(meta$period, info$frequency),
    tile = meta$tile, file = files, nobs_file = meta$nobs_file,
    url = NA_character_, size_bytes = file.size(files),
    md5 = unname(tools::md5sum(files)), status = "local",
    stringsAsFactors = FALSE
  )
  .new_manifest(df)
}

.meta_black_marble <- function(files, product) {
  p <- .parse_bm_name(files)
  if (!all(p$ok)) {
    .stop("Not Black Marble file names: ",
          .first_few(basename(files[!p$ok])))
  }
  if (any(p$product != product)) {
    .stop("Files belong to product(s) ",
          paste(unique(p$product), collapse = ", "),
          ", not '", product, "'.")
  }
  info <- .source_info(product)
  data.frame(series = product, platform = info$platform, period = p$period,
             tile = p$tile, nobs_file = NA_character_, stringsAsFactors = FALSE)
}

.meta_eog <- function(files, info) {
  b <- basename(files)
  if (info$frequency == "month") {
    rx <- paste0("^SVDNB_([a-z0-9]+)_([0-9]{8})-([0-9]{8})_",
                 "([0-9]{2,3}[NS][0-9]{3}[EW])_.*$")
    ok <- grepl(rx, b)
    token <- ifelse(ok, sub(rx, "\\1", b), NA_character_)
    period <- as.Date(ifelse(ok, sub(rx, "\\2", b), NA_character_),
                      format = "%Y%m%d")
    tile <- ifelse(ok, sub(rx, "\\4", b), NA_character_)
    nobs <- sub("avg_rade9h", "cf_cvg", b, fixed = TRUE)
  } else {
    rx <- "^VNL_(v[0-9]+_)?([a-z0-9-]+)_((19|20)[0-9]{2})_.*$"
    ok <- grepl(rx, b)
    token <- ifelse(ok, sub(rx, "\\2", b), NA_character_)
    yr <- ifelse(ok, sub(rx, "\\3", b), NA_character_)
    period <- as.Date(ifelse(ok, paste0(yr, "-01-01"), NA_character_))
    tile <- NA_character_
    nobs <- sub("average_masked", "cf_cvg", b, fixed = TRUE)
  }
  nobs <- file.path(dirname(files), nobs)
  nobs[!file.exists(nobs) | nobs == files] <- NA_character_
  series <- ifelse(is.na(token), info$id, paste0(info$id, "_", token))
  data.frame(series = series,
             platform = .platform_from_token(token), period = period,
             tile = tile, nobs_file = nobs, stringsAsFactors = FALSE)
}

.meta_year <- function(files, product) {
  b <- basename(files)
  m <- regexpr("(19|20)[0-9]{2}", b)
  yr <- rep(NA_character_, length(b))
  yr[m > 0] <- regmatches(b, m)
  info <- .source_info(product)
  data.frame(series = product, platform = info$platform,
             period = as.Date(ifelse(is.na(yr), NA_character_,
                                     paste0(yr, "-01-01"))),
             tile = NA_character_, nobs_file = NA_character_,
             stringsAsFactors = FALSE)
}
