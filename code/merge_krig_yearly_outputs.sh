# Merges yearly KRIG NetCDF outputs into a single multi-year file using cdo mergetime.
# The script detects the scale from files named kirg_XX_tp_YEAR.nc and checks that
# all years in the requested period are present before merging.
# To adapt it, change VAR, Y0, Y1, the expected filename pattern, and the folder
# where the yearly files are stored.

#!/usr/bin/env bash
set -euo pipefail

# Carpeta donde está este .sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Carpeta de salida: un nivel arriba de yearly
OUTDIR="$(dirname "$SCRIPT_DIR")"

VAR="tp"
Y0=1960
Y1=2021

cd "$SCRIPT_DIR"

# Detectar escala desde el primer archivo tipo kirg_02_tp_1960.nc
FIRST_FILE=$(ls kirg_*_${VAR}_*.nc 2>/dev/null | head -n 1 || true)

if [[ -z "$FIRST_FILE" ]]; then
  echo "ERROR: no encontré archivos tipo kirg_*_${VAR}_*.nc en:"
  echo "$SCRIPT_DIR"
  exit 1
fi

SCALE=$(echo "$FIRST_FILE" | sed -E "s/^kirg_([0-9]{2})_${VAR}_[0-9]{4}\.nc$/\1/")

if [[ -z "$SCALE" || "$SCALE" == "$FIRST_FILE" ]]; then
  echo "ERROR: no pude detectar la escala desde el archivo:"
  echo "$FIRST_FILE"
  exit 1
fi

OUTFILE="${OUTDIR}/kirg_${SCALE}_${VAR}_${Y0}_${Y1}.nc"

echo "=============================================="
echo "MERGETIME KRIG"
echo "Carpeta yearly : $SCRIPT_DIR"
echo "Carpeta salida : $OUTDIR"
echo "Escala         : $SCALE"
echo "Variable       : $VAR"
echo "Años           : $Y0-$Y1"
echo "Output         : $OUTFILE"
echo "=============================================="
echo

# Armar lista de archivos en orden año por año
FILES=()

for ((y=Y0; y<=Y1; y++)); do
  f="kirg_${SCALE}_${VAR}_${y}.nc"

  if [[ ! -f "$f" ]]; then
    echo "ERROR: falta el archivo:"
    echo "$SCRIPT_DIR/$f"
    exit 1
  fi

  FILES+=("$f")
done

echo "Archivos encontrados: ${#FILES[@]}"
echo "Uniendo con cdo mergetime..."
echo

cdo -O mergetime "${FILES[@]}" "$OUTFILE"

echo
echo "✅ Listo:"
echo "$OUTFILE"

echo
echo "Verificación rápida:"
cdo showname "$OUTFILE"
cdo ntime "$OUTFILE"