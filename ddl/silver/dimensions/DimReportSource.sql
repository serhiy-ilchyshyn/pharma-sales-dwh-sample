-- whsilver.dwh.DimReportSource
DROP TABLE IF EXISTS [dwh].[DimReportSource]
GO
CREATE TABLE [dwh].[DimReportSource]
(
	[SKReportSourceID] [bigint] NOT NULL,
	[SKReportSourceKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](20) NOT NULL,
	[Name] [varchar](50) NOT NULL,
	[IsHcpReported] [bit] NOT NULL
)
GO
