-- whgold.dwh.AggSalesMonthly
DROP TABLE IF EXISTS [dwh].[AggSalesMonthly]
GO
CREATE TABLE [dwh].[AggSalesMonthly]
(
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[YearMonth] [varchar](7) NOT NULL,
	[YearNum] [int] NOT NULL,
	[MonthNum] [int] NOT NULL,
	[SKProductID] [bigint] NOT NULL,
	[SKEmployeeID] [bigint] NOT NULL,
	[Region] [varchar](100) NULL,
	[AccountType] [varchar](50) NULL,
	[OrderLineCnt] [bigint] NULL,
	[ClientAccountCnt] [bigint] NULL,
	[TotalQty] [decimal](38,3) NULL,
	[TotalNetAmount] [decimal](38,4) NULL,
	[ReturnQty] [decimal](38,3) NULL,
	[ReturnNetAmount] [decimal](38,4) NULL,
	[MonthStartDate] [date] NULL
)
GO
