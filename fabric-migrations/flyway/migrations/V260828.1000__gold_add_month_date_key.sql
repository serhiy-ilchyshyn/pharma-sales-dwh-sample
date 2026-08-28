-- ClickUp: PHARMA-GOLD-004
-- Ключ дати в місячних агрегатах: [MonthStartDate] = перший день місяця.
--
-- Навіщо: без дати місячні агрегати неможливо звʼязати з календарем у семантичній моделі,
-- а отже не працюють ані квартали, ані порівняння з минулим роком — саме те, чого
-- найчастіше просять в ad-hoc звітності. Денний агрегат уже має SKDateID, ці шість — ні.
--
-- Колонка додається В КІНЕЦЬ таблиці й останньою в проєкції view: spFullGoldObject
-- вставляє через v.*, тому порядок колонок має збігатися.
GO
--IMPORTANT
USE [whgold];
--IMPORTANT
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_SCHEMA = 'dwh' AND TABLE_NAME = 'AggSalesMonthly' AND COLUMN_NAME = 'MonthStartDate')
    EXEC('ALTER TABLE [dwh].[AggSalesMonthly] ADD [MonthStartDate] date NULL');
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_SCHEMA = 'dwh' AND TABLE_NAME = 'AggVisitMonthly' AND COLUMN_NAME = 'MonthStartDate')
    EXEC('ALTER TABLE [dwh].[AggVisitMonthly] ADD [MonthStartDate] date NULL');
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_SCHEMA = 'dwh' AND TABLE_NAME = 'AggPrescriptionMonthly' AND COLUMN_NAME = 'MonthStartDate')
    EXEC('ALTER TABLE [dwh].[AggPrescriptionMonthly] ADD [MonthStartDate] date NULL');
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_SCHEMA = 'dwh' AND TABLE_NAME = 'AggInventoryMonthly' AND COLUMN_NAME = 'MonthStartDate')
    EXEC('ALTER TABLE [dwh].[AggInventoryMonthly] ADD [MonthStartDate] date NULL');
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_SCHEMA = 'dwh' AND TABLE_NAME = 'AggAdverseEventMonthly' AND COLUMN_NAME = 'MonthStartDate')
    EXEC('ALTER TABLE [dwh].[AggAdverseEventMonthly] ADD [MonthStartDate] date NULL');
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_SCHEMA = 'dwh' AND TABLE_NAME = 'AggPromoEffectMonthly' AND COLUMN_NAME = 'MonthStartDate')
    EXEC('ALTER TABLE [dwh].[AggPromoEffectMonthly] ADD [MonthStartDate] date NULL');
GO

CREATE OR ALTER VIEW [dwh].[vAggSalesMonthly] AS
SELECT
      CONCAT(CAST(dd.[#Year] AS varchar(4)), '-', RIGHT(CONCAT('0', CAST(dd.[#Month] AS varchar(2))), 2)) AS YearMonth
    , dd.[#Year]                               AS YearNum
    , dd.[#Month]                              AS MonthNum
    , rp.SKProductKeyID                        AS SKProductID
    , re.SKEmployeeKeyID                       AS SKEmployeeID
    , ISNULL(r.Name, 'N/A')                    AS Region
    , ISNULL(ca.AccountType, 'N/A')            AS AccountType
    , COUNT(1)                                 AS OrderLineCnt
    , COUNT(DISTINCT rca.SKClientAccountKeyID) AS ClientAccountCnt
    , SUM(CASE WHEN f.IsReturn = 0 THEN f.Qty ELSE 0 END)       AS TotalQty
    , SUM(CASE WHEN f.IsReturn = 0 THEN f.NetAmount ELSE 0 END) AS TotalNetAmount
    , SUM(CASE WHEN f.IsReturn = 1 THEN f.Qty ELSE 0 END)       AS ReturnQty
    , SUM(CASE WHEN f.IsReturn = 1 THEN f.NetAmount ELSE 0 END) AS ReturnNetAmount
    , DATEFROMPARTS(dd.[#Year], dd.[#Month], 1)   AS MonthStartDate
FROM [whsilver].[dwh].[FctSales] AS f
INNER JOIN [whsilver].[dwh].[DimDate] AS dd ON dd.SKDateID = f.SKDateID AND dd.SKDateID <> -1
LEFT JOIN [whsilver].[dwh].[RefProduct]       AS rp  ON rp.SKRefProductKeyID       = f.SKRefProductKeyID       AND rp.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[RefEmployee]      AS re  ON re.SKRefEmployeeKeyID      = f.SKRefEmployeeKeyID      AND re.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[RefClientAccount] AS rca ON rca.SKRefClientAccountKeyID = f.SKRefClientAccountKeyID AND rca.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[DimClientAccount] AS ca  ON ca.SKClientAccountKeyID    = rca.SKClientAccountKeyID  AND ca.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[DimRegion]        AS r   ON r.SKRegionKeyID            = ca.SKRegionKeyID          AND r.EndDate IS NULL
GROUP BY
      CONCAT(CAST(dd.[#Year] AS varchar(4)), '-', RIGHT(CONCAT('0', CAST(dd.[#Month] AS varchar(2))), 2))
    , dd.[#Year], dd.[#Month]
    , rp.SKProductKeyID, re.SKEmployeeKeyID
    , ISNULL(r.Name, 'N/A'), ISNULL(ca.AccountType, 'N/A')

GO

CREATE OR ALTER VIEW [dwh].[vAggVisitMonthly] AS
SELECT
      CONCAT(CAST(dd.[#Year] AS varchar(4)), '-', RIGHT(CONCAT('0', CAST(dd.[#Month] AS varchar(2))), 2)) AS YearMonth
    , dd.[#Year]                               AS YearNum
    , dd.[#Month]                              AS MonthNum
    , re.SKEmployeeKeyID                       AS SKEmployeeID
    , rp.SKProductKeyID                        AS SKProductID
    , ISNULL(s.Name, 'N/A')                    AS Specialty
    , ISNULL(at.Name, 'N/A')                   AS ActivityType
    , ISNULL(r.Name, 'N/A')                    AS Region
    , COUNT(1)                                 AS VisitCnt
    , COUNT(DISTINCT rd.SKDoctorKeyID)         AS DoctorCnt
    , SUM(CAST(ISNULL(f.DurationMin, 0) AS bigint)) AS TotalDurationMin
    , SUM(CAST(ISNULL(f.SamplesQty, 0) AS bigint))  AS TotalSamplesQty
    , DATEFROMPARTS(dd.[#Year], dd.[#Month], 1)   AS MonthStartDate
FROM [whsilver].[dwh].[FctVisit] AS f
INNER JOIN [whsilver].[dwh].[DimDate] AS dd ON dd.SKDateID = f.SKDateID AND dd.SKDateID <> -1
LEFT JOIN [whsilver].[dwh].[RefEmployee]     AS re ON re.SKRefEmployeeKeyID  = f.SKRefEmployeeKeyID  AND re.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[RefProduct]      AS rp ON rp.SKRefProductKeyID   = f.SKRefProductKeyID   AND rp.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[RefDoctor]       AS rd ON rd.SKRefDoctorKeyID    = f.SKRefDoctorKeyID    AND rd.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[DimDoctor]       AS d  ON d.SKDoctorKeyID        = rd.SKDoctorKeyID      AND d.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[DimSpecialty]    AS s  ON s.SKSpecialtyKeyID     = d.SKSpecialtyKeyID    AND s.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[DimRegion]       AS r  ON r.SKRegionKeyID        = d.SKRegionKeyID       AND r.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[DimActivityType] AS at ON at.SKActivityTypeKeyID = f.SKActivityTypeKeyID AND at.EndDate IS NULL
GROUP BY
      CONCAT(CAST(dd.[#Year] AS varchar(4)), '-', RIGHT(CONCAT('0', CAST(dd.[#Month] AS varchar(2))), 2))
    , dd.[#Year], dd.[#Month]
    , re.SKEmployeeKeyID, rp.SKProductKeyID
    , ISNULL(s.Name, 'N/A'), ISNULL(at.Name, 'N/A'), ISNULL(r.Name, 'N/A')

GO

CREATE OR ALTER VIEW [dwh].[vAggPrescriptionMonthly] AS
SELECT
      CONCAT(CAST(dd.[#Year] AS varchar(4)), '-', RIGHT(CONCAT('0', CAST(dd.[#Month] AS varchar(2))), 2)) AS YearMonth
    , dd.[#Year]                               AS YearNum
    , dd.[#Month]                              AS MonthNum
    , rp.SKProductKeyID                        AS SKProductID
    , ISNULL(s.Name, 'N/A')                    AS Specialty
    , ISNULL(r.Name, 'N/A')                    AS Region
    , COUNT(DISTINCT rd.SKDoctorKeyID)         AS DoctorCnt
    , SUM(CAST(ISNULL(f.PatientsCnt, 0) AS bigint))      AS TotalPatientsCnt
    , SUM(CAST(ISNULL(f.PrescriptionsCnt, 0) AS bigint)) AS TotalPrescriptionsCnt
    , DATEFROMPARTS(dd.[#Year], dd.[#Month], 1)   AS MonthStartDate
FROM [whsilver].[dwh].[FctPrescription] AS f
INNER JOIN [whsilver].[dwh].[DimDate] AS dd ON dd.SKDateID = f.SKDateID AND dd.SKDateID <> -1
LEFT JOIN [whsilver].[dwh].[RefProduct]   AS rp ON rp.SKRefProductKeyID = f.SKRefProductKeyID AND rp.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[RefDoctor]    AS rd ON rd.SKRefDoctorKeyID  = f.SKRefDoctorKeyID  AND rd.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[DimDoctor]    AS d  ON d.SKDoctorKeyID      = rd.SKDoctorKeyID    AND d.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[DimSpecialty] AS s  ON s.SKSpecialtyKeyID   = d.SKSpecialtyKeyID  AND s.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[DimRegion]    AS r  ON r.SKRegionKeyID      = d.SKRegionKeyID     AND r.EndDate IS NULL
GROUP BY
      CONCAT(CAST(dd.[#Year] AS varchar(4)), '-', RIGHT(CONCAT('0', CAST(dd.[#Month] AS varchar(2))), 2))
    , dd.[#Year], dd.[#Month]
    , rp.SKProductKeyID, ISNULL(s.Name, 'N/A'), ISNULL(r.Name, 'N/A')

GO

CREATE OR ALTER VIEW [dwh].[vAggInventoryMonthly] AS
SELECT
      CONCAT(CAST(dd.[#Year] AS varchar(4)), '-', RIGHT(CONCAT('0', CAST(dd.[#Month] AS varchar(2))), 2)) AS YearMonth
    , dd.[#Year]                               AS YearNum
    , dd.[#Month]                              AS MonthNum
    , rw.SKWarehouseKeyID                      AS SKWarehouseID
    , rp.SKProductKeyID                        AS SKProductID
    , COUNT(1)                                 AS MovementCnt
    , SUM(CASE WHEN mt.Id = 'IN'       THEN f.Qty ELSE 0 END) AS QtyIn
    , SUM(CASE WHEN mt.Id = 'OUT'      THEN f.Qty ELSE 0 END) AS QtyOut
    , SUM(CASE WHEN mt.Id = 'WRITEOFF' THEN f.Qty ELSE 0 END) AS QtyWriteOff
    , SUM(f.QtySigned)                         AS QtyNet
    , DATEFROMPARTS(dd.[#Year], dd.[#Month], 1)   AS MonthStartDate
FROM [whsilver].[dwh].[FctInventoryMovement] AS f
INNER JOIN [whsilver].[dwh].[DimDate] AS dd ON dd.SKDateID = f.SKDateID AND dd.SKDateID <> -1
LEFT JOIN [whsilver].[dwh].[RefWarehouse]    AS rw ON rw.SKRefWarehouseKeyID    = f.SKRefWarehouseKeyID    AND rw.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[RefProduct]      AS rp ON rp.SKRefProductKeyID      = f.SKRefProductKeyID      AND rp.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[RefMovementType] AS rm ON rm.SKRefMovementTypeKeyID = f.SKRefMovementTypeKeyID AND rm.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[DimMovementType] AS mt ON mt.SKMovementTypeKeyID    = rm.SKMovementTypeKeyID   AND mt.EndDate IS NULL
GROUP BY
      CONCAT(CAST(dd.[#Year] AS varchar(4)), '-', RIGHT(CONCAT('0', CAST(dd.[#Month] AS varchar(2))), 2))
    , dd.[#Year], dd.[#Month]
    , rw.SKWarehouseKeyID, rp.SKProductKeyID

GO

CREATE OR ALTER VIEW [dwh].[vAggAdverseEventMonthly] AS
SELECT
      CONCAT(CAST(dd.[#Year] AS varchar(4)), '-', RIGHT(CONCAT('0', CAST(dd.[#Month] AS varchar(2))), 2)) AS YearMonth
    , dd.[#Year]                               AS YearNum
    , dd.[#Month]                              AS MonthNum
    , rp.SKProductKeyID                        AS SKProductID
    , ISNULL(ser.Name, 'N/A')                  AS Seriousness
    , ISNULL(reg.Name, 'N/A')                  AS Region
    , SUM(CASE WHEN f.IsLatestVersion = 1 THEN 1 ELSE 0 END)                          AS CaseCnt
    , SUM(CASE WHEN f.IsLatestVersion = 1 AND ISNULL(o.IsFatal, 0) = 1 THEN 1 ELSE 0 END) AS FatalCnt
    , SUM(CASE WHEN f.IsLogicalError = 1 THEN 1 ELSE 0 END)                           AS LogicalErrorCnt
    , DATEFROMPARTS(dd.[#Year], dd.[#Month], 1)   AS MonthStartDate
FROM [whsilver].[dwh].[FctAdverseEvent] AS f
INNER JOIN [whsilver].[dwh].[DimDate] AS dd ON dd.SKDateID = f.SKDateID AND dd.SKDateID <> -1
LEFT JOIN [whsilver].[dwh].[RefProduct]       AS rp  ON rp.SKRefProductKeyID    = f.SKRefProductKeyID    AND rp.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[DimAeSeriousness] AS ser ON ser.SKAeSeriousnessKeyID = f.SKAeSeriousnessKeyID AND ser.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[DimAeOutcome]     AS o   ON o.SKAeOutcomeKeyID      = f.SKAeOutcomeKeyID     AND o.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[DimRegion]        AS reg ON reg.SKRegionKeyID       = f.SKRegionKeyID        AND reg.EndDate IS NULL
GROUP BY
      CONCAT(CAST(dd.[#Year] AS varchar(4)), '-', RIGHT(CONCAT('0', CAST(dd.[#Month] AS varchar(2))), 2))
    , dd.[#Year], dd.[#Month]
    , rp.SKProductKeyID, ISNULL(ser.Name, 'N/A'), ISNULL(reg.Name, 'N/A')

GO

-- Рівень 3: агрегат над агрегатами (промо-активність проти продажів)
CREATE OR ALTER VIEW [dwh].[vAggPromoEffectMonthly] AS
WITH sales AS (
    SELECT YearMonth, YearNum, MonthNum, SKProductID, Region,
           SUM(TotalQty) AS TotalQty, SUM(TotalNetAmount) AS TotalNetAmount
    FROM [dwh].[AggSalesMonthly]
    GROUP BY YearMonth, YearNum, MonthNum, SKProductID, Region
),
visits AS (
    SELECT YearMonth, YearNum, MonthNum, SKProductID, Region,
           SUM(VisitCnt) AS VisitCnt, SUM(TotalSamplesQty) AS TotalSamplesQty
    FROM [dwh].[AggVisitMonthly]
    GROUP BY YearMonth, YearNum, MonthNum, SKProductID, Region
),
rx AS (
    SELECT YearMonth, YearNum, MonthNum, SKProductID, Region,
           SUM(TotalPrescriptionsCnt) AS TotalPrescriptionsCnt
    FROM [dwh].[AggPrescriptionMonthly]
    GROUP BY YearMonth, YearNum, MonthNum, SKProductID, Region
),
keys AS (
    SELECT YearMonth, YearNum, MonthNum, SKProductID, Region FROM sales
    UNION
    SELECT YearMonth, YearNum, MonthNum, SKProductID, Region FROM visits
    UNION
    SELECT YearMonth, YearNum, MonthNum, SKProductID, Region FROM rx
)
SELECT
      k.YearMonth
    , k.YearNum
    , k.MonthNum
    , k.SKProductID
    , k.Region
    , ISNULL(v.VisitCnt, 0)                    AS VisitCnt
    , ISNULL(v.TotalSamplesQty, 0)             AS TotalSamplesQty
    , ISNULL(x.TotalPrescriptionsCnt, 0)       AS TotalPrescriptionsCnt
    , ISNULL(s.TotalQty, 0)                    AS TotalQty
    , ISNULL(s.TotalNetAmount, 0)              AS TotalNetAmount
    , CAST(ISNULL(s.TotalNetAmount, 0) / NULLIF(v.VisitCnt, 0) AS decimal(38,4)) AS NetAmountPerVisit
    , DATEFROMPARTS(k.YearNum, k.MonthNum, 1)   AS MonthStartDate
FROM keys AS k
LEFT JOIN sales  AS s ON s.YearMonth = k.YearMonth AND s.SKProductID = k.SKProductID AND s.Region = k.Region
LEFT JOIN visits AS v ON v.YearMonth = k.YearMonth AND v.SKProductID = k.SKProductID AND v.Region = k.Region
LEFT JOIN rx     AS x ON x.YearMonth = k.YearMonth AND x.SKProductID = k.SKProductID AND x.Region = k.Region
GO
