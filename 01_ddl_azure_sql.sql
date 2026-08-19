-- =====================================================================
-- Pharma ERP Source — Azure SQL Database DDL
-- Simulates a legacy Ukrainian pharmaceutical distributor's ERP schema.
--
-- Design decisions:
--   • Every table has row_id BIGINT IDENTITY PK (typical ERP surrogate).
--     Business keys are indexed but NOT unique-enforced. This allows:
--       - SCD2 versions in PRODUCTS (same product_id, multiple rows)
--       - Duplicate dim records (customer/doctor entered twice)
--       - Row-level duplicates in facts (bad ETL / user re-entry)
--       - Case versions in ADVERSE_EVENTS (same ae_id, different versions)
--   • FK constraints NOT declared — mirrors "loose" legacy ERPs where
--     orphaned FKs happen (soft-deletes, legacy migrations).
--     Relationships documented in comments.
--   • NVARCHAR everywhere for text (Cyrillic-safe).
--   • created_at / updated_at on every table (standard ERP audit fields).
-- =====================================================================

CREATE SCHEMA erp;
GO

-- =====================================================================
-- MASTER DATA
-- =====================================================================

-- ----- PRODUCTS -----
-- May contain multiple rows per product_id (SCD2-style history:
-- price changes, manufacturer changes, RX/OTC status changes).
CREATE TABLE erp.PRODUCTS (
    row_id                BIGINT IDENTITY(1,1) NOT NULL,
    product_id            NVARCHAR(20)   NOT NULL,
    sku_code              NVARCHAR(20)   NULL,
    barcode               NVARCHAR(20)   NULL,
    registration_number   NVARCHAR(50)   NULL,
    inn                   NVARCHAR(200)  NULL,
    brand_name            NVARCHAR(200)  NULL,
    atc_code              NVARCHAR(20)   NULL,
    form                  NVARCHAR(100)  NULL,
    dosage                NVARCHAR(50)   NULL,
    manufacturer          NVARCHAR(200)  NULL,
    rx_otc                NVARCHAR(10)   NULL,
    base_price_uah        DECIMAL(18,4)  NULL,
    is_active             BIT            NULL,
    created_at            DATETIME2(0)   NOT NULL,
    updated_at            DATETIME2(0)   NOT NULL,
    CONSTRAINT PK_erp_PRODUCTS PRIMARY KEY CLUSTERED (row_id)
);
CREATE INDEX IX_erp_PRODUCTS_product_id ON erp.PRODUCTS (product_id, updated_at DESC);
CREATE INDEX IX_erp_PRODUCTS_sku ON erp.PRODUCTS (sku_code);
GO

-- ----- CUSTOMERS -----
-- Pharmacies, hospital pharmacies, distributors.
-- Duplicates possible: same real pharmacy entered twice with different customer_id.
CREATE TABLE erp.CUSTOMERS (
    row_id                BIGINT IDENTITY(1,1) NOT NULL,
    customer_id           NVARCHAR(20)   NOT NULL,
    edrpou                NVARCHAR(10)   NULL,
    tax_id                NVARCHAR(12)   NULL,
    name                  NVARCHAR(500)  NULL,
    customer_type         NVARCHAR(50)   NULL,   -- Pharmacy / HospitalPharmacy / Distributor
    chain_name            NVARCHAR(200)  NULL,
    region                NVARCHAR(100)  NULL,
    city                  NVARCHAR(100)  NULL,
    address               NVARCHAR(500)  NULL,
    is_active             BIT            NULL,
    created_at            DATETIME2(0)   NOT NULL,
    updated_at            DATETIME2(0)   NOT NULL,
    CONSTRAINT PK_erp_CUSTOMERS PRIMARY KEY CLUSTERED (row_id)
);
CREATE INDEX IX_erp_CUSTOMERS_customer_id ON erp.CUSTOMERS (customer_id);
CREATE INDEX IX_erp_CUSTOMERS_edrpou ON erp.CUSTOMERS (edrpou);
GO

-- ----- DOCTORS -----
-- Physicians in HCP database. Duplicates: same doctor entered with different doctor_id
-- (different spelling of LPU name, different regional office).
CREATE TABLE erp.DOCTORS (
    row_id                BIGINT IDENTITY(1,1) NOT NULL,
    doctor_id             NVARCHAR(20)   NOT NULL,
    last_name             NVARCHAR(100)  NULL,
    first_name            NVARCHAR(100)  NULL,
    middle_name           NVARCHAR(100)  NULL,
    specialty             NVARCHAR(100)  NULL,
    lpu_name              NVARCHAR(300)  NULL,
    region                NVARCHAR(100)  NULL,
    city                  NVARCHAR(100)  NULL,
    segment               NVARCHAR(5)    NULL,   -- A / B / C / N (unknown)
    target_flag           BIT            NULL,
    created_at            DATETIME2(0)   NOT NULL,
    updated_at            DATETIME2(0)   NOT NULL,
    CONSTRAINT PK_erp_DOCTORS PRIMARY KEY CLUSTERED (row_id)
);
CREATE INDEX IX_erp_DOCTORS_doctor_id ON erp.DOCTORS (doctor_id);
GO

-- ----- EMPLOYEES -----
-- Sales representatives and their managers. manager_id references employee_id (self-ref).
CREATE TABLE erp.EMPLOYEES (
    row_id                BIGINT IDENTITY(1,1) NOT NULL,
    employee_id           NVARCHAR(20)   NOT NULL,
    full_name             NVARCHAR(200)  NULL,
    role                  NVARCHAR(100)  NULL,
    territory             NVARCHAR(100)  NULL,
    line                  NVARCHAR(20)   NULL,   -- RX / OTC / Both
    manager_id            NVARCHAR(20)   NULL,   -- FK -> EMPLOYEES.employee_id (not enforced)
    hire_date             DATE           NULL,
    is_active             BIT            NULL,
    created_at            DATETIME2(0)   NOT NULL,
    updated_at            DATETIME2(0)   NOT NULL,
    CONSTRAINT PK_erp_EMPLOYEES PRIMARY KEY CLUSTERED (row_id)
);
CREATE INDEX IX_erp_EMPLOYEES_employee_id ON erp.EMPLOYEES (employee_id);
GO

-- ----- WAREHOUSES -----
-- Own warehouses + consignment stocks at distributors.
-- owner_customer_id references CUSTOMERS.customer_id for consignment cases.
CREATE TABLE erp.WAREHOUSES (
    row_id                BIGINT IDENTITY(1,1) NOT NULL,
    warehouse_id          NVARCHAR(20)   NOT NULL,
    warehouse_code        NVARCHAR(20)   NULL,
    name                  NVARCHAR(300)  NULL,
    warehouse_type        NVARCHAR(50)   NULL,   -- Own / Consignment / Transit
    owner_customer_id     NVARCHAR(20)   NULL,   -- FK -> CUSTOMERS.customer_id (not enforced)
    region                NVARCHAR(100)  NULL,
    city                  NVARCHAR(100)  NULL,
    created_at            DATETIME2(0)   NOT NULL,
    updated_at            DATETIME2(0)   NOT NULL,
    CONSTRAINT PK_erp_WAREHOUSES PRIMARY KEY CLUSTERED (row_id)
);
CREATE INDEX IX_erp_WAREHOUSES_warehouse_id ON erp.WAREHOUSES (warehouse_id);
GO


-- =====================================================================
-- TRANSACTIONS
-- =====================================================================

-- ----- SALES_ORDERS -----
-- Sell-out to customers (pharmacies, hospitals, distributors).
-- Grain: one order line. order_number groups multiple lines of one order.
CREATE TABLE erp.SALES_ORDERS (
    row_id                BIGINT IDENTITY(1,1) NOT NULL,
    order_line_id         NVARCHAR(30)   NOT NULL,
    order_number          NVARCHAR(30)   NULL,
    order_date            DATE           NULL,
    delivery_date         DATE           NULL,
    customer_id           NVARCHAR(20)   NULL,   -- FK -> CUSTOMERS (not enforced)
    warehouse_id          NVARCHAR(20)   NULL,   -- FK -> WAREHOUSES (not enforced)
    product_id            NVARCHAR(20)   NULL,   -- FK -> PRODUCTS.product_id (not enforced)
    employee_id           NVARCHAR(20)   NULL,   -- FK -> EMPLOYEES (not enforced)
    quantity              INT            NULL,
    unit_price            DECIMAL(18,4)  NULL,
    discount_pct          DECIMAL(5,2)   NULL,
    line_amount           DECIMAL(18,4)  NULL,
    currency              NVARCHAR(5)    NULL,   -- UAH / USD / EUR
    status                NVARCHAR(20)   NULL,   -- NEW / CONFIRMED / SHIPPED / DELIVERED / CANCELLED / RETURN
    created_at            DATETIME2(0)   NOT NULL,
    updated_at            DATETIME2(0)   NOT NULL,
    CONSTRAINT PK_erp_SALES_ORDERS PRIMARY KEY CLUSTERED (row_id)
);
CREATE INDEX IX_erp_SALES_ORDERS_order_date ON erp.SALES_ORDERS (order_date);
CREATE INDEX IX_erp_SALES_ORDERS_customer ON erp.SALES_ORDERS (customer_id);
CREATE INDEX IX_erp_SALES_ORDERS_product ON erp.SALES_ORDERS (product_id);
GO

-- ----- INVENTORY_MOVEMENTS -----
-- Transactional stock movements (SAP MSEG-style).
-- movement_type: IN / OUT / TRANSFER / WRITEOFF (may include Ukrainian words too).
-- quantity always positive on source; sign is derived in Silver.
CREATE TABLE erp.INVENTORY_MOVEMENTS (
    row_id                BIGINT IDENTITY(1,1) NOT NULL,
    movement_id           NVARCHAR(30)   NOT NULL,
    movement_date         DATETIME2(0)   NULL,
    warehouse_id          NVARCHAR(20)   NULL,   -- FK -> WAREHOUSES (not enforced)
    product_id            NVARCHAR(20)   NULL,   -- FK -> PRODUCTS (not enforced)
    movement_type         NVARCHAR(50)   NULL,
    quantity              INT            NULL,
    reference_document    NVARCHAR(50)   NULL,   -- linked invoice / PO number
    employee_id           NVARCHAR(20)   NULL,   -- FK -> EMPLOYEES (not enforced)
    created_at            DATETIME2(0)   NOT NULL,
    updated_at            DATETIME2(0)   NOT NULL,
    CONSTRAINT PK_erp_INVENTORY_MOVEMENTS PRIMARY KEY CLUSTERED (row_id)
);
CREATE INDEX IX_erp_INVMOV_date ON erp.INVENTORY_MOVEMENTS (movement_date);
CREATE INDEX IX_erp_INVMOV_warehouse ON erp.INVENTORY_MOVEMENTS (warehouse_id);
CREATE INDEX IX_erp_INVMOV_product ON erp.INVENTORY_MOVEMENTS (product_id);
GO

-- ----- DOCTOR_VISITS -----
-- Medical rep visits and other promo activities.
CREATE TABLE erp.DOCTOR_VISITS (
    row_id                BIGINT IDENTITY(1,1) NOT NULL,
    visit_id              NVARCHAR(30)   NOT NULL,
    visit_date            DATETIME2(0)   NULL,
    doctor_id             NVARCHAR(20)   NULL,   -- FK -> DOCTORS (not enforced)
    employee_id           NVARCHAR(20)   NULL,   -- FK -> EMPLOYEES (not enforced)
    product_id            NVARCHAR(20)   NULL,   -- FK -> PRODUCTS (not enforced) — main promoted product
    activity_type         NVARCHAR(50)   NULL,   -- Visit / RoundTable / EDetailing / Symposium
    duration_min          INT            NULL,
    samples_qty           INT            NULL,
    notes                 NVARCHAR(500)  NULL,
    created_at            DATETIME2(0)   NOT NULL,
    updated_at            DATETIME2(0)   NOT NULL,
    CONSTRAINT PK_erp_DOCTOR_VISITS PRIMARY KEY CLUSTERED (row_id)
);
CREATE INDEX IX_erp_VISITS_date ON erp.DOCTOR_VISITS (visit_date);
CREATE INDEX IX_erp_VISITS_doctor ON erp.DOCTOR_VISITS (doctor_id);
GO

-- ----- PRESCRIPTIONS -----
-- Doctor prescriptions logged by field force in CRM.
CREATE TABLE erp.PRESCRIPTIONS (
    row_id                BIGINT IDENTITY(1,1) NOT NULL,
    prescription_id       NVARCHAR(30)   NOT NULL,
    prescription_date     DATE           NULL,
    doctor_id             NVARCHAR(20)   NULL,   -- FK -> DOCTORS (not enforced)
    product_id            NVARCHAR(20)   NULL,   -- FK -> PRODUCTS (not enforced)
    patients_count        INT            NULL,
    prescriptions_count   INT            NULL,
    entered_by_employee_id NVARCHAR(20)  NULL,   -- FK -> EMPLOYEES (not enforced)
    created_at            DATETIME2(0)   NOT NULL,
    updated_at            DATETIME2(0)   NOT NULL,
    CONSTRAINT PK_erp_PRESCRIPTIONS PRIMARY KEY CLUSTERED (row_id)
);
CREATE INDEX IX_erp_RX_date ON erp.PRESCRIPTIONS (prescription_date);
CREATE INDEX IX_erp_RX_doctor ON erp.PRESCRIPTIONS (doctor_id);
GO

-- ----- ADVERSE_EVENTS -----
-- Pharmacovigilance cases. Same ae_id can have multiple case_version rows
-- (initial report + follow-ups). No PK on business key by design.
CREATE TABLE erp.ADVERSE_EVENTS (
    row_id                BIGINT IDENTITY(1,1) NOT NULL,
    ae_id                 NVARCHAR(30)   NOT NULL,
    report_date           DATE           NULL,
    product_id            NVARCHAR(20)   NULL,   -- FK -> PRODUCTS (not enforced)
    reporter_doctor_id    NVARCHAR(20)   NULL,   -- FK -> DOCTORS (not enforced)
    seriousness           NVARCHAR(20)   NULL,   -- Non-serious / Serious / Critical
    outcome               NVARCHAR(100)  NULL,
    region                NVARCHAR(100)  NULL,
    report_source         NVARCHAR(20)   NULL,   -- HCP / Patient / Pharmacy / Literature / Study
    case_version          SMALLINT       NULL,
    created_at            DATETIME2(0)   NOT NULL,
    updated_at            DATETIME2(0)   NOT NULL,
    CONSTRAINT PK_erp_ADVERSE_EVENTS PRIMARY KEY CLUSTERED (row_id)
);
CREATE INDEX IX_erp_AE_report_date ON erp.ADVERSE_EVENTS (report_date);
CREATE INDEX IX_erp_AE_ae_id ON erp.ADVERSE_EVENTS (ae_id, case_version);
GO
