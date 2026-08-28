-- whsilver.dwh.FctVisit
DROP TABLE IF EXISTS [dwh].[FctVisit]
GO
CREATE TABLE [dwh].[FctVisit]
(
	[SKFctVisitID] [bigint] NULL,
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[SKSrcSystemKeyID] [bigint] NOT NULL,
	[ItemId] [varchar](30) NOT NULL,            -- visit_id
	[Period] [datetime2](3) NULL,               -- visit_date
	[SKDateID] [int] NOT NULL,
	[SKRefDoctorKeyID] [bigint] NOT NULL,
	[SKRefEmployeeKeyID] [bigint] NOT NULL,
	[SKRefProductKeyID] [bigint] NOT NULL,
	[SKActivityTypeKeyID] [bigint] NOT NULL,
	[DurationMin] [int] NULL,
	[SamplesQty] [int] NULL,
	[VisitCnt] [int] NOT NULL,
	[IsSrcDuplicate] [bit] NOT NULL,
	[SrcModifiedAt] [datetime2](3) NULL
)
GO
