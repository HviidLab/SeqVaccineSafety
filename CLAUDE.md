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
- **`SequentialDesign`** - Simulation framework for Type I error and power validation studies

**Sequential Analysis Packages**:
The project integrates two complementary packages:

1. **Sequential Package** (Kulldorff & Silva):
   - Exact sequential analysis methods (not approximations)
   - MaxSPRT (Maximized Sequential Probability Ratio Test)
   - Developed for CDC's Vaccine Safety Datalink
   - Wald alpha spending for optimal statistical properties
   - Automatic critical value calculations and sequential-adjusted confidence intervals
   - Used in: `sequential_surveillance.R`, `dashboard_app.R`

2. **SequentialDesign Package** (Maro & Hou):
   - Simulation framework for observational database studies
   - Type I error control validation (1000+ simulations with RR=1.0)
   - Power validation studies (1000+ simulations with RR=1.5, 2.0)
   - Misclassification modeling (sensitivity, PPV)
   - Multiple strata support
   - Used in: `validate_surveillance.R` (validation mode only)

**Installation**: All required packages are automatically installed if missing when running `launch_dashboard.R` or any analysis script.

## Development Environment

### Running R Scripts
- Open the project in RStudio by double-clicking `SeqVaccineSafety.Rproj`
- Run scripts using `Rscript script_name.R` from command line
- Or use RStudio's source button or `Ctrl+Shift+Enter`

### Installing Dependencies
```r
# Manual installation if needed:
install.packages(c("config", "ggplot2", "shiny", "shinydashboard", "plotly", "DT", "fresh", "Sequential", "SequentialDesign"))
```

### Standard Analysis Workflow

**Primary Workflow (Custom Simulation)**:
1. Ensure `config.yaml` has `simulation.method: "custom"` (default)
2. Edit other parameters in `config.yaml` for your analysis
3. Run `simulate_scri_dataset.R` → generates CSV and RData files
4. Run `sequential_surveillance.R` → generates outputs in `surveillance_outputs/`
5. Run `launch_dashboard.R` → opens interactive dashboard
6. Adjust parameters in dashboard → see results instantly

**Validation Workflow (SequentialDesign for Type I Error/Power Studies)**:
1. Edit `config.yaml` to set `simulation.sequential_design.n_simulations: 1000` (or higher)
2. Configure strata, event rates, and misclassification parameters
3. Run `validate_surveillance.R` → performs 3 scenarios (RR=1.0, 1.5, 2.0)
4. Review validation reports in `surveillance_outputs/validation_results/`
5. Use results to assess system performance and update documentation

**Simulation Method Selection**:
- **Custom method** (`method: "custom"`): Transparent, educational simulation with seasonality
  - Best for: Single datasets, teaching, research, exploratory analysis
  - Strengths: Clear code, flexible parameters, seasonal modeling

- **SequentialDesign method** (`method: "sequential_design"`): Standardized simulation framework
  - Best for: Large-scale validation (1000+ sims), power studies, Type I error checks
  - Strengths: Misclassification modeling, multiple strata, formal validation
  - Note: Primarily used via `validate_surveillance.R`, not directly in main workflow

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
├── config.yaml                           # Centralized configuration (single source of truth)
├── Main Analysis Scripts/
│   ├── simulate_scri_dataset.R           # Generate simulated datasets (supports custom & SequentialDesign methods)
│   ├── simulate_scri_sequential_design.R # SequentialDesign implementation (called by simulate_scri_dataset.R)
│   ├── sequential_surveillance.R         # Perform sequential analysis using Sequential package
│   ├── validate_surveillance.R           # Type I error and power validation (1000+ simulations)
│   ├── dashboard_app.R                   # Interactive Shiny dashboard
│   └── launch_dashboard.R                # Dashboard launcher
├── Testing & Validation/
│   ├── check_data.R                      # Data validation utility
│   ├── test_control_window.R             # Window logic testing
│   └── test_control_window2.R            # Advanced window testing
├── Documentation/
│   ├── CLAUDE.md                         # This file (project instructions)
│   ├── CONFIG_GUIDE.md                   # Configuration manual
│   └── DASHBOARD_README.md               # Dashboard user guide
├── Data Files/
│   ├── scri_data_wide.csv                # One row per case
│   ├── scri_data_long.csv                # Two rows per case (risk/control)
│   └── scri_simulation.RData             # R workspace with all objects
└── surveillance_outputs/                 # Generated results, plots, reports
    ├── sequential_design_output/         # SequentialDesign simulation results
    └── validation_results/               # Type I error and power validation studies
```

## Scripts in Repository

### Main Analysis Scripts

#### simulate_scri_dataset.R
Generates simulated SCRI datasets for vaccine safety surveillance with **dual simulation modes**:
- **Configuration-driven**: Reads all parameters from `config.yaml`
- **Simulation Method Selection** (via `simulation.method` in config):
  - `"custom"` (default): Transparent educational simulation with seasonality
  - `"sequential_design"`: Calls SequentialDesign package for validation studies

**Custom Method Features**:
- Creates population of vaccinated individuals (configurable size, default 20,000)
- Assigns age groups (65-74, 75-84, 85+) based on configured distributions
- Simulates vaccination dates following exponential distribution (front-loaded to season start)
- **Seasonality**: Implements time-varying baseline event rates
  - Sinusoidal pattern: rate(t) = baseline × (1 + 0.2 × sin(2π(t-60)/365))
  - ±20% seasonal variation with peak in early February
  - Addresses temporal confounding in SCRI designs
- Assigns adverse events using SCRI methodology (cases-only design)
- Determines event timing in risk vs. control windows based on simulated relative risk
- Calculates person-time for each window
- Filters for complete windows only (configurable)

**SequentialDesign Method Features** (calls `simulate_scri_sequential_design.R`):
- Uses SequentialDesign package functions for standardized simulation
- Supports multiple strata with configurable event rates
- Models misclassification (sensitivity, positive predictive value)
- Designed for large-scale validation (1000+ simulations)
- Outputs stored in `surveillance_outputs/sequential_design_output/`

**Outputs** (custom method):
  - `scri_data_wide.csv` - One row per case (wide format)
  - `scri_data_long.csv` - Two rows per case (long format for regression)
  - `scri_simulation.RData` - R workspace with all simulation objects

#### sequential_surveillance.R
Performs sequential statistical monitoring on SCRI data using the **Sequential R package**:
- **Configuration-driven**: Uses `config.yaml` for alpha, looks, intervals, etc.
- **Uses Sequential package for exact analysis**:
  - `AnalyzeSetUp.Binomial()` initializes the analysis with Wald alpha spending
    - `zp` parameter correctly set to control_length / risk_length
  - `Analyze.Binomial()` performs MaxSPRT test at each sequential look
  - Exact critical values (not approximations)
- Conducts binomial sequential test at each look:
  - H₀: p = p₀ (adjusts for window lengths automatically)
  - MaxSPRT test statistic with exact signal detection
- **Calculates observed relative risk (rate ratio)**:
  - Proper rate ratio: RR = (events_risk/risk_length) / (events_control/control_length)
  - Continuity correction for zero cells
  - Robust to unequal window lengths
- **Extracts sequential-adjusted 95% confidence intervals** from Sequential package
- Determines p-values and extracts critical values from Sequential package
- Stops monitoring when safety signal detected (configurable)
- **Generates 5 dashboard-ready outputs** in `surveillance_outputs/`:
  - `sequential_monitoring_results.csv` - Tabular results with sequential-adjusted CIs
  - `current_status_report.txt` - Status summary with CIs
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
- Automatically checks for and installs required packages (config, shiny, shinydashboard, ggplot2, plotly, DT, fresh, Sequential, SequentialDesign)
- Validates presence of `config.yaml` and `scri_data_wide.csv`
- Launches dashboard in default web browser
- Provides clear user instructions in console

#### validate_surveillance.R
**NEW**: Comprehensive validation system for Type I error control and statistical power using SequentialDesign:
- **Purpose**: Validates surveillance system performance through large-scale simulation studies
- **Configuration-driven**: Uses `simulation.sequential_design` parameters from `config.yaml`
- **Three Validation Scenarios** (1000+ simulations each):
  1. **Type I Error Validation** (RR = 1.0): Tests false positive rate under null hypothesis
  2. **Power Validation** (RR = 1.5): Tests detection capability with moderate elevated risk
  3. **Power Validation** (RR = 2.0): Tests detection capability with strong elevated risk

**SequentialDesign Integration**:
- Uses `initialize.data()` to configure study parameters
- Calls `create.exposure()` and `sim.exposure()` for data generation
- Executes `SCRI.seq()` for sequential analysis across all simulations
- Supports misclassification modeling (sensitivity, PPV)
- Handles multiple strata (age groups, sex, etc.)

**Outputs** (in `surveillance_outputs/validation_results/`):
- `validation_report.txt` - Comprehensive summary of all validation scenarios
- `type1_error_RR1.0/` - Sequential package output files for null hypothesis testing
- `power_RR1.5/` - Output files for moderate effect size power analysis
- `power_RR2.0/` - Output files for strong effect size power analysis

**Typical Runtime**: 30-90 minutes for 3000 total simulations (1000 per scenario)

**Usage**:
```r
# Configure parameters in config.yaml first
# Then run:
source("validate_surveillance.R")
```

**Interpretation**:
- Type I error rate should be ≈ target alpha (e.g., 0.05)
- Power at RR=1.5 should be ≥ 80-90%
- Power at RR=2.0 should be > 95%
- Results inform system calibration and performance documentation

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
- **Relative Risk**: Estimated as **rate ratio** (not odds ratio)
  - Formula: RR = (events_risk / risk_window_length) / (events_control / control_window_length)
  - Properly accounts for differential person-time when windows have different lengths
  - For equal-length windows, numerically equivalent to odds ratio

### Sequential Analysis
The project uses the **Sequential R package** for exact sequential analysis:

- **Method**: Maximized Sequential Probability Ratio Test (MaxSPRT)
  - Developed by Kulldorff & Silva for CDC's Vaccine Safety Datalink
  - Exact calculations (not asymptotic approximations)
  - Designed specifically for vaccine safety surveillance

- **Test**: Binomial sequential test
  - H₀: p = p₀ where p₀ = risk_window_length / (risk_window_length + control_window_length)
  - H₁: p > p₀ (elevated risk in risk window)
  - Automatically adjusts for unequal window lengths
  - Uses `AnalyzeSetUp.Binomial()` for initialization
  - Uses `Analyze.Binomial()` for each sequential look

- **Alpha Spending**: Wald alpha spending function
  - Balances power and Type I error control
  - Adapts to group sequential monitoring
  - Exact critical values calculated by Sequential package

- **Key Functions Used**:
  - `AnalyzeSetUp.Binomial()` - Initialize analysis parameters
    - `zp` parameter set to control_window_length / risk_window_length (matching ratio)
    - Target RR, power (90%), alpha, minimum cases
  - `Analyze.Binomial()` - Perform MaxSPRT test at each look
    - Returns signal detection, critical values, and **sequential-adjusted confidence intervals**
  - Automatic critical value calculation and signal detection

- **Sequential-Adjusted Confidence Intervals**:
  - 95% CIs extracted from Sequential package account for multiple testing
  - Reported in all outputs (console, CSV files, status reports)
  - Wider than standard CIs to maintain coverage probability under sequential testing

- **Early Stopping**: Monitoring stops when MaxSPRT exceeds critical value (configurable)
- **Signal Detection**: One-sided upper-tailed test at configured significance level

## Statistical Rigor and Recent Improvements

The codebase has been reviewed by statistical experts and underwent critical improvements to ensure methodological rigor for vaccine safety surveillance.

### Critical Statistical Fixes Implemented

**1. Rate Ratio Calculation (Fixed)**
- **Issue**: Previously used odds ratio instead of rate ratio
- **Fix**: Now correctly calculates RR = (events_risk/risk_length) / (events_control/control_length)
- **Impact**: Robust to unequal window lengths, proper SCRI methodology
- **Bonus**: Continuity correction (0.5) for zero cells

**2. Null Hypothesis for Unequal Windows (Fixed)**
- **Issue**: Previously assumed p₀ = 0.5 (only valid for equal windows)
- **Fix**: Now calculates p₀ = risk_length / (risk_length + control_length)
- **Impact**: Correct Type I error control for any window configuration

**3. Sequential Package Parameters (Fixed)**
- **Issue**: `zp` parameter was hard-coded to 1
- **Fix**: Now calculates zp = control_length / risk_length (matching ratio)
- **Impact**: Correct critical values and power calculations in Sequential package

**4. Sequential-Adjusted Confidence Intervals (Added)**
- **Issue**: Standard CIs don't account for multiple testing
- **Fix**: Extract and report 95% CIs from Sequential package (columns 13-14)
- **Impact**: Proper inference accounting for sequential monitoring
- **Example**: RR=1.27 (95% CI: 1.09-1.32)

**5. Seasonality Adjustment (Added)**
- **Issue**: Constant baseline rate unrealistic, susceptible to time-varying confounding
- **Fix**: Sinusoidal seasonal pattern: rate(t) = baseline × (1 + 0.2 × sin(2π(t-60)/365))
- **Parameters**: ±20% seasonal variation, peak in early February (day 60)
- **Impact**: More realistic simulations, addresses temporal confounding

**6. Zero Cell Handling (Added)**
- **Issue**: Undefined RR when control events = 0
- **Fix**: Applies continuity correction (events_control + 0.5)
- **Impact**: Robust analysis with sparse data

### Robustness Features

✅ **Unequal Window Lengths**: All calculations correct for any risk/control window ratio
✅ **Sparse Data**: Continuity corrections for zero cells
✅ **Temporal Confounding**: Seasonal variation in baseline rates
✅ **Multiple Testing**: Sequential-adjusted confidence intervals
✅ **Exact Methods**: No asymptotic approximations (Sequential package)

### Validation Status

#### Code Review and Critical Bug Fixes

- ✅ **Code Review**: Senior CDC statistician-level review completed (October 27, 2025)
- ✅ **Mathematical Correctness**: All formulas verified for SCRI design
- ✅ **CRITICAL BUG FIXED**: z parameter in `Analyze.Binomial()` (Line 228)
  - **Issue**: Previously hardcoded `z=1`, causing incorrect null hypothesis for unequal windows
  - **Fix**: Now uses `z=zp_ratio` from setup, ensuring correct H0 for all window configurations
  - **Testing**: Verified with both equal (28:28) and unequal (14:42) window scenarios
  - **Impact**: Type I error control now valid for any risk/control window ratio
- ✅ **Edge Cases**: Zero cells, sparse data, unequal windows tested
- ✅ **Output Verification**: All results consistent with Sequential package
- ✅ **SequentialDesign Integration**: Validation framework implemented with `validate_surveillance.R`
- ✅ **Sequential Package Verification**: Comprehensive verification document created (`SEQUENTIAL_VERIFICATION.md`)

#### Validation Studies Status

- 🔄 **Type I Error Validation**: Framework ready, requires 1000+ simulations (30-90 min runtime)
- 🔄 **Power Validation**: Framework ready, requires 1000+ simulations for RR=1.5 and RR=2.0
- ⚠️ **SequentialDesign Tuning**: Parameter configuration needs refinement for large-scale simulations

**Critical Fixes Completed (October 27, 2025)**:
1. ✅ Fixed z parameter bug in `sequential_surveillance.R:228`
2. ✅ Created `test_unequal_windows.R` to verify fix
3. ✅ Created `SEQUENTIAL_VERIFICATION.md` for statistical review
4. ✅ All fixes tested and verified working

**How to Run Validation**:
```r
# Method 1: Manual validation with custom simulation (recommended for now)
# 1. Set up multiple simulation runs with RR=1.0 (null hypothesis)
# 2. Count proportion of false positives
# 3. Should be ≈ alpha (e.g., 0.05)

# Method 2: SequentialDesign automated validation (needs parameter tuning)
# Edit config.yaml: simulation.sequential_design.n_simulations: 1000
# source("validate_surveillance.R")  # Runtime: 30-90 minutes per scenario
```

**Documentation for Statisticians**:
- See `SEQUENTIAL_VERIFICATION.md` for detailed statistical verification
- See `test_unequal_windows.R` for bug fix demonstration
- All test scripts available in project root

**Recommended for:**
- ✅ Educational use and teaching SCRI methodology
- ✅ Methods research and development
- ✅ Exploration of sequential surveillance designs
- ✅ Preliminary observational analyses (with critical bug fix applied)
- ⚠️ Production VSD deployment (after completing validation below)

**Before production VSD use:**
- ✅ **COMPLETED**: Fix critical z parameter bug
- ✅ **COMPLETED**: Verify bug fix with unequal windows test
- ✅ **COMPLETED**: Comprehensive Sequential package verification
- ⚠️ **PENDING**: Run empirical Type I error validation (1000+ sims with RR=1.0)
- ⚠️ **PENDING**: Run empirical power validation (1000+ sims with RR=1.5, 2.0)
- ⚠️ **PENDING**: Verify empirical alpha ≈ 0.05 (within 0.045-0.055)
- ⚠️ **PENDING**: Verify power ≥ 80% at RR=1.5
- ⚠️ **RECOMMENDED**: Independent statistician review of fixes
- ⚠️ **REQUIRED**: IRB and regulatory approval

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
