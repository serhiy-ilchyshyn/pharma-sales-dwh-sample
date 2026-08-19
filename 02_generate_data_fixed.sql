-- =====================================================================
-- Pharma ERP Data Generator — Pure T-SQL for Azure SQL Database
--
-- Prerequisite: schema and tables from 01_ddl_azure_sql.sql already exist.
-- This script populates all 10 erp.* tables with realistic Ukrainian pharma
-- data + intentional defects (duplicates, orphan FKs, bad currencies,
-- out-of-range dates, SCD2 versions, logic errors).
--
-- Randomness: NEWID() + CHECKSUM pattern (unique per row).
-- Reproducibility: NOT reproducible across runs (each run = new random data).
--                  For deterministic output, use the Python generator instead.
--
-- Volumes are declared in the CONFIG section at top — tune as needed.
-- =====================================================================

SET NOCOUNT ON;

-- ---------- CONFIG ----------
DECLARE @DateStart          DATE       = '2024-01-01';
DECLARE @DateEnd            DATE       = '2026-08-14';
DECLARE @DimCreatedStart    DATE       = '2015-01-01';
DECLARE @DimCreatedEnd      DATE       = '2023-12-31';

DECLARE @N_CustomersBase    INT = 500;
DECLARE @N_CustomerDups     INT = 25;
DECLARE @N_DoctorsBase      INT = 2000;
DECLARE @N_DoctorDups       INT = 100;
DECLARE @N_ManagerCount     INT = 8;
DECLARE @N_RepCount         INT = 42;
DECLARE @N_Warehouses       INT = 30;

DECLARE @N_Sales            INT = 50000;
DECLARE @N_SalesDups        INT = 1000;
DECLARE @N_Inventory        INT = 80000;
DECLARE @N_InventoryDups    INT = 1600;
DECLARE @N_Visits           INT = 15000;
DECLARE @N_VisitDups        INT = 300;
DECLARE @N_Rx               INT = 30000;
DECLARE @N_RxDups           INT = 600;
DECLARE @N_AE               INT = 5000;

DECLARE @DateRangeDays      INT = DATEDIFF(DAY, @DateStart, @DateEnd);


-- =====================================================================
-- OPTIONAL: TRUNCATE all target tables for a clean rerun
-- =====================================================================
TRUNCATE TABLE erp.ADVERSE_EVENTS;
TRUNCATE TABLE erp.PRESCRIPTIONS;
TRUNCATE TABLE erp.DOCTOR_VISITS;
TRUNCATE TABLE erp.INVENTORY_MOVEMENTS;
TRUNCATE TABLE erp.SALES_ORDERS;
TRUNCATE TABLE erp.WAREHOUSES;
TRUNCATE TABLE erp.EMPLOYEES;
TRUNCATE TABLE erp.DOCTORS;
TRUNCATE TABLE erp.CUSTOMERS;
TRUNCATE TABLE erp.PRODUCTS;


-- =====================================================================
-- NUMBERS / TALLY TABLE (up to 100k)
-- =====================================================================
IF OBJECT_ID('tempdb..#Nums') IS NOT NULL DROP TABLE #Nums;
CREATE TABLE #Nums (n INT PRIMARY KEY);
INSERT INTO #Nums (n)
SELECT TOP (100000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
FROM sys.all_columns a CROSS JOIN sys.all_columns b;


-- =====================================================================
-- REFERENCE DATA — DRUGS
-- =====================================================================
IF OBJECT_ID('tempdb..#Drugs') IS NOT NULL DROP TABLE #Drugs;
CREATE TABLE #Drugs (
    drug_no    INT IDENTITY(1,1),
    inn        NVARCHAR(200),
    brand      NVARCHAR(200),
    atc        NVARCHAR(20),
    form       NVARCHAR(100),
    dosage1    NVARCHAR(50),
    dosage2    NVARCHAR(50),
    dosage3    NVARCHAR(50),
    price_min  DECIMAL(18,2),
    price_max  DECIMAL(18,2),
    rx_otc     NVARCHAR(10)
);

INSERT INTO #Drugs (inn, brand, atc, form, dosage1, dosage2, dosage3, price_min, price_max, rx_otc) VALUES
-- Cardiovascular
(N'Amlodipinum',    N'Норваск',     N'C08CA01', N'таблетки', N'5 мг',   N'10 мг',  NULL,      200, 350, N'RX'),
(N'Bisoprololum',   N'Конкор',      N'C07AB07', N'таблетки', N'2.5 мг', N'5 мг',   N'10 мг',  150, 280, N'RX'),
(N'Losartanum',     N'Лозап',       N'C09CA01', N'таблетки', N'25 мг',  N'50 мг',  N'100 мг', 180, 320, N'RX'),
(N'Enalaprilum',    N'Ренітек',     N'C09AA02', N'таблетки', N'5 мг',   N'10 мг',  N'20 мг',  120, 240, N'RX'),
(N'Metoprololum',   N'Егілок',      N'C07AB02', N'таблетки', N'25 мг',  N'50 мг',  N'100 мг', 140, 260, N'RX'),
(N'Rosuvastatinum', N'Крестор',     N'C10AA07', N'таблетки', N'10 мг',  N'20 мг',  N'40 мг',  350, 650, N'RX'),
(N'Atorvastatinum', N'Ліпримар',    N'C10AA05', N'таблетки', N'10 мг',  N'20 мг',  N'40 мг',  300, 580, N'RX'),
(N'Simvastatinum',  N'Вазиліп',     N'C10AA01', N'таблетки', N'10 мг',  N'20 мг',  NULL,      180, 340, N'RX'),
(N'Warfarinum',     N'Варфарин',    N'B01AA03', N'таблетки', N'2.5 мг', N'5 мг',   NULL,       90, 180, N'RX'),
(N'Clopidogrelum',  N'Плавікс',     N'B01AC04', N'таблетки', N'75 мг',  NULL,      NULL,      450, 780, N'RX'),
(N'Perindoprilum',  N'Престаріум',  N'C09AA04', N'таблетки', N'5 мг',   N'10 мг',  NULL,      280, 460, N'RX'),
(N'Nebivololum',    N'Небілет',     N'C07AB12', N'таблетки', N'5 мг',   NULL,      NULL,      240, 380, N'RX'),
(N'Valsartanum',    N'Діован',      N'C09CA03', N'таблетки', N'80 мг',  N'160 мг', NULL,      320, 520, N'RX'),
(N'Ramiprilum',     N'Хартіл',      N'C09AA05', N'таблетки', N'5 мг',   N'10 мг',  NULL,      180, 340, N'RX'),
-- Analgesics / NSAIDs
(N'Ibuprofenum',    N'Нурофен',     N'M01AE01', N'таблетки', N'200 мг', N'400 мг', NULL,       60, 140, N'OTC'),
(N'Diclofenacum',   N'Диклак',      N'M01AB05', N'таблетки', N'50 мг',  N'100 мг', NULL,       80, 160, N'RX'),
(N'Ketoprofenum',   N'Кетонал',     N'M02AA10', N'гель',     N'2.5%',   NULL,      NULL,      110, 190, N'OTC'),
(N'Paracetamolum',  N'Панадол',     N'N02BE01', N'таблетки', N'500 мг', NULL,      NULL,       40, 100, N'OTC'),
(N'Meloxicamum',    N'Моваліс',     N'M01AC06', N'таблетки', N'7.5 мг', N'15 мг',  NULL,      180, 320, N'RX'),
(N'Nimesulidum',    N'Німесил',     N'M01AX17', N'порошок',  N'100 мг', NULL,      NULL,      140, 240, N'OTC'),
(N'Etoricoxibum',   N'Аркоксіа',    N'M01AH05', N'таблетки', N'60 мг',  N'90 мг',  NULL,      280, 450, N'RX'),
-- Respiratory
(N'Salbutamolum',   N'Вентолін',    N'R03AC02', N'аерозоль', N'100 мкг', NULL,     NULL,      140, 240, N'RX'),
(N'Budesonidum',    N'Пульмікорт',  N'R03BA02', N'суспензія', N'0.5 мг', NULL,     NULL,      380, 620, N'RX'),
(N'Ambroxolum',     N'Лазолван',    N'R05CB06', N'сироп',    N'15 мг/5мл', NULL,   NULL,      140, 250, N'OTC'),
(N'Fluticasonum',   N'Фліксотид',   N'R03BA05', N'аерозоль', N'125 мкг', NULL,     NULL,      280, 480, N'RX'),
(N'Acetylcysteinum',N'АЦЦ',         N'R05CB01', N'таблетки', N'200 мг', N'600 мг', NULL,      110, 220, N'OTC'),
-- Antibiotics
(N'Amoxicillinum',  N'Флемоксин',   N'J01CA04', N'таблетки', N'500 мг', N'1000 мг', NULL,     140, 260, N'RX'),
(N'AmoxiClav',      N'Аугментин',   N'J01CR02', N'таблетки', N'625 мг', N'1000 мг', NULL,     280, 480, N'RX'),
(N'Azithromycinum', N'Сумамед',     N'J01FA10', N'таблетки', N'500 мг', NULL,      NULL,      240, 420, N'RX'),
(N'Ceftriaxonum',   N'Медаксон',    N'J01DD04', N'ін''єкції',N'1 г',    NULL,      NULL,       80, 160, N'RX'),
(N'Ciprofloxacinum',N'Ципрінол',    N'J01MA02', N'таблетки', N'500 мг', NULL,      NULL,      110, 220, N'RX'),
(N'Metronidazolum', N'Метрогіл',    N'J01XD01', N'таблетки', N'250 мг', N'500 мг', NULL,       80, 160, N'RX'),
(N'Levofloxacinum', N'Таванік',     N'J01MA12', N'таблетки', N'500 мг', N'750 мг', NULL,      260, 440, N'RX'),
-- GI
(N'Omeprazolum',    N'Омез',        N'A02BC01', N'капсули',  N'20 мг',  NULL,      NULL,       80, 180, N'OTC'),
(N'Pantoprazolum',  N'Контролок',   N'A02BC02', N'таблетки', N'20 мг',  N'40 мг',  NULL,      180, 340, N'RX'),
(N'Esomeprazolum',  N'Нексіум',     N'A02BC05', N'таблетки', N'20 мг',  N'40 мг',  NULL,      320, 540, N'RX'),
(N'Domperidonum',   N'Мотіліум',    N'A03FA03', N'таблетки', N'10 мг',  NULL,      NULL,      140, 250, N'OTC'),
(N'Simeticonum',    N'Еспумізан',   N'A03AX13', N'капсули',  N'40 мг',  NULL,      NULL,      120, 220, N'OTC'),
(N'Mebeverinum',    N'Дуспаталін',  N'A03AA04', N'капсули',  N'200 мг', NULL,      NULL,      280, 450, N'RX'),
-- Diabetes
(N'Metforminum',    N'Сіофор',      N'A10BA02', N'таблетки', N'500 мг', N'850 мг', N'1000 мг',120, 240, N'RX'),
(N'Gliclazidum',    N'Діабетон',    N'A10BB09', N'таблетки', N'30 мг',  N'60 мг',  NULL,      180, 340, N'RX'),
(N'InsulinumHum',   N'Хумулін',     N'A10AB01', N'ін''єкції',N'100 МО', NULL,      NULL,      380, 620, N'RX'),
(N'Sitagliptinum',  N'Янувія',      N'A10BH01', N'таблетки', N'100 мг', NULL,      NULL,      680,1180, N'RX'),
-- Mental health
(N'Sertralinum',    N'Золофт',      N'N06AB06', N'таблетки', N'50 мг',  N'100 мг', NULL,      280, 460, N'RX'),
(N'Fluoxetinum',    N'Прозак',      N'N06AB03', N'капсули',  N'20 мг',  NULL,      NULL,      140, 260, N'RX');


-- ---------- MANUFACTURERS ----------
IF OBJECT_ID('tempdb..#Manuf') IS NOT NULL DROP TABLE #Manuf;
CREATE TABLE #Manuf (m_no INT IDENTITY(1,1), name NVARCHAR(200));
INSERT INTO #Manuf (name) VALUES
(N'Pfizer'),(N'Novartis'),(N'Merck'),(N'GSK'),(N'Sanofi'),(N'AstraZeneca'),
(N'Bayer'),(N'Boehringer Ingelheim'),(N'Berlin-Chemie'),(N'Teva'),(N'KRKA'),
(N'Egis'),(N'Дарниця'),(N'Фармак'),(N'Артеріум'),(N'Київський вітамінний завод'),
(N'Здоров''я'),(N'Юрія-Фарм');


-- ---------- REGIONS + CITIES ----------
IF OBJECT_ID('tempdb..#Cities') IS NOT NULL DROP TABLE #Cities;
CREATE TABLE #Cities (c_no INT IDENTITY(1,1), region NVARCHAR(100), city NVARCHAR(100));
INSERT INTO #Cities (region, city) VALUES
(N'Вінницька',N'Вінниця'),(N'Вінницька',N'Хмільник'),(N'Вінницька',N'Жмеринка'),
(N'Волинська',N'Луцьк'),(N'Волинська',N'Ковель'),
(N'Дніпропетровська',N'Дніпро'),(N'Дніпропетровська',N'Кривий Ріг'),(N'Дніпропетровська',N'Кам''янське'),
(N'Донецька',N'Краматорськ'),(N'Донецька',N'Слов''янськ'),
(N'Житомирська',N'Житомир'),(N'Житомирська',N'Бердичів'),
(N'Закарпатська',N'Ужгород'),(N'Закарпатська',N'Мукачево'),
(N'Запорізька',N'Запоріжжя'),(N'Запорізька',N'Мелітополь'),
(N'Івано-Франківська',N'Івано-Франківськ'),(N'Івано-Франківська',N'Коломия'),
(N'Київська',N'Біла Церква'),(N'Київська',N'Бровари'),(N'Київська',N'Ірпінь'),(N'Київська',N'Буча'),
(N'Кіровоградська',N'Кропивницький'),(N'Кіровоградська',N'Олександрія'),
(N'Луганська',N'Сєвєродонецьк'),
(N'Львівська',N'Львів'),(N'Львівська',N'Дрогобич'),(N'Львівська',N'Стрий'),
(N'Миколаївська',N'Миколаїв'),(N'Миколаївська',N'Первомайськ'),
(N'Одеська',N'Одеса'),(N'Одеська',N'Ізмаїл'),(N'Одеська',N'Чорноморськ'),
(N'Полтавська',N'Полтава'),(N'Полтавська',N'Кременчук'),
(N'Рівненська',N'Рівне'),(N'Рівненська',N'Дубно'),
(N'Сумська',N'Суми'),(N'Сумська',N'Конотоп'),
(N'Тернопільська',N'Тернопіль'),(N'Тернопільська',N'Чортків'),
(N'Харківська',N'Харків'),(N'Харківська',N'Ізюм'),(N'Харківська',N'Чугуїв'),
(N'Херсонська',N'Херсон'),
(N'Хмельницька',N'Хмельницький'),(N'Хмельницька',N'Кам''янець-Подільський'),
(N'Черкаська',N'Черкаси'),(N'Черкаська',N'Умань'),
(N'Чернівецька',N'Чернівці'),
(N'Чернігівська',N'Чернігів'),(N'Чернігівська',N'Ніжин'),
(N'Київ',N'Київ');


-- ---------- SPECIALTIES / LPU / CHAINS / DISTRIBUTORS ----------
IF OBJECT_ID('tempdb..#Specs') IS NOT NULL DROP TABLE #Specs;
CREATE TABLE #Specs (s_no INT IDENTITY(1,1), name NVARCHAR(100));
INSERT INTO #Specs (name) VALUES
(N'Терапевт'),(N'Кардіолог'),(N'Педіатр'),(N'Гастроентеролог'),(N'Ендокринолог'),
(N'Невролог'),(N'Пульмонолог'),(N'Гінеколог'),(N'Уролог'),(N'Хірург'),
(N'Офтальмолог'),(N'Отоларинголог'),(N'Дерматолог'),(N'Психіатр'),(N'Сімейний лікар');

IF OBJECT_ID('tempdb..#Lpu') IS NOT NULL DROP TABLE #Lpu;
CREATE TABLE #Lpu (l_no INT IDENTITY(1,1), template NVARCHAR(200));
INSERT INTO #Lpu (template) VALUES
(N'КНП "Міська лікарня №{n}"'),(N'КНП "Центральна районна лікарня"'),
(N'КНП "ЦПМСД №{n}"'),(N'КНП "Обласна клінічна лікарня"'),
(N'ТОВ "Медичний центр Здоров''я"'),(N'КНП "Дитяча міська лікарня №{n}"'),
(N'ДУ "Інститут кардіології"'),(N'КНП "Поліклініка №{n}"');

IF OBJECT_ID('tempdb..#Chains') IS NOT NULL DROP TABLE #Chains;
CREATE TABLE #Chains (ch_no INT IDENTITY(1,1), name NVARCHAR(100));
INSERT INTO #Chains (name) VALUES
(N'АНЦ'),(N'Подорожник'),(N'911'),(N'Бажаємо здоров''я'),(N'Медина'),
(N'Аптека доброго дня'),(N'Здорова родина'),(N'Копійка'),(N'МОІ'),(N'Аптека 24');

IF OBJECT_ID('tempdb..#Distrib') IS NOT NULL DROP TABLE #Distrib;
CREATE TABLE #Distrib (d_no INT IDENTITY(1,1), name NVARCHAR(100));
INSERT INTO #Distrib (name) VALUES
(N'Оптіма-Фарм'),(N'БаДМ'),(N'Вента'),(N'Артур-К'),(N'Фра-М');


-- ---------- UKRAINIAN NAMES ----------
IF OBJECT_ID('tempdb..#LastNames') IS NOT NULL DROP TABLE #LastNames;
CREATE TABLE #LastNames (ln_no INT IDENTITY(1,1), name NVARCHAR(100));
INSERT INTO #LastNames (name) VALUES
(N'Шевченко'),(N'Мельник'),(N'Ковальчук'),(N'Бондаренко'),(N'Ткаченко'),(N'Кравченко'),
(N'Олійник'),(N'Кучер'),(N'Петренко'),(N'Іваненко'),(N'Сидоренко'),(N'Пономаренко'),
(N'Гончаренко'),(N'Марченко'),(N'Литвиненко'),(N'Захарченко'),(N'Прокопенко'),(N'Романенко'),
(N'Савченко'),(N'Пасічник'),(N'Гриценко'),(N'Куценко'),(N'Шпак'),(N'Юрченко'),
(N'Даниленко'),(N'Кушнір'),(N'Пилипенко'),(N'Стеценко'),(N'Наконечний'),(N'Терещенко'),
(N'Панасенко'),(N'Головко'),(N'Приходько'),(N'Мороз'),(N'Бойко'),(N'Козак'),
(N'Кулик'),(N'Гнатюк'),(N'Романюк'),(N'Волошин'),(N'Заєць'),(N'Дорошенко'),
(N'Голуб'),(N'Матвієнко'),(N'Костенко'),(N'Клименко'),(N'Демченко'),(N'Григоренко'),
(N'Данилюк'),(N'Чорний'),(N'Гончарук'),(N'Різник'),(N'Захарчук'),(N'Мазур'),
(N'Слюсар'),(N'Дяченко'),(N'Ліщук'),(N'Красний'),(N'Мачульський'),(N'Ярошенко'),
(N'Литвин'),(N'Гриб'),(N'Панченко'),(N'Стельмах'),(N'Крамар'),(N'Швидкий'),
(N'Кузьменко'),(N'Приймак'),(N'Бабенко'),(N'Хоменко'),(N'Романченко'),(N'Мосійчук'),
(N'Верещак'),(N'Демчук'),(N'Полюх'),(N'Крутько'),(N'Микитенко'),(N'Швець'),
(N'Волков'),(N'Комар'),(N'Ясінський'),(N'Гарасим'),(N'Романов'),(N'Опанасюк'),
(N'Кушнерук'),(N'Юрчук'),(N'Богданов'),(N'Захаренко'),(N'Марчук'),(N'Пилипчук'),
(N'Гарбуз'),(N'Курилюк'),(N'Кульчицький'),(N'Мельничук'),(N'Никитюк'),(N'Оксенюк'),
(N'Стародуб'),(N'Тарасюк'),(N'Успенський'),(N'Хоружий'),(N'Цимбал'),(N'Черкас');

IF OBJECT_ID('tempdb..#FirstNames') IS NOT NULL DROP TABLE #FirstNames;
CREATE TABLE #FirstNames (fn_no INT IDENTITY(1,1), name NVARCHAR(100), gender CHAR(1));
INSERT INTO #FirstNames (name, gender) VALUES
(N'Олег','M'),(N'Іван','M'),(N'Петро','M'),(N'Микола','M'),(N'Володимир','M'),
(N'Юрій','M'),(N'Сергій','M'),(N'Андрій','M'),(N'Ігор','M'),(N'Роман','M'),
(N'Тарас','M'),(N'Богдан','M'),(N'Максим','M'),(N'Дмитро','M'),(N'Олександр','M'),
(N'Валерій','M'),(N'Віктор','M'),(N'Василь','M'),(N'Ярослав','M'),(N'Костянтин','M'),
(N'Артем','M'),(N'Денис','M'),(N'Євген','M'),(N'Станіслав','M'),(N'Данило','M'),
(N'Назар','M'),(N'Остап','M'),
(N'Марія','F'),(N'Ольга','F'),(N'Тетяна','F'),(N'Оксана','F'),(N'Ірина','F'),
(N'Наталія','F'),(N'Юлія','F'),(N'Валентина','F'),(N'Ганна','F'),(N'Світлана','F'),
(N'Людмила','F'),(N'Катерина','F'),(N'Христина','F'),(N'Софія','F'),(N'Ярослава','F'),
(N'Богдана','F'),(N'Аліна','F'),(N'Дарина','F'),(N'Вікторія','F'),(N'Марина','F'),
(N'Уляна','F'),(N'Настя','F'),(N'Олена','F');

IF OBJECT_ID('tempdb..#MidNames') IS NOT NULL DROP TABLE #MidNames;
CREATE TABLE #MidNames (mn_no INT IDENTITY(1,1), name NVARCHAR(100), gender CHAR(1));
INSERT INTO #MidNames (name, gender) VALUES
(N'Олегович','M'),(N'Іванович','M'),(N'Петрович','M'),(N'Миколайович','M'),(N'Володимирович','M'),
(N'Юрійович','M'),(N'Сергійович','M'),(N'Андрійович','M'),(N'Ігорович','M'),(N'Романович','M'),
(N'Тарасович','M'),(N'Богданович','M'),(N'Максимович','M'),(N'Дмитрович','M'),(N'Олександрович','M'),
(N'Валерійович','M'),(N'Вікторович','M'),(N'Васильович','M'),(N'Ярославович','M'),(N'Євгенович','M'),
(N'Олегівна','F'),(N'Іванівна','F'),(N'Петрівна','F'),(N'Миколаївна','F'),(N'Володимирівна','F'),
(N'Юріївна','F'),(N'Сергіївна','F'),(N'Андріївна','F'),(N'Ігорівна','F'),(N'Романівна','F'),
(N'Богданівна','F'),(N'Дмитрівна','F'),(N'Олександрівна','F'),(N'Валеріївна','F'),(N'Вікторівна','F'),
(N'Василівна','F'),(N'Ярославівна','F'),(N'Євгенівна','F');


-- =====================================================================
-- ROW-NUMBERED LOOKUPS + REFERENCE COUNTS
-- (all pick-lists get a contiguous 1..N key so a random index can be
--  resolved with a plain JOIN instead of a NEWID() predicate)
-- =====================================================================
DECLARE @CityCount    INT = (SELECT COUNT(*) FROM #Cities);
DECLARE @ManufCount   INT = (SELECT COUNT(*) FROM #Manuf);
DECLARE @SpecCount    INT = (SELECT COUNT(*) FROM #Specs);
DECLARE @LpuCount     INT = (SELECT COUNT(*) FROM #Lpu);
DECLARE @ChainCount   INT = (SELECT COUNT(*) FROM #Chains);
DECLARE @DistribCount INT = (SELECT COUNT(*) FROM #Distrib);
DECLARE @LnCount      INT = (SELECT COUNT(*) FROM #LastNames);
DECLARE @FnCount      INT = (SELECT COUNT(*) FROM #FirstNames);

-- middle names need per-gender numbering
IF OBJECT_ID('tempdb..#MidNamesR') IS NOT NULL DROP TABLE #MidNamesR;
SELECT name, gender,
       ROW_NUMBER() OVER (PARTITION BY gender ORDER BY mn_no) AS rn
INTO #MidNamesR
FROM #MidNames;
CREATE UNIQUE CLUSTERED INDEX IX_MidNamesR ON #MidNamesR (gender, rn);

DECLARE @MnM INT = (SELECT COUNT(*) FROM #MidNamesR WHERE gender = 'M');
DECLARE @MnF INT = (SELECT COUNT(*) FROM #MidNamesR WHERE gender = 'F');


-- =====================================================================
-- POPULATE erp.PRODUCTS
-- Base rows: one per (drug, non-null dosage), up to 3 SKUs per drug.
-- +SCD2: ~40 random products get one additional version with new price.
-- =====================================================================

IF OBJECT_ID('tempdb..#GenProd') IS NOT NULL DROP TABLE #GenProd;
;WITH doses AS (
    SELECT d.drug_no, 1 AS dose_num, d.dosage1 AS dosage FROM #Drugs d WHERE d.dosage1 IS NOT NULL
    UNION ALL
    SELECT d.drug_no, 2, d.dosage2 FROM #Drugs d WHERE d.dosage2 IS NOT NULL
    UNION ALL
    SELECT d.drug_no, 3, d.dosage3 FROM #Drugs d WHERE d.dosage3 IS NOT NULL
)
SELECT
    d.drug_no, ds.dose_num, ds.dosage,
    d.inn, d.brand, d.atc, d.form, d.rx_otc,
    ABS(CHECKSUM(NEWID())) % @ManufCount + 1                                       AS manuf_no,
    CAST(4820000000000 + ABS(CHECKSUM(NEWID())) % 9999999999 AS NVARCHAR(20))      AS barcode,
    CONCAT('UA/', 1000 + ABS(CHECKSUM(NEWID())) % 19000, '/01/01')                 AS reg_no,
    CAST(ROUND(d.price_min + (d.price_max - d.price_min)
               * (ABS(CHECKSUM(NEWID())) % 100) / 100.0, 2) AS DECIMAL(18,4))      AS price,
    CAST(DATEADD(DAY, ABS(CHECKSUM(NEWID())) % DATEDIFF(DAY, @DimCreatedStart, @DimCreatedEnd),
                 @DimCreatedStart) AS DATETIME2(0))                                AS created_at
INTO #GenProd
FROM #Drugs d
JOIN doses ds ON ds.drug_no = d.drug_no;

INSERT INTO erp.PRODUCTS
    (product_id, sku_code, barcode, registration_number, inn, brand_name, atc_code, form, dosage,
     manufacturer, rx_otc, base_price_uah, is_active, created_at, updated_at)
SELECT
    CONCAT('PRD-', FORMAT(g.drug_no, '0000'), '-', g.dose_num),
    CONCAT('SKU-', FORMAT(g.drug_no, '0000'), FORMAT(g.dose_num, '00')),
    g.barcode,
    g.reg_no,
    g.inn, g.brand, g.atc, g.form, g.dosage,
    m.name,
    g.rx_otc,
    g.price,
    1,
    g.created_at,
    g.created_at
FROM #GenProd g
JOIN #Manuf m ON m.m_no = g.manuf_no;

-- SCD2: 40 products get one extra version (price change +8-18%, updated 6-18 months later)
;WITH scd2_targets AS (
    SELECT TOP (40) row_id, product_id, sku_code, barcode, registration_number, inn, brand_name,
                    atc_code, form, dosage, manufacturer, rx_otc, base_price_uah, is_active, created_at
    FROM erp.PRODUCTS
    ORDER BY NEWID()
)
INSERT INTO erp.PRODUCTS
    (product_id, sku_code, barcode, registration_number, inn, brand_name, atc_code, form, dosage,
     manufacturer, rx_otc, base_price_uah, is_active, created_at, updated_at)
SELECT
    product_id, sku_code, barcode, registration_number, inn, brand_name, atc_code, form, dosage,
    manufacturer, rx_otc,
    ROUND(base_price_uah * (1.08 + (ABS(CHECKSUM(NEWID())) % 100) / 1000.0), 2),
    is_active,
    created_at,
    DATEADD(DAY, 180 + ABS(CHECKSUM(NEWID())) % 361, created_at)
FROM scd2_targets;

-- Defects
UPDATE p SET atc_code = CONCAT('XX', 100 + ABS(CHECKSUM(NEWID())) % 900)
FROM erp.PRODUCTS p
WHERE p.row_id IN (SELECT TOP 5 row_id FROM erp.PRODUCTS ORDER BY NEWID());

UPDATE p SET brand_name = NULL
FROM erp.PRODUCTS p
WHERE p.row_id IN (SELECT TOP 3 row_id FROM erp.PRODUCTS ORDER BY NEWID());

UPDATE p SET base_price_uah = NULL
FROM erp.PRODUCTS p
WHERE p.row_id IN (SELECT TOP 2 row_id FROM erp.PRODUCTS ORDER BY NEWID());


-- =====================================================================
-- POPULATE erp.CUSTOMERS
-- 500 base + 25 duplicates (same real pharmacy with different customer_id)
-- =====================================================================

IF OBJECT_ID('tempdb..#GenCust') IS NOT NULL DROP TABLE #GenCust;
SELECT
    n.n,
    ABS(CHECKSUM(NEWID())) % @CityCount    + 1                                   AS city_no,
    ABS(CHECKSUM(NEWID())) % @ChainCount   + 1                                   AS chain_no,
    ABS(CHECKSUM(NEWID())) % @DistribCount + 1                                   AS distrib_no,
    ABS(CHECKSUM(NEWID())) % @LnCount      + 1                                   AS street_no,
    ABS(CHECKSUM(NEWID())) % 100                                                 AS kind,
    CAST(10000000 + ABS(CHECKSUM(NEWID())) % 89999999 AS NVARCHAR(10))           AS edrpou,
    CAST(1000000000 + ABS(CHECKSUM(NEWID())) % 8999999999 AS NVARCHAR(12))       AS tax_id,
    1 + ABS(CHECKSUM(NEWID())) % 999                                             AS ph_num,
    1 + ABS(CHECKSUM(NEWID())) % 50                                              AS hosp_num,
    1 + ABS(CHECKSUM(NEWID())) % 200                                             AS house_num,
    CASE WHEN ABS(CHECKSUM(NEWID())) % 100 < 95 THEN 1 ELSE 0 END                AS is_active,
    CAST(DATEADD(DAY, ABS(CHECKSUM(NEWID())) % DATEDIFF(DAY, @DimCreatedStart, @DimCreatedEnd),
                 @DimCreatedStart) AS DATETIME2(0))                              AS created_at,
    30 + ABS(CHECKSUM(NEWID())) % 400                                            AS upd_offset
INTO #GenCust
FROM #Nums n
WHERE n.n <= @N_CustomersBase;

INSERT INTO erp.CUSTOMERS
    (customer_id, edrpou, tax_id, name, customer_type, chain_name, region, city, address, is_active, created_at, updated_at)
SELECT
    CONCAT('CST-', FORMAT(g.n, '00000')),
    g.edrpou,
    g.tax_id,
    CASE
        WHEN g.kind < 75 THEN CONCAT(ch.name, N' №', g.ph_num)
        WHEN g.kind < 90 THEN CONCAT(N'Аптека при КНП №', g.hosp_num)
        ELSE CONCAT(di.name, N' — філія ', c.city)
    END,
    CASE
        WHEN g.kind < 75 THEN N'Pharmacy'
        WHEN g.kind < 90 THEN N'HospitalPharmacy'
        ELSE N'Distributor'
    END,
    ch.name,
    c.region, c.city,
    CONCAT(N'вул. ', ln.name, N' ', g.house_num),
    g.is_active,
    g.created_at,
    DATEADD(DAY, g.upd_offset, g.created_at)
FROM #GenCust g
JOIN #Cities    c  ON c.c_no   = g.city_no
JOIN #Chains    ch ON ch.ch_no = g.chain_no
JOIN #Distrib   di ON di.d_no  = g.distrib_no
JOIN #LastNames ln ON ln.ln_no = g.street_no;

-- Duplicates: 25 rows cloned with new customer_id in 9xxxx range + minor variations
INSERT INTO erp.CUSTOMERS
    (customer_id, edrpou, tax_id, name, customer_type, chain_name, region, city, address, is_active, created_at, updated_at)
SELECT
    CONCAT('CST-', FORMAT(90000 + ROW_NUMBER() OVER (ORDER BY (SELECT NULL)), '00000')),
    edrpou, tax_id,
    REPLACE(name, N'№', N'# '),  -- name variation
    customer_type,
    CASE WHEN chain_name IS NOT NULL THEN chain_name + N' мережа' ELSE chain_name END,
    region, city, address, is_active,
    DATEADD(DAY, 60 + ABS(CHECKSUM(NEWID())) % 800, created_at),
    DATEADD(DAY, 60 + ABS(CHECKSUM(NEWID())) % 800, created_at)
FROM (
    SELECT TOP (@N_CustomerDups) * FROM erp.CUSTOMERS ORDER BY NEWID()
) src;

-- Defects: some NULL regions
UPDATE c SET region = NULL
FROM erp.CUSTOMERS c
WHERE c.row_id IN (SELECT TOP 3 row_id FROM erp.CUSTOMERS ORDER BY NEWID());


-- =====================================================================
-- POPULATE erp.DOCTORS
-- 2000 base + 100 duplicates (same person, different doctor_id + variations)
-- =====================================================================

IF OBJECT_ID('tempdb..#GenDoc') IS NOT NULL DROP TABLE #GenDoc;
SELECT
    n.n,
    ABS(CHECKSUM(NEWID())) % @LnCount   + 1                                      AS ln_no,
    ABS(CHECKSUM(NEWID())) % @FnCount   + 1                                      AS fn_no,
    ABS(CHECKSUM(NEWID()))                                                       AS mid_raw,
    ABS(CHECKSUM(NEWID())) % @SpecCount + 1                                      AS spec_no,
    ABS(CHECKSUM(NEWID())) % @LpuCount  + 1                                      AS lpu_no,
    ABS(CHECKSUM(NEWID())) % @CityCount + 1                                      AS city_no,
    1 + ABS(CHECKSUM(NEWID())) % 40                                              AS lpu_num,
    ABS(CHECKSUM(NEWID())) % 100                                                 AS seg_kind,
    CASE WHEN ABS(CHECKSUM(NEWID())) % 100 < 50 THEN 1 ELSE 0 END                AS target_flag,
    CAST(DATEADD(DAY, ABS(CHECKSUM(NEWID())) % DATEDIFF(DAY, @DimCreatedStart, @DimCreatedEnd),
                 @DimCreatedStart) AS DATETIME2(0))                              AS created_at,
    ABS(CHECKSUM(NEWID())) % 300                                                 AS upd_offset
INTO #GenDoc
FROM #Nums n
WHERE n.n <= @N_DoctorsBase;

INSERT INTO erp.DOCTORS
    (doctor_id, last_name, first_name, middle_name, specialty, lpu_name, region, city, segment, target_flag, created_at, updated_at)
SELECT
    CONCAT('DOC-', FORMAT(g.n, '00000')),
    ln.name,
    fn.name,
    mn.name,
    sp.name,
    REPLACE(lp.template, N'{n}', CAST(g.lpu_num AS NVARCHAR(10))),
    c.region, c.city,
    CASE
        WHEN g.seg_kind < 15 THEN 'A'
        WHEN g.seg_kind < 50 THEN 'B'
        WHEN g.seg_kind < 90 THEN 'C'
        ELSE 'N'
    END,
    g.target_flag,
    g.created_at,
    DATEADD(DAY, g.upd_offset, g.created_at)
FROM #GenDoc g
JOIN #LastNames  ln ON ln.ln_no = g.ln_no
JOIN #FirstNames fn ON fn.fn_no = g.fn_no
JOIN #MidNamesR  mn ON mn.gender = fn.gender
                   AND mn.rn = g.mid_raw % (CASE WHEN fn.gender = 'M' THEN @MnM ELSE @MnF END) + 1
JOIN #Specs      sp ON sp.s_no  = g.spec_no
JOIN #Lpu        lp ON lp.l_no  = g.lpu_no
JOIN #Cities     c  ON c.c_no   = g.city_no;

-- Duplicates: 100 doctors re-inserted with new doctor_id + lowercased specialty
INSERT INTO erp.DOCTORS
    (doctor_id, last_name, first_name, middle_name, specialty, lpu_name, region, city, segment, target_flag, created_at, updated_at)
SELECT
    CONCAT('DOC-', FORMAT(90000 + ROW_NUMBER() OVER (ORDER BY (SELECT NULL)), '00000')),
    last_name, first_name, middle_name,
    LOWER(specialty),
    REPLACE(lpu_name, N'"Міська', N'"м.'),
    region, city, segment, target_flag,
    DATEADD(DAY, 60 + ABS(CHECKSUM(NEWID())) % 900, created_at),
    DATEADD(DAY, 60 + ABS(CHECKSUM(NEWID())) % 900, created_at)
FROM (SELECT TOP (@N_DoctorDups) * FROM erp.DOCTORS ORDER BY NEWID()) src;

-- Defects: some NULL specialties
UPDATE d SET specialty = NULL
FROM erp.DOCTORS d
WHERE d.row_id IN (SELECT TOP 8 row_id FROM erp.DOCTORS ORDER BY NEWID());


-- =====================================================================
-- POPULATE erp.EMPLOYEES — managers first, then reps
-- =====================================================================

-- Managers (no manager_id)
IF OBJECT_ID('tempdb..#GenMgr') IS NOT NULL DROP TABLE #GenMgr;
SELECT
    n.n,
    ABS(CHECKSUM(NEWID())) % @LnCount   + 1                                      AS ln_no,
    ABS(CHECKSUM(NEWID())) % @FnCount   + 1                                      AS fn_no,
    ABS(CHECKSUM(NEWID())) % @CityCount + 1                                      AS city_no,
    ABS(CHECKSUM(NEWID())) % 3                                                   AS line_kind,
    ABS(CHECKSUM(NEWID())) % 3287                                                AS hire_offset,
    ABS(CHECKSUM(NEWID())) % DATEDIFF(DAY, @DimCreatedStart, '2022-01-01')       AS created_offset
INTO #GenMgr
FROM #Nums n
WHERE n.n <= @N_ManagerCount;

INSERT INTO erp.EMPLOYEES
    (employee_id, full_name, role, territory, line, manager_id, hire_date, is_active, created_at, updated_at)
SELECT
    CONCAT('EMP-', FORMAT(g.n, '000')),
    CONCAT(ln.name, N' ', fn.name),
    N'Регіональний менеджер',
    c.region,
    CASE g.line_kind WHEN 0 THEN N'RX' WHEN 1 THEN N'OTC' ELSE N'Both' END,
    NULL,
    DATEADD(DAY, g.hire_offset, '2010-01-01'),
    1,
    DATEADD(DAY, g.created_offset, @DimCreatedStart),
    DATEADD(DAY, g.created_offset, @DimCreatedStart)
FROM #GenMgr g
JOIN #LastNames  ln ON ln.ln_no = g.ln_no
JOIN #FirstNames fn ON fn.fn_no = g.fn_no
JOIN #Cities     c  ON c.c_no   = g.city_no;

-- Medical reps (referencing random manager)
IF OBJECT_ID('tempdb..#GenRep') IS NOT NULL DROP TABLE #GenRep;
SELECT
    n.n,
    ABS(CHECKSUM(NEWID())) % @LnCount   + 1                                      AS ln_no,
    ABS(CHECKSUM(NEWID())) % @FnCount   + 1                                      AS fn_no,
    ABS(CHECKSUM(NEWID())) % @CityCount + 1                                      AS city_no,
    ABS(CHECKSUM(NEWID())) % 5                                                   AS terr_kind,
    ABS(CHECKSUM(NEWID())) % 2                                                   AS line_kind,
    1 + ABS(CHECKSUM(NEWID())) % @N_ManagerCount                                 AS mgr_num,
    ABS(CHECKSUM(NEWID())) % DATEDIFF(DAY, '2015-01-01', '2024-06-30')           AS hire_offset,
    CASE WHEN ABS(CHECKSUM(NEWID())) % 100 < 92 THEN 1 ELSE 0 END                AS is_active,
    ABS(CHECKSUM(NEWID())) % DATEDIFF(DAY, @DimCreatedStart, '2024-01-01')       AS created_offset
INTO #GenRep
FROM #Nums n
WHERE n.n <= @N_RepCount;

INSERT INTO erp.EMPLOYEES
    (employee_id, full_name, role, territory, line, manager_id, hire_date, is_active, created_at, updated_at)
SELECT
    CONCAT('EMP-', FORMAT(@N_ManagerCount + g.n, '000')),
    CONCAT(ln.name, N' ', fn.name),
    N'Медичний представник',
    CONCAT(c.city, N'-',
           CASE g.terr_kind
               WHEN 0 THEN N'Центр' WHEN 1 THEN N'Захід' WHEN 2 THEN N'Схід'
               WHEN 3 THEN N'Північ' ELSE N'Південь' END),
    CASE g.line_kind WHEN 0 THEN N'RX' ELSE N'OTC' END,
    CONCAT('EMP-', FORMAT(g.mgr_num, '000')),
    DATEADD(DAY, g.hire_offset, '2015-01-01'),
    g.is_active,
    DATEADD(DAY, g.created_offset, @DimCreatedStart),
    DATEADD(DAY, g.created_offset, @DimCreatedStart)
FROM #GenRep g
JOIN #LastNames  ln ON ln.ln_no = g.ln_no
JOIN #FirstNames fn ON fn.fn_no = g.fn_no
JOIN #Cities     c  ON c.c_no   = g.city_no;


-- =====================================================================
-- POPULATE erp.WAREHOUSES
-- 5 own warehouses in major cities + consignment at distributors
-- =====================================================================

-- Own warehouses
INSERT INTO erp.WAREHOUSES
    (warehouse_id, warehouse_code, name, warehouse_type, owner_customer_id, region, city, created_at, updated_at)
VALUES
    ('WH-001','OWN-KYI',N'Центральний склад Київ',   N'Own', NULL, N'Київ',              N'Київ',  '2018-01-15','2018-01-15'),
    ('WH-002','OWN-LVI',N'Центральний склад Львів', N'Own', NULL, N'Львівська',         N'Львів', '2019-03-20','2019-03-20'),
    ('WH-003','OWN-DNI',N'Центральний склад Дніпро',N'Own', NULL, N'Дніпропетровська',  N'Дніпро','2019-06-10','2019-06-10'),
    ('WH-004','OWN-ODE',N'Центральний склад Одеса', N'Own', NULL, N'Одеська',           N'Одеса', '2020-02-05','2020-02-05'),
    ('WH-005','OWN-KHA',N'Центральний склад Харків',N'Own', NULL, N'Харківська',        N'Харків','2020-08-12','2020-08-12');

-- Consignment (linked to distributor customers)
IF OBJECT_ID('tempdb..#DistPool') IS NOT NULL DROP TABLE #DistPool;
SELECT customer_id, name, region, city,
       ROW_NUMBER() OVER (ORDER BY customer_id) AS rn
INTO #DistPool
FROM erp.CUSTOMERS
WHERE customer_type = N'Distributor';
CREATE UNIQUE CLUSTERED INDEX IX_DistPool ON #DistPool (rn);
DECLARE @DistPoolCount INT = (SELECT COUNT(*) FROM #DistPool);

IF OBJECT_ID('tempdb..#GenWh') IS NOT NULL DROP TABLE #GenWh;
SELECT
    n.n,
    ABS(CHECKSUM(NEWID())) % NULLIF(@DistPoolCount, 0) + 1                                          AS dist_rn,
    ABS(CHECKSUM(NEWID())) % DATEDIFF(DAY, @DimCreatedStart, '2023-01-01')               AS created_offset
INTO #GenWh
FROM #Nums n
WHERE n.n <= @N_Warehouses - 5;

INSERT INTO erp.WAREHOUSES
    (warehouse_id, warehouse_code, name, warehouse_type, owner_customer_id, region, city, created_at, updated_at)
SELECT
    CONCAT('WH-', FORMAT(5 + g.n, '000')),
    CONCAT('CON-', FORMAT(5 + g.n, '000')),
    CONCAT(N'Консигнація ', dp.name),
    N'Consignment',
    dp.customer_id,
    dp.region, dp.city,
    DATEADD(DAY, g.created_offset, @DimCreatedStart),
    DATEADD(DAY, g.created_offset, @DimCreatedStart)
FROM #GenWh g
JOIN #DistPool dp ON dp.rn = g.dist_rn;


-- =====================================================================
-- POOL TABLES for fact generation
-- =====================================================================
IF OBJECT_ID('tempdb..#ProdPool') IS NOT NULL DROP TABLE #ProdPool;
;WITH first_ver AS (
    SELECT product_id, base_price_uah,
           ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY updated_at) AS ver
    FROM erp.PRODUCTS
)
SELECT product_id, base_price_uah,
       ROW_NUMBER() OVER (ORDER BY product_id) AS rn
INTO #ProdPool
FROM first_ver WHERE ver = 1;
CREATE UNIQUE CLUSTERED INDEX IX_ProdPool ON #ProdPool (rn);
DECLARE @ProdCount INT = (SELECT COUNT(*) FROM #ProdPool);

IF OBJECT_ID('tempdb..#CustPool') IS NOT NULL DROP TABLE #CustPool;
SELECT customer_id, ROW_NUMBER() OVER (ORDER BY customer_id) AS rn
INTO #CustPool FROM erp.CUSTOMERS;
CREATE UNIQUE CLUSTERED INDEX IX_CustPool ON #CustPool (rn);
DECLARE @CustCount INT = (SELECT COUNT(*) FROM #CustPool);

IF OBJECT_ID('tempdb..#WhPool') IS NOT NULL DROP TABLE #WhPool;
SELECT warehouse_id, ROW_NUMBER() OVER (ORDER BY warehouse_id) AS rn
INTO #WhPool FROM erp.WAREHOUSES;
CREATE UNIQUE CLUSTERED INDEX IX_WhPool ON #WhPool (rn);
DECLARE @WhCount INT = (SELECT COUNT(*) FROM #WhPool);

IF OBJECT_ID('tempdb..#RepPool') IS NOT NULL DROP TABLE #RepPool;
SELECT employee_id, ROW_NUMBER() OVER (ORDER BY employee_id) AS rn
INTO #RepPool FROM erp.EMPLOYEES WHERE role = N'Медичний представник' AND is_active = 1;
CREATE UNIQUE CLUSTERED INDEX IX_RepPool ON #RepPool (rn);
DECLARE @RepCount INT = (SELECT COUNT(*) FROM #RepPool);

IF OBJECT_ID('tempdb..#EmpPool') IS NOT NULL DROP TABLE #EmpPool;
SELECT employee_id, ROW_NUMBER() OVER (ORDER BY employee_id) AS rn
INTO #EmpPool FROM erp.EMPLOYEES;
CREATE UNIQUE CLUSTERED INDEX IX_EmpPool ON #EmpPool (rn);
DECLARE @EmpCount INT = (SELECT COUNT(*) FROM #EmpPool);

IF OBJECT_ID('tempdb..#DocPool') IS NOT NULL DROP TABLE #DocPool;
SELECT doctor_id, ROW_NUMBER() OVER (ORDER BY doctor_id) AS rn
INTO #DocPool FROM erp.DOCTORS;
CREATE UNIQUE CLUSTERED INDEX IX_DocPool ON #DocPool (rn);
DECLARE @DocCount INT = (SELECT COUNT(*) FROM #DocPool);


-- =====================================================================
-- POPULATE erp.SALES_ORDERS
-- =====================================================================

IF OBJECT_ID('tempdb..#GenSales') IS NOT NULL DROP TABLE #GenSales;
SELECT
    n.n,
    ABS(CHECKSUM(NEWID())) % @CustCount + 1                                      AS cust_rn,
    ABS(CHECKSUM(NEWID())) % @WhCount   + 1                                      AS wh_rn,
    ABS(CHECKSUM(NEWID())) % @ProdCount + 1                                      AS prod_rn,
    ABS(CHECKSUM(NEWID())) % @RepCount  + 1                                      AS rep_rn,
    DATEADD(DAY, ABS(CHECKSUM(NEWID())) % @DateRangeDays, @DateStart)            AS order_date,
    1 + ABS(CHECKSUM(NEWID())) % 7                                               AS deliv_days,
    1 + ABS(CHECKSUM(NEWID())) % 20                                              AS quantity,
    CAST(CASE ABS(CHECKSUM(NEWID())) % 10
             WHEN 0 THEN 5.0 WHEN 1 THEN 10.0 WHEN 2 THEN 15.0
             ELSE 0.0 END AS DECIMAL(5,2))                                       AS discount_pct,
    ABS(CHECKSUM(NEWID())) % 100                                                 AS status_kind,
    8 + ABS(CHECKSUM(NEWID())) % 10                                              AS ord_hour
INTO #GenSales
FROM #Nums n
WHERE n.n <= @N_Sales;

INSERT INTO erp.SALES_ORDERS
    (order_line_id, order_number, order_date, delivery_date, customer_id, warehouse_id,
     product_id, employee_id, quantity, unit_price, discount_pct, line_amount,
     currency, status, created_at, updated_at)
SELECT
    CONCAT('ORD-', FORMAT(g.n, '0000000'), '-L1'),
    CONCAT('ORD-', FORMAT((g.n / 3) + 1, '000000')),
    g.order_date,
    DATEADD(DAY, g.deliv_days, g.order_date),
    cu.customer_id,
    wh.warehouse_id,
    pp.product_id,
    rp.employee_id,
    g.quantity,
    pp.base_price_uah,
    g.discount_pct,
    ROUND(g.quantity * pp.base_price_uah * (1 - g.discount_pct / 100.0), 2),
    N'UAH',
    CASE
        WHEN g.status_kind < 60 THEN N'DELIVERED'
        WHEN g.status_kind < 75 THEN N'SHIPPED'
        WHEN g.status_kind < 85 THEN N'CONFIRMED'
        WHEN g.status_kind < 90 THEN N'NEW'
        WHEN g.status_kind < 95 THEN N'CANCELLED'
        ELSE N'RETURN'
    END,
    DATEADD(HOUR, g.ord_hour, CAST(g.order_date AS DATETIME2(0))),
    DATEADD(HOUR, g.ord_hour, CAST(g.order_date AS DATETIME2(0)))
FROM #GenSales g
JOIN #CustPool cu ON cu.rn = g.cust_rn
JOIN #WhPool   wh ON wh.rn = g.wh_rn
JOIN #ProdPool pp ON pp.rn = g.prod_rn
JOIN #RepPool  rp ON rp.rn = g.rep_rn;

-- Duplicates (2%)
INSERT INTO erp.SALES_ORDERS
    (order_line_id, order_number, order_date, delivery_date, customer_id, warehouse_id,
     product_id, employee_id, quantity, unit_price, discount_pct, line_amount,
     currency, status, created_at, updated_at)
SELECT
    order_line_id, order_number, order_date, delivery_date, customer_id, warehouse_id,
    product_id, employee_id, quantity, unit_price, discount_pct, line_amount,
    currency, status, created_at, updated_at
FROM (SELECT TOP (@N_SalesDups) * FROM erp.SALES_ORDERS ORDER BY NEWID()) src;

-- Defects
UPDATE s SET currency = CASE ABS(CHECKSUM(NEWID())) % 2 WHEN 0 THEN N'USD' ELSE N'EUR' END
FROM erp.SALES_ORDERS s
WHERE s.row_id IN (SELECT TOP 250 row_id FROM erp.SALES_ORDERS ORDER BY NEWID());

UPDATE s SET quantity = -quantity
FROM erp.SALES_ORDERS s
WHERE s.row_id IN (SELECT TOP 250 row_id FROM erp.SALES_ORDERS ORDER BY NEWID());

UPDATE s SET line_amount = ROUND(line_amount * (1.1 + ABS(CHECKSUM(NEWID())) % 40 / 100.0), 2)
FROM erp.SALES_ORDERS s
WHERE s.row_id IN (SELECT TOP 250 row_id FROM erp.SALES_ORDERS ORDER BY NEWID());

UPDATE s SET order_date = CASE ABS(CHECKSUM(NEWID())) % 2 WHEN 0 THEN '2019-06-15' ELSE '2028-03-20' END
FROM erp.SALES_ORDERS s
WHERE s.row_id IN (SELECT TOP 100 row_id FROM erp.SALES_ORDERS ORDER BY NEWID());

UPDATE s SET employee_id = NULL
FROM erp.SALES_ORDERS s
WHERE s.row_id IN (SELECT TOP 500 row_id FROM erp.SALES_ORDERS ORDER BY NEWID());

UPDATE s SET customer_id = CONCAT('CST-', FORMAT(700000 + ABS(CHECKSUM(NEWID())) % 99999, '00000'))
FROM erp.SALES_ORDERS s
WHERE s.row_id IN (SELECT TOP 500 row_id FROM erp.SALES_ORDERS ORDER BY NEWID());


-- =====================================================================
-- POPULATE erp.INVENTORY_MOVEMENTS
-- =====================================================================

IF OBJECT_ID('tempdb..#GenInv') IS NOT NULL DROP TABLE #GenInv;
SELECT
    n.n,
    ABS(CHECKSUM(NEWID())) % @WhCount   + 1                                      AS wh_rn,
    ABS(CHECKSUM(NEWID())) % @ProdCount + 1                                      AS prod_rn,
    ABS(CHECKSUM(NEWID())) % @EmpCount  + 1                                      AS emp_rn,
    DATEADD(SECOND, ABS(CHECKSUM(NEWID())) % (@DateRangeDays * 86400),
            CAST(@DateStart AS DATETIME2(0)))                                    AS movement_dt,
    ABS(CHECKSUM(NEWID())) % 100                                                 AS lang_kind,
    ABS(CHECKSUM(NEWID())) % 100                                                 AS type_kind,
    ABS(CHECKSUM(NEWID())) % 4                                                   AS ukr_kind,
    1 + ABS(CHECKSUM(NEWID())) % 100                                             AS quantity,
    ABS(CHECKSUM(NEWID())) % 4                                                   AS ref_kind,
    100000 + ABS(CHECKSUM(NEWID())) % 899999                                     AS ref_num
INTO #GenInv
FROM #Nums n
WHERE n.n <= @N_Inventory;

INSERT INTO erp.INVENTORY_MOVEMENTS
    (movement_id, movement_date, warehouse_id, product_id, movement_type, quantity,
     reference_document, employee_id, created_at, updated_at)
SELECT
    CONCAT('MOV-', FORMAT(g.n, '00000000')),
    g.movement_dt,
    wh.warehouse_id,
    pp.product_id,
    CASE
        WHEN g.lang_kind < 10 THEN
            CASE g.ukr_kind
                WHEN 0 THEN N'Прихід' WHEN 1 THEN N'Видача'
                WHEN 2 THEN N'Переміщення' ELSE N'Списання' END
        ELSE
            CASE
                WHEN g.type_kind < 35 THEN N'IN'
                WHEN g.type_kind < 80 THEN N'OUT'
                WHEN g.type_kind < 90 THEN N'TRANSFER'
                ELSE N'WRITEOFF'
            END
    END,
    g.quantity,
    CONCAT(
        CASE g.ref_kind
            WHEN 0 THEN N'INV' WHEN 1 THEN N'PO' WHEN 2 THEN N'TR' ELSE N'WO' END,
        N'-', g.ref_num
    ),
    em.employee_id,
    g.movement_dt,
    g.movement_dt
FROM #GenInv g
JOIN #WhPool   wh ON wh.rn = g.wh_rn
JOIN #ProdPool pp ON pp.rn = g.prod_rn
JOIN #EmpPool  em ON em.rn = g.emp_rn;

-- Duplicates
INSERT INTO erp.INVENTORY_MOVEMENTS
    (movement_id, movement_date, warehouse_id, product_id, movement_type, quantity,
     reference_document, employee_id, created_at, updated_at)
SELECT movement_id, movement_date, warehouse_id, product_id, movement_type, quantity,
       reference_document, employee_id, created_at, updated_at
FROM (SELECT TOP (@N_InventoryDups) * FROM erp.INVENTORY_MOVEMENTS ORDER BY NEWID()) src;

-- Defects
UPDATE m SET warehouse_id = CONCAT('WH-', FORMAT(900 + ABS(CHECKSUM(NEWID())) % 99, '000'))
FROM erp.INVENTORY_MOVEMENTS m
WHERE m.row_id IN (SELECT TOP 800 row_id FROM erp.INVENTORY_MOVEMENTS ORDER BY NEWID());

UPDATE m SET quantity = 500000 + ABS(CHECKSUM(NEWID())) % 9499999
FROM erp.INVENTORY_MOVEMENTS m
WHERE m.row_id IN (SELECT TOP 250 row_id FROM erp.INVENTORY_MOVEMENTS ORDER BY NEWID());

UPDATE m SET quantity = -quantity
FROM erp.INVENTORY_MOVEMENTS m
WHERE m.row_id IN (SELECT TOP 400 row_id FROM erp.INVENTORY_MOVEMENTS ORDER BY NEWID());


-- =====================================================================
-- POPULATE erp.DOCTOR_VISITS
-- =====================================================================

IF OBJECT_ID('tempdb..#GenVis') IS NOT NULL DROP TABLE #GenVis;
SELECT
    n.n,
    ABS(CHECKSUM(NEWID())) % @DocCount  + 1                                      AS doc_rn,
    ABS(CHECKSUM(NEWID())) % @RepCount  + 1                                      AS rep_rn,
    ABS(CHECKSUM(NEWID())) % @ProdCount + 1                                      AS prod_rn,
    DATEADD(SECOND, ABS(CHECKSUM(NEWID())) % (@DateRangeDays * 86400),
            CAST(@DateStart AS DATETIME2(0)))                                    AS visit_dt,
    ABS(CHECKSUM(NEWID())) % 100                                                 AS act_kind,
    ABS(CHECKSUM(NEWID())) % 361                                                 AS dur_raw,
    ABS(CHECKSUM(NEWID())) % 10                                                  AS samples_kind,
    ABS(CHECKSUM(NEWID())) % 8                                                   AS notes_kind
INTO #GenVis
FROM #Nums n
WHERE n.n <= @N_Visits;

INSERT INTO erp.DOCTOR_VISITS
    (visit_id, visit_date, doctor_id, employee_id, product_id, activity_type,
     duration_min, samples_qty, notes, created_at, updated_at)
SELECT
    CONCAT('VIS-', FORMAT(g.n, '0000000')),
    g.visit_dt,
    dc.doctor_id,
    rp.employee_id,
    pp.product_id,
    act.activity_type,
    CASE act.activity_type
        WHEN N'Visit'      THEN 10  + g.dur_raw % 36
        WHEN N'RoundTable' THEN 60  + g.dur_raw % 61
        WHEN N'Symposium'  THEN 120 + g.dur_raw % 361
        ELSE 15 + g.dur_raw % 46
    END,
    CASE g.samples_kind
        WHEN 0 THEN 10 WHEN 1 THEN 5 WHEN 2 THEN 3 WHEN 3 THEN 3
        WHEN 4 THEN 5 WHEN 5 THEN 3 ELSE 0 END,
    CASE g.notes_kind
        WHEN 0 THEN N'Обговорено нову лінійку'
        WHEN 1 THEN N'Передано зразки'
        WHEN 2 THEN N'Візит з тренером'
        WHEN 3 THEN N'Домовились про круглий стіл'
        WHEN 4 THEN N'Обговорено клінічні дані'
        WHEN 5 THEN N'Лікар не прийняв, перенесено'
        ELSE NULL END,
    g.visit_dt, g.visit_dt
FROM #GenVis g
JOIN #DocPool  dc ON dc.rn = g.doc_rn
JOIN #RepPool  rp ON rp.rn = g.rep_rn
JOIN #ProdPool pp ON pp.rn = g.prod_rn
CROSS APPLY (SELECT CASE
                        WHEN g.act_kind < 75 THEN N'Visit'
                        WHEN g.act_kind < 85 THEN N'RoundTable'
                        WHEN g.act_kind < 95 THEN N'EDetailing'
                        ELSE N'Symposium' END AS activity_type) act;

-- Duplicates
INSERT INTO erp.DOCTOR_VISITS
    (visit_id, visit_date, doctor_id, employee_id, product_id, activity_type,
     duration_min, samples_qty, notes, created_at, updated_at)
SELECT visit_id, visit_date, doctor_id, employee_id, product_id, activity_type,
       duration_min, samples_qty, notes, created_at, updated_at
FROM (SELECT TOP (@N_VisitDups) * FROM erp.DOCTOR_VISITS ORDER BY NEWID()) src;

-- Defects
UPDATE v SET doctor_id = CONCAT('DOC-', FORMAT(700000 + ABS(CHECKSUM(NEWID())) % 99999, '00000'))
FROM erp.DOCTOR_VISITS v
WHERE v.row_id IN (SELECT TOP 150 row_id FROM erp.DOCTOR_VISITS ORDER BY NEWID());

UPDATE v SET duration_min = 1000 + ABS(CHECKSUM(NEWID())) % 4000
FROM erp.DOCTOR_VISITS v
WHERE v.row_id IN (SELECT TOP 45 row_id FROM erp.DOCTOR_VISITS ORDER BY NEWID());


-- =====================================================================
-- POPULATE erp.PRESCRIPTIONS
-- =====================================================================

IF OBJECT_ID('tempdb..#GenRx') IS NOT NULL DROP TABLE #GenRx;
SELECT
    n.n,
    ABS(CHECKSUM(NEWID())) % @DocCount  + 1                                      AS doc_rn,
    ABS(CHECKSUM(NEWID())) % @ProdCount + 1                                      AS prod_rn,
    ABS(CHECKSUM(NEWID())) % @RepCount  + 1                                      AS rep_rn,
    DATEADD(DAY, ABS(CHECKSUM(NEWID())) % @DateRangeDays, @DateStart)            AS rx_date,
    1 + ABS(CHECKSUM(NEWID())) % 8                                               AS pat_count,
    ABS(CHECKSUM(NEWID())) % 3                                                   AS rx_extra,
    9 + ABS(CHECKSUM(NEWID())) % 10                                              AS rx_hour
INTO #GenRx
FROM #Nums n
WHERE n.n <= @N_Rx;

INSERT INTO erp.PRESCRIPTIONS
    (prescription_id, prescription_date, doctor_id, product_id, patients_count,
     prescriptions_count, entered_by_employee_id, created_at, updated_at)
SELECT
    CONCAT('RX-', FORMAT(g.n, '0000000')),
    g.rx_date,
    dc.doctor_id,
    pp.product_id,
    g.pat_count,
    g.pat_count + g.rx_extra,
    rp.employee_id,
    DATEADD(HOUR, g.rx_hour, CAST(g.rx_date AS DATETIME2(0))),
    DATEADD(HOUR, g.rx_hour, CAST(g.rx_date AS DATETIME2(0)))
FROM #GenRx g
JOIN #DocPool  dc ON dc.rn = g.doc_rn
JOIN #ProdPool pp ON pp.rn = g.prod_rn
JOIN #RepPool  rp ON rp.rn = g.rep_rn;

-- Duplicates
INSERT INTO erp.PRESCRIPTIONS
    (prescription_id, prescription_date, doctor_id, product_id, patients_count,
     prescriptions_count, entered_by_employee_id, created_at, updated_at)
SELECT prescription_id, prescription_date, doctor_id, product_id, patients_count,
       prescriptions_count, entered_by_employee_id, created_at, updated_at
FROM (SELECT TOP (@N_RxDups) * FROM erp.PRESCRIPTIONS ORDER BY NEWID()) src;

-- Defects
UPDATE r SET prescriptions_count = NULL
FROM erp.PRESCRIPTIONS r
WHERE r.row_id IN (SELECT TOP 300 row_id FROM erp.PRESCRIPTIONS ORDER BY NEWID());

UPDATE r SET doctor_id = CONCAT('DOC-', FORMAT(800000 + ABS(CHECKSUM(NEWID())) % 99999, '00000'))
FROM erp.PRESCRIPTIONS r
WHERE r.row_id IN (SELECT TOP 300 row_id FROM erp.PRESCRIPTIONS ORDER BY NEWID());


-- =====================================================================
-- POPULATE erp.ADVERSE_EVENTS
-- Base rows + ~15% follow-up versions (case_version 2, 3)
-- =====================================================================

IF OBJECT_ID('tempdb..#GenAe') IS NOT NULL DROP TABLE #GenAe;
SELECT
    n.n,
    ABS(CHECKSUM(NEWID())) % @ProdCount + 1                                      AS prod_rn,
    ABS(CHECKSUM(NEWID())) % @DocCount  + 1                                      AS doc_rn,
    ABS(CHECKSUM(NEWID())) % @CityCount + 1                                      AS city_no,
    DATEADD(DAY, ABS(CHECKSUM(NEWID())) % @DateRangeDays, @DateStart)            AS report_date,
    ABS(CHECKSUM(NEWID())) % 100                                                 AS ser_kind,
    ABS(CHECKSUM(NEWID())) % 10                                                  AS outcome_kind,
    ABS(CHECKSUM(NEWID())) % 100                                                 AS source_kind
INTO #GenAe
FROM #Nums n
WHERE n.n <= @N_AE;

-- Base version 1 for all
INSERT INTO erp.ADVERSE_EVENTS
    (ae_id, report_date, product_id, reporter_doctor_id, seriousness, outcome,
     region, report_source, case_version, created_at, updated_at)
SELECT
    CONCAT('AE-', FORMAT(g.n, '000000')),
    g.report_date,
    pp.product_id,
    dc.doctor_id,
    CASE
        WHEN g.ser_kind < 70 THEN N'Non-serious'
        WHEN g.ser_kind < 95 THEN N'Serious'
        ELSE N'Critical'
    END,
    CASE g.outcome_kind
        WHEN 0 THEN N'Recovered with sequelae'
        WHEN 1 THEN N'Recovering'
        WHEN 2 THEN N'Not recovered'
        WHEN 3 THEN N'Unknown'
        ELSE N'Recovered' END,
    c.region,
    CASE
        WHEN g.source_kind < 50 THEN N'HCP'
        WHEN g.source_kind < 75 THEN N'Patient'
        WHEN g.source_kind < 90 THEN N'Pharmacy'
        WHEN g.source_kind < 95 THEN N'Literature'
        ELSE N'Study' END,
    1,
    CAST(g.report_date AS DATETIME2(0)), CAST(g.report_date AS DATETIME2(0))
FROM #GenAe g
JOIN #ProdPool pp ON pp.rn   = g.prod_rn
JOIN #DocPool  dc ON dc.rn   = g.doc_rn
JOIN #Cities   c  ON c.c_no  = g.city_no;

-- ~12% get version 2 (follow-up 0-90 days later)
INSERT INTO erp.ADVERSE_EVENTS
    (ae_id, report_date, product_id, reporter_doctor_id, seriousness, outcome,
     region, report_source, case_version, created_at, updated_at)
SELECT TOP (@N_AE * 12 / 100)
    ae_id, DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 91, report_date),
    product_id, reporter_doctor_id, seriousness,
    CASE ABS(CHECKSUM(NEWID())) % 5
        WHEN 0 THEN N'Recovered' WHEN 1 THEN N'Recovering'
        WHEN 2 THEN N'Recovered with sequelae' WHEN 3 THEN N'Not recovered'
        ELSE N'Unknown' END,
    region, report_source, 2,
    DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 91, created_at),
    DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 91, created_at)
FROM erp.ADVERSE_EVENTS WHERE case_version = 1
ORDER BY NEWID();

-- ~3% get version 3
INSERT INTO erp.ADVERSE_EVENTS
    (ae_id, report_date, product_id, reporter_doctor_id, seriousness, outcome,
     region, report_source, case_version, created_at, updated_at)
SELECT TOP (@N_AE * 3 / 100)
    ae_id, DATEADD(DAY, 30 + ABS(CHECKSUM(NEWID())) % 91, report_date),
    product_id, reporter_doctor_id, seriousness,
    CASE ABS(CHECKSUM(NEWID())) % 3 WHEN 0 THEN N'Recovered' WHEN 1 THEN N'Fatal' ELSE N'Unknown' END,
    region, report_source, 3,
    DATEADD(DAY, 30 + ABS(CHECKSUM(NEWID())) % 91, created_at),
    DATEADD(DAY, 30 + ABS(CHECKSUM(NEWID())) % 91, created_at)
FROM erp.ADVERSE_EVENTS WHERE case_version = 2
ORDER BY NEWID();

-- Defects: logic errors (Critical + Recovered)
UPDATE a SET seriousness = N'Critical', outcome = N'Recovered'
FROM erp.ADVERSE_EVENTS a
WHERE a.row_id IN (SELECT TOP 15 row_id FROM erp.ADVERSE_EVENTS ORDER BY NEWID());

-- Defects: NULL outcome
UPDATE a SET outcome = NULL
FROM erp.ADVERSE_EVENTS a
WHERE a.row_id IN (SELECT TOP 50 row_id FROM erp.ADVERSE_EVENTS ORDER BY NEWID());


-- =====================================================================
-- CLEANUP
-- =====================================================================
DROP TABLE #Nums;
DROP TABLE #Drugs;
DROP TABLE #Manuf;
DROP TABLE #Cities;
DROP TABLE #Specs;
DROP TABLE #Lpu;
DROP TABLE #Chains;
DROP TABLE #Distrib;
DROP TABLE #LastNames;
DROP TABLE #FirstNames;
DROP TABLE #MidNames;
DROP TABLE #MidNamesR;
DROP TABLE #ProdPool;
DROP TABLE #CustPool;
DROP TABLE #WhPool;
DROP TABLE #RepPool;
DROP TABLE #EmpPool;
DROP TABLE #DocPool;
DROP TABLE #DistPool;
DROP TABLE #GenProd;
DROP TABLE #GenCust;
DROP TABLE #GenDoc;
DROP TABLE #GenMgr;
DROP TABLE #GenRep;
DROP TABLE #GenWh;
DROP TABLE #GenSales;
DROP TABLE #GenInv;
DROP TABLE #GenVis;
DROP TABLE #GenRx;
DROP TABLE #GenAe;


-- =====================================================================
-- ROW COUNT REPORT
-- =====================================================================
SELECT 'PRODUCTS'            AS table_name, COUNT(*) AS rows_generated FROM erp.PRODUCTS
UNION ALL SELECT 'CUSTOMERS',            COUNT(*) FROM erp.CUSTOMERS
UNION ALL SELECT 'DOCTORS',              COUNT(*) FROM erp.DOCTORS
UNION ALL SELECT 'EMPLOYEES',            COUNT(*) FROM erp.EMPLOYEES
UNION ALL SELECT 'WAREHOUSES',           COUNT(*) FROM erp.WAREHOUSES
UNION ALL SELECT 'SALES_ORDERS',         COUNT(*) FROM erp.SALES_ORDERS
UNION ALL SELECT 'INVENTORY_MOVEMENTS',  COUNT(*) FROM erp.INVENTORY_MOVEMENTS
UNION ALL SELECT 'DOCTOR_VISITS',        COUNT(*) FROM erp.DOCTOR_VISITS
UNION ALL SELECT 'PRESCRIPTIONS',        COUNT(*) FROM erp.PRESCRIPTIONS
UNION ALL SELECT 'ADVERSE_EVENTS',       COUNT(*) FROM erp.ADVERSE_EVENTS;
