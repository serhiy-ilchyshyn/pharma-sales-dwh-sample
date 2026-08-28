-- whgold.dwh.DimClientAccount
DROP TABLE IF EXISTS [dwh].[DimClientAccount]
GO
CREATE TABLE [dwh].[DimClientAccount]
(
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[SKClientAccountID] [bigint] NOT NULL,
	[Id] [varchar](20) NOT NULL,
	[AccountName] [varchar](500) NULL,
	[AccountType] [varchar](50) NULL,
	[Chain] [varchar](200) NULL,
	[LegalEntityName] [varchar](500) NULL,
	[EDRPOU] [varchar](10) NULL,
	[Region] [varchar](100) NULL,
	[City] [varchar](100) NULL,
	[IsActive] [bit] NULL,
	[SrcDuplicateCnt] [int] NULL
)
GO
