# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Project Overview

SeqVaccineSafety is an R project for vaccine safety surveillance using Self-Controlled Risk Interval (SCRI) designs with sequential monitoring. Target population: adults aged 65+ years.

**Key Features:**
- Configuration-driven architecture (all parameters in `config.yaml`)
- Complete workflow: simulate → analyze → visualize
- Uses Sequential R package for exact methods

## Quick Reference

### Project Structure
- `config.yaml` - Single source of truth for all parameters
- `simulate_scri_dataset.R` - Generate SCRI data
- `sequential_surveillance.R` - Perform sequential analysis
- `README.md` - Complete documentation

### Standard Workflow
```r
source("simulate_scri_dataset.R")      # Generate data
source("sequential_surveillance.R")     # Analyze and visualize
```

## Key Technical Details

### Configuration
- **Never hard-code parameters** - Everything in `config.yaml`
- All scripts load with: `cfg <- config::get(file = "config.yaml")`

### SCRI Design
- **Risk window**: Post-vaccination period (e.g., days 1-28)
- **Control window**: Baseline period (e.g., days 29-56)
- Each person is their own control
- Case-only design (only individuals with events)

### Sequential Analysis
- Uses Sequential R package (Kulldorff & Silva)
- MaxSPRT with Wald alpha spending
- Exact methods, not approximations
- Key parameters:
  - `zp_ratio = control_length / risk_length` (critical!)
  - `alpha` = overall Type I error
  - `N` = max sample size

### Statistical Rigor
**Critical corrections completed:**
- ✅ z parameter bug fixed (handles unequal windows correctly)
- ✅ Rate ratio calculation (not odds ratio)
- ✅ Sequential-adjusted confidence intervals
- ✅ Symmetric continuity correction for zero cells

**Key function:** `Analyze.Binomial(name, test, z=zp_ratio, cases, controls)`
- The `z` parameter MUST equal `zp_ratio` from setup
- This was a critical bug fixed in Oct 2025

## Code Style

### R Scripts
- 2 spaces for indentation
- UTF-8 encoding
- Keep comments concise
- Use configuration parameters, never hard-code

### When Making Changes
1. **Configuration**: Only modify `config.yaml`, not R scripts
2. **Statistical code**: Be very careful with Sequential package parameters
3. **Testing**: Run test scripts after changes (`test_unequal_windows.R`)
4. **Documentation**: Update README.md if adding features

## Common Tasks

### Change Analysis Parameters
Edit `config.yaml`:
```yaml
sequential_analysis:
  overall_alpha: 0.01      # More conservative
  number_of_looks: 4       # Fewer looks
```

### Modify Window Definitions
```yaml
scri_design:
  risk_window: {start_day: 1, end_day: 7}
  control_window: {start_day: 8, end_day: 14}
```

## Important Warnings

### Statistical Code
- **Do not modify** Sequential package function calls without statistical review
- **Always preserve** the `z=zp_ratio` parameter in `Analyze.Binomial()`
- **Do not change** rate ratio calculations
- **Test thoroughly** if modifying window calculations

### Configuration
- Risk and control windows should match in length
- Minimum cases per look should be reasonable (20-50)
- Random seed can be null for non-reproducible generation

## File Locations

### Key Scripts
- Main scripts: Project root (`.R` files)
- Configuration: `config.yaml`
- Generated data: `scri_data_*.csv`, `scri_simulation.RData`
- Outputs: `surveillance_outputs/`

### Documentation
- **README.md** - Complete user documentation (consolidated)
- **CLAUDE.md** - This file (AI context)

## Status

**Production-ready** for research and education. All critical bugs fixed and verified.

For complete documentation, see README.md.
