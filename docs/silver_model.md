# Silver level — Microsoft Fabric Warehouse (`whsilverad.dwh`)

Модель silver-рівня для джерела **Pharma ERP** (Azure SQL, схема `[erp]`), створеного
скриптами `01_ddl_azure_sql.sql` (DDL) та `02_generate_data_fixed.sql` (наповнення).

Конвенції неймінгу, технічних колонок і процедур завантаження — ті самі, що в
`grp-ctl-azure-dwh/fabric-migrations/flyway/migrations`.

---

## 1. Потік даних

```
Azure SQL [erp].*            ->  Bronze lakehouse                ->  Silver warehouse
(10 таблиць ERP)                 lhbronze.erp_erp.*                  whsilverad.dwh.*
                                 (1:1 копія, без трансформацій)      (Dim / Ref / Fct)

PL_Bronze_Ingest (Copy, Overwrite) -----> PL_Silver_Full_Load (spSilverLoadLevel по рівнях)
```

Silver читає bronze **тільки через view** `dwh.v<ObjectName>`; таблиці наповнюються
процедурами `spUpsertSCDDimension` (виміри та Ref) і `spFullFct` (факти).

Очікуваний контракт bronze — таблиці з тими самими іменами й колонками, що в `[erp]`:
`PRODUCTS`, `CUSTOMERS`, `DOCTORS`, `EMPLOYEES`, `WAREHOUSES`, `SALES_ORDERS`,
`INVENTORY_MOVEMENTS`, `DOCTOR_VISITS`, `PRESCRIPTIONS`, `ADVERSE_EVENTS`
(включно з `row_id`, `created_at`, `updated_at`).

Крім них bronze-провіженер додає на початок кожної таблиці чотири технічні колонки
(та сама конвенція, що в `grp-ctl-azure-dwh/fabric-migrations/flyway/lh-provisioner`):

| Колонка | Тип | Призначення |
|---|---|---|
| `TechExecutorRunID` | string | ідентифікатор запуску виконавця завантаження |
| `TechProcessorRunID` | string | ідентифікатор запуску обробника |
| `TechProcessingDateTime` | timestamp | коли рядок потрапив у bronze |
| `TechBusinessDateTime` | timestamp | бізнес-дата завантаження |

Silver їх **не читає і не переносить**: усі `v*` мають явні списки колонок, `alias.*`
трапляється лише всередині CTE і до фінальної проєкції не доходить. Тому поява цих
колонок нічого в silver не змінює — але їх треба зберігати при будь-якому
перезаписі bronze (див. розділ 8).

## 2. Конвенції

| Елемент | Правило |
|---|---|
| Схема | `whsilverad.dwh` |
| Вимір | `Dim<Entity>`; ключі `SK<Entity>ID` (версія рядка) + `SK<Entity>KeyID` (durable key) |
| Довідник маппінгу | `Ref<Entity>`; ключі `SKRef<Entity>ID` + `SKRef<Entity>KeyID`, плюс `SKSrcSystemKeyID` та `SK<Entity>KeyID` на "золотий" запис |
| Факт | `Fct<Entity>`; ключ `SKFct<Entity>ID`, посилання **тільки на `SK*KeyID`** |
| Джерельний view | `v<TableName>`, **перша колонка = натуральний ключ `Id`** (за нею процедура визначає NK) |
| Технічні колонки Dim/Ref | `StartDate`, `EndDate`, `IsDeleted`, `CreatedBy`, `ModifiedBy`, `CreatedAt`, `ModifiedAt` |
| Технічні колонки Fct | `CreatedBy`, `CreatedAt` |
| Історизація | SCD2 (типово): активна версія — `EndDate IS NULL`; зникнення в джерелі -> `IsDeleted = 1`. SCD1 (`DimLpu`): перезапис на місці, `EndDate` завжди порожній — див. [`scd1_demo.md`](scd1_demo.md) |
| Unknown member | рядок `-1` у кожному Dim/Ref (+ `SKDateID = -1` у `DimDate`) |
| Значення за замовчуванням | текст -> `'N/A'`, ключ -> `-1` (усі `SK*KeyID` у view обгорнуті в `ISNULL(..., -1)`) |

## 3. Склад моделі

**Статичні виміри (керований словник, наповнюються міграцією, без view):**
`DimDate`, `DimSrcSystem`, `DimCurrency`, `DimAtcClass`, `DimMovementType`, `DimOrderStatus`.

**Виміри з джерела (SCD2, наповнюються `spUpsertSCDDimension`):**
`DimRegion`, `DimCity`, `DimTerritory`, `DimChain`, `DimLegalEntity`, `DimManufacturer`,
`DimProduct`, `DimClientAccount`, `DimSpecialty`, `DimLpu`, `DimDoctor`, `DimEmployee`,
`DimWarehouse`, `DimActivityType`, `DimAeSeriousness`, `DimAeOutcome`, `DimReportSource`.

**Reference-таблиці (ключ джерела -> durable key):**
`RefProduct`, `RefClientAccount`, `RefDoctor`, `RefEmployee`, `RefWarehouse`, `RefMovementType`.

**Факти:**

| Факт | Grain | Джерело |
|---|---|---|
| `FctSales` | рядок замовлення (`order_line_id`, дедупльований) | `SALES_ORDERS` |
| `FctInventoryMovement` | складський рух (`movement_id`) | `INVENTORY_MOVEMENTS` |
| `FctVisit` | візит/активність (`visit_id`) | `DOCTOR_VISITS` |
| `FctPrescription` | призначення (`prescription_id`) | `PRESCRIPTIONS` |
| `FctAdverseEvent` | версія кейсу (`ae_id` + `case_version`) | `ADVERSE_EVENTS` |

## 4. Bus matrix

| Fct \ Dim | Date | Product | ClientAccount | Warehouse | Employee | Doctor | ActivityType | OrderStatus | MovementType | Currency | Region | AE-виміри |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| FctSales | ✔ | ✔ | ✔ | ✔ | ✔ | | | ✔ | | ✔ | | |
| FctInventoryMovement | ✔ | ✔ | | ✔ | ✔ | | | | ✔ | | | |
| FctVisit | ✔ | ✔ | | | ✔ | ✔ | ✔ | | | | | |
| FctPrescription | ✔ | ✔ | | | ✔ | ✔ | | | | | | |
| FctAdverseEvent | ✔ | ✔ | | | | ✔ | | | | | ✔ | ✔ |

## 5. ER-схема

ER-схеми всіх трьох шарів (джерело, silver, gold) і bus matrix — в
[`er_diagram.md`](er_diagram.md), щоб не тримати дві копії однієї діаграми.

## 6. Як silver закриває дефекти джерела

Скрипт `02_generate_data_fixed.sql` навмисно генерує "брудні" дані. Що з ними робить silver:

| Дефект джерела | Обробка в silver |
|---|---|
| SCD2-версії в `PRODUCTS` (кілька рядків на `product_id`) | `vDimProduct` бере актуальну версію (`ROW_NUMBER` по `updated_at DESC`); історію веде вже сам SCD2 виміру |
| Дублі клієнтів (`CST-9xxxx` з тим самим ЄДРПОУ) | golden record за ЄДРПОУ; усі `customer_id` мапляться на нього через `RefClientAccount` (`IsGoldenRecord`, `DimClientAccount.SrcDuplicateCnt`) |
| Дублі лікарів (той самий ПІБ, інший `doctor_id`) | golden record за ПІБ + ЛПУ; маппінг у `RefDoctor` |
| Рядкові дублікати у фактах | дедуп `ROW_NUMBER` по бізнес-ключу + прапорець `IsSrcDuplicate` |
| Orphan-ключі (`CST-7xxxxx`, `WH-9xx`, `DOC-7/8xxxxx`) | `LEFT JOIN` + `ISNULL(..., -1)` -> посилання на unknown member |
| Укр./англ. `movement_type` | `RefMovementType` зводить сирі значення до канонічних `IN/OUT/TRANSFER/WRITEOFF`; знак кількості — `DimMovementType.QtySign` -> `FctInventoryMovement.QtySigned` |
| Некоректні дати (2019, 2028) | зберігаються, але позначені `FctSales.IsPeriodOutOfRange` |
| Розсинхрон `line_amount` | `FctSales.IsAmountConsistent` (порівняння з `Qty * UnitPrice * (1 - Discount)`) |
| Аномальні кількості (> 500k) | `FctInventoryMovement.IsQtyOutlier` |
| Битий ATC (`XX123`) | `DimProduct.IsAtcCodeValid = 0`, `SKAtcClassKeyID = -1` |
| Логічна помилка AE (`Critical` + `Recovered`) | `FctAdverseEvent.IsLogicalError` |
| NULL-и (`region`, `brand_name`, `specialty`, `outcome`) | `'N/A'` в атрибутах, `-1` у ключах |

Дані **не видаляються** — silver позначає проблеми прапорцями, рішення про фільтрацію
ухвалює gold.

## 7. Порядок завантаження

Завантаження — **окремий крок після міграцій**, це два різні етапи:

| Етап | Що робить | Що НЕ робить |
|---|---|---|
| Міграції `V260819.*` / `V260820.*` | створюють таблиці, view, процедури; наповнюють `DimDate` і статичні виміри | **не завантажують дані з bronze** |
| `EXEC [dwh].[spSilverFullLoad]` | наповнює `Dim*`, `Ref*`, `Fct*` з bronze | — |

Зокрема, `V260819.1050__silver_create_prc_full_load.sql` містить лише
`CREATE OR ALTER PROCEDURE [dwh].[spSilverFullLoad]` — його виконання створює процедуру,
але жодного рядка не завантажує. Дані з'являються тільки після виклику:

```sql
EXEC [dwh].[spSilverFullLoad] @load_id = 'manual_full_load';
```

У проді цей виклик робить CTL-workflow; вручну — з будь-якого SQL-редактора Fabric.

Порядок усередині (важливий через залежності між view та вже завантаженими таблицями):

1. `DimRegion`, `DimTerritory`, `DimChain`, `DimManufacturer`, `DimSpecialty`, `DimLegalEntity`,
   `DimActivityType`, `DimAeSeriousness`, `DimAeOutcome`, `DimReportSource`
2. `DimCity`, `DimLpu`
3. `DimProduct`, `DimClientAccount`, `DimDoctor`, `DimEmployee` (двічі — self-reference на керівника)
4. `RefProduct`, `RefClientAccount`, `RefDoctor`, `RefEmployee`, `RefMovementType`,
   далі `DimWarehouse` (потребує `RefClientAccount`) і `RefWarehouse`
5. факти: `FctSales`, `FctInventoryMovement`, `FctVisit`, `FctPrescription`, `FctAdverseEvent`

Повний перелік залежностей між об'єктами (`Object | DependOnObject`) —
[`docs/silver_dependencies.md`](silver_dependencies.md).

## 8. Оркестрація (Fabric Data Pipeline, metadata-driven)

Завантаженням керує реєстр об'єктів у самому warehouse, а не жорсткий список у коді:

| Об'єкт | Призначення |
|---|---|
| `dwh.EtlSilverObject` | реєстр: `ObjectName`, `ObjectType` (Dim/Ref/Fct), `LoadLevel`, `ScdType`, `PassCnt`, `IsActive` |
| `dwh.EtlSilverLoadLog` | журнал: `LoadId`, об'єкт, `StartedAt`/`FinishedAt`, `DurationSec`, `RowCnt`, `Status`, `ErrorMessage` |
| `dwh.spSilverLoadLevel @level, @load_id` | завантажує всі активні об'єкти одного рівня, пише журнал, падає з `THROW` при помилці |
| `dwh.spSilverFullLoad @load_id` | проходить рівні 1..MAX через `spSilverLoadLevel` |

`LoadLevel` — позиція в топологічному сортуванні графа з
[`silver_dependencies.md`](silver_dependencies.md):

| Рівень | Об'єкти |
|---|---|
| 1 | DimActivityType, DimAeOutcome, DimAeSeriousness, DimChain, DimLegalEntity, DimManufacturer, DimRegion, DimReportSource, DimSpecialty, DimTerritory, RefMovementType |
| 2 | DimCity, DimEmployee (`PassCnt = 2`), DimProduct |
| 3 | DimClientAccount, DimLpu, RefEmployee, RefProduct |
| 4 | DimDoctor, RefClientAccount |
| 5 | DimWarehouse, RefDoctor |
| 6 | FctAdverseEvent, FctPrescription, FctVisit, RefWarehouse |
| 7 | FctInventoryMovement, FctSales |

### Pipeline

`fabric-pipelines/PL_Silver_Full_Load.json` — дві активності:

1. **Lookup `LookupLoadLevels`** (`firstRowOnly = false`):
   ```sql
   SELECT DISTINCT LoadLevel FROM [dwh].[EtlSilverObject] WHERE IsActive = 1 ORDER BY LoadLevel
   ```
2. **ForEach `ForEachLoadLevel`** (`isSequential = true`), items `@activity('LookupLoadLevels').output.value`,
   всередині Script activity:
   ```sql
   EXEC [dwh].[spSilverLoadLevel] @level = @{item().LoadLevel}, @load_id = '@{pipeline().RunId}';
   ```

Що це дає:

* **трасування** — `@pipeline().RunId` потрапляє у `CreatedBy` фактів і в `EtlSilverLoadLog`,
  тож будь-який рядок факту прив'язаний до конкретного запуску pipeline;
* **рестарт з рівня** — після падіння запускаєте `EXEC dwh.spSilverLoadLevel @level = N` вручну
  або перезапускаєте pipeline; рівні до N дадуть той самий результат (upsert ідемпотентний);
* **розширення без правки pipeline** — новий вимір додається рядком у `EtlSilverObject`;
* **розклад, retry, алерти** — штатними засобами Fabric (Schedule + Activity retry).

JSON у репозиторії — шаблон: перед імпортом підставте `<FABRIC_WORKSPACE_ID>`,
`<WAREHOUSE_ITEM_ID>`, `<SQL_ENDPOINT>`. Якщо ваша версія Fabric очікує іншу структуру
`linkedService`, швидше зібрати ці дві активності в UI і вставити SQL з полів вище —
логіка оркестрації повністю в warehouse, pipeline лише викликає процедуру.

### Bronze -> silver одним запуском

`fabric-pipelines/PL_Bronze_Ingest.json` — три активності:

1. **Lookup `LookupBronzeObjects`** — перелік таблиць з `dwh.EtlBronzeObject`
   (10 рядків: `erp.<TABLE>` -> `erp_erp.<TABLE>`, режим `Overwrite`);
2. **ForEach `ForEachBronzeTable`** (паралельно, `batchCount = 4`) -> **Copy activity**:
   `SELECT * FROM [@{item().SourceSchema}].[@{item().SourceTable}]` у Lakehouse-таблицю
   `@item().TargetSchema` / `@item().TargetTable` з `tableActionOption: Overwrite`;
3. **Invoke pipeline `InvokeSilverFullLoad`** -> запускає `PL_Silver_Full_Load`
   з `waitOnCompletion: true`, тільки після `Succeeded` усього ForEach.

Розклад вішається на `PL_Bronze_Ingest`; окремий розклад на `PL_Silver_Full_Load`
краще не ставити, щоб silver не завантажувався двічі (запускати його вручну лише
для перезавантаження без переносу bronze).

Copy-активність відтворює конвенції штатного завантажувача `dpl-bronze-sql-load-full`:

* у `sqlReaderQuery` перед `*` додаються чотири технічні колонки —
  `TechExecutorRunID` (параметр `executor_run_id`, за замовчуванням `RunId` цього pipeline),
  `TechProcessorRunID` (`RunId`), `TechProcessingDateTime` (змінна `processing_datetime`,
  київський час через `convertTimeZone(..., 'FLE Standard Time')`),
  `TechBusinessDateTime` (параметр `business_datetime`, за замовчуванням = `processing_datetime`);
* `tableActionOption: OverwriteSchema` замість `Overwrite`;
* `allowDataTruncation: true`, `applyVOrder: false`, `enableTimestampNtz: false`.

Завдяки цьому наш перенос не ламає контракт bronze: схема таблиці лишається тією самою,
що її створює штатний завантажувач.

Чого свідомо **не** перенесено з `dpl-bronze-sql-load-full`: двоетапності
`Azure SQL -> lhbronzestg -> lhbronze`. У нашому pipeline копія йде одразу в `lhbronze`,
бо staging потрібен їхньому процесу для порівняння зі snapshot і ведення history-лейкхаусу,
а тут таблиця просто перезаписується. Якщо потрібна повна відповідність стандарту —
додається ще одна Copy-активність зі staging-лейкхаусом.

Повне перезавантаження bronze обране свідомо: джерело не має надійного watermark
(`updated_at` мутують дефектні `UPDATE`-и генератора), а обсяги — сотні тисяч рядків.
Для інкременту достатньо замінити `sqlReaderQuery` на фільтр по `row_id` більше
збереженого максимуму й змінити `tableActionOption` на `Append`.

Плейсхолдери перед імпортом: `<AZURE_SQL_CONNECTION_ID>`, `<BRONZE_LAKEHOUSE_ITEM_ID>`,
`<SILVER_PIPELINE_ITEM_ID>`, `<FABRIC_PIPELINE_CONNECTION_ID>` (з'єднання для Invoke Pipeline).

### Перезавантаження одного джерела з усіма залежностями

Граф залежностей живе в базі, тому «перевантажити джерело X» = «перевантажити X і все,
що з нього походить»:

| Обʼєкт | Призначення |
|---|---|
| `dwh.EtlObjectDependency` | 96 ребер `ObjectName -> DependsOnObject` (згенеровані з визначень `v*`) |
| `dwh.EtlObjectDownstream` | матеріалізоване транзитивне замикання `RootObject -> ObjectName` |
| `dwh.spRefreshObjectClosure` | перераховує замикання (WHILE-фікспойнт: рекурсивні CTE у Fabric Warehouse не підтримуються) |
| `dwh.spSilverLoadSubset @root_object, @load_id` | вантажить лише замикання кореня, у тому ж порядку рівнів |

```sql
-- усе, що залежить від однієї bronze-таблиці
EXEC [dwh].[spSilverLoadSubset] @root_object = 'lhbronze.erp_erp.CUSTOMERS', @load_id = 'reload_customers';

-- усе, що залежить від одного silver-виміру (включно з ним самим)
EXEC [dwh].[spSilverLoadSubset] @root_object = 'dwh.DimRegion', @load_id = 'reload_region';

-- що саме перезавантажиться
SELECT o.LoadLevel, d.ObjectName
FROM [dwh].[EtlObjectDownstream] d
JOIN [dwh].[EtlSilverObject] o ON o.ObjectName = d.ObjectName AND o.IsActive = 1
WHERE d.RootObject = 'lhbronze.erp_erp.CUSTOMERS'
ORDER BY o.LoadLevel, d.ObjectName;

-- доступні корені
SELECT DISTINCT RootObject FROM [dwh].[EtlObjectDownstream] ORDER BY RootObject;
```

Розміри замикань дуже різні — це наслідок спільних вимірів, а не помилка:

| Корінь | Скільки silver-обʼєктів перевантажиться |
|---|---|
| `lhbronze.erp_erp.SALES_ORDERS` | 1 (`FctSales`) |
| `lhbronze.erp_erp.PRODUCTS` | 8 |
| `lhbronze.erp_erp.CUSTOMERS` | 16 (через `DimRegion`/`DimCity`, які збираються з кількох джерел) |
| `lhbronze.erp_erp.ADVERSE_EVENTS` | 17 (теж живить `DimRegion`) |
| `dwh.RefProduct` | 6 |

### Точкове перезавантаження через pipeline

Обидва pipeline параметризовані:

* `PL_Bronze_Ingest`, параметр **`source_table`**: `''` — усі 10 таблиць і повне завантаження
  silver; `'CUSTOMERS'` — перекопіювати лише цю таблицю і передати
  `root_object = 'lhbronze.erp_erp.CUSTOMERS'` у silver;
* `PL_Silver_Full_Load`, параметр **`root_object`**: `''` — повне завантаження;
  `'lhbronze.erp_erp.CUSTOMERS'` або `'dwh.DimRegion'` — лише замикання кореня
  (Lookup рівнів фільтрується по `EtlObjectDownstream`, `spSilverLoadLevel` отримує `@root_object`).

Після зміни `v*` або появи нового обʼєкта: оновити рядки в `EtlObjectDependency`
і виконати `EXEC [dwh].[spRefreshObjectClosure]`.

### Інкрементальне завантаження фактів

| Обʼєкт | Роль |
|---|---|
| `Fct*.SrcModifiedAt` | watermark-колонка (= `erp.<table>.updated_at` з bronze), остання в таблиці й у `vFct*` |
| `dwh.EtlSilverWatermark` | останнє оброблене значення watermark по кожному факту |
| `dwh.spIncrementalFct` | вантажить зріз `SrcModifiedAt > watermark`: `DELETE` по `ItemId` + `INSERT`, далі просуває watermark |
| `dwh.spSetWatermarkFromTable` | вирівнює watermark після повного перезавантаження |
| `EtlSilverObject.LoadStrategy` | `Full` / `Incremental`; `WatermarkColumn` — назва колонки |
| `@force_full` | параметр `spSilverLoadLevel` / `spSilverLoadSubset` / `spSilverFullLoad` — ігнорує стратегію і перезаписує факти цілком |

```sql
-- інкремент (тільки нові/змінені рядки фактів)
EXEC [dwh].[spSilverLoadSubset] @root_object = NULL, @load_id = 'nightly', @force_full = 0;

-- повне перезавантаження (за замовчуванням)
EXEC [dwh].[spSilverFullLoad] @load_id = 'weekly_full';

-- стан watermark
SELECT * FROM [dwh].[EtlSilverWatermark] ORDER BY ObjectName;
```

**Виміри лишаються повними — і це не спрощення.** `spUpsertSCDDimension` закриває
(`IsDeleted = 1`) рядки, яких немає у джерельному view. Якщо відфільтрувати view по
watermark, усі незмінені рядки зникнуть із джерела і будуть помилково позначені видаленими.
SCD2 і так записує лише реальні зміни, тому повне порівняння тут — коректний режим.

Обмеження інкременту, які треба тримати в голові:

* **видалення в джерелі не видно** — рядок, стертий в `erp`, лишиться у факті до
  наступного `@force_full = 1`; тому повне перезавантаження варто лишити за розкладом
  (наприклад, щотижня) поряд із щоденним інкрементом;
* **зміна без оновлення `updated_at` не потрапить у зріз** — саме так поводяться
  `UPDATE`-и, що імітують дефекти в `02_generate_data_fixed.sql`;
* **`Tech*` колонки bronze для watermark не годяться** — bronze перезаписується повністю
  (`OverwriteSchema`), тож `TechProcessingDateTime` оновлюється в усіх рядків одночасно
  і зріз дорівнював би повній таблиці.

Після деплою міграції один раз потрібен повний прогін
(`EXEC [dwh].[spSilverFullLoad] @load_id = 'init_after_incremental'`) — він заповнить
`SrcModifiedAt` у вже завантажених рядках і вирівняє watermark.

### Контроль після запуску

```sql
SELECT LoadLevel, ObjectName, Status, RowCnt, DurationSec, ErrorMessage
FROM [dwh].[EtlSilverLoadLog]
WHERE LoadId = '<RunId>'
ORDER BY LoadLevel, StartedAt;
```

## 9. Міграції

| Файл | Вміст |
|---|---|
| `V260819.1000__silver_init_creation_create_table.sql` | усі таблиці Dim / Ref / Fct + `DimDate` |
| `V260819.1010__silver_init_creation_insert.sql` | рядки `-1` + статичні виміри |
| `V260819.1020__silver_init_creation_create_view.sql` | усі `v*` view над bronze |
| `V260819.1030__silver_init_creation_create_prc.sql` | `spSchemaValidation`, `spUpsertSCDDimension`, `spFullFct` |
| `V260819.1040__silver_insert_DimDate.sql` | наповнення календаря |
| `V260819.1050__silver_create_prc_full_load.sql` | `spSilverFullLoad` |
| `V260820.0930__silver_alter_fct_views_src_system.sql` | fix: `vFct*` беруть `SKSrcSystemKeyID` через CTE з агрегатом, а не `CROSS JOIN` |
| `V260820.1115__silver_alter_views_bronze_source.sql` | fix: перевизначення всіх 28 view на реальне bronze-джерело `[lhbronze].[erp_erp]` |
| `V260821.1030__silver_create_etl_orchestration.sql` | `EtlSilverObject`, `EtlSilverLoadLog`, `spSilverLoadLevel`, metadata-driven `spSilverFullLoad` |
| `V260821.1600__bronze_create_etl_metadata.sql` | `EtlBronzeObject` — реєстр таблиць для `PL_Bronze_Ingest` |
| `V260825.1100__silver_create_dependency_graph.sql` | `EtlObjectDependency`, `EtlObjectDownstream`, `spRefreshObjectClosure`, `spSilverLoadSubset`, `@root_object` у `spSilverLoadLevel` |
| `V260826.1030__silver_incremental_fct_load.sql` | `SrcModifiedAt` у фактах, `EtlSilverWatermark`, `spIncrementalFct`, `LoadStrategy`, `@force_full` |
| `V260827.1400__silver_enable_scd1_dimlpu.sql` | виправлена гілка SCD1 у `spUpsertSCDDimension`, `DimLpu` переведено на SCD1 |

Іменування: `V<YYMMDD>.<HHMM>__<опис>.sql`, `flyway.outOfOrder=true`, кожна міграція ідемпотентна.

## 10. Відмінності від прод-репозиторію

* `spFullFct` тут — простий `TRUNCATE + INSERT`; у проді використовується варіант зі swap-таблицею
  (`Fct*_new` -> `sp_rename`), щоб уникнути вікна порожньої таблиці.
* Одна джерельна система (`DimSrcSystem.Id = 1`, `PharmaERP`), тому `Ref*` мають рівно один
  рядок на ключ джерела; структура збережена для сумісності з мультиджерельним завантаженням.
* Провіженінг схем bronze-лейкхаусу (`.sh`-міграції з `lh_provisioner.py`) не входить у цей приклад.
