# Package index

## Find data

- [`ntl_sources()`](https://iskakovs.github.io/ntlpanel/reference/ntl_sources.md)
  : Supported nighttime lights products
- [`ntl_tiles()`](https://iskakovs.github.io/ntlpanel/reference/ntl_tiles.md)
  : Black Marble tiles covering an area of interest
- [`ntl_available()`](https://iskakovs.github.io/ntlpanel/reference/ntl_available.md)
  : Check which periods and tiles are available on NASA LAADS

## Get data

- [`ntl_fetch()`](https://iskakovs.github.io/ntlpanel/reference/ntl_fetch.md)
  : Download Black Marble tiles from NASA LAADS
- [`ntl_files()`](https://iskakovs.github.io/ntlpanel/reference/ntl_files.md)
  : Index nighttime lights files you already have
- [`ntl_cache_dir()`](https://iskakovs.github.io/ntlpanel/reference/ntl_cache_dir.md)
  [`ntl_cache_info()`](https://iskakovs.github.io/ntlpanel/reference/ntl_cache_dir.md)
  [`ntl_cache_clear()`](https://iskakovs.github.io/ntlpanel/reference/ntl_cache_dir.md)
  [`ntl_token()`](https://iskakovs.github.io/ntlpanel/reference/ntl_cache_dir.md)
  : Cache directory, cache management and credentials

## Read and mask

- [`ntl_read()`](https://iskakovs.github.io/ntlpanel/reference/ntl_read.md)
  : Read one period of a manifest as a raster
- [`ntl_read_bm()`](https://iskakovs.github.io/ntlpanel/reference/ntl_read_bm.md)
  : Read a Black Marble HDF5 tile
- [`ntl_mask()`](https://iskakovs.github.io/ntlpanel/reference/ntl_mask.md)
  : Mask low-quality, under-observed and gas-flare pixels

## Extract

- [`ntl_extract()`](https://iskakovs.github.io/ntlpanel/reference/ntl_extract.md)
  : Extract nighttime lights for many periods
- [`ntl_aggregate()`](https://iskakovs.github.io/ntlpanel/reference/ntl_aggregate.md)
  : Zonal statistics with coverage diagnostics

## Build panels

- [`ntl_splice()`](https://iskakovs.github.io/ntlpanel/reference/ntl_splice.md)
  : Splice two sensors into one consistent series
- [`ntl_splice_report()`](https://iskakovs.github.io/ntlpanel/reference/ntl_splice_report.md)
  : Diagnostics of a splice
- [`ntl_panel()`](https://iskakovs.github.io/ntlpanel/reference/ntl_panel.md)
  : Build a balanced, analysis-ready panel
- [`ntl_gapfill()`](https://iskakovs.github.io/ntlpanel/reference/ntl_gapfill.md)
  : Handle missing and low-coverage observations explicitly

## Design variables

- [`ntl_exposure()`](https://iskakovs.github.io/ntlpanel/reference/ntl_exposure.md)
  : Distance-ring treatment exposure
- [`ntl_crosswalk()`](https://iskakovs.github.io/ntlpanel/reference/ntl_crosswalk.md)
  : Crosswalk between two boundary vintages
- [`ntl_apply_crosswalk()`](https://iskakovs.github.io/ntlpanel/reference/ntl_apply_crosswalk.md)
  : Apply a boundary crosswalk to tabular data

## Example data

- [`ntl_example()`](https://iskakovs.github.io/ntlpanel/reference/ntl_example.md)
  : Synthetic example data
