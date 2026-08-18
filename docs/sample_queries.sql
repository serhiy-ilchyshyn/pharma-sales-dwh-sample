/* =====================================================================================
   Sample analytical queries for the Pharma Sales star schema.
   All joins use durable keys (SK*KeyID). For SCD2 dimensions, filter EndDate IS NULL
   to get the current version, or join on the date window for point-in-time analysis.
   ===================================================================================== */

/* 1. Net sales by month and product brand ------------------------------------------- */
SELECT
    d.[YearMonth],
    p.[Brand],
    SUM(f.[QuantityUnits]) AS TotalUnits,
    SUM(f.[NetAmount])     AS TotalNetAmount
FROM [dwh].[FctSales] AS f
JOIN [dwh].[DimDate]    AS d ON d.[SKDateKeyID]    = f.[SKDateKeyID]
JOIN [dwh].[DimProduct] AS p ON p.[SKProductKeyID] = f.[SKProductKeyID]
                            AND p.[EndDate] IS NULL          -- current product version
GROUP BY d.[YearMonth], p.[Brand]
ORDER BY d.[YearMonth], TotalNetAmount DESC;


/* 2. Plan attainment: actual net sales vs plan, by employee and month --------------- */
WITH actual AS (
    SELECT d.[YearMonth], f.[SKEmployeeKeyID], SUM(f.[NetAmount]) AS ActualAmount
    FROM [dwh].[FctSales] f
    JOIN [dwh].[DimDate]  d ON d.[SKDateKeyID] = f.[SKDateKeyID]
    GROUP BY d.[YearMonth], f.[SKEmployeeKeyID]
),
plan AS (
    SELECT d.[YearMonth], pl.[SKEmployeeKeyID], SUM(pl.[PlannedAmount]) AS PlannedAmount
    FROM [dwh].[FctSalesPlan] pl
    JOIN [dwh].[DimDate]      d ON d.[SKDateKeyID] = pl.[SKDateKeyID]
    GROUP BY d.[YearMonth], pl.[SKEmployeeKeyID]
)
SELECT
    e.[Name] AS Employee,
    p.[YearMonth],
    p.[PlannedAmount],
    a.[ActualAmount],
    CASE WHEN p.[PlannedAmount] > 0
         THEN CAST(100.0 * a.[ActualAmount] / p.[PlannedAmount] AS decimal(9,1)) END AS AttainmentPct
FROM plan p
JOIN [dwh].[DimEmployee] e ON e.[SKEmployeeKeyID] = p.[SKEmployeeKeyID] AND e.[EndDate] IS NULL
LEFT JOIN actual a ON a.[SKEmployeeKeyID] = p.[SKEmployeeKeyID] AND a.[YearMonth] = p.[YearMonth]
ORDER BY p.[YearMonth], AttainmentPct DESC;


/* 3. Call-plan execution: completed visits vs planned target frequency --------------- */
WITH planned AS (
    SELECT d.[YearMonth], tf.[SKEmployeeKeyID], SUM(tf.[QuantityVisitsPlanned]) AS PlannedVisits
    FROM [dwh].[FctTargetFrequency] tf
    JOIN [dwh].[DimDate] d ON d.[SKDateKeyID] = tf.[SKDateKeyID]
    GROUP BY d.[YearMonth], tf.[SKEmployeeKeyID]
),
done AS (
    SELECT d.[YearMonth], v.[SKEmployeeKeyID], SUM(v.[VisitCount]) AS CompletedVisits
    FROM [dwh].[FctVisit] v
    JOIN [dwh].[DimDate]  d ON d.[SKDateKeyID] = v.[SKDateKeyID]
    WHERE v.[IsCompleted] = 1
    GROUP BY d.[YearMonth], v.[SKEmployeeKeyID]
)
SELECT
    e.[Name] AS Employee,
    p.[YearMonth],
    p.[PlannedVisits],
    ISNULL(dn.[CompletedVisits], 0) AS CompletedVisits
FROM planned p
JOIN [dwh].[DimEmployee] e ON e.[SKEmployeeKeyID] = p.[SKEmployeeKeyID] AND e.[EndDate] IS NULL
LEFT JOIN done dn ON dn.[SKEmployeeKeyID] = p.[SKEmployeeKeyID] AND dn.[YearMonth] = p.[YearMonth]
ORDER BY p.[YearMonth], Employee;


/* 4. Latest stock position by account and product (periodic snapshot) --------------- */
SELECT
    ca.[Name] AS Account,
    pr.[Name] AS Product,
    d.[DateValue] AS SnapshotDate,
    i.[QuantityOnHand],
    i.[StockValue]
FROM [dwh].[FctInventorySnapshot] i
JOIN [dwh].[DimDate]          d  ON d.[SKDateKeyID]          = i.[SKDateKeyID]
JOIN [dwh].[DimClientAccount] ca ON ca.[SKClientAccountKeyID] = i.[SKClientAccountKeyID] AND ca.[EndDate] IS NULL
JOIN [dwh].[DimProduct]       pr ON pr.[SKProductKeyID]       = i.[SKProductKeyID]       AND pr.[EndDate] IS NULL
WHERE d.[DateValue] = (SELECT MAX(d2.[DateValue])
                       FROM [dwh].[FctInventorySnapshot] i2
                       JOIN [dwh].[DimDate] d2 ON d2.[SKDateKeyID] = i2.[SKDateKeyID])
ORDER BY i.[StockValue] DESC;


/* 5. Visit mix by activity type and channel ----------------------------------------- */
SELECT
    at.[Category],
    at.[Channel],
    at.[Name] AS ActivityType,
    COUNT(*)                              AS Visits,
    SUM(CASE WHEN v.[IsCompleted] = 1 THEN 1 ELSE 0 END) AS Completed,
    AVG(CAST(v.[DurationMinutes] AS float)) AS AvgDurationMin
FROM [dwh].[FctVisit] v
JOIN [dwh].[DimActivityType] at ON at.[SKActivityTypeKeyID] = v.[SKActivityTypeKeyID] AND at.[EndDate] IS NULL
GROUP BY at.[Category], at.[Channel], at.[Name]
ORDER BY Visits DESC;
