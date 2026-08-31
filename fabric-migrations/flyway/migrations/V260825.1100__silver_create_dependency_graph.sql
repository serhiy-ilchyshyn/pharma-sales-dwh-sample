-- ClickUp: PHARMA-SILVER-004
-- Перезавантаження за залежностями: "перевантажити одне джерело -> перевантажити все,
-- що з нього походить".
--
--   [dwh].[EtlObjectDependency]  — граф залежностей (обʼєкт -> від чого залежить),
--                                  імена кваліфіковані: dwh.X або lhbronze.erp_erp.X
--   [dwh].[EtlObjectDownstream]  — матеріалізоване транзитивне замикання
--                                  (корінь -> усі silver-обʼєкти, які треба перевантажити)
--   [dwh].[spRefreshObjectClosure] — перераховує замикання (WHILE-фікспойнт:
--                                  рекурсивні CTE у Fabric Warehouse не підтримуються)
--   [dwh].[spSilverLoadSubset]   — вантажить лише замикання заданого кореня, по рівнях
--   [dwh].[spSilverLoadLevel]    — доданий параметр @root_object (NULL = весь рівень)
--   [dwh].[spSilverFullLoad]     — тепер обгортка над spSilverLoadSubset з @root_object = NULL
--
-- Граф згенеровано з визначень view (V260819.1020) — та сама таблиця, що в
-- docs/silver_dependencies.md. Після зміни view/появи обʼєкта: оновити рядки в
-- EtlObjectDependency і виконати EXEC [dwh].[spRefreshObjectClosure].
GO
--IMPORTANT
USE [whsilver];
--IMPORTANT
GO

DROP TABLE IF EXISTS [whsilver].[dwh].[EtlObjectDependency]
GO
CREATE TABLE [whsilver].[dwh].[EtlObjectDependency]
(
	[ObjectName] [varchar](256) NOT NULL,        -- dwh.<SilverTable>
	[DependsOnObject] [varchar](256) NOT NULL    -- dwh.<SilverTable> | lhbronze.<schema>.<table>
)
GO

INSERT INTO [whsilver].[dwh].[EtlObjectDependency] ([ObjectName],[DependsOnObject])
VALUES
	('dwh.DimActivityType', 'lhbronze.erp_erp.DOCTOR_VISITS'),
	('dwh.DimAeOutcome', 'lhbronze.erp_erp.ADVERSE_EVENTS'),
	('dwh.DimAeSeriousness', 'lhbronze.erp_erp.ADVERSE_EVENTS'),
	('dwh.DimChain', 'lhbronze.erp_erp.CUSTOMERS'),
	('dwh.DimCity', 'dwh.DimRegion'),
	('dwh.DimCity', 'lhbronze.erp_erp.CUSTOMERS'),
	('dwh.DimCity', 'lhbronze.erp_erp.DOCTORS'),
	('dwh.DimCity', 'lhbronze.erp_erp.WAREHOUSES'),
	('dwh.DimClientAccount', 'dwh.DimChain'),
	('dwh.DimClientAccount', 'dwh.DimCity'),
	('dwh.DimClientAccount', 'dwh.DimLegalEntity'),
	('dwh.DimClientAccount', 'dwh.DimRegion'),
	('dwh.DimClientAccount', 'lhbronze.erp_erp.CUSTOMERS'),
	('dwh.DimDoctor', 'dwh.DimCity'),
	('dwh.DimDoctor', 'dwh.DimLpu'),
	('dwh.DimDoctor', 'dwh.DimRegion'),
	('dwh.DimDoctor', 'dwh.DimSpecialty'),
	('dwh.DimDoctor', 'lhbronze.erp_erp.DOCTORS'),
	('dwh.DimEmployee', 'dwh.DimTerritory'),
	('dwh.DimEmployee', 'lhbronze.erp_erp.EMPLOYEES'),
	('dwh.DimLegalEntity', 'lhbronze.erp_erp.CUSTOMERS'),
	('dwh.DimLpu', 'dwh.DimCity'),
	('dwh.DimLpu', 'dwh.DimRegion'),
	('dwh.DimLpu', 'lhbronze.erp_erp.DOCTORS'),
	('dwh.DimManufacturer', 'lhbronze.erp_erp.PRODUCTS'),
	('dwh.DimProduct', 'dwh.DimAtcClass'),
	('dwh.DimProduct', 'dwh.DimManufacturer'),
	('dwh.DimProduct', 'lhbronze.erp_erp.PRODUCTS'),
	('dwh.DimRegion', 'lhbronze.erp_erp.ADVERSE_EVENTS'),
	('dwh.DimRegion', 'lhbronze.erp_erp.CUSTOMERS'),
	('dwh.DimRegion', 'lhbronze.erp_erp.DOCTORS'),
	('dwh.DimRegion', 'lhbronze.erp_erp.WAREHOUSES'),
	('dwh.DimReportSource', 'lhbronze.erp_erp.ADVERSE_EVENTS'),
	('dwh.DimSpecialty', 'lhbronze.erp_erp.DOCTORS'),
	('dwh.DimTerritory', 'lhbronze.erp_erp.EMPLOYEES'),
	('dwh.DimWarehouse', 'dwh.DimCity'),
	('dwh.DimWarehouse', 'dwh.DimRegion'),
	('dwh.DimWarehouse', 'dwh.RefClientAccount'),
	('dwh.DimWarehouse', 'lhbronze.erp_erp.WAREHOUSES'),
	('dwh.FctAdverseEvent', 'dwh.DimAeOutcome'),
	('dwh.FctAdverseEvent', 'dwh.DimAeSeriousness'),
	('dwh.FctAdverseEvent', 'dwh.DimDate'),
	('dwh.FctAdverseEvent', 'dwh.DimRegion'),
	('dwh.FctAdverseEvent', 'dwh.DimReportSource'),
	('dwh.FctAdverseEvent', 'dwh.DimSrcSystem'),
	('dwh.FctAdverseEvent', 'dwh.RefDoctor'),
	('dwh.FctAdverseEvent', 'dwh.RefProduct'),
	('dwh.FctAdverseEvent', 'lhbronze.erp_erp.ADVERSE_EVENTS'),
	('dwh.FctInventoryMovement', 'dwh.DimDate'),
	('dwh.FctInventoryMovement', 'dwh.DimMovementType'),
	('dwh.FctInventoryMovement', 'dwh.DimSrcSystem'),
	('dwh.FctInventoryMovement', 'dwh.RefEmployee'),
	('dwh.FctInventoryMovement', 'dwh.RefMovementType'),
	('dwh.FctInventoryMovement', 'dwh.RefProduct'),
	('dwh.FctInventoryMovement', 'dwh.RefWarehouse'),
	('dwh.FctInventoryMovement', 'lhbronze.erp_erp.INVENTORY_MOVEMENTS'),
	('dwh.FctPrescription', 'dwh.DimDate'),
	('dwh.FctPrescription', 'dwh.DimSrcSystem'),
	('dwh.FctPrescription', 'dwh.RefDoctor'),
	('dwh.FctPrescription', 'dwh.RefEmployee'),
	('dwh.FctPrescription', 'dwh.RefProduct'),
	('dwh.FctPrescription', 'lhbronze.erp_erp.PRESCRIPTIONS'),
	('dwh.FctSales', 'dwh.DimCurrency'),
	('dwh.FctSales', 'dwh.DimDate'),
	('dwh.FctSales', 'dwh.DimOrderStatus'),
	('dwh.FctSales', 'dwh.DimSrcSystem'),
	('dwh.FctSales', 'dwh.RefClientAccount'),
	('dwh.FctSales', 'dwh.RefEmployee'),
	('dwh.FctSales', 'dwh.RefProduct'),
	('dwh.FctSales', 'dwh.RefWarehouse'),
	('dwh.FctSales', 'lhbronze.erp_erp.SALES_ORDERS'),
	('dwh.FctVisit', 'dwh.DimActivityType'),
	('dwh.FctVisit', 'dwh.DimDate'),
	('dwh.FctVisit', 'dwh.DimSrcSystem'),
	('dwh.FctVisit', 'dwh.RefDoctor'),
	('dwh.FctVisit', 'dwh.RefEmployee'),
	('dwh.FctVisit', 'dwh.RefProduct'),
	('dwh.FctVisit', 'lhbronze.erp_erp.DOCTOR_VISITS'),
	('dwh.RefClientAccount', 'dwh.DimClientAccount'),
	('dwh.RefClientAccount', 'dwh.DimSrcSystem'),
	('dwh.RefClientAccount', 'lhbronze.erp_erp.CUSTOMERS'),
	('dwh.RefDoctor', 'dwh.DimDoctor'),
	('dwh.RefDoctor', 'dwh.DimSrcSystem'),
	('dwh.RefDoctor', 'lhbronze.erp_erp.DOCTORS'),
	('dwh.RefEmployee', 'dwh.DimEmployee'),
	('dwh.RefEmployee', 'dwh.DimSrcSystem'),
	('dwh.RefEmployee', 'lhbronze.erp_erp.EMPLOYEES'),
	('dwh.RefMovementType', 'dwh.DimMovementType'),
	('dwh.RefMovementType', 'dwh.DimSrcSystem'),
	('dwh.RefMovementType', 'lhbronze.erp_erp.INVENTORY_MOVEMENTS'),
	('dwh.RefProduct', 'dwh.DimProduct'),
	('dwh.RefProduct', 'dwh.DimSrcSystem'),
	('dwh.RefProduct', 'lhbronze.erp_erp.PRODUCTS'),
	('dwh.RefWarehouse', 'dwh.DimSrcSystem'),
	('dwh.RefWarehouse', 'dwh.DimWarehouse'),
	('dwh.RefWarehouse', 'lhbronze.erp_erp.WAREHOUSES')
GO

DROP TABLE IF EXISTS [whsilver].[dwh].[EtlObjectDownstream]
GO
CREATE TABLE [whsilver].[dwh].[EtlObjectDownstream]
(
	[RootObject] [varchar](256) NOT NULL,        -- що перезавантажують (bronze-таблиця або silver-обʼєкт)
	[ObjectName] [varchar](128) NOT NULL         -- silver-обʼєкт без схеми (join з EtlSilverObject)
)
GO

CREATE OR ALTER PROCEDURE [dwh].[spRefreshObjectClosure]
AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE [dwh].[EtlObjectDownstream];

    -- 1. прямі залежні
    INSERT INTO [dwh].[EtlObjectDownstream] ([RootObject],[ObjectName])
    SELECT DISTINCT d.DependsOnObject, REPLACE(d.ObjectName, 'dwh.', '')
    FROM [dwh].[EtlObjectDependency] AS d;

    -- 2. сам silver-обʼєкт теж перезавантажується, якщо він і є коренем
    INSERT INTO [dwh].[EtlObjectDownstream] ([RootObject],[ObjectName])
    SELECT 'dwh.' + o.ObjectName, o.ObjectName
    FROM [dwh].[EtlSilverObject] AS o
    WHERE o.IsActive = 1
      AND NOT EXISTS (
          SELECT 1 FROM [dwh].[EtlObjectDownstream] c
          WHERE c.RootObject = 'dwh.' + o.ObjectName AND c.ObjectName = o.ObjectName
      );

    -- 3. транзитивне замикання (фікспойнт замість рекурсивного CTE)
    DECLARE @rows INT = 1;
    DECLARE @guard INT = 0;

    WHILE @rows > 0 AND @guard < 50
    BEGIN
        INSERT INTO [dwh].[EtlObjectDownstream] ([RootObject],[ObjectName])
        SELECT DISTINCT c.RootObject, REPLACE(d.ObjectName, 'dwh.', '')
        FROM [dwh].[EtlObjectDownstream] AS c
        INNER JOIN [dwh].[EtlObjectDependency] AS d
            ON d.DependsOnObject = 'dwh.' + c.ObjectName
        WHERE NOT EXISTS (
            SELECT 1 FROM [dwh].[EtlObjectDownstream] x
            WHERE x.RootObject = c.RootObject
              AND x.ObjectName = REPLACE(d.ObjectName, 'dwh.', '')
        );

        SET @rows = @@ROWCOUNT;
        SET @guard = @guard + 1;
    END

    -- Fabric Warehouse не дозволяє підзапити всередині CONCAT/PRINT -> рахуємо в змінну
    DECLARE @closure_cnt INT;
    SELECT @closure_cnt = COUNT(1) FROM [dwh].[EtlObjectDownstream];

    PRINT CONCAT('[spRefreshObjectClosure] ітерацій: ', @guard,
                 ', ребер замикання: ', @closure_cnt);
END
GO

CREATE OR ALTER PROCEDURE [dwh].[spSilverLoadLevel]
    @level INT,
    @load_id NVARCHAR(250) = 'manual_load',
    @root_object NVARCHAR(256) = NULL   -- NULL = увесь рівень; інакше лише залежні від кореня
AS
BEGIN
    SET NOCOUNT ON;

    IF @root_object = '' SET @root_object = NULL;

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
      AND o.IsActive = 1
      AND (
            @root_object IS NULL
         OR EXISTS (
                SELECT 1 FROM [dwh].[EtlObjectDownstream] AS d
                WHERE d.ObjectName = o.ObjectName
                  AND d.RootObject = @root_object
            )
          );

    DECLARE @cnt INT = (SELECT COUNT(1) FROM #level_objects);
    DECLARE @i INT = 1;

    DECLARE @obj VARCHAR(128), @type VARCHAR(10), @scd VARCHAR(10), @pass SMALLINT, @p SMALLINT;
    DECLARE @started DATETIME2(3), @finished DATETIME2(3), @rowcnt BIGINT, @sql NVARCHAR(MAX);

    PRINT CONCAT('[spSilverLoadLevel] level=', @level, ', objects=', @cnt,
                 ', root=', ISNULL(@root_object, '<all>'), ', load_id=', @load_id);

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

CREATE OR ALTER PROCEDURE [dwh].[spSilverLoadSubset]
    @root_object NVARCHAR(256) = NULL,   -- 'lhbronze.erp_erp.CUSTOMERS' | 'dwh.DimRegion' | NULL = усе
    @load_id NVARCHAR(250) = 'manual_subset_load'
AS
BEGIN
    SET NOCOUNT ON;

    IF @root_object = '' SET @root_object = NULL;

    IF @root_object IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dwh].[EtlObjectDownstream] WHERE RootObject = @root_object)
    BEGIN
        RAISERROR('Unknown root object: %s. Перелік доступних коренів: SELECT DISTINCT RootObject FROM dwh.EtlObjectDownstream.', 16, 1, @root_object);
        RETURN;
    END

    DECLARE @lvl INT = 1;
    DECLARE @max_lvl INT = (SELECT MAX(LoadLevel) FROM [dwh].[EtlSilverObject] WHERE IsActive = 1);

    -- Fabric Warehouse не дозволяє підзапити всередині CONCAT/PRINT -> рахуємо в змінну
    DECLARE @plan_cnt INT;

    IF @root_object IS NULL
        SELECT @plan_cnt = COUNT(1)
        FROM [dwh].[EtlSilverObject]
        WHERE IsActive = 1;
    ELSE
        SELECT @plan_cnt = COUNT(1)
        FROM [dwh].[EtlObjectDownstream] AS d
        INNER JOIN [dwh].[EtlSilverObject] AS o
            ON o.ObjectName = d.ObjectName
           AND o.IsActive = 1
        WHERE d.RootObject = @root_object;

    PRINT CONCAT('[spSilverLoadSubset] root=', ISNULL(@root_object, '<all>'),
                 ', обʼєктів у плані: ', @plan_cnt);

    WHILE @lvl <= @max_lvl
    BEGIN
        EXEC [dwh].[spSilverLoadLevel] @level = @lvl, @load_id = @load_id, @root_object = @root_object;
        SET @lvl = @lvl + 1;
    END
END
GO

CREATE OR ALTER PROCEDURE [dwh].[spSilverFullLoad]
    @load_id NVARCHAR(250) = 'manual_full_load'
AS
BEGIN
    SET NOCOUNT ON;
    EXEC [dwh].[spSilverLoadSubset] @root_object = NULL, @load_id = @load_id;
END
GO

EXEC [dwh].[spRefreshObjectClosure];
GO
