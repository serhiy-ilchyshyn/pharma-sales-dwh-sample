-- whsilver.dwh.FctSales
DROP TABLE IF EXISTS [dwh].[FctSales]
GO
CREATE TABLE [dwh].[FctSales]
(
	[SKFctSalesID] [bigint] NULL,
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[SKSrcSystemKeyID] [bigint] NOT NULL,
	[DocumentNumber] [varchar](30) NULL,            -- order_number
	[ItemId] [varchar](30) NOT NULL,                -- order_line_id
	[Period] [datetime2](3) NULL,                   -- order_date
	[SKDateID] [int] NOT NULL,
	[SKDeliveryDateID] [int] NOT NULL,
	[SKRefClientAccountKeyID] [bigint] NOT NULL,
	[SKRefWarehouseKeyID] [bigint] NOT NULL,
	[SKRefProductKeyID] [bigint] NOT NULL,
	[SKRefEmployeeKeyID] [bigint] NOT NULL,
	[SKOrderStatusKeyID] [bigint] NOT NULL,
	[SKCurrencyKeyID] [bigint] NOT NULL,
	[Qty] [decimal](18,3) NULL,
	[UnitPrice] [decimal](18,4) NULL,
	[DiscountPct] [decimal](5,2) NULL,
	[GrossAmount] [decimal](18,4) NULL,
	[DiscountAmount] [decimal](18,4) NULL,
	[NetAmount] [decimal](18,4) NULL,
	[IsReturn] [bit] NOT NULL,
	[IsCancelled] [bit] NOT NULL,
	[IsAmountConsistent] [bit] NOT NULL,            -- NetAmount vs Qty*UnitPrice*(1-DiscountPct)
	[IsPeriodOutOfRange] [bit] NOT NULL,            -- order_date поза [2020-01-01; сьогодні]
	[IsSrcDuplicate] [bit] NOT NULL,                -- рядок мав дублікати по order_line_id у джерелі
	[SrcModifiedAt] [datetime2](3) NULL
)
GO
