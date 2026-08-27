# Pharma Sales — Sample Data Warehouse (star schema)

Автономний **приклад моделі даних** для фармацевтичного sales/CRM домену:
**5 фактових** і **5 вимірних** таблиць, DDL, генератор синтетичних даних і
візуальна ER-схема зв'язків.

Модель відтворює конвенції реальних Azure Fabric DWH-репозиторіїв : схема `[dwh]`, T-SQL для Microsoft
Fabric Warehouse, Kimball-виміри типу **SCD Type 2** з durable-ключами, member `-1`
для невідомих значень, аудитні колонки `CreatedBy/CreatedAt/ModifiedBy/ModifiedAt`.

## Що всередині

```
pharma-sales-dwh-sample/
├── README.md
├── ddl/
│   ├── 00_schema.sql              -- створення схеми [dwh]
│   ├── build_all.sql              -- майстер-скрипт (SQLCMD :r), порядок dim -> fact
│   ├── dimensions/                -- 5 вимірів
│   │   ├── DimDate.sql
│   │   ├── DimEmployee.sql
│   │   ├── DimClientAccount.sql
│   │   ├── DimProduct.sql
│   │   └── DimActivityType.sql
│   └── facts/                     -- 5 фактів
│       ├── FctSales.sql
│       ├── FctSalesPlan.sql
│       ├── FctVisit.sql
│       ├── FctTargetFrequency.sql
│       └── FctInventorySnapshot.sql
├── scripts/
│   └── generate_sample_data.py    -- генератор даних (тільки stdlib, детермінований)
├── docs/
│   ├── er_diagram.md              -- ВІЗУАЛЬНА ER-схема (Mermaid) + bus matrix
│   └── sample_queries.sql         -- приклади аналітичних запитів
└── data/                          -- згенеровані CSV + insert_sample_data.sql (не в git)
```

## Модель даних

**Виміри (5):** `DimDate`, `DimEmployee`, `DimClientAccount`, `DimProduct`, `DimActivityType`.
**Факти (5):** `FctSales`, `FctSalesPlan`, `FctVisit`, `FctTargetFrequency`, `FctInventorySnapshot`.

Візуальна схема зв'язків — [`docs/er_diagram.md`](docs/er_diagram.md) (Mermaid ERD +
Kimball bus matrix). Нижче — стисла bus matrix:

| Fact \ Dimension        | DimDate | DimEmployee | DimClientAccount | DimProduct | DimActivityType |
|-------------------------|:-------:|:-----------:|:----------------:|:----------:|:---------------:|
| FctSales                |   ✔     |     ✔       |        ✔         |     ✔      |                 |
| FctSalesPlan            |   ✔     |     ✔       |                  |     ✔      |                 |
| FctVisit                |   ✔     |     ✔       |        ✔         |            |       ✔         |
| FctTargetFrequency      |   ✔     |     ✔       |        ✔         |            |       ✔         |
| FctInventorySnapshot    |   ✔     |             |        ✔         |     ✔      |                 |

### Ключові конвенції моделювання
- **Surrogate-ключі:** `SK<Name>ID` — PK версії рядка; `SK<Name>KeyID` — durable-ключ,
  стабільний між версіями SCD2. **Факти посилаються саме на `SK*KeyID`.**
- **SCD Type 2:** виміри історизуються через `StartDate`/`EndDate` (`EndDate IS NULL` = поточна версія).
- **SCD Type 1:** `DimLpu` перезаписується на місці — демо різниці підходів у [`docs/scd1_demo.md`](docs/scd1_demo.md).
- **Unknown member:** у кожному вимірі є рядок `-1` для orphan-фактів (гарантує inner join без втрат).
- **DimDate** — статичний календар (`SKDateKeyID` у форматі `yyyymmdd`), без SCD.
- **Grain фактів** описаний у шапці кожного `.sql` та в `docs/er_diagram.md`.

## Як запустити

### 1. Створити таблиці
Виконайте DDL у цільовій БД (Microsoft Fabric Warehouse / Azure SQL / SQL Server 2019+).
В Azure Data Studio або SSMS у **SQLCMD mode**:

```sql
-- з каталогу ddl/
:r ./build_all.sql
```
Або виконайте файли вручну в порядку: `00_schema.sql` → усі `dimensions/*` → усі `facts/*`.

### 2. Згенерувати синтетичні дані
```bash
cd scripts
python3 generate_sample_data.py            # за замовчуванням ~15k рядків -> ../data
# опції:
python3 generate_sample_data.py --clients 500 --sales-rows 20000 --seed 7
```
Генератор (лише стандартна бібліотека Python 3.9+, детермінований за seed) створює:
- по одному **CSV** на таблицю (`data/<Table>.csv`) — для bulk-load/перегляду;
- **`data/insert_sample_data.sql`** — готовий T-SQL INSERT-скрипт (dim→fact порядок).

### 2b. Догенерувати дані (append)

`02b_generate_more_data.sql` — інкрементальний генератор для ERP-джерела: не робить
`TRUNCATE`, продовжує наскрізну нумерацію бізнес-ключів, додає факти за новий період,
опційно нових клієнтів/лікарів і нові версії цін продуктів (SCD2-демо). Обсяги — у секції
CONFIG на початку файла. Після нього — `EXEC [dwh].[spSilverFullLoad]`.

### 3. Завантажити дані
Виконайте згенерований скрипт **після** DDL:
```sql
-- з каталогу data/
:r ./insert_sample_data.sql
```
або завантажте CSV через `COPY INTO` (Fabric) / `BULK INSERT` (SQL Server) / bcp.

## Гарантії якості даних
- **Референційна цілісність:** усі FK у фактах вказують на існуючі durable-ключі вимірів.
- **Детермінізм:** однаковий `--seed` → ідентичні дані.
- **Реалістичність:** ціни/суми узгоджені (`NetAmount = Gross − Discount`, `StockValue = OnHand × UnitPrice`),
  демонструється SCD2-історія (частина співробітників має закриту + поточну версію).

## Silver level (Fabric Warehouse)

Поверх ERP-джерела зі скриптів `01_ddl_azure_sql.sql` → `02_generate_data_fixed.sql`
побудована **silver-модель** для Microsoft Fabric Warehouse `whsilverad.dwh`:
23 виміри, 6 reference-таблиць маппінгу і 5 фактів, з SCD2 + durable-ключами,
unknown member `-1` та прапорцями якості даних.

```
fabric-migrations/flyway/
├── flyway.conf
└── migrations/
    ├── V260819.1000__silver_init_creation_create_table.sql   -- Dim / Ref / Fct + DimDate
    ├── V260819.1010__silver_init_creation_insert.sql         -- рядки -1 + статичні виміри
    ├── V260819.1020__silver_init_creation_create_view.sql    -- v* view над bronze
    ├── V260819.1030__silver_init_creation_create_prc.sql     -- spUpsertSCDDimension / spFullFct
    ├── V260819.1040__silver_insert_DimDate.sql               -- календар
    ├── V260819.1050__silver_create_prc_full_load.sql         -- spSilverFullLoad
    ├── V260820.0930__silver_alter_fct_views_src_system.sql   -- fix: vFct* не залежать від DimSrcSystem
    ├── V260820.1115__silver_alter_views_bronze_source.sql    -- fix: bronze = [lhbronze].[erp_erp]
    ├── V260821.1030__silver_create_etl_orchestration.sql     -- EtlSilverObject + spSilverLoadLevel
    ├── V260821.1600__bronze_create_etl_metadata.sql          -- EtlBronzeObject (реєстр для bronze)
    ├── V260825.1100__silver_create_dependency_graph.sql      -- граф залежностей + spSilverLoadSubset
    ├── V260826.1030__silver_incremental_fct_load.sql         -- інкремент фактів (watermark SrcModifiedAt)
    ├── V260826.1600__gold_init_creation.sql                  -- gold (whgold.dwh): 6 вимірів + 7 агрегатів
    ├── V260826.1610__gold_create_views_and_prc.sql           -- gold: v*, EtlGoldObject, spGoldLoadLevel
    ├── V260827.0930__gold_drop_legacy_schema_in_silver.sql   -- прибирання старої схеми [gold] у whsilver
    └── V260827.1400__silver_enable_scd1_dimlpu.sql           -- SCD1 для DimLpu (демо історизації)

fabric-pipelines/
├── PL_Bronze_Ingest.json                                     -- Azure SQL -> bronze -> тригер silver
├── PL_Silver_Full_Load.json                                  -- silver (Lookup + ForEach по рівнях)
└── PL_Gold_Full_Load.json                                    -- gold (Lookup + ForEach по рівнях)
```

Опис моделі, ER-схема, bus matrix, порядок завантаження та обробка дефектів джерела —
[`docs/silver_model.md`](docs/silver_model.md). Gold-рівень — [`docs/gold_model.md`](docs/gold_model.md).
Опис даних для бізнес-користувачів (джерело, silver, gold, прапорці якості) —
[`docs/data_dictionary.md`](docs/data_dictionary.md).

### Запуск silver

**Крок 1 — міграції.** Створюють таблиці, view і процедури, наповнюють `DimDate` та статичні
виміри. Дані з bronze вони **не завантажують**; зокрема `V260819.1050` лише створює
процедуру `spSilverFullLoad`, а не виконує її.

**Крок 2 — завантаження.** Оркестрація metadata-driven: склад і порядок беруться з
`dwh.EtlSilverObject` (7 рівнів топологічного сортування), кожен запуск пишеться в
`dwh.EtlSilverLoadLog`. Вручну:

```sql
EXEC [dwh].[spSilverFullLoad] @load_id = 'manual_full_load';   -- усі рівні
EXEC [dwh].[spSilverLoadLevel] @level = 5, @load_id = 'retry'; -- рестарт з рівня
-- перезавантажити одне джерело з усіма залежностями:
EXEC [dwh].[spSilverLoadSubset] @root_object = 'lhbronze.erp_erp.CUSTOMERS', @load_id = 'reload_customers';
-- інкремент фактів (тільки нові/змінені рядки):
EXEC [dwh].[spSilverLoadSubset] @root_object = NULL, @load_id = 'nightly', @force_full = 0;
```

Регулярно — через Fabric Data Pipeline `fabric-pipelines/PL_Silver_Full_Load.json`
(Lookup рівнів -> ForEach -> Script `spSilverLoadLevel`, `load_id = @pipeline().RunId`).

Увесь ланцюг за один запуск — `fabric-pipelines/PL_Bronze_Ingest.json`: копіює 10 таблиць
`erp` з Azure SQL у `lhbronze.erp_erp` (перелік — з `dwh.EtlBronzeObject`, паралельно по 4)
і після успіху викликає `PL_Silver_Full_Load`. Розклад вішайте саме на нього.

**Крок 3 — gold.** Агрегати для звітності — в окремому warehouse `whgold`, схема `dwh`
(окремий pipeline або вручну, з контексту `whgold`):

```sql
EXEC [dwh].[spGoldFullLoad] @load_id = 'manual_gold_full_load';
```

**Крок 4 — перевірка:**

```sql
SELECT 'FctSales', COUNT(*) FROM [dwh].[FctSales]
UNION ALL SELECT 'DimClientAccount', COUNT(*) FROM [dwh].[DimClientAccount] WHERE SKClientAccountID <> -1;
```

## Приклади аналітики
Див. [`docs/sample_queries.sql`](docs/sample_queries.sql): продажі vs план, виконання
call-плану (факт-візити vs `FctTargetFrequency`), залишки на складі тощо.
