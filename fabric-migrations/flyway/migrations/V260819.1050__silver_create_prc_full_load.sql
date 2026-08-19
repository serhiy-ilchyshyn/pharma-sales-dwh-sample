-- ClickUp: PHARMA-SILVER-001
-- Оркестрація повного завантаження silver у порядку залежностей.
-- В проді ці виклики зазвичай розкладені по окремих CTL-workflow'ах;
-- тут зібрані в одну процедуру для відтворюваності прикладу.
GO
--IMPORTANT
USE [whsilverad];
--IMPORTANT
GO

CREATE OR ALTER PROCEDURE [dwh].[spSilverFullLoad]
    @load_id NVARCHAR(250) = 'manual_full_load'
AS
BEGIN
    SET NOCOUNT ON;

    ------------------------------------------------------------------
    -- 1. Виміри без залежностей
    ------------------------------------------------------------------
    EXEC [dwh].[spUpsertSCDDimension] @dim_table_name = 'DimRegion',        @scd_type = 'SCD2';
    EXEC [dwh].[spUpsertSCDDimension] @dim_table_name = 'DimTerritory',     @scd_type = 'SCD2';
    EXEC [dwh].[spUpsertSCDDimension] @dim_table_name = 'DimChain',         @scd_type = 'SCD2';
    EXEC [dwh].[spUpsertSCDDimension] @dim_table_name = 'DimManufacturer',  @scd_type = 'SCD2';
    EXEC [dwh].[spUpsertSCDDimension] @dim_table_name = 'DimSpecialty',     @scd_type = 'SCD2';
    EXEC [dwh].[spUpsertSCDDimension] @dim_table_name = 'DimLegalEntity',   @scd_type = 'SCD2';
    EXEC [dwh].[spUpsertSCDDimension] @dim_table_name = 'DimActivityType',  @scd_type = 'SCD2';
    EXEC [dwh].[spUpsertSCDDimension] @dim_table_name = 'DimAeSeriousness', @scd_type = 'SCD2';
    EXEC [dwh].[spUpsertSCDDimension] @dim_table_name = 'DimAeOutcome',     @scd_type = 'SCD2';
    EXEC [dwh].[spUpsertSCDDimension] @dim_table_name = 'DimReportSource',  @scd_type = 'SCD2';

    ------------------------------------------------------------------
    -- 2. Виміри, залежні від географії
    ------------------------------------------------------------------
    EXEC [dwh].[spUpsertSCDDimension] @dim_table_name = 'DimCity',          @scd_type = 'SCD2';
    EXEC [dwh].[spUpsertSCDDimension] @dim_table_name = 'DimLpu',           @scd_type = 'SCD2';

    ------------------------------------------------------------------
    -- 3. Основні master-виміри
    ------------------------------------------------------------------
    EXEC [dwh].[spUpsertSCDDimension] @dim_table_name = 'DimProduct',       @scd_type = 'SCD2';
    EXEC [dwh].[spUpsertSCDDimension] @dim_table_name = 'DimClientAccount', @scd_type = 'SCD2';
    EXEC [dwh].[spUpsertSCDDimension] @dim_table_name = 'DimDoctor',        @scd_type = 'SCD2';

    -- DimEmployee посилається сам на себе (SKEmployeeManagerKeyID):
    -- перший прогін створює рядки, другий проставляє ключі керівників.
    EXEC [dwh].[spUpsertSCDDimension] @dim_table_name = 'DimEmployee',      @scd_type = 'SCD2';
    EXEC [dwh].[spUpsertSCDDimension] @dim_table_name = 'DimEmployee',      @scd_type = 'SCD2';

    ------------------------------------------------------------------
    -- 4. Reference-таблиці (ключ джерела -> durable key)
    ------------------------------------------------------------------
    EXEC [dwh].[spUpsertSCDDimension] @dim_table_name = 'RefProduct',       @scd_type = 'SCD2';
    EXEC [dwh].[spUpsertSCDDimension] @dim_table_name = 'RefClientAccount', @scd_type = 'SCD2';
    EXEC [dwh].[spUpsertSCDDimension] @dim_table_name = 'RefDoctor',        @scd_type = 'SCD2';
    EXEC [dwh].[spUpsertSCDDimension] @dim_table_name = 'RefEmployee',      @scd_type = 'SCD2';
    EXEC [dwh].[spUpsertSCDDimension] @dim_table_name = 'RefMovementType',  @scd_type = 'SCD2';

    -- DimWarehouse тягне власника-дистриб'ютора через RefClientAccount,
    -- тому йде після нього; RefWarehouse — уже після самого виміру.
    EXEC [dwh].[spUpsertSCDDimension] @dim_table_name = 'DimWarehouse',     @scd_type = 'SCD2';
    EXEC [dwh].[spUpsertSCDDimension] @dim_table_name = 'RefWarehouse',     @scd_type = 'SCD2';

    ------------------------------------------------------------------
    -- 5. Факти (повне перезавантаження)
    ------------------------------------------------------------------
    EXEC [dwh].[spFullFct] @fct_table_name = 'FctSales',             @load_id = @load_id;
    EXEC [dwh].[spFullFct] @fct_table_name = 'FctInventoryMovement', @load_id = @load_id;
    EXEC [dwh].[spFullFct] @fct_table_name = 'FctVisit',             @load_id = @load_id;
    EXEC [dwh].[spFullFct] @fct_table_name = 'FctPrescription',      @load_id = @load_id;
    EXEC [dwh].[spFullFct] @fct_table_name = 'FctAdverseEvent',      @load_id = @load_id;
END
GO
