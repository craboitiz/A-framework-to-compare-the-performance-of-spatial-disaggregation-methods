# Formats precipitation metric summaries by climate region for Supporting Information tables.
# The script reads Resumen_Indices.xlsx and creates one workbook with MAE, MSE, KGE,
# and NSE sheets, each containing tables for Domain and climate regions s1-s5.
# To adapt it, change the input/output folder, input Excel filename, list of indices,
# shape names, method names, and scale-code conversion.
# -------------------------------------------------------------------
# Script: Resumen_Indices_TablasPorShape.R
# Lee "Resumen_Indices.xlsx" y genera un nuevo Excel con 4 hojas
# (MAE, MSE, KGE, NSE). En cada hoja coloca 6 tablas (Domain, s1.s5),
# cada una de 7 filas (t?tulo + 6 escalas) y 8 columnas
# (t?tulo + 7 m?todos).
# -------------------------------------------------------------------

# 1) Cargar librer?as
library(readxl)    # Para leer el Excel de entrada
library(openxlsx)  # Para crear y escribir el Excel de salida
library(dplyr)     # Para manipulaci?n de datos
library(tidyr)     # Para pivotar

# 2) Definir rutas
folder       <- "E:/Cristobal Aboitiz/ERA5_9_secciones/pr_secciones/Resultados_climas"
input_file   <- file.path(folder, "Resumen_Indices.xlsx")
output_file  <- file.path(folder, "Resumen_Indices_TablasPorShape.xlsx")

# 3) Par?metros fijos
indices <- c("MAE", "MSE", "KGE", "NSE")
shapes  <- c("Domain", paste0("s", 1:5))
methods <- c("bic", "bil", "con", "con2", "dis", "laf", "nn")

# 4) Crear el workbook de salida
wb_out <- createWorkbook()

# 5) Procesar cada ?ndice
for (idx in indices) {
  # 5.1) Leer la hoja correspondiente
  df <- read_excel(input_file, sheet = idx)
  #    asume columnas: Shape | bic_02 | bic_05 | ... | nn_25
  
  # 5.2) Pivotar a formato largo y descomponer m?todo/escala
  long <- df %>%
    pivot_longer(-Shape,
                 names_to = c("method","scale_code"),
                 names_sep = "_",
                 values_to = "value") %>%
    mutate(
      scale = as.numeric(scale_code) / 10
    ) %>%
    filter(method %in% methods)
  
  # 5.3) Crear hoja para este ?ndice
  addWorksheet(wb_out, idx)
  current_row <- 1
  
  # 5.4) Para cada shape, crear una mini-tabla vertical
  for (sh in shapes) {
    # 5.4.1) Escribir el t?tulo (nombre del shape)
    writeData(wb_out, sheet = idx,
              x = sh,
              startRow = current_row, startCol = 1,
              colNames = FALSE)
    
    # 5.4.2) Extraer y pivotar a ancho: filas = escalas, columnas = m?todos
    tbl <- long %>%
      filter(Shape == sh) %>%
      select(scale, method, value) %>%
      pivot_wider(
        names_from  = method,
        values_from = value
      ) %>%
      arrange(scale)
    
    # Renombrar la primera columna
    names(tbl)[1] <- "Scale"
    # Asegurar orden de columnas: Scale, luego los m?todos
    tbl <- tbl[, c("Scale", methods)]
    
    # 5.4.3) Escribir la mini-tabla
    writeData(wb_out, sheet = idx,
              x = tbl,
              startRow = current_row + 1,
              startCol = 1,
              rowNames = FALSE)
    
    # 5.4.4) Avanzar la fila: 1 t?tulo + nrow(tbl) filas + 1 fila en blanco
    current_row <- current_row + nrow(tbl) + 2
  }
}

# 6) Guardar el archivo resultante
saveWorkbook(wb_out, output_file, overwrite = TRUE)
message("Se ha creado el archivo:\n", output_file)
