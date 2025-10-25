# Test control window logic
data <- read.csv("scri_data_wide.csv", stringsAsFactors = FALSE)
data$control_window_end <- as.Date(data$control_window_end)
data$vaccination_date <- as.Date(data$vaccination_date)
data$event_date <- as.Date(data$event_date)

cat("Original data:\n")
cat("  Total cases:", nrow(data), "\n")
cat("  Events in risk (1-28):", sum(data$event_in_risk_window), "\n\n")

# Test with control window 29-48
risk_start <- 1
risk_end <- 28
control_start <- 29
control_end <- 48

cat("Testing with Risk: 1-28, Control: 29-48\n")

# Recalculate event assignments
data$event_in_risk_window <- (data$days_to_event >= risk_start & data$days_to_event <= risk_end)
data$event_in_control_window <- (data$days_to_event >= control_start & data$days_to_event <= control_end)

cat("Before filtering:\n")
cat("  Cases in risk window:", sum(data$event_in_risk_window), "\n")
cat("  Cases in control window:", sum(data$event_in_control_window), "\n")
cat("  Cases in both:", sum(data$event_in_risk_window & data$event_in_control_window), "\n")
cat("  Cases in either:", sum(data$event_in_risk_window | data$event_in_control_window), "\n\n")

# Filter
data_filtered <- data[data$event_in_risk_window | data$event_in_control_window, ]

cat("After filtering:\n")
cat("  Total cases:", nrow(data_filtered), "\n")
cat("  Cases in risk:", sum(data_filtered$event_in_risk_window), "\n")
cat("  Cases in control:", sum(data_filtered$event_in_control_window), "\n\n")

# Recalculate control_window_end
data_filtered$control_window_end <- data_filtered$vaccination_date + control_end

cat("After recalculating control_window_end:\n")
cat("  Min control_window_end:", min(data_filtered$control_window_end), "\n")
cat("  Max control_window_end:", max(data_filtered$control_window_end), "\n")
cat("  Unique dates:", length(unique(data_filtered$control_window_end)), "\n\n")

# Convert to 0/1
data_filtered$event_in_risk_window <- ifelse(data_filtered$event_in_risk_window, 1, 0)

# Now simulate first look
min_cases <- 50
look_dates <- sort(unique(data_filtered$control_window_end))

cat("Looking for first viable look with min", min_cases, "cases:\n")
first_look <- NULL
for (i in 1:min(10, length(look_dates))) {
  date <- look_dates[i]
  available <- data_filtered[data_filtered$control_window_end <= date, ]
  cat("  Date", as.character(date), "- Cases available:", nrow(available), "\n")
  if (nrow(available) >= min_cases && is.null(first_look)) {
    first_look <- date
    cat("    -> First viable look!\n")

    events_risk <- sum(available$event_in_risk_window)
    events_control <- nrow(available) - events_risk
    cat("    -> Events in risk:", events_risk, "\n")
    cat("    -> Events in control:", events_control, "\n")
  }
}
