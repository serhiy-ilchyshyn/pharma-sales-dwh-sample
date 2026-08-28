-- whsilver.dwh.DimCity
DROP TABLE IF EXISTS [dwh].[DimCity]
GO
CREATE TABLE [dwh].[DimCity]
(
	[SKCityID] [bigint] NOT NULL,
	[SKCityKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](210) NOT NULL,           -- <Region>|<City>
	[Name] [varchar](100) NOT NULL,
	[SKRegionKeyID] [bigint] NOT NULL
)
GO
