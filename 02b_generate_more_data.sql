-- =====================================================================
-- Pharma ERP — ІНКРЕМЕНТАЛЬНИЙ догенератор даних (append-only)
--
-- Відмінності від 02_generate_data_fixed.sql:
--   * НЕ робить TRUNCATE — тільки додає рядки;
--   * нумерація бізнес-ключів продовжується від максимуму в таблиці
--     (ORD-/MOV-/VIS-/RX-/AE-/CST-/DOC-), тож колізій із наявними ключами немає
--     — інакше silver викинув би нові рядки дедупом по бізнес-ключу;
--   * факти посилаються на вже наявні довідники (продукти, клієнти, лікарі,
--     співробітники, склади), опційно додаються нові клієнти/лікарі;
--   * дефекти застосовуються ТІЛЬКИ до щойно вставлених рядків
--     (по row_id > знімка до вставки), історичні дані не мутують.
--
-- Після виконання: EXEC [dwh].[spSilverFullLoad] @load_id = 'after_incr_load';
--   факти перезавантажаться повністю, нові клієнти/лікарі додадуться у виміри,
--   зміни цін створять нові SCD2-версії DimProduct.
-- =====================================================================

SET NOCOUNT ON;

-- ---------- CONFIG ----------
-- Період нових фактів. NULL = продовжити з наступного дня після останньої
-- коректної дати продажів до сьогодні.
DECLARE @DateStart          DATE = NULL;
DECLARE @DateEnd            DATE = NULL;

DECLARE @N_NewCustomers     INT = 50;      -- нові клієнти (0 = не додавати)
DECLARE @N_NewDoctors       INT = 200;     -- нові лікарі (0 = не додавати)
DECLARE @N_PriceChanges     INT = 30;      -- нові SCD2-версії продуктів (зміна ціни)

DECLARE @N_Sales            INT = 20000;
DECLARE @N_SalesDups        INT = 400;
DECLARE @N_Inventory        INT = 30000;
DECLARE @N_InventoryDups    INT = 600;
DECLARE @N_Visits           INT = 6000;
DECLARE @N_VisitDups        INT = 120;
DECLARE @N_Rx               INT = 12000;
DECLARE @N_RxDups           INT = 240;
DECLARE @N_AE               INT = 2000;

IF @DateStart IS NULL
    SET @DateStart = ISNULL((
        SELECT DATEADD(DAY, 1, MAX(order_date))
        FROM erp.SALES_ORDERS
        WHERE order_date <= CAST(SYSDATETIME() AS DATE)   -- ігноруємо дефектні дати з майбутнього
    ), '2026-08-15');

IF @DateEnd IS NULL
    SET @DateEnd = CAST(SYSDATETIME() AS DATE);

IF @DateEnd < @DateStart
    SET @DateEnd = @DateStart;

DECLARE @DateRangeDays INT = DATEDIFF(DAY, @DateStart, @DateEnd) + 1;

PRINT CONCAT('Новий період фактів: ', CONVERT(VARCHAR(10), @DateStart, 120),
             ' .. ', CONVERT(VARCHAR(10), @DateEnd, 120),
             ' (', @DateRangeDays, ' днів)');


-- =====================================================================
-- TALLY
-- =====================================================================
IF OBJECT_ID('tempdb..#Nums') IS NOT NULL DROP TABLE #Nums;
CREATE TABLE #Nums (n INT PRIMARY KEY);
INSERT INTO #Nums (n)
SELECT TOP (100000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
FROM sys.all_columns a CROSS JOIN sys.all_columns b;


-- =====================================================================
-- OFFSET-и бізнес-ключів (продовжуємо наскрізну нумерацію)
-- Базові діапазони: CST-/DOC- < 90000 (90000+ — дублі, 7xxxxx/8xxxxx — orphan-и у фактах)
-- =====================================================================
DECLARE @OffSales INT = ISNULL((SELECT MAX(TRY_CAST(SUBSTRING(order_line_id, 5, 7) AS INT)) FROM erp.SALES_ORDERS), 0);
DECLARE @OffMov   INT = ISNULL((SELECT MAX(TRY_CAST(SUBSTRING(movement_id,   5, 8) AS INT)) FROM erp.INVENTORY_MOVEMENTS), 0);
DECLARE @OffVis   INT = ISNULL((SELECT MAX(TRY_CAST(SUBSTRING(visit_id,      5, 7) AS INT)) FROM erp.DOCTOR_VISITS), 0);
DECLARE @OffRx    INT = ISNULL((SELECT MAX(TRY_CAST(SUBSTRING(prescription_id, 4, 7) AS INT)) FROM erp.PRESCRIPTIONS), 0);
DECLARE @OffAe    INT = ISNULL((SELECT MAX(TRY_CAST(SUBSTRING(ae_id,         4, 6) AS INT)) FROM erp.ADVERSE_EVENTS), 0);
DECLARE @OffCust  INT = ISNULL((SELECT MAX(v) FROM (SELECT TRY_CAST(SUBSTRING(customer_id, 5, 5) AS INT) AS v FROM erp.CUSTOMERS) x WHERE v < 90000), 0);
DECLARE @OffDoc   INT = ISNULL((SELECT MAX(v) FROM (SELECT TRY_CAST(SUBSTRING(doctor_id,   5, 5) AS INT) AS v FROM erp.DOCTORS)   x WHERE v < 90000), 0);

PRINT CONCAT('Offsets: sales=', @OffSales, ', mov=', @OffMov, ', vis=', @OffVis,
             ', rx=', @OffRx, ', ae=', @OffAe, ', cust=', @OffCust, ', doc=', @OffDoc);

-- знімок max(row_id) до вставки — щоб дефекти чіпали лише нові рядки
DECLARE @RowIdSales BIGINT = ISNULL((SELECT MAX(row_id) FROM erp.SALES_ORDERS), 0);
DECLARE @RowIdMov   BIGINT = ISNULL((SELECT MAX(row_id) FROM erp.INVENTORY_MOVEMENTS), 0);
DECLARE @RowIdVis   BIGINT = ISNULL((SELECT MAX(row_id) FROM erp.DOCTOR_VISITS), 0);
DECLARE @RowIdRx    BIGINT = ISNULL((SELECT MAX(row_id) FROM erp.PRESCRIPTIONS), 0);
DECLARE @RowIdAe    BIGINT = ISNULL((SELECT MAX(row_id) FROM erp.ADVERSE_EVENTS), 0);
DECLARE @RowIdCust  BIGINT = ISNULL((SELECT MAX(row_id) FROM erp.CUSTOMERS), 0);
DECLARE @RowIdDoc   BIGINT = ISNULL((SELECT MAX(row_id) FROM erp.DOCTORS), 0);
DECLARE @RowIdProd  BIGINT = ISNULL((SELECT MAX(row_id) FROM erp.PRODUCTS), 0);


-- =====================================================================
-- НОВІ КЛІЄНТИ (атрибути тягнемо з наявних, щоб не дублювати довідники назв)
-- =====================================================================
IF @N_NewCustomers > 0
BEGIN
    IF OBJECT_ID('tempdb..#SrcCust') IS NOT NULL DROP TABLE #SrcCust;
    SELECT TOP (@N_NewCustomers)
           customer_type, chain_name, region, city, address,
           ROW_NUMBER() OVER (ORDER BY NEWID()) AS rn
    INTO #SrcCust
    FROM erp.CUSTOMERS
    WHERE region IS NOT NULL;

    INSERT INTO erp.CUSTOMERS
        (customer_id, edrpou, tax_id, name, customer_type, chain_name, region, city, address,
         is_active, created_at, updated_at)
    SELECT
        CONCAT('CST-', FORMAT(@OffCust + s.rn, '00000')),
        CAST(20000000 + ABS(CHECKSUM(NEWID())) % 9999999 AS NVARCHAR(10)),
        CAST(300000000 + ABS(CHECKSUM(NEWID())) % 99999999 AS NVARCHAR(12)),
        CONCAT(N'Аптека №', 900 + s.rn, N' ', s.city),
        s.customer_type, s.chain_name, s.region, s.city, s.address,
        1,
        DATEADD(DAY, -1 * (ABS(CHECKSUM(NEWID())) % 200), CAST(@DateStart AS DATETIME2(0))),
        DATEADD(DAY, -1 * (ABS(CHECKSUM(NEWID())) % 200), CAST(@DateStart AS DATETIME2(0)))
    FROM #SrcCust s;

    PRINT CONCAT('Додано клієнтів: ', @@ROWCOUNT);
END


-- =====================================================================
-- НОВІ ЛІКАРІ
-- =====================================================================
IF @N_NewDoctors > 0
BEGIN
    -- Golden record лікаря в silver визначається як ПІБ + ЛПУ, тому нові особи
    -- збираємо з РІЗНИХ джерельних рядків: прізвище з одного, ім'я+по батькові з
    -- другого (щоб зберегти узгодженість за статтю), спеціальність/ЛПУ/місто з третього.
    IF OBJECT_ID('tempdb..#DocSrcPool') IS NOT NULL DROP TABLE #DocSrcPool;
    SELECT last_name, first_name, middle_name, specialty, lpu_name, region, city,
           ROW_NUMBER() OVER (ORDER BY doctor_id) AS rn
    INTO #DocSrcPool
    FROM erp.DOCTORS
    WHERE specialty IS NOT NULL AND lpu_name IS NOT NULL;

    DECLARE @DocSrcCount INT = (SELECT COUNT(*) FROM #DocSrcPool);

    IF OBJECT_ID('tempdb..#GenDoc') IS NOT NULL DROP TABLE #GenDoc;
    SELECT
        n.n,
        ABS(CHECKSUM(NEWID())) % @DocSrcCount + 1 AS ln_rn,
        ABS(CHECKSUM(NEWID())) % @DocSrcCount + 1 AS name_rn,
        ABS(CHECKSUM(NEWID())) % @DocSrcCount + 1 AS lpu_rn,
        ABS(CHECKSUM(NEWID())) % 4                AS seg_kind,
        ABS(CHECKSUM(NEWID())) % 100              AS target_kind,
        ABS(CHECKSUM(NEWID())) % 200              AS created_offset
    INTO #GenDoc
    FROM #Nums n
    WHERE n.n <= @N_NewDoctors;

    INSERT INTO erp.DOCTORS
        (doctor_id, last_name, first_name, middle_name, specialty, lpu_name, region, city,
         segment, target_flag, created_at, updated_at)
    SELECT
        CONCAT('DOC-', FORMAT(@OffDoc + g.n, '00000')),
        ln.last_name,
        nm.first_name,
        nm.middle_name,
        lp.specialty, lp.lpu_name, lp.region, lp.city,
        CASE g.seg_kind WHEN 0 THEN N'A' WHEN 1 THEN N'B' WHEN 2 THEN N'C' ELSE N'N' END,
        CASE WHEN g.target_kind < 60 THEN 1 ELSE 0 END,
        DATEADD(DAY, -1 * g.created_offset, CAST(@DateStart AS DATETIME2(0))),
        DATEADD(DAY, -1 * g.created_offset, CAST(@DateStart AS DATETIME2(0)))
    FROM #GenDoc g
    JOIN #DocSrcPool ln ON ln.rn = g.ln_rn
    JOIN #DocSrcPool nm ON nm.rn = g.name_rn
    JOIN #DocSrcPool lp ON lp.rn = g.lpu_rn;

    PRINT CONCAT('Додано лікарів: ', @@ROWCOUNT);
END


-- =====================================================================
-- НОВІ SCD2-ВЕРСІЇ ПРОДУКТІВ (зміна ціни) — щоб silver показав версіонування
-- =====================================================================
IF @N_PriceChanges > 0
BEGIN
    ;WITH latest AS (
        SELECT product_id, sku_code, barcode, registration_number, inn, brand_name, atc_code,
               form, dosage, manufacturer, rx_otc, base_price_uah, is_active, created_at,
               ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY updated_at DESC, row_id DESC) AS rn
        FROM erp.PRODUCTS
    ), target AS (
        SELECT TOP (@N_PriceChanges) * FROM latest WHERE rn = 1 ORDER BY NEWID()
    )
    INSERT INTO erp.PRODUCTS
        (product_id, sku_code, barcode, registration_number, inn, brand_name, atc_code, form, dosage,
         manufacturer, rx_otc, base_price_uah, is_active, created_at, updated_at)
    SELECT
        product_id, sku_code, barcode, registration_number, inn, brand_name, atc_code, form, dosage,
        manufacturer, rx_otc,
        ROUND(base_price_uah * (1.05 + (ABS(CHECKSUM(NEWID())) % 120) / 1000.0), 2),
        is_active,
        created_at,
        DATEADD(DAY, ABS(CHECKSUM(NEWID())) % @DateRangeDays, CAST(@DateStart AS DATETIME2(0)))
    FROM target;

    PRINT CONCAT('Додано версій продуктів: ', @@ROWCOUNT);
END


-- =====================================================================
-- POOL TABLES (уже з урахуванням новододаних клієнтів/лікарів)
-- =====================================================================
IF OBJECT_ID('tempdb..#ProdPool') IS NOT NULL DROP TABLE #ProdPool;
;WITH last_ver AS (
    SELECT product_id, base_price_uah,
           ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY updated_at DESC, row_id DESC) AS ver
    FROM erp.PRODUCTS
)
SELECT product_id, base_price_uah,
       ROW_NUMBER() OVER (ORDER BY product_id) AS rn
INTO #ProdPool
FROM last_ver WHERE ver = 1;
CREATE UNIQUE CLUSTERED INDEX IX_ProdPool ON #ProdPool (rn);
DECLARE @ProdCount INT = (SELECT COUNT(*) FROM #ProdPool);

IF OBJECT_ID('tempdb..#CustPool') IS NOT NULL DROP TABLE #CustPool;
SELECT customer_id, ROW_NUMBER() OVER (ORDER BY customer_id) AS rn
INTO #CustPool FROM erp.CUSTOMERS;
CREATE UNIQUE CLUSTERED INDEX IX_CustPool ON #CustPool (rn);
DECLARE @CustCount INT = (SELECT COUNT(*) FROM #CustPool);

IF OBJECT_ID('tempdb..#WhPool') IS NOT NULL DROP TABLE #WhPool;
SELECT warehouse_id, ROW_NUMBER() OVER (ORDER BY warehouse_id) AS rn
INTO #WhPool FROM erp.WAREHOUSES;
CREATE UNIQUE CLUSTERED INDEX IX_WhPool ON #WhPool (rn);
DECLARE @WhCount INT = (SELECT COUNT(*) FROM #WhPool);

IF OBJECT_ID('tempdb..#RepPool') IS NOT NULL DROP TABLE #RepPool;
SELECT employee_id, ROW_NUMBER() OVER (ORDER BY employee_id) AS rn
INTO #RepPool FROM erp.EMPLOYEES WHERE role = N'Медичний представник' AND is_active = 1;
CREATE UNIQUE CLUSTERED INDEX IX_RepPool ON #RepPool (rn);
DECLARE @RepCount INT = (SELECT COUNT(*) FROM #RepPool);

IF OBJECT_ID('tempdb..#EmpPool') IS NOT NULL DROP TABLE #EmpPool;
SELECT employee_id, ROW_NUMBER() OVER (ORDER BY employee_id) AS rn
INTO #EmpPool FROM erp.EMPLOYEES;
CREATE UNIQUE CLUSTERED INDEX IX_EmpPool ON #EmpPool (rn);
DECLARE @EmpCount INT = (SELECT COUNT(*) FROM #EmpPool);

IF OBJECT_ID('tempdb..#DocPool') IS NOT NULL DROP TABLE #DocPool;
SELECT doctor_id, MIN(region) AS region, ROW_NUMBER() OVER (ORDER BY doctor_id) AS rn
INTO #DocPool FROM erp.DOCTORS GROUP BY doctor_id;
CREATE UNIQUE CLUSTERED INDEX IX_DocPool ON #DocPool (rn);
DECLARE @DocCount INT = (SELECT COUNT(*) FROM #DocPool);


-- =====================================================================
-- SALES_ORDERS
-- =====================================================================
IF OBJECT_ID('tempdb..#GenSales') IS NOT NULL DROP TABLE #GenSales;
SELECT
    n.n,
    ABS(CHECKSUM(NEWID())) % @CustCount + 1                           AS cust_rn,
    ABS(CHECKSUM(NEWID())) % @WhCount   + 1                           AS wh_rn,
    ABS(CHECKSUM(NEWID())) % @ProdCount + 1                           AS prod_rn,
    ABS(CHECKSUM(NEWID())) % @RepCount  + 1                           AS rep_rn,
    DATEADD(DAY, ABS(CHECKSUM(NEWID())) % @DateRangeDays, @DateStart) AS order_date,
    1 + ABS(CHECKSUM(NEWID())) % 7                                    AS deliv_days,
    1 + ABS(CHECKSUM(NEWID())) % 20                                   AS quantity,
    CAST(CASE ABS(CHECKSUM(NEWID())) % 10
             WHEN 0 THEN 5.0 WHEN 1 THEN 10.0 WHEN 2 THEN 15.0
             ELSE 0.0 END AS DECIMAL(5,2))                            AS discount_pct,
    ABS(CHECKSUM(NEWID())) % 100                                      AS status_kind,
    8 + ABS(CHECKSUM(NEWID())) % 10                                   AS ord_hour
INTO #GenSales
FROM #Nums n
WHERE n.n <= @N_Sales;

INSERT INTO erp.SALES_ORDERS
    (order_line_id, order_number, order_date, delivery_date, customer_id, warehouse_id,
     product_id, employee_id, quantity, unit_price, discount_pct, line_amount,
     currency, status, created_at, updated_at)
SELECT
    CONCAT('ORD-', FORMAT(@OffSales + g.n, '0000000'), '-L1'),
    CONCAT('ORD-', FORMAT(((@OffSales + g.n) / 3) + 1, '000000')),
    g.order_date,
    DATEADD(DAY, g.deliv_days, g.order_date),
    cu.customer_id,
    wh.warehouse_id,
    pp.product_id,
    rp.employee_id,
    g.quantity,
    pp.base_price_uah,
    g.discount_pct,
    ROUND(g.quantity * pp.base_price_uah * (1 - g.discount_pct / 100.0), 2),
    N'UAH',
    CASE
        WHEN g.status_kind < 60 THEN N'DELIVERED'
        WHEN g.status_kind < 75 THEN N'SHIPPED'
        WHEN g.status_kind < 85 THEN N'CONFIRMED'
        WHEN g.status_kind < 90 THEN N'NEW'
        WHEN g.status_kind < 95 THEN N'CANCELLED'
        ELSE N'RETURN'
    END,
    DATEADD(HOUR, g.ord_hour, CAST(g.order_date AS DATETIME2(0))),
    DATEADD(HOUR, g.ord_hour, CAST(g.order_date AS DATETIME2(0)))
FROM #GenSales g
JOIN #CustPool cu ON cu.rn = g.cust_rn
JOIN #WhPool   wh ON wh.rn = g.wh_rn
JOIN #ProdPool pp ON pp.rn = g.prod_rn
JOIN #RepPool  rp ON rp.rn = g.rep_rn;

PRINT CONCAT('Додано SALES_ORDERS: ', @@ROWCOUNT);

-- Дублікати (тільки серед нових рядків)
INSERT INTO erp.SALES_ORDERS
    (order_line_id, order_number, order_date, delivery_date, customer_id, warehouse_id,
     product_id, employee_id, quantity, unit_price, discount_pct, line_amount,
     currency, status, created_at, updated_at)
SELECT order_line_id, order_number, order_date, delivery_date, customer_id, warehouse_id,
       product_id, employee_id, quantity, unit_price, discount_pct, line_amount,
       currency, status, created_at, updated_at
FROM (SELECT TOP (@N_SalesDups) * FROM erp.SALES_ORDERS WHERE row_id > @RowIdSales ORDER BY NEWID()) src;

-- Дефекти (тільки серед нових рядків)
UPDATE s SET currency = CASE ABS(CHECKSUM(NEWID())) % 2 WHEN 0 THEN N'USD' ELSE N'EUR' END
FROM erp.SALES_ORDERS s
WHERE s.row_id IN (SELECT TOP (@N_Sales / 200) row_id FROM erp.SALES_ORDERS WHERE row_id > @RowIdSales ORDER BY NEWID());

UPDATE s SET quantity = -quantity
FROM erp.SALES_ORDERS s
WHERE s.row_id IN (SELECT TOP (@N_Sales / 200) row_id FROM erp.SALES_ORDERS WHERE row_id > @RowIdSales ORDER BY NEWID());

UPDATE s SET line_amount = ROUND(line_amount * (1.1 + ABS(CHECKSUM(NEWID())) % 40 / 100.0), 2)
FROM erp.SALES_ORDERS s
WHERE s.row_id IN (SELECT TOP (@N_Sales / 200) row_id FROM erp.SALES_ORDERS WHERE row_id > @RowIdSales ORDER BY NEWID());

UPDATE s SET employee_id = NULL
FROM erp.SALES_ORDERS s
WHERE s.row_id IN (SELECT TOP (@N_Sales / 100) row_id FROM erp.SALES_ORDERS WHERE row_id > @RowIdSales ORDER BY NEWID());

UPDATE s SET customer_id = CONCAT('CST-', FORMAT(700000 + ABS(CHECKSUM(NEWID())) % 99999, '00000'))
FROM erp.SALES_ORDERS s
WHERE s.row_id IN (SELECT TOP (@N_Sales / 100) row_id FROM erp.SALES_ORDERS WHERE row_id > @RowIdSales ORDER BY NEWID());


-- =====================================================================
-- INVENTORY_MOVEMENTS
-- =====================================================================
IF OBJECT_ID('tempdb..#GenInv') IS NOT NULL DROP TABLE #GenInv;
SELECT
    n.n,
    ABS(CHECKSUM(NEWID())) % @WhCount   + 1                            AS wh_rn,
    ABS(CHECKSUM(NEWID())) % @ProdCount + 1                            AS prod_rn,
    ABS(CHECKSUM(NEWID())) % @EmpCount  + 1                            AS emp_rn,
    DATEADD(HOUR, 8 + ABS(CHECKSUM(NEWID())) % 10,
        CAST(DATEADD(DAY, ABS(CHECKSUM(NEWID())) % @DateRangeDays, @DateStart) AS DATETIME2(0))) AS movement_dt,
    1 + ABS(CHECKSUM(NEWID())) % 500                                   AS quantity,
    ABS(CHECKSUM(NEWID())) % 100                                       AS type_kind,
    ABS(CHECKSUM(NEWID())) % 100                                       AS lang_kind,
    ABS(CHECKSUM(NEWID())) % 4                                         AS ukr_kind,
    ABS(CHECKSUM(NEWID())) % 4                                         AS ref_kind,
    100000 + ABS(CHECKSUM(NEWID())) % 899999                           AS ref_num
INTO #GenInv
FROM #Nums n
WHERE n.n <= @N_Inventory;

INSERT INTO erp.INVENTORY_MOVEMENTS
    (movement_id, movement_date, warehouse_id, product_id, movement_type, quantity,
     reference_document, employee_id, created_at, updated_at)
SELECT
    CONCAT('MOV-', FORMAT(@OffMov + g.n, '00000000')),
    g.movement_dt,
    wh.warehouse_id,
    pp.product_id,
    CASE
        WHEN g.lang_kind < 10 THEN
            CASE g.ukr_kind
                WHEN 0 THEN N'Прихід' WHEN 1 THEN N'Видача'
                WHEN 2 THEN N'Переміщення' ELSE N'Списання' END
        ELSE
            CASE
                WHEN g.type_kind < 35 THEN N'IN'
                WHEN g.type_kind < 80 THEN N'OUT'
                WHEN g.type_kind < 90 THEN N'TRANSFER'
                ELSE N'WRITEOFF'
            END
    END,
    g.quantity,
    CONCAT(
        CASE g.ref_kind
            WHEN 0 THEN N'INV' WHEN 1 THEN N'PO' WHEN 2 THEN N'TR' ELSE N'WO' END,
        N'-', g.ref_num
    ),
    em.employee_id,
    g.movement_dt,
    g.movement_dt
FROM #GenInv g
JOIN #WhPool   wh ON wh.rn = g.wh_rn
JOIN #ProdPool pp ON pp.rn = g.prod_rn
JOIN #EmpPool  em ON em.rn = g.emp_rn;

PRINT CONCAT('Додано INVENTORY_MOVEMENTS: ', @@ROWCOUNT);

INSERT INTO erp.INVENTORY_MOVEMENTS
    (movement_id, movement_date, warehouse_id, product_id, movement_type, quantity,
     reference_document, employee_id, created_at, updated_at)
SELECT movement_id, movement_date, warehouse_id, product_id, movement_type, quantity,
       reference_document, employee_id, created_at, updated_at
FROM (SELECT TOP (@N_InventoryDups) * FROM erp.INVENTORY_MOVEMENTS WHERE row_id > @RowIdMov ORDER BY NEWID()) src;

UPDATE m SET warehouse_id = CONCAT('WH-', FORMAT(900 + ABS(CHECKSUM(NEWID())) % 99, '000'))
FROM erp.INVENTORY_MOVEMENTS m
WHERE m.row_id IN (SELECT TOP (@N_Inventory / 100) row_id FROM erp.INVENTORY_MOVEMENTS WHERE row_id > @RowIdMov ORDER BY NEWID());

UPDATE m SET quantity = 500000 + ABS(CHECKSUM(NEWID())) % 9499999
FROM erp.INVENTORY_MOVEMENTS m
WHERE m.row_id IN (SELECT TOP (@N_Inventory / 300) row_id FROM erp.INVENTORY_MOVEMENTS WHERE row_id > @RowIdMov ORDER BY NEWID());

UPDATE m SET quantity = -quantity
FROM erp.INVENTORY_MOVEMENTS m
WHERE m.row_id IN (SELECT TOP (@N_Inventory / 200) row_id FROM erp.INVENTORY_MOVEMENTS WHERE row_id > @RowIdMov ORDER BY NEWID());


-- =====================================================================
-- DOCTOR_VISITS
-- =====================================================================
IF OBJECT_ID('tempdb..#GenVis') IS NOT NULL DROP TABLE #GenVis;
SELECT
    n.n,
    ABS(CHECKSUM(NEWID())) % @DocCount  + 1                            AS doc_rn,
    ABS(CHECKSUM(NEWID())) % @RepCount  + 1                            AS rep_rn,
    ABS(CHECKSUM(NEWID())) % @ProdCount + 1                            AS prod_rn,
    DATEADD(HOUR, 9 + ABS(CHECKSUM(NEWID())) % 9,
        CAST(DATEADD(DAY, ABS(CHECKSUM(NEWID())) % @DateRangeDays, @DateStart) AS DATETIME2(0))) AS visit_dt,
    ABS(CHECKSUM(NEWID())) % 100                                       AS act_kind,
    ABS(CHECKSUM(NEWID())) % 400                                       AS dur_raw,
    ABS(CHECKSUM(NEWID())) % 7                                         AS samples_kind,
    ABS(CHECKSUM(NEWID())) % 7                                         AS notes_kind
INTO #GenVis
FROM #Nums n
WHERE n.n <= @N_Visits;

INSERT INTO erp.DOCTOR_VISITS
    (visit_id, visit_date, doctor_id, employee_id, product_id, activity_type,
     duration_min, samples_qty, notes, created_at, updated_at)
SELECT
    CONCAT('VIS-', FORMAT(@OffVis + g.n, '0000000')),
    g.visit_dt,
    dc.doctor_id,
    rp.employee_id,
    pp.product_id,
    act.activity_type,
    CASE act.activity_type
        WHEN N'Visit'      THEN 10  + g.dur_raw % 36
        WHEN N'RoundTable' THEN 60  + g.dur_raw % 61
        WHEN N'Symposium'  THEN 120 + g.dur_raw % 361
        ELSE 15 + g.dur_raw % 46
    END,
    CASE g.samples_kind
        WHEN 0 THEN 10 WHEN 1 THEN 5 WHEN 2 THEN 3 WHEN 3 THEN 3
        WHEN 4 THEN 5 WHEN 5 THEN 3 ELSE 0 END,
    CASE g.notes_kind
        WHEN 0 THEN N'Обговорено нову лінійку'
        WHEN 1 THEN N'Передано зразки'
        WHEN 2 THEN N'Візит з тренером'
        WHEN 3 THEN N'Домовились про круглий стіл'
        WHEN 4 THEN N'Обговорено клінічні дані'
        WHEN 5 THEN N'Лікар не прийняв, перенесено'
        ELSE NULL END,
    g.visit_dt, g.visit_dt
FROM #GenVis g
JOIN #DocPool  dc ON dc.rn = g.doc_rn
JOIN #RepPool  rp ON rp.rn = g.rep_rn
JOIN #ProdPool pp ON pp.rn = g.prod_rn
CROSS APPLY (SELECT CASE
                        WHEN g.act_kind < 75 THEN N'Visit'
                        WHEN g.act_kind < 85 THEN N'RoundTable'
                        WHEN g.act_kind < 95 THEN N'EDetailing'
                        ELSE N'Symposium' END AS activity_type) act;

PRINT CONCAT('Додано DOCTOR_VISITS: ', @@ROWCOUNT);

INSERT INTO erp.DOCTOR_VISITS
    (visit_id, visit_date, doctor_id, employee_id, product_id, activity_type,
     duration_min, samples_qty, notes, created_at, updated_at)
SELECT visit_id, visit_date, doctor_id, employee_id, product_id, activity_type,
       duration_min, samples_qty, notes, created_at, updated_at
FROM (SELECT TOP (@N_VisitDups) * FROM erp.DOCTOR_VISITS WHERE row_id > @RowIdVis ORDER BY NEWID()) src;

UPDATE v SET doctor_id = CONCAT('DOC-', FORMAT(700000 + ABS(CHECKSUM(NEWID())) % 99999, '00000'))
FROM erp.DOCTOR_VISITS v
WHERE v.row_id IN (SELECT TOP (@N_Visits / 100) row_id FROM erp.DOCTOR_VISITS WHERE row_id > @RowIdVis ORDER BY NEWID());


-- =====================================================================
-- PRESCRIPTIONS
-- =====================================================================
IF OBJECT_ID('tempdb..#GenRx') IS NOT NULL DROP TABLE #GenRx;
SELECT
    n.n,
    ABS(CHECKSUM(NEWID())) % @DocCount  + 1                            AS doc_rn,
    ABS(CHECKSUM(NEWID())) % @ProdCount + 1                            AS prod_rn,
    ABS(CHECKSUM(NEWID())) % @RepCount  + 1                            AS rep_rn,
    DATEADD(DAY, ABS(CHECKSUM(NEWID())) % @DateRangeDays, @DateStart)  AS rx_date,
    1 + ABS(CHECKSUM(NEWID())) % 8                                     AS pat_count,
    ABS(CHECKSUM(NEWID())) % 3                                         AS rx_extra,
    9 + ABS(CHECKSUM(NEWID())) % 10                                    AS rx_hour
INTO #GenRx
FROM #Nums n
WHERE n.n <= @N_Rx;

INSERT INTO erp.PRESCRIPTIONS
    (prescription_id, prescription_date, doctor_id, product_id, patients_count,
     prescriptions_count, entered_by_employee_id, created_at, updated_at)
SELECT
    CONCAT('RX-', FORMAT(@OffRx + g.n, '0000000')),
    g.rx_date,
    dc.doctor_id,
    pp.product_id,
    g.pat_count,
    g.pat_count + g.rx_extra,
    rp.employee_id,
    DATEADD(HOUR, g.rx_hour, CAST(g.rx_date AS DATETIME2(0))),
    DATEADD(HOUR, g.rx_hour, CAST(g.rx_date AS DATETIME2(0)))
FROM #GenRx g
JOIN #DocPool  dc ON dc.rn = g.doc_rn
JOIN #ProdPool pp ON pp.rn = g.prod_rn
JOIN #RepPool  rp ON rp.rn = g.rep_rn;

PRINT CONCAT('Додано PRESCRIPTIONS: ', @@ROWCOUNT);

INSERT INTO erp.PRESCRIPTIONS
    (prescription_id, prescription_date, doctor_id, product_id, patients_count,
     prescriptions_count, entered_by_employee_id, created_at, updated_at)
SELECT prescription_id, prescription_date, doctor_id, product_id, patients_count,
       prescriptions_count, entered_by_employee_id, created_at, updated_at
FROM (SELECT TOP (@N_RxDups) * FROM erp.PRESCRIPTIONS WHERE row_id > @RowIdRx ORDER BY NEWID()) src;

UPDATE r SET prescriptions_count = NULL
FROM erp.PRESCRIPTIONS r
WHERE r.row_id IN (SELECT TOP (@N_Rx / 100) row_id FROM erp.PRESCRIPTIONS WHERE row_id > @RowIdRx ORDER BY NEWID());

UPDATE r SET doctor_id = CONCAT('DOC-', FORMAT(800000 + ABS(CHECKSUM(NEWID())) % 99999, '00000'))
FROM erp.PRESCRIPTIONS r
WHERE r.row_id IN (SELECT TOP (@N_Rx / 100) row_id FROM erp.PRESCRIPTIONS WHERE row_id > @RowIdRx ORDER BY NEWID());


-- =====================================================================
-- ADVERSE_EVENTS (+ follow-up версії кейсів)
-- =====================================================================
IF OBJECT_ID('tempdb..#GenAe') IS NOT NULL DROP TABLE #GenAe;
SELECT
    n.n,
    ABS(CHECKSUM(NEWID())) % @ProdCount + 1                            AS prod_rn,
    ABS(CHECKSUM(NEWID())) % @DocCount  + 1                            AS doc_rn,
    DATEADD(DAY, ABS(CHECKSUM(NEWID())) % @DateRangeDays, @DateStart)  AS report_date,
    ABS(CHECKSUM(NEWID())) % 100                                       AS ser_kind,
    ABS(CHECKSUM(NEWID())) % 10                                        AS outcome_kind,
    ABS(CHECKSUM(NEWID())) % 100                                       AS source_kind
INTO #GenAe
FROM #Nums n
WHERE n.n <= @N_AE;

INSERT INTO erp.ADVERSE_EVENTS
    (ae_id, report_date, product_id, reporter_doctor_id, seriousness, outcome,
     region, report_source, case_version, created_at, updated_at)
SELECT
    CONCAT('AE-', FORMAT(@OffAe + g.n, '000000')),
    g.report_date,
    pp.product_id,
    dc.doctor_id,
    CASE
        WHEN g.ser_kind < 70 THEN N'Non-serious'
        WHEN g.ser_kind < 95 THEN N'Serious'
        ELSE N'Critical'
    END,
    CASE g.outcome_kind
        WHEN 0 THEN N'Recovered with sequelae'
        WHEN 1 THEN N'Recovering'
        WHEN 2 THEN N'Not recovered'
        WHEN 3 THEN N'Unknown'
        ELSE N'Recovered' END,
    dc.region,
    CASE
        WHEN g.source_kind < 50 THEN N'HCP'
        WHEN g.source_kind < 75 THEN N'Patient'
        WHEN g.source_kind < 90 THEN N'Pharmacy'
        WHEN g.source_kind < 95 THEN N'Literature'
        ELSE N'Study' END,
    1,
    CAST(g.report_date AS DATETIME2(0)), CAST(g.report_date AS DATETIME2(0))
FROM #GenAe g
JOIN #ProdPool pp ON pp.rn = g.prod_rn
JOIN #DocPool  dc ON dc.rn = g.doc_rn;

PRINT CONCAT('Додано ADVERSE_EVENTS: ', @@ROWCOUNT);

-- ~12% кейсів отримують version 2
INSERT INTO erp.ADVERSE_EVENTS
    (ae_id, report_date, product_id, reporter_doctor_id, seriousness, outcome,
     region, report_source, case_version, created_at, updated_at)
SELECT TOP (@N_AE * 12 / 100)
    ae_id, DATEADD(DAY, 15 + ABS(CHECKSUM(NEWID())) % 60, report_date),
    product_id, reporter_doctor_id, seriousness,
    CASE ABS(CHECKSUM(NEWID())) % 3 WHEN 0 THEN N'Recovered' WHEN 1 THEN N'Fatal' ELSE N'Unknown' END,
    region, report_source, 2,
    DATEADD(DAY, 15 + ABS(CHECKSUM(NEWID())) % 60, created_at),
    DATEADD(DAY, 15 + ABS(CHECKSUM(NEWID())) % 60, created_at)
FROM erp.ADVERSE_EVENTS
WHERE row_id > @RowIdAe AND case_version = 1
ORDER BY NEWID();

UPDATE a SET seriousness = N'Critical', outcome = N'Recovered'
FROM erp.ADVERSE_EVENTS a
WHERE a.row_id IN (SELECT TOP (@N_AE / 300) row_id FROM erp.ADVERSE_EVENTS WHERE row_id > @RowIdAe ORDER BY NEWID());

UPDATE a SET outcome = NULL
FROM erp.ADVERSE_EVENTS a
WHERE a.row_id IN (SELECT TOP (@N_AE / 100) row_id FROM erp.ADVERSE_EVENTS WHERE row_id > @RowIdAe ORDER BY NEWID());


-- =====================================================================
-- ПІДСУМОК
-- =====================================================================
SELECT 'PRODUCTS'            AS tbl, COUNT(*) AS total_rows, SUM(CASE WHEN row_id > @RowIdProd  THEN 1 ELSE 0 END) AS new_rows FROM erp.PRODUCTS
UNION ALL SELECT 'CUSTOMERS',           COUNT(*), SUM(CASE WHEN row_id > @RowIdCust  THEN 1 ELSE 0 END) FROM erp.CUSTOMERS
UNION ALL SELECT 'DOCTORS',             COUNT(*), SUM(CASE WHEN row_id > @RowIdDoc   THEN 1 ELSE 0 END) FROM erp.DOCTORS
UNION ALL SELECT 'SALES_ORDERS',        COUNT(*), SUM(CASE WHEN row_id > @RowIdSales THEN 1 ELSE 0 END) FROM erp.SALES_ORDERS
UNION ALL SELECT 'INVENTORY_MOVEMENTS', COUNT(*), SUM(CASE WHEN row_id > @RowIdMov   THEN 1 ELSE 0 END) FROM erp.INVENTORY_MOVEMENTS
UNION ALL SELECT 'DOCTOR_VISITS',       COUNT(*), SUM(CASE WHEN row_id > @RowIdVis   THEN 1 ELSE 0 END) FROM erp.DOCTOR_VISITS
UNION ALL SELECT 'PRESCRIPTIONS',       COUNT(*), SUM(CASE WHEN row_id > @RowIdRx    THEN 1 ELSE 0 END) FROM erp.PRESCRIPTIONS
UNION ALL SELECT 'ADVERSE_EVENTS',      COUNT(*), SUM(CASE WHEN row_id > @RowIdAe    THEN 1 ELSE 0 END) FROM erp.ADVERSE_EVENTS;


-- =====================================================================
-- CLEANUP
-- =====================================================================
DROP TABLE IF EXISTS #Nums;
DROP TABLE IF EXISTS #SrcCust;
DROP TABLE IF EXISTS #DocSrcPool;
DROP TABLE IF EXISTS #GenDoc;
DROP TABLE IF EXISTS #ProdPool;
DROP TABLE IF EXISTS #CustPool;
DROP TABLE IF EXISTS #WhPool;
DROP TABLE IF EXISTS #RepPool;
DROP TABLE IF EXISTS #EmpPool;
DROP TABLE IF EXISTS #DocPool;
DROP TABLE IF EXISTS #GenSales;
DROP TABLE IF EXISTS #GenInv;
DROP TABLE IF EXISTS #GenVis;
DROP TABLE IF EXISTS #GenRx;
DROP TABLE IF EXISTS #GenAe;
