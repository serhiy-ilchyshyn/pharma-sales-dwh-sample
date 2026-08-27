# Gold level — вітрина звітності (`whgold.dwh`)

Денормалізовані виміри й агрегати поверх silver, в окремому warehouse **`whgold`**, схема
**`dwh`** — так само, як у прод-репозиторії (`whgoldad.dwh`). Конвенції: `Dim<Name>` / `Agg<Name>`,
технічні колонки лише `CreatedBy` + `CreatedAt`, без SCD2 — gold завжди знімок поточного стану.

Silver читається крос-базово (`[whsilver].[dwh].*`), запис іде локально в `whgold` — це і є
причина окремого warehouse: у Fabric писати можна лише в поточну базу.

## 1. Склад

**Виміри (6)** — поточні версії silver-вимірів із підставленими назвами замість ключів:
`DimDate`, `DimProduct`, `DimClientAccount`, `DimDoctor`, `DimEmployee`, `DimWarehouse`.
Ключ виміру `SK<Name>ID` = durable key silver, тож зв'язок з агрегатами стабільний.

**Агрегати (7):**

| Агрегат | Зернистість | Основні міри |
|---|---|---|
| `AggSalesDaily` | день × препарат × клієнт × представник × склад × статус × валюта | `OrderLineCnt`, `TotalQty`, `TotalGrossAmount`, `TotalDiscountAmount`, `TotalNetAmount` |
| `AggSalesMonthly` | місяць × препарат × представник × регіон × тип клієнта | `OrderLineCnt`, `ClientAccountCnt`, `TotalQty`, `TotalNetAmount`, `ReturnQty`, `ReturnNetAmount` |
| `AggVisitMonthly` | місяць × представник × препарат × спеціальність × тип активності × регіон | `VisitCnt`, `DoctorCnt`, `TotalDurationMin`, `TotalSamplesQty` |
| `AggPrescriptionMonthly` | місяць × препарат × спеціальність × регіон | `DoctorCnt`, `TotalPatientsCnt`, `TotalPrescriptionsCnt` |
| `AggInventoryMonthly` | місяць × склад × препарат | `MovementCnt`, `QtyIn`, `QtyOut`, `QtyWriteOff`, `QtyNet` |
| `AggAdverseEventMonthly` | місяць × препарат × серйозність × регіон | `CaseCnt`, `FatalCnt`, `LogicalErrorCnt` |
| `AggPromoEffectMonthly` | місяць × препарат × регіон | `VisitCnt`, `TotalSamplesQty`, `TotalPrescriptionsCnt`, `TotalQty`, `TotalNetAmount`, `NetAmountPerVisit` |

Рядки з `SKDateID = -1` (невідома дата) у місячні агрегати не потрапляють — інакше зʼявився б
місяць `N/A`; у `AggSalesDaily` вони лишаються, щоб суми сходилися з фактом.

`AggPromoEffectMonthly` рахується не з фактів, а з трьох інших агрегатів (`UNION` ключів +
`LEFT JOIN`), тому він на окремому рівні завантаження.

## 2. Оркестрація

Дзеркалить silver:

| Обʼєкт | Роль |
|---|---|
| `dwh.EtlGoldObject` | реєстр: `ObjectName`, `ObjectType` (Dim/Agg), `LoadLevel`, `IsActive` |
| `dwh.EtlGoldLoadLog` | журнал запусків: тривалість, кількість рядків, статус, помилка |
| `dwh.spFullGoldObject` | `TRUNCATE` + `INSERT` з `dwh.v<Object>` |
| `dwh.spGoldLoadLevel` | усі активні обʼєкти рівня (виклик з pipeline) |
| `dwh.spGoldFullLoad` | рівні 1..MAX |

Рівні: **1** — 6 вимірів, **2** — 6 агрегатів із фактів, **3** — `AggPromoEffectMonthly`.

```sql
EXEC [dwh].[spGoldFullLoad] @load_id = 'manual_gold_full_load';

SELECT LoadLevel, ObjectName, RowCnt, DurationSec, Status
FROM [dwh].[EtlGoldLoadLog]
WHERE LoadId = '<RunId>'
ORDER BY LoadLevel, StartedAt;
```

Pipeline — `fabric-pipelines/PL_Gold_Full_Load.json`: Lookup рівнів з `dwh.EtlGoldObject` →
ForEach (послідовно) → Script `EXEC [dwh].[spGoldLoadLevel] @level = @{item().LoadLevel},
@load_id = '@{pipeline().RunId}'`. Усі активності підключені до **`whgold`** — перед імпортом
підставте `<WHGOLD_ITEM_ID>` (endpoint у Fabric спільний для warehouse одного workspace,
але звіртесь із властивостями `whgold`).

**Ланцюг:** щоб gold рахувався одразу після silver, у `PL_Silver_Full_Load` додається
Invoke pipeline на `PL_Gold_Full_Load` після `ForEachLoadLevel` (потрібен item id gold-пайплайна
після першої публікації). Тоді `PL_Bronze_Ingest` закриває весь ланцюг
Azure SQL → bronze → silver → gold одним запуском.

Gold завжди перераховується повністю: агрегати дешеві, а часткове оновлення зробило б суми
неузгодженими між рівнями. Інкремент silver на це не впливає — gold читає вже оновлені факти.

## 3. Міграції

| Файл | Вміст |
|---|---|
| `V260826.1600__gold_init_creation.sql` | схема `dwh` у `whgold`, 6 вимірів, 7 агрегатів |
| `V260826.1610__gold_create_views_and_prc.sql` | 13 `v*` над silver, `EtlGoldObject`, `EtlGoldLoadLog`, `spFullGoldObject`, `spGoldLoadLevel`, `spGoldFullLoad` |
| `V260827.0930__gold_drop_legacy_schema_in_silver.sql` | прибирає залишки попередньої версії gold зі схеми `[gold]` у `whsilver` (ідемпотентна) |

Обидві gold-міграції починаються з `USE [whgold];` — Flyway виконує їх у тому ж наборі, що й
silver, як у прод-репозиторії, де в одній папці лежать міграції для `whsilverad` і `whgoldad`.
