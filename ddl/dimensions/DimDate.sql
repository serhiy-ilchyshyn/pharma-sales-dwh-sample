/* =====================================================================================
   Table:    [dwh].[DimDate]
   Type:     Dimension (static calendar, no SCD)
   Grain:    One row per calendar day.
   Key:      SKDateKeyID (int, format yyyymmdd) is the durable key referenced by all facts.
   Note:     Row SKDateKeyID = -1 is the "Unknown / N/A" member used for orphan fact rows.
   ===================================================================================== */

DROP TABLE IF EXISTS [dwh].[DimDate];
GO

CREATE TABLE [dwh].[DimDate]
(
    [SKDateID]      [int]          NOT NULL,   -- surrogate key (yyyymmdd)
    [SKDateKeyID]   [int]          NOT NULL,   -- durable business key (yyyymmdd), referenced by facts
    [DateValue]     [date]         NULL,
    [DayOfMonth]    [int]          NULL,
    [DayOfWeek]     [int]          NULL,       -- 1 = Monday .. 7 = Sunday
    [DayName]       [varchar](20)  NULL,
    [WeekOfYear]    [int]          NULL,
    [MonthNumber]   [int]          NULL,
    [MonthName]     [varchar](20)  NULL,
    [Quarter]       [int]          NULL,
    [Year]          [int]          NULL,
    [YearMonth]     [int]          NULL,       -- yyyymm
    [IsWeekend]     [bit]          NULL,
    [CreatedBy]     [varchar](128) NOT NULL,
    [CreatedAt]     [datetime2](3) NOT NULL
);
GO

-- Unknown / N/A member
INSERT INTO [dwh].[DimDate]
    (SKDateID, SKDateKeyID, DateValue, DayOfMonth, DayOfWeek, DayName, WeekOfYear,
     MonthNumber, MonthName, Quarter, Year, YearMonth, IsWeekend, CreatedBy, CreatedAt)
VALUES
    (-1, -1, NULL, NULL, NULL, 'N/A', NULL, NULL, 'N/A', NULL, NULL, NULL, NULL,
     'init_insert', '2000-01-01 00:00:00.000');
GO
