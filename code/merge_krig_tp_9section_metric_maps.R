# Merges the nine South American section metric maps into full-domain KRIG precipitation maps.
# For each scale and metric sheet, the script reads the section Excel files,
# places them in the NO/NC/NE, CO/CC/CE, SO/SC/SE layout, and exports one
# merged 753 x 551 Excel map per scale.
# To adapt it, change folder_path, scales, sheet names, VAR_NAME, sector sizes,
# section order, start rows/columns, final grid dimensions, and input filename pattern.

library(openxlsx)

rm(list = ls())
graphics.off()

# =========================
# Configuraci?n
# =========================
folder_path <- "G:/Cristobal_Aboitiz/Paper/KRIG/tp/tp/metrics"

# Para correr todas las escalas:
scales <- c("02", "05", "10", "15", "20", "25")#"02", "05", "10", "15", "20", "25"

# Para probar solo una escala, usa por ejemplo:
# scales <- c("05")

sheet_names <- c("MAE", "MSE", "KGE", "NSE")

VAR_NAME <- "tp"

# =========================
# Tama?os de cada sector en el mapa final
# filas = latitud
# columnas = longitud
# =========================
sector_sizes <- list(
  "NO" = c(251, 184), "NC" = c(251, 183), "NE" = c(251, 184),
  "CO" = c(251, 184), "CC" = c(251, 183), "CE" = c(251, 184),
  "SO" = c(251, 184), "SC" = c(251, 183), "SE" = c(251, 184)
)

# =========================
# Orden definitivo
# Arriba: norte de Sudam?rica
# Centro
# Abajo: sur de Sudam?rica
# =========================
sector_order <- matrix(
  c("NO", "NC", "NE",
    "CO", "CC", "CE",
    "SO", "SC", "SE"),
  nrow = 3,
  byrow = TRUE
)

# Posiciones iniciales en la matriz final
start_row <- c(1, 252, 503)
start_col <- c(1, 185, 368)

# Tama?o final del mapa
final_rows <- 753
final_cols <- 551

# =========================
# Funci?n para leer cada hoja
# =========================
read_sector_metric <- function(file, sheet) {
  
  # Los Excel de m?tricas fueron escritos con encabezados de columnas.
  # Por eso se leen con colNames = TRUE para quitar la fila V1, V2, etc.
  data <- read.xlsx(file, sheet = sheet, colNames = TRUE)
  data_mat <- as.matrix(data)
  
  return(data_mat)
}

# =========================
# Run
# =========================
cat("========================================\n")
cat("MERGE MAPS KRIG TP - FINAL\n")
cat("Carpeta:", folder_path, "\n")
cat("Escalas:", paste(scales, collapse = ", "), "\n")
cat("Orden vertical: NO/NC/NE - CO/CC/CE - SO/SC/SE\n")
cat("Sectores SIN transponer\n")
cat("========================================\n\n")

for (sc in scales) {
  
  cat("========================================\n")
  cat("Procesando escala:", sc, "\n")
  cat("========================================\n")
  
  files <- list.files(
    folder_path,
    pattern = paste0("^[A-Za-z]{2}_krig_", sc, "_", VAR_NAME, "_metrics\\.xlsx$"),
    full.names = TRUE
  )
  
  if (length(files) == 0) {
    cat("  No se encontraron archivos para escala", sc, "\n\n")
    next
  }
  
  output_excel <- file.path(
    folder_path,
    paste0("merged_map_krig_", sc, "_", VAR_NAME, "_metrics.xlsx")
  )
  
  wb <- createWorkbook()
  
  for (sheet in sheet_names) {
    
    cat("  Hoja:", sheet, "\n")
    
    final_matrix <- matrix("XXX", nrow = final_rows, ncol = final_cols)
    
    for (i in 1:nrow(sector_order)) {
      for (j in 1:ncol(sector_order)) {
        
        sector <- sector_order[i, j]
        
        file_match <- files[grepl(paste0("^", sector, "_"), basename(files))]
        
        if (length(file_match) == 0) {
          cat("    [OMITE] No se encontr? archivo para sector", sector,
              "en escala", sc, "\n")
          next
        }
        
        if (length(file_match) > 1) {
          cat("    [OMITE] M?s de un archivo para sector", sector,
              "en escala", sc, "\n")
          print(basename(file_match))
          next
        }
        
        data_mat <- read_sector_metric(file_match, sheet)
        
        sec_rows <- sector_sizes[[sector]][1]
        sec_cols <- sector_sizes[[sector]][2]
        
        r1 <- start_row[i]
        c1 <- start_col[j]
        r2 <- r1 + sec_rows - 1
        c2 <- c1 + sec_cols - 1
        
        cat("    Sector:", sector,
            "| archivo:", basename(file_match),
            "| dim le?da:", paste(dim(data_mat), collapse = "x"),
            "| esperado:", sec_rows, "x", sec_cols,
            "| filas", r1, "-", r2,
            "| cols", c1, "-", c2, "\n")
        
        if (!all(dim(data_mat) == c(sec_rows, sec_cols))) {
          cat("    [OMITE] Dimensiones no coinciden en", sector, sheet, "\n")
          next
        }
        
        final_matrix[r1:r2, c1:c2] <- data_mat
      }
    }
    
    addWorksheet(wb, sheet)
    writeData(wb, sheet, final_matrix, colNames = FALSE, rowNames = FALSE)
  }
  
  saveWorkbook(wb, output_excel, overwrite = TRUE)
  cat("  Guardado:", output_excel, "\n\n")
}

cat("Proceso terminado.\n")