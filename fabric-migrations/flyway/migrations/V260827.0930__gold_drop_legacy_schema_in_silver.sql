-- ClickUp: PHARMA-GOLD-003
-- Прибирання залишків попередньої версії gold, яка створювалась у схемі [gold]
-- всередині [whsilver]. Тепер gold живе в окремому warehouse [whgold], схема [dwh].
--
-- Міграція ідемпотентна: якщо схему [gold] у [whsilver] ніколи не створювали,
-- нічого не станеться.
GO
--IMPORTANT
USE [whsilver];
--IMPORTANT
GO

DROP VIEW IF EXISTS [gold].[vAggPromoEffectMonthly]
GO
DROP VIEW IF EXISTS [gold].[vAggAdverseEventMonthly]
GO
DROP VIEW IF EXISTS [gold].[vAggInventoryMonthly]
GO
DROP VIEW IF EXISTS [gold].[vAggPrescriptionMonthly]
GO
DROP VIEW IF EXISTS [gold].[vAggVisitMonthly]
GO
DROP VIEW IF EXISTS [gold].[vAggSalesMonthly]
GO
DROP VIEW IF EXISTS [gold].[vAggSalesDaily]
GO
DROP VIEW IF EXISTS [gold].[vDimWarehouse]
GO
DROP VIEW IF EXISTS [gold].[vDimEmployee]
GO
DROP VIEW IF EXISTS [gold].[vDimDoctor]
GO
DROP VIEW IF EXISTS [gold].[vDimClientAccount]
GO
DROP VIEW IF EXISTS [gold].[vDimProduct]
GO
DROP VIEW IF EXISTS [gold].[vDimDate]
GO

DROP PROCEDURE IF EXISTS [gold].[spGoldFullLoad]
GO
DROP PROCEDURE IF EXISTS [gold].[spGoldLoadLevel]
GO
DROP PROCEDURE IF EXISTS [gold].[spFullGoldObject]
GO

DROP TABLE IF EXISTS [gold].[AggPromoEffectMonthly]
GO
DROP TABLE IF EXISTS [gold].[AggAdverseEventMonthly]
GO
DROP TABLE IF EXISTS [gold].[AggInventoryMonthly]
GO
DROP TABLE IF EXISTS [gold].[AggPrescriptionMonthly]
GO
DROP TABLE IF EXISTS [gold].[AggVisitMonthly]
GO
DROP TABLE IF EXISTS [gold].[AggSalesMonthly]
GO
DROP TABLE IF EXISTS [gold].[AggSalesDaily]
GO
DROP TABLE IF EXISTS [gold].[DimWarehouse]
GO
DROP TABLE IF EXISTS [gold].[DimEmployee]
GO
DROP TABLE IF EXISTS [gold].[DimDoctor]
GO
DROP TABLE IF EXISTS [gold].[DimClientAccount]
GO
DROP TABLE IF EXISTS [gold].[DimProduct]
GO
DROP TABLE IF EXISTS [gold].[DimDate]
GO
DROP TABLE IF EXISTS [gold].[EtlGoldLoadLog]
GO
DROP TABLE IF EXISTS [gold].[EtlGoldObject]
GO

IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
    EXEC('DROP SCHEMA gold');
GO
