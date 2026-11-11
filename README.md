# ntlpanel

**Nighttime lights to analysis-ready panels for econometrics.**

`ntlpanel` turns nighttime lights rasters into balanced unit-by-period panels.
Every observation records how much of the unit was actually observed. The
steps that usually happen silently in a script become explicit and recorded:

- **Sensor continuity.** NOAA ended Suomi NPP data delivery on 2 November 2026.
  `ntl_splice()` puts Suomi NPP (`VNP46`) and NOAA-20 (`VJ146`) on one scale
  and reports level shifts per unit, optionally per calendar month.
- **Coverage.** `ntl_extract()` reports `share_valid`, `share_masked` and
  `mean_obs` for each unit and period, and keeps "dark" (0) separate from
  "unobserved" (`NA`). `ntl_gapfill()` applies a documented rule to
  high-latitude summer gaps and flags the cells at risk.
- **Units and design.** `ntl_crosswalk()` moves official statistics between
  boundary vintages, for example Kazakhstan's 2022 regions.
  `ntl_exposure()` assigns distance rings and first-treatment dates for
  staggered difference-in-differences designs.

## Installation

```r
# From the source tarball
install.packages("ntlpanel_0.1.0.tar.gz", repos = NULL, type = "source")
```

The package depends on `terra`, `sf`, `exactextractr` and `httr2`. Reading
Black Marble `.h5` files needs a GDAL build with HDF5 support, which the CRAN
binaries of `terra` include. The optional `hdf5r` package lets
`ntl_read_bm()` check tile orientation automatically.

## Quick start (offline, synthetic data)

```r
library(ntlpanel)
ex <- ntl_example()                               # synthetic files + polygons

m    <- ntl_files(ex$dir, "eog_vnl_monthly")      # manifest of local files
long <- ntl_extract(m, ex$units_old, id_col = "district", min_obs = 2)
sp   <- ntl_splice(long, from = "eog_vnl_monthly_npp", to = "eog_vnl_monthly_j01")
ntl_splice_report(sp)                             # level shift per district

p <- ntl_panel(sp, min_share_valid = 0.5)         # balanced, log1p outcome, t index
p <- ntl_gapfill(p, rule = "interp", units = ex$units_old, lat_threshold = 49)

e <- ntl_exposure(ex$units_old, ex$sites, rings = c(50, 100, 200),
                  id_col = "district", site_time_col = "start")
```

## Real data: Black Marble for Kazakhstan

```r
# One-off: put your NASA Earthdata token in ~/.Renviron as EARTHDATA_TOKEN=...
regions <- sf::st_read("kz_adm1_2022.gpkg")
ntl_tiles(regions)                                # h22-h26 x v03-v04

m_snpp <- ntl_fetch("VNP46A4", aoi = regions, start = 2014, end = 2025)
m_j01  <- ntl_fetch("VJ146A4", aoi = regions, start = 2018, end = 2025)
long   <- ntl_extract(rbind(m_snpp, m_j01), regions, id_col = "region")
sp     <- ntl_splice(long, from = "VNP46A4", to = "VJ146A4")
p      <- ntl_panel(sp)
```

For monthly data, fetch and extract one year at a time and call
`ntl_cache_clear()` in between. A monthly tile is about 50-130 MB.

## Functions

| Step | Functions |
|---|---|
| Find data | `ntl_sources()`, `ntl_tiles()`, `ntl_available()` |
| Get data | `ntl_fetch()` (LAADS: VNP46A3/A4, VJ146A3/A4), `ntl_files()` (EOG VNL, harmonized series, local `.h5`) |
| Read and mask | `ntl_read()`, `ntl_read_bm()`, `ntl_mask()` |
| Extract | `ntl_extract()`, `ntl_aggregate()` |
| Panel | `ntl_splice()`, `ntl_splice_report()`, `ntl_panel()`, `ntl_gapfill()` |
| Design | `ntl_exposure()`, `ntl_crosswalk()`, `ntl_apply_crosswalk()` |
| Utilities | `ntl_cache_dir()`, `ntl_cache_clear()`, `ntl_token()`, `ntl_example()` |

## Supported products

| id | What | Access |
|---|---|---|
| `VNP46A3`, `VNP46A4` | Black Marble monthly/annual, Suomi NPP (to Oct 2026) | `ntl_fetch()`, token |
| `VJ146A3`, `VJ146A4` | Black Marble monthly/annual, NOAA-20 | `ntl_fetch()`, token |
| `eog_vnl_monthly`, `eog_vnl_annual` | EOG VIIRS Nighttime Lights (npp, j01) with `cf_cvg` coverage | free EOG account, then `ntl_files()` |
| `dmsp_viirs_li` | Li et al. (2020) harmonized DMSP-VIIRS, DN scale | figshare, `ntl_files()` |
| `viirs_like_chen` | Chen et al. (2021) extended VIIRS-like series | Harvard Dataverse, `ntl_files()` |
| `world_nightlights_regan` | Regan et al. corrected 1992-2023 series | GitHub, `ntl_files()` |

## Status and validation

Version 0.1.0 passes `R CMD check` and its test suite, which runs offline on
synthetic rasters, HDF5 fixtures and mocked LAADS responses. Two parts have
**not yet been run against live data**:

1. **Downloads.** Authenticated downloads in `ntl_fetch()`. The URL layout
   and listing format were checked against the live archive, and the whole
   download path is tested with mocked responses.
2. **Tile orientation.** Orientation handling with real Black Marble files.
   Some GDAL builds return tiles upside down, and `ntl_read_bm()` checks for
   this.

Run `system.file("scripts", "validate_splice_kz.R", package = "ntlpanel")`
first. It checks orientation on a known city and measures the Suomi NPP to
NOAA-20 level shift across Kazakhstan's regions and calendar months.

## Roadmap

- Optional Google Earth Engine back-end for server-side zonal statistics.
- NOAA-21 products once they are available on LAADS.
- Network distances in `ntl_exposure()` (via `dodgr`).
- H3 grid helpers built on `h3o`.
- rOpenSci review and a JOSS paper.

## License

MIT (c) Serik Iskakov
