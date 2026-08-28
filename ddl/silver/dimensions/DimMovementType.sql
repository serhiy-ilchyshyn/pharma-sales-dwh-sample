-- whsilver.dwh.DimMovementType
DROP TABLE IF EXISTS [dwh].[DimMovementType]
GO
CREATE TABLE [dwh].[DimMovementType]
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
	[Direction] [varchar](10) NOT NULL,         -- IN / OUT / TRANSFER
	[QtySign] [smallint] NOT NULL               -- +1 / -1 / 0 : знак для FctInventoryMovement.QtySigned
)
GO
