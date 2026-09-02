# Fabric data agent — налаштування під наш стенд

Ресерч і готова конфігурація для демо «UseCase 8». Джерело: документація Microsoft Learn
(посилання в кінці), звірено 02.09.2026.

---

## 1. Що це і чим відрізняється від Copilot у звіті

**Fabric data agent** — окремий айтем воркспейсу, який відповідає на питання природною мовою
по кількох джерелах одразу. Copilot у звіті працює в межах однієї семантичної моделі;
агент вміє маршрутизувати питання між warehouse, lakehouse, семантичною моделлю та KQL —
до **пʼяти джерел** у будь-якій комбінації.

Як він обробляє питання:

1. читає схему джерел **під обліковим записом користувача**, який питає — тобто права
   не обходяться, агент бачить рівно те саме, що й людина;
2. складає промпт із трьох частин: питання + схема + ваші інструкції та приклади запитів;
3. обирає інструмент — **NL2SQL** (warehouse/lakehouse), **NL2DAX** (семантична модель),
   **NL2KQL** (KQL database);
4. генерує запит, валідує його, виконує й показує відповідь **разом із кроками
   й згенерованим кодом** — на демо це найсильніший момент, бо видно, звідки взялася цифра;
5. запити лише на читання: створення, зміна й видалення даних заблоковані на рівні продукту.

## 2. Передумови

| Вимога | Наш стенд |
|---|---|
| Capacity **F2+** або P1 із увімкненим Fabric | перевірити SKU ємності |
| Tenant setting **Users can use Copilot and other features powered by Azure OpenAI** | має бути увімкнений — Copilot у нас уже працює, отже ймовірно так |
| Tenant setting **Capacities can be designated as Fabric Copilot capacities** | перевірити |
| Cross-geo processing / storing для AI | **ймовірно не потрібно**: ємність у West Europe, тобто в межах EU data boundary. Ці два перемикачі обовʼязкові лише для ємностей поза EU і US |
| Read-доступ до джерел | є |

Зміни tenant settings підхоплюються **до години** — увімкніть заздалегідь, не в день демо.

## 3. Конфігурація для нашого демо

### Джерела (2 з 5 можливих)

| Джерело | Навіщо | Інструмент |
|---|---|---|
| Warehouse **`whgold`** | агрегати й виміри gold — точні цифри, приклади запитів (few-shot) підтримуються | NL2SQL |
| Семантична модель **`PharmaSalesGold`** | бізнес-назви мір, синоніми, готова логіка (частка повернень, сума на візит) | NL2DAX |

Обидва варті того, щоб бути в агенті: warehouse дає точність і керованість через приклади
запитів, семантична модель — бізнес-мову. Порядок пріоритету задається в інструкціях (нижче).

**Які таблиці ввімкнути в Explorer:** у `whgold.dwh` — усі 6 `Dim*` і 7 `Agg*`.
Службові `EtlGoldObject` і `EtlGoldLoadLog` **вимкнути**, інакше агент може вирішити,
що питання про завантаження стосується даних.

### Data agent instructions (вставити як є)

```md
## Objective
Допомагати бізнес-користувачам фармацевтичної компанії аналізувати продажі,
роботу польової команди, призначення лікарів, рух запасів і фармаконагляд.

## Data sources
- Для точних цифр і будь-яких питань про агрегати використовуй warehouse `whgold`,
  схема `dwh`.
- Для питань, сформульованих бізнес-мовою («виручка», «частка повернень»,
  «сума продажів на візит»), використовуй семантичну модель `PharmaSalesGold`.
- Якщо питання можна відповісти обома джерелами — обирай `whgold`.

## Key terminology
- «Продажі», «виручка», «оборот» — сума продажів без повернень (TotalNetAmount).
- «Упаковки», «обсяг» — кількість проданих одиниць (TotalQty).
- «Медпред», «представник» — співробітник польової команди (DimEmployee).
- «ЛПУ» — медичний заклад, у моделі це поле Lpu виміру лікаря.
- «Візит» — будь-яка активність представника: візит, круглий стіл, e-detailing, симпозіум.
- RX — рецептурний препарат, OTC — безрецептурний.
- «Кейс» — випадок побічного явища у фармаконагляді.

## Response guidelines
- Спершу коротка відповідь одним реченням, далі таблиця з даними.
- Суми показуй у гривнях без десяткових знаків, великі числа — з розділювачем тисяч.
- Завжди уточнюй період, за який наведені цифри.
- Якщо в питанні не вказано період — бери останні 12 місяців і скажи про це.

## Handling common topics
- Повернення НЕ входять у суму продажів: вони лежать в окремих полях
  ReturnQty і ReturnNetAmount. Якщо питають «скільки продали» — не додавай повернення.
- Питання «скільки унікальних клієнтів/лікарів» коректні лише в межах місяця:
  ці лічильники не можна підсумовувати між місяцями.
- Запаси: у моделі є рухи (прихід, видача, списання), а не залишки на дату.
  Якщо питають про залишок — поясни, що доступний лише чистий рух за період.
- Питань про план, собівартість, маржу дані не містять — так і відповідай.
```

### Data source instructions для `whgold` (вставити як є)

```md
## General knowledge
Схема `dwh` у warehouse whgold — вітрина звітності. Таблиці Agg* містять уже згорнуті
цифри, Dim* — довідники. Зʼєднання завжди по ключах SK<Назва>ID.
Місячні агрегати мають колонку MonthStartDate (перший день місяця) — використовуй її
для фільтрів за періодом і для зʼєднання з DimDate.

## Table descriptions
- AggSalesMonthly — продажі по місяцях: місяць × препарат × представник × регіон × тип клієнта.
  TotalNetAmount — сума без повернень, ReturnNetAmount — повернення окремо.
- AggSalesDaily — денний зріз продажів; тільки тут є клієнт (SKClientAccountID),
  статус замовлення й валюта.
- AggVisitMonthly — активність польової команди: візити, охоплені лікарі, роздані зразки.
- AggPrescriptionMonthly — призначення лікарів по препаратах і спеціальностях.
- AggInventoryMonthly — рух запасів по складах: QtyIn, QtyOut, QtyWriteOff, QtyNet.
- AggAdverseEventMonthly — кейси фармаконагляду по серйозності.
- AggPromoEffectMonthly — візити, зразки, призначення й продажі в одному розрізі
  місяць × препарат × регіон.
- DimProduct, DimClientAccount, DimDoctor, DimEmployee, DimWarehouse, DimDate — довідники.

## When asked about
- Про клієнтів, статуси замовлень або валюту — використовуй AggSalesDaily, в інших
  агрегатах цих розрізів немає.
- Про звʼязок промо й продажів — використовуй AggPromoEffectMonthly, не зʼєднуй
  агрегати вручну.
- Про склади — зʼєднуй AggInventoryMonthly з DimWarehouse по SKWarehouseID.
- Рядки з ключем -1 означають «невідомо» — не відкидай їх мовчки, згадай у відповіді,
  якщо їх частка помітна.
```

### Example queries — few-shot для `whgold`

Приклади підвищують точність NL2SQL: агент підбирає три найрелевантніші до питання.
Fabric використовує лише синтаксично валідні запити, що відповідають схемі.

| Питання | Запит |
|---|---|
| Топ-10 препаратів за сумою продажів за 2026 рік | `SELECT TOP 10 p.ProductName, SUM(a.TotalNetAmount) AS TotalNetAmount FROM dwh.AggSalesMonthly a JOIN dwh.DimProduct p ON p.SKProductID = a.SKProductID WHERE a.YearNum = 2026 GROUP BY p.ProductName ORDER BY TotalNetAmount DESC;` |
| Динаміка продажів по місяцях за 2026 рік | `SELECT a.YearMonth, SUM(a.TotalNetAmount) AS TotalNetAmount FROM dwh.AggSalesMonthly a WHERE a.YearNum = 2026 GROUP BY a.YearMonth ORDER BY a.YearMonth;` |
| Які препарати найбільше повертали у 2026 | `SELECT TOP 10 p.ProductName, SUM(a.ReturnNetAmount) AS ReturnNetAmount, SUM(a.ReturnQty) AS ReturnQty FROM dwh.AggSalesMonthly a JOIN dwh.DimProduct p ON p.SKProductID = a.SKProductID WHERE a.YearNum = 2026 GROUP BY p.ProductName ORDER BY ReturnNetAmount DESC;` |
| Скільки візитів зробив кожен представник у липні 2026 | `SELECT e.EmployeeName, SUM(v.VisitCnt) AS VisitCnt FROM dwh.AggVisitMonthly v JOIN dwh.DimEmployee e ON e.SKEmployeeID = v.SKEmployeeID WHERE v.YearMonth = '2026-07' GROUP BY e.EmployeeName ORDER BY VisitCnt DESC;` |
| Скільки списано по складах за 2026 рік | `SELECT w.WarehouseName, SUM(i.QtyWriteOff) AS QtyWriteOff FROM dwh.AggInventoryMonthly i JOIN dwh.DimWarehouse w ON w.SKWarehouseID = i.SKWarehouseID WHERE i.YearNum = 2026 GROUP BY w.WarehouseName ORDER BY QtyWriteOff DESC;` |
| Продажі та візити по препаратах за 2026 рік | `SELECT p.ProductName, SUM(a.VisitCnt) AS VisitCnt, SUM(a.TotalNetAmount) AS TotalNetAmount FROM dwh.AggPromoEffectMonthly a JOIN dwh.DimProduct p ON p.SKProductID = a.SKProductID WHERE a.YearNum = 2026 GROUP BY p.ProductName ORDER BY TotalNetAmount DESC;` |

Для семантичної моделі приклади запитів **не підтримуються** — там працюють лише
інструкції та метадані самої моделі (тому синоніми й описи в TMDL важливі саме для неї).

## 4. Порядок налаштування

1. **New item → Fabric data agent**, назва `PharmaSalesAgent`.
2. Додати джерело `whgold` → в Explorer лишити 13 таблиць `Dim*`/`Agg*`, зняти `Etl*`.
3. Додати друге джерело — семантичну модель `PharmaSalesGold`.
4. **Data agent instructions** — вставити текст із розділу 3.
5. **Data source instructions** для `whgold` — вставити текст із розділу 3.
6. **Example queries** для `whgold` — додати шість пар із таблиці вище.
7. Прогнати 5–7 питань із [`copilot_prompts.md`](copilot_prompts.md), дивитись на
   згенерований SQL у кроках; де відповідь неточна — доповнити інструкції або приклади.
8. **Publish** з описом — опис читають і колеги, і зовнішні оркестратори.

Після публікації існують дві версії: чернетка для доопрацювання й опублікована для колег.

## 5. Обмеження — проговорити на демо до питань із залу

* Агент **не робить причинно-наслідкового аналізу**. «Чому впали продажі у другому кварталі»
  поза його можливостями; він відповідає на «скільки», «які», «коли», а не «чому».
* Немає ML, прогнозів і кореляційного аналізу — лише вибірка й агрегація наявних даних.
* Максимум **5 джерел** на агента; у нас 2, запас є.
* Інструкції — до **15 000 символів**.
* Few-shot приклади **не працюють для семантичних моделей**, тільки для warehouse,
  lakehouse і KQL.
* Історія чату зберігається до 28 днів; **Clear chat** стирає її безповоротно.
* Відповідь залежить від прав того, хто питає: двоє людей можуть отримати різні цифри,
  і це правильна поведінка.

## 6. ALM

Агент підтримує git integration і deployment pipelines: інструкції, приклади запитів
і перелік джерел версіонуються разом з іншими айтемами. Для нашого воркспейсу це означає,
що агент варто заводити в git одразу — інакше повториться історія з семантичною моделлю,
яку синхронізація прибрала.

---

## Джерела

- [Fabric data agent creation (concept)](https://learn.microsoft.com/en-us/fabric/data-science/concept-data-agent)
- [Create a Fabric data agent](https://learn.microsoft.com/en-us/fabric/data-science/how-to-create-data-agent)
- [Data agent configurations](https://learn.microsoft.com/en-us/fabric/data-science/data-agent-configurations)
- [Configure Fabric data agent tenant settings](https://learn.microsoft.com/en-us/fabric/data-science/data-agent-tenant-settings)
- [Fabric data agent runtime](https://learn.microsoft.com/en-us/fabric/data-science/data-agent-runtime)
- [Fabric data agent sharing and permission management](https://learn.microsoft.com/en-us/fabric/data-science/data-agent-sharing)
- [Consume a data agent in Microsoft Foundry](https://learn.microsoft.com/en-us/fabric/data-science/data-agent-foundry)
