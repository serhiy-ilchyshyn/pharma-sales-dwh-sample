# Передача проєкту — стан на 28.08.2026

Прототип фармацевтичного DWH у Microsoft Fabric: Azure SQL → bronze → silver → gold →
семантична модель для Copilot. Цей документ — те, чого не видно з коду: що вже працює,
які рішення ухвалені й чому, що лишилось відкритим.

Технічні деталі кожного шару — у сусідніх файлах:
[`silver_model.md`](silver_model.md) · [`gold_model.md`](gold_model.md) ·
[`semantic_model.md`](semantic_model.md) · [`silver_dependencies.md`](silver_dependencies.md) ·
[`data_dictionary.md`](data_dictionary.md) · [`copilot_prompts.md`](copilot_prompts.md) ·
[`scd1_demo.md`](scd1_demo.md) · [`er_diagram.md`](er_diagram.md) · [`fabric_agent.md`](fabric_agent.md) · [`../ddl/README.md`](../ddl/README.md)

---

## 1. Що вже працює в середовищі

| Шар | Стан |
|---|---|
| Джерело Azure SQL `erp` | 10 таблиць, наповнені `02_generate_data_fixed.sql`; догенерація — `02b_generate_more_data.sql` |
| Bronze `lhbronze.erp_erp` | наливається pipeline'ом, дані на місці |
| Silver `whsilver.dwh` | 34 таблиці, 28 view, SCD2 + SCD1, інкремент фактів — задеплоєно, працює |
| Gold `whgold.dwh` | 6 вимірів + 7 агрегатів — задеплоєно, дані є |
| Оркестрація | metadata-driven, pipeline'и в Fabric працюють |
| Семантична модель | `PharmaSalesGold` працює у воркспейсі, Copilot відповідає на промпти. Створена вручну в UI + `deploy_semantic_model.py --item-id`, **у git ще не заведена** — наступний sync її прибере |

## 2. Ідентифікатори середовища

| Об'єкт | Значення |
|---|---|
| Workspace | `343bb55f-11c8-43a8-acba-3ad333a2d07a` |
| Warehouse `whsilver` | `578fc162-5aac-4981-be73-f6a3e928aabf` |
| Lakehouse `lhbronze` | `6c4fcfc9-dc85-4d5e-89b7-7d362bf87501`, схема `erp_erp` |
| Azure SQL | connection `5b8c6fba-3677-4218-a496-fa046222b0b1`, БД `sqldb-ds-dds-d-westeu-01` |
| Pipeline bronze | `dpl-bronze-sql-ingestion` — `bfa7da1c-5a2e-450d-9a76-004fff6802e3` |
| Pipeline silver | `dpl-silver-sql-load` — `a5d81645-aff3-45de-b4f5-5d05c95271fb` |
| Pipeline gold | `dpl-gold-sql-load` — опублікований у воркспейсі |
| Воркспейс | `fcw-plt-dds-d-westeu-01`, git integration підключений (гілка `main`) |
| Warehouse `whgold` | `dc20f929-0e9a-4619-9cf3-4a9fb9117c07` |

## 3. Ключові рішення і чому саме так

**Факти посилаються на durable keys (`SK…KeyID`), а не на ключі версій.**
Інакше зміна атрибута виміру «відривала» б історичні факти від об'єкта.

**Виміри завжди звіряються повністю, інкрементальні лише факти.**
`spUpsertSCDDimension` закриває `IsDeleted = 1` рядки, яких немає у джерельному view.
Якщо відфільтрувати view по watermark, усі незмінені рядки «зникнуть» і будуть помилково
позначені видаленими. SCD2 і так пише лише реальні зміни.

**Watermark інкременту — `updated_at` джерела, а не `TechProcessingDateTime` bronze.**
Bronze перезаписується повністю (`OverwriteSchema`), тож технічна дата оновлюється в усіх
рядків одночасно і зріз дорівнював би повній таблиці. Наслідок: видалення в джерелі
інкремент не бачить — потрібен періодичний `@force_full = 1`.

**Gold — окремий warehouse.** У Fabric писати можна лише в поточну базу, тому gold
виконується у власному контексті (`USE [whgold]`) і читає silver крос-базово.

**Оркестрація metadata-driven.** Склад і порядок беруться з реєстрів
(`EtlSilverObject`, `EtlGoldObject`, `EtlBronzeObject`), pipeline'и лише викликають процедури.
Новий об'єкт = рядок у таблиці, pipeline не чіпаємо.

**Граф залежностей лежить у базі** (`EtlObjectDependency` + матеріалізоване замикання
`EtlObjectDownstream`), тому «перевантажити одне джерело з усіма залежностями» — це
`spSilverLoadSubset @root_object = 'lhbronze.erp_erp.CUSTOMERS'`.

**Bronze-контракт не ламаємо.** Штатний завантажувач `dpl-bronze-sql-load-full` (не наш)
додає чотири `Tech*` колонки. Наш `PL_Bronze_Ingest` теж їх пише і використовує
`OverwriteSchema` — інакше перезапис зносив би схему іншої команди.

## 4. Обмеження Fabric, на які вже наступили

Щоб не витрачати час удруге:

* **немає курсорів** — цикли по пронумерованій `#temp`-таблиці;
* **немає рекурсивних CTE** — транзитивне замикання рахується WHILE-фікспойнтом;
* **підзапит не можна вживати всередині `CONCAT`/`PRINT`** — рахувати в змінну
  (на цьому падала міграція `V260825.1100`);
* **крос-warehouse запис неможливий** — звідси окремий `whgold`;
* **`CREATE VIEW` не перевіряє крос-базові посилання** — неправильний шлях до bronze
  виявився не помилкою, а порожніми таблицями.

## 5. Відкриті пункти

| # | Що зробити | Деталі |
|---|---|---|
| 1 | **Задеплоїти `V260828.1000__gold_add_month_date_key.sql`** | додає `MonthStartDate`; далі `EXEC [dwh].[spGoldFullLoad]` у `whgold`. Без цієї колонки шість звʼязків семантичної моделі з календарем биті |
| 2 | **Завести модель у git** | зараз вона існує лише у воркспейсі: закомітити `fabric-semantic-model/` у `main`, далі Source control. Інакше наступний `Update all` її знесе — так уже сталося 31.08 |
| 3 | Перезалити `PL_Silver_Full_Load` | у Fabric лежить стара версія без параметра `root_object` — адресне перезавантаження там ще не працює |
| 4 | Опублікувати `PL_Gold_Full_Load` | підставити `<WHGOLD_ITEM_ID>`; після публікації додати Invoke на нього в silver-пайплайн, щоб ланцюг закривався одним запуском |
| 5 | Розклад інкременту | щодня `@force_full = 0`, раз на тиждень `= 1`; зараз параметр у silver-пайплайні не проброшений |
| 6 | `flyway repair` | міграції `V260819.1020` і `V260820.0930` редагувалися після застосування — checksum розійшовся |
| 7 | RLS у семантичній моделі | зараз усі бачать усі регіони |
| 8 | Узгодити з власником bronze | два записувачі в ті самі таблиці — наш pipeline і `dpl-bronze-sql-load-full` |
| 9 | Fabric data agent для демо «UseCase 8» | tenant settings + створення агента над `whgold` і семантичною моделлю — готова конфігурація в `fabric_agent.md` |

## 6. Як запустити з нуля

```sql
-- 1. Azure SQL: 01_ddl_azure_sql.sql -> 02_generate_data_fixed.sql
-- 2. Flyway: усі міграції з fabric-migrations/flyway/migrations (silver у whsilver, gold у whgold)
-- 3. Bronze: PL_Bronze_Ingest (source_table = '' -> усі таблиці)
-- 4. Silver:
EXEC [dwh].[spSilverFullLoad] @load_id = 'init';
-- 5. Gold (у whgold):
EXEC [dwh].[spGoldFullLoad] @load_id = 'init';
-- 6. Семантична модель -> git integration
```

Щоденний цикл: `PL_Bronze_Ingest` за розкладом — він тягне silver, а після пункту 4 з
розділу 5 тягтиме й gold.

## 7. Що показувати замовнику

* **SCD2 проти SCD1** — `scd1_demo.md`, покроковий сценарій на живих даних.
* **Адресне перезавантаження** — `spSilverLoadSubset` від однієї bronze-таблиці.
* **Якість даних** — прапорці `IsSrcDuplicate`, `IsAmountConsistent`, `IsPeriodOutOfRange`:
  silver нічого не викидає, а позначає.
* **Copilot** — `copilot_prompts.md`, 50 перевірених питань і чесний список того, чого модель
  не вміє.
* **Fabric data agent** — питання по warehouse і семантичній моделі одразу, з показом
  згенерованого SQL; налаштування в `fabric_agent.md`.
* **Журнали завантажень** — `EtlSilverLoadLog` / `EtlGoldLoadLog`: кожен рядок факту
  прив'язаний до `RunId` пайплайна через `CreatedBy`.

## 8. Чого в моделі немає

Планових даних, собівартості й маржі, залишків на складах (є лише рухи), зв'язку продажів
із конкретним лікарем. Це обмеження джерела, а не моделі — якщо замовник просить, потрібні
нові дані, а не переробка DWH.
