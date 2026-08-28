-- whsilver.dwh.DimChain
DROP TABLE IF EXISTS [dwh].[DimChain]
GO
CREATE TABLE [dwh].[DimChain]
(
	[SKChainID] [bigint] NOT NULL,
	[SKChainKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](200) NOT NULL,
	[Name] [varchar](200) NOT NULL
)
GO
