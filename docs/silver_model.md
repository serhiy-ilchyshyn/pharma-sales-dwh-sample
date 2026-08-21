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
```

Silver читає bronze **тільки через view** `dwh.v<ObjectName>`; таблиці наповнюються
процедурами `spUpsertSCDDimension` (виміри та Ref) і `spFullFct` (факти).

Очікуваний контракт bronze — таблиці з тими самими іменами й колонками, що в `[erp]`:
`PRODUCTS`, `CUSTOMERS`, `DOCTORS`, `EMPLOYEES`, `WAREHOUSES`, `SALES_ORDERS`,
`INVENTORY_MOVEMENTS`, `DOCTOR_VISITS`, `PRESCRIPTIONS`, `ADVERSE_EVENTS`
(включно з `row_id`, `created_at`, `updated_at`).

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
| Історизація | SCD2: активна версія — `EndDate IS NULL`; зникнення в джерелі -> `IsDeleted = 1` |
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

## 5. ER-схема (ключові зв'язки)

```mermaid
erDiagram
    DimDate            ||--o{ FctSales : SKDateID
    DimOrderStatus     ||--o{ FctSales : SKOrderStatusKeyID
    DimCurrency        ||--o{ FctSales : SKCurrencyKeyID
    RefProduct         ||--o{ FctSales : SKRefProductKeyID
    RefClientAccount   ||--o{ FctSales : SKRefClientAccountKeyID
    RefWarehouse       ||--o{ FctSales : SKRefWarehouseKeyID
    RefEmployee        ||--o{ FctSales : SKRefEmployeeKeyID

    RefProduct         ||--o{ FctInventoryMovement : SKRefProductKeyID
    RefWarehouse       ||--o{ FctInventoryMovement : SKRefWarehouseKeyID
    RefEmployee        ||--o{ FctInventoryMovement : SKRefEmployeeKeyID
    RefMovementType    ||--o{ FctInventoryMovement : SKRefMovementTypeKeyID
    DimDate            ||--o{ FctInventoryMovement : SKDateID

    RefDoctor          ||--o{ FctVisit : SKRefDoctorKeyID
    RefEmployee        ||--o{ FctVisit : SKRefEmployeeKeyID
    RefProduct         ||--o{ FctVisit : SKRefProductKeyID
    DimActivityType    ||--o{ FctVisit : SKActivityTypeKeyID
    DimDate            ||--o{ FctVisit : SKDateID

    RefDoctor          ||--o{ FctPrescription : SKRefDoctorKeyID
    RefProduct         ||--o{ FctPrescription : SKRefProductKeyID
    RefEmployee        ||--o{ FctPrescription : SKRefEmployeeKeyID
    DimDate            ||--o{ FctPrescription : SKDateID

    RefProduct         ||--o{ FctAdverseEvent : SKRefProductKeyID
    RefDoctor          ||--o{ FctAdverseEvent : SKRefDoctorKeyID
    DimAeSeriousness   ||--o{ FctAdverseEvent : SKAeSeriousnessKeyID
    DimAeOutcome       ||--o{ FctAdverseEvent : SKAeOutcomeKeyID
    DimReportSource    ||--o{ FctAdverseEvent : SKReportSourceKeyID
    DimRegion          ||--o{ FctAdverseEvent : SKRegionKeyID
    DimDate            ||--o{ FctAdverseEvent : SKDateID

    DimProduct         ||--o{ RefProduct : SKProductKeyID
    DimClientAccount   ||--o{ RefClientAccount : SKClientAccountKeyID
    DimDoctor          ||--o{ RefDoctor : SKDoctorKeyID
    DimEmployee        ||--o{ RefEmployee : SKEmployeeKeyID
    DimWarehouse       ||--o{ RefWarehouse : SKWarehouseKeyID
    DimMovementType    ||--o{ RefMovementType : SKMovementTypeKeyID

    DimManufacturer    ||--o{ DimProduct : SKManufacturerKeyID
    DimAtcClass        ||--o{ DimProduct : SKAtcClassKeyID
    DimChain           ||--o{ DimClientAccount : SKChainKeyID
    DimLegalEntity     ||--o{ DimClientAccount : SKLegalEntityKeyID
    DimCity            ||--o{ DimClientAccount : SKCityKeyID
    DimRegion          ||--o{ DimCity : SKRegionKeyID
    DimSpecialty       ||--o{ DimDoctor : SKSpecialtyKeyID
    DimLpu             ||--o{ DimDoctor : SKLpuKeyID
    DimTerritory       ||--o{ DimEmployee : SKTerritoryKeyID
    DimEmployee        ||--o{ DimEmployee : SKEmployeeManagerKeyID
    DimClientAccount   ||--o{ DimWarehouse : SKClientAccountOwnerKeyID
```

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

Іменування: `V<YYMMDD>.<HHMM>__<опис>.sql`, `flyway.outOfOrder=true`, кожна міграція ідемпотентна.

## 10. Відмінності від прод-репозиторію

* `spFullFct` тут — простий `TRUNCATE + INSERT`; у проді використовується варіант зі swap-таблицею
  (`Fct*_new` -> `sp_rename`), щоб уникнути вікна порожньої таблиці.
* Одна джерельна система (`DimSrcSystem.Id = 1`, `PharmaERP`), тому `Ref*` мають рівно один
  рядок на ключ джерела; структура збережена для сумісності з мультиджерельним завантаженням.
* Провіженінг схем bronze-лейкхаусу (`.sh`-міграції з `lh_provisioner.py`) не входить у цей приклад.
