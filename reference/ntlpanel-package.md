# ntlpanel: Nighttime Lights to Analysis-Ready Panels for Econometrics

`ntlpanel` turns nighttime lights rasters into balanced unit-by-period
panels whose every row says how much of the unit was actually observed.

## Details

The workflow has five steps:

1.  **Find or fetch data.**
    [`ntl_sources()`](https://iskakovs.github.io/ntlpanel/reference/ntl_sources.md)
    lists supported products.
    [`ntl_fetch()`](https://iskakovs.github.io/ntlpanel/reference/ntl_fetch.md)
    downloads NASA Black Marble tiles (Suomi NPP `VNP46A3/A4` and
    NOAA-20 `VJ146A3/A4`) into a cache.
    [`ntl_files()`](https://iskakovs.github.io/ntlpanel/reference/ntl_files.md)
    indexes files you already have (EOG VNL composites, harmonized
    DMSP-VIIRS series, Black Marble `.h5` files). Both return a
    *manifest*.

2.  **Extract.**
    [`ntl_extract()`](https://iskakovs.github.io/ntlpanel/reference/ntl_extract.md)
    reads one period at a time, applies quality, coverage and gas-flare
    masks
    ([`ntl_mask()`](https://iskakovs.github.io/ntlpanel/reference/ntl_mask.md))
    and computes zonal statistics with coverage diagnostics
    ([`ntl_aggregate()`](https://iskakovs.github.io/ntlpanel/reference/ntl_aggregate.md)).

3.  **Splice sensors.**
    [`ntl_splice()`](https://iskakovs.github.io/ntlpanel/reference/ntl_splice.md)
    puts Suomi NPP and NOAA-20 (or any two series) on one scale and
    reports level shifts per unit.

4.  **Build the panel.**
    [`ntl_panel()`](https://iskakovs.github.io/ntlpanel/reference/ntl_panel.md)
    balances the unit x period grid and adds transforms and time
    indices.
    [`ntl_gapfill()`](https://iskakovs.github.io/ntlpanel/reference/ntl_gapfill.md)
    applies explicit rules to missing or low-coverage cells, such as the
    summer stray-light gaps at high latitudes.

5.  **Add design variables.**
    [`ntl_exposure()`](https://iskakovs.github.io/ntlpanel/reference/ntl_exposure.md)
    assigns distance rings and first-treatment dates.
    [`ntl_crosswalk()`](https://iskakovs.github.io/ntlpanel/reference/ntl_crosswalk.md)
    and
    [`ntl_apply_crosswalk()`](https://iskakovs.github.io/ntlpanel/reference/ntl_apply_crosswalk.md)
    move tabular data between boundary vintages.

## See also

Useful links:

- <https://github.com/iskakovs/ntlpanel>

- <https://iskakovs.github.io/ntlpanel/>

- Report bugs at <https://github.com/iskakovs/ntlpanel/issues>

## Author

**Maintainer**: Serik Iskakov <s.iskakov@gmail.com>
([ORCID](https://orcid.org/0009-0003-8013-5377))
