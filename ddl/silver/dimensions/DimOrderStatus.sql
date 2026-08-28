-- whsilver.dwh.DimOrderStatus
DROP TABLE IF EXISTS [dwh].[DimOrderStatus]
GO
CREATE TABLE [dwh].[DimOrderStatus]
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
