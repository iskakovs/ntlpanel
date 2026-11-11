# Supported nighttime lights products

Returns the registry of products that `ntlpanel` can fetch or read, with
the metadata the rest of the package relies on: temporal frequency,
resolution, the layers holding values, observation counts and quality
flags, access method and caveats.

## Usage

``` r
ntl_sources(id = NULL)
```

## Arguments

- id:

  Optional product id(s) to return. `NULL` returns all.

## Value

A data frame with one row per product and these columns:

- id:

  Product identifier used throughout the package.

- family:

  `black_marble`, `eog_vnl` or `harmonized`.

- platform:

  Satellite platform(s).

- frequency:

  `month` or `year`.

- resolution_arcsec:

  Nominal pixel size in arc-seconds.

- start, end:

  First and last period known to the registry (`NA` = check
  availability; see
  [`ntl_available()`](https://iskakovs.github.io/ntlpanel/reference/ntl_available.md)).

- backend:

  `laads` (downloadable) or `local`.

- laads_collection:

  LAADS archive collection number.

- value_layer, nobs_layer, quality_layer:

  HDF5 dataset names (Black Marble) or file-name tokens (EOG).

- units:

  Units of the value layer.

- file_pattern:

  Regular expression matching product files.

- url:

  Where the data live.

- notes:

  Caveats that matter for panel construction.

## Details

Products with `backend == "laads"` can be downloaded with
[`ntl_fetch()`](https://iskakovs.github.io/ntlpanel/reference/ntl_fetch.md)
(a NASA Earthdata token is required). Products with `backend == "local"`
must be downloaded by the user (EOG requires a free account; the
harmonized series are distributed through figshare, Harvard Dataverse or
GitHub) and are indexed with
[`ntl_files()`](https://iskakovs.github.io/ntlpanel/reference/ntl_files.md).
Black Marble products can also be read from local `.h5` files with
[`ntl_files()`](https://iskakovs.github.io/ntlpanel/reference/ntl_files.md).

URL patterns and file-name conventions are kept in this single registry
so that a change upstream needs only one fix.

## Examples

``` r
ntl_sources()
#>                        id       family
#> 1                 VNP46A3 black_marble
#> 2                 VNP46A4 black_marble
#> 3                 VJ146A3 black_marble
#> 4                 VJ146A4 black_marble
#> 5         eog_vnl_monthly      eog_vnl
#> 6          eog_vnl_annual      eog_vnl
#> 7           dmsp_viirs_li   harmonized
#> 8         viirs_like_chen   harmonized
#> 9 world_nightlights_regan   harmonized
#>                                           platform frequency resolution_arcsec
#> 1                                             SNPP     month                15
#> 2                                             SNPP      year                15
#> 3                                          NOAA-20     month                15
#> 4                                          NOAA-20      year                15
#> 5 SNPP (npp), NOAA-20 (j01); parsed from file name     month                15
#> 6 SNPP (npp), NOAA-20 (j01); parsed from file name      year                15
#> 7           DMSP + SNPP (harmonized to DMSP scale)      year                30
#> 8          DMSP + SNPP (harmonized to VIIRS scale)      year                15
#> 9                          DMSP + SNPP (corrected)      year                NA
#>     start     end backend laads_collection                   value_layer
#> 1 2012-01 2026-10   laads             5200 NearNadir_Composite_Snow_Free
#> 2    2012    2025   laads             5200 NearNadir_Composite_Snow_Free
#> 3    <NA>    <NA>   laads             5200 NearNadir_Composite_Snow_Free
#> 4    <NA>    <NA>   laads             5200 NearNadir_Composite_Snow_Free
#> 5 2012-04    <NA>   local             <NA>                    avg_rade9h
#> 6    2012    <NA>   local             <NA>                average_masked
#> 7    1992    <NA>   local             <NA>                            DN
#> 8    2000    <NA>   local             <NA>                      radiance
#> 9    1992    <NA>   local             <NA>                      radiance
#>                          nobs_layer                         quality_layer
#> 1 NearNadir_Composite_Snow_Free_Num NearNadir_Composite_Snow_Free_Quality
#> 2 NearNadir_Composite_Snow_Free_Num NearNadir_Composite_Snow_Free_Quality
#> 3 NearNadir_Composite_Snow_Free_Num NearNadir_Composite_Snow_Free_Quality
#> 4 NearNadir_Composite_Snow_Free_Num NearNadir_Composite_Snow_Free_Quality
#> 5                            cf_cvg                                  <NA>
#> 6                            cf_cvg                                  <NA>
#> 7                              <NA>                                  <NA>
#> 8                              <NA>                                  <NA>
#> 9                              <NA>                                  <NA>
#>                      units
#> 1                nW/cm2/sr
#> 2                nW/cm2/sr
#> 3                nW/cm2/sr
#> 4                nW/cm2/sr
#> 5                nW/cm2/sr
#> 6                nW/cm2/sr
#> 7                DN (0-63)
#> 8   nW/cm2/sr (VIIRS-like)
#> 9 see source documentation
#>                                               file_pattern
#> 1     ^VNP46A3\\.A[0-9]{7}\\.h[0-9]{2}v[0-9]{2}\\..*\\.h5$
#> 2     ^VNP46A4\\.A[0-9]{7}\\.h[0-9]{2}v[0-9]{2}\\..*\\.h5$
#> 3     ^VJ146A3\\.A[0-9]{7}\\.h[0-9]{2}v[0-9]{2}\\..*\\.h5$
#> 4     ^VJ146A4\\.A[0-9]{7}\\.h[0-9]{2}v[0-9]{2}\\..*\\.h5$
#> 5 ^SVDNB_[a-z0-9]+_[0-9]{8}-[0-9]{8}_.*avg_rade9h.*\\.tif$
#> 6          ^VNL_.*(19|20)[0-9]{2}.*average_masked.*\\.tif$
#> 7             ^Harmonized_DN_NTL_(19|20)[0-9]{2}_.*\\.tif$
#> 8                                 (19|20)[0-9]{2}.*\\.tif$
#> 9                                 (19|20)[0-9]{2}.*\\.tif$
#>                                                                    url
#> 1 https://ladsweb.modaps.eosdis.nasa.gov/archive/allData/5200/VNP46A3/
#> 2 https://ladsweb.modaps.eosdis.nasa.gov/archive/allData/5200/VNP46A4/
#> 3 https://ladsweb.modaps.eosdis.nasa.gov/archive/allData/5200/VJ146A3/
#> 4 https://ladsweb.modaps.eosdis.nasa.gov/archive/allData/5200/VJ146A4/
#> 5                              https://eogdata.mines.edu/products/vnl/
#> 6                              https://eogdata.mines.edu/products/vnl/
#> 7                          https://doi.org/10.6084/m9.figshare.9828827
#> 8                                   https://doi.org/10.7910/DVN/YGIVCD
#> 9                     https://github.com/tannerregan/world_nightlights
#>                                                                                                                                                                                                   notes
#> 1                                                                    Suomi NPP. NOAA ended Suomi NPP data delivery on 2026-11-02; splice onto the NOAA-20 product for later periods (see ntl_splice()).
#> 2                                                                    Suomi NPP. NOAA ended Suomi NPP data delivery on 2026-11-02; splice onto the NOAA-20 product for later periods (see ntl_splice()).
#> 3                                                                            NOAA-20. Same file naming and HDF5 layout as the Suomi NPP product. Check the first available period with ntl_available().
#> 4                                                                            NOAA-20. Same file naming and HDF5 layout as the Suomi NPP product. Check the first available period with ntl_available().
#> 5 Download requires a free EOG account. Prefer the stray-light corrected 'vcmslcfg' files at high latitude; matching 'cf_cvg' files give cloud-free observation counts and are picked up automatically.
#> 6                                                                          Annual VNL composites. Download requires a free EOG account. Check EOG documentation for the stray-light configuration used.
#> 7                                                                 Li, Zhou, Zhao and Zhao (2020, Scientific Data). The authors suggest using pixels with DN > 7. DMSP-scale values are top-coded at 63.
#> 8                                  Chen et al. (2021, Earth System Science Data) extended NPP-VIIRS-like series. File names vary by release; pass `period` to ntl_files() if the year cannot be parsed.
#> 9                                                                    Corrected for blooming, top-coding and cross-sensor calibration. For post-2013-only analyses the authors recommend VIIRS directly.
ntl_sources("VJ146A3")[, c("id", "platform", "frequency", "notes")]
#>        id platform frequency
#> 1 VJ146A3  NOAA-20     month
#>                                                                                                                        notes
#> 1 NOAA-20. Same file naming and HDF5 layout as the Suomi NPP product. Check the first available period with ntl_available().
```
