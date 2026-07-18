# Converts hourly temperature files to daily mean temperature using CDO daymean.
# To adapt it, change the input file pattern, output filename, compression settings,
# and CDO operator if daily minimum, maximum, or another temporal statistic is required.

cdo -O -f nc4c -z zip_4 daymean *.nc ERA5_t2m_daily_1960_2021.nc