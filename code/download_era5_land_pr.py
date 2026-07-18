# Downloads hourly ERA5-Land total precipitation for the South American domain.
# The script saves one NetCDF file per year.
# To adapt it, change the CDS dataset, variable name, years, months, days, hours,
# spatial bounding box, output format, and output filename prefix.

import cdsapi

c = cdsapi.Client()

for year in range(1960,2022):
	c.retrieve(
    'reanalysis-era5-land',
    {
        'variable': [
            'total_precipitation',
        ],
        'year': str(year),
        'day': [
            '01', '02', '03',
            '04', '05', '06',
            '07', '08', '09',
            '10', '11', '12',
            '13', '14', '15',
            '16', '17', '18',
            '19', '20', '21',
            '22', '23', '24',
            '25', '26', '27',
            '28', '29', '30',
            '31',
        ],
        'month': ['01','02','03','04','05','06','07','08','09','10','11','12',],
        'time': [
            '00:00', '01:00', '02:00',
            '03:00', '04:00', '05:00',
            '06:00', '07:00', '08:00',
            '09:00', '10:00', '11:00',
            '12:00', '13:00', '14:00',
            '15:00', '16:00', '17:00',
            '18:00', '19:00', '20:00',
            '21:00', '22:00', '23:00',
        ],
        'area': [
            15, -85, -60,
            -30,
        ],
        'format': 'netcdf',
    },
    'ERA5_pr_'+str(year)+'.nc')
