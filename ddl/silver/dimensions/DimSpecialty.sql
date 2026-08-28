-- whsilver.dwh.DimSpecialty
DROP TABLE IF EXISTS [dwh].[DimSpecialty]
GO
CREATE TABLE [dwh].[DimSpecialty]
(
	[SKSpecialtyID] [bigint] NOT NULL,
	[SKSpecialtyKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](100) NOT NULL,            -- нормалізована (UPPER) назва спеціальності
	[Name] [varchar](100) NOT NULL
)
GO
