
/*=========================================================
PROJECT   : Victoria Airbnb Market Analysis
FILE      : 01_Data_Preparation.sql
DATABASE  : airbnb_victoria
TOOL      : SQL Server (SSMS)

OBJECTIVE :
Validate, profile, clean and prepare the Victoria
Airbnb dataset for downstream business analysis and
Power BI reporting.

OUTPUT :
vw_airbnb_clean

STRUCTURE :
Section 1 → Data Validation
Section 2 → Data Quality Assessment
Section 3 → Data Profiling & Outlier Analysis
Section 4 → Data Cleaning
Section 5 → View Creation

NOTE :
This file focuses exclusively on data preparation.
All business questions are executed separately using
the analytical view created in Section 5.
=========================================================*/

SELECT DB_NAME() AS CurrentDatabase;

USE [airbnb_victoria];
GO

/*=========================================================
SECTION 1 : DATA VALIDATION
=========================================================*/

-- -------------------------------------------------------
-- 1.1 Total Listings
-- -------------------------------------------------------
-- PURPOSE : Confirm full dataset was imported correctly.
-- -------------------------------------------------------

SELECT
    COUNT(*) AS TotalListings
FROM stg_airbnb;

/*
RESULT  : 3,396 listings
FINDING : Dataset imported successfully.
*/

-- -------------------------------------------------------
-- 1.2 Duplicate Check
-- -------------------------------------------------------
-- PURPOSE : Verify listing IDs are unique.
--           Any result here indicates a data load issue.
-- -------------------------------------------------------

SELECT
    id,
    COUNT(*) AS DuplicateCount
FROM stg_airbnb
GROUP BY id
HAVING COUNT(*) > 1;

/*
RESULT  : No rows returned.
FINDING : All listing IDs are unique. No duplicates found.
*/

-- -------------------------------------------------------
-- 1.3 NULL Check on Critical Fields
-- -------------------------------------------------------
-- PURPOSE : Identify NULLs in fields used for grouping
--           in the below queries. NULL host_id or
--           neighbourhood_cleansed would distort
--           all GROUP BY aggregations.
-- -------------------------------------------------------

SELECT
    SUM(CASE WHEN host_id                IS NULL THEN 1 ELSE 0 END) AS NullHostID,
    SUM(CASE WHEN neighbourhood_cleansed IS NULL THEN 1 ELSE 0 END) AS NullNeighbourhood,
    SUM(CASE WHEN room_type              IS NULL THEN 1 ELSE 0 END) AS NullRoomType,
    SUM(CASE WHEN host_is_superhost      IS NULL THEN 1 ELSE 0 END) AS NullSuperhost
FROM stg_airbnb;

/*
RESULT  :
NullHostID    NullNeighbourhood    NullRoomType    NullSuperhost
---------------------------------------------------------------
0             0                   0               101

FINDING :
    - host_id, neighbourhood_cleansed, and room_type have
      no NULLs — all GROUP BY aggregations on these fields
      are reliable.

    - host_is_superhost has 101 NULLs (3.0% of 3,396 raw
      listings). These listings likely belong to new or
      inactive host accounts that have never been evaluated
      for Superhost status by Airbnb.

    - These 101 listings are excluded from BQ2 (Superhost
      analysis) via WHERE host_is_superhost IS NOT NULL.
      The remaining 2,781 listings provide a sufficient
      sample for that comparison.
*/

-- -------------------------------------------------------
-- 1.4 Market Coverage
-- -------------------------------------------------------
-- PURPOSE : Understand the breadth of the dataset across
--           hosts, neighborhoods and room types.
-- -------------------------------------------------------

SELECT
    COUNT(DISTINCT host_id)               AS TotalHosts,
    COUNT(DISTINCT neighbourhood_cleansed) AS Neighborhoods,
    COUNT(DISTINCT room_type)              AS RoomTypes
FROM stg_airbnb;

/*
RESULT  :
    Hosts         : 2,341
    Neighborhoods : 29
    Room Types    : 4

FINDING : Dataset covers 29 neighborhoods across 2,341
          unique hosts with 4 distinct room types,
          providing sufficient market coverage for analysis.
*/


/*=========================================================
SECTION 2 : DATA QUALITY ASSESSMENT
=========================================================*/

-- -------------------------------------------------------
-- 2.1 Missing Value Analysis
-- -------------------------------------------------------
-- PURPOSE : Quantify missingness across key analytical
--           fields to inform cleaning decisions.
-- -------------------------------------------------------

SELECT
    SUM(CASE WHEN price                    IS NULL THEN 1 ELSE 0 END) AS MissingPrice,
    SUM(CASE WHEN estimated_revenue_l365d  IS NULL THEN 1 ELSE 0 END) AS MissingRevenue,
    SUM(CASE WHEN bedrooms                 IS NULL THEN 1 ELSE 0 END) AS MissingBedrooms,
    COUNT(*)                                                           AS TotalListings
FROM stg_airbnb;

/*
RESULT  :
    Missing Price    : 514  (15.1% of total)
    Missing Revenue  : 514  (15.1% of total)
    Missing Bedrooms :  75  ( 2.2% of total)

FINDING :
    - 514 listings are missing both price and revenue, 
      these are excluded from the clean view as they
      cannot contribute to any pricing or revenue analysis.

    - Missing bedrooms (75) is minor and acceptable.
*/

-- -------------------------------------------------------
-- 2.2 Room Type Distribution
-- -------------------------------------------------------
-- PURPOSE : Understand listing composition.
--           Run on raw table to capture full picture
--           before any filtering is applied.
-- -------------------------------------------------------

SELECT
    room_type,
    COUNT(*)                                                   AS Listings,
    CAST(
        ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)
    AS DECIMAL(5,1))                                           AS PctOfTotal
FROM stg_airbnb
GROUP BY room_type
ORDER BY Listings DESC;

/*
RESULT  :
    Entire home/apt : 2,958  (87.1%)
    Private room    :   430  (12.7%)
    Shared room     :     7  ( 0.2%)
    Hotel room      :     1  ( 0.0%)

FINDING :
    Entire homes dominate at 87% of listings.
    Hotel room (1 listing) and shared rooms (7 listings)
    have sample sizes too small to draw conclusions from.
*/


/*=========================================================
SECTION 3 : DATA PROFILING + OUTLIER CHECKS
=========================================================*/

-- -------------------------------------------------------
-- 3.1 Price and Revenue Distribution + Percentile Check
-- -------------------------------------------------------
-- PURPOSE : Min/Max alone can mask skew. Percentile
--           check confirms whether extreme values are
--           genuine outliers or data errors.
-- -------------------------------------------------------

SELECT DISTINCT

    'Price' AS Metric,

    FORMAT(MIN(price) OVER (), 'N0') AS Min,
    FORMAT(MAX(price) OVER (), 'N0') AS Max,
    FORMAT(CAST(AVG(price) OVER () AS DECIMAL(10,2)), 'N2') AS Avg,

    FORMAT(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY price) OVER (), 'N0') AS P25,
    FORMAT(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY price) OVER (), 'N0') AS P50,
    FORMAT(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY price) OVER (), 'N0') AS P75,
    FORMAT(PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY price) OVER (), 'N0') AS P90,
    FORMAT(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY price) OVER (), 'N0') AS P95,
    FORMAT(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY price) OVER (), 'N0') AS P99

FROM stg_airbnb

WHERE price IS NOT NULL

UNION ALL 

SELECT DISTINCT

    'Revenue' AS Metric,

    FORMAT(MIN(estimated_revenue_l365d) OVER (), 'N0') AS Min,
    FORMAT(MAX(estimated_revenue_l365d) OVER (), 'N0') AS Max,
    FORMAT(CAST(AVG(estimated_revenue_l365d) OVER () AS DECIMAL(15,2)), 'N2') AS Avg,
    FORMAT(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY estimated_revenue_l365d) OVER (), 'N0') AS P25,
    FORMAT(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY estimated_revenue_l365d) OVER (), 'N0') AS P50,
    FORMAT(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY estimated_revenue_l365d) OVER (), 'N0') AS P75,
    FORMAT(PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY estimated_revenue_l365d) OVER (), 'N0') AS P90,
    FORMAT(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY estimated_revenue_l365d) OVER (), 'N0') AS P95,
    FORMAT(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY estimated_revenue_l365d) OVER (), 'N0') AS P99

FROM stg_airbnb

WHERE estimated_revenue_l365d IS NOT NULL;



/*
RESULT :
Metric      Min      Max        Avg        P25      P50      P75      P90      P95      P99
------------------------------------------------------------------------------------------------
Price       25       1,906      212.47     114      159      251      381      503      943
Revenue     0      454,920   22,582.49   4,370   18,240   31,365   50,234   67,382   108,814

FINDING :

PRICE DISTRIBUTION :
    - Median nightly price is $159. Half of all Victoria
      listings charge below this amount.

    - The mean ($212) sits well above the median ($159),
      confirming right skew driven by the top 1% luxury
      listings (>$943/night).

REVENUE DISTRIBUTION :
    - Median annual revenue is $18,240 — meaning half of
      all Victoria listings earn below this amount.

    - P99 sits at $108,814. The $454,920 max (Island Luxury
      Oceanside Estate) is therefore an extreme outlier —
      sitting $346,106 above P99, mirroring the same
      outlier gap seen in price.

COMBINED INSIGHT :
    - Both price and revenue follow the same right-skewed
      pattern — a long tail of modest performers with a
      small cluster of high-value outliers distorting the
      mean upward.

    - A typical Victoria Airbnb listing charges $159/night
      and earns $18,240/year — not the $212/$22,582
      suggested by the mean.
*/

-- -------------------------------------------------------
-- Outlier Investigation : Price AND Revenue
-- -------------------------------------------------------
-- PURPOSE : Investigate top 1% price listings (above P99)
--           and top 10 revenue listings.
-- -------------------------------------------------------

-- PART A : Price Outliers — listings above P99 ($942.95)
SELECT
    'Price Outlier'                                                     AS OutlierType,
    name,
    host_name,
    neighbourhood_cleansed,
    room_type,
    bedrooms,
    price,
    FORMAT(estimated_revenue_l365d, 'N0')                               AS Revenue,
    estimated_occupancy_l365d                                           AS OccupiedNights,
    CASE
        WHEN estimated_revenue_l365d = 0 THEN 'Inactive'
        ELSE                                  'Active'
    END                                                                 AS Status
FROM stg_airbnb
WHERE price > 942.95
  AND estimated_revenue_l365d IS NOT NULL

UNION ALL

-- PART B : Revenue Outliers — top 10 by annual revenue
SELECT TOP 10
    'Revenue Outlier'                                                   AS OutlierType,
    name,
    host_name,
    neighbourhood_cleansed,
    room_type,
    bedrooms,
    price,
    FORMAT(estimated_revenue_l365d, 'N0')                               AS Revenue,
    estimated_occupancy_l365d                                           AS OccupiedNights,
    CASE
        WHEN estimated_revenue_l365d = 0 THEN 'Inactive'
        ELSE                                  'Active'
    END                                                                 AS Status
FROM stg_airbnb
WHERE estimated_revenue_l365d IS NOT NULL
ORDER BY estimated_revenue_l365d DESC;

/*
RESULTS

PART A — PRICE OUTLIERS (Above P99: $942.95/night)
    Total listings        : 29
    Price range           : $947 – $1,906/night
    Room types            : 27 Entire home/apt, 2 Private room
    Bedrooms              : 1 – 7
    Neighborhoods         : Juan de Fuca (7), North Saanich (3),
                            Salt Spring Island (3), Colwood (3),
                            Downtown (3), Langford (3), Others (7)
    Active  (revenue > 0) : 24
    Inactive (revenue = 0): 5 — including $1,906 max (Wain Manor)

PART B — REVENUE OUTLIERS (Top 10 by Annual Revenue)
          Name                                   Host              Neighbourhood        Beds    Price       Revenue     OccNights   Status
    ---------------------------------------------------------------------------------------------------------------------------------------
         Island Luxury Oceanside Estate          Emr               Central Saanich      5       1,784       454,920     255         Active
         Pacific View Retreat                    Abhi And Monika   Colwood              3       900         229,500     255         Active
         Cheerful 5-bed New home w/view          Asha And Vinay    Langford             5       801         204,255     255         Active
         Air conditioned private 2 bed suite     Kristopher        Colwood              1       1,085       188,790     174         Active
         Charming waterfront Salt Spring B&B     Tania             Salt Spring Island   4       708         180,540     255         Active
         Oriole & Fawn Suite                     Lynn              Langford             3       700         178,500     255         Active
         Arbutus Hill                            Emr               Metchosin            4       691         176,205     255         Active
         "The Original" Luxury Getaway           Rob&Jen           Downtown             3       966         173,880     180         Active
         3Bed Modern Farmhouse                   Jacine            Saanich              3       667         170,085     255         Active
         The Sanctuary: Treetop Living           Ksenia            Salt Spring Island   3       653         166,515     255         Active

FINDINGS :

    1. The highest revenue listing generated $454,920 annually 
       and appears in both the price and revenue outlier groups.

    2. High occupancy (255 nights) drives the revenue outlier
       list more than high price. Seven of the top 10 revenue
       listings hit 255 occupied nights. The price range across
       the top 10 is $653–$1,784, confirming occupancy as the dominant factor.

    3. The $1,906 max price listing (Wain Manor) does NOT appear
       in the revenue outlier list. Zero bookings means zero
       revenue impact — a price outlier that is invisible
       in all revenue analysis.

    4. Emr appears twice in the top 10 revenue list (Island
       Luxury Oceanside Estate + Arbutus Hill), contributing
       $631,125 combined — consistent with Emr ranking as
       Victoria's #1 revenue-generating host in BQ6.

    5. Both distributions are confirmed right-skewed with
       legitimate outliers.

CONCLUSION : The outliers represent genuine listings rather than obvious data-entry errors and were retained for analysis.
             Median ($18,240) is the more accurate representation of typical performance.
*/
-- -------------------------------------------------------
-- 3.3 Occupancy Distribution
-- -------------------------------------------------------
-- PURPOSE : Validate occupancy range and quantify
--           zero-occupancy listings that remain in the
--           clean view and may suppress averages.
-- -------------------------------------------------------

SELECT
    MIN(estimated_occupancy_l365d)  AS MinOccupancy,
    MAX(estimated_occupancy_l365d)  AS MaxOccupancy,
    AVG(estimated_occupancy_l365d)  AS AvgOccupancy
FROM stg_airbnb;

/*
RESULT  : Min: 0  |  Max: 255  |  Avg: 115
FINDING : Max of 255 nights = ~70% annual occupancy.
         
          Min of 0 means inactive listings are present.
*/

-- Full occupancy band distribution
SELECT
    SUM(CASE WHEN estimated_occupancy_l365d = 0   THEN 1 ELSE 0 END) AS Zero_Nights,
    SUM(CASE WHEN estimated_occupancy_l365d BETWEEN 1  AND 30  THEN 1 ELSE 0 END) AS Under30,
    SUM(CASE WHEN estimated_occupancy_l365d BETWEEN 31 AND 90  THEN 1 ELSE 0 END) AS Under90,
    SUM(CASE WHEN estimated_occupancy_l365d BETWEEN 91 AND 180 THEN 1 ELSE 0 END) AS Under180,
    SUM(CASE WHEN estimated_occupancy_l365d > 180              THEN 1 ELSE 0 END) AS Over180,
    SUM(CASE WHEN estimated_occupancy_l365d > 240              THEN 1 ELSE 0 END) AS Over240,
    COUNT(*) AS Total
FROM stg_airbnb;

/*
RESULT  : 
Zero_Nights	    Under30	    Under90	    Under180	Over180	    Over240	    Total
---------------------------------------------------------------------------------
810	            292	        537	        743	        1014	    749	        3396

FINDING :

    1. Nearly one-quarter of listings recorded zero occupied nights.

    2. Almost 30% of listings exceeded 180 occupied nights annually.

    3. More than 22% of listings achieved over 240 occupied nights, indicating strong utilization among top performers.

    4. Occupancy levels vary significantly across Victoria's Airbnb market, from inactive listings to highly occupied properties.

*/
 --Checking whether zero occupancy listings have any revenue

SELECT
    COUNT(*) AS Listings
FROM stg_airbnb
WHERE estimated_occupancy_l365d = 0
  AND estimated_revenue_l365d > 0;

  /*
  Result:

  Listings
  --------
  0

  FINDING:

    1. No listings were found with positive revenue and zero occupied nights.

    2. This confirms that zero occupancy is consistently associated with zero revenue in the dataset.

    3. Therefore, replacing NULL revenue with 0 for listings with zero occupancy is a reasonable cleaning assumption.

  */

/*=========================================================
SECTION 4 : DATA CLEANING
=========================================================*/

----------------------------------------------------------
-- 4.1 Missing Price and Revenue Investigation
-- -------------------------------------------------------
-- PURPOSE : Determine whether listings with missing
--           revenue require imputation or exclusion.
-- -------------------------------------------------------

SELECT
    SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END) AS MissingPrice,
    SUM(CASE WHEN estimated_revenue_l365d IS NULL THEN 1 ELSE 0 END) AS MissingRevenue
FROM stg_airbnb;

/*
RESULT

MissingPrice     MissingRevenue
--------------------------------
514              514
*/

-- Revenue NULL + Occupancy Analysis

SELECT
    SUM(CASE
            WHEN estimated_revenue_l365d IS NULL
             AND estimated_occupancy_l365d = 0
            THEN 1 ELSE 0
        END) AS RevenueNull_Occ0,

    SUM(CASE
            WHEN estimated_revenue_l365d IS NULL
             AND estimated_occupancy_l365d > 0
            THEN 1 ELSE 0
        END) AS RevenueNull_OccGT0

FROM stg_airbnb;

/*
RESULT

RevenueNull_Occ0     RevenueNull_OccGT0
---------------------------------------
266                  248
*/

-- Check whether Revenue NULL + Occupancy > 0
-- survives the Price filter

SELECT
    COUNT(*) AS Listings
FROM stg_airbnb
WHERE estimated_revenue_l365d IS NULL
  AND estimated_occupancy_l365d > 0
  AND price IS NOT NULL;

/*
RESULT

Listings
--------
0


FINDINGS:

1. 514 listings contain missing price and revenue values.

2. Of the 514 revenue-null listings, 266 recorded zero occupancy while 248 recorded positive occupancy.

3. All 248 listings with positive occupancy and missing revenue also have missing price values.

4. Therefore, filtering out listings with missing price automatically removes all missing revenue records.


CLEANING DECISION

- Exclude listings where price IS NULL.

*/
-- -------------------------------------------------------
-- Section 5: VIEW CREATION
-- -------------------------------------------------------
-- PURPOSE : Create a clean analytical layer for all
--           SQL business questions and future Power BI
--           reporting.
--
-- FILTERS :
--   price IS NOT NULL
--       Removes 514 listings with missing pricing data.
--
-- FLAGS :
--   is_active
--
-- -------------------------------------------------------

DROP VIEW vw_airbnb_clean

CREATE VIEW vw_airbnb_clean AS

SELECT

    /* Listing Details */
    id,
    listing_url,
    name,

    /* Host Details */
    host_id,
    host_name,

    CASE
        WHEN host_is_superhost = 't' THEN 'Yes'
        WHEN host_is_superhost = 'f' THEN 'No'
        ELSE 'Unknown'
    END AS host_is_superhost,

    calculated_host_listings_count,

    /* Location */
    neighbourhood_cleansed,
    latitude,
    longitude,

    /* Property Attributes */
    room_type,
    bedrooms,
    bathrooms,
    accommodates,

    /* Booking Rules & Availability */
    minimum_nights,
    maximum_nights,
    availability_365,

    /* Pricing & Compliance */
    price,
    license,

    /* Performance Metrics */
    estimated_occupancy_l365d,
    estimated_revenue_l365d,

    /* Activity Flag */
    CASE
        WHEN estimated_occupancy_l365d > 0 THEN 1
        ELSE 0
    END AS is_active

FROM stg_airbnb

WHERE price IS NOT NULL;
GO

-- Validating View

SELECT
    COUNT(*) AS Listings
FROM vw_airbnb_clean;

/*
RESULT  :
    TotalListings   : 2,882

FINDING :
    Clean analytical layer created successfully.
    All BQ queries run against this view.
*/

