-- ClickUp: PHARMA-SILVER-003
-- Metadata-driven оркестрація silver-завантаження.
--
--   [dwh].[EtlSilverObject]   — реєстр об'єктів: тип, рівень завантаження, SCD-тип, к-сть проходів
--   [dwh].[EtlSilverLoadLog]  — журнал запусків (об'єкт, тривалість, к-сть рядків, статус, помилка)
--   [dwh].[spSilverLoadLevel] — завантажує всі об'єкти одного рівня (виклик з Data Pipeline)
--   [dwh].[spSilverFullLoad]  — проходить рівні 1..MAX (перевизначає версію з V260819.1050,
--                               яка мала жорстко зашитий список об'єктів)
--
-- Рівень = позиція в топологічному сортуванні графа залежностей (docs/silver_dependencies.md).
-- Новий вимір -> рядок у [dwh].[EtlSilverObject], pipeline змінювати не треба.
GO
--IMPORTANT
USE [whsilver];
--IMPORTANT
GO

DROP TABLE IF EXISTS [whsilver].[dwh].[EtlSilverObject]
GO
CREATE TABLE [whsilver].[dwh].[EtlSilverObject]
(
	[ObjectName] [varchar](128) NOT NULL,
	[ObjectType] [varchar](10) NOT NULL,   -- Dim / Ref / Fct
	[LoadLevel] [int] NOT NULL,            -- рівень топологічного сортування (1..N)
	[ScdType] [varchar](10) NULL,          -- SCD1 / SCD2 для Dim і Ref; NULL для Fct
	[PassCnt] [smallint] NOT NULL,         -- к-сть проходів (2 для self-reference DimEmployee)
	[IsActive] [bit] NOT NULL
)
GO

INSERT INTO [whsilver].[dwh].[EtlSilverObject]
	([ObjectName],[ObjectType],[LoadLevel],[ScdType],[PassCnt],[IsActive])
VALUES
	('DimActivityType', 'Dim', 1, 'SCD2', 1, 1),
	('DimAeOutcome', 'Dim', 1, 'SCD2', 1, 1),
	('DimAeSeriousness', 'Dim', 1, 'SCD2', 1, 1),
	('DimChain', 'Dim', 1, 'SCD2', 1, 1),
	('DimLegalEntity', 'Dim', 1, 'SCD2', 1, 1),
	('DimManufacturer', 'Dim', 1, 'SCD2', 1, 1),
	('DimRegion', 'Dim', 1, 'SCD2', 1, 1),
	('DimReportSource', 'Dim', 1, 'SCD2', 1, 1),
	('DimSpecialty', 'Dim', 1, 'SCD2', 1, 1),
	('DimTerritory', 'Dim', 1, 'SCD2', 1, 1),
	('RefMovementType', 'Ref', 1, 'SCD2', 1, 1),
	('DimCity', 'Dim', 2, 'SCD2', 1, 1),
	('DimEmployee', 'Dim', 2, 'SCD2', 2, 1),
	('DimProduct', 'Dim', 2, 'SCD2', 1, 1),
	('DimClientAccount', 'Dim', 3, 'SCD2', 1, 1),
	('DimLpu', 'Dim', 3, 'SCD2', 1, 1),
	('RefEmployee', 'Ref', 3, 'SCD2', 1, 1),
	('RefProduct', 'Ref', 3, 'SCD2', 1, 1),
	('DimDoctor', 'Dim', 4, 'SCD2', 1, 1),
	('RefClientAccount', 'Ref', 4, 'SCD2', 1, 1),
	('DimWarehouse', 'Dim', 5, 'SCD2', 1, 1),
	('RefDoctor', 'Ref', 5, 'SCD2', 1, 1),
	('FctAdverseEvent', 'Fct', 6, NULL, 1, 1),
	('FctPrescription', 'Fct', 6, NULL, 1, 1),
	('FctVisit', 'Fct', 6, NULL, 1, 1),
	('RefWarehouse', 'Ref', 6, 'SCD2', 1, 1),
	('FctInventoryMovement', 'Fct', 7, NULL, 1, 1),
	('FctSales', 'Fct', 7, NULL, 1, 1)
GO

-- Журнал не перестворюємо: історія запусків має пережити повторний прогін міграції
IF OBJECT_ID('dwh.EtlSilverLoadLog', 'U') IS NULL
    EXEC('
    CREATE TABLE [whsilver].[dwh].[EtlSilverLoadLog]
    (
        [LoadId] [varchar](250) NOT NULL,
        [ObjectName] [varchar](128) NOT NULL,
        [ObjectType] [varchar](10) NOT NULL,
        [LoadLevel] [int] NOT NULL,
        [StartedAt] [datetime2](3) NOT NULL,
        [FinishedAt] [datetime2](3) NULL,
        [DurationSec] [decimal](18,3) NULL,
        [RowCnt] [bigint] NULL,
        [Status] [varchar](20) NOT NULL,
        [ErrorMessage] [varchar](8000) NULL
    )');
GO

CREATE OR ALTER PROCEDURE [dwh].[spSilverLoadLevel]
    @level INT,
    @load_id NVARCHAR(250) = 'manual_load'
AS
BEGIN
    SET NOCOUNT ON;

    DROP TABLE IF EXISTS #level_objects;

    -- Курсори у Fabric Warehouse не підтримуються -> цикл по пронумерованій тимчасовій таблиці
    SELECT
          ROW_NUMBER() OVER (ORDER BY
              CASE o.ObjectType WHEN 'Dim' THEN 1 WHEN 'Ref' THEN 2 ELSE 3 END,
              o.ObjectName) AS rn
        , o.ObjectName
        , o.ObjectType
        , o.ScdType
        , o.PassCnt
    INTO #level_objects
    FROM [dwh].[EtlSilverObject] AS o
    WHERE o.LoadLevel = @level
      AND o.IsActive = 1;

    DECLARE @cnt INT = (SELECT COUNT(1) FROM #level_objects);
    DECLARE @i INT = 1;

    DECLARE @obj VARCHAR(128), @type VARCHAR(10), @scd VARCHAR(10), @pass SMALLINT, @p SMALLINT;
    DECLARE @started DATETIME2(3), @finished DATETIME2(3), @rowcnt BIGINT, @sql NVARCHAR(MAX);

    PRINT CONCAT('[spSilverLoadLevel] level=', @level, ', objects=', @cnt, ', load_id=', @load_id);

    WHILE @i <= @cnt
    BEGIN
        SELECT
              @obj  = ObjectName
            , @type = ObjectType
            , @scd  = ScdType
            , @pass = PassCnt
        FROM #level_objects
        WHERE rn = @i;

        SET @started = SYSUTCDATETIME();
        SET @rowcnt = NULL;

        BEGIN TRY
            SET @p = 1;

            -- PassCnt > 1 для вимірів із self-reference: другий прохід резолвить власні ключі
            WHILE @p <= @pass
            BEGIN
                IF @type = 'Fct'
                    EXEC [dwh].[spFullFct] @fct_table_name = @obj, @load_id = @load_id;
                ELSE
                    EXEC [dwh].[spUpsertSCDDimension] @dim_table_name = @obj, @scd_type = @scd;

                SET @p = @p + 1;
            END

            SET @sql = N'SELECT @c = COUNT(1) FROM [dwh].' + QUOTENAME(@obj) + N';';
            EXEC sp_executesql @sql, N'@c BIGINT OUTPUT', @c = @rowcnt OUTPUT;

            SET @finished = SYSUTCDATETIME();

            INSERT INTO [dwh].[EtlSilverLoadLog]
                ([LoadId],[ObjectName],[ObjectType],[LoadLevel],[StartedAt],[FinishedAt],[DurationSec],[RowCnt],[Status],[ErrorMessage])
            VALUES
                (@load_id, @obj, @type, @level, @started, @finished,
                 DATEDIFF(MILLISECOND, @started, @finished) / 1000.0, @rowcnt, 'Success', NULL);
        END TRY
        BEGIN CATCH
            SET @finished = SYSUTCDATETIME();

            INSERT INTO [dwh].[EtlSilverLoadLog]
                ([LoadId],[ObjectName],[ObjectType],[LoadLevel],[StartedAt],[FinishedAt],[DurationSec],[RowCnt],[Status],[ErrorMessage])
            VALUES
                (@load_id, @obj, @type, @level, @started, @finished,
                 DATEDIFF(MILLISECOND, @started, @finished) / 1000.0, NULL, 'Failed', LEFT(ERROR_MESSAGE(), 8000));

            -- рівень падає цілком -> pipeline бачить помилку і не йде далі
            THROW;
        END CATCH

        SET @i = @i + 1;
    END
END
GO

CREATE OR ALTER PROCEDURE [dwh].[spSilverFullLoad]
    @load_id NVARCHAR(250) = 'manual_full_load'
AS
BEGIN
    SET NOCOUNT ON;

    -- Послідовність рівнів і склад кожного з них беруться з [dwh].[EtlSilverObject]
    DECLARE @lvl INT = 1;
    DECLARE @max_lvl INT = (SELECT MAX(LoadLevel) FROM [dwh].[EtlSilverObject] WHERE IsActive = 1);

    WHILE @lvl <= @max_lvl
    BEGIN
        EXEC [dwh].[spSilverLoadLevel] @level = @lvl, @load_id = @load_id;
        SET @lvl = @lvl + 1;
    END
END
GO
