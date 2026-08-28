-- whsilver.dwh.RefProduct
DROP TABLE IF EXISTS [dwh].[RefProduct]
GO
CREATE TABLE [dwh].[RefProduct]
(
	[SKRefProductID] [bigint] NOT NULL,
	[SKRefProductKeyID] [bigint] NOT NULL,
	[StartDate] [datetime2](3) NULL,
	[EndDate] [datetime2](3) NULL,
	[IsDeleted] [bit] NULL,
	[CreatedBy] [varchar](128) NOT NULL,
	[ModifiedBy] [varchar](128) NULL,
	[CreatedAt] [datetime2](3) NOT NULL,
	[ModifiedAt] [datetime2](3) NULL,
	[Id] [varchar](20) NOT NULL,              -- erp.PRODUCTS.product_id
	[SKSrcSystemKeyID] [bigint] NOT NULL,
	[RawSkuCode] [varchar](20) NULL,
	[RawBrandName] [varchar](200) NULL,
	[SKProductKeyID] [bigint] NOT NULL
)
GO
