-- whsilver.dwh.EtlObjectDownstream
DROP TABLE IF EXISTS [dwh].[EtlObjectDownstream]
GO
CREATE TABLE [dwh].[EtlObjectDownstream]
(
	[RootObject] [varchar](256) NOT NULL,    -- що перезавантажують (bronze-таблиця або silver-обʼєкт)
	[ObjectName] [varchar](128) NOT NULL     -- silver-обʼєкт без схеми (join з EtlSilverObject)
)
GO
