-- whgold.dwh.AggAdverseEventMonthly
DROP TABLE IF EXISTS [dwh].[AggAdverseEventMonthly]
GO
CREATE TABLE [dwh].[AggAdverseEventMonthly]
(
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[YearMonth] [varchar](7) NOT NULL,
	[YearNum] [int] NOT NULL,
	[MonthNum] [int] NOT NULL,
	[SKProductID] [bigint] NOT NULL,
	[Seriousness] [varchar](50) NULL,
	[Region] [varchar](100) NULL,
	[CaseCnt] [bigint] NULL,
	[FatalCnt] [bigint] NULL,
	[LogicalErrorCnt] [bigint] NULL,
	[MonthStartDate] [date] NULL
)
GO
