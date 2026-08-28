# CLAUDE.md

Прототип фармацевтичного DWH у Microsoft Fabric: Azure SQL (`erp`) → bronze lakehouse →
silver warehouse → gold warehouse → семантична модель для Copilot.

Стан проєкту, ідентифікатори середовища та відкриті пункти — [`docs/handover.md`](docs/handover.md).

## Структура

```
01_ddl_azure_sql.sql / 02_generate_data_fixed.sql   -- джерело: DDL + генератор
02b_generate_more_data.sql                          -- інкрементальна догенерація (append-only)
fabric-migrations/flyway/migrations/                -- усі міграції silver і gold
fabric-pipelines/                                   -- Data Pipeline (JSON)
fabric-semantic-model/PharmaSalesGold.SemanticModel -- TMDL
docs/                                               -- моделі, залежності, словник, промпти
```

## Конвенції

Ті самі, що в репозиторії `grp-ctl-azure-dwh` (він поруч у `~/PycharmProjects`):

* міграції — `V<YYMMDD>.<HHMM>__<опис>.sql`, ідемпотентні, `flyway.outOfOrder=true`;
* кожна міграція починається з `USE [whsilver];` або `USE [whgold];` у блоці `--IMPORTANT`;
* silver: `Dim<X>` / `Ref<X>` / `Fct<X>`, ключі `SK<X>ID` (версія рядка) + `SK<X>KeyID` (durable);
  технічні колонки `StartDate`, `EndDate`, `IsDeleted`, `CreatedBy`, `ModifiedBy`, `CreatedAt`, `ModifiedAt`;
* gold: `Dim<X>` / `Agg<X>`, лише `CreatedBy` + `CreatedAt`, без SCD;
* факти посилаються **тільки** на `SK…KeyID`;
* рядок `-1` — unknown member у кожному вимірі; текст за замовчуванням `'N/A'`;
* джерельні view звуться `v<TableName>`, **перша колонка — натуральний ключ `Id`**
  (процедура визначає NK саме за `ORDINAL_POSITION = 1`).

## Що ламається найчастіше

* **Порядок колонок.** `spFullFct` / `spIncrementalFct` / `spFullGoldObject` вставляють через
  `v.*`, тож проєкція view має точно збігатися з таблицею. Нову колонку додавати **в кінець**
  і туди, і туди.
* **Fabric не дозволяє:** курсори, рекурсивні CTE, підзапити всередині `CONCAT`/`PRINT`,
  запис у інший warehouse. Обхідні шляхи вже застосовані в коді — дивіться сусідні процедури.
* **`CREATE VIEW` не валідує крос-базові посилання** — помилковий шлях виявиться порожніми
  таблицями, а не помилкою.
* **Виміри не можна робити інкрементальними** — `spUpsertSCDDimension` позначить усе, чого
  немає у view, як `IsDeleted`.

## Перевірка перед комітом

Немає тестів; перевіряйте структурно (скрипти в історії сесії роблять саме це):

* проєкції `v*` збігаються з колонками таблиць за складом і порядком;
* у `PRINT` немає підзапитів;
* нові silver-об'єкти додані в `EtlSilverObject` і `EtlObjectDependency`,
  після чого виконано `EXEC [dwh].[spRefreshObjectClosure]`.

## Запуск

```sql
EXEC [dwh].[spSilverFullLoad] @load_id = 'manual';                       -- усе silver
EXEC [dwh].[spSilverLoadSubset] @root_object = 'lhbronze.erp_erp.CUSTOMERS', @load_id = 'x';
EXEC [dwh].[spSilverLoadLevel]  @level = 5, @load_id = 'retry';          -- рестарт з рівня
EXEC [dwh].[spGoldFullLoad] @load_id = 'manual';                         -- у whgold
```

## Мова

Документація, коментарі в міграціях і спілкування — українською.
