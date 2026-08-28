-- whsilver.dwh.DimAeOutcome
DROP TABLE IF EXISTS [dwh].[DimAeOutcome]
GO
CREATE TABLE [dwh].[DimAeOutcome]
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
