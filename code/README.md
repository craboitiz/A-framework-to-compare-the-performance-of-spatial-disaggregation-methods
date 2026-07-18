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
