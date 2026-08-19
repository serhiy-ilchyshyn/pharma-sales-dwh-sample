-- ClickUp: PHARMA-SILVER-001
-- Наповнення статичного календаря [dwh].[DimDate].
-- SKDateID = yyyymmdd; окремий рядок -1 = "невідома дата" (для фактів з NULL/битою датою).
-- Фінансовий рік: квітень–березень (як у grp-ctl-azure-dwh).
GO
--IMPORTANT
USE [whsilverad];
--IMPORTANT
GO

TRUNCATE TABLE [dwh].[DimDate];
GO

SET DATEFIRST 1;

INSERT INTO [dwh].[DimDate]
(
      [SKDateID],[CalendarDate],[#DayOfYear],[#DayOfMonth],[#DayOfWeek],[WeekDayName],[WeekDayNameShort]
    , [#WeekOfYear],[#WeekOfMonth],[#Month],[MonthName],[MonthNameShort],[#Quarter],[#Year]
    , [MMYYYY],[MonthYear],[#FiscalYear],[#FiscalQuarter],[#FiscalMonth]
)
VALUES
(-1, '1900-01-01', -1, -1, -1, 'N/A', 'N/A', -1, -1, -1, 'N/A', 'N/A', -1, -1, 'N/A', 'N/A', -1, -1, -1);

WITH Dates AS (
    SELECT DATEADD(DAY, value, CAST('2015-01-01' AS datetime2(3))) AS CalendarDate
    FROM GENERATE_SERIES(
        0,
        DATEDIFF(
            DAY,
            CAST('2015-01-01' AS datetime2(3)),
            DATEADD(YEAR, 10, CAST(SYSDATETIME() AS datetime2(3)))
        )
    )
)
INSERT INTO [dwh].[DimDate]
(
      [SKDateID],[CalendarDate],[#DayOfYear],[#DayOfMonth],[#DayOfWeek],[WeekDayName],[WeekDayNameShort]
    , [#WeekOfYear],[#WeekOfMonth],[#Month],[MonthName],[MonthNameShort],[#Quarter],[#Year]
    , [MMYYYY],[MonthYear],[#FiscalYear],[#FiscalQuarter],[#FiscalMonth]
)
SELECT
      YEAR(CalendarDate) * 10000 + MONTH(CalendarDate) * 100 + DAY(CalendarDate) AS SKDateID
    , CAST(CalendarDate AS date)                       AS CalendarDate
    , DATEPART(DAYOFYEAR, CalendarDate)                AS [#DayOfYear]
    , DAY(CalendarDate)                                AS [#DayOfMonth]
    , DATEPART(WEEKDAY, CalendarDate)                  AS [#DayOfWeek]
    , DATENAME(WEEKDAY, CalendarDate)                  AS [WeekDayName]
    , UPPER(LEFT(DATENAME(WEEKDAY, CalendarDate), 3))  AS [WeekDayNameShort]
    , DATEPART(WEEK, CalendarDate)                     AS [#WeekOfYear]
    , DATEPART(WEEK, CalendarDate) - DATEPART(WEEK, DATEADD(MONTH, DATEDIFF(MONTH, 0, CalendarDate), 0)) + 1 AS [#WeekOfMonth]
    , MONTH(CalendarDate)                              AS [#Month]
    , DATENAME(MONTH, CalendarDate)                    AS [MonthName]
    , UPPER(LEFT(DATENAME(MONTH, CalendarDate), 3))    AS [MonthNameShort]
    , DATEPART(QUARTER, CalendarDate)                  AS [#Quarter]
    , YEAR(CalendarDate)                               AS [#Year]
    , RIGHT('0' + CAST(MONTH(CalendarDate) AS varchar), 2) + '-' + CAST(YEAR(CalendarDate) AS varchar) AS [MMYYYY]
    , UPPER(LEFT(DATENAME(MONTH, CalendarDate), 3)) + '-' + CAST(YEAR(CalendarDate) AS varchar(4))     AS [MonthYear]
    , YEAR(DATEADD(MONTH, -3, CAST(CalendarDate AS date))) AS [#FiscalYear]
    , CASE
          WHEN MONTH(CalendarDate) BETWEEN 4 AND 6   THEN 1
          WHEN MONTH(CalendarDate) BETWEEN 7 AND 9   THEN 2
          WHEN MONTH(CalendarDate) BETWEEN 10 AND 12 THEN 3
          ELSE 4
      END AS [#FiscalQuarter]
    , CASE
          WHEN MONTH(CalendarDate) >= 4 THEN MONTH(CalendarDate) - 3
          ELSE MONTH(CalendarDate) + 9
      END AS [#FiscalMonth]
FROM Dates;
GO
