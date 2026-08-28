-- whsilver.dwh.DimCurrency
DROP TABLE IF EXISTS [dwh].[DimCurrency]
GO
CREATE TABLE [dwh].[DimCurrency]
(
	[SKCurrencyID] [bigint] NOT NULL,
	[SKCurrencyKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NOT NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [char](3) NOT NULL,
	[Name] [varchar](20) NOT NULL,
	[FullName] [varchar](100) NULL
)
GO
