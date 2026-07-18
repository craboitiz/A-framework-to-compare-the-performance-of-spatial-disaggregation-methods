# Computes annual maximum precipitation fields from disaggregated precipitation NetCDF files.
# The script searches for F_*_ERA5_pr_1960_2021.nc files and applies cdo yearmax
# to generate *_yearmax.nc outputs.
# To adapt it, change BASE, the input filename pattern, variable/dataset naming,
# time period, and output suffix.

#!/usr/bin/env bash
set -euo pipefail

BASE="/media/sf_Cristobal_Aboitiz/Paper/KRIG/tp"

cd "$BASE"

shopt -s nullglob

for f in F_*_ERA5_pr_1960_2021.nc; do
  out="${f%.nc}_yearmax.nc"

  if [[ -f "$out" ]]; then
    echo "YA EXISTE, salto: $out"
    continue
  fi

  echo "Procesando: $f -> $out"
  cdo yearmax "$f" "$out"
done

echo "Listo."