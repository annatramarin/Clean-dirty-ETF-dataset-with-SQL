-- PART 1. LOAD DATASET AND CREATE STAGING TABLE TO WORK ON
-- We do not want to modify the raw data directly

-- Have a first look at the data
Select *
from dirty_etf_dataset
limit 10;

-- Create a copy of the original table to work on
CREATE TABLE etf_dataset_staging
LIKE dirty_etf_dataset;

-- Check that we have all the columns
SELECT *
FROM etf_dataset_staging
LIMIT 10;

-- Populate THE new table with data from original table
INSERT etf_dataset_staging
SELECT *
FROM dirty_etf_dataset;

-- Let's have another look
SELECT *
FROM etf_dataset_staging
LIMIT 10;


-- PART 2. REMOVE DUPLICATES
-- Group rows that have the same values for ticker, fund_name, inception_date, expense_ratio, aum_millions, asset_class, issuer, average_volume, ytd_return, dividend_yield
-- Within each group, a row number starting from 1 is assigned
-- If the number 2 appears in row_num column, it's a duplicate row

-- Select all columns to check for duplicate content
SELECT *,
ROW_NUMBER() OVER (PARTITION BY
ticker, fund_name, inception_date, expense_ratio, aum_millions, asset_class, issuer, average_volume, ytd_return, dividend_yield) AS row_num
FROM etf_dataset_staging;

-- Put everything in a CTE to output only duplicate rows
WITH duplicate_cte AS
(
SELECT *,
ROW_NUMBER() OVER (PARTITION BY
ticker, fund_name, inception_date, expense_ratio, aum_millions, asset_class, issuer, average_volume, ytd_return, dividend_yield) AS row_num
FROM etf_dataset_staging
)
-- Rows with number 2 are duplicates
SELECT *
FROM duplicate_cte
WHERE row_num > 1;

SELECT *
FROM etf_dataset_staging;

DROP TABLE etf_dataset_staging_2;

-- To DELETE duplicate rows let's create an empty etf_dataset_staging 2
-- How to: right click on etf_dataset_staging > Copy to Clipboard > Create Statement > paste here
CREATE TABLE `etf_dataset_staging_2` (
  `ticker` text,
  `fund_name` text,
  `inception_date` text,
  `expense_ratio` double DEFAULT NULL,
  `aum_millions` text,
  `asset_class` text,
  `issuer` text,
  `average_volume` int DEFAULT NULL,
  `ytd_return` double DEFAULT NULL,
  `dividend_yield` text,
  `row_num` int  -- add the row number column to the table
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

SELECT *
FROM etf_dataset_staging_2;

-- Populate the staging 2 table just created
INSERT INTO etf_dataset_staging_2
SELECT *,
ROW_NUMBER() OVER (PARTITION BY
ticker, fund_name, inception_date, expense_ratio, aum_millions, asset_class, issuer, average_volume, ytd_return, dividend_yield) AS row_num
FROM etf_dataset_staging;

-- Check what we should be deleting
SELECT *
FROM etf_dataset_staging_2
WHERE row_num > 1;

DELETE 
FROM etf_dataset_staging_2
WHERE row_num > 1;

-- This now yields no results
SELECT *
FROM etf_dataset_staging_2
WHERE row_num > 1;

ALTER TABLE etf_dataset_staging_2
DROP COLUMN row_num;

-- --------------------------------------------

-- STANDARDISING DATA
SELECT *
FROM etf_dataset_staging_2
LIMIT 10;

-- Check different cases - MySQL is case-insensitive
SELECT DISTINCT asset_class COLLATE utf8mb4_0900_as_cs
FROM etf_dataset_staging_2;

-- Standardise the 'asset_class' column
UPDATE etf_dataset_staging_2
SET asset_class = 'Equity'
WHERE asset_class IN ('equity', 'EQUITY');

UPDATE etf_dataset_staging_2
SET asset_class = 'Fixed Income'
WHERE asset_class IN ('fixed income');

UPDATE etf_dataset_staging_2
SET asset_class = 'International Equity'
WHERE asset_class IN ('international equity', 'International equity');

UPDATE etf_dataset_staging_2
SET asset_class = 'Real Estate'
WHERE asset_class LIKE 'real est%';

UPDATE etf_dataset_staging_2
SET asset_class = 'Commodity'
WHERE asset_class LIKE 'commod%';

SELECT DISTINCT asset_class COLLATE utf8mb4_0900_as_cs
FROM etf_dataset_staging_2;

-- Standardize the 'issuer' column
SELECT DISTINCT issuer COLLATE utf8mb4_0900_as_cs
FROM etf_dataset_staging_2;

UPDATE etf_dataset_staging_2
SET issuer = 'BlackRock'
WHERE issuer LIKE 'black%';

UPDATE etf_dataset_staging_2
SET issuer = 'Vanguard'
WHERE issuer LIKE 'vang%';

UPDATE etf_dataset_staging_2
SET issuer = 'State Street'
WHERE issuer LIKE 'STATE%';


-- CHANGE DATA FORMAT IN A COLUMN (from 'text' to 'date')
-- The column 'inception_date' is of type text
SHOW COLUMNS FROM etf_dataset_staging_2 WHERE Field='inception_date';

SELECT inception_date
FROM etf_dataset_staging_2;

-- First change the different dates to the right format
-- Check that the update will work
SELECT inception_date,
CASE
WHEN inception_date LIKE '____-__-__' THEN str_to_date(inception_date, '%Y-%m-%d')
WHEN inception_date LIKE '__/__/____' THEN str_to_date(inception_date, '%m/%d/%Y')
WHEN inception_date LIKE '_/__/____' THEN str_to_date(inception_date, '%m/%d/%Y')
WHEN inception_date LIKE '__-__-____' THEN str_to_date(inception_date, '%m-%d-%Y')
END AS parsed_date
FROM etf_dataset_staging_2;


-- Update the table with the correct formats
UPDATE etf_dataset_staging_2
SET inception_date =
CASE
WHEN inception_date LIKE '____-__-__' THEN str_to_date(inception_date, '%Y-%m-%d')
WHEN inception_date LIKE '__/__/____' THEN str_to_date(inception_date, '%m/%d/%Y')
WHEN inception_date LIKE '_/__/____' THEN str_to_date(inception_date, '%m/%d/%Y')
WHEN inception_date LIKE '__-__-____' THEN str_to_date(inception_date, '%m-%d-%Y')
END
WHERE inception_date IS NOT NULL;

-- Change the column type from TEXT to DATE
ALTER TABLE etf_dataset_staging_2
MODIFY COLUMN inception_date DATE;

-- Check the data type again
SHOW COLUMNS FROM etf_dataset_staging_2 WHERE Field='inception_date';


-- NULL and BLANK VALUES
-- Identify rows with null or empty values
SELECT * 
FROM etf_dataset_staging_2
WHERE ticker IS NULL OR ticker = ''
OR fund_name IS NULL OR fund_name = ''
OR inception_date IS NULL
OR expense_ratio IS NULL OR expense_ratio = ''
OR aum_millions IS NULL OR aum_millions = ''
OR asset_class IS NULL OR asset_class = ''
OR issuer IS NULL OR issuer = ''
OR average_volume IS NULL OR average_volume = ''
OR ytd_return IS NULL OR ytd_return = ''
OR dividend_yield IS NULL OR dividend_yield = '';

-- Fix ticker with empty string
SELECT * 
FROM etf_dataset_staging_2
where fund_name = 'Vanguard Total Stock Market ETF';

-- Identify the missing ticker
SELECT t1.ticker, t2.ticker
FROM etf_dataset_staging_2 AS t1
JOIN etf_dataset_staging_2 AS t2
-- join on the same fund name
ON t1.fund_name = t2.fund_name
WHERE (t1.ticker IS NULL OR t1.ticker= '')
AND t2.ticker IS NOT NULL;

-- Update the table with the missing ticker
UPDATE etf_dataset_staging_2 t1
JOIN etf_dataset_staging_2 t2
ON t1.fund_name = t2.fund_name
SET t1.ticker = t2.ticker
WHERE (t1.ticker IS NULL OR t1.ticker= '')
AND t2.ticker IS NOT NULL
AND t2.ticker != '';

-- CHECK FOR FAKE NULL VALUES
SELECT * FROM etf_dataset_staging_2
WHERE ticker IS NULL OR ticker = 'null'
   OR fund_name IS NULL OR fund_name = 'null'
   OR inception_date IS NULL
   OR expense_ratio IS NULL OR expense_ratio = 'null'
   OR aum_millions IS NULL OR aum_millions = 'null'
   OR asset_class IS NULL OR asset_class = 'null'
   OR issuer IS NULL OR issuer = 'null'
   OR average_volume IS NULL OR average_volume = 'null'
   OR ytd_return IS NULL OR ytd_return = 'null'
   OR dividend_yield IS NULL OR dividend_yield = 'null';
   
-- FIX THE TEXT "NULL" PROBLEM
-- Convert text "NULL" and "null" to actual NULL in aum_millions
UPDATE etf_dataset_staging_2
SET aum_millions = NULL
WHERE aum_millions = 'NULL' OR aum_millions = 'null';

-- Convert text "NULL" and "null" to actual NULL in dividend_yield
UPDATE etf_dataset_staging_2
SET dividend_yield = NULL
WHERE dividend_yield = 'NULL' OR dividend_yield = 'null';

-- Also fix the "N/A" in dividend_yield
UPDATE etf_dataset_staging_2
SET dividend_yield = NULL
WHERE dividend_yield = 'N/A';

-- Check if any fake NULLs remain in ALL text columns
SELECT *
FROM etf_dataset_staging_2
WHERE ticker = 'NULL' OR ticker = 'null'
   OR fund_name = 'NULL' OR fund_name = 'null'
   OR aum_millions = 'NULL' OR aum_millions = 'null'
   OR asset_class = 'NULL' OR asset_class = 'null'
   OR issuer = 'NULL' OR issuer = 'null'
   OR dividend_yield = 'NULL' OR dividend_yield = 'null'
   OR dividend_yield = 'N/A';
   
SELECT *
FROM etf_dataset_staging_2;
   
-- CHECK FOR EMPTY STRINGS, SPACES OR '0'
SELECT * FROM etf_dataset_staging_2
WHERE ticker = '' OR ticker = '0' OR TRIM(ticker) = ''
   OR fund_name = '' OR fund_name = '0' OR TRIM(fund_name) = ''
   OR aum_millions = '' OR aum_millions = '0' OR TRIM(aum_millions) = ''
   OR asset_class = '' OR asset_class = '0' OR TRIM(asset_class) = ''
   OR issuer = '' OR issuer = '0' OR TRIM(issuer) = ''
   OR dividend_yield = '' OR dividend_yield = '0' OR TRIM(dividend_yield) = '';

-- Identify correct row
SELECT *
FROM etf_dataset_staging_2
WHERE (aum_millions = '' OR aum_millions = '0' OR TRIM(aum_millions) = '');

-- Set value to NULL
UPDATE etf_dataset_staging_2
SET aum_millions = NULL
WHERE (aum_millions = '' OR aum_millions = '0' OR TRIM(aum_millions) = '');

-- Identify correct row
SELECT *
FROM etf_dataset_staging_2
WHERE (dividend_yield = '' OR dividend_yield = '0' OR TRIM(dividend_yield) = '');

UPDATE etf_dataset_staging_2
SET dividend_yield = NULL
WHERE (dividend_yield = '' OR dividend_yield = '0' OR TRIM(dividend_yield) = '');

-- Limit expense ratio values to 2 decimals
UPDATE etf_dataset_staging_2
SET expense_ratio = 0.09
WHERE ticker = 'SPY';

-- The table looks fine now
SELECT *
FROM etf_dataset_staging_2;
