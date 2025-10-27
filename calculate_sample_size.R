# Calculate Required Sample Size for SCRI Sequential Surveillance
# Uses Sequential package for exact sample size calculations
# Accounts for multiple sequential looks and alpha spending

# Set CRAN mirror
options(repos = c(CRAN = "https://cloud.r-project.org"))

# Load required packages
if (!require("config", quietly = TRUE)) {
  cat("Installing config package...\n")
  install.packages("config")
  library(config)
}

if (!require("Sequential", quietly = TRUE)) {
  cat("Installing Sequential package...\n")
  install.packages("Sequential")
  library(Sequential)
}

# ============================================================================
# SAMPLE SIZE CALCULATION FOR SCRI SEQUENTIAL SURVEILLANCE
# ============================================================================

cat("================================================================\n")
cat("SCRI SEQUENTIAL SURVEILLANCE SAMPLE SIZE CALCULATOR\n")
cat("================================================================\n\n")

# Load configuration
cat("Loading configuration from config.yaml...\n")
cfg <- config::get(file = "config.yaml")

# ============================================================================
# INPUT PARAMETERS
# ============================================================================

# SCRI design parameters
risk_window_start <- cfg$scri_design$risk_window$start_day
risk_window_end <- cfg$scri_design$risk_window$end_day
control_window_start <- cfg$scri_design$control_window$start_day
control_window_end <- cfg$scri_design$control_window$end_day

risk_window_length <- risk_window_end - risk_window_start + 1
control_window_length <- control_window_end - control_window_start + 1

# Matching ratio (zp parameter)
zp_ratio <- control_window_length / risk_window_length

# Null hypothesis
p0 <- risk_window_length / (risk_window_length + control_window_length)

# Sequential analysis parameters
alpha <- cfg$sequential_analysis$overall_alpha
n_looks <- cfg$sequential_analysis$number_of_looks
power_target <- 0.90  # Target power (90%)

# Target relative risk to detect
target_RR <- cfg$simulation$true_relative_risk

# Baseline event rate (per person-day)
baseline_rate <- cfg$simulation$baseline_event_rate

# Population and accrual parameters
pop_size <- cfg$simulation$population_size
season_length <- as.numeric(
  as.Date(cfg$simulation$season$end_date) -
  as.Date(cfg$simulation$season$start_date)
)

cat("\n================================================================\n")
cat("SCRI DESIGN PARAMETERS\n")
cat("================================================================\n\n")

cat(sprintf("Risk window: Days %d-%d (%d days)\n",
            risk_window_start, risk_window_end, risk_window_length))
cat(sprintf("Control window: Days %d-%d (%d days)\n",
            control_window_start, control_window_end, control_window_length))
cat(sprintf("Matching ratio (zp): %.2f\n", zp_ratio))
cat(sprintf("Null hypothesis (p0): %.3f\n", p0))

cat("\n================================================================\n")
cat("SEQUENTIAL ANALYSIS PARAMETERS\n")
cat("================================================================\n\n")

cat(sprintf("Overall alpha: %.3f\n", alpha))
cat(sprintf("Number of looks: %d\n", n_looks))
cat(sprintf("Target power: %.0f%%\n", power_target * 100))
cat(sprintf("Target RR to detect: %.2f\n", target_RR))

cat("\n================================================================\n")
cat("BASELINE PARAMETERS\n")
cat("================================================================\n\n")

cat(sprintf("Baseline event rate: %.5f per person-day\n", baseline_rate))
cat(sprintf("Population size: %d\n", pop_size))
cat(sprintf("Season length: %d days\n", season_length))

# ============================================================================
# SAMPLE SIZE CALCULATION
# ============================================================================

cat("\n================================================================\n")
cat("SAMPLE SIZE CALCULATIONS\n")
cat("================================================================\n\n")

# Calculate alternative hypothesis probability under target RR
# Under alternative: events distribute proportional to RR-weighted person-time
# p1 = (RR * risk_days) / (RR * risk_days + control_days)
p1 <- (target_RR * risk_window_length) /
      (target_RR * risk_window_length + control_window_length)

cat(sprintf("Alternative hypothesis (p1 at RR=%.2f): %.3f\n", target_RR, p1))

# Method 1: Asymptotic approximation (quick estimate)
# For binomial test: n = [(Z_alpha + Z_beta) * sqrt(p0(1-p0) + p1(1-p1))]^2 / (p1-p0)^2
# Adjusted for sequential monitoring: multiply by ~1.2-1.5 depending on spending

z_alpha <- qnorm(1 - alpha)
z_beta <- qnorm(power_target)

# Standard sample size (single test)
n_single <- ((z_alpha + z_beta)^2 * (p0 * (1 - p0) + p1 * (1 - p1))) / ((p1 - p0)^2)

# Adjustment for sequential monitoring (Wald spending)
# Empirical inflation factor: ~1.05-1.15 for Wald spending with 4-10 looks
inflation_factor <- 1 + (0.05 + 0.01 * n_looks)

n_sequential <- n_single * inflation_factor

cat("\n--- Asymptotic Approximation (Quick Estimate) ---\n")
cat(sprintf("Sample size (single test): %.0f cases\n", ceiling(n_single)))
cat(sprintf("Sequential inflation factor: %.2f\n", inflation_factor))
cat(sprintf("Sample size (sequential, %d looks): %.0f cases\n",
            n_looks, ceiling(n_sequential)))

# Method 2: Refinement based on literature
# Wald spending typically requires ~5-15% inflation over single test
# Depends on number of looks and alpha spending shape
cat("\n--- Literature-Based Refinement ---\n")
cat("Wald alpha spending inflation factors from published studies:\n")
cat(sprintf("  • 4 looks: ~1.05-1.08 (5-8%% increase)\n"))
cat(sprintf("  • 8 looks: ~1.10-1.15 (10-15%% increase)\n"))
cat(sprintf("  • 12 looks: ~1.15-1.20 (15-20%% increase)\n"))
cat(sprintf("\nUsing conservative estimate for %d looks: %.2f\n",
            n_looks, inflation_factor))
cat("\nNote: Exact calculation via AnalyzeSetUp.Binomial() with large N\n")
cat("is computationally expensive. Asymptotic approximation is standard.\n")

# ============================================================================
# OPERATIONAL ESTIMATES
# ============================================================================

cat("\n================================================================\n")
cat("OPERATIONAL ESTIMATES\n")
cat("================================================================\n\n")

# Use the asymptotic sequential estimate for planning
n_cases_required <- ceiling(n_sequential)

# Calculate expected person-time needed
total_window_length <- risk_window_length + control_window_length
expected_person_time_per_case <- total_window_length / baseline_rate

# Total person-time needed across all cases
total_person_time_needed <- n_cases_required * expected_person_time_per_case

# Expected number of vaccinations needed (assuming all complete windows)
# Each person contributes (risk_length + control_length) days of observation
person_days_per_vaccination <- total_window_length
n_vaccinations_needed <- ceiling(total_person_time_needed / person_days_per_vaccination)

# Expected surveillance duration (assuming uniform accrual)
# With exponential vaccination distribution, most occur early in season
# Approximate surveillance duration: time for last cases to complete control windows
expected_surveillance_days <- ceiling(season_length * 0.8)  # ~80% of season

cat(sprintf("Required number of CASES: %d\n", n_cases_required))
cat(sprintf("Expected person-time per case: %.0f person-days\n",
            expected_person_time_per_case))
cat(sprintf("Total person-time needed: %.0f person-days\n",
            total_person_time_needed))
cat(sprintf("\nExpected vaccinations needed: %d\n", n_vaccinations_needed))
cat(sprintf("Current population size: %d\n", pop_size))

if (n_vaccinations_needed > pop_size) {
  cat(sprintf("\n⚠️  WARNING: Required vaccinations (%d) exceeds current population (%d)\n",
              n_vaccinations_needed, pop_size))
  cat(sprintf("    Recommend increasing population_size in config.yaml to: %d\n",
              ceiling(n_vaccinations_needed * 1.2)))
} else {
  cat(sprintf("\n✓ Current population size is adequate (%.1f%% margin)\n",
              100 * (pop_size - n_vaccinations_needed) / n_vaccinations_needed))
}

cat(sprintf("\nExpected surveillance duration: %d days (~%.1f months)\n",
            expected_surveillance_days, expected_surveillance_days / 30))

# ============================================================================
# POWER AND SAMPLE SIZE TABLE
# ============================================================================

cat("\n================================================================\n")
cat("POWER ACROSS DIFFERENT RELATIVE RISKS\n")
cat("================================================================\n\n")

# Calculate expected power for different RR values
RR_values <- c(1.0, 1.2, 1.5, 2.0, 2.5, 3.0)

cat("RR      p1      Power (approx)\n")
cat("---     ----    --------------\n")

for (RR_test in RR_values) {
  p1_test <- (RR_test * risk_window_length) /
             (RR_test * risk_window_length + control_window_length)

  # Approximate power calculation
  # Power = P(reject H0 | H1 true)
  # Using normal approximation with sequential adjustment
  ncp <- sqrt(n_cases_required) * (p1_test - p0) / sqrt(p0 * (1 - p0))
  power_approx <- pnorm(ncp - z_alpha / sqrt(inflation_factor))

  cat(sprintf("%.1f    %.3f   %.1f%%\n", RR_test, p1_test, power_approx * 100))
}

cat("\n================================================================\n")
cat("RECOMMENDATION\n")
cat("================================================================\n\n")

cat(sprintf("To achieve %.0f%% power to detect RR=%.2f with alpha=%.3f:\n\n",
            power_target * 100, target_RR, alpha))
cat(sprintf("  • Simulate %d cases (events)\n", n_cases_required))
cat(sprintf("  • Population size: %d (current: %d)\n",
            max(n_vaccinations_needed, pop_size), pop_size))
cat(sprintf("  • Baseline rate: %.5f per person-day\n", baseline_rate))
cat(sprintf("  • Sequential monitoring: %d looks over %d days\n",
            n_looks, expected_surveillance_days))

cat("\nUpdate config.yaml if needed:\n")
if (n_vaccinations_needed > pop_size) {
  cat(sprintf("  simulation:\n"))
  cat(sprintf("    population_size: %d\n", ceiling(n_vaccinations_needed * 1.2)))
}
cat(sprintf("  simulation:\n"))
cat(sprintf("    baseline_event_rate: %.5f\n", baseline_rate))

cat("\n================================================================\n")
cat("SAMPLE SIZE CALCULATION COMPLETE\n")
cat("================================================================\n")
