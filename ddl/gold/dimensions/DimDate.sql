-- whgold.dwh.DimDate
DROP TABLE IF EXISTS [dwh].[DimDate]
GO
CREATE TABLE [dwh].[DimDate]
(
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[SKDateID] [int] NOT NULL,
	[CalendarDate] [date] NOT NULL,
	[DayOfMonth] [int] NOT NULL,
	[MonthNum] [int] NOT NULL,
	[MonthName] [varchar](30) NOT NULL,
	[QuarterNum] [int] NOT NULL,
	[YearNum] [int] NOT NULL,
	[YearMonth] [varchar](7) NOT NULL,
	[FiscalYear] [int] NOT NULL,
	[FiscalQuarter] [int] NOT NULL
)
GO
