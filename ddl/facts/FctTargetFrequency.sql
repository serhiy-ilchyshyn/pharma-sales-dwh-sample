/* =====================================================================================
   Table:    [dwh].[FctTargetFrequency]
   Type:     Fact - periodic (monthly) target grain. Pharma "IPPA plan" analogue.
   Grain:    One row per employee x client x activity type x period (planned call plan).
   Measures: QuantityVisitsPlanned (target visit frequency for the period).
   Refers:   DimDate (SKDateKeyID = period), DimEmployee (SKEmployeeKeyID),
             DimClientAccount (SKClientAccountKeyID), DimActivityType (SKActivityTypeKeyID).
   ===================================================================================== */

DROP TABLE IF EXISTS [dwh].[FctTargetFrequency];
GO

CREATE TABLE [dwh].[FctTargetFrequency]
(
    [SKFctTargetFrequencyID] [bigint]        NOT NULL,   -- surrogate PK

    -- Dimension foreign keys
    [SKDateKeyID]            [int]           NOT NULL,    -- FK -> [dwh].[DimDate].[SKDateKeyID]
    [SKEmployeeKeyID]        [bigint]        NOT NULL,    -- FK -> [dwh].[DimEmployee].[SKEmployeeKeyID]
    [SKClientAccountKeyID]   [bigint]        NOT NULL,    -- FK -> [dwh].[DimClientAccount].[SKClientAccountKeyID]
    [SKActivityTypeKeyID]    [bigint]        NOT NULL,    -- FK -> [dwh].[DimActivityType].[SKActivityTypeKeyID]

    -- Degenerate dimension
    [Period]                 [date]          NOT NULL,    -- first day of the plan month
    [TargetFrequencyStatus]  [varchar](8000) NULL,        -- Active / Draft / Closed
    [SegmentType]            [varchar](8000) NULL,        -- Contact / Account

    -- Measures
    [QuantityVisitsPlanned]  [int]           NOT NULL,

    -- Audit
    [CreatedBy]              [varchar](128)  NOT NULL,
    [CreatedAt]              [datetime2](3)  NOT NULL
);
GO
