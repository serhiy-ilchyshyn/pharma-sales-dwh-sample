-- whsilver.dwh.DimLegalEntity
DROP TABLE IF EXISTS [dwh].[DimLegalEntity]
GO
CREATE TABLE [dwh].[DimLegalEntity]
(
	[SKLegalEntityID] [bigint] NOT NULL,
	[SKLegalEntityKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](10) NOT NULL,               -- ЄДРПОУ
	[Name] [varchar](500) NULL,
	[EDRPOU] [varchar](10) NOT NULL,
	[TaxId] [varchar](12) NULL
)
GO
