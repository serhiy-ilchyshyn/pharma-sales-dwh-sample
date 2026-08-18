/* =====================================================================================
   Table:    [dwh].[DimClientAccount]
   Type:     Dimension, SCD Type 2 (historised via StartDate / EndDate).
   Grain:    One row per version of a client account (HCP, pharmacy, hospital, distributor).
   Keys:     SKClientAccountID    - surrogate PK, one per row version.
             SKClientAccountKeyID - durable key referenced by facts.
             Id                   - Salesforce Account.Id natural business key.
   Note:     SKClientAccountKeyID = -1 is the "Unknown / N/A" member.
   ===================================================================================== */

DROP TABLE IF EXISTS [dwh].[DimClientAccount];
GO

CREATE TABLE [dwh].[DimClientAccount]
(
    [SKClientAccountID]    [bigint]       NOT NULL,
    [SKClientAccountKeyID] [bigint]       NOT NULL,
    [StartDate]            [datetime2](3) NULL,
    [EndDate]              [datetime2](3) NULL,
    [IsDeleted]            [bit]          NULL,
    [CreatedBy]            [varchar](128) NOT NULL,
    [ModifiedBy]           [varchar](128) NULL,
    [CreatedAt]            [datetime2](3) NOT NULL,
    [ModifiedAt]           [datetime2](3) NULL,
    [Id]                   [varchar](8000) NOT NULL,  -- Salesforce Account.Id
    [Name]                 [varchar](8000) NULL,
    [AccountType]          [varchar](8000) NULL,      -- HCP / Pharmacy / Hospital / Distributor
    [RecordType]           [varchar](8000) NULL,
    [Specialty]            [varchar](8000) NULL,       -- for HCPs
    [Category]             [varchar](8000) NULL,       -- potential/segment (A / B / C)
    [Address]             [varchar](8000) NULL,
    [City]                 [varchar](8000) NULL,
    [RegionName]           [varchar](8000) NULL,
    [CountryName]          [varchar](8000) NULL,
    [PostalCode]           [varchar](8000) NULL,
    [IsActive]             [bit]          NULL
);
GO

INSERT INTO [dwh].[DimClientAccount]
    (SKClientAccountID, SKClientAccountKeyID, StartDate, EndDate, IsDeleted, CreatedBy,
     ModifiedBy, CreatedAt, ModifiedAt, Id, Name, AccountType, RecordType, Specialty,
     Category, Address, City, RegionName, CountryName, PostalCode, IsActive)
VALUES
    (-1, -1, '2000-01-01 00:00:00.000', NULL, 0, 'init_insert', NULL,
     '2000-01-01 00:00:00.000', NULL, 'N/A', 'N/A', 'N/A', 'N/A', 'N/A', 'N/A', 'N/A',
     'N/A', 'N/A', 'N/A', 'N/A', 0);
GO
