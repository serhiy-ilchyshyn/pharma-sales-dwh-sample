-- whgold.dwh.DimProduct
DROP TABLE IF EXISTS [dwh].[DimProduct]
GO
CREATE TABLE [dwh].[DimProduct]
(
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[SKProductID] [bigint] NOT NULL,
	[Id] [varchar](20) NOT NULL,
	[ProductName] [varchar](200) NULL,
	[SkuCode] [varchar](20) NULL,
	[INN] [varchar](200) NULL,
	[AtcCode] [varchar](20) NULL,
	[AtcClass] [varchar](128) NULL,
	[ReleaseForm] [varchar](100) NULL,
	[Dosage] [varchar](50) NULL,
	[Manufacturer] [varchar](200) NULL,
	[RxOtcType] [varchar](10) NULL,
	[BasePriceUAH] [decimal](18,4) NULL,
	[IsActive] [bit] NULL
)
GO
