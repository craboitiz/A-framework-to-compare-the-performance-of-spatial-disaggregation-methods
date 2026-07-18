# Example script to compute grid-cell performance metrics for ERA5-Land temperature
# after CDO-based disaggregation.
# The script compares each disaggregated t2m file against the reference ERA5-Land t2m field
# and exports MAE, MSE, KGE, and NSE maps plus average summaries.
# To adapt it, change folder_path, reference file, variable name, input filename pattern,
# output filenames, and any coordinate/orientation preprocessing.

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
folder_path <- "/media/sf_Cristobal_Aboitiz/Paper/ERA5/tas"

# Nombre del archivo de referencia
ref_file <- paste0(folder_path, "/flip_ERA5_t2m_1960_2021.nc")

# Leer el archivo de referencia
nc_ref <- nc_open(ref_file)
ref_data <- ncvar_get(nc_ref, "t2m")
lon <- ncvar_get(nc_ref, "longitude")
lat <- ncvar_get(nc_ref, "latitude")
nc_close(nc_ref)

# Listar los archivos a comparar (3 o 4 caracteres en XXX y escala en YY)
files <- list.files(folder_path, pattern = "^F_[A-Za-z0-9]{3,4}_[0-9]{2}_ERA5_t2m_1960_2021\\.nc$", full.names = TRUE)

# Inicializar contador
counter <- 1


library(openxlsx)

# Loop para analizar cada archivo
for (file in files) {
  cat("Procesando archivo", counter, "de", length(files), ":", basename(file), "\n")
  
  # Leer archivo a comparar
  nc_compare <- nc_open(file)
  compare_data <- ncvar_get(nc_compare, "t2m")
  nc_close(nc_compare)
  
  # Calcular indices
  indices <- calculate_indices(ref_data, compare_data)
  
  # Crear un nuevo archivo Excel
  output_excel_path <- paste0(folder_path, "/", sub(".nc$", "", basename(file)), "_indices.xlsx")
  wb <- createWorkbook()
  
  # Agregar cada indice como una hoja separada
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
      "\nPromedio MSE:", avg_mse,
      "\nPromedio KGE:", avg_kge,
      "\nPromedio NSE:", avg_nse
    ),
    con = output_txt
  )
  
  # aumentar contador y limpiar variables
  counter <- counter + 1
  rm(compare_data, indices, wb)
  gc()
}
cat("Proceso completado.\n")

