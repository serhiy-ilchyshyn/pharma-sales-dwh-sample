-- whsilver.dwh.FctAdverseEvent
DROP TABLE IF EXISTS [dwh].[FctAdverseEvent]
GO
CREATE TABLE [dwh].[FctAdverseEvent]
(
	[SKFctAdverseEventID] [bigint] NULL,
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[SKSrcSystemKeyID] [bigint] NOT NULL,
	[DocumentNumber] [varchar](30) NULL,         -- ae_id
	[ItemId] [varchar](40) NOT NULL,             -- ae_id + '-' + case_version
	[Period] [datetime2](3) NULL,                -- report_date
	[SKDateID] [int] NOT NULL,
	[SKRefProductKeyID] [bigint] NOT NULL,
	[SKRefDoctorKeyID] [bigint] NOT NULL,
	[SKAeSeriousnessKeyID] [bigint] NOT NULL,
	[SKAeOutcomeKeyID] [bigint] NOT NULL,
	[SKReportSourceKeyID] [bigint] NOT NULL,
	[SKRegionKeyID] [bigint] NOT NULL,
	[CaseVersion] [smallint] NULL,
	[IsLatestVersion] [bit] NOT NULL,
	[IsLogicalError] [bit] NOT NULL,             -- Critical + Recovered
	[CaseCnt] [int] NOT NULL,
	[SrcModifiedAt] [datetime2](3) NULL
)
GO
