# Configuration Guide for SeqVaccineSafety

## Overview

The SeqVaccineSafety project uses a centralized configuration file (`config.yaml`) to manage all analysis parameters and settings. This eliminates hard-coded values and ensures consistency across all scripts.

## Quick Start

### 1. Using Default Configuration

All scripts automatically load settings from `config.yaml`:

```r
# Just run the scripts - no changes needed!
source("simulate_scri_dataset.R")
source("sequential_surveillance.R")
source("launch_dashboard.R")
```

### 2. Modifying Parameters

Edit `config.yaml` to change any setting. For example, to use a more conservative alpha:

```yaml
sequential_analysis:
  overall_alpha: 0.01  # Changed from 0.05
```

All scripts will automatically use the new value.

## Configuration File Structure

### Simulation Settings

Control how data is generated:

```yaml
simulation:
  population_size: 20000           # Number of vaccinated individuals
  random_seed: 12345               # For reproducibility
  baseline_event_rate: 0.0002      # Background event rate per person-day
  true_relative_risk: 1.5          # Simulated RR in risk window
```

**Tip**: Change `random_seed` to generate different random datasets, or set to `null` for non-reproducible random generation.

### SCRI Design Parameters

Define risk and control windows:

```yaml
scri_design:
  risk_window:
    start_day: 1      # First day post-vaccination
    end_day: 28       # Last day (e.g., 28 = 4 weeks)

  control_window:
    start_day: 29     # Typically starts after risk window
    end_day: 56       # Should match risk window length
```

**Common window configurations**:
- **Acute events**: Risk 1-7, Control 8-14
- **Short-term**: Risk 1-14, Control 15-28
- **Standard**: Risk 1-28, Control 29-56 (default)
- **Long-term**: Risk 1-42, Control 43-84

### Sequential Analysis Parameters

Control statistical monitoring:

```yaml
sequential_analysis:
  overall_alpha: 0.05                    # Type I error rate (5%)
  number_of_looks: 8                     # How many interim analyses
  look_interval_days: 14                 # Days between looks
  minimum_cases_per_look: 20             # Minimum sample size
  boundary_method: "pocock"              # Alpha spending method
  stop_on_signal: true                   # Stop when signal detected
```

**Alpha spending methods**:
- `pocock`: Equal alpha per look (currently implemented)
- `obrien-fleming`: Conservative early, liberal late (future)
- `haybittle-peto`: Very strict early stopping (future)

### Dashboard Settings

Configure the interactive Shiny dashboard:

```yaml
dashboard:
  defaults:
    alpha: 0.05
    number_of_looks: 8
    # ... sets default slider values

  ranges:
    alpha:
      min: 0.01
      max: 0.10
      step: 0.01
    # ... defines slider ranges

  alert_thresholds:
    relative_risk:
      warning: 1.5      # RR > 1.5 triggers orange
      critical: 2.0     # RR > 2.0 triggers red
```

**Tip**: Adjust `alert_thresholds` to match your public health action criteria.

### Output Settings

Control file generation and formatting:

```yaml
output:
  directory: "surveillance_outputs"      # Where to save results
  timestamp_files: false                 # Add timestamps to filenames

  plots:
    dpi: 120                              # Resolution (120 standard, 300 high-quality)
    monitoring_plot:
      width: 10                           # Inches
      height: 8
      format: "png"

  reports:
    decimal_places:
      proportions: 3                      # Round to 3 decimals
      relative_risk: 2
      z_statistic: 3
      p_value: 4
```

## Common Use Cases

### Scenario 1: More Conservative Analysis

```yaml
sequential_analysis:
  overall_alpha: 0.01      # Stricter than default 0.05
  number_of_looks: 4       # Fewer looks, larger alpha per look
```

**Effect**: Reduces false positives but requires stronger evidence for signal.

### Scenario 2: High-Frequency Monitoring

```yaml
sequential_analysis:
  number_of_looks: 12           # More frequent checks
  look_interval_days: 7         # Weekly instead of biweekly
  minimum_cases_per_look: 15    # Lower threshold
```

**Effect**: Detect signals faster, but smaller alpha per look (0.05/12 = 0.0042).

### Scenario 3: Focus on Acute Events

```yaml
scri_design:
  risk_window:
    start_day: 1
    end_day: 7        # First week only
  control_window:
    start_day: 8
    end_day: 14       # Match length
```

**Effect**: Targets immediate post-vaccination events (e.g., anaphylaxis).

### Scenario 4: Larger Simulation for Power

```yaml
simulation:
  population_size: 50000        # Larger than default 20,000
  true_relative_risk: 1.2       # Smaller effect size
```

**Effect**: Better power to detect subtle safety signals.

### Scenario 5: Publication-Quality Outputs

```yaml
output:
  plots:
    dpi: 300                    # High resolution
    format: "pdf"               # Vector graphics

  reports:
    include_session_info: true  # For reproducibility
```

**Effect**: Professional outputs ready for manuscripts.

## Advanced: Multiple Configurations

Create scenario-specific config files:

### config_conservative.yaml
```yaml
default:
  sequential_analysis:
    overall_alpha: 0.01
    number_of_looks: 4
```

### config_acute.yaml
```yaml
default:
  scri_design:
    risk_window: {start_day: 1, end_day: 7}
    control_window: {start_day: 8, end_day: 14}
```

Load specific config in R:

```r
# In any script, replace:
cfg <- config::get()

# With:
cfg <- config::get(file = "config_conservative.yaml")
```

## Parameters Reference

### Complete List

| Section | Parameter | Default | Description |
|---------|-----------|---------|-------------|
| **simulation** | population_size | 20000 | Number of vaccinated individuals |
| | random_seed | 12345 | Reproducibility seed |
| | baseline_event_rate | 0.0002 | Background rate per person-day |
| | true_relative_risk | 1.5 | Simulated RR in risk window |
| **scri_design** | risk_window.start_day | 1 | Risk window start |
| | risk_window.end_day | 28 | Risk window end |
| | control_window.start_day | 29 | Control window start |
| | control_window.end_day | 56 | Control window end |
| **sequential_analysis** | overall_alpha | 0.05 | Type I error rate |
| | number_of_looks | 8 | Interim analyses count |
| | look_interval_days | 14 | Days between looks |
| | minimum_cases_per_look | 20 | Minimum sample size |
| **dashboard.defaults** | alpha | 0.05 | Dashboard default alpha |
| | number_of_looks | 8 | Dashboard default looks |
| **dashboard.alert_thresholds** | relative_risk.warning | 1.5 | Orange threshold |
| | relative_risk.critical | 2.0 | Red threshold |
| **output** | directory | "surveillance_outputs" | Output folder |
| | plots.dpi | 120 | Plot resolution |

## Validation

The config system includes automatic validation:

```yaml
validation:
  check_duplicate_ids: true      # Warn on duplicate patient IDs
  check_date_consistency: true   # Ensure event after vaccination
  check_window_calculations: true # Verify days_to_event math
  strict_mode: false             # false = warnings, true = errors
```

## Troubleshooting

### Error: "config.yaml not found"

**Solution**: Ensure `config.yaml` is in your working directory (project root).

```r
getwd()  # Check current directory
setwd("C:/path/to/SeqVaccineSafety")  # Set if needed
```

### Error: "object 'cfg' not found"

**Solution**: The config package isn't loaded. This should be automatic, but you can manually load:

```r
library(config)
cfg <- config::get()
```

### Warning: Age distribution doesn't sum to 1.0

**Solution**: Check your age distribution settings:

```yaml
simulation:
  age_distribution:
    age_65_74: 0.60
    age_75_84: 0.30
    age_85_plus: 0.10  # These must sum to 1.0
```

### Results different after editing config

**Solution**: This is expected! If you changed parameters like `random_seed` or `true_relative_risk`, results will differ. Re-run all scripts:

```r
source("simulate_scri_dataset.R")  # Regenerate data with new settings
source("sequential_surveillance.R")  # Re-analyze
```

## Best Practices

### 1. Version Control Your Config

Commit `config.yaml` to git to track parameter changes:

```bash
git add config.yaml
git commit -m "Changed alpha to 0.01 for conservative analysis"
```

### 2. Document Major Changes

Add comments in the YAML file:

```yaml
sequential_analysis:
  overall_alpha: 0.01
    # Changed from 0.05 on 2024-10-25 per regulatory request
```

### 3. Test Before Production

Create a test config with smaller samples:

```yaml
simulation:
  population_size: 1000  # Quick test run
```

Then restore for full analysis.

### 4. Match Window Lengths

For valid SCRI analysis, keep windows equal length:

```yaml
scri_design:
  risk_window: {start_day: 1, end_day: 28}     # 28 days
  control_window: {start_day: 29, end_day: 56}  # 28 days ✓
```

### 5. Reproducibility Documentation

When publishing results, include your exact `config.yaml`:

> "Analysis parameters are available in config.yaml (commit abc123) at github.com/yourname/SeqVaccineSafety"

## Migration from Hard-Coded Values

If you have old scripts with hard-coded parameters, they've been replaced:

| Old Code | New Config Path |
|----------|----------------|
| `n_patients <- 20000` | `cfg$simulation$population_size` |
| `alpha <- 0.05` | `cfg$sequential_analysis$overall_alpha` |
| `risk_window_end <- 28` | `cfg$scri_design$risk_window$end_day` |
| `min_cases_per_look <- 20` | `cfg$sequential_analysis$minimum_cases_per_look` |

All scripts now automatically use config values.

## Support

For questions or issues with configuration:

1. Check this guide
2. Review `config.yaml` comments
3. See main project documentation (CLAUDE.md, DASHBOARD_README.md)
4. Open an issue on GitHub

---

**Last Updated**: 2025-10-25
**Config Version**: 1.0.0
