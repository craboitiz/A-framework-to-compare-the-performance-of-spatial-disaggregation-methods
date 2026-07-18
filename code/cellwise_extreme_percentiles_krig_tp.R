# Computes cell-wise precipitation extreme percentile diagnostics for KRIG outputs.
# For each scale, the script compares ERA5-Land precipitation with KRIG precipitation
# and exports P95, P5, bias, absolute error, and valid-count maps.
# To adapt it, change base_dir, orig_file, scales, VAR_NAME, precipitation valid-value
# limits, MIN_VALID, output filenames, and preferred variable names.

library(ncdf4)
library(openxlsx)

rm(list = ls())
graphics.off()

# =========================
# Configuraci?n
# =========================
base_dir <- "G:/Cristobal_Aboitiz/Paper/KRIG/tp/tp"
metrics_dir <- file.path(base_dir, "metrics")

orig_file <- file.path(base_dir, "ERA5_pr_1960_2021.nc")

scales <- c("02", "05", "10", "15", "20", "25")

VAR_NAME <- "tp"

# tp est? en metros.
# Valores negativos, Inf, NaN, fill values o valores diarios absurdos se consideran NA.
TP_MIN_VALID <- 0
TP_MAX_VALID <- 10

# M?nimo de datos v?lidos para calcular percentiles por celda
MIN_VALID <- 30

# -------------------------
# Helpers
# -------------------------
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

open_nc_info <- function(file, label) {
  
  if (!file.exists(file)) {
    stop("No existe el archivo ", label, ": ", file)
  }
  
  nc <- nc_open(file)
  
  var_name <- guess_main_var(
    nc,
    preferred = c("tp", "pr", "precip", "precipitation")
  )
  
  var_obj <- nc$var[[var_name]]
  dim_names <- sapply(var_obj$dim, function(d) d$name)
  dim_vals  <- lapply(var_obj$dim, function(d) d$vals)
  dims_len  <- sapply(var_obj$dim, function(d) d$len)
  
  lon_pos  <- find_dim_pos(dim_names, c("lon", "longitude", "x"))
  lat_pos  <- find_dim_pos(dim_names, c("lat", "latitude", "y"))
  time_pos <- find_dim_pos(dim_names, c("time", "valid_time", "t"))
  
  if (is.na(lon_pos) || is.na(lat_pos) || is.na(time_pos)) {
    nc_close(nc)
    stop(
      "No pude identificar lon/lat/time en ", label, "\n",
      "Variable: ", var_name, "\n",
      "Dimensiones: ", paste(dim_names, collapse = ", ")
    )
  }
  
  info <- list(
    nc = nc,
    file = file,
    label = label,
    var_name = var_name,
    dim_names = dim_names,
    dims_len = dims_len,
    lon_pos = lon_pos,
    lat_pos = lat_pos,
    time_pos = time_pos,
    lon = dim_vals[[lon_pos]],
    lat = dim_vals[[lat_pos]],
    time = dim_vals[[time_pos]],
    n_lon = dims_len[lon_pos],
    n_lat = dims_len[lat_pos],
    n_time = dims_len[time_pos]
  )
  
  return(info)
}

coords_same <- function(a, b, tol = 1e-4) {
  if (length(a) != length(b)) return(FALSE)
  max(abs(a - b), na.rm = TRUE) < tol
}

make_index_map <- function(ref_vec, comp_vec, label = "") {
  if (length(ref_vec) != length(comp_vec)) {
    stop("Largo distinto en ", label, ": ref=", length(ref_vec), " comp=", length(comp_vec))
  }
  
  if (coords_same(ref_vec, comp_vec)) {
    return(seq_along(ref_vec))
  }
  
  if (coords_same(ref_vec, rev(comp_vec))) {
    return(rev(seq_along(ref_vec)))
  }
  
  cat("Advertencia: coordenadas no coinciden exactamente en", label, "\n")
  cat("Se usar? el mismo orden de ?ndices.\n")
  return(seq_along(ref_vec))
}

read_lon_block <- function(info, lon_index) {
  
  start_vec <- rep(1, length(info$dims_len))
  count_vec <- info$dims_len
  
  start_vec[info$lon_pos] <- lon_index
  count_vec[info$lon_pos] <- 1
  
  block <- ncvar_get(
    info$nc,
    info$var_name,
    start = start_vec,
    count = count_vec,
    collapse_degen = FALSE
  )
  
  # Reordenar a lon x lat x time
  block <- aperm(block, c(info$lon_pos, info$lat_pos, info$time_pos))
  
  # Quitar la dimensi?n lon = 1
  block_mat <- matrix(
    block[1, , ],
    nrow = info$n_lat,
    ncol = info$n_time
  )
  
  return(block_mat)
}

clean_tp_series <- function(x) {
  x[!is.finite(x)] <- NA
  x[x < TP_MIN_VALID | x > TP_MAX_VALID] <- NA
  x <- x[!is.na(x)]
  return(x)
}

safe_quantile <- function(x, prob) {
  if (length(x) < MIN_VALID) return(NA_real_)
  out <- tryCatch(
    as.numeric(quantile(x, probs = prob, na.rm = TRUE, type = 7)),
    error = function(e) NA_real_
  )
  if (!is.finite(out)) return(NA_real_)
  out
}

# =========================
# Revisar carpetas
# =========================
cat("====================================\n")
cat("EXTREMES PERCENTILES KRIG TP\n")
cat("base_dir   :", base_dir, "\n")
cat("metrics_dir:", metrics_dir, "\n")
cat("orig_file  :", orig_file, "\n")
cat("scales     :", paste(scales, collapse = ", "), "\n")
cat("Filtro tp  :", TP_MIN_VALID, "a", TP_MAX_VALID, "m\n")
cat("MIN_VALID  :", MIN_VALID, "\n")
cat("====================================\n\n")

if (!dir.exists(metrics_dir)) {
  dir.create(metrics_dir, recursive = TRUE)
}

if (!file.exists(orig_file)) {
  stop("No existe el archivo original: ", orig_file)
}

# =========================
# Loop por escala
# =========================
for (sc in scales) {
  
  gen_file <- file.path(base_dir, sc, paste0("krig_", sc, "_", VAR_NAME, "_masked.nc"))
  
  cat("====================================\n")
  cat("Procesando escala", sc, "\n")
  cat("Original :", orig_file, "\n")
  cat("Generado :", gen_file, "\n")
  cat("====================================\n")
  
  if (!file.exists(gen_file)) {
    cat("No existe:", gen_file, "\n")
    next
  }
  
  ref_info <- open_nc_info(orig_file, "ERA5")
  gen_info <- open_nc_info(gen_file, paste0("krig", sc))
  
  cat("Variable ERA :", ref_info$var_name, "\n")
  cat("Variable KRIG:", gen_info$var_name, "\n")
  cat("Dims ERA     :", paste(ref_info$dim_names, collapse = " x "), "\n")
  cat("Dims KRIG    :", paste(gen_info$dim_names, collapse = " x "), "\n")
  cat("ERA lon x lat x time :", ref_info$n_lon, "x", ref_info$n_lat, "x", ref_info$n_time, "\n")
  cat("KRIG lon x lat x time:", gen_info$n_lon, "x", gen_info$n_lat, "x", gen_info$n_time, "\n")
  
  if (ref_info$n_lon != gen_info$n_lon ||
      ref_info$n_lat != gen_info$n_lat ||
      ref_info$n_time != gen_info$n_time) {
    
    cat("Dimensiones no coinciden en escala", sc, "\n")
    nc_close(ref_info$nc)
    nc_close(gen_info$nc)
    next
  }
  
  lon_map <- make_index_map(ref_info$lon, gen_info$lon, "longitude")
  lat_map <- make_index_map(ref_info$lat, gen_info$lat, "latitude")
  
  n_lon <- ref_info$n_lon
  n_lat <- ref_info$n_lat
  
  # Matrices como latitude x longitude, consistente con los otros outputs
  P95_obs    <- matrix(NA_real_, nrow = n_lat, ncol = n_lon)
  P95_sim    <- matrix(NA_real_, nrow = n_lat, ncol = n_lon)
  Bias_P95   <- matrix(NA_real_, nrow = n_lat, ncol = n_lon)
  AbsErr_P95 <- matrix(NA_real_, nrow = n_lat, ncol = n_lon)
  
  P5_obs     <- matrix(NA_real_, nrow = n_lat, ncol = n_lon)
  P5_sim     <- matrix(NA_real_, nrow = n_lat, ncol = n_lon)
  Bias_P5    <- matrix(NA_real_, nrow = n_lat, ncol = n_lon)
  AbsErr_P5  <- matrix(NA_real_, nrow = n_lat, ncol = n_lon)
  
  N_obs      <- matrix(NA_integer_, nrow = n_lat, ncol = n_lon)
  N_sim      <- matrix(NA_integer_, nrow = n_lat, ncol = n_lon)
  
  total_cells_calculated <- 0
  total_cells_skipped <- 0
  
  for (i in 1:n_lon) {
    
    if (i %% 20 == 0 || i == 1 || i == n_lon) {
      cat("  Lon", i, "de", n_lon, "\n")
    }
    
    obs_block <- read_lon_block(ref_info, i)
    sim_block <- read_lon_block(gen_info, lon_map[i])
    
    # Alinear latitud de KRIG con ERA si est? invertida
    sim_block <- sim_block[lat_map, , drop = FALSE]
    
    for (j in 1:n_lat) {
      
      obs <- clean_tp_series(obs_block[j, ])
      sim <- clean_tp_series(sim_block[j, ])
      
      N_obs[j, i] <- length(obs)
      N_sim[j, i] <- length(sim)
      
      if (length(obs) < MIN_VALID || length(sim) < MIN_VALID) {
        total_cells_skipped <- total_cells_skipped + 1
        next
      }
      
      p95o <- safe_quantile(obs, 0.95)
      p95s <- safe_quantile(sim, 0.95)
      p5o  <- safe_quantile(obs, 0.05)
      p5s  <- safe_quantile(sim, 0.05)
      
      if (!is.na(p95o) && !is.na(p95s)) {
        P95_obs[j, i]    <- p95o
        P95_sim[j, i]    <- p95s
        Bias_P95[j, i]   <- p95s - p95o
        AbsErr_P95[j, i] <- abs(p95s - p95o)
      }
      
      if (!is.na(p5o) && !is.na(p5s)) {
        P5_obs[j, i]    <- p5o
        P5_sim[j, i]    <- p5s
        Bias_P5[j, i]   <- p5s - p5o
        AbsErr_P5[j, i] <- abs(p5s - p5o)
      }
      
      total_cells_calculated <- total_cells_calculated + 1
    }
    
    rm(obs_block, sim_block)
    if (i %% 50 == 0) gc()
  }
  
  nc_close(ref_info$nc)
  nc_close(gen_info$nc)
  
  # Guardar Excel
  out_xlsx <- file.path(
    metrics_dir,
    paste0("extremes_percentiles_krig_", sc, "_", VAR_NAME, ".xlsx")
  )
  
  wb <- createWorkbook()
  
  addWorksheet(wb, "P95_obs");    writeData(wb, "P95_obs", P95_obs, colNames = FALSE, rowNames = FALSE)
  addWorksheet(wb, "P95_sim");    writeData(wb, "P95_sim", P95_sim, colNames = FALSE, rowNames = FALSE)
  addWorksheet(wb, "Bias_P95");   writeData(wb, "Bias_P95", Bias_P95, colNames = FALSE, rowNames = FALSE)
  addWorksheet(wb, "AbsErr_P95"); writeData(wb, "AbsErr_P95", AbsErr_P95, colNames = FALSE, rowNames = FALSE)
  
  addWorksheet(wb, "P5_obs");     writeData(wb, "P5_obs", P5_obs, colNames = FALSE, rowNames = FALSE)
  addWorksheet(wb, "P5_sim");     writeData(wb, "P5_sim", P5_sim, colNames = FALSE, rowNames = FALSE)
  addWorksheet(wb, "Bias_P5");    writeData(wb, "Bias_P5", Bias_P5, colNames = FALSE, rowNames = FALSE)
  addWorksheet(wb, "AbsErr_P5");  writeData(wb, "AbsErr_P5", AbsErr_P5, colNames = FALSE, rowNames = FALSE)
  
  addWorksheet(wb, "N_obs");      writeData(wb, "N_obs", N_obs, colNames = FALSE, rowNames = FALSE)
  addWorksheet(wb, "N_sim");      writeData(wb, "N_sim", N_sim, colNames = FALSE, rowNames = FALSE)
  
  saveWorkbook(wb, out_xlsx, overwrite = TRUE)
  
  # Guardar resumen
  out_txt <- file.path(
    metrics_dir,
    paste0("extremes_percentiles_krig_", sc, "_", VAR_NAME, "_summary.txt")
  )
  
  writeLines(c(
    paste("Scale:", sc),
    paste("Variable:", VAR_NAME),
    paste("Original:", orig_file),
    paste("Generated:", gen_file),
    paste("TP_MIN_VALID:", TP_MIN_VALID),
    paste("TP_MAX_VALID:", TP_MAX_VALID),
    paste("MIN_VALID:", MIN_VALID),
    paste("Cells calculated:", total_cells_calculated),
    paste("Cells skipped:", total_cells_skipped),
    "",
    paste("Mean P95_obs:", mean(P95_obs, na.rm = TRUE)),
    paste("Mean P95_sim:", mean(P95_sim, na.rm = TRUE)),
    paste("Mean Bias_P95:", mean(Bias_P95, na.rm = TRUE)),
    paste("Mean AbsErr_P95:", mean(AbsErr_P95, na.rm = TRUE)),
    paste("Mean P5_obs:", mean(P5_obs, na.rm = TRUE)),
    paste("Mean P5_sim:", mean(P5_sim, na.rm = TRUE)),
    paste("Mean Bias_P5:", mean(Bias_P5, na.rm = TRUE)),
    paste("Mean AbsErr_P5:", mean(AbsErr_P5, na.rm = TRUE))
  ), con = out_txt)
  
  cat("Guardado:", out_xlsx, "\n")
  cat("Guardado:", out_txt, "\n")
  
  rm(
    P95_obs, P95_sim, Bias_P95, AbsErr_P95,
    P5_obs, P5_sim, Bias_P5, AbsErr_P5,
    N_obs, N_sim
  )
  gc()
}

cat("Proceso terminado.\n")