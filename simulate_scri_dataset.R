# Simulate SCRI Dataset for Vaccine Safety Surveillance
# Self-Controlled Risk Interval (SCRI) design
# Target: Adults aged 65+ years

options(repos = c(CRAN = "https://cloud.r-project.org"))

# Load required packages
if (!require("config", quietly = TRUE)) {
  install.packages("config")
  library(config)
}

if (!require("SequentialDesign", quietly = TRUE)) {
  install.packages("SequentialDesign")
}
library(SequentialDesign)

# ============================================================================
# LOAD CONFIGURATION
# ============================================================================

cat("Loading configuration from config.yaml...\n")
cfg <- config::get(file = "config.yaml")

if (!is.null(cfg$simulation$random_seed)) {
  set.seed(cfg$simulation$random_seed)
  cat(sprintf("Random seed: %d\n", cfg$simulation$random_seed))
}

# ============================================================================
# EXTRACT PARAMETERS
# ============================================================================

n_patients <- cfg$simulation$population_size
season_start <- as.Date(cfg$simulation$season$start_date)
season_end <- as.Date(cfg$simulation$season$end_date)
season_length <- as.numeric(season_end - season_start)

risk_window_start <- cfg$scri_design$risk_window$start_day
risk_window_end <- cfg$scri_design$risk_window$end_day
control_window_start <- cfg$scri_design$control_window$start_day
control_window_end <- cfg$scri_design$control_window$end_day

risk_window_length <- risk_window_end - risk_window_start + 1
control_window_length <- control_window_end - control_window_start + 1

baseline_event_rate <- cfg$simulation$baseline_event_rate
relative_risk <- cfg$simulation$true_relative_risk

alpha <- cfg$sequential_analysis$overall_alpha
n_looks <- cfg$sequential_analysis$number_of_looks
look_interval <- cfg$sequential_analysis$look_interval_days

# ============================================================================
# GENERATE PATIENT POPULATION
# ============================================================================

cat("Generating patient population...\n")

patient_data <- data.frame(
  patient_id = sprintf("P%05d", 1:n_patients)
)

# Generate age distribution (65+ years)
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
patient_data$observation_start <- season_start

# ============================================================================
# SIMULATE VACCINATION DATES
# ============================================================================

cat("Simulating vaccination dates...\n")

# Vaccination distribution: exponential decay (front-loaded)
days_into_season <- sample(
  0:season_length,
  size = n_patients,
  replace = TRUE,
  prob = dexp(0:season_length, rate = 0.02)
)

patient_data$vaccination_date <- pmin(season_start + days_into_season, season_end)
patient_data$observation_end <- pmin(
  patient_data$vaccination_date + control_window_end,
  season_end
)

# ============================================================================
# CALCULATE TIME WINDOWS
# ============================================================================

cat("Calculating risk and control windows...\n")

patient_data$risk_window_start <- patient_data$vaccination_date + risk_window_start
patient_data$risk_window_end <- patient_data$vaccination_date + risk_window_end
patient_data$control_window_start <- patient_data$vaccination_date + control_window_start
patient_data$control_window_end <- patient_data$vaccination_date + control_window_end

# Adjust for observation end
patient_data$risk_window_end <- pmin(patient_data$risk_window_end, patient_data$observation_end)
patient_data$control_window_end <- pmin(patient_data$control_window_end, patient_data$observation_end)

# Calculate person-time
patient_data$risk_persontime <- as.numeric(patient_data$risk_window_end - patient_data$risk_window_start + 1)
patient_data$control_persontime <- as.numeric(patient_data$control_window_end - patient_data$control_window_start + 1)

# Keep only patients with complete windows
patient_data <- patient_data[
  patient_data$risk_persontime == risk_window_length &
  patient_data$control_persontime == control_window_length,
]

cat(sprintf("Patients with complete windows: %d\n", nrow(patient_data)))

# ============================================================================
# SIMULATE ADVERSE EVENTS (SCRI DESIGN - CASES ONLY)
# ============================================================================

cat("Simulating adverse events...\n")

# Calculate expected cases accounting for elevated risk in risk window
expected_risk_events <- baseline_event_rate * relative_risk * sum(patient_data$risk_persontime)
expected_control_events <- baseline_event_rate * sum(patient_data$control_persontime)
expected_cases <- expected_risk_events + expected_control_events

n_cases <- rpois(1, expected_cases)

cat(sprintf("Baseline rate: %.5f/person-day, RR: %.2f\n", baseline_event_rate, relative_risk))
cat(sprintf("Expected cases: %.1f (risk: %.1f, control: %.1f)\n",
            expected_cases, expected_risk_events, expected_control_events))
cat(sprintf("Generating %d cases from %d patients\n", n_cases, nrow(patient_data)))

# Select cases
case_indices <- sample(1:nrow(patient_data), size = n_cases, replace = FALSE)
cases_data <- patient_data[case_indices, ]

# Determine if event occurred in risk or control window
# P(risk|event) = (RR * risk_days) / (RR * risk_days + control_days)
prob_risk_given_event <- (relative_risk * risk_window_length) /
  (relative_risk * risk_window_length + control_window_length)

cases_data$event_in_risk_window <- rbinom(
  n = nrow(cases_data),
  size = 1,
  prob = prob_risk_given_event
)

# Assign event dates
cases_data$event_date <- as.Date(NA)
for (i in 1:nrow(cases_data)) {
  if (cases_data$event_in_risk_window[i] == 1) {
    days_offset <- sample(0:(risk_window_length - 1), 1)
    cases_data$event_date[i] <- as.Date(cases_data$risk_window_start[i]) + days_offset
  } else {
    days_offset <- sample(0:(control_window_length - 1), 1)
    cases_data$event_date[i] <- as.Date(cases_data$control_window_start[i]) + days_offset
  }
}

cases_data$days_to_event <- as.numeric(cases_data$event_date - cases_data$vaccination_date)

# ============================================================================
# SUMMARY STATISTICS
# ============================================================================

cat("\n=====================================================\n")
cat("SIMULATION SUMMARY\n")
cat("=====================================================\n\n")

cat(sprintf("Population: %d patients\n", nrow(patient_data)))
cat(sprintf("Cases: %d\n", nrow(cases_data)))
cat(sprintf("Season: %s to %s\n", season_start, season_end))
cat(sprintf("Risk window: Days %d-%d (%d days)\n",
            risk_window_start, risk_window_end, risk_window_length))
cat(sprintf("Control window: Days %d-%d (%d days)\n",
            control_window_start, control_window_end, control_window_length))

n_events_risk <- sum(cases_data$event_in_risk_window)
n_events_control <- nrow(cases_data) - n_events_risk

cat(sprintf("\nEvents by window:\n"))
cat(sprintf("  Risk: %d (%.1f%%)\n", n_events_risk, 100 * n_events_risk / nrow(cases_data)))
cat(sprintf("  Control: %d (%.1f%%)\n", n_events_control, 100 * n_events_control / nrow(cases_data)))

obs_rate_ratio <- (n_events_risk / risk_window_length) / (n_events_control / control_window_length)
cat(sprintf("\nObserved RR: %.2f (Expected: %.2f)\n", obs_rate_ratio, relative_risk))

cat("\nAge distribution:\n")
print(table(cases_data$age_group))

cat(sprintf("\nSequential monitoring: %d looks every %d days\n", n_looks, look_interval))

# ============================================================================
# SAVE DATASETS
# ============================================================================

cat("\nSaving datasets...\n")

write.csv(cases_data, "scri_data_wide.csv", row.names = FALSE)

save(patient_data, cases_data,
     risk_window_start, risk_window_end,
     control_window_start, control_window_end,
     baseline_event_rate, relative_risk,
     alpha, n_looks,
     n_cases, n_events_risk, n_events_control,
     file = "scri_simulation.RData")

cat("  - scri_data_wide.csv\n")
cat("  - scri_simulation.RData\n")

cat("\n=====================================================\n")
cat("SIMULATION COMPLETE\n")
cat("=====================================================\n")
