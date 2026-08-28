-- whsilver.dwh.DimSrcSystem
DROP TABLE IF EXISTS [dwh].[DimSrcSystem]
GO
CREATE TABLE [dwh].[DimSrcSystem]
(
	[SKSrcSystemID] [bigint] NOT NULL,
	[SKSrcSystemKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NOT NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [int] NOT NULL,
	[Name] [varchar](50) NOT NULL
)
GO
