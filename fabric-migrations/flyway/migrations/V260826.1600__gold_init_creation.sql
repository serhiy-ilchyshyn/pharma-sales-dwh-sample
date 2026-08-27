-- ClickUp: PHARMA-GOLD-001
-- Gold-рівень: денормалізовані виміри + агрегати для бізнес-звітності.
--
-- Конвенції (як у grp-ctl-azure-dwh, whgoldad.dwh):
--   Dim<Name> / Agg<Name>, технічні колонки лише [CreatedBy] + [CreatedAt];
--   без SCD2 — gold завжди знімок поточного стану, повне перезавантаження з v*;
--   ключі вимірів = durable keys silver (SK<Name>ID), атрибути денормалізовані
--   (замість SKRegionKeyID у DimClientAccount лежить назва регіону).
--
-- Gold живе в окремому warehouse [whgold], схема [dwh] — як у прод-репозиторії
-- (там [whgoldad].[dwh]). Silver читається крос-базово як [whsilver].[dwh].*,
-- запис іде локально в [whgold].
GO
--IMPORTANT
USE [whgold];
--IMPORTANT
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dwh')
    EXEC('CREATE SCHEMA dwh');
GO

/* =========================================================
   ВИМІРИ
   ========================================================= */

DROP TABLE IF EXISTS [whgold].[dwh].[DimDate]
GO
CREATE TABLE [whgold].[dwh].[DimDate]
(
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[SKDateID] [int] NOT NULL,
	[CalendarDate] [date] NOT NULL,
	[DayOfMonth] [int] NOT NULL,
	[MonthNum] [int] NOT NULL,
	[MonthName] [varchar](30) NOT NULL,
	[QuarterNum] [int] NOT NULL,
	[YearNum] [int] NOT NULL,
	[YearMonth] [varchar](7) NOT NULL,
	[FiscalYear] [int] NOT NULL,
	[FiscalQuarter] [int] NOT NULL
)
GO

DROP TABLE IF EXISTS [whgold].[dwh].[DimProduct]
GO
CREATE TABLE [whgold].[dwh].[DimProduct]
(
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[SKProductID] [bigint] NOT NULL,
	[Id] [varchar](20) NOT NULL,
	[ProductName] [varchar](200) NULL,
	[SkuCode] [varchar](20) NULL,
	[INN] [varchar](200) NULL,
	[AtcCode] [varchar](20) NULL,
	[AtcClass] [varchar](128) NULL,
	[ReleaseForm] [varchar](100) NULL,
	[Dosage] [varchar](50) NULL,
	[Manufacturer] [varchar](200) NULL,
	[RxOtcType] [varchar](10) NULL,
	[BasePriceUAH] [decimal](18,4) NULL,
	[IsActive] [bit] NULL
)
GO

DROP TABLE IF EXISTS [whgold].[dwh].[DimClientAccount]
GO
CREATE TABLE [whgold].[dwh].[DimClientAccount]
(
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[SKClientAccountID] [bigint] NOT NULL,
	[Id] [varchar](20) NOT NULL,
	[AccountName] [varchar](500) NULL,
	[AccountType] [varchar](50) NULL,
	[Chain] [varchar](200) NULL,
	[LegalEntityName] [varchar](500) NULL,
	[EDRPOU] [varchar](10) NULL,
	[Region] [varchar](100) NULL,
	[City] [varchar](100) NULL,
	[IsActive] [bit] NULL,
	[SrcDuplicateCnt] [int] NULL
)
GO

DROP TABLE IF EXISTS [whgold].[dwh].[DimDoctor]
GO
CREATE TABLE [whgold].[dwh].[DimDoctor]
(
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[SKDoctorID] [bigint] NOT NULL,
	[Id] [varchar](20) NOT NULL,
	[DoctorName] [varchar](320) NULL,
	[Specialty] [varchar](100) NULL,
	[Lpu] [varchar](300) NULL,
	[Region] [varchar](100) NULL,
	[City] [varchar](100) NULL,
	[Segment] [varchar](5) NULL,
	[IsTarget] [bit] NULL
)
GO

DROP TABLE IF EXISTS [whgold].[dwh].[DimEmployee]
GO
CREATE TABLE [whgold].[dwh].[DimEmployee]
(
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[SKEmployeeID] [bigint] NOT NULL,
	[Id] [varchar](20) NOT NULL,
	[EmployeeName] [varchar](200) NULL,
	[EmployeeRole] [varchar](100) NULL,
	[Territory] [varchar](100) NULL,
	[ProductLine] [varchar](20) NULL,
	[ManagerName] [varchar](200) NULL,
	[HireDate] [date] NULL,
	[IsActive] [bit] NULL
)
GO

DROP TABLE IF EXISTS [whgold].[dwh].[DimWarehouse]
GO
CREATE TABLE [whgold].[dwh].[DimWarehouse]
(
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[SKWarehouseID] [bigint] NOT NULL,
	[Id] [varchar](20) NOT NULL,
	[WarehouseName] [varchar](300) NULL,
	[WarehouseCode] [varchar](20) NULL,
	[WarehouseType] [varchar](50) NULL,
	[OwnerAccountName] [varchar](500) NULL,
	[Region] [varchar](100) NULL,
	[City] [varchar](100) NULL
)
GO

/* =========================================================
   АГРЕГАТИ
   ========================================================= */

DROP TABLE IF EXISTS [whgold].[dwh].[AggSalesDaily]
GO
CREATE TABLE [whgold].[dwh].[AggSalesDaily]
(
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[SKDateID] [int] NOT NULL,
	[CalendarDate] [date] NULL,
	[SKProductID] [bigint] NOT NULL,
	[SKClientAccountID] [bigint] NOT NULL,
	[SKEmployeeID] [bigint] NOT NULL,
	[SKWarehouseID] [bigint] NOT NULL,
	[OrderStatus] [varchar](50) NULL,
	[Currency] [varchar](20) NULL,
	[OrderLineCnt] [bigint] NULL,
	[TotalQty] [decimal](38,3) NULL,
	[TotalGrossAmount] [decimal](38,4) NULL,
	[TotalDiscountAmount] [decimal](38,4) NULL,
	[TotalNetAmount] [decimal](38,4) NULL
)
GO

DROP TABLE IF EXISTS [whgold].[dwh].[AggSalesMonthly]
GO
CREATE TABLE [whgold].[dwh].[AggSalesMonthly]
(
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[YearMonth] [varchar](7) NOT NULL,
	[YearNum] [int] NOT NULL,
	[MonthNum] [int] NOT NULL,
	[SKProductID] [bigint] NOT NULL,
	[SKEmployeeID] [bigint] NOT NULL,
	[Region] [varchar](100) NULL,
	[AccountType] [varchar](50) NULL,
	[OrderLineCnt] [bigint] NULL,
	[ClientAccountCnt] [bigint] NULL,
	[TotalQty] [decimal](38,3) NULL,
	[TotalNetAmount] [decimal](38,4) NULL,
	[ReturnQty] [decimal](38,3) NULL,
	[ReturnNetAmount] [decimal](38,4) NULL
)
GO

DROP TABLE IF EXISTS [whgold].[dwh].[AggVisitMonthly]
GO
CREATE TABLE [whgold].[dwh].[AggVisitMonthly]
(
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[YearMonth] [varchar](7) NOT NULL,
	[YearNum] [int] NOT NULL,
	[MonthNum] [int] NOT NULL,
	[SKEmployeeID] [bigint] NOT NULL,
	[SKProductID] [bigint] NOT NULL,
	[Specialty] [varchar](100) NULL,
	[ActivityType] [varchar](50) NULL,
	[Region] [varchar](100) NULL,
	[VisitCnt] [bigint] NULL,
	[DoctorCnt] [bigint] NULL,
	[TotalDurationMin] [bigint] NULL,
	[TotalSamplesQty] [bigint] NULL
)
GO

DROP TABLE IF EXISTS [whgold].[dwh].[AggPrescriptionMonthly]
GO
CREATE TABLE [whgold].[dwh].[AggPrescriptionMonthly]
(
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[YearMonth] [varchar](7) NOT NULL,
	[YearNum] [int] NOT NULL,
	[MonthNum] [int] NOT NULL,
	[SKProductID] [bigint] NOT NULL,
	[Specialty] [varchar](100) NULL,
	[Region] [varchar](100) NULL,
	[DoctorCnt] [bigint] NULL,
	[TotalPatientsCnt] [bigint] NULL,
	[TotalPrescriptionsCnt] [bigint] NULL
)
GO

DROP TABLE IF EXISTS [whgold].[dwh].[AggInventoryMonthly]
GO
CREATE TABLE [whgold].[dwh].[AggInventoryMonthly]
(
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[YearMonth] [varchar](7) NOT NULL,
	[YearNum] [int] NOT NULL,
	[MonthNum] [int] NOT NULL,
	[SKWarehouseID] [bigint] NOT NULL,
	[SKProductID] [bigint] NOT NULL,
	[MovementCnt] [bigint] NULL,
	[QtyIn] [decimal](38,3) NULL,
	[QtyOut] [decimal](38,3) NULL,
	[QtyWriteOff] [decimal](38,3) NULL,
	[QtyNet] [decimal](38,3) NULL
)
GO

DROP TABLE IF EXISTS [whgold].[dwh].[AggAdverseEventMonthly]
GO
CREATE TABLE [whgold].[dwh].[AggAdverseEventMonthly]
(
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[YearMonth] [varchar](7) NOT NULL,
	[YearNum] [int] NOT NULL,
	[MonthNum] [int] NOT NULL,
	[SKProductID] [bigint] NOT NULL,
	[Seriousness] [varchar](50) NULL,
	[Region] [varchar](100) NULL,
	[CaseCnt] [bigint] NULL,
	[FatalCnt] [bigint] NULL,
	[LogicalErrorCnt] [bigint] NULL
)
GO

DROP TABLE IF EXISTS [whgold].[dwh].[AggPromoEffectMonthly]
GO
CREATE TABLE [whgold].[dwh].[AggPromoEffectMonthly]
(
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[YearMonth] [varchar](7) NOT NULL,
	[YearNum] [int] NOT NULL,
	[MonthNum] [int] NOT NULL,
	[SKProductID] [bigint] NOT NULL,
	[Region] [varchar](100) NULL,
	[VisitCnt] [bigint] NULL,
	[TotalSamplesQty] [bigint] NULL,
	[TotalPrescriptionsCnt] [bigint] NULL,
	[TotalQty] [decimal](38,3) NULL,
	[TotalNetAmount] [decimal](38,4) NULL,
	[NetAmountPerVisit] [decimal](38,4) NULL
)
GO
