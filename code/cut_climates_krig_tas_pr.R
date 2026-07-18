# Computes climate-region averages for KRIG precipitation and temperature metrics.
# The script reads merged metric maps, clips them using climate-region shapefiles s1-s5,
# exports masked rasters, and creates an Excel summary of mean, min, max, and valid-cell counts.
# To adapt it, change tas_metrics_dir, pr_metrics_dir, output_dir, shape folders,
# scales, metric names, variable/file tags, spatial extent, grid dimensions, and shape names.

library(openxlsx)
library(terra)

rm(list = ls())
graphics.off()

# ============================================================
# CONFIGURACI?N GENERAL
# ============================================================

# Carpetas donde est?n los merged maps
tas_metrics_dir <- "G:/Cristobal_Aboitiz/Paper/KRIG/tas/metrics"
pr_metrics_dir  <- "G:/Cristobal_Aboitiz/Paper/KRIG/tp/tp/metrics"

# Carpeta de salida com?n
output_dir <- "G:/Cristobal_Aboitiz/Paper/KRIG/Resultados_climas_KRIG_tas_pr"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Escalas
scales <- c("02", "05", "10", "15", "20", "25")

# ?ndices
indices <- c("MAE", "MSE", "KGE", "NSE")

# Shapes clim?ticos
shape_names <- paste0("s", 1:5)

# Extensi?n espacial del merged de Sudam?rica
xmin <- -85
xmax <- -29.9
ymin <- -60.2
ymax <- 15.1

# Tama?o esperado de los mapas merged
expected_rows <- 753
expected_cols <- 551

# ============================================================
# CONFIGURACI?N POR VARIABLE
# ============================================================
# Ojo:
# - temperatura aparece como t2m en los nombres de archivo.
# - precipitaci?n aparece como tp en los nombres de archivo,
#   aunque conceptualmente en el paper sea pr.

datasets <- list(
  tas = list(
    label = "tas",
    metrics_dir = tas_metrics_dir,
    file_var = "t2m",
    pattern_name = "t2m"
  ),
  pr = list(
    label = "pr",
    metrics_dir = pr_metrics_dir,
    file_var = "tp",
    pattern_name = "tp"
  )
)

# ============================================================
# BUSCAR CARPETA DE SHAPES
# ============================================================
# El script prueba varias ubicaciones posibles para no perder tiempo.
# Deja los shapes en una de estas carpetas.

shape_dir_candidates <- c(
  file.path(tas_metrics_dir, "shapesclimas2"),
  file.path(pr_metrics_dir, "shapesclimas2"),
  "G:/Cristobal_Aboitiz/Paper/KRIG/tas/shapesclimas2",
  "G:/Cristobal_Aboitiz/Paper/KRIG/tp/tp/shapesclimas2",
  "G:/Cristobal_Aboitiz/Paper/KRIG/shapesclimas2"
)

shapes_dir <- NA_character_

for (d in shape_dir_candidates) {
  if (dir.exists(d)) {
    test_files <- file.path(d, paste0(shape_names, ".shp"))
    if (all(file.exists(test_files))) {
      shapes_dir <- d
      break
    }
  }
}

if (is.na(shapes_dir)) {
  cat("No encontr? la carpeta de shapes.\n")
  cat("Busqu? en:\n")
  cat(paste(shape_dir_candidates, collapse = "\n"), "\n")
  stop("Debes dejar s1.shp a s5.shp en una de esas carpetas.")
}

cat("========================================\n")
cat("CUT CLIMATES KRIG TAS + PR\n")
cat("Shapes dir:", shapes_dir, "\n")
cat("Output dir:", output_dir, "\n")
cat("Escalas:", paste(scales, collapse = ", "), "\n")
cat("?ndices:", paste(indices, collapse = ", "), "\n")
cat("========================================\n\n")

# ============================================================
# LEER SHAPES
# ============================================================

shape_list <- list()

for (shp_name in shape_names) {
  
  shp_path <- file.path(shapes_dir, paste0(shp_name, ".shp"))
  
  if (!file.exists(shp_path)) {
    stop("No existe el shape: ", shp_path)
  }
  
  cat("Leyendo shape:", basename(shp_path), "\n")
  
  shp_vect <- vect(shp_path)
  
  if (is.na(crs(shp_vect))) {
    cat("  Advertencia: shape sin CRS. Se asigna EPSG:4326.\n")
    crs(shp_vect) <- "EPSG:4326"
  } else {
    shp_vect <- project(shp_vect, "EPSG:4326")
  }
  
  shape_list[[shp_name]] <- shp_vect
}

cat("\n")

# ============================================================
# FUNCIONES
# ============================================================

excel_sheet_to_raster <- function(excel_file, sheet_name, xmin, xmax, ymin, ymax) {
  
  df <- read.xlsx(excel_file, sheet = sheet_name, colNames = FALSE)
  mat <- as.matrix(df)
  
  mat[mat == "XXX"] <- NA
  mat[mat == ""] <- NA
  
  mat <- gsub(",", ".", mat)
  
  mat_num <- matrix(
    suppressWarnings(as.numeric(mat)),
    nrow = nrow(mat),
    ncol = ncol(mat)
  )
  
  if (!all(dim(mat_num) == c(expected_rows, expected_cols))) {
    stop(
      "El mapa no tiene el tama?o esperado en archivo:\n",
      excel_file, "\n",
      "Hoja: ", sheet_name, "\n",
      "Esperado: ", expected_rows, "x", expected_cols, "\n",
      "Encontrado: ", paste(dim(mat_num), collapse = "x")
    )
  }
  
  r <- rast(
    nrows = nrow(mat_num),
    ncols = ncol(mat_num),
    xmin = xmin,
    xmax = xmax,
    ymin = ymin,
    ymax = ymax,
    crs = "EPSG:4326"
  )
  
  # Orientaci?n que calza visualmente con los mapas merged:
  # filas del Excel = norte-sur, columnas = oeste-este.
  values(r) <- as.vector(t(mat_num))
  
  return(r)
}

safe_stats <- function(r) {
  
  vals <- values(r, mat = FALSE)
  vals <- vals[is.finite(vals)]
  
  n_cells <- length(vals)
  
  if (n_cells == 0) {
    return(
      data.frame(
        N_celdas = 0,
        Mean = NA_real_,
        Min = NA_real_,
        Max = NA_real_,
        stringsAsFactors = FALSE
      )
    )
  }
  
  data.frame(
    N_celdas = n_cells,
    Mean = mean(vals, na.rm = TRUE),
    Min = min(vals, na.rm = TRUE),
    Max = max(vals, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}

make_verification_plot <- function(example_excel, variable_label, output_dir) {
  
  if (!file.exists(example_excel)) {
    cat("No se hizo plot de verificaci?n para", variable_label,
        "porque no existe:", basename(example_excel), "\n")
    return(NULL)
  }
  
  check_png <- file.path(
    output_dir,
    paste0("verificacion_shapes_sobre_merged_", variable_label, ".png")
  )
  
  r_check <- excel_sheet_to_raster(example_excel, "MAE", xmin, xmax, ymin, ymax)
  
  png(check_png, width = 1200, height = 900)
  
  plot(
    r_check,
    main = paste0(
      "Verificaci?n shapes sobre ",
      basename(example_excel),
      " - MAE"
    )
  )
  
  border_cols <- c("red", "blue", "forestgreen", "orange", "purple")
  
  for (i in seq_along(shape_names)) {
    plot(shape_list[[shape_names[i]]], add = TRUE, border = border_cols[i], lwd = 2)
  }
  
  legend(
    "bottomleft",
    legend = shape_names,
    col = border_cols,
    lwd = 2,
    bg = "white"
  )
  
  dev.off()
  
  cat("Plot de verificaci?n guardado:", check_png, "\n")
  return(check_png)
}

# ============================================================
# PLOTS DE VERIFICACI?N
# ============================================================

for (var_key in names(datasets)) {
  
  ds <- datasets[[var_key]]
  
  example_excel <- file.path(
    ds$metrics_dir,
    paste0("merged_map_krig_10_", ds$file_var, "_metrics.xlsx")
  )
  
  make_verification_plot(example_excel, ds$label, output_dir)
}

cat("\n")

# ============================================================
# LOOP PRINCIPAL
# ============================================================

all_results <- data.frame(
  Variable = character(),
  Scale = character(),
  Index = character(),
  Shape = character(),
  N_celdas = integer(),
  Mean = numeric(),
  Min = numeric(),
  Max = numeric(),
  Source_file = character(),
  stringsAsFactors = FALSE
)

for (var_key in names(datasets)) {
  
  ds <- datasets[[var_key]]
  
  cat("========================================\n")
  cat("Variable:", ds$label, "\n")
  cat("Metrics dir:", ds$metrics_dir, "\n")
  cat("File var:", ds$file_var, "\n")
  cat("========================================\n")
  
  variable_output_dir <- file.path(output_dir, ds$label)
  dir.create(variable_output_dir, showWarnings = FALSE, recursive = TRUE)
  
  for (sc in scales) {
    
    excel_file <- file.path(
      ds$metrics_dir,
      paste0("merged_map_krig_", sc, "_", ds$file_var, "_metrics.xlsx")
    )
    
    if (!file.exists(excel_file)) {
      cat("  [OMITE] No existe:", excel_file, "\n")
      next
    }
    
    excel_base_name <- tools::file_path_sans_ext(basename(excel_file))
    
    cat("  Procesando:", excel_base_name, "\n")
    
    for (idx in indices) {
      
      cat("    Hoja:", idx, "\n")
      
      r <- excel_sheet_to_raster(excel_file, idx, xmin, xmax, ymin, ymax)
      
      for (shp_name in shape_names) {
        
        shp_vect <- shape_list[[shp_name]]
        
        r_crop <- crop(r, shp_vect)
        r_mask <- mask(r_crop, shp_vect)
        
        stats <- safe_stats(r_mask)
        
        tif_rec <- file.path(
          variable_output_dir,
          paste0(excel_base_name, "_", idx, "_", shp_name, ".tif")
        )
        
        writeRaster(r_mask, tif_rec, overwrite = TRUE)
        
        new_row <- data.frame(
          Variable = ds$label,
          Scale = sc,
          Index = idx,
          Shape = shp_name,
          N_celdas = stats$N_celdas,
          Mean = stats$Mean,
          Min = stats$Min,
          Max = stats$Max,
          Source_file = basename(excel_file),
          stringsAsFactors = FALSE
        )
        
        all_results <- rbind(all_results, new_row)
        
        cat("      Shape:", shp_name,
            "| n:", stats$N_celdas,
            "| mean:", stats$Mean, "\n")
      }
      
      rm(r)
      gc()
    }
  }
  
  cat("\n")
}

# ============================================================
# GUARDAR EXCEL FINAL
# ============================================================

summary_file <- file.path(output_dir, "promedios_por_shape_KRIG_tas_pr.xlsx")

wb <- createWorkbook()

addWorksheet(wb, "Resumen_all")
writeData(wb, "Resumen_all", all_results, colNames = TRUE, rowNames = FALSE)

# Hojas por variable e ?ndice
for (var_key in names(datasets)) {
  
  var_label <- datasets[[var_key]]$label
  
  for (idx in indices) {
    
    sheet_name <- paste0(var_label, "_", idx)
    
    sub <- all_results[
      all_results$Variable == var_label &
        all_results$Index == idx,
    ]
    
    addWorksheet(wb, sheet_name)
    writeData(wb, sheet_name, sub, colNames = TRUE, rowNames = FALSE)
  }
}

# Hojas resumen formato ancho: una hoja por variable, ?ndice y shape
# columnas = escalas
for (var_key in names(datasets)) {
  
  var_label <- datasets[[var_key]]$label
  
  for (idx in indices) {
    
    sub <- all_results[
      all_results$Variable == var_label &
        all_results$Index == idx,
    ]
    
    if (nrow(sub) == 0) next
    
    wide <- data.frame(Shape = shape_names, stringsAsFactors = FALSE)
    
    for (sc in scales) {
      vals <- rep(NA_real_, length(shape_names))
      
      for (k in seq_along(shape_names)) {
        sh <- shape_names[k]
        hit <- sub[sub$Scale == sc & sub$Shape == sh, ]
        if (nrow(hit) > 0) {
          vals[k] <- hit$Mean[1]
        }
      }
      
      wide[[paste0("Scale_", sc)]] <- vals
    }
    
    sheet_name <- paste0(var_label, "_", idx, "_wide")
    
    # Excel permite m?ximo 31 caracteres en nombres de hoja
    sheet_name <- substr(sheet_name, 1, 31)
    
    addWorksheet(wb, sheet_name)
    writeData(wb, sheet_name, wide, colNames = TRUE, rowNames = FALSE)
  }
}

saveWorkbook(wb, summary_file, overwrite = TRUE)

cat("========================================\n")
cat("Listo.\n")
cat("Resumen guardado en:\n")
cat(summary_file, "\n")
cat("Rasters por variable guardados en:\n")
cat(file.path(output_dir, "tas"), "\n")
cat(file.path(output_dir, "pr"), "\n")
cat("========================================\n")