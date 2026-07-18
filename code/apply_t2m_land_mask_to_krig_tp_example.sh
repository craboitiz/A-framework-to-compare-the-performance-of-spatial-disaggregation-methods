# Applies a land/sea mask from a masked t2m KRIG file to a KRIG precipitation file.
# The script writes a clean NetCDF output, preserves coordinates and metadata,
# removes non-finite values, and writes masked cells using a consistent fill value.
# To adapt it, change SCALE, BASE_TP, MASK, VAR, MASK_VAR, input/output filenames,
# and CHUNK_TIME if memory usage needs adjustment.

#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# CONFIGURACIÓN
# Cambia SOLO esta escala
# ============================================================

SCALE="02"   # opciones: 02 05 10 15 20 25

BASE_TP="/media/sf_Cristobal_Aboitiz/Paper/KRIG/tp/tp"

# Archivo t2m masked usado SOLO para definir tierra/mar
MASK="/media/sf_Cristobal_Aboitiz/Paper/KRIG/tp/tp/krig_15_t2m_masked.nc"

VAR="tp"
MASK_VAR="t2m"

SCALEDIR="$BASE_TP/$SCALE"

INFILE="$SCALEDIR/kirg_${SCALE}_${VAR}_1960_2021.nc"
OUTFILE="$SCALEDIR/krig_${SCALE}_${VAR}_masked.nc"

CHUNK_TIME=5

echo "=============================================="
echo "MASK TP DESDE T2M MASKED - SAFE V2"
echo "Escala : $SCALE"
echo "Mask   : $MASK"
echo "Input  : $INFILE"
echo "Output : $OUTFILE"
echo "=============================================="
echo

if [[ ! -f "$MASK" ]]; then
  echo "ERROR: no existe MASK:"
  echo "$MASK"
  exit 1
fi

if [[ ! -f "$INFILE" ]]; then
  echo "ERROR: no existe INFILE:"
  echo "$INFILE"
  exit 1
fi

echo "Borrando output anterior si existe..."
rm -f "$OUTFILE"

export INFILE OUTFILE MASK VAR MASK_VAR CHUNK_TIME

python3 - <<'PY'
import os
import numpy as np
from netCDF4 import Dataset

infile = os.environ["INFILE"]
outfile = os.environ["OUTFILE"]
maskfile = os.environ["MASK"]
varname = os.environ["VAR"]
mask_varname = os.environ["MASK_VAR"]
chunk_time = int(os.environ.get("CHUNK_TIME", "5"))

FILL = np.float32(9.969209968386869e36)

SKIP_ATTRS = {
    "_FillValue",
    "missing_value",
    "scale_factor",
    "add_offset",
    "valid_min",
    "valid_max",
    "valid_range",
    "actual_range",
}

def copy_global_attrs(src, dst):
    for att in src.ncattrs():
        try:
            dst.setncattr(att, src.getncattr(att))
        except Exception:
            pass

def copy_var_attrs_clean(src_var, dst_var):
    for att in src_var.ncattrs():
        if att in SKIP_ATTRS:
            continue
        try:
            dst_var.setncattr(att, src_var.getncattr(att))
        except Exception:
            pass

def get_time_axis(dims):
    if "time" not in dims:
        raise RuntimeError(f"No encontré dimensión time en {dims}")
    return dims.index("time")

def first_time_slice(var, dims):
    sl = [slice(None)] * len(dims)
    sl[get_time_axis(dims)] = 0
    return tuple(sl)

with Dataset(infile, "r") as src, Dataset(maskfile, "r") as msk:

    if varname not in src.variables:
        raise RuntimeError(f"No existe variable '{varname}' en input. Variables: {list(src.variables.keys())}")

    if mask_varname not in msk.variables:
        raise RuntimeError(f"No existe variable '{mask_varname}' en mask. Variables: {list(msk.variables.keys())}")

    src_var = src.variables[varname]
    mask_var = msk.variables[mask_varname]

    src.set_auto_maskandscale(True)
    msk.set_auto_maskandscale(True)

    src_dims = src_var.dimensions
    mask_dims = mask_var.dimensions

    if src_dims != mask_dims:
        raise RuntimeError(
            "Las dimensiones de input y mask no coinciden exactamente.\n"
            f"Input dims: {src_dims}\n"
            f"Mask dims : {mask_dims}\n"
        )

    time_axis = get_time_axis(src_dims)
    nt = src.dimensions["time"].size

    print("Input variable:", varname)
    print("Mask variable :", mask_varname)
    print("Dims          :", src_dims)
    print("Timesteps     :", nt)
    print("Chunk time    :", chunk_time)

    # ========================================================
    # Crear máscara espacial 2D desde el primer timestep de t2m
    # ========================================================
    mask_first_ma = np.ma.array(mask_var[first_time_slice(mask_var, mask_dims)])
    mask_first = np.asarray(mask_first_ma.filled(np.nan), dtype=np.float64)
    mask_missing = np.ma.getmaskarray(mask_first_ma)

    spatial_valid = np.isfinite(mask_first) & (~mask_missing)

    valid_cells = int(np.sum(spatial_valid))
    total_cells = int(spatial_valid.size)

    print("Celdas válidas en mask espacial:", valid_cells, "de", total_cells)

    if valid_cells == 0:
        raise RuntimeError("La máscara espacial no tiene ninguna celda válida. Revisa MASK/MASK_VAR.")

    # Expandir máscara para aplicarla a bloques con tiempo
    # src_dims = normalmente ('time', 'latitude', 'longitude')
    spatial_shape = spatial_valid.shape

    with Dataset(outfile, "w", format="NETCDF4") as dst:

        copy_global_attrs(src, dst)
        dst.setncattr("mask_source", maskfile)
        dst.setncattr("mask_variable", mask_varname)
        dst.setncattr("mask_method", "2D spatial mask from first timestep of t2m masked file")
        dst.setncattr("nonfinite_values", "Inf and NaN in tp written as missing")
        dst.setncattr("note", "Output variable written as float32 without scale_factor/add_offset packing")

        # Crear dimensiones
        for dname, dim in src.dimensions.items():
            dst.createDimension(dname, None if dim.isunlimited() else len(dim))

        # Copiar coordenadas y variables auxiliares excepto tp
        for vname, v in src.variables.items():
            if vname == varname:
                continue

            fill_value = None
            if "_FillValue" in v.ncattrs():
                fill_value = v.getncattr("_FillValue")

            if fill_value is None:
                outv = dst.createVariable(vname, v.datatype, v.dimensions)
            else:
                outv = dst.createVariable(vname, v.datatype, v.dimensions, fill_value=fill_value)

            copy_var_attrs_clean(v, outv)
            outv[:] = v[:]

        # Crear variable tp limpia
        chunksizes = []
        for d in src_dims:
            if d == "time":
                chunksizes.append(min(chunk_time, nt))
            else:
                chunksizes.append(src.dimensions[d].size)

        out_var = dst.createVariable(
            varname,
            "f4",
            src_dims,
            zlib=True,
            complevel=4,
            shuffle=True,
            chunksizes=tuple(chunksizes),
            fill_value=FILL
        )

        copy_var_attrs_clean(src_var, out_var)
        out_var.setncattr("missing_value", FILL)

        total_nonfinite = 0
        total_masked_space = 0
        total_written_valid = 0

        for t0 in range(0, nt, chunk_time):
            t1 = min(t0 + chunk_time, nt)

            sl = [slice(None)] * len(src_dims)
            sl[time_axis] = slice(t0, t1)
            sl = tuple(sl)

            data_ma = np.ma.array(src_var[sl])
            data_vals = np.asarray(data_ma.filled(np.nan), dtype=np.float64)
            data_missing = np.ma.getmaskarray(data_ma)

            nonfinite_data = ~np.isfinite(data_vals)

            # Armar máscara espacial con dimensión tiempo
            if time_axis == 0:
                spatial_invalid_block = np.broadcast_to(~spatial_valid, data_vals.shape)
            elif time_axis == 2:
                spatial_invalid_block = np.broadcast_to((~spatial_valid)[:, :, None], data_vals.shape)
            else:
                raise RuntimeError(f"Orden de dimensiones no contemplado: {src_dims}")

            final_missing = data_missing | nonfinite_data | spatial_invalid_block

            total_nonfinite += int(np.sum(nonfinite_data & ~data_missing))
            total_masked_space += int(np.sum(spatial_invalid_block))
            total_written_valid += int(np.sum(~final_missing))

            out_vals = data_vals.astype(np.float32)
            out_vals[final_missing] = FILL

            out_var[sl] = out_vals

            if t0 == 0:
                vals0 = out_vals[~final_missing]
                print("Primer bloque output:")
                print("  valid n:", vals0.size)
                print("  min:", float(np.min(vals0)) if vals0.size else np.nan)
                print("  max:", float(np.max(vals0)) if vals0.size else np.nan)
                print("  sd :", float(np.std(vals0)) if vals0.size else np.nan)

            print(f"Procesado timestep {t0 + 1} a {t1} de {nt}")

        print("==============================================")
        print("Resumen:")
        print("Valores Inf/NaN en input tp convertidos a missing:", total_nonfinite)
        print("Valores enmascarados espacialmente:", total_masked_space)
        print("Valores válidos escritos:", total_written_valid)
        print("Output:", outfile)
        print("==============================================")
PY

echo
echo "✅ Mask listo:"
echo "$OUTFILE"

echo
echo "Verificación con CDO:"
cdo showname "$OUTFILE"
cdo ntime "$OUTFILE"

echo
echo "Verificación con Python:"
python3 - <<'PY'
import os
import numpy as np
from netCDF4 import Dataset

outfile = os.environ["OUTFILE"]
varname = os.environ["VAR"]

with Dataset(outfile, "r") as ds:
    v = ds.variables[varname]
    dims = v.dimensions
    t_axis = dims.index("time")

    sl = [slice(None)] * len(dims)
    sl[t_axis] = 0

    arr = np.ma.array(v[tuple(sl)])
    vals = np.asarray(arr.filled(np.nan), dtype=np.float64)
    vals = vals[np.isfinite(vals)]

    print("Primer timestep output:")
    print("  n valid:", vals.size)
    if vals.size > 0:
        print("  min:", float(np.min(vals)))
        print("  max:", float(np.max(vals)))
        print("  mean:", float(np.mean(vals)))
        print("  sd:", float(np.std(vals)))
        print("  valores únicos aprox:", len(np.unique(np.round(vals, 6))))
PY

echo
echo "Proceso terminado."