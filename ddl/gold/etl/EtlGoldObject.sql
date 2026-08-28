-- whgold.dwh.EtlGoldObject
DROP TABLE IF EXISTS [dwh].[EtlGoldObject]
GO
CREATE TABLE [dwh].[EtlGoldObject]
(
	[ObjectName] [varchar](128) NOT NULL,
	[ObjectType] [varchar](10) NOT NULL,     -- Dim / Agg
	[LoadLevel] [int] NOT NULL,
	[IsActive] [bit] NOT NULL
)
GO
