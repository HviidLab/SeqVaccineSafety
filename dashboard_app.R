# Influenza Vaccine Safety Sequential Surveillance Dashboard
# Interactive Shiny application for public health monitoring

# Set CRAN mirror
options(repos = c(CRAN = "https://cloud.r-project.org"))

# Install and load required packages
required_packages <- c("config", "shiny", "shinydashboard", "ggplot2", "plotly", "DT", "fresh", "Sequential")

for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    cat(sprintf("Installing %s...\n", pkg))
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}

# ============================================================================
# LOAD CONFIGURATION
# ============================================================================

cat("Loading configuration from config.yaml...\n")
cfg <- config::get(file = "config.yaml")

# ============================================================================
# UI DEFINITION
# ============================================================================

ui <- dashboardPage(
  skin = "blue",

  # Header
  dashboardHeader(
    title = "Vaccine Safety Surveillance",
    titleWidth = 350,
    tags$li(class = "dropdown",
            tags$style(HTML("
              .main-header .logo { font-weight: bold; font-size: 20px; }
              .main-header { background-color: #2c3e50; }
            ")))
  ),

  # Sidebar
  dashboardSidebar(
    width = 350,
    sidebarMenu(
      menuItem("Dashboard", tabName = "dashboard", icon = icon("dashboard")),
      menuItem("About", tabName = "about", icon = icon("info-circle"))
    ),

    hr(),
    h4("Surveillance Parameters", style = "padding-left: 15px; color: white;"),

    sliderInput("alpha",
                "Overall Alpha (Type I Error):",
                min = cfg$dashboard$ranges$alpha$min,
                max = cfg$dashboard$ranges$alpha$max,
                value = cfg$dashboard$defaults$alpha,
                step = cfg$dashboard$ranges$alpha$step),

    sliderInput("n_looks",
                "Number of Sequential Looks:",
                min = cfg$dashboard$ranges$number_of_looks$min,
                max = cfg$dashboard$ranges$number_of_looks$max,
                value = cfg$dashboard$defaults$number_of_looks,
                step = cfg$dashboard$ranges$number_of_looks$step),

    sliderInput("risk_window",
                "Risk Window (Days Post-Vaccination):",
                min = cfg$dashboard$ranges$risk_window_days$min,
                max = cfg$dashboard$ranges$risk_window_days$max,
                value = c(cfg$dashboard$defaults$risk_window_start,
                         cfg$dashboard$defaults$risk_window_end)),

    sliderInput("control_window",
                "Control Window (Days Post-Vaccination):",
                min = cfg$dashboard$ranges$control_window_days$min,
                max = cfg$dashboard$ranges$control_window_days$max,
                value = c(cfg$dashboard$defaults$control_window_start,
                         cfg$dashboard$defaults$control_window_end)),

    sliderInput("min_cases",
                "Minimum Cases Per Look:",
                min = cfg$dashboard$ranges$minimum_cases$min,
                max = cfg$dashboard$ranges$minimum_cases$max,
                value = cfg$dashboard$defaults$minimum_cases,
                step = cfg$dashboard$ranges$minimum_cases$step),

    hr(),

    actionButton("run_analysis", "Run Analysis",
                 icon = icon("play"),
                 class = "btn-primary btn-lg",
                 style = "width: 90%; margin-left: 5%;"),

    br(), br(),

    div(style = "padding: 15px; background-color: #34495e; border-radius: 5px; margin: 10px;",
        h5("Data Source:", style = "color: white; margin-top: 0;"),
        p("Simulated SCRI data", style = "color: #bdc3c7; font-size: 12px;"),
        p(textOutput("data_info"), style = "color: #ecf0f1; font-size: 11px;")
    )
  ),

  # Main Body
  dashboardBody(

    # Custom CSS
    tags$head(
      tags$style(HTML("
        @import url('https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;700&display=swap');

        body, .content-wrapper, .main-sidebar, .sidebar {
          font-family: 'Roboto', sans-serif;
        }

        .value-box-custom {
          border-radius: 8px;
          box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }

        .signal-alert {
          background: linear-gradient(135deg, #e74c3c 0%, #c0392b 100%);
          color: white;
          padding: 20px;
          border-radius: 8px;
          margin-bottom: 20px;
          box-shadow: 0 4px 6px rgba(0,0,0,0.1);
          animation: pulse 2s infinite;
        }

        .no-signal {
          background: linear-gradient(135deg, #27ae60 0%, #229954 100%);
          color: white;
          padding: 20px;
          border-radius: 8px;
          margin-bottom: 20px;
          box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }

        @keyframes pulse {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.85; }
        }

        .info-box {
          border-radius: 8px;
          box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }

        .box {
          border-radius: 8px;
          box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }

        .small-box {
          border-radius: 8px;
        }

        .recommendation-box {
          background-color: #f8f9fa;
          border-left: 4px solid #3498db;
          padding: 15px;
          margin: 10px 0;
          border-radius: 4px;
        }

        .metric-label {
          font-size: 14px;
          color: #7f8c8d;
          font-weight: 300;
        }

        .metric-value {
          font-size: 32px;
          font-weight: 700;
          color: #2c3e50;
        }
      "))
    ),

    tabItems(
      # Dashboard Tab
      tabItem(tabName = "dashboard",

        # Alert Banner
        uiOutput("alert_banner"),

        # Key Metrics Row
        fluidRow(
          valueBoxOutput("total_cases_box", width = 3),
          valueBoxOutput("rr_box", width = 3),
          valueBoxOutput("pvalue_box", width = 3),
          valueBoxOutput("signal_box", width = 3)
        ),

        # Charts Row
        fluidRow(
          box(
            title = "Sequential Monitoring: Test Statistics",
            status = "primary",
            solidHeader = TRUE,
            width = 12,
            plotlyOutput("monitoring_plot", height = "400px")
          )
        ),

        fluidRow(
          box(
            title = "Relative Risk Over Time",
            status = "info",
            solidHeader = TRUE,
            width = 6,
            plotlyOutput("rr_plot", height = "350px")
          ),

          box(
            title = "Cumulative Cases Timeline",
            status = "info",
            solidHeader = TRUE,
            width = 6,
            plotlyOutput("timeline_plot", height = "350px")
          )
        ),

        # Results Table
        fluidRow(
          box(
            title = "Sequential Analysis Results",
            status = "primary",
            solidHeader = TRUE,
            width = 12,
            DT::dataTableOutput("results_table")
          )
        ),

        # Recommendations
        fluidRow(
          box(
            title = "Recommendations for Public Health Action",
            status = "warning",
            solidHeader = TRUE,
            width = 12,
            uiOutput("recommendations")
          )
        )
      ),

      # About Tab
      tabItem(tabName = "about",
        fluidRow(
          box(
            title = "About This Dashboard",
            status = "primary",
            solidHeader = TRUE,
            width = 12,
            h3("Influenza Vaccine Safety Sequential Surveillance"),
            p("This dashboard implements a Self-Controlled Risk Interval (SCRI) design with sequential monitoring for detecting vaccine safety signals in near-real-time."),

            h4("Methodology"),
            tags$ul(
              tags$li("Design: SCRI (Self-Controlled Risk Interval)"),
              tags$li("Population: Adults aged 65+ years"),
              tags$li("Sequential Method: Exact sequential analysis using the Sequential R package"),
              tags$li("Alpha Spending: Wald alpha spending function"),
              tags$li("Test: Binomial test (MaxSPRT) comparing risk vs control window events")
            ),

            h4("How It Works"),
            tags$ol(
              tags$li("Cases (individuals with adverse events) are identified"),
              tags$li("Each case's event is classified as occurring in the risk window (days 1-28) or control window (days 29-56) post-vaccination"),
              tags$li("Sequential looks are performed at regular intervals"),
              tags$li("At each look, a statistical test compares the proportion of events in risk vs control windows"),
              tags$li("If the test statistic exceeds the critical boundary, a safety signal is detected")
            ),

            h4("Interpretation"),
            tags$ul(
              tags$li(strong("No Signal:"), " Continue routine surveillance"),
              tags$li(strong("Signal Detected:"), " Immediate investigation recommended"),
              tags$li(strong("Relative Risk > 1:"), " More events in risk window than control window"),
              tags$li(strong("P-value < Alpha:"), " Result is statistically significant")
            ),

            h4("Data Source"),
            p("This dashboard uses simulated data generated from the SCRI simulation script. In production, this would connect to live surveillance data."),

            h4("Repository"),
            p(a("GitHub: HviidLab/SeqVaccineSafety",
                href = "https://github.com/HviidLab/SeqVaccineSafety",
                target = "_blank"))
          )
        )
      )
    )
  )
)

# ============================================================================
# SERVER LOGIC
# ============================================================================

server <- function(input, output, session) {

  # Load data
  cases_wide <- reactive({
    data <- read.csv("scri_data_wide.csv", stringsAsFactors = FALSE)
    data$control_window_end <- as.Date(data$control_window_end)
    data$vaccination_date <- as.Date(data$vaccination_date)
    data$event_date <- as.Date(data$event_date)
    data
  })

  # Data info text
  output$data_info <- renderText({
    data <- cases_wide()
    sprintf("%d cases, %d in risk window",
            nrow(data),
            sum(data$event_in_risk_window))
  })

  # Reactive analysis results
  analysis_results <- eventReactive(input$run_analysis, {

    data <- cases_wide()

    # Get parameters
    alpha <- input$alpha
    n_looks <- input$n_looks
    risk_start <- input$risk_window[1]
    risk_end <- input$risk_window[2]
    control_start <- input$control_window[1]
    control_end <- input$control_window[2]
    min_cases_per_look <- input$min_cases

    risk_length <- risk_end - risk_start + 1
    control_length <- control_end - control_start + 1

    # Recalculate event assignments based on new windows
    data$event_in_risk_window <- (data$days_to_event >= risk_start & data$days_to_event <= risk_end)
    data$event_in_control_window <- (data$days_to_event >= control_start & data$days_to_event <= control_end)

    # Filter to only include cases whose events fall in either the risk OR control window
    # This is crucial: if user changes windows, some cases may fall outside both windows
    data <- data[data$event_in_risk_window | data$event_in_control_window, ]

    # Convert to binary 0/1 for analysis
    data$event_in_risk_window <- ifelse(data$event_in_risk_window, 1, 0)

    # Recalculate control_window_end based on new control window parameters
    # This is crucial for correct look scheduling when user changes the control window
    data$control_window_end <- data$vaccination_date + control_end

    # CRITICAL: Null hypothesis proportion must account for different window lengths!
    # Under null (no elevated risk), events distribute proportional to observation time
    p0 <- risk_length / (risk_length + control_length)

    # Set up exact sequential analysis using Sequential package
    analysis_name <- paste0("Dashboard_", Sys.time() |> as.numeric() |> round())
    RR_target <- cfg$simulation$true_relative_risk

    # Create temp directory for Sequential package setup files
    temp_dir <- file.path(tempdir(), analysis_name)
    dir.create(temp_dir, showWarnings = FALSE, recursive = TRUE)

    # Use total number of cases as maximum sample size
    max_N <- nrow(data)

    # Initialize Sequential analysis with exact methods
    AnalyzeSetUp.Binomial(
      name = analysis_name,
      N = max_N,                   # Maximum sample size from data
      alpha = alpha,                # Overall Type I error
      zp = 1,                      # Matching ratio (z=1 for SCRI, p=0.5)
      M = min_cases_per_look,      # Min events before signal
      AlphaSpendType = "Wald",     # Wald alpha spending function
      power = 0.9,                 # Target power
      RR = RR_target,              # Relative risk to detect
      Tailed = "upper",            # Upper-tailed test (elevated risk)
      title = "Dashboard SCRI Analysis",
      address = temp_dir
    )

    # Define look schedule - always plan for n_looks
    look_dates <- sort(unique(data$control_window_end))

    # Find first viable look date
    current_date <- min(look_dates)
    max_date <- max(look_dates)
    first_look_date <- NULL

    while (current_date <= max_date && is.null(first_look_date)) {
      available_cases <- data[data$control_window_end <= current_date, ]
      if (nrow(available_cases) >= min_cases_per_look) {
        first_look_date <- current_date
      }
      current_date <- current_date + 14
    }

    if (is.null(first_look_date)) return(NULL)

    # Generate all n_looks scheduled dates (14 days apart)
    look_schedule <- seq(from = first_look_date,
                        by = 14,
                        length.out = n_looks)

    # Determine which looks have data available
    looks_with_data <- sapply(look_schedule, function(date) {
      available <- data[data$control_window_end <= date, ]
      nrow(available) >= min_cases_per_look
    })

    # Perform analysis at each look using Sequential package
    results <- data.frame()
    signal_detected_overall <- FALSE
    z_critical <- NA  # Will be extracted from Sequential package results

    for (look in 1:n_looks) {
      look_date <- look_schedule[look]

      # Check if this look has sufficient data
      if (looks_with_data[look]) {
        available_cases <- data[data$control_window_end <= look_date, ]
        n_cases <- nrow(available_cases)

        events_risk <- sum(available_cases$event_in_risk_window)
        events_control <- n_cases - events_risk

        prop_risk <- events_risk / n_cases
        # RR must account for different window lengths!
        # RR = (rate in risk) / (rate in control) = (events_risk/risk_length) / (events_control/control_length)
        observed_RR <- ifelse(events_control > 0,
                             (events_risk / events_control) * (control_length / risk_length),
                             NA)

        # Perform exact sequential test using Sequential package
        seq_result <- suppressMessages(Analyze.Binomial(
          name = analysis_name,
          test = look,
          z = 1,                    # Matching ratio (z=1 for SCRI, implies p=0.5)
          cases = events_risk,
          controls = events_control
        ))

        # Extract results from Sequential package
        # seq_result is a table with columns including "Reject H0" and "CV"
        signal_detected <- if(!is.null(seq_result) && nrow(seq_result) > 0) {
          seq_result[nrow(seq_result), "Reject H0"] == "Yes"
        } else {
          FALSE
        }

        z_critical <- if(!is.null(seq_result) && nrow(seq_result) > 0) {
          seq_result[nrow(seq_result), "CV"]
        } else {
          NA
        }

        # Calculate test statistic and p-value for display
        se_prop <- sqrt(p0 * (1 - p0) / n_cases)
        z_stat <- (prop_risk - p0) / se_prop
        p_val <- 1 - pnorm(z_stat)

      } else {
        # Planned look but data not yet available
        n_cases <- NA
        events_risk <- NA
        events_control <- NA
        prop_risk <- NA
        observed_RR <- NA
        z_stat <- NA
        p_val <- NA
        signal_detected <- FALSE
        # Keep z_critical from previous look if available
      }

      results <- rbind(results, data.frame(
        look_number = look,
        look_date = look_date,
        n_cases = n_cases,
        events_risk = events_risk,
        events_control = events_control,
        prop_risk = prop_risk,
        observed_RR = observed_RR,
        z_statistic = z_stat,
        z_critical = z_critical,
        p_value = p_val,
        signal_detected = signal_detected,
        data_available = looks_with_data[look]
      ))

      # Stop if signal detected (only for looks with data)
      if (looks_with_data[look] && signal_detected) {
        signal_detected_overall <- TRUE
        # Keep remaining planned looks in results but mark them as not analyzed
        if (look < n_looks) {
          for (future_look in (look + 1):n_looks) {
            results <- rbind(results, data.frame(
              look_number = future_look,
              look_date = look_schedule[future_look],
              n_cases = NA,
              events_risk = NA,
              events_control = NA,
              prop_risk = NA,
              observed_RR = NA,
              z_statistic = NA,
              z_critical = z_critical,
              p_value = NA,
              signal_detected = FALSE,
              data_available = FALSE
            ))
          }
        }
        break
      }
    }

    # Clean up temp directory
    unlink(temp_dir, recursive = TRUE)

    list(
      results = results,
      signal = signal_detected_overall,
      alpha_per_look = alpha / n_looks,  # For display only
      z_critical = z_critical,
      risk_window = c(risk_start, risk_end),
      control_window = c(control_start, control_end)
    )
  })

  # Alert Banner
  output$alert_banner <- renderUI({
    results <- analysis_results()
    if (is.null(results)) return(NULL)

    if (results$signal) {
      div(class = "signal-alert",
          icon("exclamation-triangle", class = "fa-2x"),
          h3("SAFETY SIGNAL DETECTED", style = "margin: 10px 0;"),
          p("Immediate investigation recommended. Statistical threshold exceeded.")
      )
    } else {
      div(class = "no-signal",
          icon("check-circle", class = "fa-2x"),
          h3("NO SIGNAL DETECTED", style = "margin: 10px 0;"),
          p("Continue routine surveillance monitoring.")
      )
    }
  })

  # Value Boxes
  output$total_cases_box <- renderValueBox({
    results <- analysis_results()
    if (is.null(results)) {
      valueBox(
        "—", "Total Cases", icon = icon("users"), color = "light-blue"
      )
    } else {
      # Get latest look with actual data (not planned future looks)
      latest <- results$results[results$results$data_available == TRUE, ]
      latest <- latest[nrow(latest), ]
      valueBox(
        latest$n_cases, "Total Cases Analyzed",
        icon = icon("users"), color = "light-blue"
      )
    }
  })

  output$rr_box <- renderValueBox({
    results <- analysis_results()
    if (is.null(results)) {
      valueBox(
        "—", "Relative Risk", icon = icon("chart-line"), color = "purple"
      )
    } else {
      # Get latest look with actual data (not planned future looks)
      latest <- results$results[results$results$data_available == TRUE, ]
      latest <- latest[nrow(latest), ]
      # Use config thresholds for color coding
      color <- if (latest$observed_RR > cfg$dashboard$alert_thresholds$relative_risk$critical) {
        "red"
      } else if (latest$observed_RR > cfg$dashboard$alert_thresholds$relative_risk$warning) {
        "orange"
      } else {
        "green"
      }
      valueBox(
        sprintf("%.2f", latest$observed_RR), "Observed Relative Risk",
        icon = icon("chart-line"), color = color
      )
    }
  })

  output$pvalue_box <- renderValueBox({
    results <- analysis_results()
    if (is.null(results)) {
      valueBox(
        "—", "P-value", icon = icon("calculator"), color = "yellow"
      )
    } else {
      # Get latest look with actual data (not planned future looks)
      latest <- results$results[results$results$data_available == TRUE, ]
      latest <- latest[nrow(latest), ]
      color <- if (latest$p_value < results$alpha_per_look) "red" else "green"
      valueBox(
        sprintf("%.4f", latest$p_value),
        sprintf("P-value (α = %.4f)", results$alpha_per_look),
        icon = icon("calculator"), color = color
      )
    }
  })

  output$signal_box <- renderValueBox({
    results <- analysis_results()
    if (is.null(results)) {
      valueBox(
        "—", "Signal Status", icon = icon("bell"), color = "light-blue"
      )
    } else {
      if (results$signal) {
        valueBox(
          "YES", "Safety Signal", icon = icon("exclamation-triangle"), color = "red"
        )
      } else {
        valueBox(
          "NO", "Safety Signal", icon = icon("check"), color = "green"
        )
      }
    }
  })

  # Monitoring Plot
  output$monitoring_plot <- renderPlotly({
    results <- analysis_results()
    if (is.null(results)) return(NULL)

    df <- results$results

    # Separate looks with data from planned future looks
    df_with_data <- df[df$data_available == TRUE & !is.na(df$z_statistic), ]
    df_planned <- df[df$data_available == FALSE | is.na(df$z_statistic), ]

    p <- plot_ly()

    # Add z-statistic for looks with data
    if (nrow(df_with_data) > 0) {
      p <- p %>%
        add_trace(data = df_with_data, x = ~look_number, y = ~z_statistic,
                  type = 'scatter', mode = 'lines+markers',
                  name = 'Z-Statistic (Data Available)',
                  line = list(color = '#3498db', width = 3),
                  marker = list(size = 10, color = '#3498db'))
    }

    # Add critical boundary across all looks
    p <- p %>%
      add_trace(x = c(1, max(df$look_number)), y = c(df$z_critical[1], df$z_critical[1]),
                type = 'scatter', mode = 'lines',
                name = 'Critical Boundary', line = list(color = '#e74c3c', width = 2, dash = 'dash')) %>%
      add_trace(x = c(1, max(df$look_number)), y = c(0, 0),
                type = 'scatter', mode = 'lines', name = 'Null (No Effect)',
                line = list(color = 'gray', width = 1, dash = 'dot'))

    # Add markers for planned looks without data
    if (nrow(df_planned) > 0) {
      p <- p %>%
        add_trace(data = df_planned, x = ~look_number, y = 0,
                  type = 'scatter', mode = 'markers',
                  name = 'Planned (Data Not Yet Available)',
                  marker = list(size = 8, color = '#95a5a6', symbol = 'circle-open'))
    }

    p <- p %>%
      layout(
        title = list(text = "Sequential Test Statistics vs. Critical Boundary", font = list(size = 16)),
        xaxis = list(title = "Sequential Look Number",
                     range = c(0.5, max(df$look_number) + 0.5)),
        yaxis = list(title = "Z-Statistic"),
        hovermode = 'closest',
        showlegend = TRUE,
        legend = list(x = 0.02, y = 0.98)
      )

    p
  })

  # RR Plot
  output$rr_plot <- renderPlotly({
    results <- analysis_results()
    if (is.null(results)) return(NULL)

    df <- results$results

    # Get threshold values from config
    rr_warning <- cfg$dashboard$alert_thresholds$relative_risk$warning
    rr_critical <- cfg$dashboard$alert_thresholds$relative_risk$critical

    plot_ly(df) %>%
      add_trace(x = ~look_number, y = ~observed_RR, type = 'scatter', mode = 'lines+markers',
                name = 'Observed RR', line = list(color = '#27ae60', width = 3),
                marker = list(size = 10, color = '#27ae60')) %>%
      add_trace(x = c(min(df$look_number), max(df$look_number)), y = c(1, 1),
                type = 'scatter', mode = 'lines', name = 'RR = 1.0 (No Effect)',
                line = list(color = 'black', width = 2, dash = 'dash')) %>%
      add_trace(x = c(min(df$look_number), max(df$look_number)),
                y = c(rr_warning, rr_warning),
                type = 'scatter', mode = 'lines',
                name = sprintf('RR = %.1f (Warning)', rr_warning),
                line = list(color = 'orange', width = 1, dash = 'dot')) %>%
      add_trace(x = c(min(df$look_number), max(df$look_number)),
                y = c(rr_critical, rr_critical),
                type = 'scatter', mode = 'lines',
                name = sprintf('RR = %.1f (Critical)', rr_critical),
                line = list(color = 'red', width = 1, dash = 'dot')) %>%
      layout(
        title = list(text = "Observed Relative Risk Over Time", font = list(size = 16)),
        xaxis = list(title = "Sequential Look Number"),
        yaxis = list(title = "Relative Risk"),
        hovermode = 'closest',
        showlegend = TRUE
      )
  })

  # Timeline Plot
  output$timeline_plot <- renderPlotly({
    results <- analysis_results()
    if (is.null(results)) return(NULL)

    df <- results$results

    plot_ly(df) %>%
      add_trace(x = ~look_date, y = ~n_cases, type = 'scatter', mode = 'lines+markers',
                name = 'Total Cases', line = list(color = '#3498db', width = 3),
                marker = list(size = 8)) %>%
      add_trace(x = ~look_date, y = ~events_risk, type = 'scatter', mode = 'lines+markers',
                name = 'Risk Window Events', line = list(color = '#e74c3c', width = 2),
                marker = list(size = 8, symbol = 'triangle-up')) %>%
      add_trace(x = ~look_date, y = ~events_control, type = 'scatter', mode = 'lines+markers',
                name = 'Control Window Events', line = list(color = '#27ae60', width = 2),
                marker = list(size = 8, symbol = 'square')) %>%
      layout(
        title = list(text = "Cumulative Cases Over Time", font = list(size = 16)),
        xaxis = list(title = "Date"),
        yaxis = list(title = "Cumulative Count"),
        hovermode = 'closest',
        showlegend = TRUE
      )
  })

  # Results Table
  output$results_table <- DT::renderDataTable({
    results <- analysis_results()
    if (is.null(results)) return(NULL)

    df <- results$results
    df$look_date <- as.character(df$look_date)
    df$observed_RR <- round(df$observed_RR, 2)
    df$z_statistic <- round(df$z_statistic, 3)
    df$p_value <- round(df$p_value, 4)

    # Update status to show planned vs analyzed
    df$status <- ifelse(!df$data_available, "Planned",
                       ifelse(df$signal_detected, "SIGNAL", "Continue"))

    display_df <- df[, c("look_number", "look_date", "n_cases", "events_risk",
                         "events_control", "observed_RR", "z_statistic",
                         "p_value", "status")]

    colnames(display_df) <- c("Look", "Date", "Cases", "Risk Events", "Control Events",
                              "RR", "Z-stat", "P-value", "Status")

    DT::datatable(display_df,
                  options = list(pageLength = 10, dom = 't'),
                  rownames = FALSE) %>%
      DT::formatStyle('Status',
                      backgroundColor = DT::styleEqual(c('SIGNAL', 'Continue'),
                                                       c('#e74c3c', '#27ae60')),
                      color = 'white',
                      fontWeight = 'bold')
  })

  # Recommendations
  output$recommendations <- renderUI({
    results <- analysis_results()
    if (is.null(results)) {
      return(p("Run analysis to see recommendations."))
    }

    latest <- results$results[nrow(results$results), ]

    if (results$signal) {
      tagList(
        div(class = "recommendation-box",
            h4(icon("exclamation-circle"), " IMMEDIATE ACTIONS REQUIRED"),
            tags$ol(
              tags$li(strong("Detailed Case Review:"), " Review medical records for all ",
                      latest$events_risk, " risk window cases. Assess severity and outcomes."),
              tags$li(strong("Stratified Analysis:"), " Examine by age group (65-74, 75-84, 85+), comorbidities, and vaccine lot."),
              tags$li(strong("Clinical Expert Panel:"), " Convene experts to assess biological plausibility and clinical significance."),
              tags$li(strong("Regulatory Notification:"), " Immediately notify regulatory authorities of the detected signal."),
              tags$li(strong("Risk Communication:"), " Prepare materials for healthcare providers and public communication."),
              tags$li(strong("Risk-Benefit Assessment:"), " Evaluate whether vaccination should continue while investigating.")
            )
        ),
        div(class = "recommendation-box",
            h4(icon("info-circle"), " SIGNAL DETAILS"),
            p(sprintf("Relative Risk: %.2f (%.0f%% increased risk in risk window)",
                      latest$observed_RR, (latest$observed_RR - 1) * 100)),
            p(sprintf("Statistical Significance: p = %.4f (threshold: %.4f)",
                      latest$p_value, results$alpha_per_look)),
            p(sprintf("Signal detected at Look %d on %s with %d cases",
                      latest$look_number, latest$look_date, latest$n_cases))
        )
      )
    } else {
      tagList(
        div(class = "recommendation-box",
            h4(icon("check-circle"), " CONTINUE ROUTINE MONITORING"),
            p("No safety signal detected at this time. Current recommendations:"),
            tags$ul(
              tags$li("Continue sequential surveillance as scheduled"),
              tags$li("Monitor for changes in relative risk trends"),
              tags$li("Maintain data quality and completeness"),
              tags$li("Prepare for next scheduled look")
            )
        ),
        div(class = "recommendation-box",
            h4(icon("chart-line"), " CURRENT STATUS"),
            p(sprintf("Relative Risk: %.2f", latest$observed_RR)),
            p(sprintf("P-value: %.4f (threshold: %.4f)",
                      latest$p_value, results$alpha_per_look)),
            p(sprintf("Latest analysis: %s with %d cases",
                      latest$look_date, latest$n_cases))
        )
      )
    }
  })
}

# ============================================================================
# RUN APPLICATION
# ============================================================================

shinyApp(ui = ui, server = server)
