-- whsilver.dwh.DimRegion
DROP TABLE IF EXISTS [dwh].[DimRegion]
GO
CREATE TABLE [dwh].[DimRegion]
(
	[SKRegionID] [bigint] NOT NULL,
	[SKRegionKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](100) NOT NULL,
	[Name] [varchar](100) NOT NULL
)
GO
