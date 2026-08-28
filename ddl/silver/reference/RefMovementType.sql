-- whsilver.dwh.RefMovementType
DROP TABLE IF EXISTS [dwh].[RefMovementType]
GO
CREATE TABLE [dwh].[RefMovementType]
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
	[Id] [varchar](50) NOT NULL,                   -- сире значення erp.INVENTORY_MOVEMENTS.movement_type
	[SKSrcSystemKeyID] [bigint] NOT NULL,
	[RawMovementType] [varchar](50) NULL,
	[SKMovementTypeKeyID] [bigint] NOT NULL
)
GO
