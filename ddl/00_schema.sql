/* =====================================================================================
   Object:   [dwh] schema
   Purpose:  Target schema for the Pharma Sales sample star schema (Silver / Gold layer).
   Platform: Microsoft Fabric Warehouse (T-SQL). Also runs on Azure SQL / SQL Server 2019+.
   ===================================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dwh')
    EXEC('CREATE SCHEMA [dwh]');
GO
