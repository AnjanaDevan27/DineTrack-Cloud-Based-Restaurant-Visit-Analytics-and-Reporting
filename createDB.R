#-------------------------------------------------------------
# createDB.R
# Author: "Deivasigamani, Anjana"
#-------------------------------------------------------------

# Load necessary libraries
suppressWarnings(suppressMessages(library(DBI)))
suppressWarnings(suppressMessages(library(RMySQL)))

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

# -------------------- CREATE TABLES --------------------
create_tables <- function() {
  queries <- list(
    "CREATE TABLE IF NOT EXISTS Restaurant (
      RestaurantID INT PRIMARY KEY AUTO_INCREMENT,
      RestaurantName VARCHAR(255) NOT NULL UNIQUE
    ) ENGINE=InnoDB",
    
    "CREATE TABLE IF NOT EXISTS Server (
      ServerEmpID INT PRIMARY KEY AUTO_INCREMENT,
      ServerName VARCHAR(255) NOT NULL,
      StartDateHired DATE DEFAULT NULL,
      EndDateHired DATE DEFAULT NULL,
      HourlyRate DECIMAL(5,2) DEFAULT 0.00,
      ServerBirthDate DATE DEFAULT NULL,
      ServerTIN VARCHAR(20) UNIQUE,
      INDEX idx_server_empid (ServerEmpID)
    ) ENGINE=InnoDB",
    
    "CREATE TABLE IF NOT EXISTS Payment (
      PaymentID INT PRIMARY KEY AUTO_INCREMENT,
      PaymentMethod VARCHAR(50) NOT NULL UNIQUE,
      DiscountApplied DECIMAL(5,2) DEFAULT 0.00
    ) ENGINE=InnoDB",
    
    "CREATE TABLE IF NOT EXISTS Customer (
      CustomerID INT PRIMARY KEY AUTO_INCREMENT,
      CustomerName VARCHAR(255) NOT NULL,
      CustomerPhone VARCHAR(20) DEFAULT NULL,
      CustomerMail VARCHAR(255) DEFAULT NULL,
      LoyaltyMember TINYINT(1) DEFAULT NULL, -- Allow NULL to preserve true values
      UNIQUE (CustomerName, CustomerPhone, CustomerMail)
    ) ENGINE=InnoDB",
    
    "CREATE TABLE IF NOT EXISTS Visit (
      VisitID INT AUTO_INCREMENT PRIMARY KEY,
      CustomerID INT NULL,  
      RestaurantID INT NOT NULL,  
      ServerEmpID INT NULL,
      PaymentID INT NULL,
      VisitDate DATE NOT NULL,
      VisitTime TIME DEFAULT NULL,
      MealType VARCHAR(50) NOT NULL,
      PartySize INT NOT NULL,
      WaitTime INT DEFAULT NULL,
      FoodBill DECIMAL(10,2) NOT NULL,
      TipAmount DECIMAL(10,2) DEFAULT 0.00,
      OrderedAlcohol TINYINT(1) NOT NULL DEFAULT FALSE,
      AlcoholBill DECIMAL(10,2) DEFAULT 0.00,
    
      UNIQUE (VisitDate, VisitTime, RestaurantID, CustomerID, ServerEmpID, PaymentID, FoodBill, AlcoholBill, TipAmount),
    
      CONSTRAINT fk_visit_customer FOREIGN KEY (CustomerID) 
          REFERENCES Customer(CustomerID) ON DELETE SET NULL,
      CONSTRAINT fk_visit_restaurant FOREIGN KEY (RestaurantID) 
          REFERENCES Restaurant(RestaurantID) ON DELETE CASCADE,
      CONSTRAINT fk_visit_server FOREIGN KEY (ServerEmpID) 
          REFERENCES Server(ServerEmpID) ON DELETE SET NULL,
      CONSTRAINT fk_visit_payment FOREIGN KEY (PaymentID) 
          REFERENCES Payment(PaymentID) ON DELETE SET NULL,
    
      INDEX idx_visit_date (VisitDate),
      INDEX idx_visit_restaurant (RestaurantID),
      INDEX idx_visit_customer (CustomerID)
    );"
  )
  
  for (query in queries) {
    dbExecute(dbCon, query)
  }
}
create_tables()

# -------------------- DISCONNECT DATABASE CONNECTION --------------------
# Disconnect db connection
dbDisconnect(dbCon)
print("Database created successfully.")

