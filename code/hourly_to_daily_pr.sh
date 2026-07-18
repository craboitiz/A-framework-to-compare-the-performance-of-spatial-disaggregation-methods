# Converts hourly precipitation files to daily accumulated precipitation using CDO daysum.
# To adapt it, change the input file pattern, output filename, compression settings,
# and CDO operator if a different temporal aggregation is required.

cdo -O -f nc4c -z zip_4 daysum *.nc ERA5_pr_daily_1960_2021.nc

