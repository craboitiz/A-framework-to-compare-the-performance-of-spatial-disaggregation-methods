# Example script to compute grid-cell performance metrics for CR2MET precipitation
# in one Chilean subregion.
# The script compares the reference CR2MET precipitation field against disaggregated
# precipitation files and exports MAE, MSE, KGE, and NSE maps plus average summaries.
# To adapt it, change folder_path, reference file, variable name, input filename pattern,
# spatial subset indices, output filenames, and region label.

library(ncdf4)
library(hydroGOF)
library(raster)

rm(list=ls()) 
graphics.off()

# Funcion para calcular los indices
calculate_indices <- function(ref_data, compare_data) {
  dims <- dim(ref_data)
  
  # Inicializar matrices para los inndices
  mae_matrix <- matrix(NA, nrow = dims[1], ncol = dims[2])
  mse_matrix <- matrix(NA, nrow = dims[1], ncol = dims[2])
  kge_matrix <- matrix(NA, nrow = dims[1], ncol = dims[2])
  nse_matrix <- matrix(NA, nrow = dims[1], ncol = dims[2])
  
  # Iterar sobre cada punto de la grilla (lon, lat)
  for (i in 1:dims[1]) {
    for (j in 1:dims[2]) {
      ref_series <- ref_data[i, j, ]  # Serie temporal del punto de referencia
      comp_series <- compare_data[i, j, ]  # Serie temporal del punto comparado
      
      # Verificar que no sean todos NA
      if (all(is.na(ref_series)) || all(is.na(comp_series))) next
      
      # Calcular indices
      mae_matrix[i, j] <- mae(ref_series, comp_series)
      mse_matrix[i, j] <- mse(ref_series, comp_series)
      kge_matrix[i, j] <- KGE(ref_series, comp_series)
      nse_matrix[i, j] <- NSE(ref_series, comp_series)
    }
  }
  
  
  list(mae = mae_matrix, mse = mse_matrix, kge = kge_matrix, nse = nse_matrix)
}

# Ruta a la carpeta
folder_path <- "F:/Cristobal Aboitiz/LISTOS_PAPER/CR2/ESCALADO_CR2/ncs_pr/N"

# Nombre del archivo de referencia
ref_file <- paste0(folder_path, "/pr_CR2_1960_2021.nc") #N=260 C=260 S=280

# Leer el archivo de referencia
nc_ref <- nc_open(ref_file)

ref_data <- ncvar_get(nc_ref, "pr", start = c(2, 541, 1), count = c(219, 260, -1))#1:280=S  281:540=C  541:800=N

# Cerrar el archivo
nc_close(nc_ref)

# Limpiar variables innecesarias
rm(nc_ref)

# Listar los archivos a comparar (3 o 4 caracteres en XXX y escala en YY)
files <- list.files(folder_path, pattern = "^N_[A-Za-z0-9]{2,4}_[0-9]{1,2}_pr_CR2_1960_2021\\.nc$", full.names = TRUE)

# Inicializar contador
counter <- 1


library(openxlsx)

# Loop para analizar cada archivo
 for (file in files) {
  cat("Procesando archivo", counter, "de", length(files), ":", basename(file), "/n")
  
  # Leer archivo a comparar
  nc_compare <- nc_open(file)
  compare_data <- ncvar_get(nc_compare, "pr")
  nc_close(nc_compare)
  
  # Calcular indices
  indices <- calculate_indices(ref_data, compare_data)
  
  # Crear un nuevo archivo Excel
  output_excel_path <- paste0(folder_path, "/", sub(".nc$", "", basename(file)), "_indices.xlsx")
  wb <- createWorkbook()
  
  # Agregar cada ?ndice como una hoja separada
  addWorksheet(wb, "MAE")
  writeData(wb, "MAE", indices$mae)
  
  addWorksheet(wb, "MSE")
  writeData(wb, "MSE", indices$mse)
  
  addWorksheet(wb, "KGE")
  writeData(wb, "KGE", indices$kge)
  
  addWorksheet(wb, "NSE")
  writeData(wb, "NSE", indices$nse)
  
  # Guardar el archivo Excel
  saveWorkbook(wb, output_excel_path, overwrite = TRUE)
  
  
  # Calcular promedios
  avg_mae <- mean(indices$mae, na.rm = TRUE)
  avg_mse <- mean(indices$mse, na.rm = TRUE)
  avg_kge <- mean(indices$kge, na.rm = TRUE)
  avg_nse <- mean(indices$nse, na.rm = TRUE)
  
  # Guardar promedios en un archivo de texto separado
  output_txt <- paste0(folder_path, "/", sub(".nc$", "", basename(file)), "_averages.txt")
  writeLines(
    paste(
      "Promedio MAE:", avg_mae,
      "/nPromedio MSE:", avg_mse,
      "/nPromedio KGE:", avg_kge,
      "/nPromedio NSE:", avg_nse
    ),
    con = output_txt
  )
  
  # aumentar contador y limpiar variables
  counter <- counter + 1
  rm(compare_data, indices, wb)
  gc()
}

cat("Proceso completado./n")
