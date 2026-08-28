-- whgold.dwh.AggPrescriptionMonthly
DROP TABLE IF EXISTS [dwh].[AggPrescriptionMonthly]
GO
CREATE TABLE [dwh].[AggPrescriptionMonthly]
(
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[YearMonth] [varchar](7) NOT NULL,
	[YearNum] [int] NOT NULL,
	[MonthNum] [int] NOT NULL,
	[SKProductID] [bigint] NOT NULL,
	[Specialty] [varchar](100) NULL,
	[Region] [varchar](100) NULL,
	[DoctorCnt] [bigint] NULL,
	[TotalPatientsCnt] [bigint] NULL,
	[TotalPrescriptionsCnt] [bigint] NULL,
	[MonthStartDate] [date] NULL
)
GO
