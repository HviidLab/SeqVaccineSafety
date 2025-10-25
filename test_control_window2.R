# Test if we can find ANY viable look with control window 29-48
data <- read.csv("scri_data_wide.csv", stringsAsFactors = FALSE)
data$vaccination_date <- as.Date(data$vaccination_date)

# Parameters
risk_start <- 1
risk_end <- 28
control_start <- 29
control_end <- 48
min_cases <- 50

# Filter and recalculate
data$event_in_risk_window <- (data$days_to_event >= risk_start & data$days_to_event <= risk_end)
data$event_in_control_window <- (data$days_to_event >= control_start & data$days_to_event <= control_end)
data <- data[data$event_in_risk_window | data$event_in_control_window, ]
data$control_window_end <- data$vaccination_date + control_end

cat("Total cases after filtering:", nrow(data), "\n")
cat("Looking for first date with >=", min_cases, "cases:\n\n")

look_dates <- sort(unique(data$control_window_end))

found_first <- FALSE
for (i in 1:length(look_dates)) {
  date <- look_dates[i]
  available <- data[data$control_window_end <= date, ]
  n <- nrow(available)

  if (!found_first) {
    if (n >= min_cases) {
      cat("FIRST VIABLE LOOK:\n")
      cat("  Date:", as.character(date), "\n")
      cat("  Cases available:", n, "\n")
      found_first <- TRUE

      # Also show last look
      last_date <- max(look_dates)
      last_available <- data[data$control_window_end <= last_date, ]
      cat("\nLAST LOOK:\n")
      cat("  Date:", as.character(last_date), "\n")
      cat("  Cases available:", nrow(last_available), "\n")

      break
    }
  }
}

if (!found_first) {
  cat("NO VIABLE LOOK FOUND!\n")
  cat("Maximum cases available:", max(sapply(look_dates, function(d) nrow(data[data$control_window_end <= d, ]))), "\n")
  cat("Need at least:", min_cases, "\n")
}
