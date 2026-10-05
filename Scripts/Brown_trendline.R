#install.packages("png")
library(png)

# Load original PNG image
img_path <- "Brown.png"
img <- readPNG(img_path)

# Extract image dimensions (height x width)
img_h <- dim(img)[1]
img_w <- dim(img)[2]

# Data points extracted from Figure 3 (Brown & Brown 1986)
df_data <- data.frame(
  x = c(0.1, 0.2, 0.4, 0.6, 0.8, 1.0, 1.3, 1.8, 2.1, 2.3, 4.8, 5.8, 6.7, 8.9, 14.8),
  y = c(195, 200, 150, 110, 75, 5, 350, 320, 200, 220, 450, 510, 310, 345, 710)
)

# Linear regression fit
fit <- lm(y ~ x, data = df_data)

# Generate trend points across domain
df_trend <- data.frame(x = seq(0, 15, length.out = 100))
df_trend$y <- predict(fit, newdata = df_trend)

# Linear coordinate mapping function to pixel space (382 x 382)
# Origin (x=0, y=0): (63, 260)
# X-max (x=15): (336, 260)
# Y-max (y=800): (63, 22)
x_to_px <- function(x) { 63 + (x / 15.0) * (336 - 63) }
y_to_px <- function(y) { 260 - (y / 800.0) * (260 - 22) }

px_x <- x_to_px(df_trend$x)
px_y <- y_to_px(df_trend$y)

# Render output directly to file using base graphics device
png("trend_fitted_figure3_base.png", width = img_w, height = img_h, res = 300)

# Set margin parameters to zero to match exact image bounds
par(mar = c(0, 0, 0, 0), xaxs = "i", yaxs = "i")

# Plot canvas matching pixel dimensions
plot(c(0, img_w), c(0, img_h), type = "n", xlab = "", ylab = "", axes = FALSE)

# Draw image to background
rasterImage(img, 0, 0, img_w, img_h)

# Overlay trend line (y-axis inverted for standard graphics orientation)
lines(px_x, img_h - px_y, col = "#00BFFF", lwd = 3)

dev.off()