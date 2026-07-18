# Code

This folder contains the scripts used in the study:

**A framework to compare the performance of spatial disaggregation methods of statistical climate downscaling in South America**

The scripts are provided as a reference implementation of the workflow used in the study. File paths, input datasets, spatial and temporal domains, resolution scales, variable names, grid description files, and disaggregation methods should be modified according to the specific case study and analysis objectives of the user.

Large input datasets are not included in this repository.

## General workflow

The scripts include steps related to:

- ERA5-Land data download
- Hourly-to-daily temporal aggregation
- Spatial subsetting
- Spatial aggregation to coarser grids
- Spatial disaggregation using CDO methods
- Ordinary kriging disaggregation
- Masking and splitting large domains
- Evaluation metric calculation
- Merging metric maps
- Domain and climate-region averages
- Maximum Scaling Factor calculation
- Supporting figures and tables

The execution order may depend on the selected configuration and on the available input files. Users should review and adapt each script before running it.

## Inputs

Input files may include gridded observations, reanalysis products, aggregated climate fields, disaggregated outputs, shapefiles, and intermediate metric tables. Large input datasets are not included in this repository.

## Outputs

The scripts may generate processed NetCDF files, metric maps, Excel tables, text summaries, figures, rasters, and intermediate files. Generated outputs should be stored in the corresponding output folders when applicable.

## Requirements

The workflow uses a combination of Bash, CDO, R, and Python.

Required software and libraries may include:

```text
CDO
Python
R
cdsapi
xarray
numpy
pykrige
netCDF4
ncdf4
hydroGOF
openxlsx
readxl
writexl
dplyr
tidyr
stringr
terra
```

Before running shell scripts copied from Windows, it may be necessary to fix line endings and make the scripts executable:

```bash
sed -i 's/\r$//' script_name.sh
chmod +x script_name.sh
```

## Scripts

### Data download and temporal aggregation

#### `download_era5_land_pr.py`

Downloads hourly ERA5-Land total precipitation for the South American domain and saves one NetCDF file per year.

To adapt it, change the CDS dataset, variable name, years, months, days, hours, spatial bounding box, output format, and output filename prefix.

#### `hourly_to_daily_pr.sh`

Converts hourly precipitation files to daily accumulated precipitation using `CDO daysum`.

To adapt it, change the input file pattern, output filename, compression settings, and CDO operator if a different temporal aggregation is required.

#### `hourly_to_daily_tas.sh`

Converts hourly temperature files to daily mean temperature using `CDO daymean`.

To adapt it, change the input file pattern, output filename, compression settings, and CDO operator if daily minimum, maximum, or another temporal statistic is required.

### Spatial subsets and grid preparation

#### `split_chile_NCS_example.sh`

Example script to split NetCDF files into North, Central, and South Chile subregions.

The script uses `CDO sellonlatbox` and adds the prefixes `N_`, `C_`, and `S_` to the outputs.

To adapt it, change the input folder, longitude/latitude bounds for each subregion, output prefixes, and file pattern if the inputs are not all `*.nc` files.

#### `split_krig_t2m_9sections_example.sh`

Example script to split a KRIG t2m output into the nine South American sections.

The expected layout is:

```text
NO  NC  NE
CO  CC  CE
SO  SC  SE
```

To adapt it, change the input file names, scale code, base path, suffix, output folder, and index ranges if the grid dimensions are different.

### Spatial aggregation and CDO disaggregation

#### `aggregate_to_scale10_bic_example.sh`

Example aggregation/remapping script for scale 10.

The script remaps all NetCDF files in the current folder to the coarse grid defined in `01_10.txt` using `CDO remapbic`.

To adapt it, change the input file pattern, output prefix, scale code, interpolation/remapping method, and coarse-grid description file.

#### `cdo_disaggregation_all_methods_scale10_example.sh`

Example disaggregation script for scale 10.

The script applies CDO remapping methods to all NetCDF files in the current folder and disaggregates them to the target grid defined in `G-F_10.txt`.

Methods included:

```text
BIL  -> remapbil
BIC  -> remapbic
NN   -> remapnn
LAF  -> remaplaf
DIS  -> remapdis
CON1 -> remapcon
CON2 -> remapcon2
```

To adapt it, change the input file pattern, scale code, output prefixes, CDO methods, and target grid description file.

### Ordinary kriging

#### `krige_fixed_variogram.py`

Performs ordinary kriging from a coarse source grid to a target fine grid using PyKrige.

The variogram is fitted once using the first valid timestep and then reused for all timesteps. By default, `log1p/expm1` is applied for precipitation to avoid negative predictions. For variables such as temperature, use:

```bash
--no-log1p
```

To adapt it, change `--src`, `--tgt`, `--out`, `--varname`, `--nclosest`, `--variogram`, `--compress`, and add or remove `--no-log1p` depending on the variable.

#### `run_krig_yearly_pr_example.sh`

Example wrapper to run ordinary kriging year by year for precipitation.

The script extracts one year at a time from the source and target NetCDF files, calls `krige_fixed_variogram.py`, saves yearly KRIG outputs, logs runtime, and allows restarting from a selected year.

To adapt it, change `SCALE`, `VAR`, `SRC`, `TGT`, path to the Python script, `NCLOSE`, variogram model, compression level, `Y0/Y1`, work/output folders, and filename pattern.

#### `run_krig_yearly_t2m_example.sh`

Example wrapper to run ordinary kriging year by year for temperature.

This version uses `--no-log1p`, because the logarithmic precipitation transformation should not be applied to temperature.

To adapt it, change `SCALE`, `VAR`, `SRC`, `TGT`, path to the Python script, `NCLOSE`, variogram model, compression level, `Y0/Y1`, work/output folders, and filename pattern.

#### `merge_krig_yearly_outputs.sh`

Merges yearly KRIG NetCDF outputs into a single multi-year file using `CDO mergetime`.

The script checks that all yearly files are present before merging.

To adapt it, change `VAR`, `Y0`, `Y1`, the expected filename pattern, and the folder where the yearly files are stored.

**Note:** some older outputs used the typo `kirg` instead of `krig`. Keep the filename pattern consistent across the KRIG wrapper and merge scripts.

### Masking and postprocessing

#### `apply_t2m_land_mask_to_krig_tp_example.sh`

Applies a land/sea mask from a masked t2m KRIG file to a KRIG precipitation file.

The script writes a clean NetCDF output, preserves coordinates and metadata, removes non-finite values, and writes masked cells using a consistent fill value.

To adapt it, change `SCALE`, `BASE_TP`, `MASK`, `VAR`, `MASK_VAR`, input/output filenames, and `CHUNK_TIME` if memory usage needs adjustment.

### Metric calculation

#### `compute_metrics_cr2_pr_region_example.R`

Example script to compute grid-cell performance metrics for CR2MET precipitation in one Chilean subregion.

The script compares the reference CR2MET precipitation field against disaggregated precipitation files and exports MAE, MSE, KGE, and NSE maps plus average summaries.

To adapt it, change `folder_path`, reference file, variable name, input filename pattern, spatial subset indices, output filenames, and region label.

#### `compute_metrics_era5_t2m_cdo_example.R`

Example script to compute grid-cell performance metrics for ERA5-Land temperature after CDO-based disaggregation.

The script compares each disaggregated t2m file against the reference ERA5-Land t2m field and exports MAE, MSE, KGE, and NSE maps plus average summaries.

To adapt it, change `folder_path`, reference file, variable name, input filename pattern, output filenames, and any coordinate/orientation preprocessing.

#### `compute_metrics_krig_tp_9sections.R`

Computes grid-cell performance metrics for KRIG precipitation over the nine South American sections.

For each scale and section, the script compares the reference ERA5-Land precipitation series with the KRIG output and exports MAE, MSE, KGE, and NSE maps plus average summaries.

To adapt it, change `BASE_DIR`, `ERA_DIR`, `KRIG_DIR`, scales, section names, file tags, variable names, valid-value limits, `MIN_VALID`, and output filename pattern.

### Merging metric maps and spatial averages

#### `merge_krig_tp_9section_metric_maps.R`

Merges the nine South American section metric maps into full-domain KRIG precipitation maps.

For each scale and metric sheet, the script reads the section Excel files, places them in the `NO/NC/NE`, `CO/CC/CE`, `SO/SC/SE` layout, and exports one merged `753 x 551` Excel map per scale.

To adapt it, change `folder_path`, scales, sheet names, `VAR_NAME`, sector sizes, section order, start rows/columns, final grid dimensions, and input filename pattern.

#### `average_metrics_cr2_NCS.R`

Computes average MAE, MSE, KGE, and NSE values for the Chilean North, Central, and South subregions from CR2MET metric maps stored in Excel files.

To adapt it, change `folder_path`, input Excel file pattern, metric sheet names, subregion column ranges, output filenames, and region labels.

#### `domain_averages_krig_tp.R`

Computes full-domain spatial averages of KRIG precipitation metrics for each scale.

The script reads merged MAE, MSE, KGE, and NSE maps and averages all valid cells.

To adapt it, change `folder_path`, scales, metric sheet names, `VAR_NAME`, input filename pattern, output filename, and missing-value codes.

#### `cut_climates_krig_tas_pr.R`

Computes climate-region averages for KRIG precipitation and temperature metrics.

The script reads merged metric maps, clips them using climate-region shapefiles `s1-s5`, exports masked rasters, and creates an Excel summary of mean, minimum, maximum, and valid-cell counts.

To adapt it, change `tas_metrics_dir`, `pr_metrics_dir`, `output_dir`, shape folders, scales, metric names, variable/file tags, spatial extent, grid dimensions, and shape names.

### Summary tables and thresholds

#### `format_summary_tables_pr_by_shape.R`

Formats precipitation metric summaries by climate region for Supporting Information tables.

The script reads `Resumen_Indices.xlsx` and creates one workbook with MAE, MSE, KGE, and NSE sheets, each containing tables for Domain and climate regions `s1-s5`.

To adapt it, change the input/output folder, input Excel filename, list of indices, shape names, method names, and scale-code conversion.

The same structure can be used for temperature by changing the input folder and variable-specific filenames.

#### `compute_msf_thresholds_era5_krig.R`

Computes threshold scales and Maximum Scaling Factors from weighted-index summary tables.

The weighted index was previously calculated in Excel from MAE, MSE, KGE, and NSE and stored in the `Ponderado` sheet of the precipitation and temperature summary files.

The script reads those sheets, fits a quadratic relationship between weighted index and scale, identifies the 0.7 threshold crossing, and computes:

```text
MSF = scale_threshold / original_resolution
```

To adapt it, change `archivo_pr`, `archivo_tas`, `output_dir`, threshold value, original resolution, method names, and the expected structure of the `Ponderado` sheet.

#### `plot_thresholds_chile.R`

Computes and plots weighted-index threshold curves for the Chilean domain.

The script reads the weighted-index table, fits quadratic curves by variable, sector, and method, identifies the 0.7 threshold crossing, and saves plots.

To adapt it, change `ruta_base`, input Excel filename, threshold value, variable/sector/method names, plotting settings, and output folder.

### Supporting analyses and figures

#### `compute_annual_max_precipitation_cdo.sh`

Computes annual maximum precipitation fields from disaggregated precipitation NetCDF files.

The script searches for `F_*_ERA5_pr_1960_2021.nc` files and applies `CDO yearmax` to generate `*_yearmax.nc` outputs.

To adapt it, change `BASE`, the input filename pattern, variable/dataset naming, time period, and output suffix.

#### `cellwise_extreme_percentiles_krig_tp.R`

Computes cell-wise precipitation extreme percentile diagnostics for KRIG outputs.

For each scale, the script compares ERA5-Land precipitation with KRIG precipitation and exports P95, P5, bias, absolute error, and valid-count maps.

To adapt it, change `base_dir`, `orig_file`, scales, `VAR_NAME`, precipitation valid-value limits, `MIN_VALID`, output filenames, and preferred variable names.

#### `spatial_percentile_series_krig_tp.R`

Computes daily spatial percentile series for ERA5-Land precipitation and KRIG outputs.

For each day, the script calculates spatial P95 and P05 values over the domain, along with the number of valid and removed cells.

To adapt it, change `base_dir`, `orig_file`, the list of KRIG files/scales, output filename, precipitation variable names, valid-value limits, and `chunk_size`.

#### `figure_kge_chile_3regions.R`

Generates KGE map visualizations and boxplots for the Chilean domain and its North, Central, and South subregions.

To adapt it, change `input_dir`, input Excel file, output folder, spatial extent, subregion column ranges, percentile clipping limits, color palette, and figure labels.

## Climate-region shapefiles

`shapesclimas2/`

This folder contains the climate-region shapefiles used to compute climate-sector averages.

The scripts expect shapefiles named:

```text
s1.shp
s2.shp
s3.shp
s4.shp
s5.shp
```

To adapt the workflow, replace these shapefiles and update the corresponding shape names, coordinate reference system, and region labels in the climate-region scripts.

## Notes

- Most scripts are examples and use hard-coded local paths.
- Before running, update all paths, filenames, variables, scale codes, grid files, and output folders.
- Keep naming consistent across the workflow. Prefer `krig` over the older typo `kirg`, unless older outputs already use `kirg`.
- For precipitation, scripts may remove invalid values below 0 or above 10 m/day.
- For temperature, do not apply precipitation-specific filtering and use `--no-log1p` when running kriging.
- The weighted index itself was calculated in Excel; the MSF script starts from the already prepared `Ponderado` sheets.
