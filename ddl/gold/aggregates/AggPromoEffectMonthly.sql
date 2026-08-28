-- whgold.dwh.AggPromoEffectMonthly
DROP TABLE IF EXISTS [dwh].[AggPromoEffectMonthly]
GO
CREATE TABLE [dwh].[AggPromoEffectMonthly]
(
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[YearMonth] [varchar](7) NOT NULL,
	[YearNum] [int] NOT NULL,
	[MonthNum] [int] NOT NULL,
	[SKProductID] [bigint] NOT NULL,
	[Region] [varchar](100) NULL,
	[VisitCnt] [bigint] NULL,
	[TotalSamplesQty] [bigint] NULL,
	[TotalPrescriptionsCnt] [bigint] NULL,
	[TotalQty] [decimal](38,3) NULL,
	[TotalNetAmount] [decimal](38,4) NULL,
	[NetAmountPerVisit] [decimal](38,4) NULL,
	[MonthStartDate] [date] NULL
)
GO
