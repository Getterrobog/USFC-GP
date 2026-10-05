# Load required libraries
library(ggplot2)

# Set seed for reproducibility
set.seed(1899)

# Define simulation time grid
t_max <- 100
dt <- 0.1
time <- seq(0, t_max, by = dt)
n_steps <- length(time)

# --- Model Parameters ---
K0    <- 1000   # Baseline mean carrying capacity
A     <- 0.3    # Amplitude of macro-seasonal cycle
omega <- 0.2    # Frequency of macro-seasons
N0    <- 25     # Initial population size
r     <- 0.25   # Intrinsic growth rate

# --- Ornstein-Uhlenbeck (OU) Red Noise Parameters ---
theta <- 0.15   # Mean reversion rate (environmental memory)
sigma <- 0.15   # Environmental volatility (noise amplitude)

# Simulate OU stochastic process for environmental noise epsilon(t)
epsilon <- numeric(n_steps)
epsilon[1] <- 0

for (i in 2:n_steps) {
  dW <- rnorm(1, mean = 0, sd = sqrt(dt))
  epsilon[i] <- epsilon[i-1] - theta * epsilon[i-1] * dt + sigma * dW
}

# Construct Stochastic Carrying Capacity K(t)
# K(t) = K0 * (1 + A*sin(omega*t) + epsilon(t))
K_t <- K0 * (1 + A * sin(omega * time) + epsilon)
K_t <- pmax(K_t, 1) # Floor to prevent non-positive K

# --- Evaluate Analytical Trajectory ---
# y(t) = K(t) / (1 + ((K(t) - N0) / N0) * exp(-r * t))
y_analytical <- numeric(n_steps)
y_analytical[1] <- N0

for (i in 2:n_steps) {
  t_i <- time[i]
  K_i <- K_t[i]
  y_analytical[i] <- K_i / (1 + ((K_i - N0) / N0) * exp(-r * t_i))
}

# Data frame for visualization
df_eval <- data.frame(
  Time = time,
  Population = y_analytical,
  CarryingCapacity = K_t
)

# Plot Trajectory
ggplot(df_eval, aes(x = Time)) +
  geom_line(aes(y = CarryingCapacity, color = "Environmental K(t)"), linetype = "dashed", size = 0.8) +
  geom_line(aes(y = Population, color = "Population Trajectory y(t)"), size = 1.1) +
  scale_color_manual(values = c("Environmental K(t)" = "darkred", "Population Trajectory y(t)" = "navy")) +
  labs(
    title = "Analytical Model with Autocorrelated Environmental Stochasticity",
    subtitle = "Driven by an Ornstein-Uhlenbeck noise process on Carrying Capacity K(t)",
    x = "Time (t)",
    y = "Abundance / Density",
    color = "Variable"
  ) +
  theme_minimal()
#Framework 2: Numerical Integration of Itô Stochastic Differential Equation (SDE)If the intention is to allow environmental noise to perturb growth directly at every instantaneous step rather than updating an integrated curve parameter, numerical solution via Euler-Maruyama integration solves:$$dy_t = r y_t \left(1 - \frac{y_t}{K_0(1 + A \sin(\omega t))}\right) dt + \sigma_{env} y_t dW_t$$R# SDE Simulation via Euler-Maruyama Method
set.seed(1899)

sigma_env <- 0.08 # Environmental volatility parameter

y_sde <- numeric(n_steps)
y_sde[1] <- N0

for (i in 1:(n_steps - 1)) {
  t_i <- time[i]
  y_i <- y_sde[i]
  
  # Time-varying baseline K
  K_base <- K0 * (1 + A * sin(omega * t_i))
  
  # Drift term: f(y, t) = r * y * (1 - y / K(t))
  drift <- r * y_i * (1 - (y_i / K_base))
  
  # Diffusion term: g(y, t) = sigma_env * y
  diffusion <- sigma_env * y_i
  
  # Wiener increment
  dW <- rnorm(1, mean = 0, sd = sqrt(dt))
  
  # Euler-Maruyama update
  y_next <- y_i + drift * dt + diffusion * dW
  y_sde[i + 1] <- max(y_next, 0) # Non-negativity boundary condition
}

df_sde <- data.frame(Time = time, Population = y_sde)

ggplot(df_sde, aes(x = Time, y = Population)) +
  geom_line(color = "darkgreen", size = 0.5) +
  labs(
    title = "Continuous environmental stochasticity acting on growth rate",
    x = "Time (t)",
    y = "Population Size (y)"
  ) +
  theme_minimal()
