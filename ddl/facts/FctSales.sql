/* =====================================================================================
   Table:    [dwh].[FctSales]
   Type:     Fact - transaction grain.
   Grain:    One row per sales line (day x employee x client x product x invoice line).
   Measures: QuantityUnits, GrossAmount, DiscountAmount, NetAmount (additive).
   Refers:   DimDate (SKDateKeyID), DimEmployee (SKEmployeeKeyID),
             DimClientAccount (SKClientAccountKeyID), DimProduct (SKProductKeyID).
   ===================================================================================== */

DROP TABLE IF EXISTS [dwh].[FctSales];
GO

CREATE TABLE [dwh].[FctSales]
(
    [SKFctSalesID]         [bigint]        NOT NULL,   -- surrogate PK

    -- Dimension foreign keys (durable keys)
    [SKDateKeyID]          [int]           NOT NULL,   -- FK -> [dwh].[DimDate].[SKDateKeyID]
    [SKEmployeeKeyID]      [bigint]        NOT NULL,   -- FK -> [dwh].[DimEmployee].[SKEmployeeKeyID]
    [SKClientAccountKeyID] [bigint]        NOT NULL,   -- FK -> [dwh].[DimClientAccount].[SKClientAccountKeyID]
    [SKProductKeyID]       [bigint]        NOT NULL,   -- FK -> [dwh].[DimProduct].[SKProductKeyID]

    -- Degenerate dimension
    [InvoiceNumber]        [varchar](8000) NULL,
    [SalesChannel]         [varchar](8000) NULL,       -- Direct / Distributor / Pharmacy

    -- Measures
    [QuantityUnits]        [int]           NOT NULL,
    [GrossAmount]          [decimal](18,2) NOT NULL,
    [DiscountAmount]       [decimal](18,2) NOT NULL,
    [NetAmount]            [decimal](18,2) NOT NULL,
    [Currency]             [varchar](8000) NULL,

    -- Audit
    [CreatedBy]            [varchar](128)  NOT NULL,
    [CreatedAt]            [datetime2](3)  NOT NULL
);
GO
