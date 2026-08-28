-- Знімок DDL шару gold. Джерело істини — fabric-migrations/flyway/migrations.
-- SQLCMD mode: :r виконує файли в порядку залежностей.

-- ---------- dimensions ----------
:r ./dimensions/DimClientAccount.sql
:r ./dimensions/DimDate.sql
:r ./dimensions/DimDoctor.sql
:r ./dimensions/DimEmployee.sql
:r ./dimensions/DimProduct.sql
:r ./dimensions/DimWarehouse.sql

-- ---------- aggregates ----------
:r ./aggregates/AggAdverseEventMonthly.sql
:r ./aggregates/AggInventoryMonthly.sql
:r ./aggregates/AggPrescriptionMonthly.sql
:r ./aggregates/AggPromoEffectMonthly.sql
:r ./aggregates/AggSalesDaily.sql
:r ./aggregates/AggSalesMonthly.sql
:r ./aggregates/AggVisitMonthly.sql

-- ---------- etl ----------
:r ./etl/EtlGoldLoadLog.sql
:r ./etl/EtlGoldObject.sql
