-- whsilver.dwh.EtlSilverObject
DROP TABLE IF EXISTS [dwh].[EtlSilverObject]
GO
CREATE TABLE [dwh].[EtlSilverObject]
(
	[ObjectName] [varchar](128) NOT NULL,
	[ObjectType] [varchar](10) NOT NULL,      -- Dim / Ref / Fct
	[LoadLevel] [int] NOT NULL,
	[ScdType] [varchar](10) NULL,             -- SCD1 / SCD2 для Dim і Ref
	[PassCnt] [smallint] NOT NULL,
	[LoadStrategy] [varchar](20) NOT NULL,    -- Full / Incremental (Incremental лише для Fct)
	[WatermarkColumn] [varchar](128) NULL,
	[IsActive] [bit] NOT NULL
)
GO
