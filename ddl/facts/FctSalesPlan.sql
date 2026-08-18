/* =====================================================================================
   Table:    [dwh].[FctSalesPlan]
   Type:     Fact - periodic (monthly) target grain.
   Grain:    One row per employee x product x month (planning period).
   Measures: PlannedUnits, PlannedAmount (additive within a period).
   Refers:   DimDate (SKDateKeyID = first day of period), DimEmployee (SKEmployeeKeyID),
             DimProduct (SKProductKeyID).
   ===================================================================================== */

DROP TABLE IF EXISTS [dwh].[FctSalesPlan];
GO

CREATE TABLE [dwh].[FctSalesPlan]
(
    [SKFctSalesPlanID] [bigint]        NOT NULL,   -- surrogate PK

    -- Dimension foreign keys
    [SKDateKeyID]      [int]           NOT NULL,   -- FK -> [dwh].[DimDate].[SKDateKeyID]
    [SKEmployeeKeyID]  [bigint]        NOT NULL,   -- FK -> [dwh].[DimEmployee].[SKEmployeeKeyID]
    [SKProductKeyID]   [bigint]        NOT NULL,   -- FK -> [dwh].[DimProduct].[SKProductKeyID]

    -- Degenerate dimension
    [Period]           [date]          NOT NULL,   -- first day of the plan month
    [PlanVersion]      [varchar](8000) NULL,

    -- Measures
    [PlannedUnits]     [int]           NOT NULL,
    [PlannedAmount]    [decimal](18,2) NOT NULL,
    [Currency]         [varchar](8000) NULL,

    -- Audit
    [CreatedBy]        [varchar](128)  NOT NULL,
    [CreatedAt]        [datetime2](3)  NOT NULL
);
GO
