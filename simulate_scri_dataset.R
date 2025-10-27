# Simulate SCRI Dataset for Influenza Vaccine Safety Surveillance
# Self-Controlled Risk Interval (SCRI) design for sequential monitoring
# Target population: Adults aged 65+ years
# Single flu season, single dose per person

# Set CRAN mirror
options(repos = c(CRAN = "https://cloud.r-project.org"))

# Load required packages
if (!require("config", quietly = TRUE)) {
  cat("Installing config package...\n")
  install.packages("config")
  library(config)
}

# Load SequentialDesign package if needed
if (!require("SequentialDesign", quietly = TRUE)) {
  cat("Installing SequentialDesign package...\n")
  install.packages("SequentialDesign")
}
library(SequentialDesign)

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

# Check simulation method
simulation_method <- cfg$simulation$method
if (is.null(simulation_method)) {
  simulation_method <- "custom"  # Default to custom method
}

cat(sprintf("\nSimulation method: %s\n", simulation_method))

# Branch based on simulation method
if (simulation_method == "sequential_design") {
  cat("\n=== USING SequentialDesign PACKAGE ===\n\n")
  source("simulate_scri_sequential_design.R")
  quit(save = "no")
}

# Otherwise continue with custom simulation
cat("\n=== USING CUSTOM SIMULATION METHOD ===\n\n")

# ============================================================================
# SIMULATION PARAMETERS (from config)
# ============================================================================

# Population parameters
n_patients <- cfg$simulation$population_size

# Flu season timeframe
season_start <- as.Date(cfg$simulation$season$start_date)
season_end <- as.Date(cfg$simulation$season$end_date)
season_length <- as.numeric(season_end - season_start)

# SCRI time windows (in days)
risk_window_start <- cfg$scri_design$risk_window$start_day
risk_window_end <- cfg$scri_design$risk_window$end_day
control_window_start <- cfg$scri_design$control_window$start_day
control_window_end <- cfg$scri_design$control_window$end_day

risk_window_length <- risk_window_end - risk_window_start + 1
control_window_length <- control_window_end - control_window_start + 1

# Event rate parameters (per person-day)
baseline_event_rate <- cfg$simulation$baseline_event_rate
relative_risk <- cfg$simulation$true_relative_risk

# Sequential monitoring parameters
alpha <- cfg$sequential_analysis$overall_alpha
n_looks <- cfg$sequential_analysis$number_of_looks
look_interval <- cfg$sequential_analysis$look_interval_days

# ============================================================================
# GENERATE PATIENT POPULATION
# ============================================================================

cat("Generating patient population...\n")

# Create patient IDs
patient_data <- data.frame(
  patient_id = sprintf("P%05d", 1:n_patients)
)

# Generate age distribution (65+ years)
# Using distribution from config
age_groups <- sample(
  c("65-74", "75-84", "85+"),
  size = n_patients,
  replace = TRUE,
  prob = c(
    cfg$simulation$age_distribution$age_65_74,
    cfg$simulation$age_distribution$age_75_84,
    cfg$simulation$age_distribution$age_85_plus
  )
)

patient_data$age_group <- age_groups
patient_data$age <- sapply(age_groups, function(ag) {
  if (ag == "65-74") runif(1, 65, 75)
  else if (ag == "75-84") runif(1, 75, 85)
  else runif(1, 85, 95)
})
patient_data$age <- round(patient_data$age)

# Observation start (season enrollment)
patient_data$observation_start <- season_start

# ============================================================================
# SIMULATE VACCINATION DATES
# ============================================================================

cat("Simulating vaccination dates...\n")

# Realistic vaccination distribution: peaks early, tapers off
# Most vaccines given in October-November
days_into_season <- sample(
  0:season_length,
  size = n_patients,
  replace = TRUE,
  prob = dexp(0:season_length, rate = 0.02)  # Exponential decay
)

patient_data$vaccination_date <- season_start + days_into_season

# Ensure vaccination is within season
patient_data$vaccination_date <- pmin(patient_data$vaccination_date, season_end)

# Calculate observation end (whichever comes first: season end or control window end)
patient_data$observation_end <- pmin(
  patient_data$vaccination_date + control_window_end,
  season_end
)

# ============================================================================
# CALCULATE TIME WINDOWS FOR EACH PATIENT
# ============================================================================

cat("Calculating risk and control windows...\n")

# Risk window dates
patient_data$risk_window_start <- patient_data$vaccination_date + risk_window_start
patient_data$risk_window_end <- patient_data$vaccination_date + risk_window_end

# Control window dates
patient_data$control_window_start <- patient_data$vaccination_date + control_window_start
patient_data$control_window_end <- patient_data$vaccination_date + control_window_end

# Adjust for patients who may not complete full windows
patient_data$risk_window_end <- pmin(
  patient_data$risk_window_end,
  patient_data$observation_end
)
patient_data$control_window_end <- pmin(
  patient_data$control_window_end,
  patient_data$observation_end
)

# Calculate actual person-time in each window
patient_data$risk_persontime <- as.numeric(
  patient_data$risk_window_end - patient_data$risk_window_start + 1
)
patient_data$control_persontime <- as.numeric(
  patient_data$control_window_end - patient_data$control_window_start + 1
)

# Remove patients with incomplete windows
patient_data <- patient_data[
  patient_data$risk_persontime == risk_window_length &
  patient_data$control_persontime == control_window_length,
]

cat(sprintf("Patients with complete risk and control windows: %d\n", nrow(patient_data)))

# ============================================================================
# SIMULATE ADVERSE EVENTS (CASES ONLY - SCRI DESIGN)
# ============================================================================

cat("Simulating adverse events using SCRI design...\n")

# In SCRI, we only include CASES (individuals who experienced the event)
# For each case, we determine if the event occurred in risk or control window

# NOTE: Seasonality has been removed for statistical clarity
# Assumption: Homogeneous baseline event rate across the season
# This simplifies the model and avoids temporal confounding complications

# Total person-time across both windows
total_persontime <- sum(patient_data$risk_persontime) + sum(patient_data$control_persontime)

# Calculate expected cases accounting for elevated risk in risk window
# Exact calculation:
# Expected cases = expected_risk_events + expected_control_events
expected_risk_events <- baseline_event_rate * relative_risk * sum(patient_data$risk_persontime)
expected_control_events <- baseline_event_rate * sum(patient_data$control_persontime)
expected_cases <- expected_risk_events + expected_control_events

# Generate actual number of cases (Poisson-distributed)
n_cases <- rpois(1, expected_cases)

cat(sprintf("Baseline event rate: %.5f per person-day\n", baseline_event_rate))
cat(sprintf("Relative risk in risk window: %.2f\n", relative_risk))
cat(sprintf("Expected cases: %.1f (risk: %.1f, control: %.1f)\n",
            expected_cases, expected_risk_events, expected_control_events))
cat(sprintf("Generating %d cases from population of %d...\n", n_cases, nrow(patient_data)))

# Randomly select which individuals are cases
case_indices <- sample(1:nrow(patient_data), size = n_cases, replace = FALSE)

# For SCRI: Among cases, determine if event was in risk or control window
# With homogeneous baseline rate:
# P(risk|event) = (RR * risk_days) / (RR * risk_days + control_days)
# This assumes constant baseline event rate across both windows
prob_risk_given_event <- (relative_risk * risk_window_length) /
  (relative_risk * risk_window_length + control_window_length)

cat(sprintf("Probability of event in risk window (given case): %.3f\n",
            prob_risk_given_event))

# Create case dataset
cases_data <- patient_data[case_indices, ]

# For each case, determine which window the event occurred in
cases_data$event_in_risk_window <- rbinom(
  n = nrow(cases_data),
  size = 1,
  prob = prob_risk_given_event
)

# Determine event date based on which window
cases_data$event_date <- as.Date(NA)

for (i in 1:nrow(cases_data)) {
  if (cases_data$event_in_risk_window[i] == 1) {
    # Event in risk window
    days_offset <- sample(0:(risk_window_length - 1), 1)
    cases_data$event_date[i] <- as.Date(cases_data$risk_window_start[i]) + days_offset
  } else {
    # Event in control window
    days_offset <- sample(0:(control_window_length - 1), 1)
    cases_data$event_date[i] <- as.Date(cases_data$control_window_start[i]) + days_offset
  }
}

# Days from vaccination to event
cases_data$days_to_event <- as.numeric(
  cases_data$event_date - cases_data$vaccination_date
)

# ============================================================================
# FORMAT FOR SCRI ANALYSIS
# ============================================================================

cat("Formatting data for SCRI analysis...\n")

# SCRI analysis dataset: CASES ONLY, one row per window per case
# Each case contributes two rows (risk window and control window)
# The outcome indicates which window contained the event

scri_data <- data.frame()

for (i in 1:nrow(cases_data)) {
  # Risk window row
  risk_row <- data.frame(
    patient_id = cases_data$patient_id[i],
    age = cases_data$age[i],
    age_group = cases_data$age_group[i],
    vaccination_date = cases_data$vaccination_date[i],
    event_date = cases_data$event_date[i],
    days_to_event = cases_data$days_to_event[i],
    window = "risk",
    window_start = cases_data$risk_window_start[i],
    window_end = cases_data$risk_window_end[i],
    person_time = risk_window_length,
    event = cases_data$event_in_risk_window[i]  # 1 if event in this window, 0 otherwise
  )

  # Control window row
  control_row <- data.frame(
    patient_id = cases_data$patient_id[i],
    age = cases_data$age[i],
    age_group = cases_data$age_group[i],
    vaccination_date = cases_data$vaccination_date[i],
    event_date = cases_data$event_date[i],
    days_to_event = cases_data$days_to_event[i],
    window = "control",
    window_start = cases_data$control_window_start[i],
    window_end = cases_data$control_window_end[i],
    person_time = control_window_length,
    event = 1 - cases_data$event_in_risk_window[i]  # 1 if event in this window, 0 otherwise
  )

  scri_data <- rbind(scri_data, risk_row, control_row)
}

# Add window indicator variable for conditional logistic regression
scri_data$risk_indicator <- as.integer(scri_data$window == "risk")

# ============================================================================
# PREPARE FOR SEQUENTIAL MONITORING
# ============================================================================

cat("Preparing sequential monitoring datasets...\n")

# Add calendar time for sequential looks
scri_data$calendar_date <- scri_data$window_end  # Use end of window as "data available" date

# Sort by calendar date
scri_data <- scri_data[order(scri_data$calendar_date), ]

# Create look number based on calendar time
look_dates <- seq(
  from = season_start + control_window_end + look_interval,
  by = look_interval,
  length.out = n_looks
)

scri_data$look_available <- sapply(scri_data$calendar_date, function(d) {
  sum(d >= look_dates)
})

# ============================================================================
# VALIDATION AND SUMMARY STATISTICS
# ============================================================================

cat("\n=====================================================\n")
cat("SIMULATION SUMMARY\n")
cat("=====================================================\n\n")

cat(sprintf("Total population at risk: %d\n", nrow(patient_data)))
cat(sprintf("Number of CASES (events): %d\n", nrow(cases_data)))
cat(sprintf("Flu season: %s to %s\n", season_start, season_end))
cat(sprintf("Risk window: Days %d-%d post-vaccination (%d days)\n",
            risk_window_start, risk_window_end, risk_window_length))
cat(sprintf("Control window: Days %d-%d post-vaccination (%d days)\n",
            control_window_start, control_window_end, control_window_length))
cat(sprintf("\nBaseline event rate: %.5f per person-day\n", baseline_event_rate))
cat(sprintf("Relative risk in risk window: %.2f\n", relative_risk))

# SCRI analysis: Among cases, how many had events in risk vs control window
n_events_risk <- sum(cases_data$event_in_risk_window)
n_events_control <- nrow(cases_data) - n_events_risk

cat(sprintf("\nAmong %d cases:\n", nrow(cases_data)))
cat(sprintf("  Events in risk window: %d (%.1f%%)\n",
            n_events_risk, 100 * n_events_risk / nrow(cases_data)))
cat(sprintf("  Events in control window: %d (%.1f%%)\n",
            n_events_control, 100 * n_events_control / nrow(cases_data)))

# Observed rate ratio (used in SCRI)
# RR = (events_risk / risk_persontime) / (events_control / control_persontime)
# For equal-length windows, this simplifies to events_risk / events_control
obs_rate_ratio <- (n_events_risk / risk_window_length) / (n_events_control / control_window_length)

cat(sprintf("\nObserved rate ratio (risk/control): %.2f\n", obs_rate_ratio))
cat(sprintf("Expected rate ratio (under true RR=%.2f): %.2f\n",
            relative_risk, relative_risk))
cat(sprintf("Note: For equal-length windows (%d days each), RR = OR = %.2f\n",
            risk_window_length, n_events_risk / n_events_control))

# Age distribution of cases
cat("\nAge group distribution of cases:\n")
print(table(cases_data$age_group))

# Sequential monitoring
cat(sprintf("\nSequential monitoring: %d planned looks\n", n_looks))
cat(sprintf("Look interval: %d days\n", look_interval))
cat("Look dates:\n")
print(look_dates)

# Data available at each look
cat("\nCases available by sequential look:\n")
for (look in 1:n_looks) {
  n_available <- sum(scri_data$look_available >= look & scri_data$window == "risk")
  cat(sprintf("  Look %d: %d cases available\n", look, n_available))
}

# ============================================================================
# SAVE DATASETS
# ============================================================================

cat("\nSaving datasets...\n")

# Save wide format (one row per case)
write.csv(cases_data, "scri_data_wide.csv", row.names = FALSE)
cat("  - scri_data_wide.csv (wide format, one row per case)\n")

# Save long format (one row per window per case)
write.csv(scri_data, "scri_data_long.csv", row.names = FALSE)
cat("  - scri_data_long.csv (long format, two rows per case - risk and control windows)\n")

# Save R objects for further analysis
save(patient_data, cases_data, scri_data,
     risk_window_start, risk_window_end,
     control_window_start, control_window_end,
     baseline_event_rate, relative_risk,
     alpha, n_looks, look_dates,
     n_cases, n_events_risk, n_events_control,
     file = "scri_simulation.RData")
cat("  - scri_simulation.RData (R workspace with all objects)\n")

cat("\n=====================================================\n")
cat("SIMULATION COMPLETE\n")
cat("=====================================================\n")
