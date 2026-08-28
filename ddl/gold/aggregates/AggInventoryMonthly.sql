-- whgold.dwh.AggInventoryMonthly
DROP TABLE IF EXISTS [dwh].[AggInventoryMonthly]
GO
CREATE TABLE [dwh].[AggInventoryMonthly]
(
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[YearMonth] [varchar](7) NOT NULL,
	[YearNum] [int] NOT NULL,
	[MonthNum] [int] NOT NULL,
	[SKWarehouseID] [bigint] NOT NULL,
	[SKProductID] [bigint] NOT NULL,
	[MovementCnt] [bigint] NULL,
	[QtyIn] [decimal](38,3) NULL,
	[QtyOut] [decimal](38,3) NULL,
	[QtyWriteOff] [decimal](38,3) NULL,
	[QtyNet] [decimal](38,3) NULL,
	[MonthStartDate] [date] NULL
)
GO
