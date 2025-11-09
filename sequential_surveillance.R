# Sequential Surveillance for Vaccine Safety
# Self-Controlled Risk Interval (SCRI) Design
# Method: Sequential binomial test using Sequential package

# ==============================================================================
# OVERVIEW
# ==============================================================================
#
# This script performs sequential vaccine safety surveillance using exact
# binomial methods from the Sequential package (Kulldorff & Silva, CDC).
#
# WORKFLOW (5 Main Steps):
#   1. Load SCRI data and configuration
#   2. Setup sequential analysis parameters (MaxSPRT with Wald alpha spending)
#   3. Define calendar-based look schedule (realistic surveillance timing)
#   4. Perform sequential analysis at each look (with early stopping if signal)
#   5. Generate outputs: plots, reports, and alert files
#
# STATISTICAL METHODS:
#   - MaxSPRT: Maximized Sequential Probability Ratio Test
#   - Exact binomial test (not approximations)
#   - Wald alpha spending function for Type I error control
#   - Sequential-adjusted confidence intervals
#   - Null hypothesis: Events distributed proportional to person-time
#
# CALENDAR-BASED SCHEDULING:
#   - Realistic approach: Each look occurs at fixed calendar intervals
#   - Only cases with complete follow-up windows by look date are analyzed
#   - Allows for insufficient data (skips looks if minimum cases not met)
#   - Example: If look_interval_days=14, looks occur every 2 weeks
#
# INPUTS:
#   - config.yaml: Sequential analysis parameters including:
#       * overall_alpha: Type I error rate (e.g., 0.05)
#       * number_of_looks: Total planned interim analyses (e.g., 8)
#       * look_interval_days: Days between looks (e.g., 14)
#       * minimum_cases_per_look: Min sample size for analysis (e.g., 20)
#       * stop_on_signal: Whether to halt monitoring upon signal detection
#   - scri_data_wide.csv: Case-level dataset from simulate_scri_dataset.R
#
# OUTPUTS (surveillance_outputs/ directory):
#   - sequential_monitoring_results.csv: Detailed results for all looks
#       Columns: look_number, analysis_date, cases_analyzed, events_risk,
#                events_control, RR, LLR, critical_value, signal_detected, etc.
#   - sequential_monitoring_plot.png: Test statistics and boundaries over time
#   - cases_timeline.png: Cumulative cases and events over time
#   - current_status_report.txt: Plain text summary of latest surveillance status
#   - dashboard_alerts.csv: Alert metrics and thresholds
#
# HELPER FUNCTIONS (Lines 14-240):
#   This script defines 5 helper functions at the top:
#     1. extract_ci_from_sequential(): Extract CIs from Sequential package output
#     2. plot_sequential_monitoring(): Create test statistic monitoring plot
#     3. plot_cases_timeline(): Visualize cumulative cases over time
#     4. generate_status_report(): Create plain text summary report
#     5. generate_dashboard_alerts(): Create alert thresholds for visualization
#   These are called in Step 5 (Generate Outputs) of the main workflow.
#
# CONFIGURATION:
#   - All parameters are sourced from config.yaml
#   - DO NOT hard-code values in this script
#   - To modify analysis: Edit config.yaml, not this file
#   - Example modifications:
#       * More conservative: sequential_analysis$overall_alpha: 0.01
#       * Fewer looks: sequential_analysis$number_of_looks: 4
#       * Weekly monitoring: sequential_analysis$look_interval_days: 7
#
# SIGNAL DETECTION:
#   A safety signal is detected when the test statistic exceeds the critical
#   boundary at any look. This indicates potential elevated risk requiring
#   immediate investigation. Sequential adjustment ensures proper Type I error
#   control across multiple looks.
#
# EXECUTION TIME: ~10-30 seconds depending on number of looks
#
# ==============================================================================

options(repos = c(CRAN = "https://cloud.r-project.org"))

# 1. Install pacman itself, if not already installed
if (!require("pacman")) install.packages("pacman")

# 2. Use p_load to check, install (if needed), and load all packages
pacman::p_load(config, ggplot2, Sequential)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Extract confidence intervals from Sequential package result
# Sequential package returns RR_CI_lower and RR_CI_upper in columns 13-14
extract_ci_from_sequential <- function(seq_result) {
  if (is.null(seq_result) || nrow(seq_result) == 0) {
    return(list(lower = NA, upper = NA))
  }

  result_row <- seq_result[nrow(seq_result), ]

  # Try named columns first (RR_CI_lower, RR_CI_upper)
  RR_CI_lower <- if ("RR_CI_lower" %in% colnames(result_row)) {
    as.numeric(result_row$RR_CI_lower)
  } else if (ncol(result_row) >= 13) {
    as.numeric(result_row[, 13])  # Fallback to column 13
  } else {
    NA
  }

  RR_CI_upper <- if ("RR_CI_upper" %in% colnames(result_row)) {
    as.numeric(result_row$RR_CI_upper)
  } else if (ncol(result_row) >= 14) {
    as.numeric(result_row[, 14])  # Fallback to column 14
  } else {
    NA
  }

  return(list(lower = RR_CI_lower, upper = RR_CI_upper))
}

# Create sequential monitoring plot (Z-statistics vs boundary)
create_monitoring_plot <- function(summary_table, z_critical_display, output_path, plot_config) {
  png(output_path,
      width = plot_config$width,
      height = plot_config$height,
      units = "in", res = plot_config$dpi)

  par(mfrow = c(2, 1), mar = c(4, 4.5, 3, 2))

  # Plot 1: Z-statistic vs critical value over time
  plot(summary_table$look_number, summary_table$z_statistic,
       type = "b", pch = 19, col = "blue", lwd = 2.5,
       xlab = "Sequential Look Number",
       ylab = "Z-Statistic",
       main = "Sequential Monitoring: Test Statistics vs. Boundary (Sequential Package)",
       ylim = c(-0.5, max(c(summary_table$z_statistic, z_critical_display), na.rm = TRUE) * 1.2),
       cex.main = 1.3, cex.lab = 1.1)

  abline(h = z_critical_display, col = "red", lwd = 2.5, lty = 2)
  abline(h = 0, col = "gray50", lwd = 1, lty = 3)

  # Add signal detection marker if applicable
  if (any(summary_table$signal_detected)) {
    signal_look <- which(summary_table$signal_detected)[1]
    points(signal_look, summary_table$z_statistic[signal_look],
           pch = 8, col = "red", cex = 3, lwd = 2)
    text(signal_look, summary_table$z_statistic[signal_look],
         "SIGNAL", pos = 3, col = "red", font = 2, cex = 1.2)
  }

  legend("topleft",
         legend = c("Test Statistic (Z)", "Critical Boundary", "No Effect", "Signal"),
         col = c("blue", "red", "gray50", "red"),
         lty = c(1, 2, 3, NA), pch = c(19, NA, NA, 8), lwd = c(2.5, 2.5, 1, 2),
         cex = 0.9)

  grid(col = "gray80")

  # Plot 2: Observed RR over time
  plot(summary_table$look_number, summary_table$observed_RR,
       type = "b", pch = 19, col = "darkgreen", lwd = 2.5,
       xlab = "Sequential Look Number",
       ylab = "Relative Risk (RR)",
       main = "Observed Relative Risk Over Time",
       ylim = c(0.5, max(summary_table$observed_RR, na.rm = TRUE) * 1.2),
       cex.main = 1.3, cex.lab = 1.1)

  abline(h = 1.0, col = "black", lty = 2, lwd = 2)
  abline(h = 1.5, col = "orange", lty = 3, lwd = 1.5)
  abline(h = 2.0, col = "red", lty = 3, lwd = 1.5)

  legend("topleft",
         legend = c("Observed RR", "No Effect (RR=1.0)", "RR=1.5", "RR=2.0"),
         col = c("darkgreen", "black", "orange", "red"),
         lty = c(1, 2, 3, 3), pch = c(19, NA, NA, NA), lwd = c(2.5, 2, 1.5, 1.5),
         cex = 0.9)

  grid(col = "gray80")

  dev.off()
}

# Create timeline plot (cumulative cases and events over time)
create_timeline_plot <- function(summary_table, output_path, plot_config) {
  png(output_path,
      width = plot_config$width,
      height = plot_config$height,
      units = "in", res = plot_config$dpi)

  par(mar = c(4, 4.5, 3, 2))

  plot(summary_table$look_date, summary_table$n_cases,
       type = "l", lwd = 3, col = "steelblue",
       xlab = "Date",
       ylab = "Cumulative Count",
       main = "Cumulative Cases and Events Over Time",
       ylim = c(0, max(summary_table$n_cases) * 1.1),
       cex.main = 1.3, cex.lab = 1.1)

  points(summary_table$look_date, summary_table$n_cases,
         pch = 19, col = "steelblue", cex = 1.5)

  lines(summary_table$look_date, summary_table$events_risk,
        lwd = 2.5, col = "red")
  points(summary_table$look_date, summary_table$events_risk,
         pch = 17, col = "red", cex = 1.5)

  lines(summary_table$look_date, summary_table$events_control,
        lwd = 2.5, col = "green4")
  points(summary_table$look_date, summary_table$events_control,
         pch = 15, col = "green4", cex = 1.5)

  legend("topleft",
         legend = c("Total Cases", "Events in Risk Window", "Events in Control Window"),
         col = c("steelblue", "red", "green4"),
         pch = c(19, 17, 15), lwd = c(3, 2.5, 2.5), cex = 1)

  grid(col = "gray80")

  dev.off()
}

# Generate status report text file
generate_status_report <- function(latest_look, summary_table, alpha_per_look,
                                   risk_window, control_window, output_path) {
  status_report <- list(
    surveillance_date = Sys.Date(),
    analysis_date = as.character(latest_look$look_date),
    total_looks_performed = nrow(summary_table),
    total_cases_analyzed = latest_look$n_cases,
    events_in_risk_window = latest_look$events_risk,
    events_in_control_window = latest_look$events_control,
    observed_relative_risk = latest_look$observed_RR,
    p_value = latest_look$p_value,
    signal_status = ifelse(latest_look$signal_detected,
                          "SAFETY SIGNAL DETECTED",
                          "NO SIGNAL - CONTINUE MONITORING"),
    recommendation = ifelse(latest_look$signal_detected,
                           "Immediate investigation recommended. Consider regulatory action.",
                           "Continue routine surveillance.")
  )

  sink(output_path)
  cat("=======================================================\n")
  cat("VACCINE SAFETY SURVEILLANCE\n")
  cat("CURRENT STATUS REPORT\n")
  cat("=======================================================\n\n")
  cat(sprintf("Report Generated: %s\n", status_report$surveillance_date))
  cat(sprintf("Latest Analysis Date: %s\n", status_report$analysis_date))
  cat(sprintf("Sequential Looks Performed: %d\n", status_report$total_looks_performed))
  cat("\n--- CUMULATIVE DATA ---\n")
  cat(sprintf("Total Cases Analyzed: %d\n", status_report$total_cases_analyzed))
  cat(sprintf("Events in Risk Window (Days %d-%d): %d (%.1f%%)\n",
              risk_window$start_day, risk_window$end_day,
              status_report$events_in_risk_window,
              100 * status_report$events_in_risk_window / status_report$total_cases_analyzed))
  cat(sprintf("Events in Control Window (Days %d-%d): %d (%.1f%%)\n",
              control_window$start_day, control_window$end_day,
              status_report$events_in_control_window,
              100 * status_report$events_in_control_window / status_report$total_cases_analyzed))
  cat("\n--- STATISTICAL ANALYSIS ---\n")
  cat(sprintf("Observed Relative Risk: %.2f\n", status_report$observed_relative_risk))
  cat(sprintf("95%% CI (Sequential-Adjusted): %.2f - %.2f\n",
              latest_look$RR_CI_lower, latest_look$RR_CI_upper))
  cat(sprintf("P-value: %.4f\n", status_report$p_value))
  cat(sprintf("Alpha threshold (Pocock): %.4f\n", alpha_per_look))
  cat("\n--- SIGNAL STATUS ---\n")
  cat(sprintf("STATUS: %s\n", status_report$signal_status))
  cat("\n--- RECOMMENDATION ---\n")
  cat(sprintf("%s\n", status_report$recommendation))
  cat("\n=======================================================\n")
  sink()
}

# Generate alert table for dashboard
generate_alert_table <- function(latest_look, alpha_per_look, output_path) {
  alert_table <- data.frame(
    Metric = c("Surveillance Status", "Cases Analyzed", "Risk Window Events",
               "Control Window Events", "Observed RR", "P-value", "Signal"),
    Value = c(
      "ACTIVE",
      as.character(latest_look$n_cases),
      sprintf("%d (%.1f%%)", latest_look$events_risk,
              100 * latest_look$events_risk / latest_look$n_cases),
      sprintf("%d (%.1f%%)", latest_look$events_control,
              100 * latest_look$events_control / latest_look$n_cases),
      sprintf("%.2f", latest_look$observed_RR),
      sprintf("%.4f", latest_look$p_value),
      ifelse(latest_look$signal_detected, "YES", "NO")
    ),
    Alert_Level = c(
      "Normal",
      "Normal",
      ifelse(latest_look$prop_risk > 0.6, "Warning", "Normal"),
      "Normal",
      ifelse(latest_look$observed_RR > 1.5, "Warning",
             ifelse(latest_look$observed_RR > 2.0, "Critical", "Normal")),
      ifelse(latest_look$p_value < alpha_per_look, "Alert", "Normal"),
      ifelse(latest_look$signal_detected, "CRITICAL", "Normal")
    ),
    stringsAsFactors = FALSE
  )

  write.csv(alert_table, output_path, row.names = FALSE)
}

# ============================================================================
# LOAD CONFIGURATION AND DATA
# ============================================================================

cfg <- config::get(file = "config.yaml")

output_dir <- cfg$output$directory
if (!dir.exists(output_dir)) dir.create(output_dir)

cat("=======================================================\n")
cat("SEQUENTIAL VACCINE SAFETY SURVEILLANCE\n")
cat("=======================================================\n\n")

cat("Loading SCRI data...\n")

cases_wide <- read.csv("scri_data_wide.csv", stringsAsFactors = FALSE)

# Convert date columns
date_cols_wide <- c("observation_start", "vaccination_date", "observation_end",
                    "risk_window_start", "risk_window_end",
                    "control_window_start", "control_window_end", "event_date")
for (col in date_cols_wide) cases_wide[[col]] <- as.Date(cases_wide[[col]])

cat(sprintf("Cases: %d, Range: %s to %s\n\n",
            nrow(cases_wide),
            min(cases_wide$vaccination_date),
            max(cases_wide$event_date, na.rm = TRUE)))

# ============================================================================
# SURVEILLANCE PARAMETERS
# ============================================================================

cat("Setting up surveillance parameters...\n")

alpha <- cfg$sequential_analysis$overall_alpha
n_looks <- cfg$sequential_analysis$number_of_looks

risk_window_length <- cfg$scri_design$risk_window$end_day -
                      cfg$scri_design$risk_window$start_day + 1
control_window_length <- cfg$scri_design$control_window$end_day -
                         cfg$scri_design$control_window$start_day + 1

# Null hypothesis proportion
p0 <- risk_window_length / (risk_window_length + control_window_length)

cat(sprintf("Alpha: %.3f, Looks: %d\n", alpha, n_looks))

analysis_name <- "SCRI_Surveillance"
RR_target <- cfg$simulation$true_relative_risk

# Clean up previous analysis
analysis_dir <- file.path(output_dir, "sequential_setup")
if (dir.exists(analysis_dir)) unlink(analysis_dir, recursive = TRUE)
dir.create(analysis_dir, showWarnings = FALSE)
# Sequential package requires absolute path
analysis_dir <- normalizePath(analysis_dir, winslash = "/")

# Initialize Sequential analysis
max_N <- nrow(cases_wide)
zp_ratio <- control_window_length / risk_window_length

# Save working directory (Sequential package changes it)
original_wd <- getwd()

AnalyzeSetUp.Binomial(
  name = analysis_name,
  N = max_N,
  alpha = alpha,
  zp = zp_ratio,
  M = cfg$sequential_analysis$minimum_cases_per_look,
  AlphaSpendType = "Wald",
  power = 0.9,
  RR = RR_target,
  Tailed = "upper",
  title = "SCRI Vaccine Safety Surveillance",
  address = analysis_dir
)

# Restore working directory
setwd(original_wd)

cat("Sequential analysis setup complete\n\n")

# Alpha per look for display (Sequential package uses exact Wald spending)
alpha_per_look <- alpha / n_looks
z_critical_display <- qnorm(1 - alpha_per_look)

# ============================================================================
# DEFINE SEQUENTIAL ANALYSIS SCHEDULE
# ============================================================================

cat("Defining look schedule...\n")

min_cases_per_look <- cfg$sequential_analysis$minimum_cases_per_look
look_interval <- cfg$sequential_analysis$look_interval_days

# Calendar-based schedule (realistic for real-time surveillance)
# Start date: earliest time when cases with complete windows could be available
season_start <- as.Date(cfg$simulation$season$start_date)
first_look_date <- season_start + control_window_length + look_interval

# Generate fixed calendar-based look schedule
look_schedule <- seq(
  from = first_look_date,
  by = look_interval,
  length.out = n_looks
)

cat(sprintf("Looks: %d planned, Schedule: %s to %s\n",
            n_looks, min(look_schedule), max(look_schedule)))
cat(sprintf("Look interval: %d days, Minimum cases per look: %d\n\n",
            look_interval, min_cases_per_look))

# ============================================================================
# PERFORM SEQUENTIAL ANALYSIS
# ============================================================================

cat("Performing sequential analysis...\n\n")

surveillance_results <- data.frame(
  look_number = integer(),
  look_date = character(),
  n_cases = integer(),
  events_risk = integer(),
  events_control = integer(),
  prop_risk = numeric(),
  observed_RR = numeric(),
  RR_CI_lower = numeric(),
  RR_CI_upper = numeric(),
  z_statistic = numeric(),
  z_critical = numeric(),
  p_value = numeric(),
  signal_detected = logical(),
  stringsAsFactors = FALSE
)

# Track sequential test number (increments only when analysis is performed)
sequential_test_number <- 0

for (look in 1:n_looks) {
  look_date <- look_schedule[look]

  # Get cases available at this look (realistic: only cases with complete windows by this date)
  available_cases <- cases_wide[cases_wide$control_window_end <= look_date, ]
  n_cases <- nrow(available_cases)

  # Check if sufficient cases are available
  if (n_cases < min_cases_per_look) {
    cat(sprintf("Look %d (%s): n=%d - INSUFFICIENT CASES (minimum: %d), skipping analysis\n",
                look, look_date, n_cases, min_cases_per_look))
    next
  }

  # Increment sequential test number
  sequential_test_number <- sequential_test_number + 1

  events_risk <- sum(available_cases$event_in_risk_window)
  events_control <- n_cases - events_risk
  prop_risk <- events_risk / n_cases

  # Calculate observed RR with continuity correction
  events_risk_adj <- events_risk + 0.5
  events_control_adj <- events_control + 0.5
  observed_RR <- (events_risk_adj / risk_window_length) / (events_control_adj / control_window_length)

  # Perform exact sequential binomial test
  seq_result <- suppressMessages(Analyze.Binomial(
    name = analysis_name,
    test = sequential_test_number,
    z = zp_ratio,
    cases = events_risk,
    controls = events_control
  ))

  # Restore working directory (Sequential package changes it)
  setwd(original_wd)

  # Extract results
  signal_detected <- if(!is.null(seq_result) && nrow(seq_result) > 0) {
    seq_result[nrow(seq_result), "Reject H0"] == "Yes"
  } else {
    FALSE
  }

  z_critical <- if(!is.null(seq_result) && nrow(seq_result) > 0) {
    seq_result[nrow(seq_result), "CV"]
  } else {
    NA
  }

  # Extract sequential-adjusted CIs
  ci_result <- extract_ci_from_sequential(seq_result)
  RR_CI_lower <- ci_result$lower
  RR_CI_upper <- ci_result$upper

  # Calculate test statistic and p-value
  se_prop <- sqrt(p0 * (1 - p0) / n_cases)
  z_stat <- (prop_risk - p0) / se_prop
  p_val <- 1 - pnorm(z_stat)

  surveillance_results <- rbind(surveillance_results, data.frame(
    look_number = look,
    look_date = as.character(look_date),
    n_cases = n_cases,
    events_risk = events_risk,
    events_control = events_control,
    prop_risk = prop_risk,
    observed_RR = observed_RR,
    RR_CI_lower = RR_CI_lower,
    RR_CI_upper = RR_CI_upper,
    z_statistic = z_stat,
    z_critical = z_critical,
    p_value = p_val,
    signal_detected = signal_detected
  ))

  cat(sprintf("Look %d (%s): n=%d, RR=%.2f (%.2f-%.2f), Z=%.2f, ",
              look, look_date, n_cases,
              ifelse(is.na(observed_RR), 0, observed_RR),
              ifelse(is.na(RR_CI_lower), 0, RR_CI_lower),
              ifelse(is.na(RR_CI_upper), 0, RR_CI_upper),
              z_stat))

  if (signal_detected) {
    cat("*** SIGNAL ***\n")
  } else {
    cat("No signal (p=%.4f)\n", p_val)
  }

  if (signal_detected && cfg$sequential_analysis$stop_on_signal) {
    cat("\n*** Signal detected! Surveillance stopped. ***\n\n")
    break
  }
}

# ============================================================================
# GENERATE OUTPUTS
# ============================================================================

cat("Generating outputs...\n")

# Summary table
summary_table <- surveillance_results
summary_table$look_date <- as.Date(summary_table$look_date)
summary_table$status <- ifelse(summary_table$signal_detected, "SIGNAL", "Continue")

summary_display <- summary_table
summary_display$p_value <- sprintf("%.4f", summary_display$p_value)
summary_display$observed_RR <- sprintf("%.2f", summary_display$observed_RR)
summary_display$z_statistic <- sprintf("%.3f", summary_display$z_statistic)
summary_display$prop_risk <- sprintf("%.3f", summary_display$prop_risk)

write.csv(summary_display, file.path(output_dir, "sequential_monitoring_results.csv"), row.names = FALSE)

# Generate status report
latest_look <- summary_table[nrow(summary_table), ]
generate_status_report(
  latest_look = latest_look,
  summary_table = summary_table,
  alpha_per_look = alpha_per_look,
  risk_window = cfg$scri_design$risk_window,
  control_window = cfg$scri_design$control_window,
  output_path = file.path(output_dir, "current_status_report.txt")
)
cat("  - Current status report saved\n")

# Generate sequential monitoring plot
plot_config <- list(
  width = cfg$output$plots$monitoring_plot$width,
  height = cfg$output$plots$monitoring_plot$height,
  dpi = cfg$output$plots$dpi
)
create_monitoring_plot(
  summary_table = summary_table,
  z_critical_display = z_critical_display,
  output_path = file.path(output_dir, "sequential_monitoring_plot.png"),
  plot_config = plot_config
)
cat("  - Sequential monitoring plot saved\n")

# Generate timeline plot
plot_config_timeline <- list(
  width = cfg$output$plots$timeline_plot$width,
  height = cfg$output$plots$timeline_plot$height,
  dpi = cfg$output$plots$dpi
)
create_timeline_plot(
  summary_table = summary_table,
  output_path = file.path(output_dir, "cases_timeline.png"),
  plot_config = plot_config_timeline
)
cat("  - Cases timeline plot saved\n")

# Generate alert table for dashboard
generate_alert_table(
  latest_look = latest_look,
  alpha_per_look = alpha_per_look,
  output_path = file.path(output_dir, "dashboard_alerts.csv")
)

# ============================================================================
# SUMMARY
# ============================================================================

cat("\n=======================================================\n")
cat("ANALYSIS COMPLETE\n")
cat("=======================================================\n\n")

cat(sprintf("Looks: %d, Cases: %d\n", nrow(summary_table), latest_look$n_cases))
cat(sprintf("Events - Risk: %d (%.1f%%), Control: %d (%.1f%%)\n",
            latest_look$events_risk,
            100 * latest_look$events_risk / latest_look$n_cases,
            latest_look$events_control,
            100 * latest_look$events_control / latest_look$n_cases))
cat(sprintf("RR: %.2f, P: %.4f (α: %.4f)\n\n", latest_look$observed_RR, latest_look$p_value, alpha_per_look))

if (latest_look$signal_detected) {
  cat("*** SIGNAL DETECTED ***\n")
  cat("Recommendation: Immediate investigation\n")
} else {
  cat("No signal detected\n")
  cat("Recommendation: Continue surveillance\n")
}

cat("\nOutputs saved to:", output_dir, "\n")
cat("=======================================================\n")
