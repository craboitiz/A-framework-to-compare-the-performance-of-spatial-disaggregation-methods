# Performs ordinary kriging from a coarse source grid to a target fine grid using PyKrige.
# The variogram is fitted once using the first valid timestep and then reused for all timesteps.
# By default, log1p/expm1 is applied for precipitation to avoid negative predictions.
# To adapt it, change --src, --tgt, --out, --varname, --nclosest,
# --variogram, --compress, and use --no-log1p for variables such as temperature.

import argparse, numpy as np, xarray as xr
from pykrige.ok import OrdinaryKriging


def pick_xy(ds):
    for x in ["lon","longitude","x"]:
        if x in ds.coords:
            break
    else:
        raise ValueError("No encuentro coord lon/longitude/x")

    for y in ["lat","latitude","y"]:
        if y in ds.coords:
            break
    else:
        raise ValueError("No encuentro coord lat/latitude/y")

    return x, y


ap = argparse.ArgumentParser()
ap.add_argument("--src", required=True)
ap.add_argument("--tgt", required=True)
ap.add_argument("--out", required=True)
ap.add_argument("--varname", default="pr")
ap.add_argument("--nclosest", type=int, default=36)
ap.add_argument("--variogram", default="spherical",
               choices=["spherical","exponential","gaussian","linear","power"])
ap.add_argument("--compress", type=int, default=4)

# Transformación recomendada para precip
ap.add_argument("--no-log1p", action="store_true",
                help="Desactiva log1p/expm1 (por defecto se aplica para pr).")

args = ap.parse_args()

ds_s = xr.open_dataset(args.src)
ds_t = xr.open_dataset(args.tgt)
xs, ys = pick_xy(ds_s)
xt, yt = pick_xy(ds_t)

if args.varname not in ds_s:
    raise ValueError(f"No existe variable '{args.varname}' en SRC. Vars: {list(ds_s.data_vars)}")

V = ds_s[args.varname]
time = ds_s["time"].values

lon_s = ds_s[xs].values; lat_s = ds_s[ys].values
lon_t = ds_t[xt].values; lat_t = ds_t[yt].values

LONs, LATs = np.meshgrid(lon_s, lat_s)
LONt, LATt = np.meshgrid(lon_t, lat_t)

lat0s = float(np.nanmean(lat_s))
lat0t = float(np.nanmean(lat_t))

# proyección simple lon*cos(lat0), lat (como en t2m)
x_s = LONs * np.cos(np.deg2rad(lat0s)); y_s = LATs
x_t = LONt * np.cos(np.deg2rad(lat0t)); y_t = LATt

out_data = np.full((time.size, lat_t.size, lon_t.size), np.nan, dtype=np.float32)

use_log1p = (not args.no_log1p)

def fwd(z):
    # log1p para precip: estabiliza y evita negativos
    if not use_log1p:
        return z
    z = np.asarray(z, dtype=np.float64)
    z = np.clip(z, 0, None)
    return np.log1p(z)

def inv(z):
    if not use_log1p:
        return z
    z = np.asarray(z, dtype=np.float64)
    z = np.expm1(z)
    return np.clip(z, 0, None)

# Fit variograma UNA vez y reutilizar
vario_params = None
for i in range(time.size):
    z2d = V.isel(time=i).values.astype("float64")
    z = z2d.reshape(-1)
    m = np.isfinite(z)

    if m.sum() >= max(20, min(args.nclosest, int(m.sum()))):
        zfit = fwd(z[m])

        OK0 = OrdinaryKriging(
            x_s.reshape(-1)[m], y_s.reshape(-1)[m], zfit,
            variogram_model=args.variogram,
            verbose=False, enable_plotting=False
        )
        vario_params = OK0.variogram_model_parameters.tolist()
        break

if vario_params is None:
    raise RuntimeError("No pude ajustar variograma inicial (demasiados NaN?)")

print("Variogram params (fixed):", vario_params)
print("log1p:", use_log1p)

for i in range(time.size):
    z2d = V.isel(time=i).values.astype("float64")
    z = z2d.reshape(-1)
    m = np.isfinite(z)
    if m.sum() < 10:
        continue

    ztrain = fwd(z[m])

    OK = OrdinaryKriging(
        x_s.reshape(-1)[m], y_s.reshape(-1)[m], ztrain,
        variogram_model=args.variogram,
        variogram_parameters=vario_params,
        verbose=False, enable_plotting=False
    )

    pred, _ = OK.execute(
        "grid",
        xpoints=x_t[0, :],
        ypoints=y_t[:, 0],
        n_closest_points=min(args.nclosest, int(m.sum())),
        backend="loop",
    )

    out_data[i, :, :] = np.asarray(inv(pred), dtype=np.float32)

ds_out = xr.Dataset(
    {args.varname: (("time", yt, xt), out_data)},
    coords={"time": time, yt: lat_t, xt: lon_t},
)

enc = {}
if args.compress and args.compress > 0:
    enc = {args.varname: {"zlib": True, "complevel": int(args.compress), "dtype": "float32"}}

ds_out.to_netcdf(args.out, encoding=enc)
print("Wrote:", args.out)
