#-------------------------------------------------------------
# testDBLoading.R
# Author: Deivasigamani, Anjana
#-------------------------------------------------------------

# Load necessary libraries
suppressWarnings(suppressMessages(library(DBI)))
suppressWarnings(suppressMessages(library(RMySQL)))
suppressWarnings(suppressMessages(library(readr)))
suppressWarnings(suppressMessages(library(dplyr)))
suppressWarnings(suppressMessages(library(tidyr)))

# -------------------- DATABASE CONNECTION --------------------
db_host <- "35.193.167.112"
db_user <- "rstudio_user"
db_password <- "user123"
db_name <- "restaurant_db"

dbCon <- dbConnect(
  RMySQL::MySQL(),
  dbname = db_name,
  host = db_host,
  user = db_user,
  password = db_password
)

if (dbIsValid(dbCon)) {
  print("Successfully connected.")
} else {
  stop("Connection failed.")
}

# -------------------- LOAD ORIGINAL CSV --------------------
# Read the CSV directly from the URL
suppressWarnings(suppressMessages({
  df.orig <- vroom::vroom("https://s3.us-east-2.amazonaws.com/artificium.us/datasets/restaurant-visits-139874.csv",
                          show_col_types = FALSE, col_types = cols(.default = "c"))
  
}))
# Handle column name inconsistencies
df.orig <- df.orig %>%
  rename_with(~"RestaurantName", matches("Restaurant")) %>%
  rename_with(~"OrderedAlcohol", matches("orderedAlcohol"))

print("CSV Data Loaded Successfully!")

# -------------------- CONVERT NA VALUES TO ZERO --------------------
df.orig <- df.orig %>%
  mutate(
    FoodBill = ifelse(is.na(FoodBill), 0, FoodBill),
    AlcoholBill = ifelse(is.na(AlcoholBill), 0, AlcoholBill),
    TipAmount = ifelse(is.na(TipAmount), 0, TipAmount)
  )

# -------------------- TEST RESTAURANT TABLE --------------------
csv_restaurant_count <- df.orig %>%
  select(RestaurantName) %>%
  distinct() %>%
  filter(!is.na(RestaurantName)) %>%
  nrow()

db_restaurant_count <- suppressWarnings({dbGetQuery(dbCon, "SELECT COUNT(*) as count FROM Restaurant")$count})

print(paste("Restaurant count in CSV:", csv_restaurant_count))
print(paste("Restaurant count in DB:", db_restaurant_count))

if (csv_restaurant_count == db_restaurant_count) {
  print("Restaurant counts match!")
} else {
  print("Restaurant counts don't match!")
}

# -------------------- TEST SERVER TABLE --------------------
csv_server_count <- df.orig %>%
  select(ServerEmpID) %>%
  distinct() %>%
  filter(!is.na(ServerEmpID)) %>%
  nrow()

db_server_count <- suppressWarnings({dbGetQuery(dbCon, "SELECT COUNT(*) as count FROM Server")$count})

print(paste(" Server count in CSV:", csv_server_count))
print(paste(" Server count in DB:", db_server_count))

if (csv_server_count == db_server_count) {
  print("Server counts match!")
} else {
  print("Server counts don't match!")
}

# -------------------- TEST CUSTOMERS --------------------
csv_customer_count <- df.orig %>%
  select(CustomerName) %>%
  distinct() %>%
  filter(!is.na(CustomerName) & CustomerName != "") %>%
  nrow()

db_customer_count <- suppressWarnings({dbGetQuery(dbCon, "SELECT COUNT(*) as count FROM Customer")$count})

print(paste("Customer count in CSV:", csv_customer_count))
print(paste("Customer count in DB:", db_customer_count))

if (csv_customer_count == db_customer_count) {
  print("Customer counts match!")
} else {
  print("Customer counts don't match!")
}

# -------------------- TEST PAYMENTS --------------------
csv_payment_count <- df.orig %>%
  select(PaymentMethod) %>%
  distinct() %>%
  filter(!is.na(PaymentMethod) & PaymentMethod != "") %>%
  nrow()

db_payment_count <- suppressWarnings({dbGetQuery(dbCon, "SELECT COUNT(*) as count FROM Payment")$count})

print(paste("Payment method count in CSV:", csv_payment_count))
print(paste("Payment method count in DB:", db_payment_count))

if (csv_payment_count == db_payment_count) {
  print("Payment method counts match!")
} else {
  print("Payment method counts don't match!")
}


# -------------------- TEST FINANCIAL SUMS --------------------
print("Financial Sums Comparison:")

# To ensure columns are numeric before further operations
df.orig <- df.orig %>%
  mutate(
    FoodBill = as.numeric(FoodBill),
    AlcoholBill = as.numeric(AlcoholBill),
    TipAmount = as.numeric(TipAmount)
  )

# Ensure missing values (NA) are replaced with 0 before summing
csv_sums <- df.orig %>%
  summarize(
    total_food = sum(FoodBill, na.rm = TRUE),
    total_alcohol = sum(AlcoholBill, na.rm = TRUE),
    total_tips = sum(TipAmount, na.rm = TRUE)
  ) %>%
  mutate(across(everything(), ~replace_na(., 0)))  # Ensures no NA values

# Query DB sums, ensuring COALESCE to avoid NULL values
db_sums <- suppressWarnings({dbGetQuery(dbCon, "
  SELECT 
    COALESCE(SUM(FoodBill), 0) as total_food,
    COALESCE(SUM(AlcoholBill), 0) as total_alcohol,
    COALESCE(SUM(TipAmount), 0) as total_tips
  FROM Visit
")
})

# Ensure all values are numeric
csv_sums <- csv_sums %>% mutate(across(everything(), as.numeric))
db_sums <- db_sums %>% mutate(across(everything(), as.numeric))

# Print results
print("CSV Sums:")
print(csv_sums)

print("DB Sums:")
print(db_sums)

# -------------------- COMPARE FINANCIAL VALUES --------------------
# Avoid division by zero errors
food_ratio <- ifelse(csv_sums$total_food > 0, db_sums$total_food / csv_sums$total_food, NA)
alcohol_ratio <- ifelse(csv_sums$total_alcohol > 0, db_sums$total_alcohol / csv_sums$total_alcohol, NA)
tip_ratio <- ifelse(csv_sums$total_tips > 0, db_sums$total_tips / csv_sums$total_tips, NA)

print(paste("Food totals ratio (DB:CSV):", round(food_ratio, 4)))
print(paste("Alcohol totals ratio (DB:CSV):", round(alcohol_ratio, 4)))
print(paste("Tip totals ratio (DB:CSV):", round(tip_ratio, 4)))

# Tolerance level for floating point discrepancies
tolerance <- 0.01  # 1% difference allowed

# Function to compare values with tolerance
compare_values <- function(label, csv_value, db_value) {
  if (is.na(csv_value) || is.na(db_value)) {
    print(paste("WARNING:", label, "comparison skipped due to missing data!"))
    return()
  }
  
  diff_pct <- abs(csv_value - db_value) / max(csv_value, 1) * 100  # Avoid division by zero
  
  print(paste("Total", label, "- CSV: $", round(csv_value, 2), "| Database: $", round(db_value, 2)))
  
  if (diff_pct <= tolerance * 100) {
    print(paste("totals match within tolerance (", round(diff_pct, 2), "%)"))
  } else {
    print(paste("totals differ by", round(diff_pct, 2), "%"))
  }
}

# Compare financial values
compare_values("Food Bill", csv_sums$total_food, db_sums$total_food)
compare_values("Alcohol Bill", csv_sums$total_alcohol, db_sums$total_alcohol)
compare_values("Tip Amount", csv_sums$total_tips, db_sums$total_tips)

# -------------------- DISCONNECT DATABASE CONNECTION --------------------
dbDisconnect(dbCon)
print("Database testing completed.")
