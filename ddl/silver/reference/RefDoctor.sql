-- whsilver.dwh.RefDoctor
DROP TABLE IF EXISTS [dwh].[RefDoctor]
GO
CREATE TABLE [dwh].[RefDoctor]
(
	[SKRefDoctorID] [bigint] NOT NULL,
	[SKRefDoctorKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](20) NOT NULL,             -- erp.DOCTORS.doctor_id
	[SKSrcSystemKeyID] [bigint] NOT NULL,
	[RawFullName] [varchar](320) NULL,
	[RawLpuName] [varchar](300) NULL,
	[IsGoldenRecord] [bit] NOT NULL,
	[SKDoctorKeyID] [bigint] NOT NULL
)
GO
