# Pharma Sales DWH — прототип на Microsoft Fabric

Наскрізний прототип фармацевтичного sales/CRM сховища: **Azure SQL → bronze → silver → gold →
семантична модель для Copilot**, з міграціями Flyway, metadata-driven оркестрацією та
Data Pipeline'ами.

Конвенції відтворюють реальний Fabric DWH-репозиторій: SCD Type 2 з durable-ключами,
member `-1` для невідомих значень, аудитні колонки `CreatedBy/CreatedAt/ModifiedBy/ModifiedAt`,
міграції формату `V<YYMMDD>.<HHMM>__<опис>.sql`.

## Що всередині

```
pharma-sales-dwh-sample/
├── 01_ddl_azure_sql.sql            -- джерело: DDL схеми [erp]
├── 02_generate_data_fixed.sql      -- джерело: генератор даних (TRUNCATE + повна генерація)
├── 02b_generate_more_data.sql      -- джерело: догенерація без TRUNCATE (append-only)
├── 03_analytics_queries.sql        -- перевірочні запити до джерела
├── ddl/                            -- знімок DDL задеплоєної моделі (silver + gold)
├── fabric-migrations/flyway/       -- міграції: усе, що реально розгортає середовище
├── fabric-pipelines/               -- Data Pipeline (JSON)
├── fabric-semantic-model/          -- TMDL семантичної моделі PharmaSalesGold
└── docs/                           -- моделі, залежності, словник даних, промпти, передача
```

## Модель даних

Три шари в Microsoft Fabric:

| Шар | Де | Склад |
|---|---|---|
| **Джерело** | Azure SQL, схема `erp` | 10 таблиць облікової системи з навмисними дефектами |
| **Bronze** | `lhbronze.erp_erp` | 1:1 копія джерела + технічні колонки `Tech*` |
| **Silver** | `whsilver.dwh` | 23 виміри, 6 Ref-таблиць маппінгу, 5 фактів; SCD2 + durable-ключі |
| **Gold** | `whgold.dwh` | 6 денормалізованих вимірів, 7 агрегатів |
| **Семантична модель** | `PharmaSalesGold` | 13 таблиць, 35 мір, синоніми для Copilot |

**Факти silver:** `FctSales` (рядок замовлення), `FctInventoryMovement` (складський рух),
`FctVisit` (активність), `FctPrescription` (призначення), `FctAdverseEvent` (версія кейсу).

**Агрегати gold:** `AggSalesDaily`, `AggSalesMonthly`, `AggVisitMonthly`,
`AggPrescriptionMonthly`, `AggInventoryMonthly`, `AggAdverseEventMonthly`,
`AggPromoEffectMonthly`.

ER-схеми всіх трьох шарів і bus matrix — [`docs/er_diagram.md`](docs/er_diagram.md).
Знімок DDL задеплоєної моделі — [`ddl/`](ddl/README.md).

### Ключові конвенції моделювання
- **Surrogate-ключі:** `SK<Name>ID` — версія рядка; `SK<Name>KeyID` — durable-ключ,
  стабільний між версіями SCD2. **Факти посилаються саме на `SK*KeyID`.**
- **SCD Type 2** для всіх вимірів: `StartDate`/`EndDate`, поточна версія — `EndDate IS NULL`.
- **SCD Type 1** для `DimLpu` — перезапис на місці, демо різниці підходів
  ([`docs/scd1_demo.md`](docs/scd1_demo.md)).
- **Ref-шар:** `Ref<Entity>` зводить коди джерела до «золотого» запису, тому дублі клієнтів
  і лікарів не розмножують факти.
- **Unknown member:** рядок `-1` у кожному вимірі — orphan-факти не зникають зі звітів.
- **Прапорці якості:** silver нічого не викидає, а позначає (`IsSrcDuplicate`,
  `IsAmountConsistent`, `IsPeriodOutOfRange`, `IsQtyOutlier`, `IsLogicalError`).
- **Інкремент:** факти вантажаться по watermark `SrcModifiedAt`, виміри звіряються повністю.

## Як запустити

### 1. Джерело (Azure SQL)
```sql
-- 01_ddl_azure_sql.sql   -- створює схему [erp] і 10 таблиць
-- 02_generate_data_fixed.sql  -- наповнює (увага: починається з TRUNCATE усіх таблиць)
```
Догенерувати дані пізніше, не стираючи наявні — `02b_generate_more_data.sql`:
продовжує наскрізну нумерацію бізнес-ключів, додає факти за новий період, опційно нових
клієнтів і лікарів та нові версії цін (демо SCD2). Обсяги — у секції CONFIG на початку файла.

### 2. Міграції
Прогнати `fabric-migrations/flyway/migrations` — silver-міграції виконуються в контексті
`whsilver`, gold-міграції починаються з `USE [whgold]`. Міграції створюють таблиці, view,
процедури, наповнюють календар і статичні виміри, але **дані з bronze не завантажують**.

### 3. Завантаження
```sql
-- bronze: PL_Bronze_Ingest (параметр source_table = '' -> усі 10 таблиць)
EXEC [dwh].[spSilverFullLoad] @load_id = 'init';   -- silver, у whsilver
EXEC [dwh].[spGoldFullLoad]   @load_id = 'init';   -- gold, у whgold
```

## Silver level (Fabric Warehouse)

Поверх ERP-джерела зі скриптів `01_ddl_azure_sql.sql` → `02_generate_data_fixed.sql`
побудована **silver-модель** для Microsoft Fabric Warehouse `whsilver.dwh`:
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
    ├── V260827.1400__silver_enable_scd1_dimlpu.sql           -- SCD1 для DimLpu (демо історизації)
    └── V260828.1000__gold_add_month_date_key.sql             -- MonthStartDate у місячних агрегатах

fabric-semantic-model/
└── PharmaSalesGold.SemanticModel/                            -- TMDL: 13 таблиць, 35 мір, синоніми

fabric-pipelines/
├── PL_Bronze_Ingest.json                                     -- Azure SQL -> bronze -> тригер silver
├── PL_Silver_Full_Load.json                                  -- silver (Lookup + ForEach по рівнях)
└── PL_Gold_Full_Load.json                                    -- gold (Lookup + ForEach по рівнях)
```

**Стан проєкту, ідентифікатори середовища та відкриті пункти — [`docs/handover.md`](docs/handover.md).**

Промпти для ad-hoc звітності в Copilot — [`docs/copilot_prompts.md`](docs/copilot_prompts.md),
налаштування Fabric data agent — [`docs/fabric_agent.md`](docs/fabric_agent.md),
семантична модель над gold — [`docs/semantic_model.md`](docs/semantic_model.md).
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

- [`03_analytics_queries.sql`](03_analytics_queries.sql) — перевірочні запити до **джерела**
  (демонструють дублі, orphan-ключі та SCD2-версії до очищення).
- [`docs/copilot_prompts.md`](docs/copilot_prompts.md) — 50 промптів для ad-hoc звітності
  над gold через Copilot.

## Легасі

`scripts/generate_sample_data.py`, `data/`, `docs/sample_queries.sql` лишилися від початкового
навчального прикладу «5 фактів + 5 вимірів» (`FctSalesPlan`, `FctTargetFrequency`,
`FctInventorySnapshot`), якого в задеплоєній моделі немає. Ці файли ні на що не впливають
і підлягають видаленню.
