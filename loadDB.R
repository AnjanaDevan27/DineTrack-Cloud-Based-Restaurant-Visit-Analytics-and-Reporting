#-------------------------------------------------------------
# loadDB.R
# Author: Deivasigamani, Anjana
#-------------------------------------------------------------

# Load necessary libraries
suppressWarnings(suppressMessages(library(DBI)))
suppressWarnings(suppressMessages(library(RMySQL)))
suppressWarnings(suppressMessages(library(readr)))
suppressWarnings(suppressMessages(library(dplyr)))
suppressWarnings(suppressMessages(library(lubridate)))
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

#-------------------------------------------------------------
# Step 1: Load CSV File
#-------------------------------------------------------------

# Read the CSV directly from the URL
suppressWarnings(suppressMessages({
  df.orig <- vroom::vroom("https://s3.us-east-2.amazonaws.com/artificium.us/datasets/restaurant-visits-139874.csv",
                          show_col_types = FALSE, col_types = cols(.default = "c"))
  
}))

#-------------------------------------------------------------
# Step 2: Rename Columns & Convert Data Types
#-------------------------------------------------------------

df.orig <- df.orig %>%
  rename(
    RestaurantName = any_of("Restaurant"),
    OrderedAlcohol = any_of("orderedAlcohol")
  ) %>%
  mutate(
    FoodBill = replace_na(FoodBill, 0.00),
    AlcoholBill = replace_na(AlcoholBill, 0.00),
    TipAmount = replace_na(TipAmount, 0.00),
    OrderedAlcohol = ifelse(OrderedAlcohol %in% c("TRUE", "True", "1"), 1, 0),
    LoyaltyMember = ifelse(LoyaltyMember %in% c("TRUE", "True", "1"), 1, 0)
  )

#-------------------------------------------------------------
# Step 3: Insert Unique Restaurants
#-------------------------------------------------------------

df.restaurants <- df.orig %>%
  select(RestaurantName) %>%
  distinct() %>%
  filter(!is.na(RestaurantName))

dbWriteTable(dbCon, "Restaurant", df.restaurants, append = TRUE, row.names = FALSE)
print("Inserted Restaurant Table")

#-------------------------------------------------------------
# Step 4: Insert Unique Servers
#-------------------------------------------------------------

df.servers <- df.orig %>%
  select(ServerEmpID, ServerName, StartDateHired, EndDateHired, HourlyRate, ServerBirthDate, ServerTIN) %>%
  distinct() %>%
  filter(!is.na(ServerEmpID))

dbWriteTable(dbCon, "Server", df.servers, append = TRUE, row.names = FALSE)
print("Inserted Server Table")

#-------------------------------------------------------------
# Step 5: Insert Unique Customers
#-------------------------------------------------------------

df.customers <- df.orig %>%
  select(CustomerName, CustomerPhone, CustomerEmail, LoyaltyMember) %>%
  rename(CustomerMail = CustomerEmail) %>%
  distinct() %>%
  filter(!is.na(CustomerName) & CustomerName != "")

dbWriteTable(dbCon, "Customer", df.customers, append = TRUE, row.names = FALSE)
print("Inserted Customer Table")

#-------------------------------------------------------------
# Step 6: Insert Unique Payments
#-------------------------------------------------------------

df.payments <- df.orig %>%
  select(PaymentMethod, DiscountApplied) %>%
  distinct() %>%
  mutate(
    PaymentMethod = ifelse(is.na(PaymentMethod) | PaymentMethod == "", "Unknown", PaymentMethod),
    DiscountApplied = ifelse(is.na(DiscountApplied), 0.00, DiscountApplied)
  )

dbWriteTable(dbCon, "Payment", df.payments, append = TRUE, row.names = FALSE)

print("Inserted Payment Table")

#-------------------------------------------------------------
# Step 7: Insert Visit Records
#-------------------------------------------------------------

# Load CustomerID mapping
customer_map <- dbGetQuery(dbCon, "SELECT CustomerID, CustomerName FROM Customer")
restaurant_map <- dbGetQuery(dbCon, "SELECT RestaurantID, RestaurantName FROM Restaurant")
payment_lookup <- dbGetQuery(dbCon, "SELECT DISTINCT PaymentID, PaymentMethod FROM Payment")

# Perform LEFT JOIN to map foreign keys, allowing missing IDs
df.visits <- df.orig %>%
  select(CustomerName, RestaurantName, ServerEmpID, PaymentMethod, VisitDate, VisitTime, MealType, 
         PartySize, WaitTime, FoodBill, TipAmount, OrderedAlcohol, AlcoholBill) %>%
  left_join(customer_map, by = "CustomerName") %>%  # Allows NULL CustomerID
  left_join(restaurant_map, by = "RestaurantName") %>%
  left_join(payment_lookup, by = "PaymentMethod") %>%
  mutate(
    CustomerID = ifelse(is.na(CustomerID), NA_integer_, CustomerID),  # Keep NULLs instead of dropping rows
    OrderedAlcohol = ifelse(AlcoholBill > 0, 1, 0)  # Ensure OrderedAlcohol is correct
  ) %>%
  select(CustomerID, RestaurantID, ServerEmpID, PaymentID, VisitDate, VisitTime, MealType, 
         PartySize, WaitTime, FoodBill, TipAmount, OrderedAlcohol, AlcoholBill)

# Fix: Convert `NA` values to NULL
df.visits <- df.visits %>%
  mutate(
    CustomerID = ifelse(is.na(CustomerID), NA_integer_, CustomerID),
    RestaurantID = ifelse(is.na(RestaurantID), NA_integer_, RestaurantID),
    PaymentID = ifelse(is.na(PaymentID), NA_integer_, PaymentID)
  )

# Optimize Batch Processing
batch_size <- 5000
total_batches <- ceiling(nrow(df.visits) / batch_size)
records_inserted <- 0

for (i in seq_len(total_batches)) {
  start_idx <- (i - 1) * batch_size + 1
  end_idx <- min(i * batch_size, nrow(df.visits))
  
  batch <- df.visits[start_idx:end_idx, ]
  
  dbExecute(dbCon, "START TRANSACTION")
  tryCatch({
    dbWriteTable(dbCon, "Visit", batch, append = TRUE, row.names = FALSE)
    records_inserted <- records_inserted + nrow(batch)
    dbExecute(dbCon, "COMMIT")
  }, error = function(e) {
    dbExecute(dbCon, "ROLLBACK")
    print(sprintf("Error in batch %d: %s", i, e$message))
  })
  gc(full = TRUE)
}

print("Inserted Visit Table")

# -------------------- DISCONNECT DATABASE CONNECTION --------------------
# Disconnect db connection
dbDisconnect(dbCon)
print("Database loaded successfully.")
