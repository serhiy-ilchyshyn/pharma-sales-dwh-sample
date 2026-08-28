-- Знімок DDL шару silver. Джерело істини — fabric-migrations/flyway/migrations.
-- SQLCMD mode: :r виконує файли в порядку залежностей.

-- ---------- dimensions ----------
:r ./dimensions/DimActivityType.sql
:r ./dimensions/DimAeOutcome.sql
:r ./dimensions/DimAeSeriousness.sql
:r ./dimensions/DimAtcClass.sql
:r ./dimensions/DimChain.sql
:r ./dimensions/DimCity.sql
:r ./dimensions/DimClientAccount.sql
:r ./dimensions/DimCurrency.sql
:r ./dimensions/DimDate.sql
:r ./dimensions/DimDoctor.sql
:r ./dimensions/DimEmployee.sql
:r ./dimensions/DimLegalEntity.sql
:r ./dimensions/DimLpu.sql
:r ./dimensions/DimManufacturer.sql
:r ./dimensions/DimMovementType.sql
:r ./dimensions/DimOrderStatus.sql
:r ./dimensions/DimProduct.sql
:r ./dimensions/DimRegion.sql
:r ./dimensions/DimReportSource.sql
:r ./dimensions/DimSpecialty.sql
:r ./dimensions/DimSrcSystem.sql
:r ./dimensions/DimTerritory.sql
:r ./dimensions/DimWarehouse.sql

-- ---------- reference ----------
:r ./reference/RefClientAccount.sql
:r ./reference/RefDoctor.sql
:r ./reference/RefEmployee.sql
:r ./reference/RefMovementType.sql
:r ./reference/RefProduct.sql
:r ./reference/RefWarehouse.sql

-- ---------- facts ----------
:r ./facts/FctAdverseEvent.sql
:r ./facts/FctInventoryMovement.sql
:r ./facts/FctPrescription.sql
:r ./facts/FctSales.sql
:r ./facts/FctVisit.sql

-- ---------- etl ----------
:r ./etl/EtlBronzeObject.sql
:r ./etl/EtlObjectDependency.sql
:r ./etl/EtlObjectDownstream.sql
:r ./etl/EtlSilverLoadLog.sql
:r ./etl/EtlSilverObject.sql
:r ./etl/EtlSilverWatermark.sql
