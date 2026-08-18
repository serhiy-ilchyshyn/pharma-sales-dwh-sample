/* =====================================================================================
   Master build script for the Pharma Sales sample star schema.
   Run order: schema -> dimensions -> facts.
   Platform:  Microsoft Fabric Warehouse / Azure SQL. Use with SQLCMD mode (:r) in SSMS
              or Azure Data Studio, or execute each referenced file individually.
   ===================================================================================== */

:r ./00_schema.sql

-- Dimensions
:r ./dimensions/DimDate.sql
:r ./dimensions/DimEmployee.sql
:r ./dimensions/DimClientAccount.sql
:r ./dimensions/DimProduct.sql
:r ./dimensions/DimActivityType.sql

-- Facts
:r ./facts/FctSales.sql
:r ./facts/FctSalesPlan.sql
:r ./facts/FctVisit.sql
:r ./facts/FctTargetFrequency.sql
:r ./facts/FctInventorySnapshot.sql
