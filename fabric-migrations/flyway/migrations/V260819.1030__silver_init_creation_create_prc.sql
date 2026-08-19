-- ClickUp: PHARMA-SILVER-001
-- Процедури завантаження silver:
--   [dwh].[spSchemaValidation]   — звіряє колонки таблиці та її джерельного view
--   [dwh].[spUpsertSCDDimension] — SCD1/SCD2 upsert виміру або Ref-таблиці з durable key
--   [dwh].[spFullFct]            — повне перезавантаження фактової таблиці з vFct*
GO
--IMPORTANT
USE [whsilverad];
--IMPORTANT
GO

CREATE OR ALTER PROCEDURE [dwh].[spSchemaValidation]
    @schema_name     SYSNAME,
    @table_name      SYSNAME,
    @view_name       SYSNAME,
    @sk_key          SYSNAME = NULL,
    @dk_key          SYSNAME = NULL,
    @natural_key     SYSNAME = NULL,
    @system_columns  NVARCHAR(MAX) = NULL  -- comma-separated: 'StartDate,EndDate,...'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql NVARCHAR(MAX) = N'
DECLARE @missing_cnt INT, @extra_cnt INT;
DECLARE @missing_list NVARCHAR(MAX), @extra_list NVARCHAR(MAX);

;WITH exclusions AS (
    SELECT CAST(LTRIM(RTRIM(value)) AS NVARCHAR(128)) COLLATE DATABASE_DEFAULT AS col
    FROM STRING_SPLIT(@p_system_columns, '','')
    WHERE @p_system_columns IS NOT NULL
      AND LTRIM(RTRIM(@p_system_columns)) <> ''''
      AND LTRIM(RTRIM(value)) <> ''''

    UNION ALL SELECT @p_sk_key      COLLATE DATABASE_DEFAULT WHERE @p_sk_key      IS NOT NULL
    UNION ALL SELECT @p_dk_key      COLLATE DATABASE_DEFAULT WHERE @p_dk_key      IS NOT NULL
    UNION ALL SELECT @p_natural_key COLLATE DATABASE_DEFAULT WHERE @p_natural_key IS NOT NULL
),
table_cols AS (
    SELECT c.COLUMN_NAME COLLATE DATABASE_DEFAULT AS column_name
    FROM INFORMATION_SCHEMA.COLUMNS c
    WHERE c.TABLE_SCHEMA = @p_schema_name
      AND c.TABLE_NAME   = @p_table_name
      AND (
            NOT EXISTS (SELECT 1 FROM exclusions)
            OR c.COLUMN_NAME COLLATE DATABASE_DEFAULT NOT IN (SELECT col FROM exclusions)
          )
),
view_cols AS (
    SELECT c.COLUMN_NAME COLLATE DATABASE_DEFAULT AS column_name
    FROM INFORMATION_SCHEMA.COLUMNS c
    WHERE c.TABLE_SCHEMA = @p_schema_name
      AND c.TABLE_NAME   = @p_view_name
      AND (
            NOT EXISTS (SELECT 1 FROM exclusions)
            OR c.COLUMN_NAME COLLATE DATABASE_DEFAULT NOT IN (SELECT col FROM exclusions)
          )
),
missing_in_view AS (               -- є в таблиці, немає у view
    SELECT column_name FROM table_cols
    EXCEPT
    SELECT column_name FROM view_cols
),
extra_in_view AS (                 -- є у view, немає в таблиці
    SELECT column_name FROM view_cols
    EXCEPT
    SELECT column_name FROM table_cols
)
SELECT
    @missing_cnt  = m.cnt,
    @extra_cnt    = e.cnt,
    @missing_list = ml.list,
    @extra_list   = el.list
FROM (SELECT COUNT(*) AS cnt FROM missing_in_view) m
CROSS JOIN (SELECT COUNT(*) AS cnt FROM extra_in_view)   e
CROSS JOIN (SELECT STRING_AGG(column_name, '','') AS list FROM missing_in_view) ml
CROSS JOIN (SELECT STRING_AGG(column_name, '','') AS list FROM extra_in_view)   el;

IF (@missing_cnt > 0 OR @extra_cnt > 0)
BEGIN
    SET @missing_list = COALESCE(@missing_list, N'''');
    SET @extra_list   = COALESCE(@extra_list,   N'''');

    DECLARE @msg NVARCHAR(MAX) = CONCAT(
        N''Column mismatch between ['',
        @p_schema_name, N''.'', @p_table_name, N''] and ['',
        @p_schema_name, N''.'', @p_view_name, N'']. '',
        N''Missing in view ('', @missing_cnt, N''): '', @missing_list, N''; '',
        N''Extra in view ('', @extra_cnt, N''): '', @extra_list
    );
    THROW 50013, @msg, 1;
END
ELSE
BEGIN
    PRINT N''Validation is passed'';
END
';

    EXEC sys.sp_executesql
        @sql,
        N'@p_schema_name SYSNAME,
          @p_table_name  SYSNAME,
          @p_view_name   SYSNAME,
          @p_system_columns NVARCHAR(MAX),
          @p_sk_key      SYSNAME,
          @p_dk_key      SYSNAME,
          @p_natural_key SYSNAME',
        @p_schema_name    = @schema_name,
        @p_table_name     = @table_name,
        @p_view_name      = @view_name,
        @p_system_columns = @system_columns,
        @p_sk_key         = @sk_key,
        @p_dk_key         = @dk_key,
        @p_natural_key    = @natural_key;
END
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

        -- SCD1: оновлення змінених записів
        UPDATE trg
        SET ' + CASE WHEN @update_columns <> '' THEN @update_columns + N',' ELSE N'' END + N'
            trg.ModifiedAt = @current_time,
            trg.ModifiedBy = ''fbr_man_process''
        FROM ' + @full_table + N' trg
        JOIN #' + @dim_table_name + N' src
            ON trg.' + QUOTENAME(@natural_key) + N' = src.' + QUOTENAME(@natural_key) + N'
        WHERE ' + @change_condition + N';

        -- SCD1: вставка нових записів
        INSERT INTO ' + @full_table + N' (
            ' + QUOTENAME(@sk_key) + N',
            CreatedBy, CreatedAt,
            ' + QUOTENAME(@natural_key) +
            CASE WHEN @tracked_columns <> '' THEN N', ' + @tracked_columns ELSE N'' END + N'
        )
        SELECT
            CAST(HASHBYTES(''SHA1'', CONCAT(NEWID(), SYSDATETIME())) AS BIGINT) AS ' + QUOTENAME(@sk_key) + N',
            ''fbr_man_process'', @current_time,
            src.' + QUOTENAME(@natural_key) +
            CASE WHEN @tracked_columns <> '' THEN N', src.' + REPLACE(@tracked_columns, ',', ', src.') ELSE N'' END + N'
        FROM #' + @dim_table_name + N' src
        LEFT JOIN ' + @full_table + N' trg
            ON trg.' + QUOTENAME(@natural_key) + N' = src.' + QUOTENAME(@natural_key) + N'
        WHERE trg.' + QUOTENAME(@natural_key) + N' IS NULL;';
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

CREATE OR ALTER PROCEDURE [dwh].[spFullFct]
    @fct_table_name NVARCHAR(250),
    @load_id NVARCHAR(250)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @schema_name NVARCHAR(3) = 'dwh';
    DECLARE @fct_view_name NVARCHAR(100) = 'v' + @fct_table_name;
    DECLARE @sk_key NVARCHAR(150) = 'SK' + @fct_table_name + 'ID';

    IF NOT EXISTS (
        SELECT 1
        FROM INFORMATION_SCHEMA.VIEWS
        WHERE TABLE_SCHEMA = @schema_name
          AND TABLE_NAME   = @fct_view_name
    )
    BEGIN
        RAISERROR('View [%s.%s] does not exist.', 16, 1, @schema_name, @fct_view_name);
        RETURN;
    END;

    DECLARE @trg_table_exists INT = (
        SELECT COUNT(1)
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_NAME = @fct_table_name
          AND TABLE_SCHEMA = @schema_name
    );

    DECLARE @full_table NVARCHAR(200) = QUOTENAME(@schema_name) + '.' + QUOTENAME(@fct_table_name);
    DECLARE @full_view  NVARCHAR(200) = QUOTENAME(@schema_name) + '.' + QUOTENAME(@fct_view_name);
    DECLARE @current_time DATETIME2(3) = SYSUTCDATETIME();

    DECLARE @sql NVARCHAR(MAX);

    IF @trg_table_exists = 1
        SET @sql = '
        TRUNCATE TABLE ' + @full_table + ';

        -- FCT: повне перезавантаження
        INSERT INTO ' + @full_table + '
        SELECT
            CAST(HASHBYTES(''SHA1'', CONCAT(NEWID(), SYSDATETIME())) AS BIGINT) AS ' + @sk_key + ',
            CAST(''' + @load_id + ''' AS VARCHAR(100)) AS CreatedBy,
            @current_time AS CreatedAt,
            v_fct.*
        FROM ' + @full_view + ' v_fct;';
    ELSE
        SET @sql = '
        -- FCT: створення таблиці за структурою view
        SELECT
            CAST(HASHBYTES(''SHA1'', CONCAT(NEWID(), SYSDATETIME())) AS BIGINT) AS ' + @sk_key + ',
            CAST(''' + @load_id + ''' AS VARCHAR(100)) AS CreatedBy,
            @current_time AS CreatedAt,
            v_fct.*
        INTO ' + @full_table + '
        FROM ' + @full_view + ' v_fct;';

    PRINT @sql;

    EXEC sp_executesql
        @sql,
        N'@current_time DATETIME2(3)',
        @current_time = @current_time;
END
GO
