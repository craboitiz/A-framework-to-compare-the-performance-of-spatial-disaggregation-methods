# Example aggregation/remapping script for scale 10.
# The script remaps all NetCDF files in the current folder to the coarse grid
# defined in 01_10.txt using CDO remapbic.
# To adapt it, change the input file pattern, output prefix, scale code,
# interpolation/remapping method, and coarse-grid description file.

for file in *.nc; do cdo remapbic,01_10.txt "$file" "10_${file}"; done
