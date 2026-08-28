-- whsilver.dwh.EtlObjectDependency
DROP TABLE IF EXISTS [dwh].[EtlObjectDependency]
GO
CREATE TABLE [dwh].[EtlObjectDependency]
(
	[ObjectName] [varchar](256) NOT NULL,         -- dwh.<SilverTable>
	[DependsOnObject] [varchar](256) NOT NULL     -- dwh.<SilverTable> | lhbronze.<schema>.<table>
)
GO
