-- ClickUp: PHARMA-SILVER-005
-- Інкрементальне завантаження фактів.
--
-- Що змінюється:
--   * у 5 фактових таблиць і view додано [SrcModifiedAt] (= erp.<table>.updated_at з bronze)
--     — остання колонка, бо spFullFct/spIncrementalFct вставляють через v_fct.*;
--   * [dwh].[EtlSilverWatermark] тримає останнє оброблене значення watermark по кожному факту;
--   * [dwh].[spIncrementalFct] вантажить лише зріз SrcModifiedAt > watermark:
--     DELETE по ItemId + INSERT (upsert за бізнес-ключем), далі просування watermark;
--   * [dwh].[EtlSilverObject] отримує LoadStrategy ('Full'|'Incremental') і WatermarkColumn;
--   * [dwh].[spSilverLoadLevel] диспетчеризує Fct за LoadStrategy і має @force_full.
--
-- ЧОМУ ВИМІРИ ЛИШАЮТЬСЯ ПОВНИМИ: spUpsertSCDDimension позначає IsDeleted = 1 для рядків,
-- яких немає у джерельному view. Якщо відфільтрувати view по watermark, усі "старі" рядки
-- зникнуть із джерела і будуть помилково закриті як видалені. Тому Dim/Ref рахуються
-- повним порівнянням — SCD2 і так пише лише реальні зміни.
--
-- ОБМЕЖЕННЯ інкременту (свідомі):
--   * видалення рядків у джерелі інкремент не бачить -> періодично потрібен @force_full = 1;
--   * якщо джерело змінює рядок, не оновивши updated_at (у 02_generate_data_fixed.sql так
--     роблять UPDATE-и, що імітують дефекти), зміна не потрапить в інкремент;
--   * Tech* колонки bronze для watermark не годяться: bronze перезаписується повністю
--     (OverwriteSchema), тому TechProcessingDateTime оновлюється в усіх рядків одразу.
GO
--IMPORTANT
USE [whsilverad];
--IMPORTANT
GO

/* =========================================================
   1. Колонка watermark у фактових таблицях
   ========================================================= */

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_SCHEMA = 'dwh' AND TABLE_NAME = 'FctSales' AND COLUMN_NAME = 'SrcModifiedAt')
    EXEC('ALTER TABLE [dwh].[FctSales] ADD [SrcModifiedAt] datetime2(3) NULL');
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_SCHEMA = 'dwh' AND TABLE_NAME = 'FctInventoryMovement' AND COLUMN_NAME = 'SrcModifiedAt')
    EXEC('ALTER TABLE [dwh].[FctInventoryMovement] ADD [SrcModifiedAt] datetime2(3) NULL');
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_SCHEMA = 'dwh' AND TABLE_NAME = 'FctVisit' AND COLUMN_NAME = 'SrcModifiedAt')
    EXEC('ALTER TABLE [dwh].[FctVisit] ADD [SrcModifiedAt] datetime2(3) NULL');
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_SCHEMA = 'dwh' AND TABLE_NAME = 'FctPrescription' AND COLUMN_NAME = 'SrcModifiedAt')
    EXEC('ALTER TABLE [dwh].[FctPrescription] ADD [SrcModifiedAt] datetime2(3) NULL');
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_SCHEMA = 'dwh' AND TABLE_NAME = 'FctAdverseEvent' AND COLUMN_NAME = 'SrcModifiedAt')
    EXEC('ALTER TABLE [dwh].[FctAdverseEvent] ADD [SrcModifiedAt] datetime2(3) NULL');
GO

/* =========================================================
   2. Фактові view: SrcModifiedAt останньою колонкою
   ========================================================= */

/* =========================================================
   ФАКТИ
   ========================================================= */

CREATE OR ALTER VIEW [dwh].[vFctSales] AS
WITH dedup_sales AS (
    SELECT
          s.*
        , ROW_NUMBER() OVER (PARTITION BY s.order_line_id ORDER BY s.row_id) AS rn
        , COUNT(1)    OVER (PARTITION BY s.order_line_id)                    AS SrcRowCnt
    FROM [lhbronze].[erp_erp].[SALES_ORDERS] AS s
),
-- Агрегат без GROUP BY завжди повертає рівно 1 рядок,
-- тому CROSS JOIN нижче не може обнулити факт, навіть якщо рядка джерельної системи немає.
src_system AS (
    SELECT ISNULL(MAX(SKSrcSystemKeyID), -1) AS SKSrcSystemKeyID
    FROM [whsilverad].[dwh].[DimSrcSystem]
    WHERE Id = 1 AND EndDate IS NULL
)
SELECT
      ss.SKSrcSystemKeyID                              AS SKSrcSystemKeyID
    , ISNULL(s.order_number, 'N/A')                    AS DocumentNumber
    , s.order_line_id                                  AS ItemId
    , CAST(s.order_date AS datetime2(3))               AS Period
    , ISNULL(dd.SKDateID, -1)                          AS SKDateID
    , ISNULL(dld.SKDateID, -1)                         AS SKDeliveryDateID
    , ISNULL(rca.SKRefClientAccountKeyID, -1)          AS SKRefClientAccountKeyID
    , ISNULL(rwh.SKRefWarehouseKeyID, -1)              AS SKRefWarehouseKeyID
    , ISNULL(rpr.SKRefProductKeyID, -1)                AS SKRefProductKeyID
    , ISNULL(remp.SKRefEmployeeKeyID, -1)              AS SKRefEmployeeKeyID
    , ISNULL(dos.SKOrderStatusKeyID, -1)               AS SKOrderStatusKeyID
    , ISNULL(cur.SKCurrencyKeyID, -1)                  AS SKCurrencyKeyID
    , CAST(s.quantity AS decimal(18,3))                AS Qty
    , CAST(s.unit_price AS decimal(18,4))              AS UnitPrice
    , CAST(s.discount_pct AS decimal(5,2))             AS DiscountPct
    , CAST(s.quantity * ISNULL(s.unit_price, 0) AS decimal(18,4)) AS GrossAmount
    , CAST(s.quantity * ISNULL(s.unit_price, 0) * (ISNULL(s.discount_pct, 0) / 100.0) AS decimal(18,4)) AS DiscountAmount
    , CAST(s.line_amount AS decimal(18,4))             AS NetAmount
    , CAST(CASE WHEN s.status = 'RETURN' THEN 1 ELSE 0 END AS bit)    AS IsReturn
    , CAST(CASE WHEN s.status = 'CANCELLED' THEN 1 ELSE 0 END AS bit) AS IsCancelled
    , CAST(CASE
               WHEN s.line_amount IS NULL OR s.quantity IS NULL OR s.unit_price IS NULL THEN 0
               WHEN ABS(s.line_amount - ROUND(s.quantity * s.unit_price * (1 - ISNULL(s.discount_pct, 0) / 100.0), 2)) <= 0.01 THEN 1
               ELSE 0
           END AS bit)                                 AS IsAmountConsistent
    , CAST(CASE
               WHEN s.order_date IS NULL THEN 1
               WHEN s.order_date < '2020-01-01' OR s.order_date > CAST(SYSDATETIME() AS date) THEN 1
               ELSE 0
           END AS bit)                                 AS IsPeriodOutOfRange
    , CAST(CASE WHEN s.SrcRowCnt > 1 THEN 1 ELSE 0 END AS bit) AS IsSrcDuplicate
    , CAST(s.updated_at AS datetime2(3))       AS SrcModifiedAt
FROM dedup_sales AS s
CROSS JOIN src_system AS ss
LEFT JOIN [whsilverad].[dwh].[DimDate] AS dd
    ON dd.CalendarDate = s.order_date
LEFT JOIN [whsilverad].[dwh].[DimDate] AS dld
    ON dld.CalendarDate = s.delivery_date
LEFT JOIN [whsilverad].[dwh].[RefClientAccount] AS rca
    ON  rca.Id = s.customer_id
    AND rca.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[RefWarehouse] AS rwh
    ON  rwh.Id = s.warehouse_id
    AND rwh.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[RefProduct] AS rpr
    ON  rpr.Id = s.product_id
    AND rpr.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[RefEmployee] AS remp
    ON  remp.Id = s.employee_id
    AND remp.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[DimOrderStatus] AS dos
    ON  dos.Id = LTRIM(RTRIM(s.status))
    AND dos.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[DimCurrency] AS cur
    ON  cur.Id = LTRIM(RTRIM(s.currency))
    AND cur.EndDate IS NULL
WHERE s.rn = 1

GO

CREATE OR ALTER VIEW [dwh].[vFctInventoryMovement] AS
WITH dedup_movement AS (
    SELECT
          m.*
        , ROW_NUMBER() OVER (PARTITION BY m.movement_id ORDER BY m.row_id) AS rn
        , COUNT(1)    OVER (PARTITION BY m.movement_id)                    AS SrcRowCnt
    FROM [lhbronze].[erp_erp].[INVENTORY_MOVEMENTS] AS m
),
-- Агрегат без GROUP BY завжди повертає рівно 1 рядок,
-- тому CROSS JOIN нижче не може обнулити факт, навіть якщо рядка джерельної системи немає.
src_system AS (
    SELECT ISNULL(MAX(SKSrcSystemKeyID), -1) AS SKSrcSystemKeyID
    FROM [whsilverad].[dwh].[DimSrcSystem]
    WHERE Id = 1 AND EndDate IS NULL
)
SELECT
      ss.SKSrcSystemKeyID                         AS SKSrcSystemKeyID
    , ISNULL(m.reference_document, 'N/A')         AS DocumentNumber
    , m.movement_id                               AS ItemId
    , CAST(m.movement_date AS datetime2(3))       AS Period
    , ISNULL(dd.SKDateID, -1)                     AS SKDateID
    , ISNULL(rwh.SKRefWarehouseKeyID, -1)         AS SKRefWarehouseKeyID
    , ISNULL(rpr.SKRefProductKeyID, -1)           AS SKRefProductKeyID
    , ISNULL(remp.SKRefEmployeeKeyID, -1)         AS SKRefEmployeeKeyID
    , ISNULL(rmt.SKRefMovementTypeKeyID, -1)      AS SKRefMovementTypeKeyID
    , CAST(m.quantity AS decimal(18,3))           AS Qty
    , CAST(m.quantity * ISNULL(dmt.QtySign, 0) AS decimal(18,3)) AS QtySigned
    , CAST(CASE WHEN ABS(ISNULL(m.quantity, 0)) > 100000 THEN 1 ELSE 0 END AS bit) AS IsQtyOutlier
    , CAST(CASE WHEN m.SrcRowCnt > 1 THEN 1 ELSE 0 END AS bit)                     AS IsSrcDuplicate
    , CAST(m.updated_at AS datetime2(3))       AS SrcModifiedAt
FROM dedup_movement AS m
CROSS JOIN src_system AS ss
LEFT JOIN [whsilverad].[dwh].[DimDate] AS dd
    ON dd.CalendarDate = CAST(m.movement_date AS date)
LEFT JOIN [whsilverad].[dwh].[RefWarehouse] AS rwh
    ON  rwh.Id = m.warehouse_id
    AND rwh.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[RefProduct] AS rpr
    ON  rpr.Id = m.product_id
    AND rpr.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[RefEmployee] AS remp
    ON  remp.Id = m.employee_id
    AND remp.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[RefMovementType] AS rmt
    ON  rmt.Id = LTRIM(RTRIM(m.movement_type))
    AND rmt.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[DimMovementType] AS dmt
    ON  dmt.SKMovementTypeKeyID = rmt.SKMovementTypeKeyID
    AND dmt.EndDate IS NULL
WHERE m.rn = 1

GO

CREATE OR ALTER VIEW [dwh].[vFctVisit] AS
WITH dedup_visit AS (
    SELECT
          v.*
        , ROW_NUMBER() OVER (PARTITION BY v.visit_id ORDER BY v.row_id) AS rn
        , COUNT(1)    OVER (PARTITION BY v.visit_id)                    AS SrcRowCnt
    FROM [lhbronze].[erp_erp].[DOCTOR_VISITS] AS v
),
-- Агрегат без GROUP BY завжди повертає рівно 1 рядок,
-- тому CROSS JOIN нижче не може обнулити факт, навіть якщо рядка джерельної системи немає.
src_system AS (
    SELECT ISNULL(MAX(SKSrcSystemKeyID), -1) AS SKSrcSystemKeyID
    FROM [whsilverad].[dwh].[DimSrcSystem]
    WHERE Id = 1 AND EndDate IS NULL
)
SELECT
      ss.SKSrcSystemKeyID                      AS SKSrcSystemKeyID
    , v.visit_id                               AS ItemId
    , CAST(v.visit_date AS datetime2(3))       AS Period
    , ISNULL(dd.SKDateID, -1)                  AS SKDateID
    , ISNULL(rdoc.SKRefDoctorKeyID, -1)        AS SKRefDoctorKeyID
    , ISNULL(remp.SKRefEmployeeKeyID, -1)      AS SKRefEmployeeKeyID
    , ISNULL(rpr.SKRefProductKeyID, -1)        AS SKRefProductKeyID
    , ISNULL(dat.SKActivityTypeKeyID, -1)      AS SKActivityTypeKeyID
    , v.duration_min                           AS DurationMin
    , v.samples_qty                            AS SamplesQty
    , 1                                        AS VisitCnt
    , CAST(CASE WHEN v.SrcRowCnt > 1 THEN 1 ELSE 0 END AS bit) AS IsSrcDuplicate
    , CAST(v.updated_at AS datetime2(3))       AS SrcModifiedAt
FROM dedup_visit AS v
CROSS JOIN src_system AS ss
LEFT JOIN [whsilverad].[dwh].[DimDate] AS dd
    ON dd.CalendarDate = CAST(v.visit_date AS date)
LEFT JOIN [whsilverad].[dwh].[RefDoctor] AS rdoc
    ON  rdoc.Id = v.doctor_id
    AND rdoc.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[RefEmployee] AS remp
    ON  remp.Id = v.employee_id
    AND remp.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[RefProduct] AS rpr
    ON  rpr.Id = v.product_id
    AND rpr.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[DimActivityType] AS dat
    ON  dat.Id = LTRIM(RTRIM(v.activity_type))
    AND dat.EndDate IS NULL
WHERE v.rn = 1

GO

CREATE OR ALTER VIEW [dwh].[vFctPrescription] AS
WITH dedup_rx AS (
    SELECT
          r.*
        , ROW_NUMBER() OVER (PARTITION BY r.prescription_id ORDER BY r.row_id) AS rn
        , COUNT(1)    OVER (PARTITION BY r.prescription_id)                    AS SrcRowCnt
    FROM [lhbronze].[erp_erp].[PRESCRIPTIONS] AS r
),
-- Агрегат без GROUP BY завжди повертає рівно 1 рядок,
-- тому CROSS JOIN нижче не може обнулити факт, навіть якщо рядка джерельної системи немає.
src_system AS (
    SELECT ISNULL(MAX(SKSrcSystemKeyID), -1) AS SKSrcSystemKeyID
    FROM [whsilverad].[dwh].[DimSrcSystem]
    WHERE Id = 1 AND EndDate IS NULL
)
SELECT
      ss.SKSrcSystemKeyID                        AS SKSrcSystemKeyID
    , r.prescription_id                          AS ItemId
    , CAST(r.prescription_date AS datetime2(3))  AS Period
    , ISNULL(dd.SKDateID, -1)                    AS SKDateID
    , ISNULL(rdoc.SKRefDoctorKeyID, -1)          AS SKRefDoctorKeyID
    , ISNULL(rpr.SKRefProductKeyID, -1)          AS SKRefProductKeyID
    , ISNULL(remp.SKRefEmployeeKeyID, -1)        AS SKRefEmployeeKeyID
    , r.patients_count                           AS PatientsCnt
    , r.prescriptions_count                      AS PrescriptionsCnt
    , CAST(CASE WHEN r.SrcRowCnt > 1 THEN 1 ELSE 0 END AS bit) AS IsSrcDuplicate
    , CAST(r.updated_at AS datetime2(3))       AS SrcModifiedAt
FROM dedup_rx AS r
CROSS JOIN src_system AS ss
LEFT JOIN [whsilverad].[dwh].[DimDate] AS dd
    ON dd.CalendarDate = r.prescription_date
LEFT JOIN [whsilverad].[dwh].[RefDoctor] AS rdoc
    ON  rdoc.Id = r.doctor_id
    AND rdoc.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[RefProduct] AS rpr
    ON  rpr.Id = r.product_id
    AND rpr.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[RefEmployee] AS remp
    ON  remp.Id = r.entered_by_employee_id
    AND remp.EndDate IS NULL
WHERE r.rn = 1

GO

CREATE OR ALTER VIEW [dwh].[vFctAdverseEvent] AS
WITH dedup_ae AS (
    SELECT
          a.*
        , ROW_NUMBER() OVER (PARTITION BY a.ae_id, a.case_version ORDER BY a.row_id DESC) AS rn
        , MAX(a.case_version) OVER (PARTITION BY a.ae_id)                                 AS MaxCaseVersion
    FROM [lhbronze].[erp_erp].[ADVERSE_EVENTS] AS a
),
-- Агрегат без GROUP BY завжди повертає рівно 1 рядок,
-- тому CROSS JOIN нижче не може обнулити факт, навіть якщо рядка джерельної системи немає.
src_system AS (
    SELECT ISNULL(MAX(SKSrcSystemKeyID), -1) AS SKSrcSystemKeyID
    FROM [whsilverad].[dwh].[DimSrcSystem]
    WHERE Id = 1 AND EndDate IS NULL
)
SELECT
      ss.SKSrcSystemKeyID                              AS SKSrcSystemKeyID
    , a.ae_id                                          AS DocumentNumber
    , CONCAT(a.ae_id, '-', CAST(ISNULL(a.case_version, 0) AS varchar(5))) AS ItemId
    , CAST(a.report_date AS datetime2(3))              AS Period
    , ISNULL(dd.SKDateID, -1)                          AS SKDateID
    , ISNULL(rpr.SKRefProductKeyID, -1)                AS SKRefProductKeyID
    , ISNULL(rdoc.SKRefDoctorKeyID, -1)                AS SKRefDoctorKeyID
    , ISNULL(dser.SKAeSeriousnessKeyID, -1)            AS SKAeSeriousnessKeyID
    , ISNULL(dout.SKAeOutcomeKeyID, -1)                AS SKAeOutcomeKeyID
    , ISNULL(drs.SKReportSourceKeyID, -1)              AS SKReportSourceKeyID
    , ISNULL(reg.SKRegionKeyID, -1)                    AS SKRegionKeyID
    , a.case_version                                   AS CaseVersion
    , CAST(CASE WHEN a.case_version = a.MaxCaseVersion THEN 1 ELSE 0 END AS bit) AS IsLatestVersion
    , CAST(CASE
               WHEN LTRIM(RTRIM(a.seriousness)) = 'Critical'
                AND LTRIM(RTRIM(a.outcome)) IN ('Recovered', 'Recovering') THEN 1
               ELSE 0
           END AS bit)                                 AS IsLogicalError
    , 1                                                AS CaseCnt
    , CAST(a.updated_at AS datetime2(3))       AS SrcModifiedAt
FROM dedup_ae AS a
CROSS JOIN src_system AS ss
LEFT JOIN [whsilverad].[dwh].[DimDate] AS dd
    ON dd.CalendarDate = a.report_date
LEFT JOIN [whsilverad].[dwh].[RefProduct] AS rpr
    ON  rpr.Id = a.product_id
    AND rpr.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[RefDoctor] AS rdoc
    ON  rdoc.Id = a.reporter_doctor_id
    AND rdoc.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[DimAeSeriousness] AS dser
    ON  dser.Id = LTRIM(RTRIM(a.seriousness))
    AND dser.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[DimAeOutcome] AS dout
    ON  dout.Id = LTRIM(RTRIM(a.outcome))
    AND dout.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[DimReportSource] AS drs
    ON  drs.Id = LTRIM(RTRIM(a.report_source))
    AND drs.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[DimRegion] AS reg
    ON  reg.Id = LTRIM(RTRIM(a.region))
    AND reg.EndDate IS NULL
WHERE a.rn = 1

GO

/* =========================================================
   3. Реєстр обʼєктів: стратегія завантаження
   ========================================================= */

DROP TABLE IF EXISTS [whsilverad].[dwh].[EtlSilverObject]
GO
CREATE TABLE [whsilverad].[dwh].[EtlSilverObject]
(
	[ObjectName] [varchar](128) NOT NULL,
	[ObjectType] [varchar](10) NOT NULL,        -- Dim / Ref / Fct
	[LoadLevel] [int] NOT NULL,
	[ScdType] [varchar](10) NULL,               -- SCD1 / SCD2 для Dim і Ref
	[PassCnt] [smallint] NOT NULL,
	[LoadStrategy] [varchar](20) NOT NULL,      -- Full / Incremental (Incremental лише для Fct)
	[WatermarkColumn] [varchar](128) NULL,
	[IsActive] [bit] NOT NULL
)
GO

INSERT INTO [whsilverad].[dwh].[EtlSilverObject]
	([ObjectName],[ObjectType],[LoadLevel],[ScdType],[PassCnt],[LoadStrategy],[WatermarkColumn],[IsActive])
VALUES
	('DimActivityType', 'Dim', 1, 'SCD2', 1, 'Full', NULL, 1),
	('DimAeOutcome', 'Dim', 1, 'SCD2', 1, 'Full', NULL, 1),
	('DimAeSeriousness', 'Dim', 1, 'SCD2', 1, 'Full', NULL, 1),
	('DimChain', 'Dim', 1, 'SCD2', 1, 'Full', NULL, 1),
	('DimLegalEntity', 'Dim', 1, 'SCD2', 1, 'Full', NULL, 1),
	('DimManufacturer', 'Dim', 1, 'SCD2', 1, 'Full', NULL, 1),
	('DimRegion', 'Dim', 1, 'SCD2', 1, 'Full', NULL, 1),
	('DimReportSource', 'Dim', 1, 'SCD2', 1, 'Full', NULL, 1),
	('DimSpecialty', 'Dim', 1, 'SCD2', 1, 'Full', NULL, 1),
	('DimTerritory', 'Dim', 1, 'SCD2', 1, 'Full', NULL, 1),
	('RefMovementType', 'Ref', 1, 'SCD2', 1, 'Full', NULL, 1),
	('DimCity', 'Dim', 2, 'SCD2', 1, 'Full', NULL, 1),
	('DimEmployee', 'Dim', 2, 'SCD2', 2, 'Full', NULL, 1),
	('DimProduct', 'Dim', 2, 'SCD2', 1, 'Full', NULL, 1),
	('DimClientAccount', 'Dim', 3, 'SCD2', 1, 'Full', NULL, 1),
	('DimLpu', 'Dim', 3, 'SCD2', 1, 'Full', NULL, 1),
	('RefEmployee', 'Ref', 3, 'SCD2', 1, 'Full', NULL, 1),
	('RefProduct', 'Ref', 3, 'SCD2', 1, 'Full', NULL, 1),
	('DimDoctor', 'Dim', 4, 'SCD2', 1, 'Full', NULL, 1),
	('RefClientAccount', 'Ref', 4, 'SCD2', 1, 'Full', NULL, 1),
	('DimWarehouse', 'Dim', 5, 'SCD2', 1, 'Full', NULL, 1),
	('RefDoctor', 'Ref', 5, 'SCD2', 1, 'Full', NULL, 1),
	('FctAdverseEvent', 'Fct', 6, NULL, 1, 'Incremental', 'SrcModifiedAt', 1),
	('FctPrescription', 'Fct', 6, NULL, 1, 'Incremental', 'SrcModifiedAt', 1),
	('FctVisit', 'Fct', 6, NULL, 1, 'Incremental', 'SrcModifiedAt', 1),
	('RefWarehouse', 'Ref', 6, 'SCD2', 1, 'Full', NULL, 1),
	('FctInventoryMovement', 'Fct', 7, NULL, 1, 'Incremental', 'SrcModifiedAt', 1),
	('FctSales', 'Fct', 7, NULL, 1, 'Incremental', 'SrcModifiedAt', 1)
GO

/* =========================================================
   4. Watermark
   ========================================================= */

IF OBJECT_ID('dwh.EtlSilverWatermark', 'U') IS NULL
    EXEC('
    CREATE TABLE [whsilverad].[dwh].[EtlSilverWatermark]
    (
        [ObjectName] [varchar](128) NOT NULL,
        [WatermarkValue] [datetime2](3) NULL,
        [LastLoadId] [varchar](250) NULL,
        [ModifiedAt] [datetime2](3) NULL
    )');
GO

INSERT INTO [whsilverad].[dwh].[EtlSilverWatermark] ([ObjectName],[WatermarkValue],[LastLoadId],[ModifiedAt])
SELECT v.ObjectName, v.WatermarkValue, v.LastLoadId, v.ModifiedAt
FROM (VALUES
	('FctSales', '1900-01-01', NULL, NULL),
	('FctInventoryMovement', '1900-01-01', NULL, NULL),
	('FctVisit', '1900-01-01', NULL, NULL),
	('FctPrescription', '1900-01-01', NULL, NULL),
	('FctAdverseEvent', '1900-01-01', NULL, NULL)
) AS v(ObjectName, WatermarkValue, LastLoadId, ModifiedAt)
WHERE NOT EXISTS (
    SELECT 1 FROM [whsilverad].[dwh].[EtlSilverWatermark] w WHERE w.ObjectName = v.ObjectName
);
GO

/* =========================================================
   5. Процедури
   ========================================================= */

CREATE OR ALTER PROCEDURE [dwh].[spSetWatermarkFromTable]
    @object_name NVARCHAR(128),
    @watermark_column NVARCHAR(128),
    @load_id NVARCHAR(250)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @max_wm DATETIME2(3);
    DECLARE @sql NVARCHAR(MAX) =
        N'SELECT @m = MAX(' + QUOTENAME(@watermark_column) + N') FROM [dwh].' + QUOTENAME(@object_name) + N';';

    EXEC sp_executesql @sql, N'@m DATETIME2(3) OUTPUT', @m = @max_wm OUTPUT;

    UPDATE [dwh].[EtlSilverWatermark]
    SET WatermarkValue = ISNULL(@max_wm, '1900-01-01'),
        LastLoadId = @load_id,
        ModifiedAt = SYSUTCDATETIME()
    WHERE ObjectName = @object_name;

    PRINT CONCAT('[spSetWatermarkFromTable] ', @object_name, ' -> ', CONVERT(VARCHAR(30), @max_wm, 121));
END
GO

CREATE OR ALTER PROCEDURE [dwh].[spIncrementalFct]
    @fct_table_name NVARCHAR(250),
    @load_id NVARCHAR(250),
    @watermark_column NVARCHAR(128) = 'SrcModifiedAt'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @schema_name NVARCHAR(3) = 'dwh';
    DECLARE @full_table NVARCHAR(200) = QUOTENAME(@schema_name) + '.' + QUOTENAME(@fct_table_name);
    DECLARE @full_view  NVARCHAR(200) = QUOTENAME(@schema_name) + '.' + QUOTENAME('v' + @fct_table_name);
    DECLARE @sk_key NVARCHAR(150) = 'SK' + @fct_table_name + 'ID';
    DECLARE @current_time DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @wm_col NVARCHAR(150) = QUOTENAME(@watermark_column);

    DECLARE @wm DATETIME2(3);
    SELECT @wm = WatermarkValue FROM [dwh].[EtlSilverWatermark] WHERE ObjectName = @fct_table_name;
    IF @wm IS NULL SET @wm = '1900-01-01';

    DECLARE @sql NVARCHAR(MAX);
    DECLARE @new_wm DATETIME2(3);
    DECLARE @slice_cnt BIGINT;

    -- 1. чи є що вантажити
    SET @sql = N'SELECT @m = MAX(' + @wm_col + N'), @c = COUNT(1) FROM ' + @full_view + N' WHERE ' + @wm_col + N' > @w;';
    EXEC sp_executesql @sql,
         N'@m DATETIME2(3) OUTPUT, @c BIGINT OUTPUT, @w DATETIME2(3)',
         @m = @new_wm OUTPUT, @c = @slice_cnt OUTPUT, @w = @wm;

    PRINT CONCAT('[spIncrementalFct] ', @fct_table_name, ': watermark=', CONVERT(VARCHAR(30), @wm, 121),
                 ', рядків у зрізі=', ISNULL(@slice_cnt, 0));

    IF ISNULL(@slice_cnt, 0) = 0
        RETURN;

    -- 2. прибираємо попередні версії рядків зрізу (upsert за бізнес-ключем ItemId)
    SET @sql = N'DELETE FROM ' + @full_table + N'
                 WHERE ItemId IN (SELECT ItemId FROM ' + @full_view + N' WHERE ' + @wm_col + N' > @w);';
    EXEC sp_executesql @sql, N'@w DATETIME2(3)', @w = @wm;

    -- 3. вставляємо зріз
    SET @sql = N'INSERT INTO ' + @full_table + N'
                 SELECT CAST(HASHBYTES(''SHA1'', CONCAT(NEWID(), SYSDATETIME())) AS BIGINT) AS ' + @sk_key + N',
                        CAST(''' + @load_id + N''' AS VARCHAR(100)) AS CreatedBy,
                        @t AS CreatedAt,
                        v_fct.*
                 FROM ' + @full_view + N' v_fct
                 WHERE v_fct.' + @wm_col + N' > @w;';
    EXEC sp_executesql @sql,
         N'@t DATETIME2(3), @w DATETIME2(3)',
         @t = @current_time, @w = @wm;

    -- 4. просуваємо watermark
    UPDATE [dwh].[EtlSilverWatermark]
    SET WatermarkValue = @new_wm,
        LastLoadId = @load_id,
        ModifiedAt = SYSUTCDATETIME()
    WHERE ObjectName = @fct_table_name;
END
GO

CREATE OR ALTER PROCEDURE [dwh].[spSilverLoadLevel]
    @level INT,
    @load_id NVARCHAR(250) = 'manual_load',
    @root_object NVARCHAR(256) = NULL,   -- NULL = увесь рівень; інакше лише залежні від кореня
    @force_full BIT = 0                  -- 1 = ігнорувати LoadStrategy і перезавантажити факти повністю
AS
BEGIN
    SET NOCOUNT ON;

    IF @root_object = '' SET @root_object = NULL;

    DROP TABLE IF EXISTS #level_objects;

    -- Курсори у Fabric Warehouse не підтримуються -> цикл по пронумерованій тимчасовій таблиці
    SELECT
          ROW_NUMBER() OVER (ORDER BY
              CASE o.ObjectType WHEN 'Dim' THEN 1 WHEN 'Ref' THEN 2 ELSE 3 END,
              o.ObjectName) AS rn
        , o.ObjectName
        , o.ObjectType
        , o.ScdType
        , o.PassCnt
        , o.LoadStrategy
        , o.WatermarkColumn
    INTO #level_objects
    FROM [dwh].[EtlSilverObject] AS o
    WHERE o.LoadLevel = @level
      AND o.IsActive = 1
      AND (
            @root_object IS NULL
         OR EXISTS (
                SELECT 1 FROM [dwh].[EtlObjectDownstream] AS d
                WHERE d.ObjectName = o.ObjectName
                  AND d.RootObject = @root_object
            )
          );

    DECLARE @cnt INT = (SELECT COUNT(1) FROM #level_objects);
    DECLARE @i INT = 1;

    DECLARE @obj VARCHAR(128), @type VARCHAR(10), @scd VARCHAR(10), @pass SMALLINT, @p SMALLINT;
    DECLARE @strategy VARCHAR(20), @wm_col VARCHAR(128);
    DECLARE @started DATETIME2(3), @finished DATETIME2(3), @rowcnt BIGINT, @sql NVARCHAR(MAX);

    PRINT CONCAT('[spSilverLoadLevel] level=', @level, ', objects=', @cnt,
                 ', root=', ISNULL(@root_object, '<all>'), ', force_full=', @force_full,
                 ', load_id=', @load_id);

    WHILE @i <= @cnt
    BEGIN
        SELECT
              @obj      = ObjectName
            , @type     = ObjectType
            , @scd      = ScdType
            , @pass     = PassCnt
            , @strategy = LoadStrategy
            , @wm_col   = WatermarkColumn
        FROM #level_objects
        WHERE rn = @i;

        SET @started = SYSUTCDATETIME();
        SET @rowcnt = NULL;

        BEGIN TRY
            SET @p = 1;

            -- PassCnt > 1 для вимірів із self-reference: другий прохід резолвить власні ключі
            WHILE @p <= @pass
            BEGIN
                IF @type = 'Fct'
                BEGIN
                    IF @force_full = 1 OR ISNULL(@strategy, 'Full') = 'Full'
                    BEGIN
                        EXEC [dwh].[spFullFct] @fct_table_name = @obj, @load_id = @load_id;

                        -- після повного перезавантаження watermark має відповідати вмісту таблиці,
                        -- інакше наступний інкремент пропустить частину рядків
                        IF @wm_col IS NOT NULL
                            EXEC [dwh].[spSetWatermarkFromTable]
                                 @object_name = @obj, @watermark_column = @wm_col, @load_id = @load_id;
                    END
                    ELSE
                        EXEC [dwh].[spIncrementalFct]
                             @fct_table_name = @obj, @load_id = @load_id, @watermark_column = @wm_col;
                END
                ELSE
                    EXEC [dwh].[spUpsertSCDDimension] @dim_table_name = @obj, @scd_type = @scd;

                SET @p = @p + 1;
            END

            SET @sql = N'SELECT @c = COUNT(1) FROM [dwh].' + QUOTENAME(@obj) + N';';
            EXEC sp_executesql @sql, N'@c BIGINT OUTPUT', @c = @rowcnt OUTPUT;

            SET @finished = SYSUTCDATETIME();

            INSERT INTO [dwh].[EtlSilverLoadLog]
                ([LoadId],[ObjectName],[ObjectType],[LoadLevel],[StartedAt],[FinishedAt],[DurationSec],[RowCnt],[Status],[ErrorMessage])
            VALUES
                (@load_id, @obj, @type, @level, @started, @finished,
                 DATEDIFF(MILLISECOND, @started, @finished) / 1000.0, @rowcnt, 'Success', NULL);
        END TRY
        BEGIN CATCH
            SET @finished = SYSUTCDATETIME();

            INSERT INTO [dwh].[EtlSilverLoadLog]
                ([LoadId],[ObjectName],[ObjectType],[LoadLevel],[StartedAt],[FinishedAt],[DurationSec],[RowCnt],[Status],[ErrorMessage])
            VALUES
                (@load_id, @obj, @type, @level, @started, @finished,
                 DATEDIFF(MILLISECOND, @started, @finished) / 1000.0, NULL, 'Failed', LEFT(ERROR_MESSAGE(), 8000));

            -- рівень падає цілком -> pipeline бачить помилку і не йде далі
            THROW;
        END CATCH

        SET @i = @i + 1;
    END
END
GO

CREATE OR ALTER PROCEDURE [dwh].[spSilverLoadSubset]
    @root_object NVARCHAR(256) = NULL,   -- 'lhbronze.erp_erp.CUSTOMERS' | 'dwh.DimRegion' | NULL = усе
    @load_id NVARCHAR(250) = 'manual_subset_load',
    @force_full BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @root_object = '' SET @root_object = NULL;

    IF @root_object IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dwh].[EtlObjectDownstream] WHERE RootObject = @root_object)
    BEGIN
        RAISERROR('Unknown root object: %s. Перелік доступних коренів: SELECT DISTINCT RootObject FROM dwh.EtlObjectDownstream.', 16, 1, @root_object);
        RETURN;
    END

    DECLARE @lvl INT = 1;
    DECLARE @max_lvl INT = (SELECT MAX(LoadLevel) FROM [dwh].[EtlSilverObject] WHERE IsActive = 1);

    -- Fabric Warehouse не дозволяє підзапити всередині CONCAT/PRINT -> рахуємо в змінну
    DECLARE @plan_cnt INT;

    IF @root_object IS NULL
        SELECT @plan_cnt = COUNT(1)
        FROM [dwh].[EtlSilverObject]
        WHERE IsActive = 1;
    ELSE
        SELECT @plan_cnt = COUNT(1)
        FROM [dwh].[EtlObjectDownstream] AS d
        INNER JOIN [dwh].[EtlSilverObject] AS o
            ON o.ObjectName = d.ObjectName
           AND o.IsActive = 1
        WHERE d.RootObject = @root_object;

    PRINT CONCAT('[spSilverLoadSubset] root=', ISNULL(@root_object, '<all>'),
                 ', обʼєктів у плані: ', @plan_cnt, ', force_full=', @force_full);

    WHILE @lvl <= @max_lvl
    BEGIN
        EXEC [dwh].[spSilverLoadLevel]
             @level = @lvl, @load_id = @load_id, @root_object = @root_object, @force_full = @force_full;
        SET @lvl = @lvl + 1;
    END
END
GO

CREATE OR ALTER PROCEDURE [dwh].[spSilverFullLoad]
    @load_id NVARCHAR(250) = 'manual_full_load',
    @force_full BIT = 1                  -- повне завантаження за замовчуванням перезаписує факти цілком
AS
BEGIN
    SET NOCOUNT ON;
    EXEC [dwh].[spSilverLoadSubset] @root_object = NULL, @load_id = @load_id, @force_full = @force_full;
END
GO
