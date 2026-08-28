-- whsilver.dwh.DimProduct
DROP TABLE IF EXISTS [dwh].[DimProduct]
GO
CREATE TABLE [dwh].[DimProduct]
(
	[SKProductID] [bigint] NOT NULL,
	[SKProductKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](20) NOT NULL,
	[Name] [varchar](200) NULL,
	[SkuCode] [varchar](20) NULL,
	[Barcode] [varchar](20) NULL,
	[RegistrationNumber] [varchar](50) NULL,
	[INN] [varchar](200) NULL,
	[AtcCode] [varchar](20) NULL,
	[SKAtcClassKeyID] [bigint] NOT NULL,
	[ReleaseForm] [varchar](100) NULL,
	[Dosage] [varchar](50) NULL,
	[SKManufacturerKeyID] [bigint] NOT NULL,
	[RxOtcType] [varchar](10) NULL,
	[BasePriceUAH] [decimal](18,4) NULL,
	[IsActive] [bit] NULL,
	[IsAtcCodeValid] [bit] NOT NULL,
	[SrcCreatedAt] [datetime2](3) NULL
)
GO
