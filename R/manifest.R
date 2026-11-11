# Manifest helpers -------------------------------------------------------------
#
# A manifest is a data frame with one row per file (or per missing tile) and
# the columns below. ntl_fetch() and ntl_files() both return one, and
# ntl_extract() consumes it.

.manifest_cols <- c(
  "product", "series", "platform", "frequency", "period", "period_label",
  "tile", "file", "nobs_file", "url", "size_bytes", "md5", "status"
)

.new_manifest <- function(df) {
  if (is.null(df) || nrow(df) == 0) {
    df <- as.data.frame(stats::setNames(
      replicate(length(.manifest_cols), logical(0), simplify = FALSE),
      .manifest_cols
    ))
    df$period <- as.Date(character(0))
  }
  for (col in setdiff(.manifest_cols, names(df))) df[[col]] <- NA
  df <- df[, .manifest_cols, drop = FALSE]
  df$period <- as.Date(df$period)
  df <- df[order(df$series, df$period, df$tile), , drop = FALSE]
  rownames(df) <- NULL
  class(df) <- c("ntl_manifest", "data.frame")
  df
}

#' @export
print.ntl_manifest <- function(x, ...) {
  y <- x
  class(y) <- "data.frame"
  n_files <- sum(!is.na(y$file))
  n_missing <- sum(y$status %in% "missing")
  rng <- if (nrow(y) > 0) range(y$period) else as.Date(c(NA, NA))
  cat("<ntl_manifest> ", n_files, " file(s), ", length(unique(y$series)),
      " series, periods ", format(rng[1]), " to ", format(rng[2]), sep = "")
  if (n_missing > 0) cat(", ", n_missing, " missing tile-period(s)", sep = "")
  cat("\n")
  show <- utils::head(y[, c("series", "period_label", "tile", "status", "file")], 10)
  show$file <- basename(show$file)
  print(show, row.names = FALSE)
  if (nrow(y) > 10) cat("... ", nrow(y) - 10, " more row(s)\n", sep = "")
  invisible(x)
}

.write_manifest <- function(manifest, cache_dir) {
  dir <- file.path(cache_dir, "manifests")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  stamp <- format(Sys.time(), "%Y%m%dT%H%M%S")
  rng <- range(manifest$period)
  name <- sprintf("%s_%s_%s_%s.csv", paste(unique(manifest$product), collapse = "-"),
                  format(rng[1], "%Y%m"), format(rng[2], "%Y%m"), stamp)
  path <- file.path(dir, name)
  out <- manifest
  class(out) <- "data.frame"
  utils::write.csv(out, path, row.names = FALSE)
  path
}

.is_hdf5 <- function(path) {
  if (!file.exists(path) || file.size(path) < 8) return(FALSE)
  sig <- readBin(path, what = "raw", n = 8)
  identical(sig, as.raw(c(0x89, 0x48, 0x44, 0x46, 0x0d, 0x0a, 0x1a, 0x0a)))
}
