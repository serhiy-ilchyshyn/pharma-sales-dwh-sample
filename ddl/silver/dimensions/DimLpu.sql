-- whsilver.dwh.DimLpu
DROP TABLE IF EXISTS [dwh].[DimLpu]
GO
CREATE TABLE [dwh].[DimLpu]
(
	[SKLpuID] [bigint] NOT NULL,
	[SKLpuKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](300) NOT NULL,
	[Name] [varchar](300) NOT NULL,
	[SKRegionKeyID] [bigint] NOT NULL,
	[SKCityKeyID] [bigint] NOT NULL
)
GO
