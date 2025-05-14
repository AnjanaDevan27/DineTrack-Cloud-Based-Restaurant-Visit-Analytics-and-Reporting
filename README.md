# DineTrack: Restaurant Visit Analytics on Cloud SQL

## Overview

**DineTrack** is a data analytics project that simulates a real-world restaurant reporting pipeline. It involves designing and hosting a normalized relational database on **Google Cloud SQL**, loading structured synthetic data using **R**, and generating a comprehensive analytics report in **RMarkdown**. The objective is to uncover insights into customer behavior, food vs. alcohol revenue trends, and location-level sales performance—all without automation or a web interface.

---

## Schema Design Highlights

The relational schema is normalized to **3NF** and includes:

### Dimension Tables
- `dim_customer`: Customer demographics
- `dim_product`: Food vs. alcohol categories
- `dim_location`: City, state, and store address
- `dim_time`: Calendar metadata (year, quarter, etc.)
- `dim_business_unit`: Business region or group

### Fact Tables
- `fact_visit`: Detailed visit transactions
- `fact_sales_yearly`: Aggregated annual metrics
- `fact_customer`: Links visits to customer profiles

📄 Refer to [`designDBSchema.PractI.DeivasigamaniA.pdf`](designDBSchema.PractI.DeivasigamaniA.pdf) for a detailed schema diagram.

---

## wTools & Technologies

- **Languages**: R, SQL
- **Database**: MySQL 8+, hosted on Google Cloud SQL
- **Libraries**: `DBI`, `RMySQL`, `dplyr`, `ggplot2`, `kableExtra`, `lubridate`
- **Output**: PDF/HTML via RMarkdown

---

## Implementation Breakdown

- **Schema Creation**: Done via `createDB.PractI.DeivasigamaniA.R`
- **Data Insertion**: Loaded structured CSVs using `loadDB.PractI.DeivasigamaniA.R`
- **Stored Procedures**: Configured visit logic via `configBusinessLogic.PractI.DeivasigamaniA.R`
- **Validation**: Referential checks and counts using `testDBLoading.PractI.DeivasigamaniA.R`
- **Cleanup**: Tables dropped via `deleteDB.PractI.DeivasigamaniA.R`
- **Analytics Report**: Final summary in `RevenueReport.PractI.DeivasigamaniA.Rmd`

---

## Report Highlights

### Top Performing Restaurants (by Revenue)
| Restaurant          | Total Food Revenue | Total Alcohol Revenue |
|---------------------|--------------------|------------------------|
| Bite & Bun          | \$562,995          | \$70,434               |
| The Burger Joint    | \$551,032          | \$71,661               |
| Flame Shack         | \$544,854          | \$69,723               |
| Burger Haven        | \$542,519          | \$69,073               |
| Grill & Thrill      | \$546,700          | \$67,897               |

> Note: Loyalty customers were most frequent at **Bite & Bun** and **Stacked & Sizzled**.

### Revenue Growth Over Years

| Year | Total Revenue  | Avg Spend/Party | Avg Party Size |
|------|----------------|------------------|----------------|
| 2018 | \$303,343      | \$39.72          | 2.31           |
| 2019 | \$456,590      | \$39.85          | 2.32           |
| 2020 | \$500,901      | \$39.31          | 2.29           |
| 2021 | \$645,308      | \$39.50          | 2.30           |
| 2022 | \$1,208,142    | \$39.45          | 2.30           |
| 2023 | \$1,145,689    | \$39.36          | 2.30           |
| 2024 | **\$1,264,824**| \$39.56          | 2.32           |

 **2024** saw the highest total revenue, indicating growing sales momentum despite economic fluctuations.

---

## Project File Structure
```
DineTrack/
├── designDBSchema.pdf       # Database schema documentation
├── createDB.R               # Create schema and tables
├── loadDB.R                 # Load data into MySQL (GCP)
├── configBusinessLogic.R    # Configure stored procedures
├── testDBLoading.R          # Validate data integrity
├── deleteDB.R               # Drop all tables (reset)
├── RevenueReport.Rmd        # RMarkdown report template
├── RevenueReport.pdf        # Final analytics report
└── README.md                # Project documentation
```
---


