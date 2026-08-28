-- whsilver.dwh.FctPrescription
DROP TABLE IF EXISTS [dwh].[FctPrescription]
GO
CREATE TABLE [dwh].[FctPrescription]
(
	[SKFctPrescriptionID] [bigint] NULL,
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[SKSrcSystemKeyID] [bigint] NOT NULL,
	[ItemId] [varchar](30) NOT NULL,           -- prescription_id
	[Period] [datetime2](3) NULL,              -- prescription_date
	[SKDateID] [int] NOT NULL,
	[SKRefDoctorKeyID] [bigint] NOT NULL,
	[SKRefProductKeyID] [bigint] NOT NULL,
	[SKRefEmployeeKeyID] [bigint] NOT NULL,    -- entered_by_employee_id
	[PatientsCnt] [int] NULL,
	[PrescriptionsCnt] [int] NULL,
	[IsSrcDuplicate] [bit] NOT NULL,
	[SrcModifiedAt] [datetime2](3) NULL
)
GO
