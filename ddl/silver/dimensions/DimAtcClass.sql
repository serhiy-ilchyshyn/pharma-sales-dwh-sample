-- whsilver.dwh.DimAtcClass
DROP TABLE IF EXISTS [dwh].[DimAtcClass]
GO
CREATE TABLE [dwh].[DimAtcClass]
(
	[SKAtcClassID] [bigint] NOT NULL,
	[SKAtcClassKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NOT NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [char](1) NOT NULL,
	[Name] [varchar](128) NOT NULL,
	[Description] [varchar](256) NULL
)
GO
