# Example disaggregation script for scale 10.
# The script applies CDO remapping methods to all NetCDF files in the current folder
# and disaggregates them to the target grid defined in G-F_10.txt.
# To adapt it, change the input file pattern, scale code, output prefixes,
# CDO methods, and target grid description file.

FILES=(*.nc)

for file in "${FILES[@]}"; do cdo -b F32 remapbil,G-F_10.txt "$file" "bil_${file}"; done
for file in "${FILES[@]}"; do cdo -b F32 remapbic,G-F_10.txt "$file" "bic_${file}"; done
for file in "${FILES[@]}"; do cdo -b F32 remapnn,G-F_10.txt "$file" "nn_${file}"; done
for file in "${FILES[@]}"; do cdo -b F32 remaplaf,G-F_10.txt "$file" "laf_${file}"; done
for file in "${FILES[@]}"; do cdo -b F32 remapdis,G-F_10.txt "$file" "dis_${file}"; done
for file in "${FILES[@]}"; do cdo -b F32 remapcon,G-F_10.txt "$file" "con_${file}"; done
for file in "${FILES[@]}"; do cdo -b F32 remapcon2,G-F_10.txt "$file" "con2_${file}"; done
