-- whsilver.dwh.EtlBronzeObject
DROP TABLE IF EXISTS [dwh].[EtlBronzeObject]
GO
CREATE TABLE [dwh].[EtlBronzeObject]
(
	[SourceSchema] [varchar](128) NOT NULL,
	[SourceTable] [varchar](128) NOT NULL,
	[TargetSchema] [varchar](128) NOT NULL,
	[TargetTable] [varchar](128) NOT NULL,
	[LoadMode] [varchar](20) NOT NULL,         -- Overwrite (повне перезавантаження таблиці bronze)
	[IsActive] [bit] NOT NULL
)
GO
