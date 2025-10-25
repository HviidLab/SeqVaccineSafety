# Launch Sequential Vaccine Safety Surveillance Dashboard
#
# This script launches the interactive Shiny dashboard for
# monitoring vaccine safety using sequential surveillance methods.
#
# Usage:
#   1. Open R or RStudio
#   2. Set working directory to the SeqVaccineSafety folder
#   3. Run: source("launch_dashboard.R")
#   4. The dashboard will open in your default web browser

cat("=======================================================\n")
cat("SEQUENTIAL VACCINE SAFETY SURVEILLANCE DASHBOARD\n")
cat("=======================================================\n\n")

cat("Checking required packages...\n")

# Set CRAN mirror
options(repos = c(CRAN = "https://cloud.r-project.org"))

# Required packages
required_packages <- c("config", "shiny", "shinydashboard", "ggplot2", "plotly", "DT", "fresh")

# Check and install missing packages
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    cat(sprintf("  Installing %s...\n", pkg))
    install.packages(pkg, quiet = TRUE)
  }
}

cat("\nAll packages installed.\n\n")

# Check for configuration file
if (!file.exists("config.yaml")) {
  stop("Error: config.yaml not found. Please ensure config.yaml is in the project root directory.")
}

# Check for data files
if (!file.exists("scri_data_wide.csv")) {
  stop("Error: scri_data_wide.csv not found. Please run simulate_scri_dataset.R first.")
}

cat("Configuration and data files found.\n\n")

cat("Launching dashboard...\n")
cat("The dashboard will open in your web browser.\n")
cat("To stop the dashboard, press Ctrl+C or close the R session.\n\n")

# Launch the dashboard
shiny::runApp("dashboard_app.R", launch.browser = TRUE)
