# Check data distribution
data <- read.csv('scri_data_wide.csv')

cat('Total cases:', nrow(data), '\n')
cat('Days to event - min:', min(data$days_to_event), 'max:', max(data$days_to_event), '\n\n')

cat('Events by day range:\n')
cat('  Days 1-28:', sum(data$days_to_event >= 1 & data$days_to_event <= 28), '\n')
cat('  Days 29-48:', sum(data$days_to_event >= 29 & data$days_to_event <= 48), '\n')
cat('  Days 49-56:', sum(data$days_to_event >= 49 & data$days_to_event <= 56), '\n')
cat('  Days 57+:', sum(data$days_to_event > 56), '\n\n')

# Check what happens with different control windows
cat('If control window is 29-48:\n')
data_29_48 <- data[data$days_to_event <= 48, ]
cat('  Total cases:', nrow(data_29_48), '\n')
cat('  Risk (1-28):', sum(data_29_48$days_to_event >= 1 & data_29_48$days_to_event <= 28), '\n')
cat('  Control (29-48):', sum(data_29_48$days_to_event >= 29 & data_29_48$days_to_event <= 48), '\n')
