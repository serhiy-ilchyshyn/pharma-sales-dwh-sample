-- whsilver.dwh.DimActivityType
DROP TABLE IF EXISTS [dwh].[DimActivityType]
GO
CREATE TABLE [dwh].[DimActivityType]
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
