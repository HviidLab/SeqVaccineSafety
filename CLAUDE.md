# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SeqVaccineSafety is an R project for vaccine safety surveillance using Self-Controlled Risk Interval (SCRI) designs with sequential monitoring methods. The project generates simulated vaccine safety datasets (target population: adults aged 65+ years) and performs sequential statistical analyses to detect potential adverse events following vaccination.

**Key Features**:
- Configuration-driven architecture (no hard-coded values)
- Complete end-to-end workflow (simulate → analyze → visualize)
- Interactive Shiny dashboard with real-time updates
- Publication-ready outputs
- Built-in data validation and testing utilities

## R Project Configuration

This is an RStudio project (`.Rproj` file present). The project uses:
- 2 spaces for indentation
- UTF-8 encoding
- Standard R workspace settings

## Key Dependencies

**Core R Packages**:
- `config` - Configuration management from YAML
- `ggplot2` - Base plotting and visualizations
- `shiny` - Interactive dashboard framework
- `shinydashboard` - Dashboard template and layout
- `plotly` - Interactive visualizations (zoom, pan, hover)
- `DT` - Interactive data tables
- `fresh` - Dashboard styling and theming
- **`Sequential`** - Exact sequential analysis using MaxSPRT for vaccine safety surveillance

**Sequential Analysis Package**:
The project uses the `Sequential` R package (Kulldorff & Silva) for formal sequential statistical analysis. This package was developed for the CDC's Vaccine Safety Datalink and provides exact sequential methods (not approximations) for post-market vaccine safety surveillance using the Maximized Sequential Probability Ratio Test (MaxSPRT).

**Installation**: All required packages are automatically installed if missing when running `launch_dashboard.R`.

## Development Environment

### Running R Scripts
- Open the project in RStudio by double-clicking `SeqVaccineSafety.Rproj`
- Run scripts using `Rscript script_name.R` from command line
- Or use RStudio's source button or `Ctrl+Shift+Enter`

### Installing Dependencies
```r
# Manual installation if needed:
install.packages(c("config", "ggplot2", "shiny", "shinydashboard", "plotly", "DT", "fresh", "Sequential"))
```

### Important Note on Sequential Package
The `Sequential` package is **essential** for this project. It provides:
- Exact sequential analysis methods (not approximations)
- MaxSPRT (Maximized Sequential Probability Ratio Test)
- Designed specifically for vaccine safety surveillance (CDC Vaccine Safety Datalink)
- Wald alpha spending for optimal statistical properties
- Automatic critical value calculations based on cumulative data

### Standard Analysis Workflow
1. Edit `config.yaml` to set parameters for your analysis
2. Run `simulate_scri_dataset.R` → generates CSV and RData files
3. Run `sequential_surveillance.R` → generates outputs in `surveillance_outputs/`
4. Run `launch_dashboard.R` → opens interactive dashboard
5. Adjust parameters in dashboard → see results instantly

## Centralized Configuration System

**All analysis parameters are managed through `config.yaml`** - the single source of truth for the project. Changes to this file automatically propagate to all scripts.

### Configuration File Structure
- **Simulation settings**: Population size, event rates, relative risk, season parameters, age distributions
- **SCRI design parameters**: Risk/control window definitions, completeness requirements
- **Sequential analysis parameters**: Alpha level, number of looks, look intervals, minimum cases, boundary method
- **Dashboard settings**: Default values, slider ranges, alert thresholds
- **Output settings**: Directory paths, plot specifications, report formatting
- **Data validation**: Checks for duplicates, date consistency, missing values
- **Advanced options**: Logging, parallel processing (future), caching (future)
- **Metadata**: Project name, version, description, contact info

### Configuration Profiles
The project includes multiple configuration profiles for different scenarios:
- **`default`**: Standard analysis (alpha=0.05, 8 looks, 28-day risk window)
- **`conservative`**: More stringent analysis (alpha=0.01, 4 looks)
- **`acute_events`**: Early-onset events (7-day risk window, RR=2.0)

**Documentation**: See `CONFIG_GUIDE.md` for comprehensive configuration instructions, examples, and best practices.

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

## Project Structure

```
SeqVaccineSafety/
├── config.yaml                      # Centralized configuration (single source of truth)
├── Main Analysis Scripts/
│   ├── simulate_scri_dataset.R      # Generate simulated datasets
│   ├── sequential_surveillance.R    # Perform sequential analysis
│   ├── dashboard_app.R              # Interactive Shiny dashboard
│   └── launch_dashboard.R           # Dashboard launcher
├── Testing & Validation/
│   ├── check_data.R                 # Data validation utility
│   ├── test_control_window.R        # Window logic testing
│   └── test_control_window2.R       # Advanced window testing
├── Documentation/
│   ├── CLAUDE.md                    # This file (project instructions)
│   ├── CONFIG_GUIDE.md              # Configuration manual
│   └── DASHBOARD_README.md          # Dashboard user guide
├── Data Files/
│   ├── scri_data_wide.csv           # One row per case
│   ├── scri_data_long.csv           # Two rows per case (risk/control)
│   └── scri_simulation.RData        # R workspace with all objects
└── surveillance_outputs/            # Generated results, plots, reports
```

## Scripts in Repository

### Main Analysis Scripts

#### simulate_scri_dataset.R
Generates simulated SCRI datasets for vaccine safety surveillance:
- **Configuration-driven**: Reads all parameters from `config.yaml`
- Creates population of vaccinated individuals (configurable size, default 20,000)
- Assigns age groups (65-74, 75-84, 85+) based on configured distributions
- Simulates vaccination dates following exponential distribution (front-loaded to season start)
- Assigns adverse events using SCRI methodology (cases-only design)
- Determines event timing in risk vs. control windows based on simulated relative risk
- Calculates person-time for each window
- Filters for complete windows only (configurable)
- **Outputs**:
  - `scri_data_wide.csv` - One row per case (wide format)
  - `scri_data_long.csv` - Two rows per case (long format for regression)
  - `scri_simulation.RData` - R workspace with all simulation objects

#### sequential_surveillance.R
Performs sequential statistical monitoring on SCRI data using the **Sequential R package**:
- **Configuration-driven**: Uses `config.yaml` for alpha, looks, intervals, etc.
- **Uses Sequential package for exact analysis**:
  - `AnalyzeSetUp.Binomial()` initializes the analysis with Wald alpha spending
  - `Analyze.Binomial()` performs MaxSPRT test at each sequential look
  - Exact critical values (not approximations)
- Conducts binomial sequential test at each look:
  - H₀: Equal risk in both windows (p = 0.5)
  - MaxSPRT test statistic with exact signal detection
- Calculates observed relative risk (odds ratio)
- Determines p-values and extracts critical values from Sequential package
- Stops monitoring when safety signal detected (configurable)
- **Generates 5 dashboard-ready outputs** in `surveillance_outputs/`:
  - `sequential_monitoring_results.csv` - Tabular results for all looks
  - `current_status_report.txt` - Human-readable status summary
  - `sequential_monitoring_plot.png` - Test statistics vs. exact boundaries + RR trends
  - `cases_timeline.png` - Cumulative cases and events over time
  - `dashboard_alerts.csv` - Alert levels for key metrics

#### dashboard_app.R
Interactive R Shiny dashboard for real-time vaccine safety monitoring using the **Sequential R package**:
- **Data source**: Loads `scri_data_wide.csv` and performs real-time analysis
- **Sequential Analysis**: Uses Sequential package for exact MaxSPRT testing
  - Dynamic setup with `AnalyzeSetUp.Binomial()` for user-selected parameters
  - Real-time analysis with `Analyze.Binomial()` at each look
  - Exact critical values and signal detection
- **Features**:
  - Interactive parameter controls (sliders for alpha, looks, window sizes, min cases)
  - Real-time sequential analysis with instant updates using exact methods
  - Animated alert banners for signal detection (red = signal, green = no signal)
  - Interactive Plotly visualizations (zoom, pan, hover details)
  - Color-coded value boxes for key metrics (total cases, RR, p-value, signal status)
  - Automated recommendations for public health action
  - Professional styling with custom CSS
  - Two-tab layout: Dashboard (analysis) and About (documentation)
- **Dependencies**: Requires shiny, shinydashboard, plotly, DT, ggplot2, config, fresh, Sequential packages
- **Usage**: Launch with `source("launch_dashboard.R")`
- **Documentation**: See `DASHBOARD_README.md` for detailed user guide

#### launch_dashboard.R
Convenience script to launch the Shiny dashboard:
- Automatically checks for and installs required packages (config, shiny, shinydashboard, ggplot2, plotly, DT, fresh, Sequential)
- Validates presence of `config.yaml` and `scri_data_wide.csv`
- Launches dashboard in default web browser
- Provides clear user instructions in console

### Testing & Validation Scripts

#### check_data.R
Data validation and exploratory analysis utility:
- Loads simulated data and provides summary statistics
- Shows distribution of events across different day ranges
- Tests filtering logic with different window definitions
- Helps validate data consistency

#### test_control_window.R
Test script for control window logic validation:
- Tests recalculation of event assignments with different window definitions
- Verifies filtering and data recalculation
- Checks control window end date recalculation
- Tests first look viability with minimum cases threshold

#### test_control_window2.R
Advanced control window testing:
- Tests finding first viable look with minimum case requirement
- Shows date ranges for sequential analysis
- Validates the complete look schedule can be established

## Data Files & Formats

### Generated Data Files

**scri_data_wide.csv** (Wide format - One row per case):
- **Columns (15)**: patient_id, age_group, age, observation_start, observation_end, vaccination_date, event_date, risk_window_start, risk_window_end, control_window_start, control_window_end, risk_persontime, control_persontime, days_to_event, event_in_risk_window
- **Use case**: Binomial tests, dashboard visualization, summary statistics

**scri_data_long.csv** (Long format - Two rows per case):
- **Columns (14)**: patient_id, age, age_group, vaccination_date, event_date, days_to_event, window (risk/control), window_start, window_end, person_time, event (0/1), risk_indicator (1/0), calendar_date, look_available
- **Use case**: Conditional logistic regression, time-varying analyses

**scri_simulation.RData**:
- R workspace containing all simulation objects (patient_data, cases_data, scri_data)
- Window parameters, rate parameters, sequential parameters
- Summary statistics (n_cases, events_risk, events_control)

## Dashboard Outputs

The sequential surveillance system generates 5 files in `surveillance_outputs/`:

1. **sequential_monitoring_results.csv** - Tabular results for all sequential looks
   - Columns: look_number, look_date, n_cases, events_risk, events_control, prop_risk, observed_RR, z_statistic, z_critical, p_value, signal_detected, status

2. **current_status_report.txt** - Human-readable status summary
   - Contains: Report date, analysis date, total looks, case counts, events by window, relative risk, p-value, signal status, recommendations

3. **sequential_monitoring_plot.png** - Two-panel visualization
   - Panel 1: Z-statistic vs. Pocock boundary over time (with signal marker)
   - Panel 2: Observed RR trends with reference lines (RR=1.0, 1.5, 2.0)

4. **cases_timeline.png** - Cumulative timeline visualization
   - Total cumulative cases, events in risk window, events in control window

5. **dashboard_alerts.csv** - Alert metrics table
   - Columns: Metric, Value, Alert_Level (Normal/Warning/Alert/Critical)

## Data Validation Infrastructure

The project includes built-in data validation controlled by `config.yaml`:

**Validation Checks**:
- Duplicate patient ID detection
- Date consistency verification (vaccination before event, proper chronological order)
- Window calculation verification (correct person-time, no overlaps)
- Missing value warnings

**Configuration Options**:
- `strict_mode: false` - Whether to treat validation warnings as errors
- Individual toggles for each validation check type

**Validation Scripts**: Use `check_data.R`, `test_control_window.R`, and `test_control_window2.R` for manual validation and testing.

## Statistical Methodology

### SCRI Design
- **Self-Controlled Risk Interval**: Each person serves as their own control
- **Case-only design**: No denominator data needed, analyzes only individuals who experienced events
- **Within-person comparison**: Compares event rates in risk window vs. control window (same person)
- **Relative Risk**: Estimated as odds ratio from 2x2 table (risk window events / control window events)

### Sequential Analysis
The project uses the **Sequential R package** for exact sequential analysis:

- **Method**: Maximized Sequential Probability Ratio Test (MaxSPRT)
  - Developed by Kulldorff & Silva for CDC's Vaccine Safety Datalink
  - Exact calculations (not asymptotic approximations)
  - Designed specifically for vaccine safety surveillance

- **Test**: Binomial sequential test
  - H₀: p = 0.5 (equal risk in both windows for equal-length windows)
  - H₁: p > 0.5 (elevated risk in risk window)
  - Uses `AnalyzeSetUp.Binomial()` for initialization
  - Uses `Analyze.Binomial()` for each sequential look

- **Alpha Spending**: Wald alpha spending function
  - Balances power and Type I error control
  - Adapts to group sequential monitoring
  - Exact critical values calculated by Sequential package

- **Key Functions Used**:
  - `AnalyzeSetUp.Binomial()` - Initialize analysis parameters (target RR, power, alpha, minimum cases)
  - `Analyze.Binomial()` - Perform test at each look (cases, controls, matching ratio)
  - Automatic critical value calculation and signal detection

- **Early Stopping**: Monitoring stops when MaxSPRT exceeds critical value (configurable)
- **Signal Detection**: One-sided upper-tailed test at configured significance level

## Interactive Dashboard

For real-time monitoring and parameter exploration, use the Shiny dashboard:
```r
source("launch_dashboard.R")
```

The dashboard provides:
- Instant visual feedback on signal detection
- Interactive parameter adjustment with real-time analysis updates
- Publication-ready interactive visualizations
- Automated decision support for public health officials

**Full documentation**: See `DASHBOARD_README.md` for detailed user guide.

## Documentation Files

- **CLAUDE.md** (this file) - Project instructions for Claude Code and quick reference
- **CONFIG_GUIDE.md** - Comprehensive configuration manual with examples and best practices
- **DASHBOARD_README.md** - Shiny dashboard user guide with features, use cases, and interpretation

## Best Practices

### Configuration Management
- **Always use `config.yaml`** - Never hard-code parameters in scripts
- Test configuration changes with validation scripts before full analysis
- Document custom configuration profiles in CONFIG_GUIDE.md
- Use version control to track configuration changes

### Reproducibility
- Set `random_seed` in config.yaml for reproducible simulations
- Document all parameter modifications
- Keep config.yaml in version control
- Save complete outputs (CSV + RData) for archival

### Workflow Tips
- Run validation scripts (`check_data.R`, `test_control_window.R`) after simulation
- Review `surveillance_outputs/current_status_report.txt` for quick status summaries
- Use dashboard for parameter exploration before finalizing analysis config
- Test different configuration profiles (default, conservative, acute_events) to assess sensitivity
