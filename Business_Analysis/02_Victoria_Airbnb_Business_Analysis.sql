
/*=========================================================
PROJECT   : Victoria Airbnb Market Analysis
FILE      : 02_Victoria_Airbnb_Business_Analysis.sql
DATABASE  : airbnb_victoria
TOOL      : SQL Server (SSMS)

OBJECTIVE :
Analyze Victoria's Airbnb market using the clean
analytical layer (vw_airbnb_clean) to uncover
insights related to pricing, occupancy, revenue,
host performance, compliance and market structure.

DATA SOURCE :
vw_airbnb_clean

STRUCTURE :
Business Question 1 → Neighborhood Revenue Analysis


Business Question 2 → Superhost vs Regular Host
                       Performance

Business Question 3 → Room Type Performance

Business Question 4 → Licensing Compliance &
                       Economic Significance

Business Question 5 → Market Concentration Among
                       Multi-Listing Hosts

OUTPUT :
Actionable business insights suitable for Power BI
visualization and stakeholder reporting.

=========================================================*/
USE [airbnb_victoria];
GO
/*==========================================================
BUSINESS QUESTION 1

Which neighborhoods have the highest average listing revenue?
============================================================*/

SELECT TOP 10

    neighbourhood_cleansed AS Neighbourhood,
    COUNT(*) AS Listings,
    FORMAT(CAST(AVG(price) AS DECIMAL(10,0)), 'N0') AS AvgPrice,
    FORMAT(CAST(AVG(estimated_revenue_l365d) AS DECIMAL(10,0)), 'N0') AS AvgRevenue,
    FORMAT(CAST(AVG(estimated_occupancy_l365d) AS DECIMAL(10,0)), 'N0') AS AvgOccupancy

FROM vw_airbnb_clean
GROUP BY neighbourhood_cleansed
ORDER BY AVG(estimated_revenue_l365d) DESC;

/*
RESULTS

Neighbourhood	    Listings	AvgPrice	AvgRevenue	AvgOccupancy
Metchosin	        33	        243	        33,428	    129
Central Saanich	    71	        240	        31,881	    151
Juan de Fuca	    350	        293	        30,132	    121
Salt Spring Island	263 	    240	        27,522	    129
Sooke	            152	        225	        26,145	    134
North Jubilee	    9	        145	        24,048	    168
Sidney	            53	        166	        23,870	    148
North Saanich	    78	        272	        23,665	    127
Saanich	            394	        171	        23,500	    145
Oak Bay	            36	        274	        23,157	    118


FINDINGS

1. Rural/peripheral neighborhoods outperform urban ones on revenue
        Metchosin and Central Saanich top the revenue chart despite minimal listings, likely driven by premium waterfront or rural properties commanding higher nightly rates.
2. Juan de Fuca is the standout high-volume performer
        With 350 listings and $30,132 avg revenue — backed by the highest avg price ($293) in the group — it's the only neighborhood combining scale with strong yield.
3. More listings ≠ more revenue
        Saanich has the most listings (394) yet ranks last in the top 10 by revenue ($23,500) — 42% below Metchosin's 33 listings. Market size does not guarantee returns.
4. Nightly price drives revenue more than occupancy
        North Jubilee has the highest occupancy (168 nights) but ranks 6th in revenue due to a low $145 nightly rate. Juan de Fuca earns more with just 121 occupied nights by charging $293/night.
5. The $225–$293 nightly rate band is the revenue sweet spot
        Every top-5 revenue neighborhood falls in this pricing range. Neighborhoods priced below ~$200/night consistently underperform regardless of occupancy.

Price ceiling matters more than occupancy for maximizing Airbnb revenue in Victoria. Juan de Fuca offers the best combination of scale and yield in the dataset.

*/

/*=========================================================
BUSINESS QUESTION 2

Do Superhosts outperform regular hosts?
=========================================================*/

SELECT

CASE

    WHEN host_is_superhost='Yes'
    THEN 'Superhost'

    WHEN host_is_superhost='No'
    THEN 'Regular Host'

END AS HostType,

COUNT(*) AS Listings,

ROUND(
AVG(price),
0
) AS AvgPrice,

ROUND(
AVG(estimated_revenue_l365d),
0
) AS AvgRevenue,

ROUND(
AVG(estimated_occupancy_l365d),
0
) AS AvgOccupancy


FROM vw_airbnb_clean


WHERE host_is_superhost In ('Yes','No')


GROUP BY host_is_superhost;


/*
RESULTS

HostType	    Listings	AvgPrice	AvgRevenue	AvgOccupancy	
Superhost	    1612	    210	        28082	    152	            
Regular Host	1190	    217	        14872	    78	           


FINDINGS

1. Superhosts generated approximately 89% higher average revenue than Regular Hosts.

2. Despite charging slightly lower prices, Superhosts achieved substantially higher occupancy.

3. Higher occupancy appears to contribute more to revenue growth than higher pricing.

*/


/*=========================================================
BUSINESS QUESTION 3

Which room type maximizes revenue and occupancy?
=========================================================*/

SELECT
    room_type,
    COUNT(*)                                   AS Listings,
    ROUND(AVG(price),                     0)   AS AvgPrice,
    ROUND(AVG(estimated_revenue_l365d),   0)   AS AvgRevenue,
    ROUND(AVG(estimated_occupancy_l365d), 0)   AS AvgOccupancy
   
FROM vw_airbnb_clean
GROUP BY room_type
ORDER BY AVG(estimated_revenue_l365d) DESC;

/*
RESULTS

Room Type        Listings  AvgPrice  AvgRevenue  AvgOccupancy 
--------------------------------------------------------------
Hotel room              1     292      40,296        138          
Entire home/apt     2,528     223      23,849        122         
Private room          346     138      13,614        113          
Shared room             7      87       6,124         70         

FINDINGS

1. Hotel room result is statistically meaningless.
   A single listing cannot represent a category. Its $40,296 avg
   revenue is one data point, not a market signal. We can exclude from
   strategic conclusions.

2. Entire homes are the clear market standard.
   With 2,528 listings (87% of the clean view), entire homes deliver
   $23,849 avg revenue at 122 occupied nights — the only room type
   with sufficient scale for reliable conclusions.

3. Private rooms are a viable secondary segment.
   At 113 occupied nights, private rooms show similar demand 
   but generate only $13,614 avg revenue due to a $138 vs $223 nightly rate gap. 
   The occupancy is there, the price ceiling is not.

4. Shared rooms underperform across every metric.
   Lowest price ($87) and lowest occupancy (70 nights),
   With only 7 listings, the segment is effectively non-existent
   in Victoria's market.

BOTTOM LINE : Entire homes are the only room type worth benchmarking
              in Victoria. Private rooms are second with a
              hard revenue ceiling set by nightly rate, not occupancy.
*/

/*=========================================================
BUSINESS QUESTION 4

What is the level of licensing compliance among Airbnb
listings, and how economically significant are
unregistered listings?
=========================================================*/

WITH LicenseStatus AS
(
    SELECT
        CASE
            WHEN license IS NULL THEN 'No License Information'
            WHEN license LIKE '%Exempt%' THEN 'Exempt'
            ELSE 'Registered'
        END AS LicenseCategory,

        estimated_revenue_l365d,
        estimated_occupancy_l365d

    FROM vw_airbnb_clean
)

SELECT

    LicenseCategory,

    COUNT(*) AS Listings,

    CAST(
        ROUND(
            COUNT(*) * 100.0 /
            SUM(COUNT(*)) OVER (),
            1
        )
    AS DECIMAL(5,1)
    ) AS PctOfListings,

    '$' +
    FORMAT(
    CAST(SUM(estimated_revenue_l365d) / 1000000.0 AS DECIMAL(10,1)),
    'N1')
    + 'M' AS TotalRevenue,

    CAST(
        ROUND(
            SUM(estimated_revenue_l365d) * 100.0 /
            SUM(SUM(estimated_revenue_l365d)) OVER (),
            1
        )
    AS DECIMAL(5,1)
    ) AS RevenueSharePct,

    FORMAT(
        CAST(
            AVG(estimated_revenue_l365d)
            AS DECIMAL(12,0)
        ),
        'N0'
    ) AS AvgRevenue,

    ROUND(
        AVG(estimated_occupancy_l365d),
        0
    ) AS AvgOccupancy,

    FORMAT(
        MAX(estimated_revenue_l365d),
        'N0'
    ) AS MaxRevenue

FROM LicenseStatus

GROUP BY LicenseCategory

ORDER BY Listings DESC;

/*
RESULTS

| License Category       | Listings | Listing Share | Total Revenue | Revenue Share | Avg Revenue | Avg Occupancy | Max Revenue |
| ---------------------- | -------: | ------------: | ------------: | ------------: | ----------: | ------------: | ----------: |
| Registered             |    2,041 |         70.8% |        $51.9M |         79.7% |      $25.4K |           134 |     $454.9K |
| No License Information |      567 |         19.7% |         $7.9M |         12.2% |      $14.0K |            91 |     $229.5K |
| Exempt                 |      274 |          9.5% |         $5.3M |          8.1% |      $19.2K |            89 |     $110.2K |

FINDING:

    1. Registered listings dominate the market, accounting for 70.8% of listings and 79.7% of total revenue.

    2. Listings with no license information represent 19.7% of listings and generate $7.9M annually, indicating meaningful economic activity outside the registered segment.

    3. Registered listings achieve the strongest performance, averaging $25.4K revenue and 134 occupied nights per year.

    4. Despite lower average performance, the highest-earning unregistered listing generated $229.5K annually, suggesting the presence of commercially significant operators outside the registered category.

    5. Exempt listings contribute 8.1% of platform revenue while maintaining occupancy levels similar to the unregistered segment.
*/

/*=========================================================
BUSINESS QUESTION 5

To what extent is Victoria's Airbnb market
concentrated among multi-listing operators?
=========================================================*/

SELECT

    CASE
        WHEN calculated_host_listings_count = 1
            THEN 'Individual Host(1)'

        WHEN calculated_host_listings_count BETWEEN 2 AND 4
            THEN 'Small Portfolio Host(2-4)'

        WHEN calculated_host_listings_count BETWEEN 5 AND 9
            THEN 'Large Portfolio(5-9)'

        ELSE 'Commercial Operator(10+)'
    END AS HostCategory,

    COUNT(DISTINCT host_id) AS Hosts,

    COUNT(*) AS Listings,

    CAST(
        ROUND(
            COUNT(*) * 100.0 /
            SUM(COUNT(*)) OVER (),
            1
        ) AS DECIMAL(5,1)
    ) AS ListingSharePct,

    '$' +
    FORMAT(
        CAST(
            SUM(estimated_revenue_l365d) / 1000000.0
            AS DECIMAL(10,1)
        ),
        'N1'
    ) + 'M' AS TotalRevenue,

    CAST(
        ROUND(
            SUM(estimated_revenue_l365d) * 100.0 /
            SUM(SUM(estimated_revenue_l365d)) OVER (),
            1
        )
    AS DECIMAL(5,1)
    ) AS RevenueSharePct,

    FORMAT(
        CAST(
            AVG(estimated_revenue_l365d)
            AS DECIMAL(12,0)
        ),
        'N0'
    ) AS AvgRevenue

FROM vw_airbnb_clean

GROUP BY

    CASE
        WHEN calculated_host_listings_count = 1
            THEN 'Individual Host(1)'

        WHEN calculated_host_listings_count BETWEEN 2 AND 4
            THEN 'Small Portfolio Host(2-4)'

        WHEN calculated_host_listings_count BETWEEN 5 AND 9
            THEN 'Large Portfolio(5-9)'

        ELSE 'Commercial Operator(10+)'
    END

ORDER BY
    MIN(calculated_host_listings_count);

/*
RESULTS

HostCategory                Hosts   Listings   ListingSharePct   TotalRevenue   RevenueSharePct   AvgRevenue
------------------------------------------------------------------------------------------------------------
Individual Host             1,669    1,669          57.9%          $41.0M            63.0%          24,562

Small Portfolio Host          300     658           22.8%          $16.2M            24.9%          24,621

Large Portfolio               34      184            6.4%           $3.4M            5.2%           18,565

Commercial Operator           20      371            12.9%          $4.5M            6.9%           12,057


## FINDINGS

| Insight Area         | Finding                                                                                                                                                         |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Market Structure     | Individual Hosts (1 Listing) account for 57.9% of listings and generate 63.0% of total revenue, 
                         making them the dominant market segment both numerically and economically. 

| Small Portfolio Hosts| Small Portfolio Hosts (2–4 Listings) manage 22.8% of listings and contribute 24.9% of total revenue, 
                         demonstrating a strong market presence despite their smaller size.

| Commercial Activity  | Large Portfolio Hosts (5–9 Listings) and Commercial Operators (10+ Listings) collectively control 19.3% of listings 
                         but generate only 12.1% of total revenue, suggesting that scale alone does not guarantee stronger financial performance. 

| Listing Performance  | Individual Hosts and Small Portfolio Hosts generate approximately $24.6K average revenue per listing, substantially outperforming Commercial Operators, 
                         whose average revenue per listing is approximately $12.1K.

| Market Concentration | Although only 20 Commercial Operators exist in the market, they collectively manage 371 listings (12.9% of all listings), 
                         indicating some concentration in listing ownership while remaining a relatively small contributor to overall revenue. 

| Overall Conclusion   | Victoria's Airbnb market is dominated by smaller-scale hosts and appears fragmented rather than highly concentrated. 
                         While larger operators contribute meaningfully to listing supply, the majority of revenue is generated by Individual and Small Portfolio Hosts. 
*/
