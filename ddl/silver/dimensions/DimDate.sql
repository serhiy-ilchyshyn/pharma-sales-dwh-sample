-- whsilver.dwh.DimDate
DROP TABLE IF EXISTS [dwh].[DimDate]
GO
CREATE TABLE [dwh].[DimDate]
(
	[SKDateID] [int] NOT NULL,
	[CalendarDate] [date] NOT NULL,
	[#DayOfYear] [int] NOT NULL,
	[#DayOfMonth] [int] NOT NULL,
	[#DayOfWeek] [int] NOT NULL,
	[WeekDayName] [varchar](30) NOT NULL,
	[WeekDayNameShort] [varchar](30) NOT NULL,
	[#WeekOfYear] [int] NOT NULL,
	[#WeekOfMonth] [int] NOT NULL,
	[#Month] [int] NOT NULL,
	[MonthName] [varchar](30) NOT NULL,
	[MonthNameShort] [varchar](30) NOT NULL,
	[#Quarter] [int] NOT NULL,
	[#Year] [int] NOT NULL,
	[MMYYYY] [varchar](30) NOT NULL,
	[MonthYear] [varchar](30) NULL,
	[#FiscalYear] [int] NOT NULL,
	[#FiscalQuarter] [int] NOT NULL,
	[#FiscalMonth] [int] NOT NULL
)
GO
