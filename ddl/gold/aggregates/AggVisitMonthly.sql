-- whgold.dwh.AggVisitMonthly
DROP TABLE IF EXISTS [dwh].[AggVisitMonthly]
GO
CREATE TABLE [dwh].[AggVisitMonthly]
(
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[YearMonth] [varchar](7) NOT NULL,
	[YearNum] [int] NOT NULL,
	[MonthNum] [int] NOT NULL,
	[SKEmployeeID] [bigint] NOT NULL,
	[SKProductID] [bigint] NOT NULL,
	[Specialty] [varchar](100) NULL,
	[ActivityType] [varchar](50) NULL,
	[Region] [varchar](100) NULL,
	[VisitCnt] [bigint] NULL,
	[DoctorCnt] [bigint] NULL,
	[TotalDurationMin] [bigint] NULL,
	[TotalSamplesQty] [bigint] NULL,
	[MonthStartDate] [date] NULL
)
GO
