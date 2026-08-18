/* =====================================================================================
   Table:    [dwh].[FctInventorySnapshot]
   Type:     Fact - periodic snapshot grain.
   Grain:    One row per client account x product x snapshot day (e.g. pharmacy stock).
   Measures: QuantityOnHand & StockValue (semi-additive - do NOT sum across dates),
             QuantitySold & QuantityReceived (additive within the period).
   Refers:   DimDate (SKDateKeyID), DimClientAccount (SKClientAccountKeyID),
             DimProduct (SKProductKeyID).
   ===================================================================================== */

DROP TABLE IF EXISTS [dwh].[FctInventorySnapshot];
GO

CREATE TABLE [dwh].[FctInventorySnapshot]
(
    [SKFctInventorySnapshotID] [bigint]        NOT NULL,   -- surrogate PK

    -- Dimension foreign keys
    [SKDateKeyID]              [int]           NOT NULL,    -- FK -> [dwh].[DimDate].[SKDateKeyID]
    [SKClientAccountKeyID]     [bigint]        NOT NULL,    -- FK -> [dwh].[DimClientAccount].[SKClientAccountKeyID]
    [SKProductKeyID]           [bigint]        NOT NULL,    -- FK -> [dwh].[DimProduct].[SKProductKeyID]

    -- Measures
    [QuantityOnHand]           [int]           NOT NULL,    -- semi-additive
    [QuantityReceived]         [int]           NOT NULL,    -- additive within period
    [QuantitySold]             [int]           NOT NULL,    -- additive within period
    [StockValue]               [decimal](18,2) NOT NULL,    -- semi-additive
    [Currency]                 [varchar](8000) NULL,

    -- Audit
    [CreatedBy]                [varchar](128)  NOT NULL,
    [CreatedAt]                [datetime2](3)  NOT NULL
);
GO
