# Example script to split a KRIG t2m output into the nine South American sections.
# For other scales or variables, change the input file names, scale code, base path,
# suffix, output folder, and index ranges if the grid dimensions are different.

#!/usr/bin/env bash
set -euo pipefail

SCALE="10"
# SCALE="02"
# SCALE="05"
# SCALE="15"
# SCALE="20"
# SCALE="25"

BASE="/media/sf_Cristobal_Aboitiz/Paper/KRIG/tas"

INFILE_MASKED="$BASE/krig_${SCALE}_t2m_masked.nc"
INFILE_PLAIN="$BASE/krig_${SCALE}_t2m.nc"

if [[ -f "$INFILE_MASKED" ]]; then
    INFILE="$INFILE_MASKED"
    SUFFIX="t2m_masked"
    echo "Usando archivo masked:"
    echo "$INFILE"
elif [[ -f "$INFILE_PLAIN" ]]; then
    INFILE="$INFILE_PLAIN"
    SUFFIX="t2m"
    echo "Usando archivo sin mask:"
    echo "$INFILE"
else
    echo "ERROR: no existe ninguno de estos archivos:"
    echo "$INFILE_MASKED"
    echo "$INFILE_PLAIN"
    exit 1
fi

OUTDIR="$BASE/${SCALE}_split_9"
mkdir -p "$OUTDIR"

echo "=============================================="
echo "SPLIT ${SCALE} TAS EN 9 SECCIONES"
echo "Input : $INFILE"
echo "Output: $OUTDIR"
echo "=============================================="
echo

rm -f "$OUTDIR"/NO_krig_${SCALE}_*.nc
rm -f "$OUTDIR"/NC_krig_${SCALE}_*.nc
rm -f "$OUTDIR"/NE_krig_${SCALE}_*.nc
rm -f "$OUTDIR"/CO_krig_${SCALE}_*.nc
rm -f "$OUTDIR"/CC_krig_${SCALE}_*.nc
rm -f "$OUTDIR"/CE_krig_${SCALE}_*.nc
rm -f "$OUTDIR"/SO_krig_${SCALE}_*.nc
# Example script to split a KRIG t2m output into the nine South American sections.
# For other scales or variables, change the input file names, scale code, base path,
# suffix, output folder, and index ranges if the grid dimensions are different.

rm -f "$OUTDIR"/SC_krig_${SCALE}_*.nc
rm -f "$OUTDIR"/SE_krig_${SCALE}_*.nc

echo "Cortando en 9 secciones..."

# Fila norte
cdo -O selindexbox,1,184,1,251       "$INFILE" "$OUTDIR/NO_krig_${SCALE}_${SUFFIX}.nc"
cdo -O selindexbox,185,367,1,251     "$INFILE" "$OUTDIR/NC_krig_${SCALE}_${SUFFIX}.nc"
cdo -O selindexbox,368,551,1,251     "$INFILE" "$OUTDIR/NE_krig_${SCALE}_${SUFFIX}.nc"

# Fila centro
cdo -O selindexbox,1,184,252,502     "$INFILE" "$OUTDIR/CO_krig_${SCALE}_${SUFFIX}.nc"
cdo -O selindexbox,185,367,252,502   "$INFILE" "$OUTDIR/CC_krig_${SCALE}_${SUFFIX}.nc"
cdo -O selindexbox,368,551,252,502   "$INFILE" "$OUTDIR/CE_krig_${SCALE}_${SUFFIX}.nc"

# Fila sur
cdo -O selindexbox,1,184,503,753     "$INFILE" "$OUTDIR/SO_krig_${SCALE}_${SUFFIX}.nc"
cdo -O selindexbox,185,367,503,753   "$INFILE" "$OUTDIR/SC_krig_${SCALE}_${SUFFIX}.nc"
cdo -O selindexbox,368,551,503,753   "$INFILE" "$OUTDIR/SE_krig_${SCALE}_${SUFFIX}.nc"

echo
echo "Verificación rápida:"
ls -lh "$OUTDIR"/*.nc

echo
echo "Listo. Archivos guardados en:"
echo "$OUTDIR"