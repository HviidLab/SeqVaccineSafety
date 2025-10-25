# Sequential Vaccine Safety Surveillance Dashboard

An interactive R Shiny dashboard for real-time monitoring of vaccine safety using Self-Controlled Risk Interval (SCRI) design with sequential statistical methods.

## Features

### 📊 Interactive Visualizations
- **Sequential Monitoring Plot**: Test statistics vs. critical boundaries over time
- **Relative Risk Trends**: Track observed RR across sequential looks
- **Cumulative Timeline**: Cases and events accumulation over time
- **All plots are interactive** (zoom, pan, hover for details)

### ⚙️ Configurable Parameters
Adjust surveillance parameters in real-time:
- **Overall Alpha**: Type I error rate (0.01 - 0.10)
- **Number of Looks**: Sequential analysis frequency (4 - 12)
- **Risk Window**: Days post-vaccination to monitor (customizable)
- **Control Window**: Comparison period (customizable)
- **Minimum Cases**: Threshold for analysis (10 - 50)

### 🚨 Real-Time Alerts
- **Color-coded status banner**: Instant signal detection feedback
- **Animated alerts**: Eye-catching visual warnings when signal detected
- **Value boxes**: Key metrics at a glance (cases, RR, p-value, signal status)

### 📋 Decision Support
- **Automated recommendations**: Context-specific guidance for public health officials
- **Detailed action items**: Step-by-step investigation protocols
- **Risk communication**: Ready-to-use summaries for stakeholders

### 📑 Data Export Ready
- **Interactive tables**: Sortable, filterable results
- **Professional formatting**: Publication-ready visualizations
- **Copy/export**: All charts can be downloaded

## Getting Started

### Prerequisites
- R (version 4.0 or higher)
- RStudio (recommended)

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/HviidLab/SeqVaccineSafety.git
   cd SeqVaccineSafety
   ```

2. **Generate sample data** (if not already present):
   ```r
   source("simulate_scri_dataset.R")
   ```

3. **Launch the dashboard**:
   ```r
   source("launch_dashboard.R")
   ```

   Or directly:
   ```r
   shiny::runApp("dashboard_app.R")
   ```

### First Use

When you first launch the dashboard:
1. The sidebar shows default parameters (alpha=0.05, 8 looks, etc.)
2. Click **"Run Analysis"** button to perform initial analysis
3. Explore the interactive charts and results
4. Adjust parameters and re-run to see how results change

## Dashboard Layout

### Sidebar (Left)
- **Navigation**: Dashboard / About tabs
- **Parameters**: Interactive sliders and inputs
- **Run Button**: Execute analysis with current settings
- **Data Info**: Summary of loaded dataset

### Main Panel (Right)

#### 1. Alert Banner
- 🔴 **Red (SIGNAL)**: Safety signal detected - immediate action needed
- 🟢 **Green (NO SIGNAL)**: Continue routine monitoring

#### 2. Key Metrics Row
Four value boxes showing:
- **Total Cases**: Number of cases analyzed at latest look
- **Relative Risk**: Observed RR (color-coded by severity)
- **P-value**: Statistical significance
- **Signal Status**: YES/NO

#### 3. Sequential Monitoring Plot
Interactive time-series showing:
- Blue line: Z-statistic trajectory
- Red dashed line: Critical boundary (Pocock)
- Signal markers: Where threshold was crossed

#### 4. Additional Charts
- **RR Over Time**: Trend in relative risk estimates
- **Cases Timeline**: Cumulative data accrual

#### 5. Results Table
Detailed look-by-look analysis results:
- Date, cases analyzed
- Events in risk/control windows
- Statistical test results
- Signal status (color-coded)

#### 6. Recommendations Panel
Context-aware guidance:
- **Signal detected**: Detailed investigation protocol
- **No signal**: Routine monitoring guidance

## Use Cases

### Scenario 1: Routine Monitoring
Default parameters detect signal at Look 4:
- 183 cases analyzed
- RR = 1.47
- P-value = 0.0048
- **Result**: Signal detected, investigation recommended

### Scenario 2: Stricter Monitoring
Adjust alpha to 0.01 (more conservative):
- Requires stronger evidence for signal
- May need more cases before detection
- Reduces false positives

### Scenario 3: Flexible Windows
Modify risk window to days 1-14 (acute events):
- Tests for immediate post-vaccination effects
- Control window adjusted accordingly
- Recomputes all statistics

### Scenario 4: More Frequent Looks
Increase to 12 looks:
- More frequent monitoring
- Smaller alpha per look
- Earlier detection possible (with trade-offs)

## Interpretation Guide

### When Signal is Detected (🔴)

**What it means**:
- Statistical evidence of elevated risk in post-vaccination period
- Threshold for public health action has been crossed

**What to do**:
1. Review all cases in detail (medical records)
2. Stratify by demographics and comorbidities
3. Convene clinical expert panel
4. Notify regulatory authorities
5. Prepare risk communications
6. Conduct risk-benefit assessment

**Important caveats**:
- Signal ≠ proven causation
- May be due to chance, bias, or confounding
- Clinical review is essential

### When No Signal (🟢)

**What it means**:
- No statistical evidence of elevated risk detected
- Continue monitoring as planned

**What to do**:
- Maintain surveillance schedule
- Monitor trends in RR
- Ensure data quality
- Prepare for next look

## Technical Details

### Statistical Method
- **Design**: Self-Controlled Risk Interval (SCRI)
- **Test**: Binomial test of proportions
- **Null Hypothesis**: Equal risk in both windows (p = 0.5)
- **Alpha Spending**: Pocock boundaries (equal alpha per look)
- **Test Statistic**: Z = (p̂ - 0.5) / SE(p̂)

### Data Requirements
The dashboard expects `scri_data_wide.csv` with columns:
- `patient_id`
- `event_in_risk_window` (0/1)
- `control_window_end` (Date)
- `vaccination_date` (Date)
- `event_date` (Date)
- `days_to_event` (numeric)

## Customization

### Connecting to Live Data
Replace the file loading in `dashboard_app.R`:
```r
cases_wide <- reactive({
  # Replace with database query or API call
  data <- read.csv("scri_data_wide.csv", stringsAsFactors = FALSE)
  # ... rest of code
})
```

### Styling
Modify CSS in the `tags$head()` section of `ui` to match your organization's branding.

### Additional Tabs
Add new `tabItem()` elements in the `tabItems()` section for extra functionality.

## Troubleshooting

### Dashboard won't launch
- Check all required packages are installed
- Verify `scri_data_wide.csv` exists in working directory
- Check R console for error messages

### No results after clicking "Run Analysis"
- Ensure minimum cases threshold is not too high
- Check that data has enough observations
- Verify date columns are properly formatted

### Plots not displaying
- Update `plotly` package: `install.packages("plotly")`
- Clear browser cache
- Try different browser

## Contributing

This dashboard is part of the SeqVaccineSafety project. To contribute:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## Citation

If you use this dashboard in your work, please cite:
```
HviidLab SeqVaccineSafety Dashboard
https://github.com/HviidLab/SeqVaccineSafety
```

## License

This project is open source. See repository for license details.

## Contact

For questions or issues:
- Open an issue on GitHub
- See repository documentation

---

**Built with**: R Shiny, Plotly, DT, shinydashboard

**Last Updated**: October 2025
