# Data description

This folder describes the input datasets, expected file structure, and data availability associated with the study:

**A framework to compare the performance of spatial disaggregation methods of statistical climate downscaling in South America**

Large raw NetCDF datasets are not stored in this repository due to file size and/or redistribution restrictions. Users should obtain the original datasets from their official sources before running the scripts.

## Data sources

The workflow uses two main observational/reanalysis datasets.

### ERA5-Land

ERA5-Land data were used for the South American domain. The required ERA5-Land variables were downloaded as hourly NetCDF files using the CDS API scripts provided in the `Code/` folder.

The main ERA5-Land variables used in the workflow are:

```text
total_precipitation  -> precipitation
2m_temperature       -> temperature
```

The hourly ERA5-Land files are then converted to daily data using the temporal aggregation scripts in `Code/`:

```text
hourly_to_daily_pr.sh   -> daily accumulated precipitation
hourly_to_daily_tas.sh  -> daily mean temperature
```

Users should modify the API scripts according to their own target domain, time period, variables, and output file naming convention.

### CR2MET

CR2MET data were used for the Chilean domain. These files were downloaded directly from the official CR2MET data source and are not included in this repository.

Users should download the required CR2MET variables and versions before running the scripts. The scripts assume that the CR2MET files are already available locally as NetCDF files and follow the expected naming conventions.

## Expected input files

The exact filenames may vary depending on the user configuration, but the workflow expects input files such as:

```text
ERA5_pr_1960_2021.nc
ERA5_t2m_1960_2021.nc
pr_CR2_1960_2021.nc
txn_CR2_1960_2021.nc
```

Aggregated and disaggregated intermediate files are generated during the workflow and may follow naming patterns such as:

```text
10_ERA5_pr_1960_2021.nc
10_ERA5_t2m_1960_2021.nc
bic_10_ERA5_pr_1960_2021.nc
bil_10_ERA5_t2m_1960_2021.nc
krig_10_t2m_1960_2021.nc
krig_10_tp_1960_2021.nc
```

The specific prefixes depend on the selected scale, variable, method, and processing step.

## File structure

Raw and processed NetCDF files are not included in this repository. However, users may organize their local data using a structure similar to:

```text
Data/
  raw/
    ERA5_Land/
      hourly/
      daily/
    CR2MET/
  processed/
    aggregation/
    disaggregation/
    kriging/
    metrics/
```

The scripts in `Code/` contain hard-coded local paths from the original study. These paths should be modified before running the scripts.

## Grid description files

Some CDO scripts require grid description files, for example:

```text
01_10.txt
G-F_10.txt
```

These files define the coarse and target grids used for aggregation and disaggregation examples. For other spatial resolutions or domains, users must create or modify the corresponding grid description files.

## Climate-region shapefiles

Climate-region averages require shapefiles stored in:

```text
shapesclimas2/
```

The scripts expect files named:

```text
s1.shp
s2.shp
s3.shp
s4.shp
s5.shp
```

including their associated auxiliary files, such as `.dbf`, `.shx`, and `.prj`.

## Notes

Before running the scripts, users should verify and modify:

- File paths
- Dataset versions
- Variable names
- Variable units
- Spatial domain
- Temporal period
- Resolution scale
- Grid description files
- Input and output folder names
- Filename patterns

The repository provides the code structure and workflow used in the study, but users are responsible for downloading the required input datasets and adapting the scripts to their own local file organization.
