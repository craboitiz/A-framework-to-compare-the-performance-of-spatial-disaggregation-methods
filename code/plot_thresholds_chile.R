# Computes and plots weighted-index threshold curves for the Chilean domain.
# The script reads the weighted-index table, fits quadratic curves by variable,
# sector, and method, identifies the 0.7 threshold crossing, and saves plots.
# To adapt it, change ruta_base, input Excel filename, threshold value,
# variable/sector/method names, plotting settings, and output folder.

# Paquetes
library(readxl)
library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)
library(writexl)

# Par?metros
ruta_base <- "F:/Cristobal Aboitiz/LISTOS_PAPER/CR2/ESCALADO_CR2"
archivo   <- file.path(ruta_base, "tabla umbral.xlsx")
umbral    <- 0.7

# 1) Leer y pivotar todo en formato tidy
df <- read_excel(archivo) %>%
  mutate(
    Variable = as.character(Variable),
    Sector   = as.character(Sector),
    Escala   = as.numeric(str_replace(as.character(Escala), ",", "."))
  ) %>%
  pivot_longer(
    cols      = c(BIC, BIL, CON1, CON2, DIS, LAF, NN),
    names_to  = "metodo",
    values_to = "indice_ponderado"
  ) %>%
  mutate(
    indice_ponderado = as.numeric(str_replace(as.character(indice_ponderado), ",", "."))
  )

# 2) Calcular thresholds resolviendo sobre la curva ajustada
thresholds <- df %>%
  group_by(Variable, Sector, metodo) %>%
  summarise(
    scale_threshold = {
      # tomamos todos los datos del grupo con pick()
      dat <- pick(everything())
      # 2.1) Ajuste del modelo cuadr?tico
      mod <- lm(indice_ponderado ~ Escala + I(Escala^2), data = dat)
      # 2.2) Generamos la curva predicha
      pred_df <- tibble(
        Escala = seq(min(dat$Escala), max(dat$Escala), length.out = 200)
      ) %>% mutate(pred = predict(mod, newdata = .))
      # 2.3) Interpolamos para encontrar Escala cuando pred == umbral
      approx(x = pred_df$pred, y = pred_df$Escala, xout = umbral)$y
    },
    .groups = "drop"
  )


# 3) Exportar la tabla de thresholds a Excel
write_xlsx(
  thresholds,
  path = file.path(ruta_base, "umbral_thresholds.xlsx")
)

# 4) Preparar carpeta de salida de gr?ficos
dir_plots <- file.path(ruta_base, "plots_umbral_sectores")
if (!dir.exists(dir_plots)) dir.create(dir_plots)

# 5) Graficar - ahora cada punto usa el thr correcto por m?todo
for(v in unique(df$Variable)) {
  for(sec in unique(df$Sector)) {
    sub_df  <- df        %>% filter(Variable == v, Sector == sec)
    thr_dom <- thresholds%>% filter(Variable == v, Sector == sec)
    if (nrow(sub_df)==0 || nrow(thr_dom)==0) next
    
    p <- ggplot(sub_df, aes(x = Escala, y = indice_ponderado)) +
      geom_point(size = 2) +
      # curva cuadr?tica por faceta
      geom_smooth(
        method    = "lm",
        formula   = y ~ x + I(x^2),
        se        = FALSE,
        color     = "steelblue",
        linewidth = 1
      ) +
      geom_hline(yintercept = umbral, linetype = "dashed", linewidth = 0.8) +
      # un punto y etiqueta por m?todo, ubicados en thr_dom
      geom_point(
        data = thr_dom,
        aes(x = scale_threshold, y = umbral),
        shape = 21, size = 4, fill = "red", color = "black"
      ) +
      geom_text(
        data = thr_dom,
        aes(x = scale_threshold, y = umbral,
            label = sprintf("%.2f", scale_threshold)),
        vjust = 1.2, size = 8, color = "black"
      ) +
      facet_wrap(~ metodo, ncol = 1, scales = "free_x") +
      labs(
        title = sprintf("Variable: %s - Sector: %s", v, sec),
        x     = "SCALE",
        y     = "INDEX VALUE"
      ) +
      theme_bw() +
      theme(
        plot.title   = element_text(hjust = 0.5, size = 28, face = "bold"),
        axis.title.x = element_text(size = 24, face = "bold"),
        axis.title.y = element_text(size = 24, face = "bold"),
        axis.text    = element_text(size = 20),
        strip.text   = element_text(size = 22, face = "bold"),
        panel.grid   = element_blank()
      )
    
    ggsave(
      filename = file.path(dir_plots, sprintf("plot_%s_%s.png", v, sec)),
      plot   = p, width = 6, height = 16, dpi = 300
    )
  }
}

