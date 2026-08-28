-- whsilver.dwh.EtlSilverWatermark
DROP TABLE IF EXISTS [dwh].[EtlSilverWatermark]
GO
CREATE TABLE [dwh].[EtlSilverWatermark]
(
	[ObjectName] [varchar](128) NOT NULL,
	[WatermarkValue] [datetime2](3) NULL,
	[LastLoadId] [varchar](250) NULL,
	[ModifiedAt] [datetime2](3) NULL
)
GO
