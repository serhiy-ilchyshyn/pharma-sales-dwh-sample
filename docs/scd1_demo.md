# SCD Type 1 на silver — `DimLpu`

Демонстрація різниці між двома стратегіями історизації на живих даних:
`DimProduct` веде історію (**SCD2**), `DimLpu` перезаписує атрибути на місці (**SCD1**).

## Чому саме `DimLpu`

Назва й розташування медзакладу — довідкова інформація. Бізнесу потрібне актуальне
значення, а не історія того, як виправляли друкарську помилку в назві лікарні.
Для препарату навпаки: зміна ціни має лишити слід, бо старі продажі рахувались за старою.

Стратегія зберігається в реєстрі, тому перемкнути будь-який інший вимір — один рядок:

```sql
UPDATE [dwh].[EtlSilverObject] SET ScdType = 'SCD1' WHERE ObjectName = 'DimChain';
```

## Як показати замовнику

### 1. Стан до змін

```sql
DECLARE @lpu varchar(300) = (SELECT TOP 1 Id FROM [dwh].[DimLpu] WHERE SKLpuID <> -1 ORDER BY Id);

SELECT SKLpuID, SKLpuKeyID, Id, Name, SKCityKeyID, StartDate, EndDate, ModifiedAt, ModifiedBy
FROM [dwh].[DimLpu]
WHERE Id = @lpu;
```

Один рядок: `EndDate` порожній, `ModifiedAt` порожній.

### 2. Зміна в джерелі (Azure SQL)

Переносимо всіх лікарів одного медзакладу в інше місто:

```sql
UPDATE erp.DOCTORS
SET city = N'Одеса',
    updated_at = SYSUTCDATETIME()
WHERE UPPER(LTRIM(RTRIM(lpu_name))) = '<Id з кроку 1>';
```

### 3. Перезавантаження лише залежного від `DOCTORS`

```sql
-- у Fabric: спершу перелити DOCTORS у bronze (PL_Bronze_Ingest з source_table = 'DOCTORS'),
-- далі silver лише по замиканню цього джерела:
EXEC [dwh].[spSilverLoadSubset] @root_object = 'lhbronze.erp_erp.DOCTORS', @load_id = 'scd1_demo';
```

### 4. Стан після

```sql
SELECT SKLpuID, SKLpuKeyID, Id, Name, SKCityKeyID, StartDate, EndDate, ModifiedAt, ModifiedBy
FROM [dwh].[DimLpu]
WHERE Id = '<Id з кроку 1>';
```

Той самий рядок, той самий `SKLpuID` і `SKLpuKeyID`, змінений `SKCityKeyID`,
заповнені `ModifiedAt` / `ModifiedBy`. Другої версії **не зʼявилось**.

### 5. Контраст із SCD2

```sql
SELECT 'DimLpu (SCD1)'     AS Obj, Id, COUNT(*) AS Versions FROM [dwh].[DimLpu]
WHERE Id = '<Id з кроку 1>' GROUP BY Id
UNION ALL
SELECT 'DimProduct (SCD2)', Id, COUNT(*) FROM [dwh].[DimProduct]
WHERE Id IN (SELECT Id FROM [dwh].[DimProduct] GROUP BY Id HAVING COUNT(*) > 1) GROUP BY Id;
```

`DimLpu` — завжди 1 версія на ключ. `DimProduct` — 2 і більше після зміни ціни
(`02b_generate_more_data.sql` створює такі зміни параметром `@N_PriceChanges`).

Історію змін самого SCD1-виміру можна побачити тільки в журналі завантажень:

```sql
SELECT LoadId, ObjectName, RowCnt, StartedAt
FROM [dwh].[EtlSilverLoadLog]
WHERE ObjectName = 'DimLpu'
ORDER BY StartedAt DESC;
```

## Що варто проговорити на демо

* **SCD1 не зберігає попереднє значення.** Після перезапису старе місто зникає назавжди —
  це і є суть підходу, а не втрата даних через помилку.
* **Durable key не змінюється** ні в SCD1, ні в SCD2, тому факти й `RefDoctor` продовжують
  посилатися на той самий медзаклад.
* **Зміна самої назви ЛПУ створить новий рядок, а не оновить наявний** — натуральний ключ
  `DimLpu` виводиться з назви (`UPPER(lpu_name)`). Це обмеження ключа, а не стратегії SCD:
  щоб перейменування оновлювало запис, у джерелі має бути стабільний код медзакладу.
* **`EndDate` у SCD1 завжди порожній** — версій немає, і всі наявні join-и
  (`... AND EndDate IS NULL`) продовжують працювати без змін.
* **Зникнення з джерела** позначається `IsDeleted = 1`; якщо запис повертається — позначка
  знімається автоматично.
