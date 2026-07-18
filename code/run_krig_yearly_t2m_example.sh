#!/usr/bin/env bash
set -euo pipefail

# Example wrapper to run ordinary kriging year by year for ERA5-Land t2m.
# The script extracts one year at a time from the source and target NetCDF files,
# calls krige_fixed_variogram.py, saves yearly KRIG outputs, logs runtime,
# and allows restarting from a selected year.
# To adapt it, change SCALE, VAR, SRC, TGT, path to the Python script, NCLOSE,
# variogram model, compression level, Y0/Y1, work/output folders, filename pattern,
# and add/remove --no-log1p depending on the variable.

# ============================================================
# CONFIGURATION
# ============================================================

SCALE="10"
# SCALE="02"
# SCALE="05"
# SCALE="15"
# SCALE="20"
# SCALE="25"

VAR="t2m"

# Coarse source file and fine target/reference grid.
# These files should be in the folder where this script is executed,
# unless absolute paths are provided.
SRC="${SCALE}_ERA5_${VAR}_1960_2021.nc"
TGT="ERA5_${VAR}_1960_2021.nc"

# Generic kriging script.
# Use the version included in this repository.
SPY="./krige_fixed_variogram.py"

NCLOSE=36
VARTO="spherical"
COMP=4

# Years to process.
# Change Y0 to resume from a later year.
Y0=1960
Y1=2021

# Output folder.
WORK="./krig_${VAR}/${SCALE}"
TMP="$WORK/tmp"
OUTDIR="$WORK/yearly"
LOGDIR="$WORK/logs"

mkdir -p "$TMP" "$OUTDIR" "$LOGDIR"

# ============================================================
# CHECKS
# ============================================================

if [[ ! -f "$SPY" ]]; then
  echo "ERROR: kriging Python script not found:"
  echo "$SPY"
  exit 1
fi

if [[ ! -f "$SRC" ]]; then
  echo "ERROR: source file not found:"
  echo "$SRC"
  exit 1
fi

if [[ ! -f "$TGT" ]]; then
  echo "ERROR: target file not found:"
  echo "$TGT"
  exit 1
fi

command -v cdo >/dev/null 2>&1 || { echo "ERROR: cdo is not installed or not in PATH."; exit 1; }
command -v python >/dev/null 2>&1 || { echo "ERROR: python is not installed or not in PATH."; exit 1; }

# ============================================================
# RUN YEAR BY YEAR
# ============================================================

TOTAL_YEARS=$((Y1 - Y0 + 1))
START_ALL=$(date +%s)

for ((y=Y0; y<=Y1; y++)); do
  i=$((y - Y0 + 1))

  echo "=============================="
  echo "Year ${i}/${TOTAL_YEARS} (Y=${y}) | Scale=${SCALE} | Var=${VAR}"
  echo "=============================="

  SRCY="$TMP/SRC_${SCALE}_${VAR}_${y}.nc"
  TGTY="$TMP/TGT_${VAR}_${y}.nc"
  OUTY="$OUTDIR/krig_${SCALE}_${VAR}_${y}.nc"
  LOG="$LOGDIR/krig_${SCALE}_${VAR}_${y}.log"

  if [[ -f "$OUTY" ]]; then
    echo "Already exists, skipping:"
    echo "$OUTY"
    continue
  fi

  t0=$(date +%s)

  cdo -O -f nc4c selyear,${y} "$SRC" "$SRCY"
  cdo -O -f nc4c selyear,${y} "$TGT" "$TGTY"

  /usr/bin/time -v python "$SPY" \
    --src "$SRCY" \
    --tgt "$TGTY" \
    --out "$OUTY" \
    --varname "$VAR" \
    --nclosest "$NCLOSE" \
    --variogram "$VARTO" \
    --compress "$COMP" \
    --no-log1p \
    2>&1 | tee "$LOG"

  rm -f "$SRCY" "$TGTY"

  t1=$(date +%s)
  dt=$((t1 - t0))
  h=$((dt/3600))
  m=$(((dt%3600)/60))
  s=$((dt%60))

  elapsed_all=$((t1 - START_ALL))
  rem=$((TOTAL_YEARS - i))
  eta=$(( (elapsed_all / i) * rem ))
  eh=$((eta/3600))
  em=$(((eta%3600)/60))
  es=$((eta%60))

  echo "Finished year ${y}: $OUTY"
  printf "Runtime year %d: %02d:%02d:%02d | Total: %02d:%02d:%02d | ETA: %02d:%02d:%02d\n" \
    "$y" "$h" "$m" "$s" \
    $((elapsed_all/3600)) $(((elapsed_all%3600)/60)) $((elapsed_all%60)) \
    "$eh" "$em" "$es"
done

echo "Finished scale ${SCALE} (${VAR})."
