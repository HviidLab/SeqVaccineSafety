# Sequential Surveillance for Vaccine Safety
# Self-Controlled Risk Interval (SCRI) Design
# Method: Sequential binomial test using Sequential package

options(repos = c(CRAN = "https://cloud.r-project.org"))

required_packages <- c("config", "ggplot2", "Sequential")
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}

# ============================================================================
# LOAD CONFIGURATION AND DATA
# ============================================================================

cfg <- config::get(file = "config.yaml")

output_dir <- file.path(getwd(), cfg$output$directory)
if (!dir.exists(output_dir)) dir.create(output_dir)

cat("=======================================================\n")
cat("SEQUENTIAL VACCINE SAFETY SURVEILLANCE\n")
cat("=======================================================\n\n")

cat("Loading SCRI data...\n")

cases_wide <- read.csv("scri_data_wide.csv", stringsAsFactors = FALSE)
cases_long <- read.csv("scri_data_long.csv", stringsAsFactors = FALSE)

# Convert date columns
date_cols_wide <- c("observation_start", "vaccination_date", "observation_end",
                    "risk_window_start", "risk_window_end",
                    "control_window_start", "control_window_end", "event_date")
for (col in date_cols_wide) cases_wide[[col]] <- as.Date(cases_wide[[col]])

date_cols_long <- c("vaccination_date", "event_date", "window_start",
                    "window_end", "calendar_date")
for (col in date_cols_long) cases_long[[col]] <- as.Date(cases_long[[col]])

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

# Initialize Sequential analysis
max_N <- nrow(cases_wide)
zp_ratio <- control_window_length / risk_window_length

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

cat("Sequential analysis setup complete\n\n")

# Alpha per look for display (Sequential package uses exact Wald spending)
alpha_per_look <- alpha / n_looks
z_critical_display <- qnorm(1 - alpha_per_look)

# ============================================================================
# DEFINE SEQUENTIAL ANALYSIS SCHEDULE
# ============================================================================

cat("Defining look schedule...\n")

look_dates <- sort(unique(cases_wide$control_window_end))
min_cases_per_look <- cfg$sequential_analysis$minimum_cases_per_look
look_interval <- cfg$sequential_analysis$look_interval_days
look_schedule <- c()
current_date <- min(look_dates)
max_date <- max(look_dates)

while (current_date <= max_date) {
  available_cases <- cases_wide[cases_wide$control_window_end <= current_date, ]
  if (nrow(available_cases) >= min_cases_per_look) {
    look_schedule <- c(look_schedule, as.character(current_date))
  }
  current_date <- current_date + look_interval
}

look_schedule <- unique(look_schedule)
actual_looks <- min(length(look_schedule), n_looks)
look_schedule <- as.Date(look_schedule[1:actual_looks])

cat(sprintf("Looks: %d, Schedule: %s to %s\n\n",
            actual_looks, min(look_schedule), max(look_schedule)))

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
for (look in 1:actual_looks) {
  look_date <- look_schedule[look]

  # Get cases available at this look
  available_cases <- cases_wide[cases_wide$control_window_end <= look_date, ]
  n_cases <- nrow(available_cases)

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
    test = look,
    z = zp_ratio,
    cases = events_risk,
    controls = events_control
  ))

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
  RR_CI_lower <- NA
  RR_CI_upper <- NA

  if (!is.null(seq_result) && nrow(seq_result) > 0) {
    result_row <- seq_result[nrow(seq_result), ]
    col_names <- colnames(result_row)

    # Try column names first
    lower_col_names <- c("RR_CI_lower", "Lower limit", "lower.limit", "CI_lower",
                         "LowerLimit", "Lower_limit", "lower_CI", "RR.lower")
    upper_col_names <- c("RR_CI_upper", "Upper limit", "upper.limit", "CI_upper",
                         "UpperLimit", "Upper_limit", "upper_CI", "RR.upper")

    lower_col <- which(col_names %in% lower_col_names)
    upper_col <- which(col_names %in% upper_col_names)

    # Fallback to grep
    if (length(lower_col) == 0) lower_col <- grep("lower|Lower", col_names, ignore.case = TRUE)
    if (length(upper_col) == 0) upper_col <- grep("upper|Upper", col_names, ignore.case = TRUE)

    # Extract values
    if (length(lower_col) > 0) {
      RR_CI_lower <- as.numeric(result_row[, lower_col[1]])
    } else if (ncol(result_row) >= 13) {
      RR_CI_lower <- as.numeric(result_row[, 13])
    }

    if (length(upper_col) > 0) {
      RR_CI_upper <- as.numeric(result_row[, upper_col[1]])
    } else if (ncol(result_row) >= 14) {
      RR_CI_upper <- as.numeric(result_row[, 14])
    }
  }

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

# Status report
latest_look <- summary_table[nrow(summary_table), ]

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

# Save status report
sink(file.path(output_dir, "current_status_report.txt"))
cat("=======================================================\n")
cat("INFLUENZA VACCINE SAFETY SURVEILLANCE\n")
cat("CURRENT STATUS REPORT\n")
cat("=======================================================\n\n")
cat(sprintf("Report Generated: %s\n", status_report$surveillance_date))
cat(sprintf("Latest Analysis Date: %s\n", status_report$analysis_date))
cat(sprintf("Sequential Looks Performed: %d\n", status_report$total_looks_performed))
cat("\n--- CUMULATIVE DATA ---\n")
cat(sprintf("Total Cases Analyzed: %d\n", status_report$total_cases_analyzed))
cat(sprintf("Events in Risk Window (Days 1-28): %d (%.1f%%)\n",
            status_report$events_in_risk_window,
            100 * status_report$events_in_risk_window / status_report$total_cases_analyzed))
cat(sprintf("Events in Control Window (Days 29-56): %d (%.1f%%)\n",
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

cat("  - Current status report saved\n")

# --- 5.3 Visualization: Sequential Monitoring Plot ---
png(file.path(output_dir, "sequential_monitoring_plot.png"),
    width = cfg$output$plots$monitoring_plot$width,
    height = cfg$output$plots$monitoring_plot$height,
    units = "in", res = cfg$output$plots$dpi)

par(mfrow = c(2, 1), mar = c(4, 4.5, 3, 2))

# Plot 1: Z-statistic vs critical value over time
plot(summary_table$look_number, summary_table$z_statistic,
     type = "b", pch = 19, col = "blue", lwd = 2.5,
     xlab = "Sequential Look Number",
     ylab = "Z-Statistic",
     main = "Sequential Monitoring: Test Statistics vs. Boundary (Sequential Package)",
     ylim = c(-0.5, max(c(summary_table$z_statistic, z_critical_display), na.rm = TRUE) * 1.2),
     cex.main = 1.3, cex.lab = 1.1)

# Add approximate critical value line for reference
# Note: Sequential package uses exact Wald spending; this is Pocock approximation for visualization
abline(h = z_critical_display, col = "red", lwd = 2.5, lty = 2)

# Add null hypothesis line
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

cat("  - Sequential monitoring plot saved\n")

# --- 5.4 Visualization: Cases and Events Over Time ---
png(file.path(output_dir, "cases_timeline.png"),
    width = cfg$output$plots$timeline_plot$width,
    height = cfg$output$plots$timeline_plot$height,
    units = "in", res = cfg$output$plots$dpi)

par(mar = c(4, 4.5, 3, 2))

# Create stacked area for cumulative events
plot(summary_table$look_date, summary_table$n_cases,
     type = "l", lwd = 3, col = "steelblue",
     xlab = "Date",
     ylab = "Cumulative Count",
     main = "Cumulative Cases and Events Over Time",
     ylim = c(0, max(summary_table$n_cases) * 1.1),
     cex.main = 1.3, cex.lab = 1.1)

# Add points for cases
points(summary_table$look_date, summary_table$n_cases,
       pch = 19, col = "steelblue", cex = 1.5)

# Add lines for events
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

cat("  - Cases timeline plot saved\n")

# --- 5.5 Alert Table for Dashboard ---
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

write.csv(alert_table, file.path(output_dir, "dashboard_alerts.csv"),
          row.names = FALSE)

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
