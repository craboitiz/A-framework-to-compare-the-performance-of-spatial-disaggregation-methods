# Computes full-domain spatial averages of KRIG precipitation metrics for each scale.
# The script reads merged MAE, MSE, KGE, and NSE maps and averages all valid cells.
# To adapt it, change folder_path, scales, metric sheet names, VAR_NAME,
# input filename pattern, output filename, and missing-value codes.

library(openxlsx)

rm(list = ls())
graphics.off()

# =========================
# Configuraci?n
# =========================
folder_path <- "G:/Cristobal_Aboitiz/Paper/KRIG/tp/tp/metrics"

# Para todas las escalas:
scales <- c("02", "05", "10", "15", "20", "25")

# Para probar solo una escala, usa por ejemplo:
# scales <- c("05")

indices <- c("MAE", "MSE", "KGE", "NSE")

VAR_NAME <- "tp"

output_file <- file.path(
  folder_path,
  paste0("promedios_espaciales_por_escala_", VAR_NAME, ".xlsx")
)

# =========================
# Run
# =========================
cat("========================================\n")
cat("PROMEDIOS ESPACIALES POR ESCALA - KRIG TP\n")
cat("Carpeta:", folder_path, "\n")
cat("Escalas:", paste(scales, collapse = ", "), "\n")
cat("========================================\n\n")

wb_out <- createWorkbook()

for (idx in indices) {
  
  cat("Procesando ?ndice:", idx, "\n")
  
  resultados <- data.frame(
    Escala = scales,
    Promedio = NA_real_
  )
  
  for (k in seq_along(scales)) {
    
    sc <- scales[k]
    
    infile <- file.path(
      folder_path,
      paste0("merged_map_krig_", sc, "_", VAR_NAME, "_metrics.xlsx")
    )
    
    if (!file.exists(infile)) {
      cat("  No existe:", basename(infile), "\n")
      next
    }
    
    cat("  Escala:", sc, "| Archivo:", basename(infile), "\n")
    
    dat <- read.xlsx(infile, sheet = idx, colNames = FALSE)
    mat <- as.matrix(dat)
    
    # limpiar valores no num?ricos
    mat[mat == "XXX"] <- NA
    mat[mat == ""] <- NA
    
    # convertir coma decimal a punto
    mat <- gsub(",", ".", mat)
    
    # pasar a num?rico
    mat_num <- matrix(
      suppressWarnings(as.numeric(mat)),
      nrow = nrow(mat),
      ncol = ncol(mat)
    )
    
    # promedio ignorando NA
    prom <- mean(mat_num, na.rm = TRUE)
    
    # si no hay ning?n valor num?rico, dejar NA en vez de NaN
    if (is.nan(prom)) prom <- NA_real_
    
    resultados$Promedio[k] <- prom
  }
  
  addWorksheet(wb_out, idx)
  writeData(wb_out, idx, resultados, colNames = TRUE, rowNames = FALSE)
  
  cat("\n")
}

saveWorkbook(wb_out, output_file, overwrite = TRUE)

cat("========================================\n")
cat("Archivo guardado en:\n")
cat(output_file, "\n")
cat("========================================\n")