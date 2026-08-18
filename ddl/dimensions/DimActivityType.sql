/* =====================================================================================
   Table:    [dwh].[DimActivityType]
   Type:     Dimension, SCD Type 2 (historised via StartDate / EndDate).
   Grain:    One row per version of a CRM activity / visit type.
   Keys:     SKActivityTypeID    - surrogate PK, one per row version.
             SKActivityTypeKeyID - durable key referenced by facts.
             Id                  - Salesforce RecordType.Id natural business key.
   Note:     SKActivityTypeKeyID = -1 is the "Unknown / N/A" member.
   ===================================================================================== */

DROP TABLE IF EXISTS [dwh].[DimActivityType];
GO

CREATE TABLE [dwh].[DimActivityType]
(
    [SKActivityTypeID]    [bigint]       NOT NULL,
    [SKActivityTypeKeyID] [bigint]       NOT NULL,
    [StartDate]           [datetime2](3) NULL,
    [EndDate]             [datetime2](3) NULL,
    [IsDeleted]           [bit]          NULL,
    [CreatedBy]           [varchar](128) NOT NULL,
    [ModifiedBy]          [varchar](128) NULL,
    [CreatedAt]           [datetime2](3) NOT NULL,
    [ModifiedAt]          [datetime2](3) NULL,
    [Id]                  [varchar](8000) NOT NULL,  -- Salesforce RecordType.Id
    [Name]                [varchar](8000) NOT NULL,  -- e.g. 1:1 Visit, Office Visit, Pharmacy Visit
    [Category]            [varchar](8000) NULL,      -- Visit / Call / Event
    [Channel]             [varchar](8000) NULL,      -- F2F / Remote / Phone
    [SegmentType]         [varchar](8000) NULL,      -- Contact / Account
    [IsActive]            [bit]          NULL
);
GO

INSERT INTO [dwh].[DimActivityType]
    (SKActivityTypeID, SKActivityTypeKeyID, StartDate, EndDate, IsDeleted, CreatedBy,
     ModifiedBy, CreatedAt, ModifiedAt, Id, Name, Category, Channel, SegmentType, IsActive)
VALUES
    (-1, -1, '2000-01-01 00:00:00.000', NULL, 0, 'init_insert', NULL,
     '2000-01-01 00:00:00.000', NULL, 'N/A', 'N/A', 'N/A', 'N/A', 'N/A', 0);
GO
