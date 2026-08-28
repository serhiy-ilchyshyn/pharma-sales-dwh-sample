-- whgold.dwh.DimDoctor
DROP TABLE IF EXISTS [dwh].[DimDoctor]
GO
CREATE TABLE [dwh].[DimDoctor]
(
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[SKDoctorID] [bigint] NOT NULL,
	[Id] [varchar](20) NOT NULL,
	[DoctorName] [varchar](320) NULL,
	[Specialty] [varchar](100) NULL,
	[Lpu] [varchar](300) NULL,
	[Region] [varchar](100) NULL,
	[City] [varchar](100) NULL,
	[Segment] [varchar](5) NULL,
	[IsTarget] [bit] NULL
)
GO
