-- whsilver.dwh.DimClientAccount
DROP TABLE IF EXISTS [dwh].[DimClientAccount]
GO
CREATE TABLE [dwh].[DimClientAccount]
(
	[SKClientAccountID] [bigint] NOT NULL,
	[SKClientAccountKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](20) NOT NULL,                 -- golden customer_id (найстаріший з дублів)
	[Name] [varchar](500) NULL,
	[AccountType] [varchar](50) NULL,            -- Pharmacy / HospitalPharmacy / Distributor
	[SKChainKeyID] [bigint] NOT NULL,
	[SKLegalEntityKeyID] [bigint] NOT NULL,
	[SKRegionKeyID] [bigint] NOT NULL,
	[SKCityKeyID] [bigint] NOT NULL,
	[Address] [varchar](500) NULL,
	[IsActive] [bit] NULL,
	[SrcDuplicateCnt] [int] NOT NULL,            -- скільки customer_id джерела злиті в цей запис
	[SrcCreatedAt] [datetime2](3) NULL
)
GO
