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
    └── V260820.0930__silver_alter_fct_views_src_system.sql   -- fix: vFct* не залежать від DimSrcSystem
```

Опис моделі, ER-схема, bus matrix, порядок завантаження та обробка дефектів джерела —
[`docs/silver_model.md`](docs/silver_model.md). Запуск завантаження після міграцій:

```sql
EXEC [dwh].[spSilverFullLoad] @load_id = 'manual_full_load';
```

## Приклади аналітики
Див. [`docs/sample_queries.sql`](docs/sample_queries.sql): продажі vs план, виконання
call-плану (факт-візити vs `FctTargetFrequency`), залишки на складі тощо.
