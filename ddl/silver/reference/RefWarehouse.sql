-- whsilver.dwh.RefWarehouse
DROP TABLE IF EXISTS [dwh].[RefWarehouse]
GO
CREATE TABLE [dwh].[RefWarehouse]
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
	[Id] [varchar](20) NOT NULL,                -- erp.WAREHOUSES.warehouse_id
	[SKSrcSystemKeyID] [bigint] NOT NULL,
	[RawName] [varchar](300) NULL,
	[SKWarehouseKeyID] [bigint] NOT NULL
)
GO
