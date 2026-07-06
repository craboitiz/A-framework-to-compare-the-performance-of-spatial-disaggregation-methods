# Code

This folder contains the scripts used in the study:

**A framework to compare the performance of spatial disaggregation methods of statistical climate downscaling in South America**

The scripts are provided as a reference implementation of the workflow used in the study. File paths, input datasets, spatial and temporal domains, resolution scales, and disaggregation methods should be modified according to the specific case study and analysis objectives of the user.

## General workflow

The scripts may include steps related to:

- Data preprocessing
- Spatial aggregation and disaggregation
- Comparison of spatial disaggregation methods
- Bias correction
- Evaluation metrics
- Figure and table generation

The execution order may depend on the selected configuration and on the available input files. Users should review each script before running it.

## Inputs

Input files may include climate datasets, reanalysis products, gridded observations, and climate model outputs. Large input datasets are not included in this repository.

## Outputs

The scripts may generate processed datasets, evaluation tables, figures, and intermediate files. Generated outputs should be stored in the corresponding `outputs/` folder when applicable.

## Notes

Before running the scripts, users should check and modify:

- File paths
- Variable names
- Spatial domain
- Temporal period
- Resolution scale
- Disaggregation method
- Input and output folder names
