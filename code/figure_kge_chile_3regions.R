# Generates KGE map visualizations and boxplots for the Chilean domain and its
# North, Central, and South subregions.
# To adapt it, change input_dir, input Excel file, output folder, spatial extent,
# subregion column ranges, percentile clipping limits, color palette, and figure labels.
# --------------------------------------------------------------------------
# Script: graficar_KGE_prueba_con_boxplot_vertical_ajustado6_con_lineas_corregido.R
# Usa exclusivamente la hoja "KGE" del Excel (800 columnas, sin t?tulos de fila),
# y corrige la lectura de datos para no eliminar filas ni columnas de encabezado.
# --------------------------------------------------------------------------

# -------------------------------
# 1) Cargar librer?as necesarias
# -------------------------------
library(readxl)
library(terra)
library(tools)

# -------------------------------
# 2) Definir rutas y par?metros
# -------------------------------
input_dir  <- "F:/Cristobal Aboitiz/LISTOS_PAPER/CR2/ESCALADO_CR2"
input_file <- file.path(input_dir, "bic_1_pr_CR2_1960_2021_indices.xlsx")

output_dir <- file.path(input_dir, "imagenes_KGE")
dir.create(output_dir, showWarnings = FALSE)

# Extensi?n aproximada de Chile continental
xmin_full <- -85; xmax_full <- -30
ymin_full <- -60; ymax_full <-  15

# Rangos de columnas para subregiones
South_cols  <- 1:260
Center_cols <- 261:520
North_cols  <- 521:800

# Percentiles para recorte de outliers
lower_pct <- 0.03; upper_pct <- 1

# Paleta saturada
pal_cols <- c("#FF6666","#FFFF66","#66FF66")
paleta   <- colorRampPalette(pal_cols)(100)

# -------------------------------
# 3) Leer solamente la hoja "KGE" sin nombres de columna
# -------------------------------
df_full <- read_excel(input_file,
                      sheet     = "KGE",
                      col_names = FALSE)

# Convertir todo el data.frame a matriz num?rica (800 columnas)
mat <- as.matrix(df_full)
storage.mode(mat) <- "numeric"

# -------------------------------
# 4) Funci?n auxiliar (sin cambios)
# -------------------------------
guardar_png <- function(mat_sub, xmin_sub, xmax_sub, ymin_sub, ymax_sub, nombre_out) {
  mat_t <- t(mat_sub)[ncol(mat_sub):1, ]
  r_sub <- rast(mat_t)
  ext(r_sub) <- c(xmin_sub,xmax_sub,ymin_sub,ymax_sub)
  crs(r_sub)   <- "+proj=longlat +datum=WGS84"
  
  vals <- values(r_sub)
  q <- quantile(vals, c(lower_pct, upper_pct), na.rm=TRUE)
  if (q[1]==q[2]) q <- range(vals, na.rm=TRUE)
  
  r_plot   <- clamp(r_sub, lower=q[1], upper=q[2])
  box_vals <- values(r_plot)
  
  out_png <- file.path(output_dir, paste0(nombre_out,".png"))
  png(out_png, width=1200, height=600, res=100)
  
  layout(matrix(c(1,2),1), widths=c(3,1))
  par(cex=1.3, mar=c(1,1,2.5,1), oma=c(2,2,2,2))
  
  terra::plot(r_plot, col=paleta, range=q, fill_range=TRUE, legend=TRUE,
              axes=FALSE, main=nombre_out, cex.main=1.3)
  
  par(mar=c(5,5,3,1))
  boxplot(box_vals, horizontal=FALSE, boxwex=0.5, col="gray",
          outline    = FALSE, ylim       = c(-0.5, 1),
          main="Distribution", cex.main=1.1, cex.axis=0.9)
  mtext("KGE Value", side=2, line=3, cex=1.1)
  
  dev.off()
}

# -------------------------------
# 5) Continental Chile con l?neas horizontales
# -------------------------------
mat_full_t <- t(mat)[ncol(mat):1, ]
r_full     <- rast(mat_full_t)
ext(r_full) <- c(xmin_full,xmax_full,ymin_full,ymax_full)
crs(r_full)   <- "+proj=longlat +datum=WGS84"

vals_full     <- values(r_full)
q_full        <- quantile(vals_full, c(lower_pct, upper_pct), na.rm=TRUE)
if (q_full[1]==q_full[2]) q_full <- range(vals_full, na.rm=TRUE)
r_full_plot   <- clamp(r_full, lower=q_full[1], upper=q_full[2])
box_full_vals <- values(r_full_plot)

# calcular latitudes de separaci?n
h1 <- ymin_full + (ymax_full - ymin_full)/3    # Norte/Centro
h2 <- ymin_full + 2*(ymax_full - ymin_full)/3  # Centro/Sur

out_full <- file.path(output_dir, "Chile_completo.png")
png(out_full, width=1200, height=600, res=100)

layout(matrix(c(1,2),1), widths=c(3,1))
par(cex=1.3, mar=c(1,1,2.5,1), oma=c(2,2,2,2))

terra::plot(r_full_plot, col=paleta, range=q_full, fill_range=TRUE,
            legend=TRUE, axes=FALSE,
            main="Continental Chile", cex.main=1.3)

# a?adir l?neas horizontales sin tocar el boxplot ni textos
abline(h = c(h1, h2), col="black", lwd=2)

par(mar=c(5,5,3,1))
boxplot(box_full_vals, horizontal=FALSE, boxwex=0.5, col="gray",
        outline    = FALSE, ylim       = c(-0.5, 1),
        main="Distribution", cex.main=1.1, cex.axis=0.9)
mtext("KGE Value", side=2, line=3, cex=1.1)

dev.off()

# -------------------------------
# 6) Subregiones (sin cambios)
# -------------------------------
dx   <- (xmax_full - xmin_full)/ncol(mat)
xmin_S <- xmin_full + (South_cols[1]-1)*dx
xmax_S <- xmin_full + max(South_cols)*dx
guardar_png(mat[,South_cols], xmin_S, xmax_S, ymin_full, ymax_full, "Southern Chile")

xmin_C <- xmin_full + (Center_cols[1]-1)*dx
xmax_C <- xmin_full + max(Center_cols)*dx
guardar_png(mat[,Center_cols], xmin_C, xmax_C, ymin_full, ymax_full, "Center Chile")

xmin_N <- xmin_full + (North_cols[1]-1)*dx
xmax_N <- xmin_full + max(North_cols)*dx
guardar_png(mat[,North_cols], xmin_N, xmax_N, ymin_full, ymax_full, "Northern Chile")

message("?Hecho! Revisa las im?genes en:\n", normalizePath(output_dir))
