-- whsilver.dwh.DimWarehouse
DROP TABLE IF EXISTS [dwh].[DimWarehouse]
GO
CREATE TABLE [dwh].[DimWarehouse]
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
	[WarehouseType] [varchar](50) NULL,               -- Own / Consignment / Transit
	[SKClientAccountOwnerKeyID] [bigint] NOT NULL,
	[SKRegionKeyID] [bigint] NOT NULL,
	[SKCityKeyID] [bigint] NOT NULL,
	[SrcCreatedAt] [datetime2](3) NULL
)
GO
