-- whsilver.dwh.DimAeSeriousness
DROP TABLE IF EXISTS [dwh].[DimAeSeriousness]
GO
CREATE TABLE [dwh].[DimAeSeriousness]
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
