-- whgold.dwh.EtlGoldLoadLog
DROP TABLE IF EXISTS [dwh].[EtlGoldLoadLog]
GO
CREATE TABLE [dwh].[EtlGoldLoadLog]
(
	[LoadId] [varchar](250) NOT NULL,
	[ObjectName] [varchar](128) NOT NULL,
	[ObjectType] [varchar](10) NOT NULL,
	[LoadLevel] [int] NOT NULL,
	[StartedAt] [datetime2](3) NOT NULL,
	[FinishedAt] [datetime2](3) NULL,
	[DurationSec] [decimal](18,3) NULL,
	[RowCnt] [bigint] NULL,
	[Status] [varchar](20) NOT NULL,
	[ErrorMessage] [varchar](8000) NULL
)
GO
