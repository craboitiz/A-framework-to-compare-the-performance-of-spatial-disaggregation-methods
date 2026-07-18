# Example script to split NetCDF files into North, Central, and South Chile subregions.
# The script uses cdo sellonlatbox and adds the prefixes N_, C_, and S_ to the outputs.
# To adapt it, change the input folder, longitude/latitude bounds for each subregion,
# output prefixes, and file pattern if the inputs are not all *.nc files.

# Itera sobre los archivos .nc en el directorio actual
for file in *.nc; do
  if [ -f "$file" ]; then
    # Norte
    cdo sellonlatbox,-76.975,-66.025,-30,-17 "$file" "N_${file}"

    # Centro
    cdo sellonlatbox,-76.975,-66.025,-43,-30 "$file" "C_${file}"

    # Sur
    cdo sellonlatbox,-76.975,-66.025,-56.975,-43 "$file" "S_${file}"
  fi
done

echo "Procesamiento completado. Los archivos recortados tienen los prefijos N_, C_ y S_."

