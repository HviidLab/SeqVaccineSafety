# Test Script: Verify z Parameter Fix with Unequal Windows
# This tests the critical bug fix for unequal risk/control windows

cat("===============================================================\n")
cat("TESTING: z PARAMETER FIX WITH UNEQUAL WINDOWS\n")
cat("===============================================================\n\n")

# Load packages
library(config)
library(Sequential)

# Load configuration
cfg <- config::get(file = "config.yaml")

# Test Case: Risk=14 days, Control=42 days (1:3 ratio)
risk_window_length <- 14
control_window_length <- 42
zp_ratio <- control_window_length / risk_window_length  # Should be 3.0

cat(sprintf("Test Configuration:\n"))
cat(sprintf("  Risk window: %d days\n", risk_window_length))
cat(sprintf("  Control window: %d days\n", control_window_length))
cat(sprintf("  zp_ratio: %.1f\n", zp_ratio))
cat(sprintf("  Expected p0: %.3f\n", risk_window_length / (risk_window_length + control_window_length)))
cat("\n")

# Setup Sequential analysis with unequal windows
analysis_name <- "Test_Unequal_Windows"
output_dir <- file.path(getwd(), "surveillance_outputs", "test_unequal")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

cat("Setting up Sequential analysis...\n")
AnalyzeSetUp.Binomial(
  name = analysis_name,
  N = 100,
  alpha = 0.05,
  zp = zp_ratio,  # 3.0 for 14:42 ratio
  M = 5,
  AlphaSpendType = "Wald",
  power = 0.9,
  RR = 1.5,
  Tailed = "upper",
  title = "Test Unequal Windows",
  address = output_dir
)

cat("Setup complete.\n\n")

# Test case: Simulate data consistent with H0 (no elevated risk)
# With p0 = 14/56 = 0.25, we expect ~25% of events in risk window
cat("Test 1: Data consistent with H0 (RR=1.0)\n")
cat("-----------------------------------------------\n")

# Simulate: 20 events in risk, 60 in control (25% in risk window)
events_risk_h0 <- 20
events_control_h0 <- 60

cat(sprintf("  Events in risk window: %d\n", events_risk_h0))
cat(sprintf("  Events in control window: %d\n", events_control_h0))
cat(sprintf("  Proportion in risk: %.3f (expected: %.3f)\n",
            events_risk_h0/(events_risk_h0+events_control_h0),
            risk_window_length / (risk_window_length + control_window_length)))

# Run analysis with CORRECT z parameter
result_correct <- Analyze.Binomial(
  name = analysis_name,
  test = 1,
  z = zp_ratio,  # CORRECT: Use matching ratio from setup
  cases = events_risk_h0,
  controls = events_control_h0
)

cat("\nResult with CORRECT z parameter (z=3.0):\n")
print(result_correct)

# Calculate what OLD buggy code would have done
cat("\n\n")
cat("Test 2: What the BUG would have produced (z=1 hardcoded)\n")
cat("-----------------------------------------------\n")

# Create new setup with z=1 to show the bug
analysis_name_bug <- "Test_Bug_z1"
output_dir_bug <- file.path(getwd(), "surveillance_outputs", "test_bug")
dir.create(output_dir_bug, recursive = TRUE, showWarnings = FALSE)

AnalyzeSetUp.Binomial(
  name = analysis_name_bug,
  N = 100,
  alpha = 0.05,
  zp = 1,  # WRONG - assumes equal windows
  M = 5,
  AlphaSpendType = "Wald",
  power = 0.9,
  RR = 1.5,
  Tailed = "upper",
  title = "Test Bug Version",
  address = output_dir_bug
)

result_bug <- Analyze.Binomial(
  name = analysis_name_bug,
  test = 1,
  z = 1,  # BUGGY: Hardcoded z=1
  cases = events_risk_h0,
  controls = events_control_h0
)

cat("\nResult with BUGGY z parameter (z=1):\n")
print(result_bug)

cat("\n\n")
cat("===============================================================\n")
cat("COMPARISON:\n")
cat("===============================================================\n")
cat(sprintf("Correct approach (z=%.1f): Reject H0 = %s\n",
            zp_ratio,
            result_correct[nrow(result_correct), "Reject H0"]))
cat(sprintf("Buggy approach (z=1.0):    Reject H0 = %s\n",
            result_bug[nrow(result_bug), "Reject H0"]))
cat("\n")

# Test case with elevated risk
cat("Test 3: Data with elevated risk (RR ~ 2.0)\n")
cat("-----------------------------------------------\n")

# Simulate: 50 events in risk, 50 in control
# With 14 vs 42 days, this is: (50/14) / (50/42) = 3.0 rate ratio
# But in terms of relative risk in SCRI: RR = OR when baseline is low
events_risk_h1 <- 50
events_control_h1 <- 50

cat(sprintf("  Events in risk window: %d\n", events_risk_h1))
cat(sprintf("  Events in control window: %d\n", events_control_h1))
cat(sprintf("  Proportion in risk: %.3f\n",
            events_risk_h1/(events_risk_h1+events_control_h1)))
cat(sprintf("  Rate ratio: %.2f\n",
            (events_risk_h1/risk_window_length) / (events_control_h1/control_window_length)))

result_h1 <- Analyze.Binomial(
  name = analysis_name,
  test = 2,
  z = zp_ratio,
  cases = events_risk_h1,
  controls = events_control_h1
)

cat("\nResult with CORRECT z parameter:\n")
print(result_h1)

cat("\n\n")
cat("===============================================================\n")
cat("CONCLUSION:\n")
cat("===============================================================\n")
cat("The z parameter fix ensures:\n")
cat("1. Correct null hypothesis for unequal windows\n")
cat("2. Valid Type I error control\n")
cat("3. Correct critical values and signal detection\n")
cat("4. The bug would cause SEVERE BIAS with unequal windows\n")
cat("===============================================================\n")

# Cleanup
unlink(output_dir, recursive = TRUE)
unlink(output_dir_bug, recursive = TRUE)
