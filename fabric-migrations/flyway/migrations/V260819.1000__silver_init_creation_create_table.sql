-- ClickUp: PHARMA-SILVER-001
-- Silver level (Microsoft Fabric Warehouse) для джерела Pharma ERP (Azure SQL, схема [erp]).
-- Джерела: 01_ddl_azure_sql.sql (DDL) + 02_generate_data_fixed.sql (наповнення).
--
-- Конвенції (аналогічні grp-ctl-azure-dwh/fabric-migrations/flyway/migrations):
--   Dim<Entity> : SK<Entity>ID (версія рядка) + SK<Entity>KeyID (durable key) + SCD2
--   Ref<Entity> : SKRef<Entity>ID + SKRef<Entity>KeyID + SKSrcSystemKeyID
--                 (маппінг "сирий ключ джерела -> durable key золотого запису")
--   Fct<Entity> : SKFct<Entity>ID + CreatedBy/CreatedAt, повне перезавантаження (spFullFct)
--   Технічні колонки вимірів: StartDate, EndDate, IsDeleted, CreatedBy, ModifiedBy,
--                             CreatedAt, ModifiedAt
--   Факти посилаються на durable keys (SK*KeyID), ніколи на SK*ID версії рядка.
--   Рядок -1 ("невідомо") є в кожному вимірі та довіднику -> inner join без втрат.
GO
--IMPORTANT
USE [whsilverad];
--IMPORTANT
GO

/* =========================================================
   СТАТИЧНІ / ТЕХНІЧНІ ВИМІРИ
   ========================================================= */

DROP TABLE IF EXISTS [whsilverad].[dwh].[DimDate]
GO
CREATE TABLE [whsilverad].[dwh].[DimDate]
(
	[SKDateID] [int] NOT NULL,
	[CalendarDate] [date] NOT NULL,
	[#DayOfYear] [int] NOT NULL,
	[#DayOfMonth] [int] NOT NULL,
	[#DayOfWeek] [int] NOT NULL,
	[WeekDayName] [varchar](30) NOT NULL,
	[WeekDayNameShort] [varchar](30) NOT NULL,
	[#WeekOfYear] [int] NOT NULL,
	[#WeekOfMonth] [int] NOT NULL,
	[#Month] [int] NOT NULL,
	[MonthName] [varchar](30) NOT NULL,
	[MonthNameShort] [varchar](30) NOT NULL,
	[#Quarter] [int] NOT NULL,
	[#Year] [int] NOT NULL,
	[MMYYYY] [varchar](30) NOT NULL,
	[MonthYear] [varchar](30) NULL,
	[#FiscalYear] [int] NOT NULL,
	[#FiscalQuarter] [int] NOT NULL,
	[#FiscalMonth] [int] NOT NULL
)
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[DimSrcSystem]
GO
CREATE TABLE [whsilverad].[dwh].[DimSrcSystem]
(
	[SKSrcSystemID] [bigint] NOT NULL,
	[SKSrcSystemKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NOT NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [int] NOT NULL,
	[Name] [varchar](50) NOT NULL
)
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[DimCurrency]
GO
CREATE TABLE [whsilverad].[dwh].[DimCurrency]
(
	[SKCurrencyID] [bigint] NOT NULL,
	[SKCurrencyKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NOT NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [char](3) NOT NULL,
	[Name] [varchar](20) NOT NULL,
	[FullName] [varchar](100) NULL
)
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[DimAtcClass]
GO
CREATE TABLE [whsilverad].[dwh].[DimAtcClass]
(
	[SKAtcClassID] [bigint] NOT NULL,
	[SKAtcClassKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NOT NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [char](1) NOT NULL,
	[Name] [varchar](128) NOT NULL,
	[Description] [varchar](256) NULL
)
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[DimMovementType]
GO
CREATE TABLE [whsilverad].[dwh].[DimMovementType]
(
	[SKMovementTypeID] [bigint] NOT NULL,
	[SKMovementTypeKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NOT NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](20) NOT NULL,
	[Name] [varchar](50) NOT NULL,
	[Direction] [varchar](10) NOT NULL,   -- IN / OUT / TRANSFER
	[QtySign] [smallint] NOT NULL         -- +1 / -1 / 0 : знак для FctInventoryMovement.QtySigned
)
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[DimOrderStatus]
GO
CREATE TABLE [whsilverad].[dwh].[DimOrderStatus]
(
	[SKOrderStatusID] [bigint] NOT NULL,
	[SKOrderStatusKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NOT NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](20) NOT NULL,
	[Name] [varchar](50) NOT NULL,
	[IsSale] [bit] NOT NULL,
	[IsReturn] [bit] NOT NULL,
	[IsCancelled] [bit] NOT NULL
)
GO

/* =========================================================
   ГЕОГРАФІЯ ТА ОРГАНІЗАЦІЙНІ ВИМІРИ
   ========================================================= */

DROP TABLE IF EXISTS [whsilverad].[dwh].[DimRegion]
GO
CREATE TABLE [whsilverad].[dwh].[DimRegion]
(
	[SKRegionID] [bigint] NOT NULL,
	[SKRegionKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](100) NOT NULL,
	[Name] [varchar](100) NOT NULL
)
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[DimCity]
GO
CREATE TABLE [whsilverad].[dwh].[DimCity]
(
	[SKCityID] [bigint] NOT NULL,
	[SKCityKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](210) NOT NULL,         -- <Region>|<City>
	[Name] [varchar](100) NOT NULL,
	[SKRegionKeyID] [bigint] NOT NULL
)
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[DimTerritory]
GO
CREATE TABLE [whsilverad].[dwh].[DimTerritory]
(
	[SKTerritoryID] [bigint] NOT NULL,
	[SKTerritoryKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](100) NOT NULL,
	[Name] [varchar](100) NOT NULL
)
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[DimChain]
GO
CREATE TABLE [whsilverad].[dwh].[DimChain]
(
	[SKChainID] [bigint] NOT NULL,
	[SKChainKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](200) NOT NULL,
	[Name] [varchar](200) NOT NULL
)
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[DimLegalEntity]
GO
CREATE TABLE [whsilverad].[dwh].[DimLegalEntity]
(
	[SKLegalEntityID] [bigint] NOT NULL,
	[SKLegalEntityKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](10) NOT NULL,          -- ЄДРПОУ
	[Name] [varchar](500) NULL,
	[EDRPOU] [varchar](10) NOT NULL,
	[TaxId] [varchar](12) NULL
)
GO

/* =========================================================
   ПРОДУКТОВІ ВИМІРИ
   ========================================================= */

DROP TABLE IF EXISTS [whsilverad].[dwh].[DimManufacturer]
GO
CREATE TABLE [whsilverad].[dwh].[DimManufacturer]
(
	[SKManufacturerID] [bigint] NOT NULL,
	[SKManufacturerKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](200) NOT NULL,
	[Name] [varchar](200) NOT NULL
)
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[DimProduct]
GO
CREATE TABLE [whsilverad].[dwh].[DimProduct]
(
	[SKProductID] [bigint] NOT NULL,
	[SKProductKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](20) NOT NULL,
	[Name] [varchar](200) NULL,
	[SkuCode] [varchar](20) NULL,
	[Barcode] [varchar](20) NULL,
	[RegistrationNumber] [varchar](50) NULL,
	[INN] [varchar](200) NULL,
	[AtcCode] [varchar](20) NULL,
	[SKAtcClassKeyID] [bigint] NOT NULL,
	[ReleaseForm] [varchar](100) NULL,
	[Dosage] [varchar](50) NULL,
	[SKManufacturerKeyID] [bigint] NOT NULL,
	[RxOtcType] [varchar](10) NULL,
	[BasePriceUAH] [decimal](18,4) NULL,
	[IsActive] [bit] NULL,
	[IsAtcCodeValid] [bit] NOT NULL,
	[SrcCreatedAt] [datetime2](3) NULL
)
GO

/* =========================================================
   КЛІЄНТИ, HCP ТА ПЕРСОНАЛ
   ========================================================= */

DROP TABLE IF EXISTS [whsilverad].[dwh].[DimClientAccount]
GO
CREATE TABLE [whsilverad].[dwh].[DimClientAccount]
(
	[SKClientAccountID] [bigint] NOT NULL,
	[SKClientAccountKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](20) NOT NULL,          -- golden customer_id (найстаріший з дублів)
	[Name] [varchar](500) NULL,
	[AccountType] [varchar](50) NULL,     -- Pharmacy / HospitalPharmacy / Distributor
	[SKChainKeyID] [bigint] NOT NULL,
	[SKLegalEntityKeyID] [bigint] NOT NULL,
	[SKRegionKeyID] [bigint] NOT NULL,
	[SKCityKeyID] [bigint] NOT NULL,
	[Address] [varchar](500) NULL,
	[IsActive] [bit] NULL,
	[SrcDuplicateCnt] [int] NOT NULL,     -- скільки customer_id джерела злиті в цей запис
	[SrcCreatedAt] [datetime2](3) NULL
)
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[DimSpecialty]
GO
CREATE TABLE [whsilverad].[dwh].[DimSpecialty]
(
	[SKSpecialtyID] [bigint] NOT NULL,
	[SKSpecialtyKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](100) NOT NULL,         -- нормалізована (UPPER) назва спеціальності
	[Name] [varchar](100) NOT NULL
)
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[DimLpu]
GO
CREATE TABLE [whsilverad].[dwh].[DimLpu]
(
	[SKLpuID] [bigint] NOT NULL,
	[SKLpuKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](300) NOT NULL,
	[Name] [varchar](300) NOT NULL,
	[SKRegionKeyID] [bigint] NOT NULL,
	[SKCityKeyID] [bigint] NOT NULL
)
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[DimDoctor]
GO
CREATE TABLE [whsilverad].[dwh].[DimDoctor]
(
	[SKDoctorID] [bigint] NOT NULL,
	[SKDoctorKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](20) NOT NULL,          -- golden doctor_id (найстаріший з дублів)
	[Name] [varchar](320) NULL,           -- ПІБ
	[LastName] [varchar](100) NULL,
	[FirstName] [varchar](100) NULL,
	[MiddleName] [varchar](100) NULL,
	[SKSpecialtyKeyID] [bigint] NOT NULL,
	[SKLpuKeyID] [bigint] NOT NULL,
	[SKRegionKeyID] [bigint] NOT NULL,
	[SKCityKeyID] [bigint] NOT NULL,
	[Segment] [varchar](5) NULL,          -- A / B / C / N
	[IsTarget] [bit] NULL,
	[SrcDuplicateCnt] [int] NOT NULL,
	[SrcCreatedAt] [datetime2](3) NULL
)
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[DimEmployee]
GO
CREATE TABLE [whsilverad].[dwh].[DimEmployee]
(
	[SKEmployeeID] [bigint] NOT NULL,
	[SKEmployeeKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](20) NOT NULL,
	[Name] [varchar](200) NULL,
	[EmployeeRole] [varchar](100) NULL,
	[SKTerritoryKeyID] [bigint] NOT NULL,
	[ProductLine] [varchar](20) NULL,     -- RX / OTC / Both
	[SKEmployeeManagerKeyID] [bigint] NOT NULL,
	[HireDate] [date] NULL,
	[IsActive] [bit] NULL,
	[SrcCreatedAt] [datetime2](3) NULL
)
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[DimWarehouse]
GO
CREATE TABLE [whsilverad].[dwh].[DimWarehouse]
(
	[SKWarehouseID] [bigint] NOT NULL,
	[SKWarehouseKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](20) NOT NULL,
	[Name] [varchar](300) NULL,
	[WarehouseCode] [varchar](20) NULL,
	[WarehouseType] [varchar](50) NULL,   -- Own / Consignment / Transit
	[SKClientAccountOwnerKeyID] [bigint] NOT NULL,
	[SKRegionKeyID] [bigint] NOT NULL,
	[SKCityKeyID] [bigint] NOT NULL,
	[SrcCreatedAt] [datetime2](3) NULL
)
GO

/* =========================================================
   ВИМІРИ АКТИВНОСТЕЙ ТА ФАРМАКОНАГЛЯДУ
   ========================================================= */

DROP TABLE IF EXISTS [whsilverad].[dwh].[DimActivityType]
GO
CREATE TABLE [whsilverad].[dwh].[DimActivityType]
(
	[SKActivityTypeID] [bigint] NOT NULL,
	[SKActivityTypeKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](50) NOT NULL,
	[Name] [varchar](50) NOT NULL,
	[IsRemote] [bit] NOT NULL,
	[IsGroupEvent] [bit] NOT NULL
)
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[DimAeSeriousness]
GO
CREATE TABLE [whsilverad].[dwh].[DimAeSeriousness]
(
	[SKAeSeriousnessID] [bigint] NOT NULL,
	[SKAeSeriousnessKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](20) NOT NULL,
	[Name] [varchar](50) NOT NULL,
	[SeverityRank] [smallint] NOT NULL
)
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[DimAeOutcome]
GO
CREATE TABLE [whsilverad].[dwh].[DimAeOutcome]
(
	[SKAeOutcomeID] [bigint] NOT NULL,
	[SKAeOutcomeKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](100) NOT NULL,
	[Name] [varchar](100) NOT NULL,
	[IsFatal] [bit] NOT NULL,
	[IsRecovered] [bit] NOT NULL
)
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[DimReportSource]
GO
CREATE TABLE [whsilverad].[dwh].[DimReportSource]
(
	[SKReportSourceID] [bigint] NOT NULL,
	[SKReportSourceKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](20) NOT NULL,
	[Name] [varchar](50) NOT NULL,
	[IsHcpReported] [bit] NOT NULL
)
GO

/* =========================================================
   REFERENCE TABLES (маппінг ключів джерела -> durable keys)
   ========================================================= */

DROP TABLE IF EXISTS [whsilverad].[dwh].[RefProduct]
GO
CREATE TABLE [whsilverad].[dwh].[RefProduct]
(
	[SKRefProductID] [bigint] NOT NULL,
	[SKRefProductKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](20) NOT NULL,          -- erp.PRODUCTS.product_id
	[SKSrcSystemKeyID] [bigint] NOT NULL,
	[RawSkuCode] [varchar](20) NULL,
	[RawBrandName] [varchar](200) NULL,
	[SKProductKeyID] [bigint] NOT NULL
)
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[RefClientAccount]
GO
CREATE TABLE [whsilverad].[dwh].[RefClientAccount]
(
	[SKRefClientAccountID] [bigint] NOT NULL,
	[SKRefClientAccountKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](20) NOT NULL,          -- erp.CUSTOMERS.customer_id (у т.ч. дублі CST-9xxxx)
	[SKSrcSystemKeyID] [bigint] NOT NULL,
	[RawName] [varchar](500) NULL,
	[RawEDRPOU] [varchar](10) NULL,
	[IsGoldenRecord] [bit] NOT NULL,
	[SKClientAccountKeyID] [bigint] NOT NULL
)
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[RefDoctor]
GO
CREATE TABLE [whsilverad].[dwh].[RefDoctor]
(
	[SKRefDoctorID] [bigint] NOT NULL,
	[SKRefDoctorKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](20) NOT NULL,          -- erp.DOCTORS.doctor_id
	[SKSrcSystemKeyID] [bigint] NOT NULL,
	[RawFullName] [varchar](320) NULL,
	[RawLpuName] [varchar](300) NULL,
	[IsGoldenRecord] [bit] NOT NULL,
	[SKDoctorKeyID] [bigint] NOT NULL
)
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[RefEmployee]
GO
CREATE TABLE [whsilverad].[dwh].[RefEmployee]
(
	[SKRefEmployeeID] [bigint] NOT NULL,
	[SKRefEmployeeKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](20) NOT NULL,          -- erp.EMPLOYEES.employee_id
	[SKSrcSystemKeyID] [bigint] NOT NULL,
	[RawFullName] [varchar](200) NULL,
	[SKEmployeeKeyID] [bigint] NOT NULL
)
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[RefWarehouse]
GO
CREATE TABLE [whsilverad].[dwh].[RefWarehouse]
(
	[SKRefWarehouseID] [bigint] NOT NULL,
	[SKRefWarehouseKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](20) NOT NULL,          -- erp.WAREHOUSES.warehouse_id
	[SKSrcSystemKeyID] [bigint] NOT NULL,
	[RawName] [varchar](300) NULL,
	[SKWarehouseKeyID] [bigint] NOT NULL
)
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[RefMovementType]
GO
CREATE TABLE [whsilverad].[dwh].[RefMovementType]
(
	[SKRefMovementTypeID] [bigint] NOT NULL,
	[SKRefMovementTypeKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](50) NOT NULL,          -- сире значення erp.INVENTORY_MOVEMENTS.movement_type
	[SKSrcSystemKeyID] [bigint] NOT NULL,
	[RawMovementType] [varchar](50) NULL,
	[SKMovementTypeKeyID] [bigint] NOT NULL
)
GO

/* =========================================================
   ФАКТИ (повне перезавантаження через [dwh].[spFullFct])
   ========================================================= */

DROP TABLE IF EXISTS [whsilverad].[dwh].[FctSales]
GO
CREATE TABLE [whsilverad].[dwh].[FctSales]
(
	[SKFctSalesID] [bigint] NULL,
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[SKSrcSystemKeyID] [bigint] NOT NULL,
	[DocumentNumber] [varchar](30) NULL,          -- order_number
	[ItemId] [varchar](30) NOT NULL,              -- order_line_id
	[Period] [datetime2](3) NULL,                 -- order_date
	[SKDateID] [int] NOT NULL,
	[SKDeliveryDateID] [int] NOT NULL,
	[SKRefClientAccountKeyID] [bigint] NOT NULL,
	[SKRefWarehouseKeyID] [bigint] NOT NULL,
	[SKRefProductKeyID] [bigint] NOT NULL,
	[SKRefEmployeeKeyID] [bigint] NOT NULL,
	[SKOrderStatusKeyID] [bigint] NOT NULL,
	[SKCurrencyKeyID] [bigint] NOT NULL,
	[Qty] [decimal](18,3) NULL,
	[UnitPrice] [decimal](18,4) NULL,
	[DiscountPct] [decimal](5,2) NULL,
	[GrossAmount] [decimal](18,4) NULL,
	[DiscountAmount] [decimal](18,4) NULL,
	[NetAmount] [decimal](18,4) NULL,
	[IsReturn] [bit] NOT NULL,
	[IsCancelled] [bit] NOT NULL,
	[IsAmountConsistent] [bit] NOT NULL,          -- NetAmount vs Qty*UnitPrice*(1-DiscountPct)
	[IsPeriodOutOfRange] [bit] NOT NULL,          -- order_date поза [2020-01-01; сьогодні]
	[IsSrcDuplicate] [bit] NOT NULL               -- рядок мав дублікати по order_line_id у джерелі
)
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[FctInventoryMovement]
GO
CREATE TABLE [whsilverad].[dwh].[FctInventoryMovement]
(
	[SKFctInventoryMovementID] [bigint] NULL,
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[SKSrcSystemKeyID] [bigint] NOT NULL,
	[DocumentNumber] [varchar](50) NULL,          -- reference_document
	[ItemId] [varchar](30) NOT NULL,              -- movement_id
	[Period] [datetime2](3) NULL,                 -- movement_date
	[SKDateID] [int] NOT NULL,
	[SKRefWarehouseKeyID] [bigint] NOT NULL,
	[SKRefProductKeyID] [bigint] NOT NULL,
	[SKRefEmployeeKeyID] [bigint] NOT NULL,
	[SKRefMovementTypeKeyID] [bigint] NOT NULL,
	[Qty] [decimal](18,3) NULL,                   -- сира кількість джерела
	[QtySigned] [decimal](18,3) NULL,             -- Qty * DimMovementType.QtySign
	[IsQtyOutlier] [bit] NOT NULL,                -- |Qty| > 100 000
	[IsSrcDuplicate] [bit] NOT NULL
)
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[FctVisit]
GO
CREATE TABLE [whsilverad].[dwh].[FctVisit]
(
	[SKFctVisitID] [bigint] NULL,
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[SKSrcSystemKeyID] [bigint] NOT NULL,
	[ItemId] [varchar](30) NOT NULL,              -- visit_id
	[Period] [datetime2](3) NULL,                 -- visit_date
	[SKDateID] [int] NOT NULL,
	[SKRefDoctorKeyID] [bigint] NOT NULL,
	[SKRefEmployeeKeyID] [bigint] NOT NULL,
	[SKRefProductKeyID] [bigint] NOT NULL,
	[SKActivityTypeKeyID] [bigint] NOT NULL,
	[DurationMin] [int] NULL,
	[SamplesQty] [int] NULL,
	[VisitCnt] [int] NOT NULL,
	[IsSrcDuplicate] [bit] NOT NULL
)
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[FctPrescription]
GO
CREATE TABLE [whsilverad].[dwh].[FctPrescription]
(
	[SKFctPrescriptionID] [bigint] NULL,
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[SKSrcSystemKeyID] [bigint] NOT NULL,
	[ItemId] [varchar](30) NOT NULL,              -- prescription_id
	[Period] [datetime2](3) NULL,                 -- prescription_date
	[SKDateID] [int] NOT NULL,
	[SKRefDoctorKeyID] [bigint] NOT NULL,
	[SKRefProductKeyID] [bigint] NOT NULL,
	[SKRefEmployeeKeyID] [bigint] NOT NULL,       -- entered_by_employee_id
	[PatientsCnt] [int] NULL,
	[PrescriptionsCnt] [int] NULL,
	[IsSrcDuplicate] [bit] NOT NULL
)
GO

DROP TABLE IF EXISTS [whsilverad].[dwh].[FctAdverseEvent]
GO
CREATE TABLE [whsilverad].[dwh].[FctAdverseEvent]
(
	[SKFctAdverseEventID] [bigint] NULL,
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[SKSrcSystemKeyID] [bigint] NOT NULL,
	[DocumentNumber] [varchar](30) NULL,          -- ae_id
	[ItemId] [varchar](40) NOT NULL,              -- ae_id + '-' + case_version
	[Period] [datetime2](3) NULL,                 -- report_date
	[SKDateID] [int] NOT NULL,
	[SKRefProductKeyID] [bigint] NOT NULL,
	[SKRefDoctorKeyID] [bigint] NOT NULL,
	[SKAeSeriousnessKeyID] [bigint] NOT NULL,
	[SKAeOutcomeKeyID] [bigint] NOT NULL,
	[SKReportSourceKeyID] [bigint] NOT NULL,
	[SKRegionKeyID] [bigint] NOT NULL,
	[CaseVersion] [smallint] NULL,
	[IsLatestVersion] [bit] NOT NULL,
	[IsLogicalError] [bit] NOT NULL,              -- Critical + Recovered
	[CaseCnt] [int] NOT NULL
)
GO
