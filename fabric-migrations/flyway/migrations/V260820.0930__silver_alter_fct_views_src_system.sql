-- ClickUp: PHARMA-SILVER-001
-- Fix: vFct* більше не залежать від наявності рядка [dwh].[DimSrcSystem] (Id = 1).
-- Було: CROSS JOIN (SELECT SKSrcSystemKeyID FROM DimSrcSystem WHERE Id = 1 AND EndDate IS NULL) AS ss
--       -> якщо підзапит порожній, CROSS JOIN обнуляв увесь факт (таблиця після spFullFct — порожня).
-- Стало: CTE src_system з агрегатом MAX() без GROUP BY — завжди рівно 1 рядок,
--        відсутнє джерело дає SKSrcSystemKeyID = -1 (unknown member), а не втрату рядків.
--
-- Зміст повторює відповідні view з V260819.1020 (там оновлено для нових середовищ).
GO
--IMPORTANT
USE [whsilverad];
--IMPORTANT
GO

/* =========================================================
   ФАКТИ
   ========================================================= */

CREATE OR ALTER VIEW [dwh].[vFctSales] AS
WITH dedup_sales AS (
    SELECT
          s.*
        , ROW_NUMBER() OVER (PARTITION BY s.order_line_id ORDER BY s.row_id) AS rn
        , COUNT(1)    OVER (PARTITION BY s.order_line_id)                    AS SrcRowCnt
    FROM [lhbronzead].[pharma_erp].[SALES_ORDERS] AS s
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
    FROM [lhbronzead].[pharma_erp].[INVENTORY_MOVEMENTS] AS m
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
    FROM [lhbronzead].[pharma_erp].[DOCTOR_VISITS] AS v
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
    FROM [lhbronzead].[pharma_erp].[PRESCRIPTIONS] AS r
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
    FROM [lhbronzead].[pharma_erp].[ADVERSE_EVENTS] AS a
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
