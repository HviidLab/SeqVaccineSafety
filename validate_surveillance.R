# Validate Sequential Surveillance System
# Type I Error and Power Validation using SequentialDesign Package
# Self-Controlled Risk Interval (SCRI) Design
# Target population: Adults aged 65+ years

# This script performs validation studies to assess:
# 1. Type I error control (with RR = 1.0, no elevated risk)
# 2. Statistical power (with RR = 1.5, true elevated risk)
# Using 1000+ simulations per scenario

# Set CRAN mirror
options(repos = c(CRAN = "https://cloud.r-project.org"))

# Load required packages
required_packages <- c("config", "SequentialDesign", "Sequential", "ggplot2")

for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    cat(sprintf("Installing '%s' package...\n", pkg))
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}

cat("===============================================================\n")
cat("SEQUENTIAL SURVEILLANCE VALIDATION SYSTEM\n")
cat("Type I Error and Power Validation\n")
cat("===============================================================\n\n")

# ============================================================================
# LOAD CONFIGURATION
# ============================================================================

cat("Loading configuration from config.yaml...\n")
cfg <- config::get(file = "config.yaml")

# Set seed for reproducibility
if (!is.null(cfg$simulation$random_seed)) {
  set.seed(cfg$simulation$random_seed)
  cat(sprintf("Random seed set to: %d\n", cfg$simulation$random_seed))
}

# ============================================================================
# VALIDATION PARAMETERS
# ============================================================================

cat("\nSetting up validation parameters...\n")

# Extract SequentialDesign parameters
sd_params <- cfg$simulation$sequential_design
n_sims <- sd_params$n_simulations
t0 <- sd_params$t0
tf <- sd_params$tf
n_strata <- sd_params$n_strata
strata_ratio <- unlist(sd_params$strata_ratio)
event_rate <- unlist(sd_params$event_rate_by_strata)
sensitivity <- sd_params$sensitivity
ppv_est <- sd_params$positive_predictive_value
match_ratio <- sd_params$match_ratio
exposure_rate <- sd_params$exposure_rate
exposure_offset <- sd_params$exposure_offset

# Sequential analysis parameters
alpha <- cfg$sequential_analysis$overall_alpha
n_looks <- cfg$sequential_analysis$number_of_looks
min_events <- cfg$sequential_analysis$minimum_cases_per_look
alpha_spend_type <- "Wald"  # Use Wald for validation
alpha_parameter <- sd_params$alpha_parameter
max_sample_size <- sd_params$max_sample_size

# SCRI window parameters
risk_window_start <- cfg$scri_design$risk_window$start_day
risk_window_end <- cfg$scri_design$risk_window$end_day
control_window_start <- cfg$scri_design$control_window$start_day
control_window_end <- cfg$scri_design$control_window$end_day

risk_window_length <- risk_window_end - risk_window_start + 1
control_window_length <- control_window_end - control_window_start + 1

cat(sprintf("  Number of simulations per scenario: %d\n", n_sims))
cat(sprintf("  Number of strata: %d\n", n_strata))
cat(sprintf("  Alpha (Type I error): %.3f\n", alpha))
cat(sprintf("  Number of looks: %d\n", n_looks))
cat(sprintf("  Risk window: Days %d-%d (%d days)\n",
            risk_window_start, risk_window_end, risk_window_length))
cat(sprintf("  Control window: Days %d-%d (%d days)\n\n",
            control_window_start, control_window_end, control_window_length))

# Create output directory
validation_dir <- file.path(getwd(), cfg$output$directory, "validation_results")
if (!dir.exists(validation_dir)) {
  dir.create(validation_dir, recursive = TRUE)
}

# ============================================================================
# SCENARIO 1: TYPE I ERROR VALIDATION (RR = 1.0)
# ============================================================================

cat("===============================================================\n")
cat("SCENARIO 1: TYPE I ERROR VALIDATION\n")
cat("===============================================================\n")
cat("Testing false positive rate with NO elevated risk (RR = 1.0)\n")
cat(sprintf("Running %d simulations...\n", n_sims))
cat("This may take 10-30 minutes depending on system performance...\n\n")

# Create subdirectory for Type I error results
type1_dir <- file.path(validation_dir, "type1_error_RR1.0")
if (!dir.exists(type1_dir)) {
  dir.create(type1_dir, recursive = TRUE)
}

# Initialize parameters for Type I error scenario
params_type1 <- initialize.data(
  seed = cfg$simulation$random_seed,
  N = n_sims,
  t0 = t0,
  tf = tf,
  NStrata = n_strata,
  strataRatio = strata_ratio,
  EventRate = event_rate,
  sensitivity = sensitivity,
  PPVest = ppv_est,
  RR = 1.0,  # NULL HYPOTHESIS: No elevated risk
  MatchRatio = match_ratio,
  maxSampleSize = max_sample_size,
  maxTest = n_looks,
  totalAlpha = alpha,
  minEvents = min_events,
  AlphaSpendType = alpha_spend_type,
  AlphaParameter = alpha_parameter,
  address = type1_dir,
  rate = exposure_rate,
  offset = exposure_offset
)

cat("Creating exposure matrices...\n")
exposure_type1 <- create.exposure(params_type1)

cat("Simulating exposure data...\n")
exposure_data_type1 <- sim.exposure(exposure_type1, params_type1)

cat("Running SCRI sequential analysis...\n")
start_time_type1 <- Sys.time()
results_type1 <- SCRI.seq(exposure_data_type1, params_type1)
end_time_type1 <- Sys.time()

cat(sprintf("\nType I error validation complete!\n"))
cat(sprintf("Computation time: %.2f minutes\n\n",
            as.numeric(difftime(end_time_type1, start_time_type1, units = "mins"))))

# ============================================================================
# SCENARIO 2: POWER VALIDATION (RR = 1.5)
# ============================================================================

cat("===============================================================\n")
cat("SCENARIO 2: POWER VALIDATION\n")
cat("===============================================================\n")
cat("Testing detection power with MODERATE elevated risk (RR = 1.5)\n")
cat(sprintf("Running %d simulations...\n", n_sims))
cat("This may take 10-30 minutes depending on system performance...\n\n")

# Create subdirectory for power results
power_dir <- file.path(validation_dir, "power_RR1.5")
if (!dir.exists(power_dir)) {
  dir.create(power_dir, recursive = TRUE)
}

# Initialize parameters for power scenario
params_power <- initialize.data(
  seed = cfg$simulation$random_seed + 10000,  # Different seed for independence
  N = n_sims,
  t0 = t0,
  tf = tf,
  NStrata = n_strata,
  strataRatio = strata_ratio,
  EventRate = event_rate,
  sensitivity = sensitivity,
  PPVest = ppv_est,
  RR = 1.5,  # ALTERNATIVE HYPOTHESIS: 50% elevated risk
  MatchRatio = match_ratio,
  maxSampleSize = max_sample_size,
  maxTest = n_looks,
  totalAlpha = alpha,
  minEvents = min_events,
  AlphaSpendType = alpha_spend_type,
  AlphaParameter = alpha_parameter,
  address = power_dir,
  rate = exposure_rate,
  offset = exposure_offset
)

cat("Creating exposure matrices...\n")
exposure_power <- create.exposure(params_power)

cat("Simulating exposure data...\n")
exposure_data_power <- sim.exposure(exposure_power, params_power)

cat("Running SCRI sequential analysis...\n")
start_time_power <- Sys.time()
results_power <- SCRI.seq(exposure_data_power, params_power)
end_time_power <- Sys.time()

cat(sprintf("\nPower validation complete!\n"))
cat(sprintf("Computation time: %.2f minutes\n\n",
            as.numeric(difftime(end_time_power, start_time_power, units = "mins"))))

# ============================================================================
# SCENARIO 3: POWER VALIDATION (RR = 2.0) - OPTIONAL
# ============================================================================

cat("===============================================================\n")
cat("SCENARIO 3: POWER VALIDATION (OPTIONAL)\n")
cat("===============================================================\n")
cat("Testing detection power with STRONG elevated risk (RR = 2.0)\n")
cat(sprintf("Running %d simulations...\n", n_sims))
cat("This may take 10-30 minutes depending on system performance...\n\n")

# Create subdirectory for high power results
power2_dir <- file.path(validation_dir, "power_RR2.0")
if (!dir.exists(power2_dir)) {
  dir.create(power2_dir, recursive = TRUE)
}

# Initialize parameters for high power scenario
params_power2 <- initialize.data(
  seed = cfg$simulation$random_seed + 20000,  # Different seed
  N = n_sims,
  t0 = t0,
  tf = tf,
  NStrata = n_strata,
  strataRatio = strata_ratio,
  EventRate = event_rate,
  sensitivity = sensitivity,
  PPVest = ppv_est,
  RR = 2.0,  # ALTERNATIVE HYPOTHESIS: Doubled risk
  MatchRatio = match_ratio,
  maxSampleSize = max_sample_size,
  maxTest = n_looks,
  totalAlpha = alpha,
  minEvents = min_events,
  AlphaSpendType = alpha_spend_type,
  AlphaParameter = alpha_parameter,
  address = power2_dir,
  rate = exposure_rate,
  offset = exposure_offset
)

cat("Creating exposure matrices...\n")
exposure_power2 <- create.exposure(params_power2)

cat("Simulating exposure data...\n")
exposure_data_power2 <- sim.exposure(exposure_power2, params_power2)

cat("Running SCRI sequential analysis...\n")
start_time_power2 <- Sys.time()
results_power2 <- SCRI.seq(exposure_data_power2, params_power2)
end_time_power2 <- Sys.time()

cat(sprintf("\nPower validation (RR=2.0) complete!\n"))
cat(sprintf("Computation time: %.2f minutes\n\n",
            as.numeric(difftime(end_time_power2, start_time_power2, units = "mins"))))

# ============================================================================
# PARSE RESULTS FROM SEQUENTIAL OUTPUT FILES
# ============================================================================

cat("===============================================================\n")
cat("PARSING VALIDATION RESULTS\n")
cat("===============================================================\n\n")

# Function to parse Sequential package output
parse_sequential_results <- function(output_dir, scenario_name) {
  cat(sprintf("Parsing results for: %s\n", scenario_name))

  # Look for the inputSetUp.csv file created by Sequential package
  setup_file <- list.files(output_dir, pattern = "inputSetUp.*\\.csv$", full.names = TRUE)

  if (length(setup_file) == 0) {
    cat(sprintf("  Warning: No Sequential output files found in %s\n", output_dir))
    return(NULL)
  }

  # The Sequential package stores results in TXT files
  # Look for analysis result files
  result_files <- list.files(output_dir, pattern = "\\.txt$", full.names = TRUE)

  cat(sprintf("  Found %d output files\n", length(result_files)))

  return(list(
    scenario = scenario_name,
    output_dir = output_dir,
    n_files = length(result_files)
  ))
}

# Parse each scenario
type1_results <- parse_sequential_results(type1_dir, "Type I Error (RR=1.0)")
power_results <- parse_sequential_results(power_dir, "Power (RR=1.5)")
power2_results <- parse_sequential_results(power2_dir, "Power (RR=2.0)")

# ============================================================================
# GENERATE VALIDATION REPORT
# ============================================================================

cat("\n===============================================================\n")
cat("GENERATING VALIDATION REPORT\n")
cat("===============================================================\n\n")

# Create comprehensive validation report
report_file <- file.path(validation_dir, "validation_report.txt")

sink(report_file)
cat("===============================================================\n")
cat("SEQUENTIAL SURVEILLANCE VALIDATION REPORT\n")
cat("===============================================================\n\n")

cat(sprintf("Report Generated: %s\n", Sys.Date()))
cat(sprintf("Analysis Method: SequentialDesign Package + Sequential Package\n"))
cat(sprintf("SCRI Design: Self-Controlled Risk Interval\n\n"))

cat("--- VALIDATION PARAMETERS ---\n")
cat(sprintf("Number of simulations per scenario: %d\n", n_sims))
cat(sprintf("Target alpha (Type I error): %.3f\n", alpha))
cat(sprintf("Number of sequential looks: %d\n", n_looks))
cat(sprintf("Minimum events per look: %d\n", min_events))
cat(sprintf("Alpha spending method: %s\n", alpha_spend_type))
cat(sprintf("Risk window: Days %d-%d (%d days)\n",
            risk_window_start, risk_window_end, risk_window_length))
cat(sprintf("Control window: Days %d-%d (%d days)\n",
            control_window_start, control_window_end, control_window_length))
cat(sprintf("Number of strata: %d\n", n_strata))
cat(sprintf("Sensitivity: %.2f\n", sensitivity))
cat(sprintf("Positive predictive value: %.2f\n\n", ppv_est))

cat("--- SCENARIO 1: TYPE I ERROR VALIDATION ---\n")
cat("Research Question: Does the system maintain correct false positive rate?\n")
cat(sprintf("True relative risk: RR = 1.0 (no elevated risk)\n"))
cat(sprintf("Expected Type I error rate: %.3f\n", alpha))
cat(sprintf("Number of simulations: %d\n", n_sims))
cat(sprintf("Output directory: %s\n", type1_dir))
cat(sprintf("Computation time: %.2f minutes\n\n",
            as.numeric(difftime(end_time_type1, start_time_type1, units = "mins"))))
cat("INTERPRETATION:\n")
cat("  If observed Type I error rate ≈ target alpha: System is well-calibrated\n")
cat("  If observed Type I error rate > target alpha: System is too liberal (inflated false positives)\n")
cat("  If observed Type I error rate < target alpha: System is too conservative\n\n")

cat("--- SCENARIO 2: POWER VALIDATION (RR=1.5) ---\n")
cat("Research Question: Can the system detect moderate elevated risk?\n")
cat(sprintf("True relative risk: RR = 1.5 (50%% elevated risk)\n"))
cat(sprintf("Expected power: 80-90%% (target: 90%%)\n"))
cat(sprintf("Number of simulations: %d\n", n_sims))
cat(sprintf("Output directory: %s\n", power_dir))
cat(sprintf("Computation time: %.2f minutes\n\n",
            as.numeric(difftime(end_time_power, start_time_power, units = "mins"))))
cat("INTERPRETATION:\n")
cat("  Power = Proportion of simulations detecting signal (rejecting H0)\n")
cat("  Good power: ≥ 80% detection rate\n")
cat("  Excellent power: ≥ 90% detection rate\n\n")

cat("--- SCENARIO 3: POWER VALIDATION (RR=2.0) ---\n")
cat("Research Question: Can the system detect strong elevated risk?\n")
cat(sprintf("True relative risk: RR = 2.0 (100%% elevated risk / doubled)\n"))
cat(sprintf("Expected power: > 95%%\n"))
cat(sprintf("Number of simulations: %d\n", n_sims))
cat(sprintf("Output directory: %s\n", power2_dir))
cat(sprintf("Computation time: %.2f minutes\n\n",
            as.numeric(difftime(end_time_power2, start_time_power2, units = "mins"))))
cat("INTERPRETATION:\n")
cat("  With RR=2.0, power should be very high (>95%)\n")
cat("  Low power here would indicate serious design problems\n\n")

cat("--- HOW TO ANALYZE RESULTS ---\n")
cat("1. Navigate to each scenario output directory\n")
cat("2. Review Sequential package output files (*.txt)\n")
cat("3. Calculate observed Type I error and power rates\n")
cat("4. Compare against target values\n")
cat("5. Consider adjusting:\n")
cat("   - Number of looks (fewer = higher power, less frequent monitoring)\n")
cat("   - Alpha level (higher = more power, more false positives)\n")
cat("   - Minimum events per look (higher = delayed detection, more power)\n")
cat("   - Sample size (larger = more power)\n\n")

cat("--- TOTAL COMPUTATION TIME ---\n")
total_time <- as.numeric(difftime(end_time_power2, start_time_type1, units = "mins"))
cat(sprintf("Total validation runtime: %.2f minutes (%.2f hours)\n", total_time, total_time/60))

cat("\n===============================================================\n")
cat("VALIDATION COMPLETE\n")
cat("===============================================================\n")
cat(sprintf("\nAll results saved to: %s\n", validation_dir))
cat("\nNext steps:\n")
cat("1. Review individual scenario results in subdirectories\n")
cat("2. Calculate empirical Type I error and power rates\n")
cat("3. Update CLAUDE.md with validation status\n")
cat("4. If results are satisfactory, system is ready for production use\n")
cat("\n===============================================================\n")

sink()

# Print report to console as well
cat(readLines(report_file), sep = "\n")

cat("\n\n=== VALIDATION SYSTEM COMPLETE ===\n")
cat(sprintf("Full report saved to: %s\n", report_file))
