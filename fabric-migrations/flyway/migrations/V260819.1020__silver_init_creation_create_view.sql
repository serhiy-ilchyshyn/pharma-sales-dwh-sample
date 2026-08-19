-- ClickUp: PHARMA-SILVER-001
-- Джерельні view для silver-об'єктів. Читають bronze lakehouse
-- [lhbronzead].[pharma_erp].* (1:1 копія схеми [erp] з 01_ddl_azure_sql.sql).
--
-- Правила (як у grp-ctl-azure-dwh):
--   * перша колонка vDim*/vRef* = натуральний ключ [Id] — процедура
--     [dwh].[spUpsertSCDDimension] визначає natural key саме за ORDINAL_POSITION = 1;
--   * view не містить SK*ID/технічних колонок — їх додає процедура;
--   * усі SK*KeyID у view обгорнуті в ISNULL(..., -1) -> факти без втрат на inner join;
--   * порядок колонок vFct* має точно збігатися з порядком колонок таблиці Fct*
--     починаючи з SKSrcSystemKeyID (spFullFct робить SELECT ... , v_fct.*).
GO
--IMPORTANT
USE [whsilverad];
--IMPORTANT
GO

/* =========================================================
   ГЕОГРАФІЯ
   ========================================================= */

CREATE OR ALTER VIEW [dwh].[vDimRegion] AS
WITH raw_region AS (
    SELECT region FROM [lhbronzead].[pharma_erp].[CUSTOMERS]
    UNION ALL
    SELECT region FROM [lhbronzead].[pharma_erp].[DOCTORS]
    UNION ALL
    SELECT region FROM [lhbronzead].[pharma_erp].[WAREHOUSES]
    UNION ALL
    SELECT region FROM [lhbronzead].[pharma_erp].[ADVERSE_EVENTS]
)
SELECT DISTINCT
      LTRIM(RTRIM(r.region)) AS Id
    , LTRIM(RTRIM(r.region)) AS Name
FROM raw_region AS r
WHERE NULLIF(LTRIM(RTRIM(r.region)), '') IS NOT NULL
GO

CREATE OR ALTER VIEW [dwh].[vDimCity] AS
WITH raw_city AS (
    SELECT region, city FROM [lhbronzead].[pharma_erp].[CUSTOMERS]
    UNION ALL
    SELECT region, city FROM [lhbronzead].[pharma_erp].[DOCTORS]
    UNION ALL
    SELECT region, city FROM [lhbronzead].[pharma_erp].[WAREHOUSES]
),
dedup_city AS (
    SELECT DISTINCT
          ISNULL(NULLIF(LTRIM(RTRIM(c.region)), ''), 'N/A') AS RegionName
        , LTRIM(RTRIM(c.city))                              AS CityName
    FROM raw_city AS c
    WHERE NULLIF(LTRIM(RTRIM(c.city)), '') IS NOT NULL
)
SELECT
      CONCAT(c.RegionName, '|', c.CityName) AS Id
    , c.CityName                            AS Name
    , ISNULL(reg.SKRegionKeyID, -1)         AS SKRegionKeyID
FROM dedup_city AS c
LEFT JOIN [whsilverad].[dwh].[DimRegion] AS reg
    ON  reg.Id = c.RegionName
    AND reg.EndDate IS NULL
GO

CREATE OR ALTER VIEW [dwh].[vDimTerritory] AS
SELECT DISTINCT
      LTRIM(RTRIM(e.territory)) AS Id
    , LTRIM(RTRIM(e.territory)) AS Name
FROM [lhbronzead].[pharma_erp].[EMPLOYEES] AS e
WHERE NULLIF(LTRIM(RTRIM(e.territory)), '') IS NOT NULL
GO

CREATE OR ALTER VIEW [dwh].[vDimChain] AS
SELECT DISTINCT
      LTRIM(RTRIM(c.chain_name)) AS Id
    , LTRIM(RTRIM(c.chain_name)) AS Name
FROM [lhbronzead].[pharma_erp].[CUSTOMERS] AS c
WHERE NULLIF(LTRIM(RTRIM(c.chain_name)), '') IS NOT NULL
GO

/* =========================================================
   ЮРИДИЧНІ ОСОБИ (ЄДРПОУ) — база для склеювання дублів клієнтів
   ========================================================= */

CREATE OR ALTER VIEW [dwh].[vDimLegalEntity] AS
WITH latest_customer AS (
    SELECT
          c.*
        , ROW_NUMBER() OVER (PARTITION BY c.customer_id ORDER BY c.updated_at DESC, c.row_id DESC) AS rn
    FROM [lhbronzead].[pharma_erp].[CUSTOMERS] AS c
),
legal_entity AS (
    SELECT
          LTRIM(RTRIM(lc.edrpou)) AS EDRPOU
        , lc.name
        , lc.tax_id
        , ROW_NUMBER() OVER (
              PARTITION BY LTRIM(RTRIM(lc.edrpou))
              ORDER BY lc.created_at, lc.customer_id
          ) AS rn_le
    FROM latest_customer AS lc
    WHERE lc.rn = 1
      AND NULLIF(LTRIM(RTRIM(lc.edrpou)), '') IS NOT NULL
)
SELECT
      le.EDRPOU              AS Id
    , ISNULL(le.name, 'N/A') AS Name
    , le.EDRPOU              AS EDRPOU
    , ISNULL(le.tax_id, 'N/A') AS TaxId
FROM legal_entity AS le
WHERE le.rn_le = 1
GO

/* =========================================================
   ПРОДУКТИ
   ========================================================= */

CREATE OR ALTER VIEW [dwh].[vDimManufacturer] AS
SELECT DISTINCT
      LTRIM(RTRIM(p.manufacturer)) AS Id
    , LTRIM(RTRIM(p.manufacturer)) AS Name
FROM [lhbronzead].[pharma_erp].[PRODUCTS] AS p
WHERE NULLIF(LTRIM(RTRIM(p.manufacturer)), '') IS NOT NULL
GO

-- erp.PRODUCTS веде власну SCD2-історію (кілька рядків на product_id).
-- У silver беремо актуальну версію джерела, історизацію робить сам silver (SCD2).
CREATE OR ALTER VIEW [dwh].[vDimProduct] AS
WITH latest_product AS (
    SELECT
          p.*
        , ROW_NUMBER() OVER (PARTITION BY p.product_id ORDER BY p.updated_at DESC, p.row_id DESC) AS rn
    FROM [lhbronzead].[pharma_erp].[PRODUCTS] AS p
)
SELECT
      lp.product_id                             AS Id
    , ISNULL(lp.brand_name, 'N/A')              AS Name
    , ISNULL(lp.sku_code, 'N/A')                AS SkuCode
    , ISNULL(lp.barcode, 'N/A')                 AS Barcode
    , ISNULL(lp.registration_number, 'N/A')     AS RegistrationNumber
    , ISNULL(lp.inn, 'N/A')                     AS INN
    , ISNULL(lp.atc_code, 'N/A')                AS AtcCode
    , ISNULL(atc.SKAtcClassKeyID, -1)           AS SKAtcClassKeyID
    , ISNULL(lp.form, 'N/A')                    AS ReleaseForm
    , ISNULL(lp.dosage, 'N/A')                  AS Dosage
    , ISNULL(man.SKManufacturerKeyID, -1)       AS SKManufacturerKeyID
    , ISNULL(lp.rx_otc, 'N/A')                  AS RxOtcType
    , lp.base_price_uah                         AS BasePriceUAH
    , lp.is_active                              AS IsActive
    , CAST(CASE WHEN atc.SKAtcClassKeyID IS NULL THEN 0 ELSE 1 END AS bit) AS IsAtcCodeValid
    , CAST(lp.created_at AS datetime2(3))       AS SrcCreatedAt
FROM latest_product AS lp
LEFT JOIN [whsilverad].[dwh].[DimManufacturer] AS man
    ON  man.Id = LTRIM(RTRIM(lp.manufacturer))
    AND man.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[DimAtcClass] AS atc
    ON  atc.Id = LEFT(LTRIM(RTRIM(lp.atc_code)), 1)
    AND atc.SKAtcClassKeyID <> -1
    AND atc.EndDate IS NULL
WHERE lp.rn = 1
GO

/* =========================================================
   КЛІЄНТИ (golden record: дублі з однаковим ЄДРПОУ склеюються)
   ========================================================= */

CREATE OR ALTER VIEW [dwh].[vDimClientAccount] AS
WITH latest_customer AS (
    SELECT
          c.*
        , ROW_NUMBER() OVER (PARTITION BY c.customer_id ORDER BY c.updated_at DESC, c.row_id DESC) AS rn
    FROM [lhbronzead].[pharma_erp].[CUSTOMERS] AS c
),
golden AS (
    SELECT
          lc.*
        , MIN(lc.customer_id) OVER (
              PARTITION BY COALESCE(NULLIF(LTRIM(RTRIM(lc.edrpou)), ''), lc.customer_id)
          ) AS GoldenCustomerId
        , COUNT(1) OVER (
              PARTITION BY COALESCE(NULLIF(LTRIM(RTRIM(lc.edrpou)), ''), lc.customer_id)
          ) AS SrcDuplicateCnt
    FROM latest_customer AS lc
    WHERE lc.rn = 1
)
SELECT
      g.customer_id                       AS Id
    , ISNULL(g.name, 'N/A')               AS Name
    , ISNULL(g.customer_type, 'N/A')      AS AccountType
    , ISNULL(ch.SKChainKeyID, -1)         AS SKChainKeyID
    , ISNULL(le.SKLegalEntityKeyID, -1)   AS SKLegalEntityKeyID
    , ISNULL(reg.SKRegionKeyID, -1)       AS SKRegionKeyID
    , ISNULL(cty.SKCityKeyID, -1)         AS SKCityKeyID
    , ISNULL(g.address, 'N/A')            AS Address
    , g.is_active                         AS IsActive
    , g.SrcDuplicateCnt                   AS SrcDuplicateCnt
    , CAST(g.created_at AS datetime2(3))  AS SrcCreatedAt
FROM golden AS g
LEFT JOIN [whsilverad].[dwh].[DimChain] AS ch
    ON  ch.Id = LTRIM(RTRIM(g.chain_name))
    AND ch.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[DimLegalEntity] AS le
    ON  le.Id = LTRIM(RTRIM(g.edrpou))
    AND le.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[DimRegion] AS reg
    ON  reg.Id = LTRIM(RTRIM(g.region))
    AND reg.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[DimCity] AS cty
    ON  cty.Id = CONCAT(ISNULL(NULLIF(LTRIM(RTRIM(g.region)), ''), 'N/A'), '|', LTRIM(RTRIM(g.city)))
    AND cty.EndDate IS NULL
WHERE g.customer_id = g.GoldenCustomerId
GO

/* =========================================================
   HCP (лікарі, спеціальності, ЛПУ)
   ========================================================= */

CREATE OR ALTER VIEW [dwh].[vDimSpecialty] AS
SELECT
      UPPER(LTRIM(RTRIM(d.specialty))) AS Id
    , MIN(LTRIM(RTRIM(d.specialty)))   AS Name
FROM [lhbronzead].[pharma_erp].[DOCTORS] AS d
WHERE NULLIF(LTRIM(RTRIM(d.specialty)), '') IS NOT NULL
GROUP BY UPPER(LTRIM(RTRIM(d.specialty)))
GO

CREATE OR ALTER VIEW [dwh].[vDimLpu] AS
WITH lpu AS (
    SELECT
          UPPER(LTRIM(RTRIM(d.lpu_name))) AS LpuKey
        , MIN(LTRIM(RTRIM(d.lpu_name)))   AS LpuName
        , MIN(LTRIM(RTRIM(d.region)))     AS RegionName
        , MIN(LTRIM(RTRIM(d.city)))       AS CityName
    FROM [lhbronzead].[pharma_erp].[DOCTORS] AS d
    WHERE NULLIF(LTRIM(RTRIM(d.lpu_name)), '') IS NOT NULL
    GROUP BY UPPER(LTRIM(RTRIM(d.lpu_name)))
)
SELECT
      l.LpuKey                     AS Id
    , l.LpuName                    AS Name
    , ISNULL(reg.SKRegionKeyID, -1) AS SKRegionKeyID
    , ISNULL(cty.SKCityKeyID, -1)   AS SKCityKeyID
FROM lpu AS l
LEFT JOIN [whsilverad].[dwh].[DimRegion] AS reg
    ON  reg.Id = l.RegionName
    AND reg.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[DimCity] AS cty
    ON  cty.Id = CONCAT(ISNULL(NULLIF(l.RegionName, ''), 'N/A'), '|', l.CityName)
    AND cty.EndDate IS NULL
GO

-- Golden record лікаря: ПІБ + ЛПУ (дублі мають інший doctor_id та інший регістр спеціальності)
CREATE OR ALTER VIEW [dwh].[vDimDoctor] AS
WITH latest_doctor AS (
    SELECT
          d.*
        , ROW_NUMBER() OVER (PARTITION BY d.doctor_id ORDER BY d.updated_at DESC, d.row_id DESC) AS rn
    FROM [lhbronzead].[pharma_erp].[DOCTORS] AS d
),
keyed AS (
    SELECT
          ld.*
        , UPPER(CONCAT(
              ISNULL(LTRIM(RTRIM(ld.last_name)), ''), '|',
              ISNULL(LTRIM(RTRIM(ld.first_name)), ''), '|',
              ISNULL(LTRIM(RTRIM(ld.middle_name)), ''), '|',
              ISNULL(LTRIM(RTRIM(ld.lpu_name)), '')
          )) AS DedupKey
    FROM latest_doctor AS ld
    WHERE ld.rn = 1
),
golden AS (
    SELECT
          k.*
        , MIN(k.doctor_id) OVER (PARTITION BY k.DedupKey) AS GoldenDoctorId
        , COUNT(1) OVER (PARTITION BY k.DedupKey)         AS SrcDuplicateCnt
    FROM keyed AS k
)
SELECT
      g.doctor_id AS Id
    , LTRIM(RTRIM(CONCAT(
          ISNULL(g.last_name, ''), ' ',
          ISNULL(g.first_name, ''), ' ',
          ISNULL(g.middle_name, '')
      )))                                 AS Name
    , ISNULL(g.last_name, 'N/A')          AS LastName
    , ISNULL(g.first_name, 'N/A')         AS FirstName
    , ISNULL(g.middle_name, 'N/A')        AS MiddleName
    , ISNULL(spec.SKSpecialtyKeyID, -1)   AS SKSpecialtyKeyID
    , ISNULL(lpu.SKLpuKeyID, -1)          AS SKLpuKeyID
    , ISNULL(reg.SKRegionKeyID, -1)       AS SKRegionKeyID
    , ISNULL(cty.SKCityKeyID, -1)         AS SKCityKeyID
    , ISNULL(g.segment, 'N')              AS Segment
    , g.target_flag                       AS IsTarget
    , g.SrcDuplicateCnt                   AS SrcDuplicateCnt
    , CAST(g.created_at AS datetime2(3))  AS SrcCreatedAt
FROM golden AS g
LEFT JOIN [whsilverad].[dwh].[DimSpecialty] AS spec
    ON  spec.Id = UPPER(LTRIM(RTRIM(g.specialty)))
    AND spec.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[DimLpu] AS lpu
    ON  lpu.Id = UPPER(LTRIM(RTRIM(g.lpu_name)))
    AND lpu.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[DimRegion] AS reg
    ON  reg.Id = LTRIM(RTRIM(g.region))
    AND reg.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[DimCity] AS cty
    ON  cty.Id = CONCAT(ISNULL(NULLIF(LTRIM(RTRIM(g.region)), ''), 'N/A'), '|', LTRIM(RTRIM(g.city)))
    AND cty.EndDate IS NULL
WHERE g.doctor_id = g.GoldenDoctorId
GO

/* =========================================================
   ПЕРСОНАЛ ТА СКЛАДИ
   ========================================================= */

-- SKEmployeeManagerKeyID резолвиться з уже завантаженого DimEmployee:
-- на першому прогоні керівники отримують -1, на наступному — коректний durable key.
CREATE OR ALTER VIEW [dwh].[vDimEmployee] AS
WITH latest_employee AS (
    SELECT
          e.*
        , ROW_NUMBER() OVER (PARTITION BY e.employee_id ORDER BY e.updated_at DESC, e.row_id DESC) AS rn
    FROM [lhbronzead].[pharma_erp].[EMPLOYEES] AS e
)
SELECT
      le.employee_id                      AS Id
    , ISNULL(le.full_name, 'N/A')         AS Name
    , ISNULL(le.role, 'N/A')              AS EmployeeRole
    , ISNULL(ter.SKTerritoryKeyID, -1)    AS SKTerritoryKeyID
    , ISNULL(le.line, 'N/A')              AS ProductLine
    , ISNULL(mgr.SKEmployeeKeyID, -1)     AS SKEmployeeManagerKeyID
    , le.hire_date                        AS HireDate
    , le.is_active                        AS IsActive
    , CAST(le.created_at AS datetime2(3)) AS SrcCreatedAt
FROM latest_employee AS le
LEFT JOIN [whsilverad].[dwh].[DimTerritory] AS ter
    ON  ter.Id = LTRIM(RTRIM(le.territory))
    AND ter.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[DimEmployee] AS mgr
    ON  mgr.Id = le.manager_id
    AND mgr.EndDate IS NULL
    AND mgr.SKEmployeeKeyID <> -1
WHERE le.rn = 1
GO

CREATE OR ALTER VIEW [dwh].[vDimWarehouse] AS
WITH latest_warehouse AS (
    SELECT
          w.*
        , ROW_NUMBER() OVER (PARTITION BY w.warehouse_id ORDER BY w.updated_at DESC, w.row_id DESC) AS rn
    FROM [lhbronzead].[pharma_erp].[WAREHOUSES] AS w
)
SELECT
      lw.warehouse_id                         AS Id
    , ISNULL(lw.name, 'N/A')                  AS Name
    , ISNULL(lw.warehouse_code, 'N/A')        AS WarehouseCode
    , ISNULL(lw.warehouse_type, 'N/A')        AS WarehouseType
    , ISNULL(rca.SKClientAccountKeyID, -1)    AS SKClientAccountOwnerKeyID
    , ISNULL(reg.SKRegionKeyID, -1)           AS SKRegionKeyID
    , ISNULL(cty.SKCityKeyID, -1)             AS SKCityKeyID
    , CAST(lw.created_at AS datetime2(3))     AS SrcCreatedAt
FROM latest_warehouse AS lw
LEFT JOIN [whsilverad].[dwh].[RefClientAccount] AS rca
    ON  rca.Id = lw.owner_customer_id
    AND rca.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[DimRegion] AS reg
    ON  reg.Id = LTRIM(RTRIM(lw.region))
    AND reg.EndDate IS NULL
LEFT JOIN [whsilverad].[dwh].[DimCity] AS cty
    ON  cty.Id = CONCAT(ISNULL(NULLIF(LTRIM(RTRIM(lw.region)), ''), 'N/A'), '|', LTRIM(RTRIM(lw.city)))
    AND cty.EndDate IS NULL
WHERE lw.rn = 1
GO

/* =========================================================
   ВИМІРИ АКТИВНОСТЕЙ ТА ФАРМАКОНАГЛЯДУ
   ========================================================= */

CREATE OR ALTER VIEW [dwh].[vDimActivityType] AS
SELECT DISTINCT
      LTRIM(RTRIM(v.activity_type)) AS Id
    , LTRIM(RTRIM(v.activity_type)) AS Name
    , CAST(CASE WHEN LTRIM(RTRIM(v.activity_type)) = 'EDetailing' THEN 1 ELSE 0 END AS bit)               AS IsRemote
    , CAST(CASE WHEN LTRIM(RTRIM(v.activity_type)) IN ('RoundTable', 'Symposium') THEN 1 ELSE 0 END AS bit) AS IsGroupEvent
FROM [lhbronzead].[pharma_erp].[DOCTOR_VISITS] AS v
WHERE NULLIF(LTRIM(RTRIM(v.activity_type)), '') IS NOT NULL
GO

CREATE OR ALTER VIEW [dwh].[vDimAeSeriousness] AS
SELECT DISTINCT
      LTRIM(RTRIM(a.seriousness)) AS Id
    , LTRIM(RTRIM(a.seriousness)) AS Name
    , CAST(CASE LTRIM(RTRIM(a.seriousness))
               WHEN 'Non-serious' THEN 1
               WHEN 'Serious'     THEN 2
               WHEN 'Critical'    THEN 3
               ELSE 0
           END AS smallint) AS SeverityRank
FROM [lhbronzead].[pharma_erp].[ADVERSE_EVENTS] AS a
WHERE NULLIF(LTRIM(RTRIM(a.seriousness)), '') IS NOT NULL
GO

CREATE OR ALTER VIEW [dwh].[vDimAeOutcome] AS
SELECT DISTINCT
      LTRIM(RTRIM(a.outcome)) AS Id
    , LTRIM(RTRIM(a.outcome)) AS Name
    , CAST(CASE WHEN LTRIM(RTRIM(a.outcome)) = 'Fatal' THEN 1 ELSE 0 END AS bit) AS IsFatal
    , CAST(CASE WHEN LTRIM(RTRIM(a.outcome)) IN ('Recovered', 'Recovered with sequelae') THEN 1 ELSE 0 END AS bit) AS IsRecovered
FROM [lhbronzead].[pharma_erp].[ADVERSE_EVENTS] AS a
WHERE NULLIF(LTRIM(RTRIM(a.outcome)), '') IS NOT NULL
GO

CREATE OR ALTER VIEW [dwh].[vDimReportSource] AS
SELECT DISTINCT
      LTRIM(RTRIM(a.report_source)) AS Id
    , LTRIM(RTRIM(a.report_source)) AS Name
    , CAST(CASE WHEN LTRIM(RTRIM(a.report_source)) = 'HCP' THEN 1 ELSE 0 END AS bit) AS IsHcpReported
FROM [lhbronzead].[pharma_erp].[ADVERSE_EVENTS] AS a
WHERE NULLIF(LTRIM(RTRIM(a.report_source)), '') IS NOT NULL
GO

/* =========================================================
   REFERENCE VIEWS (ключ джерела -> durable key виміру)
   ========================================================= */

CREATE OR ALTER VIEW [dwh].[vRefProduct] AS
WITH latest_product AS (
    SELECT
          p.*
        , ROW_NUMBER() OVER (PARTITION BY p.product_id ORDER BY p.updated_at DESC, p.row_id DESC) AS rn
    FROM [lhbronzead].[pharma_erp].[PRODUCTS] AS p
)
SELECT
      lp.product_id                    AS Id
    , ISNULL(ss.SKSrcSystemKeyID, -1)  AS SKSrcSystemKeyID
    , ISNULL(lp.sku_code, 'N/A')       AS RawSkuCode
    , ISNULL(lp.brand_name, 'N/A')     AS RawBrandName
    , ISNULL(dp.SKProductKeyID, -1)    AS SKProductKeyID
FROM latest_product AS lp
CROSS JOIN (SELECT SKSrcSystemKeyID FROM [whsilverad].[dwh].[DimSrcSystem] WHERE Id = 1 AND EndDate IS NULL) AS ss
LEFT JOIN [whsilverad].[dwh].[DimProduct] AS dp
    ON  dp.Id = lp.product_id
    AND dp.EndDate IS NULL
WHERE lp.rn = 1
GO

CREATE OR ALTER VIEW [dwh].[vRefClientAccount] AS
WITH latest_customer AS (
    SELECT
          c.*
        , ROW_NUMBER() OVER (PARTITION BY c.customer_id ORDER BY c.updated_at DESC, c.row_id DESC) AS rn
    FROM [lhbronzead].[pharma_erp].[CUSTOMERS] AS c
),
golden AS (
    SELECT
          lc.*
        , MIN(lc.customer_id) OVER (
              PARTITION BY COALESCE(NULLIF(LTRIM(RTRIM(lc.edrpou)), ''), lc.customer_id)
          ) AS GoldenCustomerId
    FROM latest_customer AS lc
    WHERE lc.rn = 1
)
SELECT
      g.customer_id                                   AS Id
    , ISNULL(ss.SKSrcSystemKeyID, -1)                 AS SKSrcSystemKeyID
    , ISNULL(g.name, 'N/A')                           AS RawName
    , ISNULL(NULLIF(LTRIM(RTRIM(g.edrpou)), ''), 'N/A') AS RawEDRPOU
    , CAST(CASE WHEN g.customer_id = g.GoldenCustomerId THEN 1 ELSE 0 END AS bit) AS IsGoldenRecord
    , ISNULL(dca.SKClientAccountKeyID, -1)            AS SKClientAccountKeyID
FROM golden AS g
CROSS JOIN (SELECT SKSrcSystemKeyID FROM [whsilverad].[dwh].[DimSrcSystem] WHERE Id = 1 AND EndDate IS NULL) AS ss
LEFT JOIN [whsilverad].[dwh].[DimClientAccount] AS dca
    ON  dca.Id = g.GoldenCustomerId
    AND dca.EndDate IS NULL
GO

CREATE OR ALTER VIEW [dwh].[vRefDoctor] AS
WITH latest_doctor AS (
    SELECT
          d.*
        , ROW_NUMBER() OVER (PARTITION BY d.doctor_id ORDER BY d.updated_at DESC, d.row_id DESC) AS rn
    FROM [lhbronzead].[pharma_erp].[DOCTORS] AS d
),
keyed AS (
    SELECT
          ld.*
        , UPPER(CONCAT(
              ISNULL(LTRIM(RTRIM(ld.last_name)), ''), '|',
              ISNULL(LTRIM(RTRIM(ld.first_name)), ''), '|',
              ISNULL(LTRIM(RTRIM(ld.middle_name)), ''), '|',
              ISNULL(LTRIM(RTRIM(ld.lpu_name)), '')
          )) AS DedupKey
    FROM latest_doctor AS ld
    WHERE ld.rn = 1
),
golden AS (
    SELECT
          k.*
        , MIN(k.doctor_id) OVER (PARTITION BY k.DedupKey) AS GoldenDoctorId
    FROM keyed AS k
)
SELECT
      g.doctor_id                       AS Id
    , ISNULL(ss.SKSrcSystemKeyID, -1)   AS SKSrcSystemKeyID
    , LTRIM(RTRIM(CONCAT(
          ISNULL(g.last_name, ''), ' ',
          ISNULL(g.first_name, ''), ' ',
          ISNULL(g.middle_name, '')
      )))                               AS RawFullName
    , ISNULL(g.lpu_name, 'N/A')         AS RawLpuName
    , CAST(CASE WHEN g.doctor_id = g.GoldenDoctorId THEN 1 ELSE 0 END AS bit) AS IsGoldenRecord
    , ISNULL(dd.SKDoctorKeyID, -1)      AS SKDoctorKeyID
FROM golden AS g
CROSS JOIN (SELECT SKSrcSystemKeyID FROM [whsilverad].[dwh].[DimSrcSystem] WHERE Id = 1 AND EndDate IS NULL) AS ss
LEFT JOIN [whsilverad].[dwh].[DimDoctor] AS dd
    ON  dd.Id = g.GoldenDoctorId
    AND dd.EndDate IS NULL
GO

CREATE OR ALTER VIEW [dwh].[vRefEmployee] AS
WITH latest_employee AS (
    SELECT
          e.*
        , ROW_NUMBER() OVER (PARTITION BY e.employee_id ORDER BY e.updated_at DESC, e.row_id DESC) AS rn
    FROM [lhbronzead].[pharma_erp].[EMPLOYEES] AS e
)
SELECT
      le.employee_id                   AS Id
    , ISNULL(ss.SKSrcSystemKeyID, -1)  AS SKSrcSystemKeyID
    , ISNULL(le.full_name, 'N/A')      AS RawFullName
    , ISNULL(de.SKEmployeeKeyID, -1)   AS SKEmployeeKeyID
FROM latest_employee AS le
CROSS JOIN (SELECT SKSrcSystemKeyID FROM [whsilverad].[dwh].[DimSrcSystem] WHERE Id = 1 AND EndDate IS NULL) AS ss
LEFT JOIN [whsilverad].[dwh].[DimEmployee] AS de
    ON  de.Id = le.employee_id
    AND de.EndDate IS NULL
WHERE le.rn = 1
GO

CREATE OR ALTER VIEW [dwh].[vRefWarehouse] AS
WITH latest_warehouse AS (
    SELECT
          w.*
        , ROW_NUMBER() OVER (PARTITION BY w.warehouse_id ORDER BY w.updated_at DESC, w.row_id DESC) AS rn
    FROM [lhbronzead].[pharma_erp].[WAREHOUSES] AS w
)
SELECT
      lw.warehouse_id                  AS Id
    , ISNULL(ss.SKSrcSystemKeyID, -1)  AS SKSrcSystemKeyID
    , ISNULL(lw.name, 'N/A')           AS RawName
    , ISNULL(dw.SKWarehouseKeyID, -1)  AS SKWarehouseKeyID
FROM latest_warehouse AS lw
CROSS JOIN (SELECT SKSrcSystemKeyID FROM [whsilverad].[dwh].[DimSrcSystem] WHERE Id = 1 AND EndDate IS NULL) AS ss
LEFT JOIN [whsilverad].[dwh].[DimWarehouse] AS dw
    ON  dw.Id = lw.warehouse_id
    AND dw.EndDate IS NULL
WHERE lw.rn = 1
GO

-- Сирі типи рухів джерела (укр. та англ. варіанти) -> канонічний DimMovementType
CREATE OR ALTER VIEW [dwh].[vRefMovementType] AS
WITH raw_type AS (
    SELECT DISTINCT
        LTRIM(RTRIM(m.movement_type)) AS RawMovementType
    FROM [lhbronzead].[pharma_erp].[INVENTORY_MOVEMENTS] AS m
    WHERE NULLIF(LTRIM(RTRIM(m.movement_type)), '') IS NOT NULL
),
mapped AS (
    SELECT
          rt.RawMovementType
        , CASE
              WHEN rt.RawMovementType IN ('IN', 'Прихід')             THEN 'IN'
              WHEN rt.RawMovementType IN ('OUT', 'Видача')            THEN 'OUT'
              WHEN rt.RawMovementType IN ('TRANSFER', 'Переміщення')  THEN 'TRANSFER'
              WHEN rt.RawMovementType IN ('WRITEOFF', 'Списання')     THEN 'WRITEOFF'
              ELSE 'N/A'
          END AS MovementTypeId
    FROM raw_type AS rt
)
SELECT
      m.RawMovementType                  AS Id
    , ISNULL(ss.SKSrcSystemKeyID, -1)    AS SKSrcSystemKeyID
    , m.RawMovementType                  AS RawMovementType
    , ISNULL(dmt.SKMovementTypeKeyID, -1) AS SKMovementTypeKeyID
FROM mapped AS m
CROSS JOIN (SELECT SKSrcSystemKeyID FROM [whsilverad].[dwh].[DimSrcSystem] WHERE Id = 1 AND EndDate IS NULL) AS ss
LEFT JOIN [whsilverad].[dwh].[DimMovementType] AS dmt
    ON  dmt.Id = m.MovementTypeId
    AND dmt.SKMovementTypeKeyID <> -1
    AND dmt.EndDate IS NULL
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
)
SELECT
      ISNULL(ss.SKSrcSystemKeyID, -1)                  AS SKSrcSystemKeyID
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
CROSS JOIN (SELECT SKSrcSystemKeyID FROM [whsilverad].[dwh].[DimSrcSystem] WHERE Id = 1 AND EndDate IS NULL) AS ss
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
)
SELECT
      ISNULL(ss.SKSrcSystemKeyID, -1)             AS SKSrcSystemKeyID
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
CROSS JOIN (SELECT SKSrcSystemKeyID FROM [whsilverad].[dwh].[DimSrcSystem] WHERE Id = 1 AND EndDate IS NULL) AS ss
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
)
SELECT
      ISNULL(ss.SKSrcSystemKeyID, -1)          AS SKSrcSystemKeyID
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
CROSS JOIN (SELECT SKSrcSystemKeyID FROM [whsilverad].[dwh].[DimSrcSystem] WHERE Id = 1 AND EndDate IS NULL) AS ss
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
)
SELECT
      ISNULL(ss.SKSrcSystemKeyID, -1)            AS SKSrcSystemKeyID
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
CROSS JOIN (SELECT SKSrcSystemKeyID FROM [whsilverad].[dwh].[DimSrcSystem] WHERE Id = 1 AND EndDate IS NULL) AS ss
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
)
SELECT
      ISNULL(ss.SKSrcSystemKeyID, -1)                  AS SKSrcSystemKeyID
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
CROSS JOIN (SELECT SKSrcSystemKeyID FROM [whsilverad].[dwh].[DimSrcSystem] WHERE Id = 1 AND EndDate IS NULL) AS ss
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
