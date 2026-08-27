-- ClickUp: PHARMA-GOLD-002
-- Джерельні view gold (читають silver крос-базово: [whsilver].[dwh].*) + оркестрація:
--   [dwh].[EtlGoldObject]     — реєстр обʼєктів і рівнів завантаження
--   [dwh].[EtlGoldLoadLog]    — журнал запусків
--   [dwh].[spFullGoldObject]  — TRUNCATE + INSERT з v<Object>
--   [dwh].[spGoldLoadLevel]   — рівень цілком (виклик з Data Pipeline)
--   [dwh].[spGoldFullLoad]    — рівні 1..MAX
--
-- Порядок колонок кожного vDim*/vAgg* має точно збігатися з таблицею,
-- починаючи з третьої колонки (spFullGoldObject вставляє CreatedBy, CreatedAt, v.*).
GO
--IMPORTANT
USE [whgold];
--IMPORTANT
GO

/* =========================================================
   ВИМІРИ
   ========================================================= */

CREATE OR ALTER VIEW [dwh].[vDimDate] AS
SELECT
      d.SKDateID
    , d.CalendarDate
    , d.[#DayOfMonth]                          AS DayOfMonth
    , d.[#Month]                               AS MonthNum
    , d.MonthName
    , d.[#Quarter]                             AS QuarterNum
    , d.[#Year]                                AS YearNum
    , CASE WHEN d.SKDateID = -1 THEN 'N/A'
           ELSE CONCAT(CAST(d.[#Year] AS varchar(4)), '-', RIGHT(CONCAT('0', CAST(d.[#Month] AS varchar(2))), 2))
      END                                      AS YearMonth
    , d.[#FiscalYear]                          AS FiscalYear
    , d.[#FiscalQuarter]                       AS FiscalQuarter
FROM [whsilver].[dwh].[DimDate] AS d
GO

CREATE OR ALTER VIEW [dwh].[vDimProduct] AS
SELECT
      p.SKProductKeyID                         AS SKProductID
    , p.Id
    , p.Name                                   AS ProductName
    , p.SkuCode
    , p.INN
    , p.AtcCode
    , ISNULL(a.Name, 'N/A')                    AS AtcClass
    , p.ReleaseForm
    , p.Dosage
    , ISNULL(m.Name, 'N/A')                    AS Manufacturer
    , p.RxOtcType
    , p.BasePriceUAH
    , p.IsActive
FROM [whsilver].[dwh].[DimProduct] AS p
LEFT JOIN [whsilver].[dwh].[DimManufacturer] AS m
    ON m.SKManufacturerKeyID = p.SKManufacturerKeyID AND m.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[DimAtcClass] AS a
    ON a.SKAtcClassKeyID = p.SKAtcClassKeyID AND a.EndDate IS NULL
WHERE p.EndDate IS NULL
GO

CREATE OR ALTER VIEW [dwh].[vDimClientAccount] AS
SELECT
      ca.SKClientAccountKeyID                  AS SKClientAccountID
    , ca.Id
    , ca.Name                                  AS AccountName
    , ca.AccountType
    , ISNULL(ch.Name, 'N/A')                   AS Chain
    , ISNULL(le.Name, 'N/A')                   AS LegalEntityName
    , ISNULL(le.EDRPOU, 'N/A')                 AS EDRPOU
    , ISNULL(r.Name, 'N/A')                    AS Region
    , ISNULL(c.Name, 'N/A')                    AS City
    , ca.IsActive
    , ca.SrcDuplicateCnt
FROM [whsilver].[dwh].[DimClientAccount] AS ca
LEFT JOIN [whsilver].[dwh].[DimChain]       AS ch ON ch.SKChainKeyID       = ca.SKChainKeyID       AND ch.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[DimLegalEntity] AS le ON le.SKLegalEntityKeyID = ca.SKLegalEntityKeyID AND le.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[DimRegion]      AS r  ON r.SKRegionKeyID       = ca.SKRegionKeyID      AND r.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[DimCity]        AS c  ON c.SKCityKeyID         = ca.SKCityKeyID        AND c.EndDate IS NULL
WHERE ca.EndDate IS NULL
GO

CREATE OR ALTER VIEW [dwh].[vDimDoctor] AS
SELECT
      d.SKDoctorKeyID                          AS SKDoctorID
    , d.Id
    , d.Name                                   AS DoctorName
    , ISNULL(s.Name, 'N/A')                    AS Specialty
    , ISNULL(l.Name, 'N/A')                    AS Lpu
    , ISNULL(r.Name, 'N/A')                    AS Region
    , ISNULL(c.Name, 'N/A')                    AS City
    , d.Segment
    , d.IsTarget
FROM [whsilver].[dwh].[DimDoctor] AS d
LEFT JOIN [whsilver].[dwh].[DimSpecialty] AS s ON s.SKSpecialtyKeyID = d.SKSpecialtyKeyID AND s.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[DimLpu]       AS l ON l.SKLpuKeyID       = d.SKLpuKeyID       AND l.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[DimRegion]    AS r ON r.SKRegionKeyID    = d.SKRegionKeyID    AND r.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[DimCity]      AS c ON c.SKCityKeyID      = d.SKCityKeyID      AND c.EndDate IS NULL
WHERE d.EndDate IS NULL
GO

CREATE OR ALTER VIEW [dwh].[vDimEmployee] AS
SELECT
      e.SKEmployeeKeyID                        AS SKEmployeeID
    , e.Id
    , e.Name                                   AS EmployeeName
    , e.EmployeeRole
    , ISNULL(t.Name, 'N/A')                    AS Territory
    , e.ProductLine
    , ISNULL(mgr.Name, 'N/A')                  AS ManagerName
    , e.HireDate
    , e.IsActive
FROM [whsilver].[dwh].[DimEmployee] AS e
LEFT JOIN [whsilver].[dwh].[DimTerritory] AS t   ON t.SKTerritoryKeyID  = e.SKTerritoryKeyID       AND t.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[DimEmployee]  AS mgr ON mgr.SKEmployeeKeyID = e.SKEmployeeManagerKeyID AND mgr.EndDate IS NULL
WHERE e.EndDate IS NULL
GO

CREATE OR ALTER VIEW [dwh].[vDimWarehouse] AS
SELECT
      w.SKWarehouseKeyID                       AS SKWarehouseID
    , w.Id
    , w.Name                                   AS WarehouseName
    , w.WarehouseCode
    , w.WarehouseType
    , ISNULL(o.Name, 'N/A')                    AS OwnerAccountName
    , ISNULL(r.Name, 'N/A')                    AS Region
    , ISNULL(c.Name, 'N/A')                    AS City
FROM [whsilver].[dwh].[DimWarehouse] AS w
LEFT JOIN [whsilver].[dwh].[DimClientAccount] AS o ON o.SKClientAccountKeyID = w.SKClientAccountOwnerKeyID AND o.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[DimRegion]        AS r ON r.SKRegionKeyID        = w.SKRegionKeyID             AND r.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[DimCity]          AS c ON c.SKCityKeyID          = w.SKCityKeyID               AND c.EndDate IS NULL
WHERE w.EndDate IS NULL
GO

/* =========================================================
   АГРЕГАТИ
   ========================================================= */

CREATE OR ALTER VIEW [dwh].[vAggSalesDaily] AS
SELECT
      f.SKDateID
    , dd.CalendarDate
    , rp.SKProductKeyID                        AS SKProductID
    , rca.SKClientAccountKeyID                 AS SKClientAccountID
    , re.SKEmployeeKeyID                       AS SKEmployeeID
    , rw.SKWarehouseKeyID                      AS SKWarehouseID
    , os.Name                                  AS OrderStatus
    , cur.Name                                 AS Currency
    , COUNT(1)                                 AS OrderLineCnt
    , SUM(f.Qty)                               AS TotalQty
    , SUM(f.GrossAmount)                       AS TotalGrossAmount
    , SUM(f.DiscountAmount)                    AS TotalDiscountAmount
    , SUM(f.NetAmount)                         AS TotalNetAmount
FROM [whsilver].[dwh].[FctSales] AS f
INNER JOIN [whsilver].[dwh].[DimDate] AS dd ON dd.SKDateID = f.SKDateID
LEFT JOIN [whsilver].[dwh].[RefProduct]       AS rp  ON rp.SKRefProductKeyID       = f.SKRefProductKeyID       AND rp.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[RefClientAccount] AS rca ON rca.SKRefClientAccountKeyID = f.SKRefClientAccountKeyID AND rca.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[RefEmployee]      AS re  ON re.SKRefEmployeeKeyID      = f.SKRefEmployeeKeyID      AND re.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[RefWarehouse]     AS rw  ON rw.SKRefWarehouseKeyID     = f.SKRefWarehouseKeyID     AND rw.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[DimOrderStatus]   AS os  ON os.SKOrderStatusKeyID      = f.SKOrderStatusKeyID      AND os.EndDate IS NULL
LEFT JOIN [whsilver].[dwh].[DimCurrency]      AS cur ON cur.SKCurrencyKeyID        = f.SKCurrencyKeyID         AND cur.EndDate IS NULL
GROUP BY
      f.SKDateID, dd.CalendarDate
    , rp.SKProductKeyID, rca.SKClientAccountKeyID, re.SKEmployeeKeyID, rw.SKWarehouseKeyID
    , os.Name, cur.Name
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
FROM keys AS k
LEFT JOIN sales  AS s ON s.YearMonth = k.YearMonth AND s.SKProductID = k.SKProductID AND s.Region = k.Region
LEFT JOIN visits AS v ON v.YearMonth = k.YearMonth AND v.SKProductID = k.SKProductID AND v.Region = k.Region
LEFT JOIN rx     AS x ON x.YearMonth = k.YearMonth AND x.SKProductID = k.SKProductID AND x.Region = k.Region
GO

/* =========================================================
   ОРКЕСТРАЦІЯ
   ========================================================= */

DROP TABLE IF EXISTS [whgold].[dwh].[EtlGoldObject]
GO
CREATE TABLE [whgold].[dwh].[EtlGoldObject]
(
	[ObjectName] [varchar](128) NOT NULL,
	[ObjectType] [varchar](10) NOT NULL,   -- Dim / Agg
	[LoadLevel] [int] NOT NULL,
	[IsActive] [bit] NOT NULL
)
GO

INSERT INTO [whgold].[dwh].[EtlGoldObject] ([ObjectName],[ObjectType],[LoadLevel],[IsActive])
VALUES
	('DimDate',                 'Dim', 1, 1),
	('DimProduct',              'Dim', 1, 1),
	('DimClientAccount',        'Dim', 1, 1),
	('DimDoctor',               'Dim', 1, 1),
	('DimEmployee',             'Dim', 1, 1),
	('DimWarehouse',            'Dim', 1, 1),
	('AggSalesDaily',           'Agg', 2, 1),
	('AggSalesMonthly',         'Agg', 2, 1),
	('AggVisitMonthly',         'Agg', 2, 1),
	('AggPrescriptionMonthly',  'Agg', 2, 1),
	('AggInventoryMonthly',     'Agg', 2, 1),
	('AggAdverseEventMonthly',  'Agg', 2, 1),
	('AggPromoEffectMonthly',   'Agg', 3, 1)
GO

IF OBJECT_ID('dwh.EtlGoldLoadLog', 'U') IS NULL
    EXEC('
    CREATE TABLE [whgold].[dwh].[EtlGoldLoadLog]
    (
        [LoadId] [varchar](250) NOT NULL,
        [ObjectName] [varchar](128) NOT NULL,
        [ObjectType] [varchar](10) NOT NULL,
        [LoadLevel] [int] NOT NULL,
        [StartedAt] [datetime2](3) NOT NULL,
        [FinishedAt] [datetime2](3) NULL,
        [DurationSec] [decimal](18,3) NULL,
        [RowCnt] [bigint] NULL,
        [Status] [varchar](20) NOT NULL,
        [ErrorMessage] [varchar](8000) NULL
    )');
GO

CREATE OR ALTER PROCEDURE [dwh].[spFullGoldObject]
    @object_name NVARCHAR(250),
    @load_id NVARCHAR(250)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @schema_name NVARCHAR(3) = 'dwh';
    DECLARE @view_name NVARCHAR(150) = 'v' + @object_name;

    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.VIEWS
        WHERE TABLE_SCHEMA = @schema_name AND TABLE_NAME = @view_name
    )
    BEGIN
        RAISERROR('View [%s].[%s] does not exist.', 16, 1, @schema_name, @view_name);
        RETURN;
    END;

    DECLARE @full_table NVARCHAR(200) = QUOTENAME(@schema_name) + '.' + QUOTENAME(@object_name);
    DECLARE @full_view  NVARCHAR(200) = QUOTENAME(@schema_name) + '.' + QUOTENAME(@view_name);
    DECLARE @current_time DATETIME2(3) = SYSUTCDATETIME();

    DECLARE @sql NVARCHAR(MAX) = N'
        TRUNCATE TABLE ' + @full_table + N';

        INSERT INTO ' + @full_table + N'
        SELECT CAST(''' + @load_id + N''' AS VARCHAR(100)) AS CreatedBy,
               @t AS CreatedAt,
               v.*
        FROM ' + @full_view + N' v;';

    PRINT @sql;

    EXEC sp_executesql @sql, N'@t DATETIME2(3)', @t = @current_time;
END
GO

CREATE OR ALTER PROCEDURE [dwh].[spGoldLoadLevel]
    @level INT,
    @load_id NVARCHAR(250) = 'manual_gold_load'
AS
BEGIN
    SET NOCOUNT ON;

    DROP TABLE IF EXISTS #gold_level_objects;

    SELECT
          ROW_NUMBER() OVER (ORDER BY o.ObjectType, o.ObjectName) AS rn
        , o.ObjectName
        , o.ObjectType
    INTO #gold_level_objects
    FROM [dwh].[EtlGoldObject] AS o
    WHERE o.LoadLevel = @level
      AND o.IsActive = 1;

    DECLARE @cnt INT = (SELECT COUNT(1) FROM #gold_level_objects);
    DECLARE @i INT = 1;

    DECLARE @obj VARCHAR(128), @type VARCHAR(10);
    DECLARE @started DATETIME2(3), @finished DATETIME2(3), @rowcnt BIGINT, @sql NVARCHAR(MAX);

    PRINT CONCAT('[spGoldLoadLevel] level=', @level, ', objects=', @cnt, ', load_id=', @load_id);

    WHILE @i <= @cnt
    BEGIN
        SELECT @obj = ObjectName, @type = ObjectType
        FROM #gold_level_objects WHERE rn = @i;

        SET @started = SYSUTCDATETIME();
        SET @rowcnt = NULL;

        BEGIN TRY
            EXEC [dwh].[spFullGoldObject] @object_name = @obj, @load_id = @load_id;

            SET @sql = N'SELECT @c = COUNT(1) FROM [dwh].' + QUOTENAME(@obj) + N';';
            EXEC sp_executesql @sql, N'@c BIGINT OUTPUT', @c = @rowcnt OUTPUT;

            SET @finished = SYSUTCDATETIME();

            INSERT INTO [dwh].[EtlGoldLoadLog]
                ([LoadId],[ObjectName],[ObjectType],[LoadLevel],[StartedAt],[FinishedAt],[DurationSec],[RowCnt],[Status],[ErrorMessage])
            VALUES
                (@load_id, @obj, @type, @level, @started, @finished,
                 DATEDIFF(MILLISECOND, @started, @finished) / 1000.0, @rowcnt, 'Success', NULL);
        END TRY
        BEGIN CATCH
            SET @finished = SYSUTCDATETIME();

            INSERT INTO [dwh].[EtlGoldLoadLog]
                ([LoadId],[ObjectName],[ObjectType],[LoadLevel],[StartedAt],[FinishedAt],[DurationSec],[RowCnt],[Status],[ErrorMessage])
            VALUES
                (@load_id, @obj, @type, @level, @started, @finished,
                 DATEDIFF(MILLISECOND, @started, @finished) / 1000.0, NULL, 'Failed', LEFT(ERROR_MESSAGE(), 8000));

            THROW;
        END CATCH

        SET @i = @i + 1;
    END
END
GO

CREATE OR ALTER PROCEDURE [dwh].[spGoldFullLoad]
    @load_id NVARCHAR(250) = 'manual_gold_full_load'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @lvl INT = 1;
    DECLARE @max_lvl INT = (SELECT MAX(LoadLevel) FROM [dwh].[EtlGoldObject] WHERE IsActive = 1);

    WHILE @lvl <= @max_lvl
    BEGIN
        EXEC [dwh].[spGoldLoadLevel] @level = @lvl, @load_id = @load_id;
        SET @lvl = @lvl + 1;
    END
END
GO
