#-------------------------------------------------------------
# configBusinessLogic.R
# Author: Deivasigamani, Anjana
#-------------------------------------------------------------

# Load necessary libraries
suppressWarnings(suppressMessages(library(DBI)))
suppressWarnings(suppressMessages(library(RMySQL)))
suppressWarnings(suppressMessages(library(dplyr)))

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

# -------------------------------------------------------------
# DELETE PREVIOUS TEST DATA
# -------------------------------------------------------------
print("Deleting previous test data...")

suppressWarnings({
  dbExecute(dbCon, "
      DELETE FROM Visit 
      WHERE VisitDate = '2025-03-15' 
      AND VisitTime = '19:45:00' 
      AND RestaurantID = (SELECT RestaurantID FROM Restaurant WHERE RestaurantName = 'Royal Spice Kitchen')
      AND CustomerID = (SELECT CustomerID FROM Customer WHERE CustomerMail = 'anjana.deivasigamani@email.com');
  ")
  
  dbExecute(dbCon, "
      DELETE FROM Customer 
      WHERE CustomerMail = 'anjana.deivasigamani@email.com';
  ")
  
  dbExecute(dbCon, "
      DELETE FROM Restaurant 
      WHERE RestaurantName = 'Royal Spice Kitchen';
  ")
  
  dbExecute(dbCon, "
      DELETE FROM Payment 
      WHERE PaymentMethod = 'Credit Card';
  ")
})

print("Old test data removed.")

# -------------------------------------------------------------
# TESTING storeVisit STORED PROCEDURE
# -------------------------------------------------------------
print("Testing `storeVisit` Procedure...")

suppressWarnings({
  dbExecute(dbCon, "
      CALL storeVisit(
          1, 1, '2025-03-15', '19:45:00', 'Dinner', 2, 10, 120.75, 18.00, 1, 45.00, 'Credit Card', 3
      );
  ")
})

print("`storeVisit` executed successfully!")

# -------------------------------------------------------------
# TESTING storeNewVisit STORED PROCEDURE
# -------------------------------------------------------------
print("Testing `storeNewVisit` Procedure...")

suppressWarnings({
  dbExecute(dbCon, "
      CALL storeNewVisit(
          'anjana.deivasigamani@email.com', 'Anjana Deivasigamani', '987-654-3210',
          'Royal Spice Kitchen', 505, 'Sarah Williams', '2022-05-10', 28.50,
          '2025-03-15', '19:45:00', 'Dinner', 2, 10, 120.75, 18.00, 1, 45.00, 'Credit Card'
      );
  ")
})

print("`storeNewVisit` executed successfully!")

# -------------------------------------------------------------
# VERIFY INSERTED DATA
# -------------------------------------------------------------
print("Verifying `storeVisit` and `storeNewVisit` inserts...")

suppressWarnings({
  visit_test <- dbGetQuery(dbCon, "
      SELECT VisitID, CustomerID, RestaurantID, VisitDate, VisitTime, MealType, PartySize, FoodBill, TipAmount 
      FROM Visit 
      WHERE VisitDate = '2025-03-15' 
      AND CustomerID = (SELECT CustomerID FROM Customer WHERE CustomerMail = 'anjana.deivasigamani@email.com');
  ") %>% mutate(across(where(is.character), as.factor)) %>% mutate(across(where(is.numeric), as.numeric))
  
  customer_test <- dbGetQuery(dbCon, "
      SELECT CustomerID, CustomerName, CustomerPhone, CustomerMail 
      FROM Customer 
      WHERE CustomerMail = 'anjana.deivasigamani@email.com';
  ") %>% mutate(across(where(is.character), as.factor))
  
  restaurant_test <- dbGetQuery(dbCon, "
      SELECT RestaurantID, RestaurantName 
      FROM Restaurant 
      WHERE RestaurantName = 'Royal Spice Kitchen';
  ") %>% mutate(across(where(is.character), as.factor))
  
  payment_test <- dbGetQuery(dbCon, "
      SELECT PaymentID, PaymentMethod 
      FROM Payment 
      WHERE PaymentMethod = 'Credit Card';
  ") %>% mutate(across(where(is.character), as.factor))
})

# Print verification results
print("Newly Inserted Visits:")
print(visit_test)

print("Customer Details:")
print(customer_test)

print("Restaurant Details:")
print(restaurant_test)

print("Payment Details:")
print(payment_test)

# -------------------- DISCONNECT DATABASE CONNECTION --------------------
dbDisconnect(dbCon)
print("Database connection closed.")
