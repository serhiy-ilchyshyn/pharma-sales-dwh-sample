-- whgold.dwh.DimWarehouse
DROP TABLE IF EXISTS [dwh].[DimWarehouse]
GO
CREATE TABLE [dwh].[DimWarehouse]
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
