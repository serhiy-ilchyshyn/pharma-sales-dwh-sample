-- ClickUp: PHARMA-SILVER-006
-- Демонстрація SCD Type 1 на silver.
--
-- 1. Виправлено гілку SCD1 у [dwh].[spUpsertSCDDimension]:
--      * INSERT тепер заповнює durable key SK<Name>KeyID — без нього вставка падала
--        (колонка NOT NULL), а факти й Ref-таблиці не знайшли б новий запис;
--      * додано мʼяке видалення (IsDeleted = 1) для записів, що зникли з джерела,
--        і зняття позначки, якщо запис повернувся;
--      * UPDATE більше не чіпає службовий рядок -1.
--    EndDate у SCD1 лишається порожнім: версій немає, тому всі наявні join-и
--    з умовою EndDate IS NULL продовжують бачити актуальний рядок.
--
-- 2. [dwh].[DimLpu] переведено на SCD1.
--    Чому саме він: назва й розташування медзакладу — довідкова інформація.
--    Бізнесу потрібне актуальне значення, а не історія того, як виправляли
--    друкарську помилку в назві лікарні. Решта вимірів лишається SCD2.
--    Перемкнути інший обʼєкт = один UPDATE у [dwh].[EtlSilverObject].
--
-- 3. Історичні версії DimLpu згорнуто до поточних: у SCD1 закриті версії
--    не мають сенсу, а UPDATE по натуральному ключу зачепив би їх усі.
GO
--IMPORTANT
USE [whsilver];
--IMPORTANT
GO

CREATE OR ALTER PROCEDURE [dwh].[spUpsertSCDDimension]
    @dim_table_name SYSNAME,
    @scd_type VARCHAR(10)  -- 'SCD1' or 'SCD2'
AS
BEGIN
    SET NOCOUNT ON;

    IF @scd_type NOT IN ('SCD1', 'SCD2')
    BEGIN
        RAISERROR('Unsupported SCD type: %s. Allowed values: SCD1, SCD2.', 16, 1, @scd_type);
        RETURN;
    END;

    DECLARE @schema_name NVARCHAR(3) = 'dwh';
    DECLARE @dim_view_name NVARCHAR(100) = 'v' + @dim_table_name;
    DECLARE @system_columns NVARCHAR(MAX) = 'StartDate,EndDate,IsDeleted,CreatedBy,ModifiedBy,CreatedAt,ModifiedAt';

    DECLARE @sk_key NVARCHAR(150);
    DECLARE @dk_key NVARCHAR(150);

    IF NOT EXISTS (
        SELECT 1
        FROM INFORMATION_SCHEMA.VIEWS
        WHERE TABLE_SCHEMA = @schema_name
          AND TABLE_NAME   = @dim_view_name
    )
    BEGIN
        RAISERROR('View [%s.%s] does not exist.', 16, 1, @schema_name, @dim_view_name);
        RETURN;
    END;

    -- Ref* тримає префікс у назві ключа (SKRefPlaceID), Dim* — ні (SKPlaceID)
    IF LEFT(@dim_table_name, 3) = 'Ref'
    BEGIN
        SET @sk_key = 'SK' + @dim_table_name + 'ID';
        SET @dk_key = 'SK' + @dim_table_name + 'KeyID';
    END
    ELSE
    BEGIN
        SET @sk_key = 'SK' + RIGHT(@dim_table_name, LEN(@dim_table_name) - 3) + 'ID';
        SET @dk_key = 'SK' + RIGHT(@dim_table_name, LEN(@dim_table_name) - 3) + 'KeyID';
    END;

    -- Натуральний ключ = перша колонка view
    DECLARE @natural_key NVARCHAR(MAX) = (
        SELECT COLUMN_NAME
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = @dim_view_name
          AND TABLE_SCHEMA = @schema_name
          AND ORDINAL_POSITION = 1
    );

    IF @natural_key IS NULL
    BEGIN
        RAISERROR('Could not determine natural key from view [%s.%s].', 16, 1, @schema_name, @dim_view_name);
        RETURN;
    END;

    DECLARE @trg_table_exists BIT = CASE WHEN EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = @schema_name AND TABLE_NAME = @dim_table_name
    ) THEN 1 ELSE 0 END;

    DECLARE @full_table NVARCHAR(200) = QUOTENAME(@schema_name) + '.' + QUOTENAME(@dim_table_name);
    DECLARE @full_view  NVARCHAR(200) = QUOTENAME(@schema_name) + '.' + QUOTENAME(@dim_view_name);
    DECLARE @current_time DATETIME2(3) = SYSUTCDATETIME();

    DECLARE @tracked_columns NVARCHAR(MAX);
    DECLARE @update_columns  NVARCHAR(MAX);
    DECLARE @change_condition NVARCHAR(MAX);
    DECLARE @sql NVARCHAR(MAX);

    -- Tracked columns: усе, крім системних, SK, DK та натурального ключа
    SELECT @tracked_columns = STRING_AGG(COLUMN_NAME, ',')
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = @dim_view_name
      AND TABLE_SCHEMA = @schema_name
      AND COLUMN_NAME NOT IN (
          SELECT value FROM STRING_SPLIT(@system_columns, ',')
          UNION SELECT @sk_key
          UNION SELECT @dk_key
          UNION SELECT @natural_key
      );

    SET @tracked_columns = ISNULL(@tracked_columns, '');

    -- Умова зміни з урахуванням типів даних (NULL-safe)
    IF @tracked_columns = ''
    BEGIN
        SET @change_condition = '1=0';
    END
    ELSE
    BEGIN
        SELECT @change_condition = STRING_AGG(
            CASE
                WHEN DATA_TYPE IN (
                    'int','bigint','tinyint','smallint',
                    'decimal','numeric','float','real',
                    'bit','money','smallmoney'
                )
                    THEN 'ISNULL(trg.' + QUOTENAME(COLUMN_NAME) + ', -1) <> ISNULL(src.' + QUOTENAME(COLUMN_NAME) + ', -1)'
                WHEN DATA_TYPE IN ('varchar','nvarchar','char','nchar','text')
                    THEN 'ISNULL(trg.' + QUOTENAME(COLUMN_NAME) + ', ''N/A'') <> ISNULL(src.' + QUOTENAME(COLUMN_NAME) + ', ''N/A'')'
                WHEN DATA_TYPE IN ('datetime','datetime2','smalldatetime','date','time')
                    THEN 'ISNULL(trg.' + QUOTENAME(COLUMN_NAME) + ', ''1900-01-01'') <> ISNULL(src.' + QUOTENAME(COLUMN_NAME) + ', ''1900-01-01'')'
                ELSE 'trg.' + QUOTENAME(COLUMN_NAME) + ' <> src.' + QUOTENAME(COLUMN_NAME)
            END,
            ' OR '
        )
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = @dim_view_name
          AND TABLE_SCHEMA = @schema_name
          AND COLUMN_NAME NOT IN (
              SELECT value FROM STRING_SPLIT(@system_columns, ',')
              UNION SELECT @sk_key
              UNION SELECT @dk_key
              UNION SELECT @natural_key
          );
    END;

    -- Максимальний durable key (рядок -1 ігноруємо)
    DECLARE @max_dk BIGINT = 0;

    IF @trg_table_exists = 1
    BEGIN
        DECLARE @sql_max NVARCHAR(MAX) =
            N'SELECT @max_dk =
                ISNULL(MAX(CASE WHEN ' + QUOTENAME(@dk_key) + N' > 0 THEN ' + QUOTENAME(@dk_key) + N' END), 0)
              FROM ' + @full_table + N';';

        EXEC sp_executesql
            @sql_max,
            N'@max_dk BIGINT OUTPUT',
            @max_dk OUTPUT;
    END;

    -- Якщо цільової таблиці немає — створюємо порожню за структурою view
    IF @trg_table_exists = 0
    BEGIN
        DECLARE @sql_create_tbl NVARCHAR(MAX);

        IF @scd_type = 'SCD1'
        BEGIN
            SET @sql_create_tbl = N'
            SELECT
                CAST(HASHBYTES(''SHA1'', CONCAT(NEWID(), SYSDATETIME())) AS BIGINT) AS ' + QUOTENAME(@sk_key) + N',
                CAST(0 AS BIT) AS IsDeleted,
                CAST(''fbr_man_process'' AS VARCHAR(128)) AS CreatedBy,
                CAST(''fbr_man_process'' AS VARCHAR(128)) AS ModifiedBy,
                CAST(@current_time AS DATETIME2(3)) AS CreatedAt,
                CAST(NULL AS DATETIME2(3)) AS ModifiedAt,
                src.' + QUOTENAME(@natural_key) + N'
                ' + CASE WHEN @tracked_columns <> '' THEN N', src.' + REPLACE(@tracked_columns, ',', ', src.') ELSE N'' END + N'
            INTO ' + @full_table + N'
            FROM ' + @full_view + N' src
            WHERE 1=0;';
        END
        ELSE
        BEGIN
            SET @sql_create_tbl = N'
            SELECT
                CAST(HASHBYTES(''SHA1'', CONCAT(NEWID(), SYSDATETIME())) AS BIGINT) AS ' + QUOTENAME(@sk_key) + N',
                CAST(NULL AS BIGINT) AS ' + QUOTENAME(@dk_key) + N',
                CAST(@current_time AS DATETIME2(3)) AS StartDate,
                CAST(NULL AS DATETIME2(3)) AS EndDate,
                CAST(0 AS BIT) AS IsDeleted,
                CAST(''fbr_man_process'' AS VARCHAR(128)) AS CreatedBy,
                CAST(''fbr_man_process'' AS VARCHAR(128)) AS ModifiedBy,
                CAST(@current_time AS DATETIME2(3)) AS CreatedAt,
                CAST(NULL AS DATETIME2(3)) AS ModifiedAt,
                src.' + QUOTENAME(@natural_key) + N'
                ' + CASE WHEN @tracked_columns <> '' THEN N', src.' + REPLACE(@tracked_columns, ',', ', src.') ELSE N'' END + N'
            INTO ' + @full_table + N'
            FROM ' + @full_view + N' src
            WHERE 1=0;';
        END;

        EXEC sp_executesql @sql_create_tbl, N'@current_time DATETIME2(3)', @current_time=@current_time;
        PRINT @sql_create_tbl;

        SET @trg_table_exists = 1;
    END;

    EXEC [dwh].[spSchemaValidation]
        @schema_name    = @schema_name,
        @table_name     = @dim_table_name,
        @view_name      = @dim_view_name,
        @sk_key         = @sk_key,
        @dk_key         = @dk_key,
        @natural_key    = @natural_key,
        @system_columns = @system_columns;

    -----------------------
    -- SCD1
    -----------------------
    IF @scd_type = 'SCD1'
    BEGIN
        IF @tracked_columns <> ''
        BEGIN
            SELECT @update_columns = STRING_AGG(
                'trg.' + QUOTENAME(TRIM(value)) + ' = src.' + QUOTENAME(TRIM(value)), ', '
            )
            FROM STRING_SPLIT(@tracked_columns, ',');
        END
        ELSE
        BEGIN
            SET @update_columns = '';
        END;

        SET @sql = N'
        SELECT * INTO #' + @dim_table_name + N' FROM ' + @full_view + N';

        -- SCD1: перезапис атрибутів на місці, історія не ведеться.
        -- Повторна поява раніше зниклого запису знімає IsDeleted.
        UPDATE trg
        SET ' + CASE WHEN @update_columns <> '' THEN @update_columns + N',' ELSE N'' END + N'
            trg.IsDeleted = 0,
            trg.ModifiedAt = @current_time,
            trg.ModifiedBy = ''fbr_man_process''
        FROM ' + @full_table + N' trg
        JOIN #' + @dim_table_name + N' src
            ON trg.' + QUOTENAME(@natural_key) + N' = src.' + QUOTENAME(@natural_key) + N'
        WHERE trg.' + QUOTENAME(@sk_key) + N' <> -1
          AND (' + @change_condition + N' OR ISNULL(trg.IsDeleted, 0) = 1);

        -- Нові натуральні ключі -> нові durable keys (у SCD1 вони теж потрібні:
        -- факти й Ref-таблиці посилаються саме на SK<Name>KeyID)
        SELECT DISTINCT
            src.' + QUOTENAME(@natural_key) + N' AS NK,
            CAST(@max_dk + ROW_NUMBER() OVER (ORDER BY src.' + QUOTENAME(@natural_key) + N') AS BIGINT) AS DK
        INTO #NewScd1
        FROM #' + @dim_table_name + N' src
        WHERE NOT EXISTS (
            SELECT 1
            FROM ' + @full_table + N' t
            WHERE t.' + QUOTENAME(@natural_key) + N' = src.' + QUOTENAME(@natural_key) + N'
              AND t.' + QUOTENAME(@dk_key) + N' > 0
        );

        -- SCD1: вставка нових записів
        INSERT INTO ' + @full_table + N' (
            ' + QUOTENAME(@sk_key) + N',
            ' + QUOTENAME(@dk_key) + N',
            StartDate, EndDate, IsDeleted,
            CreatedBy, CreatedAt,
            ' + QUOTENAME(@natural_key) +
            CASE WHEN @tracked_columns <> '' THEN N', ' + @tracked_columns ELSE N'' END + N'
        )
        SELECT
            CAST(HASHBYTES(''SHA1'', CONCAT(NEWID(), SYSDATETIME())) AS BIGINT) AS ' + QUOTENAME(@sk_key) + N',
            nw.DK,
            @current_time, NULL, 0,
            ''fbr_man_process'', @current_time,
            src.' + QUOTENAME(@natural_key) +
            CASE WHEN @tracked_columns <> '' THEN N', src.' + REPLACE(@tracked_columns, ',', ', src.') ELSE N'' END + N'
        FROM #' + @dim_table_name + N' src
        LEFT JOIN ' + @full_table + N' trg
            ON trg.' + QUOTENAME(@natural_key) + N' = src.' + QUOTENAME(@natural_key) + N'
        LEFT JOIN #NewScd1 nw
            ON nw.NK = src.' + QUOTENAME(@natural_key) + N'
        WHERE trg.' + QUOTENAME(@natural_key) + N' IS NULL;

        -- SCD1: запис зник із джерела -> позначаємо IsDeleted.
        -- EndDate не заповнюємо: у SCD1 версій немає, і всі join-и по EndDate IS NULL
        -- мають далі бачити актуальний рядок.
        UPDATE trg
        SET
            trg.IsDeleted = 1,
            trg.ModifiedAt = @current_time,
            trg.ModifiedBy = ''fbr_man_process''
        FROM ' + @full_table + N' trg
        LEFT JOIN #' + @dim_table_name + N' src
            ON trg.' + QUOTENAME(@natural_key) + N' = src.' + QUOTENAME(@natural_key) + N'
        WHERE src.' + QUOTENAME(@natural_key) + N' IS NULL
          AND ISNULL(trg.IsDeleted, 0) = 0
          AND trg.' + QUOTENAME(@sk_key) + N' <> -1;';
    END

    -----------------------
    -- SCD2 (durable key переїжджає на нову версію рядка)
    -----------------------
    ELSE IF @scd_type = 'SCD2'
    BEGIN
        SET @sql = N'
        SELECT * INTO #' + @dim_table_name + N' FROM ' + @full_view + N';

        -- Активні рядки, що змінилися (durable key перевикористовуємо)
        SELECT
            trg.' + QUOTENAME(@natural_key) + N' AS NK,
            trg.' + QUOTENAME(@dk_key) + N' AS DK
        INTO #Changed
        FROM ' + @full_table + N' trg
        INNER JOIN #' + @dim_table_name + N' src
            ON trg.' + QUOTENAME(@natural_key) + N' = src.' + QUOTENAME(@natural_key) + N'
        WHERE trg.EndDate IS NULL
          AND (' + @change_condition + N')
          AND trg.' + QUOTENAME(@sk_key) + N' <> -1;

        -- SCD2: закриття попередніх версій
        UPDATE trg
        SET
            trg.EndDate = @current_time,
            trg.ModifiedAt = @current_time,
            trg.ModifiedBy = ''fbr_man_process''
        FROM ' + @full_table + N' trg
        INNER JOIN #Changed ch
            ON ch.NK = trg.' + QUOTENAME(@natural_key) + N'
        WHERE trg.EndDate IS NULL
          AND trg.' + QUOTENAME(@sk_key) + N' <> -1;

        -- Нові натуральні ключі -> нові durable keys (max + row_number)
        SELECT DISTINCT
            src.' + QUOTENAME(@natural_key) + N' AS NK,
            CAST(@max_dk + ROW_NUMBER() OVER (ORDER BY src.' + QUOTENAME(@natural_key) + N') AS BIGINT) AS DK
        INTO #New
        FROM #' + @dim_table_name + N' src
        WHERE NOT EXISTS (
            SELECT 1
            FROM ' + @full_table + N' t
            WHERE t.' + QUOTENAME(@natural_key) + N' = src.' + QUOTENAME(@natural_key) + N'
              AND t.' + QUOTENAME(@dk_key) + N' > 0
        );

        -- SCD2: вставка нових/змінених версій
        INSERT INTO ' + @full_table + N' (
            ' + QUOTENAME(@sk_key) + N',
            ' + QUOTENAME(@dk_key) + N',
            StartDate, EndDate, IsDeleted,
            CreatedBy, CreatedAt,
            ' + QUOTENAME(@natural_key) +
            CASE WHEN @tracked_columns <> '' THEN N', ' + @tracked_columns ELSE N'' END + N'
        )
        SELECT
            CAST(HASHBYTES(''SHA1'', CONCAT(NEWID(), SYSDATETIME())) AS BIGINT) AS ' + QUOTENAME(@sk_key) + N',
            COALESCE(ch.DK, nw.DK) AS ' + QUOTENAME(@dk_key) + N',
            @current_time, NULL, 0,
            ''fbr_man_process'', @current_time,
            src.' + QUOTENAME(@natural_key) +
            CASE WHEN @tracked_columns <> '' THEN N', src.' + REPLACE(@tracked_columns, ',', ', src.') ELSE N'' END + N'
        FROM #' + @dim_table_name + N' src
        LEFT JOIN ' + @full_table + N' trg
            ON trg.' + QUOTENAME(@natural_key) + N' = src.' + QUOTENAME(@natural_key) + N'
           AND trg.EndDate IS NULL
        LEFT JOIN #Changed ch
            ON ch.NK = src.' + QUOTENAME(@natural_key) + N'
        LEFT JOIN #New nw
            ON nw.NK = src.' + QUOTENAME(@natural_key) + N'
        WHERE trg.' + QUOTENAME(@natural_key) + N' IS NULL
           OR ch.NK IS NOT NULL;

        -- SCD2: м''яке видалення записів, яких більше немає у джерелі (рядок -1 не чіпаємо)
        UPDATE trg
        SET
            trg.EndDate = @current_time,
            trg.IsDeleted = 1,
            trg.ModifiedAt = @current_time,
            trg.ModifiedBy = ''fbr_man_process''
        FROM ' + @full_table + N' trg
        LEFT JOIN #' + @dim_table_name + N' src
            ON trg.' + QUOTENAME(@natural_key) + N' = src.' + QUOTENAME(@natural_key) + N'
        WHERE trg.EndDate IS NULL
          AND src.' + QUOTENAME(@natural_key) + N' IS NULL
          AND trg.' + QUOTENAME(@sk_key) + N' <> -1;';
    END;

    PRINT @change_condition;
    PRINT @update_columns;
    PRINT @tracked_columns;
    PRINT @natural_key;
    PRINT @sk_key;
    PRINT @dk_key;
    PRINT @full_table;
    PRINT @full_view;
    PRINT @sql;

    EXEC sp_executesql
        @sql,
        N'@current_time DATETIME2(3), @max_dk BIGINT',
        @current_time = @current_time,
        @max_dk = @max_dk;
END
GO

-- Згортаємо історію DimLpu до актуальних рядків (SCD2 -> SCD1)
DELETE FROM [dwh].[DimLpu] WHERE EndDate IS NOT NULL;
GO

-- Перемикаємо стратегію в реєстрі обʼєктів
UPDATE [dwh].[EtlSilverObject]
SET ScdType = 'SCD1'
WHERE ObjectName = 'DimLpu';
GO
