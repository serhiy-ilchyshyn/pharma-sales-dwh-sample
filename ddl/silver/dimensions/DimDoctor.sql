-- whsilver.dwh.DimDoctor
DROP TABLE IF EXISTS [dwh].[DimDoctor]
GO
CREATE TABLE [dwh].[DimDoctor]
(
	[SKDoctorID] [bigint] NOT NULL,
	[SKDoctorKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](20) NOT NULL,             -- golden doctor_id (найстаріший з дублів)
	[Name] [varchar](320) NULL,              -- ПІБ
	[LastName] [varchar](100) NULL,
	[FirstName] [varchar](100) NULL,
	[MiddleName] [varchar](100) NULL,
	[SKSpecialtyKeyID] [bigint] NOT NULL,
	[SKLpuKeyID] [bigint] NOT NULL,
	[SKRegionKeyID] [bigint] NOT NULL,
	[SKCityKeyID] [bigint] NOT NULL,
	[Segment] [varchar](5) NULL,             -- A / B / C / N
	[IsTarget] [bit] NULL,
	[SrcDuplicateCnt] [int] NOT NULL,
	[SrcCreatedAt] [datetime2](3) NULL
)
GO
