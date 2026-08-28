-- whsilver.dwh.DimManufacturer
DROP TABLE IF EXISTS [dwh].[DimManufacturer]
GO
CREATE TABLE [dwh].[DimManufacturer]
(
	[SKManufacturerID] [bigint] NOT NULL,
	[SKManufacturerKeyID] [bigint] NOT NULL,
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
