# Computes average MAE, MSE, KGE, and NSE values for the Chilean North, Central,
# and South subregions from CR2MET metric maps stored in Excel files.
# To adapt it, change folder_path, input Excel file pattern, metric sheet names,
# subregion column ranges, output filenames, and region labels.

library(readxl)
library(writexl)

rm(list=ls())
graphics.off()

# Ruta a la carpeta principal
folder_path <- "F:/Cristobal Aboitiz/LISTOS_PAPER/CR2/ESCALADO_CR2/pr/revisados/FF/xsl"

# Listar archivos Excel
files <- list.files(path = folder_path, pattern = "\\.xlsx$", full.names = TRUE)

if (length(files) == 0) {
  stop("No se encontraron archivos Excel en la carpeta especificada.")
}

# Inicializar listas para almacenar los datos para el archivo final
mae_data <- data.frame(File = character(), S = numeric(), C = numeric(), N = numeric(), stringsAsFactors = FALSE)
mse_data <- data.frame(File = character(), S = numeric(), C = numeric(), N = numeric(), stringsAsFactors = FALSE)
kge_data <- data.frame(File = character(), S = numeric(), C = numeric(), N = numeric(), stringsAsFactors = FALSE)
nse_data <- data.frame(File = character(), S = numeric(), C = numeric(), N = numeric(), stringsAsFactors = FALSE)

# Procesar cada archivo Excel
for (file in files) {
  cat("Procesando archivo:", basename(file), "\n")
  
  # Leer cada hoja
  mae <- read_excel(file, sheet = "MAE")
  mse <- read_excel(file, sheet = "MSE")
  kge <- read_excel(file, sheet = "KGE")
  nse <- read_excel(file, sheet = "NSE")
  
  # Calcular promedios para cada conjunto de columnas
  mae_s <- mean(as.matrix(mae[, 1:280]), na.rm = TRUE)
  mae_c <- mean(as.matrix(mae[, 281:540]), na.rm = TRUE)
  mae_n <- mean(as.matrix(mae[, 541:800]), na.rm = TRUE)
  
  mse_s <- mean(as.matrix(mse[, 1:280]), na.rm = TRUE)
  mse_c <- mean(as.matrix(mse[, 281:540]), na.rm = TRUE)
  mse_n <- mean(as.matrix(mse[, 541:800]), na.rm = TRUE)
  
  kge_s <- mean(as.matrix(kge[, 1:280]), na.rm = TRUE)
  kge_c <- mean(as.matrix(kge[, 281:540]), na.rm = TRUE)
  kge_n <- mean(as.matrix(kge[, 541:800]), na.rm = TRUE)
  
  nse_s <- mean(as.matrix(nse[, 1:280]), na.rm = TRUE)
  nse_c <- mean(as.matrix(nse[, 281:540]), na.rm = TRUE)
  nse_n <- mean(as.matrix(nse[, 541:800]), na.rm = TRUE)
  
  # Guardar resultados en archivos de texto
  output_base <- file.path(folder_path, sub("\\.xlsx$", "", basename(file)))
  
  writeLines(
    paste(
      "Promedio MAE:", mae_s,
      "\nPromedio MSE:", mse_s,
      "\nPromedio KGE:", kge_s,
      "\nPromedio NSE:", nse_s
    ),
    con = paste0(output_base, "_S.txt")
  )
  
  writeLines(
    paste(
      "Promedio MAE:", mae_c,
      "\nPromedio MSE:", mse_c,
      "\nPromedio KGE:", kge_c,
      "\nPromedio NSE:", nse_c
    ),
    con = paste0(output_base, "_C.txt")
  )
  
  writeLines(
    paste(
      "Promedio MAE:", mae_n,
      "\nPromedio MSE:", mse_n,
      "\nPromedio KGE:", kge_n,
      "\nPromedio NSE:", nse_n
    ),
    con = paste0(output_base, "_N.txt")
  )
  
  # Agregar datos al resumen final
  mae_data <- rbind(mae_data, data.frame(File = basename(file), S = mae_s, C = mae_c, N = mae_n))
  mse_data <- rbind(mse_data, data.frame(File = basename(file), S = mse_s, C = mse_c, N = mse_n))
  kge_data <- rbind(kge_data, data.frame(File = basename(file), S = kge_s, C = kge_c, N = kge_n))
  nse_data <- rbind(nse_data, data.frame(File = basename(file), S = nse_s, C = nse_c, N = nse_n))
}

# Crear archivo Excel final
output_excel_path <- file.path(folder_path, "resumen_indices.xlsx")
wb <- createWorkbook()

addWorksheet(wb, "MAE")
writeData(wb, "MAE", mae_data)

addWorksheet(wb, "MSE")
writeData(wb, "MSE", mse_data)

addWorksheet(wb, "KGE")
writeData(wb, "KGE", kge_data)

addWorksheet(wb, "NSE")
writeData(wb, "NSE", nse_data)

saveWorkbook(wb, output_excel_path, overwrite = TRUE)

cat("Archivo Excel final creado en:", output_excel_path, "\n")

