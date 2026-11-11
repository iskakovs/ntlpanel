# Contributing to ntlpanel

Thank you for helping improve ntlpanel. Bug reports, data-source
requests, documentation fixes and code contributions are all welcome.

## Reporting a problem

Open an issue at <https://github.com/iskakovs/ntlpanel/issues> with:

- what you ran (a minimal reproducible example; the `reprex` package
  helps),
- what you expected and what happened,
- the output of
  [`sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html) and
  [`terra::gdal()`](https://rspatial.github.io/terra/reference/gdal.html),
- the product id and period (for example `VJ146A3`, `2024-06`) if the
  problem concerns a specific data file.

Never paste your NASA Earthdata token into an issue.

## Proposing a change

1.  Open an issue first for anything larger than a typo, so we can agree
    on the approach.
2.  Fork the repository and create a branch from `main`.
3.  Follow the existing style: snake_case names, lines of at most 80
    characters, roxygen2 documentation with an example and a `@return`
    for every exported function.
4.  Add tests with testthat. Tests must run offline: use the fixtures in
    `tests/testthat/helper-fixtures.R` or
    [`httr2::with_mocked_responses()`](https://httr2.r-lib.org/reference/with_mocked_responses.html)
    for anything that would download data.
5.  Run `devtools::document()`, `devtools::test()` and
    `devtools::check()` before opening the pull request, and add a line
    to `NEWS.md`.

## Code of conduct

Please note that this project is released with a Contributor Code of
Conduct. By contributing to this project you agree to abide by its
terms. If the package is accepted by rOpenSci, the [rOpenSci Code of
Conduct](https://ropensci.org/code-of-conduct/) applies.
