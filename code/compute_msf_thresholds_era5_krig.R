# Computes threshold scales and Maximum Scaling Factors from weighted-index summary tables.
# The weighted index was previously calculated in Excel from MAE, MSE, KGE, and NSE
# and stored in the "Ponderado" sheet of the precipitation and temperature summary files.
# The script reads those sheets, fits a quadratic relationship between weighted index
# and scale, identifies the 0.7 threshold crossing, and computes MSF as
# scale_threshold / original_resolution.
# To adapt it, change archivo_pr, archivo_tas, output_dir, umbral,
# original_resolution, method names, and the expected structure of the Ponderado sheet.
# ============================================================
# CALCULAR UMBRAL / MAXIMUM SCALING FACTOR - ERA5 KRIG FINAL
#
# This script starts from the weighted-index summary tables.
# The weighted index was previously calculated in Excel from
# MAE, MSE, KGE, and NSE, and stored in the "Ponderado" sheet
# of the precipitation and temperature summary files.
#
# The script reads the "Ponderado" sheets, fits the quadratic
# relationship between weighted index and scale, identifies the
# 0.7 threshold crossing, and computes the Maximum Scaling Factor
# as scale_threshold / original_resolution.
# ============================================================
# ============================================================
# CALCULAR UMBRAL / MAXIMUM SCALING FACTOR - ERA5 KRIG FINAL
# Basado en el c?digo original "Graficos umbral ERA.R"
# Solo calcula thresholds. No grafica.
# ============================================================

library(readxl)
library(dplyr)
library(tidyr)
library(stringr)
library(writexl)

rm(list = ls())
graphics.off()

# ============================================================
# CONFIGURACI?N
# ============================================================

# Cambia estas rutas si tus archivos est?n en otra carpeta
archivo_pr <- "G:/Cristobal_Aboitiz/Paper/KRIG/ERA5_pr_Summary_table.xlsx"
archivo_tas <- "G:/Cristobal_Aboitiz/Paper/KRIG/ERA5_t2m_Summary_table_tas.xlsx"

# Carpeta de salida
output_dir <- "G:/Cristobal_Aboitiz/Paper/KRIG/umbrales_MSF_actual"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Umbral usado en el paper
umbral <- 0.7

# Resoluci?n original ERA5-Land en Sudam?rica
# MSF = scale_threshold / original_resolution
original_resolution <- 0.1

# M?todos en el orden de las tablas del paper
methods_order <- c("BIC", "BIL", "DIS", "CON1", "CON2", "LAF", "NN", "KRIG")

# ============================================================
# HELPERS
# ============================================================

to_num <- function(x) {
  suppressWarnings(as.numeric(str_replace(as.character(x), ",", ".")))
}

cell_value <- function(df, r, c) {
  if (r < 1 || r > nrow(df) || c < 1 || c > ncol(df)) return(NA)
  df[[c]][r]
}

normalize_method <- function(x) {
  x <- str_to_upper(str_trim(as.character(x)))
  if (x == "CON") x <- "CON1"
  return(x)
}

# ------------------------------------------------------------
# Esta funci?n extrae el bloque PONDERADO desde la hoja "Ponderado"
# de los Summary_table actuales.
#
# La l?gica es:
# - Busca la celda "Factor"
# - El bloque Ponderado comienza en el primer "Scale" a la derecha
# - Lee Domain, s1, s2, s3, s4, s5 verticalmente
# ------------------------------------------------------------

read_weighted_from_summary <- function(file_path, variable_label) {
  
  if (!file.exists(file_path)) {
    stop("No existe el archivo: ", file_path)
  }
  
  cat("Leyendo:", file_path, "\n")
  
  raw <- read_excel(
    file_path,
    sheet = "Ponderado",
    col_names = FALSE,
    .name_repair = "minimal"
  )
  
  # Buscar celda "Factor"
  factor_loc <- NULL
  
  for (r in seq_len(nrow(raw))) {
    for (c in seq_len(ncol(raw))) {
      val <- cell_value(raw, r, c)
      if (!is.na(val) && str_to_lower(str_trim(as.character(val))) == "factor") {
        factor_loc <- c(r, c)
        break
      }
    }
    if (!is.null(factor_loc)) break
  }
  
  if (is.null(factor_loc)) {
    stop("No encontr? la celda 'Factor' en la hoja Ponderado de: ", file_path)
  }
  
  factor_row <- factor_loc[1]
  factor_col <- factor_loc[2]
  
  header_row <- factor_row + 1
  
  # Buscar primer "Scale" a la derecha de Factor
  scale_cols <- c()
  
  for (c in seq((factor_col + 1), ncol(raw))) {
    val <- cell_value(raw, header_row, c)
    if (!is.na(val) && str_to_lower(str_trim(as.character(val))) == "scale") {
      scale_cols <- c(scale_cols, c)
    }
  }
  
  if (length(scale_cols) == 0) {
    stop("No encontr? el bloque Ponderado despu?s de 'Factor' en: ", file_path)
  }
  
  start_col <- scale_cols[1]
  
  cat("  Bloque ponderado detectado en columna:", start_col, "\n")
  
  out <- data.frame(
    Variable = character(),
    Sector = character(),
    Escala = numeric(),
    metodo = character(),
    indice_ponderado = numeric(),
    stringsAsFactors = FALSE
  )
  
  # El primer sector est? una fila antes del header
  r <- header_row - 1
  
  while (r <= nrow(raw)) {
    
    sector_name <- cell_value(raw, r, start_col)
    
    if (!is.na(sector_name) && str_trim(as.character(sector_name)) != "") {
      
      sector_name <- str_trim(as.character(sector_name))
      h <- r + 1
      
      header_check <- cell_value(raw, h, start_col)
      
      if (!is.na(header_check) &&
          str_to_lower(str_trim(as.character(header_check))) == "scale") {
        
        # Leer m?todos desde la fila de encabezado
        method_cols <- data.frame(
          metodo = character(),
          col = integer(),
          stringsAsFactors = FALSE
        )
        
        cc <- start_col + 1
        
        while (cc <= ncol(raw)) {
          method_name <- cell_value(raw, h, cc)
          
          if (is.na(method_name) || str_trim(as.character(method_name)) == "") {
            break
          }
          
          method_cols <- rbind(
            method_cols,
            data.frame(
              metodo = normalize_method(method_name),
              col = cc,
              stringsAsFactors = FALSE
            )
          )
          
          cc <- cc + 1
        }
        
        # Leer filas de escalas
        rr <- h + 1
        
        while (rr <= nrow(raw)) {
          
          escala_val <- to_num(cell_value(raw, rr, start_col))
          
          if (is.na(escala_val)) {
            break
          }
          
          for (k in seq_len(nrow(method_cols))) {
            
            metodo_k <- method_cols$metodo[k]
            col_k <- method_cols$col[k]
            indice_val <- to_num(cell_value(raw, rr, col_k))
            
            out <- rbind(
              out,
              data.frame(
                Variable = variable_label,
                Sector = sector_name,
                Escala = escala_val,
                metodo = metodo_k,
                indice_ponderado = indice_val,
                stringsAsFactors = FALSE
              )
            )
          }
          
          rr <- rr + 1
        }
        
        r <- rr
        
      } else {
        r <- r + 1
      }
      
    } else {
      r <- r + 1
    }
  }
  
  out <- out %>%
    filter(
      !is.na(Escala),
      !is.na(indice_ponderado),
      metodo %in% methods_order
    )
  
  return(out)
}

# ------------------------------------------------------------
# Esta funci?n replica la l?gica original:
# lm(indice_ponderado ~ Escala + I(Escala^2))
# luego approx(pred, Escala, xout = 0.7)
# ------------------------------------------------------------

calculate_threshold_original_method <- function(escala, indice, umbral = 0.7) {
  
  dat <- data.frame(
    Escala = escala,
    indice_ponderado = indice
  ) %>%
    filter(
      is.finite(Escala),
      is.finite(indice_ponderado)
    ) %>%
    arrange(Escala)
  
  if (nrow(dat) < 3) {
    return(NA_real_)
  }
  
  # Si todos est?n bajo el umbral, el cruce puede no ser confiable
  # Pero mantenemos la l?gica original: ajustar curva y buscar cruce.
  out <- tryCatch({
    
    mod <- lm(indice_ponderado ~ Escala + I(Escala^2), data = dat)
    
    pred_df <- data.frame(
      Escala = seq(
        min(dat$Escala, na.rm = TRUE),
        max(dat$Escala, na.rm = TRUE),
        length.out = 200
      )
    )
    
    pred_df$pred <- predict(mod, newdata = pred_df)
    
    # approx() igual que el c?digo original
    thr <- approx(
      x = pred_df$pred,
      y = pred_df$Escala,
      xout = umbral
    )$y
    
    as.numeric(thr)
    
  }, error = function(e) {
    NA_real_
  })
  
  if (length(out) == 0 || !is.finite(out)) {
    return(NA_real_)
  }
  
  return(out)
}

# ============================================================
# LEER DATOS ACTUALES
# ============================================================

df_pr <- read_weighted_from_summary(
  file_path = archivo_pr,
  variable_label = "Precipitation"
)

df_tas <- read_weighted_from_summary(
  file_path = archivo_tas,
  variable_label = "Temperature"
)

df_all <- bind_rows(df_pr, df_tas)

cat("\nDatos le?dos:\n")
print(
  df_all %>%
    group_by(Variable, Sector, metodo) %>%
    summarise(n = n(), .groups = "drop") %>%
    arrange(Variable, Sector, metodo)
)

# ============================================================
# CALCULAR THRESHOLDS
# ============================================================

thresholds <- df_all %>%
  group_by(Variable, Sector, metodo) %>%
  summarise(
    scale_threshold = calculate_threshold_original_method(
      escala = Escala,
      indice = indice_ponderado,
      umbral = umbral
    ),
    .groups = "drop"
  ) %>%
  mutate(
    MSF = scale_threshold / original_resolution
  ) %>%
  arrange(Variable, Sector, factor(metodo, levels = methods_order))

# ============================================================
# ARMAR TABLE 5 DEL DOMINIO COMPLETO
# ============================================================

table5_domain <- thresholds %>%
  filter(Sector == "Domain") %>%
  select(Variable, metodo, MSF) %>%
  pivot_wider(
    names_from = Variable,
    values_from = MSF
  ) %>%
  rename(Method = metodo) %>%
  mutate(
    Method = factor(Method, levels = methods_order)
  ) %>%
  arrange(Method) %>%
  mutate(
    Method = as.character(Method),
    Precipitation = round(Precipitation, 1),
    Temperature = round(Temperature, 1)
  )

# ============================================================
# GUARDAR RESULTADOS
# ============================================================

output_file <- file.path(output_dir, "umbral_thresholds_actual_KRIG.xlsx")

write_xlsx(
  list(
    thresholds_all = thresholds,
    table5_domain = table5_domain,
    data_used = df_all
  ),
  path = output_file
)

# Tambi?n guardar CSV simple por si quieres copiar r?pido
write.csv(
  thresholds,
  file = file.path(output_dir, "thresholds_all.csv"),
  row.names = FALSE
)

write.csv(
  table5_domain,
  file = file.path(output_dir, "table5_domain_MSF.csv"),
  row.names = FALSE
)

# ============================================================
# IMPRIMIR RESULTADOS PRINCIPALES
# ============================================================

cat("\n========================================\n")
cat("TABLE 5 - DOMAIN MSF\n")
cat("========================================\n")
print(table5_domain)

cat("\n========================================\n")
cat("Archivos guardados en:\n")
cat(output_file, "\n")
cat(file.path(output_dir, "thresholds_all.csv"), "\n")
cat(file.path(output_dir, "table5_domain_MSF.csv"), "\n")
cat("========================================\n")