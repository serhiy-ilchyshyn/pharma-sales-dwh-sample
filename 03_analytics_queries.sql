-- =====================================================================
-- Pharma ERP — перевірочні та аналітичні запити
-- Показують, як таблиці зв'язуються між собою по бізнес-ключах
-- (FK у схемі не оголошені — усі зв'язки логічні).
--
-- Карта зв'язків:
--   SALES_ORDERS.customer_id        -> CUSTOMERS.customer_id
--   SALES_ORDERS.warehouse_id       -> WAREHOUSES.warehouse_id
--   SALES_ORDERS.product_id         -> PRODUCTS.product_id      (SCD2!)
--   SALES_ORDERS.employee_id        -> EMPLOYEES.employee_id
--   INVENTORY_MOVEMENTS.warehouse_id-> WAREHOUSES.warehouse_id
--   INVENTORY_MOVEMENTS.product_id  -> PRODUCTS.product_id
--   INVENTORY_MOVEMENTS.employee_id -> EMPLOYEES.employee_id
--   DOCTOR_VISITS.doctor_id         -> DOCTORS.doctor_id
--   DOCTOR_VISITS.employee_id       -> EMPLOYEES.employee_id
--   DOCTOR_VISITS.product_id        -> PRODUCTS.product_id
--   PRESCRIPTIONS.doctor_id         -> DOCTORS.doctor_id
--   PRESCRIPTIONS.product_id        -> PRODUCTS.product_id
--   PRESCRIPTIONS.entered_by_employee_id -> EMPLOYEES.employee_id
--   ADVERSE_EVENTS.product_id       -> PRODUCTS.product_id
--   ADVERSE_EVENTS.reporter_doctor_id    -> DOCTORS.doctor_id
--   WAREHOUSES.owner_customer_id    -> CUSTOMERS.customer_id
--   EMPLOYEES.manager_id            -> EMPLOYEES.employee_id    (self-ref)
--
-- Три пастки, які враховані нижче:
--   1) PRODUCTS має кілька версій на product_id (SCD2) -> дедуп по updated_at
--   2) У фактах є рядкові дублікати -> дедуп по бізнес-ключу
--   3) Є orphan-ключі (CST-7xxxxx, DOC-7/8xxxxx, WH-9xx) -> тільки LEFT JOIN
-- =====================================================================


-- =====================================================================
-- ЗАПИТ 1. Головний 360° зріз: продукт × регіон × місяць
-- Об'єднує 5 фактових таблиць у спільну зернистість і тягне атрибути
-- з 4 довідників. Це і є демонстрація повного зв'язування схеми.
-- =====================================================================
DECLARE @DateFrom DATE = '2024-01-01';
DECLARE @DateTo   DATE = '2026-08-14';

WITH
-- ---------- довідники (дедуп) ----------
prod AS (
    SELECT product_id, brand_name, inn, atc_code, rx_otc, manufacturer, base_price_uah
    FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY product_id
                                     ORDER BY updated_at DESC, row_id DESC) AS v
        FROM erp.PRODUCTS
    ) p
    WHERE v = 1                       -- SCD2: беремо актуальну версію
),
cust AS (
    SELECT customer_id, name, customer_type, region, city
    FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_id
                                     ORDER BY updated_at DESC, row_id DESC) AS v
        FROM erp.CUSTOMERS
    ) c
    WHERE v = 1
),
doc AS (
    SELECT doctor_id, last_name, first_name, specialty, segment, region, city
    FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY doctor_id
                                     ORDER BY updated_at DESC, row_id DESC) AS v
        FROM erp.DOCTORS
    ) d
    WHERE v = 1
),
-- ---------- факти (дедуп рядкових дублікатів) ----------
so AS (
    SELECT *
    FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY order_line_id ORDER BY row_id) AS dup
        FROM erp.SALES_ORDERS
    ) s
    WHERE dup = 1
),
im AS (
    SELECT *
    FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY movement_id ORDER BY row_id) AS dup
        FROM erp.INVENTORY_MOVEMENTS
    ) m
    WHERE dup = 1
),
dv AS (
    SELECT *
    FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY visit_id ORDER BY row_id) AS dup
        FROM erp.DOCTOR_VISITS
    ) v
    WHERE dup = 1
),
rx AS (
    SELECT *
    FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY prescription_id ORDER BY row_id) AS dup
        FROM erp.PRESCRIPTIONS
    ) r
    WHERE dup = 1
),
ae AS (   -- pharmacovigilance: беремо останню версію кейса
    SELECT *
    FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY ae_id
                                     ORDER BY case_version DESC, row_id DESC) AS v
        FROM erp.ADVERSE_EVENTS
    ) a
    WHERE v = 1
),
-- ---------- агрегати на спільній зернистості ----------
sales_agg AS (
    SELECT
        DATEFROMPARTS(YEAR(so.order_date), MONTH(so.order_date), 1) AS mth,
        so.product_id,
        c.region,
        COUNT(*)                                        AS order_lines,
        COUNT(DISTINCT so.order_number)                 AS orders_cnt,
        COUNT(DISTINCT so.customer_id)                  AS customers_cnt,
        SUM(so.quantity)                                AS units_sold,
        SUM(so.line_amount)                             AS revenue_uah
    FROM so
    LEFT JOIN cust c ON c.customer_id = so.customer_id      -- LEFT: є orphan-клієнти
    WHERE so.order_date BETWEEN @DateFrom AND @DateTo       -- відсікає дати 2019/2028
      AND so.currency = N'UAH'                              -- відсікає підкинуті USD/EUR
      AND so.quantity > 0                                   -- відсікає від'ємні кількості
      AND so.status NOT IN (N'CANCELLED', N'RETURN')
    GROUP BY DATEFROMPARTS(YEAR(so.order_date), MONTH(so.order_date), 1),
             so.product_id, c.region
),
inv_agg AS (
    SELECT
        DATEFROMPARTS(YEAR(im.movement_date), MONTH(im.movement_date), 1) AS mth,
        im.product_id,
        w.region,
        SUM(CASE WHEN im.movement_type IN (N'IN', N'Прихід')                THEN  im.quantity
                 WHEN im.movement_type IN (N'OUT', N'Видача',
                                           N'WRITEOFF', N'Списання')        THEN -im.quantity
                 ELSE 0 END)                            AS net_qty_moved,
        SUM(CASE WHEN im.movement_type IN (N'WRITEOFF', N'Списання')
                 THEN im.quantity ELSE 0 END)           AS writeoff_qty
    FROM im
    LEFT JOIN erp.WAREHOUSES w ON w.warehouse_id = im.warehouse_id   -- LEFT: є WH-9xx
    WHERE im.movement_date >= @DateFrom
      AND im.movement_date <  DATEADD(DAY, 1, @DateTo)
      AND ABS(im.quantity) < 100000                     -- відсікає викиди
    GROUP BY DATEFROMPARTS(YEAR(im.movement_date), MONTH(im.movement_date), 1),
             im.product_id, w.region
),
promo_agg AS (
    SELECT
        DATEFROMPARTS(YEAR(dv.visit_date), MONTH(dv.visit_date), 1) AS mth,
        dv.product_id,
        d.region,
        COUNT(*)                                        AS activities,
        COUNT(DISTINCT dv.doctor_id)                    AS doctors_covered,
        COUNT(DISTINCT dv.employee_id)                  AS reps_active,
        SUM(dv.samples_qty)                             AS samples_given
    FROM dv
    LEFT JOIN doc d ON d.doctor_id = dv.doctor_id       -- LEFT: є DOC-7xxxxx
    WHERE dv.visit_date >= @DateFrom
      AND dv.visit_date <  DATEADD(DAY, 1, @DateTo)
    GROUP BY DATEFROMPARTS(YEAR(dv.visit_date), MONTH(dv.visit_date), 1),
             dv.product_id, d.region
),
rx_agg AS (
    SELECT
        DATEFROMPARTS(YEAR(rx.prescription_date), MONTH(rx.prescription_date), 1) AS mth,
        rx.product_id,
        d.region,
        SUM(rx.prescriptions_count)                     AS rx_count,
        SUM(rx.patients_count)                          AS patients
    FROM rx
    LEFT JOIN doc d ON d.doctor_id = rx.doctor_id
    WHERE rx.prescription_date BETWEEN @DateFrom AND @DateTo
    GROUP BY DATEFROMPARTS(YEAR(rx.prescription_date), MONTH(rx.prescription_date), 1),
             rx.product_id, d.region
),
ae_agg AS (
    SELECT
        DATEFROMPARTS(YEAR(ae.report_date), MONTH(ae.report_date), 1) AS mth,
        ae.product_id,
        ae.region,
        COUNT(*)                                        AS ae_cases,
        SUM(CASE WHEN ae.seriousness IN (N'Serious', N'Critical') THEN 1 ELSE 0 END) AS ae_serious
    FROM ae
    WHERE ae.report_date BETWEEN @DateFrom AND @DateTo
    GROUP BY DATEFROMPARTS(YEAR(ae.report_date), MONTH(ae.report_date), 1),
             ae.product_id, ae.region
),
-- ---------- спільний "хребет" ключів ----------
spine AS (
    SELECT mth, product_id, region FROM sales_agg
    UNION SELECT mth, product_id, region FROM inv_agg
    UNION SELECT mth, product_id, region FROM promo_agg
    UNION SELECT mth, product_id, region FROM rx_agg
    UNION SELECT mth, product_id, region FROM ae_agg
)
SELECT
    s.mth,
    s.region,
    s.product_id,
    p.brand_name,
    p.inn,
    p.atc_code,
    p.rx_otc,
    p.manufacturer,
    -- sell-out
    ISNULL(sa.order_lines, 0)                           AS order_lines,
    ISNULL(sa.customers_cnt, 0)                         AS customers,
    ISNULL(sa.units_sold, 0)                            AS units_sold,
    CAST(ISNULL(sa.revenue_uah, 0) AS DECIMAL(18,2))    AS revenue_uah,
    -- склад
    ISNULL(ia.net_qty_moved, 0)                         AS net_qty_moved,
    ISNULL(ia.writeoff_qty, 0)                          AS writeoff_qty,
    -- промо
    ISNULL(pa.activities, 0)                            AS activities,
    ISNULL(pa.doctors_covered, 0)                       AS doctors_covered,
    ISNULL(pa.samples_given, 0)                         AS samples_given,
    -- призначення
    ISNULL(ra.rx_count, 0)                              AS rx_count,
    ISNULL(ra.patients, 0)                              AS patients,
    -- PV
    ISNULL(aa.ae_cases, 0)                              AS ae_cases,
    ISNULL(aa.ae_serious, 0)                            AS ae_serious,
    -- похідні метрики
    CAST(ISNULL(sa.revenue_uah, 0) / NULLIF(pa.activities, 0) AS DECIMAL(18,2))
                                                        AS revenue_per_activity,
    CAST(1.0 * ISNULL(ra.rx_count, 0) / NULLIF(pa.doctors_covered, 0) AS DECIMAL(18,2))
                                                        AS rx_per_covered_doctor
FROM spine s
LEFT JOIN prod      p  ON p.product_id = s.product_id
LEFT JOIN sales_agg sa ON sa.mth = s.mth AND sa.product_id = s.product_id
                      AND ISNULL(sa.region, N'#NA') = ISNULL(s.region, N'#NA')
LEFT JOIN inv_agg   ia ON ia.mth = s.mth AND ia.product_id = s.product_id
                      AND ISNULL(ia.region, N'#NA') = ISNULL(s.region, N'#NA')
LEFT JOIN promo_agg pa ON pa.mth = s.mth AND pa.product_id = s.product_id
                      AND ISNULL(pa.region, N'#NA') = ISNULL(s.region, N'#NA')
LEFT JOIN rx_agg    ra ON ra.mth = s.mth AND ra.product_id = s.product_id
                      AND ISNULL(ra.region, N'#NA') = ISNULL(s.region, N'#NA')
LEFT JOIN ae_agg    aa ON aa.mth = s.mth AND aa.product_id = s.product_id
                      AND ISNULL(aa.region, N'#NA') = ISNULL(s.region, N'#NA')
ORDER BY s.mth DESC, revenue_uah DESC;
GO


-- =====================================================================
-- ЗАПИТ 2. Звіт цілісності ключів (скільки записів "не б'ється")
-- Саме тут видно навмисно закладені orphan-и.
-- =====================================================================
;WITH prod_k AS (SELECT DISTINCT product_id  FROM erp.PRODUCTS),
      cust_k AS (SELECT DISTINCT customer_id FROM erp.CUSTOMERS),
      doc_k  AS (SELECT DISTINCT doctor_id   FROM erp.DOCTORS),
      emp_k  AS (SELECT DISTINCT employee_id FROM erp.EMPLOYEES),
      wh_k   AS (SELECT DISTINCT warehouse_id FROM erp.WAREHOUSES)
SELECT relationship, total_rows, null_keys, orphan_rows,
       CAST(100.0 * orphan_rows / NULLIF(total_rows, 0) AS DECIMAL(5,2)) AS orphan_pct
FROM (
    SELECT 'SALES_ORDERS.customer_id -> CUSTOMERS' AS relationship,
           COUNT(*) AS total_rows,
           SUM(CASE WHEN s.customer_id IS NULL THEN 1 ELSE 0 END) AS null_keys,
           SUM(CASE WHEN s.customer_id IS NOT NULL AND c.customer_id IS NULL THEN 1 ELSE 0 END) AS orphan_rows
    FROM erp.SALES_ORDERS s LEFT JOIN cust_k c ON c.customer_id = s.customer_id
    UNION ALL
    SELECT 'SALES_ORDERS.product_id -> PRODUCTS',
           COUNT(*), SUM(CASE WHEN s.product_id IS NULL THEN 1 ELSE 0 END),
           SUM(CASE WHEN s.product_id IS NOT NULL AND p.product_id IS NULL THEN 1 ELSE 0 END)
    FROM erp.SALES_ORDERS s LEFT JOIN prod_k p ON p.product_id = s.product_id
    UNION ALL
    SELECT 'SALES_ORDERS.warehouse_id -> WAREHOUSES',
           COUNT(*), SUM(CASE WHEN s.warehouse_id IS NULL THEN 1 ELSE 0 END),
           SUM(CASE WHEN s.warehouse_id IS NOT NULL AND w.warehouse_id IS NULL THEN 1 ELSE 0 END)
    FROM erp.SALES_ORDERS s LEFT JOIN wh_k w ON w.warehouse_id = s.warehouse_id
    UNION ALL
    SELECT 'SALES_ORDERS.employee_id -> EMPLOYEES',
           COUNT(*), SUM(CASE WHEN s.employee_id IS NULL THEN 1 ELSE 0 END),
           SUM(CASE WHEN s.employee_id IS NOT NULL AND e.employee_id IS NULL THEN 1 ELSE 0 END)
    FROM erp.SALES_ORDERS s LEFT JOIN emp_k e ON e.employee_id = s.employee_id
    UNION ALL
    SELECT 'INVENTORY_MOVEMENTS.warehouse_id -> WAREHOUSES',
           COUNT(*), SUM(CASE WHEN m.warehouse_id IS NULL THEN 1 ELSE 0 END),
           SUM(CASE WHEN m.warehouse_id IS NOT NULL AND w.warehouse_id IS NULL THEN 1 ELSE 0 END)
    FROM erp.INVENTORY_MOVEMENTS m LEFT JOIN wh_k w ON w.warehouse_id = m.warehouse_id
    UNION ALL
    SELECT 'INVENTORY_MOVEMENTS.product_id -> PRODUCTS',
           COUNT(*), SUM(CASE WHEN m.product_id IS NULL THEN 1 ELSE 0 END),
           SUM(CASE WHEN m.product_id IS NOT NULL AND p.product_id IS NULL THEN 1 ELSE 0 END)
    FROM erp.INVENTORY_MOVEMENTS m LEFT JOIN prod_k p ON p.product_id = m.product_id
    UNION ALL
    SELECT 'DOCTOR_VISITS.doctor_id -> DOCTORS',
           COUNT(*), SUM(CASE WHEN v.doctor_id IS NULL THEN 1 ELSE 0 END),
           SUM(CASE WHEN v.doctor_id IS NOT NULL AND d.doctor_id IS NULL THEN 1 ELSE 0 END)
    FROM erp.DOCTOR_VISITS v LEFT JOIN doc_k d ON d.doctor_id = v.doctor_id
    UNION ALL
    SELECT 'DOCTOR_VISITS.employee_id -> EMPLOYEES',
           COUNT(*), SUM(CASE WHEN v.employee_id IS NULL THEN 1 ELSE 0 END),
           SUM(CASE WHEN v.employee_id IS NOT NULL AND e.employee_id IS NULL THEN 1 ELSE 0 END)
    FROM erp.DOCTOR_VISITS v LEFT JOIN emp_k e ON e.employee_id = v.employee_id
    UNION ALL
    SELECT 'PRESCRIPTIONS.doctor_id -> DOCTORS',
           COUNT(*), SUM(CASE WHEN r.doctor_id IS NULL THEN 1 ELSE 0 END),
           SUM(CASE WHEN r.doctor_id IS NOT NULL AND d.doctor_id IS NULL THEN 1 ELSE 0 END)
    FROM erp.PRESCRIPTIONS r LEFT JOIN doc_k d ON d.doctor_id = r.doctor_id
    UNION ALL
    SELECT 'ADVERSE_EVENTS.product_id -> PRODUCTS',
           COUNT(*), SUM(CASE WHEN a.product_id IS NULL THEN 1 ELSE 0 END),
           SUM(CASE WHEN a.product_id IS NOT NULL AND p.product_id IS NULL THEN 1 ELSE 0 END)
    FROM erp.ADVERSE_EVENTS a LEFT JOIN prod_k p ON p.product_id = a.product_id
    UNION ALL
    SELECT 'ADVERSE_EVENTS.reporter_doctor_id -> DOCTORS',
           COUNT(*), SUM(CASE WHEN a.reporter_doctor_id IS NULL THEN 1 ELSE 0 END),
           SUM(CASE WHEN a.reporter_doctor_id IS NOT NULL AND d.doctor_id IS NULL THEN 1 ELSE 0 END)
    FROM erp.ADVERSE_EVENTS a LEFT JOIN doc_k d ON d.doctor_id = a.reporter_doctor_id
    UNION ALL
    SELECT 'WAREHOUSES.owner_customer_id -> CUSTOMERS',
           COUNT(*), SUM(CASE WHEN w.owner_customer_id IS NULL THEN 1 ELSE 0 END),
           SUM(CASE WHEN w.owner_customer_id IS NOT NULL AND c.customer_id IS NULL THEN 1 ELSE 0 END)
    FROM erp.WAREHOUSES w LEFT JOIN cust_k c ON c.customer_id = w.owner_customer_id
    UNION ALL
    SELECT 'EMPLOYEES.manager_id -> EMPLOYEES (self)',
           COUNT(*), SUM(CASE WHEN e.manager_id IS NULL THEN 1 ELSE 0 END),
           SUM(CASE WHEN e.manager_id IS NOT NULL AND m.employee_id IS NULL THEN 1 ELSE 0 END)
    FROM erp.EMPLOYEES e LEFT JOIN emp_k m ON m.employee_id = e.manager_id
) x
ORDER BY orphan_pct DESC;
GO


-- =====================================================================
-- ЗАПИТ 3. 360° по лікарю: візити -> призначення -> AE -> продажі регіону
-- Демонструє ланцюжок DOCTORS -> DOCTOR_VISITS -> EMPLOYEES -> (self) manager
-- =====================================================================
;WITH doc AS (
    SELECT doctor_id, last_name, first_name, specialty, segment, target_flag, region, city
    FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY doctor_id
                                       ORDER BY updated_at DESC, row_id DESC) AS v
          FROM erp.DOCTORS) d
    WHERE v = 1
),
v AS (
    SELECT doctor_id, employee_id,
           COUNT(*) AS visits,
           SUM(duration_min) AS minutes_spent,
           SUM(samples_qty)  AS samples,
           MAX(visit_date)   AS last_visit
    FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY visit_id ORDER BY row_id) AS dup
          FROM erp.DOCTOR_VISITS) t
    WHERE dup = 1 AND duration_min BETWEEN 1 AND 600
    GROUP BY doctor_id, employee_id
),
r AS (
    SELECT doctor_id,
           SUM(prescriptions_count) AS rx_total,
           COUNT(DISTINCT product_id) AS products_prescribed
    FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY prescription_id ORDER BY row_id) AS dup
          FROM erp.PRESCRIPTIONS) t
    WHERE dup = 1
    GROUP BY doctor_id
),
a AS (
    SELECT reporter_doctor_id AS doctor_id,
           COUNT(*) AS ae_reported,
           SUM(CASE WHEN seriousness IN (N'Serious', N'Critical') THEN 1 ELSE 0 END) AS ae_serious
    FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY ae_id
                                       ORDER BY case_version DESC, row_id DESC) AS ver
          FROM erp.ADVERSE_EVENTS) t
    WHERE ver = 1
    GROUP BY reporter_doctor_id
)
SELECT TOP (50)
    d.doctor_id,
    d.last_name + N' ' + d.first_name       AS doctor_name,
    d.specialty, d.segment, d.region, d.city,
    e.employee_id                            AS rep_id,
    e.full_name                              AS rep_name,
    mgr.full_name                            AS manager_name,      -- self-join EMPLOYEES
    e.territory,
    v.visits, v.minutes_spent, v.samples, v.last_visit,
    ISNULL(r.rx_total, 0)                    AS rx_total,
    ISNULL(r.products_prescribed, 0)         AS products_prescribed,
    ISNULL(a.ae_reported, 0)                 AS ae_reported,
    ISNULL(a.ae_serious, 0)                  AS ae_serious,
    CAST(1.0 * ISNULL(r.rx_total, 0) / NULLIF(v.visits, 0) AS DECIMAL(10,2)) AS rx_per_visit
FROM doc d
JOIN      v        ON v.doctor_id  = d.doctor_id
LEFT JOIN erp.EMPLOYEES e   ON e.employee_id = v.employee_id
LEFT JOIN erp.EMPLOYEES mgr ON mgr.employee_id = e.manager_id
LEFT JOIN r        ON r.doctor_id  = d.doctor_id
LEFT JOIN a        ON a.doctor_id  = d.doctor_id
WHERE d.target_flag = 1
ORDER BY rx_per_visit DESC, v.visits DESC;
GO


-- =====================================================================
-- ЗАПИТ 4. Якість даних: дублікати та SCD2-версії
-- =====================================================================
SELECT 'PRODUCTS (SCD2 versions)' AS check_name,
       COUNT(*) AS keys_affected, SUM(cnt) AS rows_affected
FROM (SELECT product_id, COUNT(*) AS cnt FROM erp.PRODUCTS
      GROUP BY product_id HAVING COUNT(*) > 1) x
UNION ALL
SELECT 'CUSTOMERS (same EDRPOU, different id)',
       COUNT(*), SUM(cnt)
FROM (SELECT edrpou, COUNT(DISTINCT customer_id) AS cnt FROM erp.CUSTOMERS
      WHERE edrpou IS NOT NULL GROUP BY edrpou HAVING COUNT(DISTINCT customer_id) > 1) x
UNION ALL
SELECT 'DOCTORS (same person, different id)',
       COUNT(*), SUM(cnt)
FROM (SELECT last_name, first_name, middle_name, city, COUNT(DISTINCT doctor_id) AS cnt
      FROM erp.DOCTORS
      GROUP BY last_name, first_name, middle_name, city
      HAVING COUNT(DISTINCT doctor_id) > 1) x
UNION ALL
SELECT 'SALES_ORDERS (duplicate order_line_id)',
       COUNT(*), SUM(cnt)
FROM (SELECT order_line_id, COUNT(*) AS cnt FROM erp.SALES_ORDERS
      GROUP BY order_line_id HAVING COUNT(*) > 1) x
UNION ALL
SELECT 'INVENTORY_MOVEMENTS (duplicate movement_id)',
       COUNT(*), SUM(cnt)
FROM (SELECT movement_id, COUNT(*) AS cnt FROM erp.INVENTORY_MOVEMENTS
      GROUP BY movement_id HAVING COUNT(*) > 1) x
UNION ALL
SELECT 'DOCTOR_VISITS (duplicate visit_id)',
       COUNT(*), SUM(cnt)
FROM (SELECT visit_id, COUNT(*) AS cnt FROM erp.DOCTOR_VISITS
      GROUP BY visit_id HAVING COUNT(*) > 1) x
UNION ALL
SELECT 'PRESCRIPTIONS (duplicate prescription_id)',
       COUNT(*), SUM(cnt)
FROM (SELECT prescription_id, COUNT(*) AS cnt FROM erp.PRESCRIPTIONS
      GROUP BY prescription_id HAVING COUNT(*) > 1) x
UNION ALL
SELECT 'ADVERSE_EVENTS (case versions)',
       COUNT(*), SUM(cnt)
FROM (SELECT ae_id, COUNT(*) AS cnt FROM erp.ADVERSE_EVENTS
      GROUP BY ae_id HAVING COUNT(*) > 1) x;
GO
