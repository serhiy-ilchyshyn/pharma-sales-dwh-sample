/* =====================================================================================
   Table:    [dwh].[DimEmployee]
   Type:     Dimension, SCD Type 2 (historised via StartDate / EndDate).
   Grain:    One row per version of a sales employee (medical / sales representative).
   Keys:     SKEmployeeID    - surrogate PK, one per row version.
             SKEmployeeKeyID - durable key, stable across versions, referenced by facts.
             Id              - Salesforce natural business key (User.Id).
   Note:     SKEmployeeKeyID = -1 is the "Unknown / N/A" member.
   ===================================================================================== */

DROP TABLE IF EXISTS [dwh].[DimEmployee];
GO

CREATE TABLE [dwh].[DimEmployee]
(
    [SKEmployeeID]    [bigint]       NOT NULL,
    [SKEmployeeKeyID] [bigint]       NOT NULL,
    [StartDate]       [datetime2](3) NULL,      -- SCD2 valid-from
    [EndDate]         [datetime2](3) NULL,      -- SCD2 valid-to (NULL = current)
    [IsDeleted]       [bit]          NULL,
    [CreatedBy]       [varchar](128) NOT NULL,
    [ModifiedBy]      [varchar](128) NULL,
    [CreatedAt]       [datetime2](3) NOT NULL,
    [ModifiedAt]      [datetime2](3) NULL,
    [Id]              [varchar](8000) NOT NULL, -- Salesforce User.Id
    [Name]            [varchar](8000) NULL,
    [FirstName]       [varchar](8000) NULL,
    [LastName]        [varchar](8000) NULL,
    [Email]           [varchar](8000) NULL,
    [MobilePhone]     [varchar](8000) NULL,
    [ProfileName]     [varchar](8000) NULL,     -- role profile (e.g. Medical Rep, District Manager)
    [ManagerId]       [varchar](8000) NULL,
    [Direction]       [varchar](8000) NULL,     -- business direction / franchise
    [Division]        [varchar](8000) NULL,
    [Territory]       [varchar](8000) NULL,
    [RegionName]      [varchar](8000) NULL,
    [CountryName]     [varchar](8000) NULL,
    [IsActive]        [bit]          NULL
);
GO

INSERT INTO [dwh].[DimEmployee]
    (SKEmployeeID, SKEmployeeKeyID, StartDate, EndDate, IsDeleted, CreatedBy, ModifiedBy,
     CreatedAt, ModifiedAt, Id, Name, FirstName, LastName, Email, MobilePhone, ProfileName,
     ManagerId, Direction, Division, Territory, RegionName, CountryName, IsActive)
VALUES
    (-1, -1, '2000-01-01 00:00:00.000', NULL, 0, 'init_insert', NULL,
     '2000-01-01 00:00:00.000', NULL, 'N/A', 'N/A', 'N/A', 'N/A', 'N/A', 'N/A', 'N/A',
     'N/A', 'N/A', 'N/A', 'N/A', 'N/A', 'N/A', 0);
GO
