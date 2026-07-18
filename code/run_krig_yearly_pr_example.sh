# Example wrapper to run ordinary kriging year by year for precipitation.
# The script extracts one year at a time from the source and target NetCDF files,
# calls krige_fixed_variogram.py, saves yearly KRIG outputs, logs runtime,
# and allows restarting from a selected year.
# To adapt it, change SCALE, VAR, SRC, TGT, path to the Python script, NCLOSE,
# variogram model, compression level, Y0/Y1, work/output folders, and filename pattern.

#!/usr/bin/env bash
set -euo pipefail

SCALE="02"
VAR="tp"

SRC="${SCALE}_ERA5_pr_1960_2021.nc"
TGT="ERA5_pr_1960_2021.nc"
SPY="./krige_pr_fixedvario.py"

NCLOSE=36
VARTO="spherical"
COMP=4

# Reanudar desde aquí
Y0=1960
Y1=2021

if [[ ! -f "$SPY" ]]; then echo "ERROR: no existe $SPY"; exit 1; fi
if [[ ! -f "$SRC" ]]; then echo "ERROR: no existe $SRC"; exit 1; fi
if [[ ! -f "$TGT" ]]; then echo "ERROR: no existe $TGT"; exit 1; fi

WORK="/media/sf_Cristobal_Aboitiz/Paper/KRIG/tp/${VAR}/${SCALE}"
TMP="$WORK/tmp"; OUTDIR="$WORK/yearly"; LOGDIR="$WORK/logs"
mkdir -p "$TMP" "$OUTDIR" "$LOGDIR"

TOTAL_YEARS=$((Y1 - Y0 + 1))
START_ALL=$(date +%s)

for ((y=Y0; y<=Y1; y++)); do
  i=$((y - Y0 + 1))
  echo "=============================="
  echo "▶ Año ${i}/${TOTAL_YEARS} (Y=${y}) | Escala=${SCALE} | Var=${VAR}"
  echo "=============================="

  SRCY="$TMP/SRC_${SCALE}_${VAR}_${y}.nc"
  TGTY="$TMP/TGT_${VAR}_${y}.nc"
  OUTY="$OUTDIR/kirg_${SCALE}_${VAR}_${y}.nc"
  LOG="$LOGDIR/kirg_${SCALE}_${VAR}_${y}.log"

  if [[ -f "$OUTY" ]]; then
    echo "✔ Ya existe: $OUTY (skip)"
    continue
  fi

  t0=$(date +%s)

  cdo -O -f nc4c selyear,${y} "$SRC" "$SRCY"
  cdo -O -f nc4c selyear,${y} "$TGT" "$TGTY"

  /usr/bin/time -v python "$SPY" \
    --src "$SRCY" --tgt "$TGTY" --out "$OUTY" \
    --varname "$VAR" --nclosest "$NCLOSE" --variogram "$VARTO" --compress "$COMP" \
    2>&1 | tee "$LOG"

  rm -f "$SRCY" "$TGTY"

  t1=$(date +%s)
  dt=$((t1 - t0))
  h=$((dt/3600)); m=$(((dt%3600)/60)); s=$((dt%60))

  elapsed_all=$((t1 - START_ALL))
  rem=$((TOTAL_YEARS - i))
  eta=$(( (elapsed_all / i) * rem ))
  eh=$((eta/3600)); em=$(((eta%3600)/60)); es=$((eta%60))

  echo "✅ Año ${y} listo: $OUTY"
  printf "🕒 Año %d: %02d:%02d:%02d | Total: %02d:%02d:%02d | ETA: %02d:%02d:%02d\n" \
    "$y" "$h" "$m" "$s" \
    $((elapsed_all/3600)) $(((elapsed_all%3600)/60)) $((elapsed_all%60)) \
    "$eh" "$em" "$es"
done

echo "🎉 Terminado escala ${SCALE} (${VAR})"
