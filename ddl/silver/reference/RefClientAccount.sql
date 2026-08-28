-- whsilver.dwh.RefClientAccount
DROP TABLE IF EXISTS [dwh].[RefClientAccount]
GO
CREATE TABLE [dwh].[RefClientAccount]
(
	[SKRefClientAccountID] [bigint] NOT NULL,
	[SKRefClientAccountKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](20) NOT NULL,                    -- erp.CUSTOMERS.customer_id (у т.ч. дублі CST-9xxxx)
	[SKSrcSystemKeyID] [bigint] NOT NULL,
	[RawName] [varchar](500) NULL,
	[RawEDRPOU] [varchar](10) NULL,
	[IsGoldenRecord] [bit] NOT NULL,
	[SKClientAccountKeyID] [bigint] NOT NULL
)
GO
