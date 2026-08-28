-- whsilver.dwh.DimEmployee
DROP TABLE IF EXISTS [dwh].[DimEmployee]
GO
CREATE TABLE [dwh].[DimEmployee]
(
	[SKEmployeeID] [bigint] NOT NULL,
	[SKEmployeeKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](20) NOT NULL,
	[Name] [varchar](200) NULL,
	[EmployeeRole] [varchar](100) NULL,
	[SKTerritoryKeyID] [bigint] NOT NULL,
	[ProductLine] [varchar](20) NULL,              -- RX / OTC / Both
	[SKEmployeeManagerKeyID] [bigint] NOT NULL,
	[HireDate] [date] NULL,
	[IsActive] [bit] NULL,
	[SrcCreatedAt] [datetime2](3) NULL
)
GO
