-- whgold.dwh.DimEmployee
DROP TABLE IF EXISTS [dwh].[DimEmployee]
GO
CREATE TABLE [dwh].[DimEmployee]
(
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[SKEmployeeID] [bigint] NOT NULL,
	[Id] [varchar](20) NOT NULL,
	[EmployeeName] [varchar](200) NULL,
	[EmployeeRole] [varchar](100) NULL,
	[Territory] [varchar](100) NULL,
	[ProductLine] [varchar](20) NULL,
	[ManagerName] [varchar](200) NULL,
	[HireDate] [date] NULL,
	[IsActive] [bit] NULL
)
GO
