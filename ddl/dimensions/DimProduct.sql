/* =====================================================================================
   Table:    [dwh].[DimProduct]
   Type:     Dimension, SCD Type 2 (historised via StartDate / EndDate).
   Grain:    One row per version of a promotable / sellable product (SKU).
   Keys:     SKProductID    - surrogate PK, one per row version.
             SKProductKeyID - durable key referenced by facts.
             Id             - Salesforce Product2.Id natural business key.
   Note:     SKProductKeyID = -1 is the "Unknown / N/A" member.
   ===================================================================================== */

DROP TABLE IF EXISTS [dwh].[DimProduct];
GO

CREATE TABLE [dwh].[DimProduct]
(
    [SKProductID]     [bigint]       NOT NULL,
    [SKProductKeyID]  [bigint]       NOT NULL,
    [StartDate]       [datetime2](3) NULL,
    [EndDate]         [datetime2](3) NULL,
    [IsDeleted]       [bit]          NULL,
    [CreatedBy]       [varchar](128) NOT NULL,
    [ModifiedBy]      [varchar](128) NULL,
    [CreatedAt]       [datetime2](3) NOT NULL,
    [ModifiedAt]      [datetime2](3) NULL,
    [Id]              [varchar](8000) NOT NULL,  -- Salesforce Product2.Id
    [Name]            [varchar](8000) NOT NULL,
    [Brand]           [varchar](8000) NULL,
    [ProductCategory] [varchar](8000) NULL,      -- Rx / OTC / FMCG
    [TherapeuticArea] [varchar](8000) NULL,
    [ATCCode]         [varchar](8000) NULL,
    [PackSize]        [varchar](8000) NULL,
    [UnitPrice]       [decimal](18,2) NULL,
    [Currency]        [varchar](8000) NULL,
    [IsActive]        [bit]          NULL,
    [ExternalId]      [varchar](8000) NOT NULL
);
GO

INSERT INTO [dwh].[DimProduct]
    (SKProductID, SKProductKeyID, StartDate, EndDate, IsDeleted, CreatedBy, ModifiedBy,
     CreatedAt, ModifiedAt, Id, Name, Brand, ProductCategory, TherapeuticArea, ATCCode,
     PackSize, UnitPrice, Currency, IsActive, ExternalId)
VALUES
    (-1, -1, '2000-01-01 00:00:00.000', NULL, 0, 'init_insert', NULL,
     '2000-01-01 00:00:00.000', NULL, 'N/A', 'N/A', 'N/A', 'N/A', 'N/A', 'N/A', 'N/A',
     0.00, 'N/A', 0, 'N/A');
GO
