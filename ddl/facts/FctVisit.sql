/* =====================================================================================
   Table:    [dwh].[FctVisit]
   Type:     Fact - transaction grain (CRM / Salesforce activity).
   Grain:    One row per completed or planned field-force activity (visit / call).
   Measures: DurationMinutes, VisitCount (=1), DetailedProductsCount.
   Refers:   DimDate (SKDateKeyID), DimEmployee (SKEmployeeKeyID),
             DimClientAccount (SKClientAccountKeyID), DimActivityType (SKActivityTypeKeyID).
   ===================================================================================== */

DROP TABLE IF EXISTS [dwh].[FctVisit];
GO

CREATE TABLE [dwh].[FctVisit]
(
    [SKFctVisitID]         [bigint]        NOT NULL,   -- surrogate PK

    -- Dimension foreign keys
    [SKDateKeyID]          [int]           NOT NULL,   -- FK -> [dwh].[DimDate].[SKDateKeyID]
    [SKEmployeeKeyID]      [bigint]        NOT NULL,   -- FK -> [dwh].[DimEmployee].[SKEmployeeKeyID]
    [SKClientAccountKeyID] [bigint]        NOT NULL,   -- FK -> [dwh].[DimClientAccount].[SKClientAccountKeyID]
    [SKActivityTypeKeyID]  [bigint]        NOT NULL,   -- FK -> [dwh].[DimActivityType].[SKActivityTypeKeyID]

    -- Degenerate dimension
    [ActivityId]           [varchar](8000) NULL,       -- Salesforce Activity.Id
    [VisitStatus]          [varchar](8000) NULL,       -- Planned / Completed / Cancelled

    -- Measures
    [VisitCount]           [int]           NOT NULL,    -- always 1 (fact counter)
    [DurationMinutes]      [int]           NULL,
    [DetailedProductsCount][int]           NULL,
    [IsCompleted]          [bit]           NOT NULL,

    -- Audit
    [CreatedBy]            [varchar](128)  NOT NULL,
    [CreatedAt]            [datetime2](3)  NOT NULL
);
GO
