-- ClickUp: PHARMA-BRONZE-001
-- Реєстр таблиць для завантаження Azure SQL [erp] -> bronze lakehouse [lhbronze].[erp_erp].
-- Читається Lookup-активністю pipeline PL_Bronze_Ingest; додавання таблиці = рядок тут,
-- pipeline змінювати не потрібно.
--
-- Метадані bronze-шару живуть у silver-warehouse свідомо: у цьому прикладі немає окремої
-- ETL-бази (у прод-репозиторії її роль виконує [sql-db-etl].[etl]).
GO
--IMPORTANT
USE [whsilverad];
--IMPORTANT
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[EtlBronzeObject]
GO
CREATE TABLE [whsilverad].[dwh].[EtlBronzeObject]
(
	[SourceSchema] [varchar](128) NOT NULL,
	[SourceTable] [varchar](128) NOT NULL,
	[TargetSchema] [varchar](128) NOT NULL,
	[TargetTable] [varchar](128) NOT NULL,
	[LoadMode] [varchar](20) NOT NULL,   -- Overwrite (повне перезавантаження таблиці bronze)
	[IsActive] [bit] NOT NULL
)
GO

INSERT INTO [whsilverad].[dwh].[EtlBronzeObject]
	([SourceSchema],[SourceTable],[TargetSchema],[TargetTable],[LoadMode],[IsActive])
VALUES
	('erp', 'PRODUCTS',            'erp_erp', 'PRODUCTS',            'Overwrite', 1),
	('erp', 'CUSTOMERS',           'erp_erp', 'CUSTOMERS',           'Overwrite', 1),
	('erp', 'DOCTORS',             'erp_erp', 'DOCTORS',             'Overwrite', 1),
	('erp', 'EMPLOYEES',           'erp_erp', 'EMPLOYEES',           'Overwrite', 1),
	('erp', 'WAREHOUSES',          'erp_erp', 'WAREHOUSES',          'Overwrite', 1),
	('erp', 'SALES_ORDERS',        'erp_erp', 'SALES_ORDERS',        'Overwrite', 1),
	('erp', 'INVENTORY_MOVEMENTS', 'erp_erp', 'INVENTORY_MOVEMENTS', 'Overwrite', 1),
	('erp', 'DOCTOR_VISITS',       'erp_erp', 'DOCTOR_VISITS',       'Overwrite', 1),
	('erp', 'PRESCRIPTIONS',       'erp_erp', 'PRESCRIPTIONS',       'Overwrite', 1),
	('erp', 'ADVERSE_EVENTS',      'erp_erp', 'ADVERSE_EVENTS',      'Overwrite', 1)
GO
