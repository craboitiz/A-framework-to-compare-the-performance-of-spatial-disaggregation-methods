# Computes daily spatial percentile series for ERA5-Land precipitation and KRIG outputs.
# For each day, the script calculates spatial P95 and P05 values over the domain,
# along with the number of valid and removed cells.
# To adapt it, change base_dir, orig_file, the list of KRIG files/scales,
# output filename, precipitation variable names, valid-value limits, and chunk_size.

library(openxlsx)

rm(list = ls())
graphics.off()

# =========================
# Configuraci?n
# =========================
base_dir <- "G:/Cristobal_Aboitiz/Paper/KRIG/tp/tp"
metrics_dir <- file.path(base_dir, "metrics")

orig_file <- file.path(base_dir, "ERA5_pr_1960_2021.nc")

files <- c(
  ERA5   = orig_file,
  krig02 = file.path(base_dir, "02", "krig_02_tp_masked.nc"),
  krig05 = file.path(base_dir, "05", "krig_05_tp_masked.nc"),
  krig10 = file.path(base_dir, "10", "krig_10_tp_masked.nc"),
  krig15 = file.path(base_dir, "15", "krig_15_tp_masked.nc"),
  krig20 = file.path(base_dir, "20", "krig_20_tp_masked.nc"),
  krig25 = file.path(base_dir, "25", "krig_25_tp_masked.nc")
)

out_xlsx <- file.path(metrics_dir, "series_percentiles_espaciales_tp.xlsx")

# Tama?o del bloque de lectura en timesteps
chunk_size <- 10

# =========================
# Limpieza para tp
# =========================
# tp est? en metros. Valores negativos, Inf, NaN, fill values o valores absurdos
# se consideran NA antes de calcular percentiles espaciales.
TP_MIN_VALID <- 0
TP_MAX_VALID <- 10

# =========================
# Helpers
# =========================
guess_main_var <- function(nc, preferred = NULL) {
  vars <- names(nc$var)
  
  if (!is.null(preferred)) {
    for (p in preferred) {
      if (p %in% vars) return(p)
    }
  }
  
  drop_candidates <- c(
    "lon", "longitude", "lat", "latitude", "time", "valid_time",
    "time_bnds", "time_bounds",
    "lon_bnds", "lon_bounds",
    "lat_bnds", "lat_bounds",
    "bounds"
  )
  
  vars2 <- vars[!tolower(vars) %in% drop_candidates]
  
  if (length(vars2) == 0) return(vars[1])
  vars2[1]
}

find_dim_pos <- function(dim_names, candidates) {
  dim_low <- tolower(dim_names)
  hit <- which(dim_low %in% candidates)
  if (length(hit) == 0) return(NA_integer_)
  hit[1]
}

parse_nc_time <- function(nc) {
  if (!"time" %in% names(nc$dim) && !"time" %in% names(nc$var)) {
    return(NULL)
  }
  
  time_vals <- tryCatch(ncvar_get(nc, "time"), error = function(e) NULL)
  if (is.null(time_vals)) return(NULL)
  
  att <- ncatt_get(nc, "time", "units")
  if (is.null(att$value)) return(NULL)
  
  units_str <- att$value
  
  m <- regexec(
    "^(hours|days|seconds) since ([0-9]{4}-[0-9]{2}-[0-9]{2})([ T]([0-9]{2}:[0-9]{2}:[0-9]{2}))?$",
    units_str
  )
  
  reg <- regmatches(units_str, m)[[1]]
  
  if (length(reg) == 0) return(NULL)
  
  unit <- reg[2]
  date_part <- reg[3]
  time_part <- ifelse(length(reg) >= 5 && nzchar(reg[5]), reg[5], "00:00:00")
  
  origin <- as.POSIXct(paste(date_part, time_part), tz = "UTC")
  
  if (unit == "hours") {
    dates <- origin + time_vals * 3600
  } else if (unit == "days") {
    dates <- origin + time_vals * 86400
  } else if (unit == "seconds") {
    dates <- origin + time_vals
  } else {
    return(NULL)
  }
  
  as.POSIXct(dates, origin = "1970-01-01", tz = "UTC")
}

clean_tp_values <- function(vals) {
  vals[!is.finite(vals)] <- NA
  vals[vals < TP_MIN_VALID | vals > TP_MAX_VALID] <- NA
  vals
}

compute_spatial_percentile_series <- function(nc_file, label, dates_ref = NULL, chunk_size = 10) {
  
  cat("====================================\n")
  cat("Archivo:", label, "\n")
  cat("Ruta   :", nc_file, "\n")
  
  if (!file.exists(nc_file)) {
    stop("No existe el archivo: ", nc_file)
  }
  
  nc <- nc_open(nc_file)
  on.exit(nc_close(nc))
  
  var_name <- guess_main_var(
    nc,
    preferred = c("tp", "pr", "precip", "precipitation")
  )
  
  cat("Variable detectada:", var_name, "\n")
  
  var_obj <- nc$var[[var_name]]
  var_dims <- sapply(var_obj$dim, function(x) x$name)
  dims_len <- sapply(var_obj$dim, function(x) x$len)
  
  if (length(dims_len) != 3) {
    stop(
      "Se esperaban 3 dimensiones en ", label,
      ". Se detectaron: ", paste(var_dims, collapse = ", ")
    )
  }
  
  lon_pos  <- find_dim_pos(var_dims, c("lon", "longitude", "x"))
  lat_pos  <- find_dim_pos(var_dims, c("lat", "latitude", "y"))
  time_pos <- find_dim_pos(var_dims, c("time", "valid_time", "t"))
  
  if (is.na(lon_pos) || is.na(lat_pos) || is.na(time_pos)) {
    stop(
      "No pude identificar lon/lat/time en ", label, "\n",
      "Dimensiones detectadas: ", paste(var_dims, collapse = ", ")
    )
  }
  
  nx <- dims_len[lon_pos]
  ny <- dims_len[lat_pos]
  nt <- dims_len[time_pos]
  
  cat("Dims:", paste(var_dims, collapse = " x "), "\n")
  cat("Tama?o lon x lat x time:", nx, "x", ny, "x", nt, "\n")
  
  dates <- parse_nc_time(nc)
  
  if (is.null(dates)) {
    if (!is.null(dates_ref) && length(dates_ref) == nt) {
      dates <- dates_ref
    } else {
      dates <- seq_len(nt)
    }
  }
  
  p95 <- rep(NA_real_, nt)
  p05 <- rep(NA_real_, nt)
  
  n_valid <- rep(NA_integer_, nt)
  n_removed <- rep(NA_integer_, nt)
  
  last_year <- NA_character_
  
  starts <- seq(1, nt, by = chunk_size)
  
  for (s in starts) {
    
    count_t <- min(chunk_size, nt - s + 1)
    
    start_vec <- rep(1, length(dims_len))
    count_vec <- dims_len
    
    start_vec[time_pos] <- s
    count_vec[time_pos] <- count_t
    
    block <- ncvar_get(
      nc,
      var_name,
      start = start_vec,
      count = count_vec,
      collapse_degen = FALSE
    )
    
    if (length(dim(block)) == 2) {
      tmp_dim <- dims_len
      tmp_dim[time_pos] <- 1
      block <- array(block, dim = tmp_dim)
    }
    
    # Reordenar bloque siempre a lon x lat x time
    block <- aperm(block, c(lon_pos, lat_pos, time_pos))
    
    for (k in 1:count_t) {
      
      t_idx <- s + k - 1
      
      vals_raw <- as.vector(block[, , k])
      n_total <- length(vals_raw)
      
      vals <- clean_tp_values(vals_raw)
      vals <- vals[!is.na(vals)]
      
      n_valid[t_idx] <- length(vals)
      n_removed[t_idx] <- n_total - length(vals)
      
      if (length(vals) > 0) {
        p95[t_idx] <- as.numeric(
          quantile(vals, probs = 0.95, na.rm = TRUE, type = 7)
        )
        
        p05[t_idx] <- as.numeric(
          quantile(vals, probs = 0.05, na.rm = TRUE, type = 7)
        )
      }
      
      if (inherits(dates, "POSIXct")) {
        yy <- format(dates[t_idx], "%Y")
        if (!identical(yy, last_year)) {
          cat(label, "- a?o", yy, "\n")
          last_year <- yy
        }
      }
    }
  }
  
  list(
    dates = dates,
    p95 = p95,
    p05 = p05,
    n_valid = n_valid,
    n_removed = n_removed
  )
}

# =========================
# Revisar archivos
# =========================
cat("====================================\n")
cat("SERIES PERCENTILES ESPACIALES TP\n")
cat("base_dir:", base_dir, "\n")
cat("metrics_dir:", metrics_dir, "\n")
cat("output:", out_xlsx, "\n")
cat("Filtro tp v?lido:", TP_MIN_VALID, "a", TP_MAX_VALID, "m\n")
cat("====================================\n\n")

if (!dir.exists(metrics_dir)) {
  dir.create(metrics_dir, recursive = TRUE)
}

if (!file.exists(orig_file)) {
  stop("No existe el archivo original: ", orig_file)
}

for (nm in names(files)) {
  if (!file.exists(files[[nm]])) {
    stop("Falta archivo para ", nm, ": ", files[[nm]])
  }
}

# =========================
# Obtener fechas de referencia desde ERA5
# =========================
nc_ref <- nc_open(orig_file)
dates_ref <- parse_nc_time(nc_ref)
nc_close(nc_ref)

# =========================
# Procesar archivos
# =========================
results <- list()

for (nm in names(files)) {
  results[[nm]] <- compute_spatial_percentile_series(
    nc_file = files[[nm]],
    label = nm,
    dates_ref = dates_ref,
    chunk_size = chunk_size
  )
}

# =========================
# Armar tablas finales
# =========================
if (inherits(results[[1]]$dates, "POSIXct")) {
  date_col <- as.Date(results[[1]]$dates)
} else {
  date_col <- results[[1]]$dates
}

df_p95 <- data.frame(Date = date_col)
df_p05 <- data.frame(Date = date_col)
df_n_valid <- data.frame(Date = date_col)
df_n_removed <- data.frame(Date = date_col)

for (nm in names(results)) {
  df_p95[[nm]] <- results[[nm]]$p95
  df_p05[[nm]] <- results[[nm]]$p05
  df_n_valid[[nm]] <- results[[nm]]$n_valid
  df_n_removed[[nm]] <- results[[nm]]$n_removed
}

# =========================
# Guardar Excel
# =========================
wb <- createWorkbook()

addWorksheet(wb, "P95")
writeData(wb, "P95", df_p95, colNames = TRUE, rowNames = FALSE)

addWorksheet(wb, "P05")
writeData(wb, "P05", df_p05, colNames = TRUE, rowNames = FALSE)

addWorksheet(wb, "N_valid")
writeData(wb, "N_valid", df_n_valid, colNames = TRUE, rowNames = FALSE)

addWorksheet(wb, "N_removed")
writeData(wb, "N_removed", df_n_removed, colNames = TRUE, rowNames = FALSE)

saveWorkbook(wb, out_xlsx, overwrite = TRUE)

cat("====================================\n")
cat("Listo.\n")
cat("Excel guardado en:\n")
cat(out_xlsx, "\n")
cat("====================================\n")