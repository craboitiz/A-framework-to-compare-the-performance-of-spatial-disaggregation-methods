# Computes grid-cell performance metrics for KRIG precipitation over the nine
# South American sections.
# For each scale and section, the script compares the reference ERA5-Land precipitation
# series with the KRIG output and exports MAE, MSE, KGE, and NSE maps plus average summaries.
# To adapt it, change BASE_DIR, ERA_DIR, KRIG_DIR, scales, section names, file tags,
# variable names, valid-value limits, MIN_VALID, and output filename pattern.

library(ncdf4)
library(hydroGOF)
library(openxlsx)

rm(list=ls())
graphics.off()

# =========================
# Configuraci?n
# =========================
BASE_DIR <- "G:/Cristobal_Aboitiz/Paper/KRIG/tp/tp/metrics"
ERA_DIR  <- BASE_DIR
KRIG_DIR <- BASE_DIR


SCALES <- c("02", "05", "10", "15", "20", "25")

SECTORS <- c("NO","NC","NE","CO","CC","CE","SO","SC","SE")

ERA_FILE_TAG <- "ERA5_pr"
KRIG_TAG     <- "tp"

# =========================
# Limpieza para tp
# =========================
# tp est? en metros. Todo valor diario < 0 o > 10 m se considera inv?lido.
# 10 m/d?a ya es f?sicamente absurdo, pero permite no eliminar eventos reales extremos.
TP_MIN_VALID <- 0
TP_MAX_VALID <- 10

# M?nimo de pares v?lidos para calcular ?ndices en una celda
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
  
  drop_candidates <- c("lon","longitude","lat","latitude","time","valid_time",
                       "time_bnds","time_bounds",
                       "lon_bnds","lon_bounds","lat_bnds","lat_bounds","bounds")
  
  vars2 <- vars[!tolower(vars) %in% drop_candidates]
  
  if (length(vars2) == 0) return(vars[1])
  return(vars2[1])
}

find_dim_pos <- function(dim_names, candidates) {
  dim_low <- tolower(dim_names)
  hit <- which(dim_low %in% candidates)
  if (length(hit) == 0) return(NA_integer_)
  return(hit[1])
}

read_nc_lon_lat_time <- function(file, preferred_vars = NULL) {
  nc <- nc_open(file)
  
  varname <- guess_main_var(nc, preferred_vars)
  var_obj <- nc$var[[varname]]
  
  dim_names <- sapply(var_obj$dim, function(d) d$name)
  dim_vals  <- lapply(var_obj$dim, function(d) d$vals)
  
  lon_pos  <- find_dim_pos(dim_names, c("lon", "longitude", "x"))
  lat_pos  <- find_dim_pos(dim_names, c("lat", "latitude", "y"))
  time_pos <- find_dim_pos(dim_names, c("time", "valid_time", "t"))
  
  if (is.na(lon_pos) || is.na(lat_pos) || is.na(time_pos)) {
    nc_close(nc)
    stop(
      "No pude identificar lon/lat/time en: ", basename(file), "\n",
      "Variable: ", varname, "\n",
      "Dimensiones: ", paste(dim_names, collapse = ", ")
    )
  }
  
  data <- ncvar_get(nc, varname, collapse_degen = FALSE)
  
  # Reordenar SIEMPRE a longitude x latitude x time
  data <- aperm(data, c(lon_pos, lat_pos, time_pos))
  
  lon  <- dim_vals[[lon_pos]]
  lat  <- dim_vals[[lat_pos]]
  time <- dim_vals[[time_pos]]
  
  nc_close(nc)
  
  list(
    file = file,
    varname = varname,
    data = data,
    lon = lon,
    lat = lat,
    time = time
  )
}

coords_same <- function(a, b, tol = 1e-4) {
  if (length(a) != length(b)) return(FALSE)
  max(abs(a - b), na.rm = TRUE) < tol
}

align_comp_to_ref <- function(ref_info, comp_info) {
  
  # Longitud
  if (coords_same(ref_info$lon, comp_info$lon)) {
    # mismo orden, no hacer nada
  } else if (coords_same(ref_info$lon, rev(comp_info$lon))) {
    comp_info$data <- comp_info$data[dim(comp_info$data)[1]:1, , , drop = FALSE]
    comp_info$lon <- rev(comp_info$lon)
  } else {
    cat("Advertencia: longitude no coincide exactamente entre ERA y KRIG. Se mantiene mismo orden de ?ndices.\n")
  }
  
  # Latitud
  if (coords_same(ref_info$lat, comp_info$lat)) {
    # mismo orden, no hacer nada
  } else if (coords_same(ref_info$lat, rev(comp_info$lat))) {
    comp_info$data <- comp_info$data[, dim(comp_info$data)[2]:1, , drop = FALSE]
    comp_info$lat <- rev(comp_info$lat)
  } else {
    cat("Advertencia: latitude no coincide exactamente entre ERA y KRIG. Se mantiene mismo orden de ?ndices.\n")
  }
  
  return(comp_info)
}

safe_metric <- function(fun, ref_series, comp_series) {
  out <- tryCatch(
    fun(ref_series, comp_series, na.rm = TRUE),
    error = function(e) NA_real_,
    warning = function(w) suppressWarnings(fun(ref_series, comp_series, na.rm = TRUE))
  )
  
  if (length(out) == 0) return(NA_real_)
  if (!is.finite(out)) return(NA_real_)
  as.numeric(out)
}

clean_tp_series <- function(x) {
  x[!is.finite(x)] <- NA
  x[x < TP_MIN_VALID | x > TP_MAX_VALID] <- NA
  return(x)
}

calculate_indices <- function(ref_data, compare_data) {
  
  dims <- dim(ref_data)
  
  n_lon  <- dims[1]
  n_lat  <- dims[2]
  n_time <- dims[3]
  
  mae_matrix <- matrix(NA, nrow = n_lat, ncol = n_lon)
  mse_matrix <- matrix(NA, nrow = n_lat, ncol = n_lon)
  kge_matrix <- matrix(NA, nrow = n_lat, ncol = n_lon)
  nse_matrix <- matrix(NA, nrow = n_lat, ncol = n_lon)
  
  invalid_ref_total <- 0
  invalid_comp_total <- 0
  skipped_cells_total <- 0
  calculated_cells_total <- 0
  
  for (i in 1:n_lon) {
    
    if (i %% 20 == 0 || i == 1 || i == n_lon) {
      cat("    Lon index", i, "de", n_lon, "\n")
    }
    
    for (j in 1:n_lat) {
      
      ref_series  <- ref_data[i, j, ]
      comp_series <- compare_data[i, j, ]
      
      if (length(ref_series) != length(comp_series)) next
      
      invalid_ref_before <- sum(!is.finite(ref_series) |
                                  ref_series < TP_MIN_VALID |
                                  ref_series > TP_MAX_VALID,
                                na.rm = TRUE)
      
      invalid_comp_before <- sum(!is.finite(comp_series) |
                                   comp_series < TP_MIN_VALID |
                                   comp_series > TP_MAX_VALID,
                                 na.rm = TRUE)
      
      invalid_ref_total <- invalid_ref_total + invalid_ref_before
      invalid_comp_total <- invalid_comp_total + invalid_comp_before
      
      ref_series  <- clean_tp_series(ref_series)
      comp_series <- clean_tp_series(comp_series)
      
      valid <- is.finite(ref_series) & is.finite(comp_series)
      
      if (sum(valid) < MIN_VALID) {
        skipped_cells_total <- skipped_cells_total + 1
        next
      }
      
      ref_series_valid  <- ref_series[valid]
      comp_series_valid <- comp_series[valid]
      
      # Se mantiene el mismo orden del c?digo original:
      # ref_series primero, comp_series segundo.
      mae_matrix[j, i] <- safe_metric(mae, ref_series_valid, comp_series_valid)
      mse_matrix[j, i] <- safe_metric(mse, ref_series_valid, comp_series_valid)
      kge_matrix[j, i] <- safe_metric(KGE, ref_series_valid, comp_series_valid)
      nse_matrix[j, i] <- safe_metric(NSE, ref_series_valid, comp_series_valid)
      
      calculated_cells_total <- calculated_cells_total + 1
    }
  }
  
  list(
    mae = mae_matrix,
    mse = mse_matrix,
    kge = kge_matrix,
    nse = nse_matrix,
    summary = list(
      invalid_ref_total = invalid_ref_total,
      invalid_comp_total = invalid_comp_total,
      skipped_cells_total = skipped_cells_total,
      calculated_cells_total = calculated_cells_total
    )
  )
}

format_matrix <- function(mat) {
  out <- matrix("XXX", nrow = nrow(mat), ncol = ncol(mat))
  ok <- !is.na(mat) & is.finite(mat)
  out[ok] <- gsub("\\.", ",", sprintf("%.6f", mat[ok]))
  return(out)
}

# =========================
# Run
# =========================
cat("Procesando escalas:", paste(SCALES, collapse = ", "), "\n")
cat("BASE_DIR:", BASE_DIR, "\n")
cat("Limpieza tp: valores <", TP_MIN_VALID, "o >", TP_MAX_VALID, "m se consideran NA\n")
cat("MIN_VALID:", MIN_VALID, "\n\n")

for (sc in SCALES) {
  cat("========================================\n")
  cat("ESCALA:", sc, "\n")
  
  for (sec in SECTORS) {
    
    era_file <- file.path(ERA_DIR, paste0(sec, "_", ERA_FILE_TAG, "_1960_2021.nc"))
    
    krig_masked <- file.path(KRIG_DIR, paste0(sec, "_krig_", sc, "_", KRIG_TAG, "_masked.nc"))
    krig_plain  <- file.path(KRIG_DIR, paste0(sec, "_krig_", sc, "_", KRIG_TAG, ".nc"))
    krig_file <- if (file.exists(krig_masked)) krig_masked else krig_plain
    
    if (!file.exists(era_file)) {
      cat("[OMITE] Falta ERA:", basename(era_file), "\n")
      next
    }
    
    if (!file.exists(krig_file)) {
      cat("[OMITE] Falta KRIG para", sec, "escala", sc, "\n")
      next
    }
    
    cat("----------------------------------------\n")
    cat("Sector:", sec, "| Escala:", sc, "\n")
    cat("ERA :", basename(era_file), "\n")
    cat("KRIG:", basename(krig_file), "\n")
    
    # ERA
    ref_info <- read_nc_lon_lat_time(
      era_file,
      preferred_vars = c("tp", "pr", "precip", "precipitation")
    )
    
    # KRIG
    comp_info <- read_nc_lon_lat_time(
      krig_file,
      preferred_vars = c("tp", "pr", "precip", "precipitation")
    )
    
    cat("Variable ERA :", ref_info$varname, "\n")
    cat("Variable KRIG:", comp_info$varname, "\n")
    
    cat("ERA tama?o lon x lat x time:",
        dim(ref_info$data)[1], "x", dim(ref_info$data)[2], "x", dim(ref_info$data)[3], "\n")
    
    cat("KRIG tama?o lon x lat x time:",
        dim(comp_info$data)[1], "x", dim(comp_info$data)[2], "x", dim(comp_info$data)[3], "\n")
    
    # Alinear lon/lat si hace falta
    comp_info <- align_comp_to_ref(ref_info, comp_info)
    
    # Chequeo de dimensiones
    if (!all(dim(ref_info$data) == dim(comp_info$data))) {
      cat("[OMITE] dims no coinciden. ERA:", paste(dim(ref_info$data), collapse = "x"),
          "KRIG:", paste(dim(comp_info$data), collapse = "x"), "\n")
      rm(ref_info, comp_info)
      gc()
      next
    }
    
    # C?lculo
    indices <- calculate_indices(ref_info$data, comp_info$data)
    
    # Promedios antes de formatear con coma decimal
    avg_mae <- mean(indices$mae, na.rm = TRUE)
    avg_mse <- mean(indices$mse, na.rm = TRUE)
    avg_kge <- mean(indices$kge, na.rm = TRUE)
    avg_nse <- mean(indices$nse, na.rm = TRUE)
    
    # Formato coma decimal + XXX
    indices_fmt <- list(
      mae = format_matrix(indices$mae),
      mse = format_matrix(indices$mse),
      kge = format_matrix(indices$kge),
      nse = format_matrix(indices$nse)
    )
    
    # Outputs
    out_prefix <- file.path(BASE_DIR, paste0(sec, "_krig_", sc, "_", KRIG_TAG))
    output_excel_path <- paste0(out_prefix, "_metrics.xlsx")
    output_txt <- paste0(out_prefix, "_averages.txt")
    
    wb <- createWorkbook()
    
    # El Excel queda con matriz latitude x longitude.
    addWorksheet(wb, "MAE"); writeData(wb, "MAE", indices_fmt$mae)
    addWorksheet(wb, "MSE"); writeData(wb, "MSE", indices_fmt$mse)
    addWorksheet(wb, "KGE"); writeData(wb, "KGE", indices_fmt$kge)
    addWorksheet(wb, "NSE"); writeData(wb, "NSE", indices_fmt$nse)
    
    saveWorkbook(wb, output_excel_path, overwrite = TRUE)
    
    writeLines(
      paste("Sector:", sec,
            "\nEscala:", sc,
            "\nPromedio MAE:", avg_mae,
            "\nPromedio MSE:", avg_mse,
            "\nPromedio KGE:", avg_kge,
            "\nPromedio NSE:", avg_nse,
            "\n\nLimpieza tp:",
            "\nValores ERA descartados por no finitos/fuera de rango:", indices$summary$invalid_ref_total,
            "\nValores KRIG descartados por no finitos/fuera de rango:", indices$summary$invalid_comp_total,
            "\nCeldas omitidas por menos de MIN_VALID pares v?lidos:", indices$summary$skipped_cells_total,
            "\nCeldas calculadas:", indices$summary$calculated_cells_total,
            "\nTP_MIN_VALID:", TP_MIN_VALID,
            "\nTP_MAX_VALID:", TP_MAX_VALID,
            "\nMIN_VALID:", MIN_VALID),
      con = output_txt
    )
    
    cat("OK ->", basename(output_excel_path), "\n")
    cat("    Valores ERA descartados:", indices$summary$invalid_ref_total, "\n")
    cat("    Valores KRIG descartados:", indices$summary$invalid_comp_total, "\n")
    cat("    Celdas omitidas:", indices$summary$skipped_cells_total, "\n")
    cat("    Celdas calculadas:", indices$summary$calculated_cells_total, "\n")
    
    rm(ref_info, comp_info, indices, indices_fmt)
    gc()
  }
}

cat("\nProceso completado.\n")