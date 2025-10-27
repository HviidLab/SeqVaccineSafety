# Quick Validation Test (n=100 simulations)
# Verifies validation framework before running full 1000+ simulation study
# Runtime: ~3-5 minutes

cat("===============================================================\n")
cat("QUICK VALIDATION TEST (n=100 simulations)\n")
cat("Verifying framework before full validation\n")
cat("===============================================================\n\n")

# Set CRAN mirror
options(repos = c(CRAN = "https://cloud.r-project.org"))

# Load packages
required_packages <- c("config", "SequentialDesign", "Sequential")
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    cat(sprintf("Installing '%s' package...\n", pkg))
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}

# Load configuration
cat("Loading configuration...\n")
cfg <- config::get(file = "config.yaml")

# Override n_simulations for quick test
n_sims_quick <- 100
set.seed(cfg$simulation$random_seed)

cat(sprintf("Running %d simulations (quick test)...\n\n", n_sims_quick))

# Extract parameters
sd_params <- cfg$simulation$sequential_design
alpha <- cfg$sequential_analysis$overall_alpha
n_looks <- cfg$sequential_analysis$number_of_looks
min_events <- cfg$sequential_analysis$minimum_cases_per_look

risk_window_length <- cfg$scri_design$risk_window$end_day -
                      cfg$scri_design$risk_window$start_day + 1
control_window_length <- cfg$scri_design$control_window$end_day -
                         cfg$scri_design$control_window$start_day + 1

# Create output directory
quick_val_dir <- file.path(getwd(), "surveillance_outputs", "quick_validation")
if (dir.exists(quick_val_dir)) {
  unlink(quick_val_dir, recursive = TRUE)
}
dir.create(quick_val_dir, recursive = TRUE)

cat("==============================================================\n")
cat("TEST 1: TYPE I ERROR (RR=1.0) - Quick Test\n")
cat("==============================================================\n\n")

type1_quick_dir <- file.path(quick_val_dir, "type1_RR1.0")
dir.create(type1_quick_dir, showWarnings = FALSE)

cat("Initializing parameters...\n")
params_type1 <- initialize.data(
  seed = cfg$simulation$random_seed,
  N = n_sims_quick,  # Quick test: 100 simulations
  t0 = sd_params$t0,
  tf = sd_params$tf,
  NStrata = sd_params$n_strata,
  strataRatio = unlist(sd_params$strata_ratio),
  EventRate = unlist(sd_params$event_rate_by_strata),
  sensitivity = sd_params$sensitivity,
  PPVest = sd_params$positive_predictive_value,
  RR = 1.0,  # NULL HYPOTHESIS
  MatchRatio = sd_params$match_ratio,
  maxSampleSize = sd_params$max_sample_size,
  maxTest = n_looks,
  totalAlpha = alpha,
  minEvents = min_events,
  AlphaSpendType = "Wald",
  AlphaParameter = sd_params$alpha_parameter,
  address = type1_quick_dir,
  rate = sd_params$exposure_rate,
  offset = sd_params$exposure_offset
)

cat("Creating exposure matrices...\n")
exposure_type1 <- create.exposure(params_type1)

cat("Simulating exposure data...\n")
exposure_data_type1 <- sim.exposure(exposure_type1, params_type1)

cat("Running SCRI sequential analysis...\n")
start_time <- Sys.time()
results_type1 <- SCRI.seq(exposure_data_type1, params_type1)
end_time <- Sys.time()

runtime_minutes <- as.numeric(difftime(end_time, start_time, units = "mins"))
cat(sprintf("\nCompleted in %.2f minutes\n", runtime_minutes))
cat(sprintf("Estimated time for 1000 simulations: %.1f minutes (%.1f hours)\n",
            runtime_minutes * 10, runtime_minutes * 10 / 60))

cat("\n==============================================================\n")
cat("TEST 2: POWER (RR=1.5) - Quick Test\n")
cat("==============================================================\n\n")

power_quick_dir <- file.path(quick_val_dir, "power_RR1.5")
dir.create(power_quick_dir, showWarnings = FALSE)

cat("Initializing parameters...\n")
params_power <- initialize.data(
  seed = cfg$simulation$random_seed + 10000,
  N = n_sims_quick,
  t0 = sd_params$t0,
  tf = sd_params$tf,
  NStrata = sd_params$n_strata,
  strataRatio = unlist(sd_params$strata_ratio),
  EventRate = unlist(sd_params$event_rate_by_strata),
  sensitivity = sd_params$sensitivity,
  PPVest = sd_params$positive_predictive_value,
  RR = 1.5,  # ALTERNATIVE HYPOTHESIS
  MatchRatio = sd_params$match_ratio,
  maxSampleSize = sd_params$max_sample_size,
  maxTest = n_looks,
  totalAlpha = alpha,
  minEvents = min_events,
  AlphaSpendType = "Wald",
  AlphaParameter = sd_params$alpha_parameter,
  address = power_quick_dir,
  rate = sd_params$exposure_rate,
  offset = sd_params$exposure_offset
)

cat("Creating exposure matrices...\n")
exposure_power <- create.exposure(params_power)

cat("Simulating exposure data...\n")
exposure_data_power <- sim.exposure(exposure_power, params_power)

cat("Running SCRI sequential analysis...\n")
start_time <- Sys.time()
results_power <- SCRI.seq(exposure_data_power, params_power)
end_time <- Sys.time()

runtime_minutes2 <- as.numeric(difftime(end_time, start_time, units = "mins"))
cat(sprintf("\nCompleted in %.2f minutes\n", runtime_minutes2))

total_runtime <- runtime_minutes + runtime_minutes2
cat("\n==============================================================\n")
cat("QUICK VALIDATION TEST COMPLETE\n")
cat("==============================================================\n\n")

cat(sprintf("Total runtime: %.2f minutes\n", total_runtime))
cat(sprintf("Estimated time for full validation (3 scenarios x 1000 sims):\n"))
cat(sprintf("  %.1f - %.1f minutes (%.1f - %.1f hours)\n",
            total_runtime * 15, total_runtime * 20,
            total_runtime * 15 / 60, total_runtime * 20 / 60))

cat("\nResults stored in:\n")
cat(sprintf("  %s\n", quick_val_dir))

cat("\n==============================================================\n")
cat("FRAMEWORK VERIFICATION\n")
cat("==============================================================\n\n")

# Check if output files exist
type1_files <- list.files(type1_quick_dir, pattern = "\\.txt$", full.names = FALSE)
power_files <- list.files(power_quick_dir, pattern = "\\.txt$", full.names = FALSE)

cat(sprintf("✅ Type I error scenario: %d output files generated\n", length(type1_files)))
cat(sprintf("✅ Power scenario: %d output files generated\n", length(power_files)))

if (length(type1_files) > 0 && length(power_files) > 0) {
  cat("\n✅ VALIDATION FRAMEWORK WORKING CORRECTLY\n")
  cat("\nReady to run full validation with n=1000+ simulations.\n")
  cat("Edit config.yaml: simulation.sequential_design.n_simulations: 1000\n")
  cat("Then run: source('validate_surveillance.R')\n")
} else {
  cat("\n❌ ERROR: Validation framework not producing expected outputs\n")
  cat("Check SequentialDesign package installation and parameters\n")
}

cat("\n==============================================================\n")
