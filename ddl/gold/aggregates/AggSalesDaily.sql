-- whgold.dwh.AggSalesDaily
DROP TABLE IF EXISTS [dwh].[AggSalesDaily]
GO
CREATE TABLE [dwh].[AggSalesDaily]
(
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[SKDateID] [int] NOT NULL,
	[CalendarDate] [date] NULL,
	[SKProductID] [bigint] NOT NULL,
	[SKClientAccountID] [bigint] NOT NULL,
	[SKEmployeeID] [bigint] NOT NULL,
	[SKWarehouseID] [bigint] NOT NULL,
	[OrderStatus] [varchar](50) NULL,
	[Currency] [varchar](20) NULL,
	[OrderLineCnt] [bigint] NULL,
	[TotalQty] [decimal](38,3) NULL,
	[TotalGrossAmount] [decimal](38,4) NULL,
	[TotalDiscountAmount] [decimal](38,4) NULL,
	[TotalNetAmount] [decimal](38,4) NULL
)
GO
