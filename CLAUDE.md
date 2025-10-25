# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SeqVaccineSafety is an R project focused on vaccine safety surveillance using Self-Controlled Risk Interval (SCRI) designs with sequential monitoring methods. The project generates simulated datasets and performs sequential statistical analyses for detecting potential adverse events following vaccination.

## R Project Configuration

This is an RStudio project (`.Rproj` file present). The project uses:
- 2 spaces for indentation
- UTF-8 encoding
- Standard R workspace settings

## Key Dependencies

The primary R package used is `sequentialdesign` for implementing sequential monitoring methods in vaccine safety surveillance.

## Development Environment

### Running R Scripts
- Open the project in RStudio by double-clicking `SeqVaccineSafety.Rproj`
- Run scripts using `Rscript script_name.R` from command line
- Or use RStudio's source button or `Ctrl+Shift+Enter`

### Installing Dependencies
```r
install.packages("sequentialdesign")
# Install other required packages as they are added to scripts
```

## SCRI Design Context

When working with SCRI (Self-Controlled Risk Interval) designs in this project:

- **Risk window**: Period immediately post-vaccination where elevated risk is evaluated (e.g., days 1-28)
- **Control window**: Period where baseline risk is measured (e.g., days 29-56 or pre-vaccination)
- Each individual serves as their own control, comparing event rates within the same person
- Sequential monitoring allows for early detection of safety signals during ongoing surveillance

## Data Structure Considerations

Simulated datasets should include:
- Patient identifiers
- Vaccination dates
- Adverse event dates and classifications
- Time windows (risk vs control)
- Person-time calculations for each window
- Format compatible with conditional Poisson regression models

## Sequential Analysis Parameters

When implementing sequential designs, consider:
- Alpha spending function for controlling Type I error (e.g., Pocock-type boundaries)
- Number and timing of sequential looks
- Stopping boundaries for detecting signals
- Sample size and power calculations

## Scripts in Repository

### simulate_scri_dataset.R
Generates simulated SCRI datasets for vaccine safety surveillance:
- Creates cases-only data (individuals who experienced events)
- Assigns events to risk or control windows based on configured relative risk
- Outputs: scri_data_wide.csv, scri_data_long.csv, scri_simulation.RData

### sequential_surveillance.R
Performs sequential statistical monitoring on SCRI data:
- Implements Pocock-type sequential boundaries
- Conducts binomial test at each sequential look
- Generates dashboard-ready outputs:
  - Sequential monitoring plots
  - Status reports
  - Alert tables
  - Timeline visualizations
- Stops monitoring when safety signal is detected
- Output directory: surveillance_outputs/

## Dashboard Outputs

The sequential surveillance system generates files suitable for public health dashboards:
- **sequential_monitoring_results.csv** - Tabular results for all looks
- **current_status_report.txt** - Human-readable status summary
- **dashboard_alerts.csv** - Alert levels for key metrics
- **sequential_monitoring_plot.png** - Test statistics vs. boundaries
- **cases_timeline.png** - Cumulative cases and events over time
