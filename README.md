# SeqVaccineSafety

Sequential vaccine safety surveillance using Self-Controlled Risk Interval (SCRI) designs with real-time monitoring.

[![R](https://img.shields.io/badge/R-%3E%3D%204.0-blue.svg)](https://www.r-project.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen.svg)](#status)

---

## Overview

SeqVaccineSafety provides an end-to-end workflow for vaccine safety surveillance in adults aged 65+. The system uses:

- **SCRI Design**: Self-Controlled Risk Interval (each person is their own control)
- **Sequential Monitoring**: MaxSPRT for early signal detection
- **Exact Methods**: Sequential R package (CDC-validated)
- **Interactive Dashboard**: Real-time parameter adjustment and visualization

**Key Features:**
- Configuration-driven (all parameters in `config.yaml`)
- Complete workflow: simulate → analyze → visualize
- Interactive Shiny dashboard
- Publication-ready outputs
- Built-in validation utilities

---

## Quick Start

### Install and Launch Dashboard

```r
source("launch_dashboard.R")
```

This auto-installs dependencies and opens an interactive dashboard where you can explore the analysis in real-time.

### Run Complete Workflow

```r
# 1. Generate simulated data
source("simulate_scri_dataset.R")

# 2. Perform sequential surveillance
source("sequential_surveillance.R")

# 3. Launch dashboard
source("launch_dashboard.R")
```

---

## Installation

### Prerequisites
- R ≥ 4.0
- RStudio (recommended)

### Manual Package Installation

```r
install.packages(c("config", "ggplot2", "shiny", "shinydashboard",
                   "plotly", "DT", "fresh", "Sequential", "SequentialDesign"))
```

**Note**: All scripts auto-install missing packages.

---

## Usage

### Basic Workflow

1. **Configure** - Edit `config.yaml` to set your parameters:
   ```yaml
   simulation:
     population_size: 20000
     true_relative_risk: 1.5

   scri_design:
     risk_window: {start_day: 1, end_day: 28}
     control_window: {start_day: 29, end_day: 56}

   sequential_analysis:
     overall_alpha: 0.05
     number_of_looks: 8
   ```

2. **Simulate** - Generate SCRI dataset:
   ```r
   source("simulate_scri_dataset.R")
   ```
   Creates: `scri_data_wide.csv`, `scri_simulation.RData`

3. **Analyze** - Run sequential surveillance:
   ```r
   source("sequential_surveillance.R")
   ```
   Generates outputs in `surveillance_outputs/`

4. **Visualize** - Launch interactive dashboard:
   ```r
   source("launch_dashboard.R")
   ```

### Interactive Dashboard

The dashboard provides:
- **Real-time parameter adjustment** (alpha, windows, looks)
- **Visual signal detection** (color-coded alerts)
- **Interactive plots** (zoom, pan, hover)
- **Automated recommendations**
- **Exportable results**

**Controls:**
- Alpha: 0.01 to 0.10
- Number of looks: 4 to 12
- Risk/control windows: Customizable
- Minimum cases: 10 to 50

### Configuration Profiles

Three pre-configured scenarios:

```r
# Standard (default)
cfg <- config::get()

# Conservative (stricter)
cfg <- config::get(config = "conservative")

# Acute events (7-day risk window)
cfg <- config::get(config = "acute_events")
```

---

## Configuration Guide

All parameters managed through `config.yaml`:

### Key Configuration Sections

**Simulation Settings**
```yaml
simulation:
  population_size: 20000              # Vaccinated individuals
  random_seed: 12345                  # For reproducibility
  baseline_event_rate: 0.0002         # Events per person-day
  true_relative_risk: 1.5             # Simulated RR
```

**SCRI Design**
```yaml
scri_design:
  risk_window:                        # Post-vaccination monitoring
    start_day: 1
    end_day: 28
  control_window:                     # Baseline comparison
    start_day: 29
    end_day: 56                       # Match risk window length
```

**Sequential Analysis**
```yaml
sequential_analysis:
  overall_alpha: 0.05                 # Type I error rate
  number_of_looks: 8                  # Interim analyses
  look_interval_days: 14              # Days between looks
  minimum_cases_per_look: 20          # Min sample size
  stop_on_signal: true                # Stop when detected
```

**Dashboard Settings**
```yaml
dashboard:
  defaults:
    alpha: 0.05
    number_of_looks: 8
  alert_thresholds:
    relative_risk:
      warning: 1.5
      critical: 2.0
```

### Common Configurations

**Conservative Analysis**
```yaml
sequential_analysis:
  overall_alpha: 0.01      # More stringent
  number_of_looks: 4       # Fewer looks
  minimum_cases_per_look: 30
```

**Acute Event Detection**
```yaml
scri_design:
  risk_window: {start_day: 1, end_day: 7}
  control_window: {start_day: 8, end_day: 14}

sequential_analysis:
  look_interval_days: 7
```

---

## Project Structure

```
SeqVaccineSafety/
├── config.yaml                      # Configuration (single source of truth)
├── Main Scripts/
│   ├── simulate_scri_dataset.R      # Data generation
│   ├── sequential_surveillance.R    # Sequential analysis
│   ├── dashboard_app.R              # Shiny dashboard
│   └── launch_dashboard.R           # Dashboard launcher
├── Validation/
│   ├── validate_surveillance.R      # Type I error/power validation
│   ├── calculate_sample_size.R     # Sample size calculator
│   └── test_unequal_windows.R      # Window testing
├── Generated Data/
│   ├── scri_data_wide.csv           # One row per case
│   └── scri_simulation.RData        # R workspace
└── surveillance_outputs/            # Analysis results
```

---

## Methodology

### SCRI Design

**Self-Controlled Risk Interval**:
- Each person serves as their own control
- Case-only design (only individuals with events)
- Compares event rates: risk window vs. control window
- Controls for time-invariant confounders

**Relative Risk Calculation**:
```
RR = (events_risk / risk_days) / (events_control / control_days)
```
- Properly accounts for unequal window lengths
- Continuity correction for zero cells
- Sequential-adjusted confidence intervals

### Sequential Analysis

**Method**: MaxSPRT (Maximized Sequential Probability Ratio Test)
- **Package**: Sequential R package (Kulldorff & Silva)
- **Test**: Binomial test with Wald alpha spending
- **Null hypothesis**: Events distributed proportional to person-time
- **Signal detection**: Test statistic exceeds critical boundary

**Key Features**:
- Exact methods (not approximations)
- Controls Type I error across multiple looks
- Early stopping for safety signals
- Sequential-adjusted confidence intervals

### Statistical Rigor

✅ **Validated Components**:
- Correct rate ratio calculation
- Proper null hypothesis for unequal windows
- Sequential package parameters verified
- Zero cell handling with continuity correction
- Unequal window support

✅ **Recent Fixes** (Oct 2025):
- Critical z parameter bug fixed
- Sequential-adjusted CIs implemented
- Symmetric continuity correction added
- Comprehensive verification completed

---

## Validation

### Type I Error and Power Validation

To validate the surveillance system:

```yaml
# config.yaml
simulation:
  method: "sequential_design"
  sequential_design:
    n_simulations: 1000
```

```r
source("validate_surveillance.R")  # Runtime: 30-90 min
```

Runs three scenarios:
- **RR=1.0**: Type I error rate (should ≈ alpha)
- **RR=1.5**: Power for moderate effect
- **RR=2.0**: Power for strong effect

Results saved to `surveillance_outputs/validation_results/`

### Sample Size Calculation

```r
source("calculate_sample_size.R")
```

Calculates required cases for target power:
- Accounts for sequential inflation
- Adjusts for number of looks
- Provides operational estimates

---

## Outputs

### Generated Files

**Data Files**:
- `scri_data_wide.csv` - One row per case
- `scri_simulation.RData` - R workspace

**Analysis Results** (`surveillance_outputs/`):
- `sequential_monitoring_results.csv` - All sequential looks
- `current_status_report.txt` - Summary report
- `sequential_monitoring_plot.png` - Test statistics and boundaries
- `cases_timeline.png` - Cumulative cases over time
- `dashboard_alerts.csv` - Alert metrics

### Interpreting Results

**No Signal**:
- RR near 1.0 (no elevated risk)
- P-value > alpha (not significant)
- Action: Continue surveillance

**Signal Detected**:
- RR > 1.5 (elevated risk)
- P-value < alpha (significant)
- Action: Immediate investigation
- Review: Case details, stratified analysis, clinical significance

---

## Status

**Current Status**: Production-ready for research and education

✅ **Completed**:
- Core functionality working
- Critical bugs fixed and verified
- Comprehensive code review
- Statistical methods validated
- Documentation complete

🔄 **Optional**:
- Empirical validation (1000+ simulations)
- Independent statistical review
- Regulatory approval (for clinical deployment)

**Recommended For**:
- ✅ Educational use and teaching
- ✅ Research publications
- ✅ Methods development
- ✅ Preliminary analyses
- ⚠️ Clinical deployment (after full validation)

---

## Tips and Best Practices

### Configuration
1. Always match risk and control window lengths
2. Set `random_seed` for reproducible simulations
3. Use configuration profiles for common scenarios
4. Test parameter changes in dashboard first

### Analysis
1. Ensure minimum cases threshold is reasonable (20-50)
2. More looks = more frequent monitoring but lower power per look
3. Review sequential-adjusted CIs (account for multiple testing)
4. Consider alpha=0.01 for more conservative monitoring

### Dashboard
1. Use interactive plots to explore results
2. Test different window definitions
3. Compare alpha levels (0.05 vs 0.01)
4. Export visualizations for presentations

---

## Troubleshooting

**"File not found" errors**
- Run `simulate_scri_dataset.R` first to generate data

**Dashboard won't load**
- Check R version ≥ 4.0
- Run `launch_dashboard.R` which auto-installs packages

**No signal detected with high RR**
- Increase population size or baseline rate
- Check window definitions
- Verify minimum cases threshold

**Results seem incorrect**
- Verify windows don't overlap
- Ensure risk/control windows match in length
- Check `config.yaml` for typos

---

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Submit pull request with clear description

---

## License

MIT License - see LICENSE file for details

---

## References

**Packages**:
- Sequential: Kulldorff & Silva (CDC Vaccine Safety Datalink)
- SequentialDesign: Maro & Hou (FDA Sentinel Initiative)

**Methods**:
- SCRI Design: Self-controlled risk interval methodology
- MaxSPRT: Maximized Sequential Probability Ratio Test
- Wald Alpha Spending: Optimal alpha spending function

---

## Contact

For questions or issues, please open a GitHub issue.

**Repository**: [SeqVaccineSafety](https://github.com/HviidLab/SeqVaccineSafety)
