-- whsilver.dwh.RefEmployee
DROP TABLE IF EXISTS [dwh].[RefEmployee]
GO
CREATE TABLE [dwh].[RefEmployee]
(
	[SKRefEmployeeID] [bigint] NOT NULL,
	[SKRefEmployeeKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](20) NOT NULL,               -- erp.EMPLOYEES.employee_id
	[SKSrcSystemKeyID] [bigint] NOT NULL,
	[RawFullName] [varchar](200) NULL,
	[SKEmployeeKeyID] [bigint] NOT NULL
)
GO
