# Silver — залежності між об'єктами

Згенеровано з міграцій `V260819.1000` (таблиці) та `V260819.1020` (view).
Читається як «**Object** не можна створити/завантажити, поки не готовий **DependOnObject**».

Два типи ребер:

* `dwh.<Table>` → `dwh.v<Table>` — таблиця наповнюється зі свого джерельного view
  (`spUpsertSCDDimension` для `Dim*`/`Ref*`, `spFullFct` для `Fct*`);
* `dwh.v<Object>` → `dwh.<Object>` — view читає вже завантажений silver-об'єкт
  (резолв durable keys).

## 1. Залежності всередині silver (92 ребра)

| Object | DependOnObject |
|---|---|
| dwh.DimActivityType | dwh.vDimActivityType |
| dwh.DimAeOutcome | dwh.vDimAeOutcome |
| dwh.DimAeSeriousness | dwh.vDimAeSeriousness |
| dwh.DimChain | dwh.vDimChain |
| dwh.DimCity | dwh.vDimCity |
| dwh.DimClientAccount | dwh.vDimClientAccount |
| dwh.DimDoctor | dwh.vDimDoctor |
| dwh.DimEmployee | dwh.vDimEmployee |
| dwh.DimLegalEntity | dwh.vDimLegalEntity |
| dwh.DimLpu | dwh.vDimLpu |
| dwh.DimManufacturer | dwh.vDimManufacturer |
| dwh.DimProduct | dwh.vDimProduct |
| dwh.DimRegion | dwh.vDimRegion |
| dwh.DimReportSource | dwh.vDimReportSource |
| dwh.DimSpecialty | dwh.vDimSpecialty |
| dwh.DimTerritory | dwh.vDimTerritory |
| dwh.DimWarehouse | dwh.vDimWarehouse |
| dwh.FctAdverseEvent | dwh.vFctAdverseEvent |
| dwh.FctInventoryMovement | dwh.vFctInventoryMovement |
| dwh.FctPrescription | dwh.vFctPrescription |
| dwh.FctSales | dwh.vFctSales |
| dwh.FctVisit | dwh.vFctVisit |
| dwh.RefClientAccount | dwh.vRefClientAccount |
| dwh.RefDoctor | dwh.vRefDoctor |
| dwh.RefEmployee | dwh.vRefEmployee |
| dwh.RefMovementType | dwh.vRefMovementType |
| dwh.RefProduct | dwh.vRefProduct |
| dwh.RefWarehouse | dwh.vRefWarehouse |
| dwh.vDimCity | dwh.DimRegion |
| dwh.vDimClientAccount | dwh.DimChain |
| dwh.vDimClientAccount | dwh.DimCity |
| dwh.vDimClientAccount | dwh.DimLegalEntity |
| dwh.vDimClientAccount | dwh.DimRegion |
| dwh.vDimDoctor | dwh.DimCity |
| dwh.vDimDoctor | dwh.DimLpu |
| dwh.vDimDoctor | dwh.DimRegion |
| dwh.vDimDoctor | dwh.DimSpecialty |
| dwh.vDimEmployee | dwh.DimEmployee |
| dwh.vDimEmployee | dwh.DimTerritory |
| dwh.vDimLpu | dwh.DimCity |
| dwh.vDimLpu | dwh.DimRegion |
| dwh.vDimProduct | dwh.DimAtcClass |
| dwh.vDimProduct | dwh.DimManufacturer |
| dwh.vDimWarehouse | dwh.DimCity |
| dwh.vDimWarehouse | dwh.DimRegion |
| dwh.vDimWarehouse | dwh.RefClientAccount |
| dwh.vFctAdverseEvent | dwh.DimAeOutcome |
| dwh.vFctAdverseEvent | dwh.DimAeSeriousness |
| dwh.vFctAdverseEvent | dwh.DimDate |
| dwh.vFctAdverseEvent | dwh.DimRegion |
| dwh.vFctAdverseEvent | dwh.DimReportSource |
| dwh.vFctAdverseEvent | dwh.DimSrcSystem |
| dwh.vFctAdverseEvent | dwh.RefDoctor |
| dwh.vFctAdverseEvent | dwh.RefProduct |
| dwh.vFctInventoryMovement | dwh.DimDate |
| dwh.vFctInventoryMovement | dwh.DimMovementType |
| dwh.vFctInventoryMovement | dwh.DimSrcSystem |
| dwh.vFctInventoryMovement | dwh.RefEmployee |
| dwh.vFctInventoryMovement | dwh.RefMovementType |
| dwh.vFctInventoryMovement | dwh.RefProduct |
| dwh.vFctInventoryMovement | dwh.RefWarehouse |
| dwh.vFctPrescription | dwh.DimDate |
| dwh.vFctPrescription | dwh.DimSrcSystem |
| dwh.vFctPrescription | dwh.RefDoctor |
| dwh.vFctPrescription | dwh.RefEmployee |
| dwh.vFctPrescription | dwh.RefProduct |
| dwh.vFctSales | dwh.DimCurrency |
| dwh.vFctSales | dwh.DimDate |
| dwh.vFctSales | dwh.DimOrderStatus |
| dwh.vFctSales | dwh.DimSrcSystem |
| dwh.vFctSales | dwh.RefClientAccount |
| dwh.vFctSales | dwh.RefEmployee |
| dwh.vFctSales | dwh.RefProduct |
| dwh.vFctSales | dwh.RefWarehouse |
| dwh.vFctVisit | dwh.DimActivityType |
| dwh.vFctVisit | dwh.DimDate |
| dwh.vFctVisit | dwh.DimSrcSystem |
| dwh.vFctVisit | dwh.RefDoctor |
| dwh.vFctVisit | dwh.RefEmployee |
| dwh.vFctVisit | dwh.RefProduct |
| dwh.vRefClientAccount | dwh.DimClientAccount |
| dwh.vRefClientAccount | dwh.DimSrcSystem |
| dwh.vRefDoctor | dwh.DimDoctor |
| dwh.vRefDoctor | dwh.DimSrcSystem |
| dwh.vRefEmployee | dwh.DimEmployee |
| dwh.vRefEmployee | dwh.DimSrcSystem |
| dwh.vRefMovementType | dwh.DimMovementType |
| dwh.vRefMovementType | dwh.DimSrcSystem |
| dwh.vRefProduct | dwh.DimProduct |
| dwh.vRefProduct | dwh.DimSrcSystem |
| dwh.vRefWarehouse | dwh.DimSrcSystem |
| dwh.vRefWarehouse | dwh.DimWarehouse |

## 2. Залежності від bronze: view -> bronze table (33 ребра)

| Object | DependOnObject |
|---|---|
| dwh.vDimActivityType | lhbronze.erp_erp.DOCTOR_VISITS |
| dwh.vDimAeOutcome | lhbronze.erp_erp.ADVERSE_EVENTS |
| dwh.vDimAeSeriousness | lhbronze.erp_erp.ADVERSE_EVENTS |
| dwh.vDimChain | lhbronze.erp_erp.CUSTOMERS |
| dwh.vDimCity | lhbronze.erp_erp.CUSTOMERS |
| dwh.vDimCity | lhbronze.erp_erp.DOCTORS |
| dwh.vDimCity | lhbronze.erp_erp.WAREHOUSES |
| dwh.vDimClientAccount | lhbronze.erp_erp.CUSTOMERS |
| dwh.vDimDoctor | lhbronze.erp_erp.DOCTORS |
| dwh.vDimEmployee | lhbronze.erp_erp.EMPLOYEES |
| dwh.vDimLegalEntity | lhbronze.erp_erp.CUSTOMERS |
| dwh.vDimLpu | lhbronze.erp_erp.DOCTORS |
| dwh.vDimManufacturer | lhbronze.erp_erp.PRODUCTS |
| dwh.vDimProduct | lhbronze.erp_erp.PRODUCTS |
| dwh.vDimRegion | lhbronze.erp_erp.ADVERSE_EVENTS |
| dwh.vDimRegion | lhbronze.erp_erp.CUSTOMERS |
| dwh.vDimRegion | lhbronze.erp_erp.DOCTORS |
| dwh.vDimRegion | lhbronze.erp_erp.WAREHOUSES |
| dwh.vDimReportSource | lhbronze.erp_erp.ADVERSE_EVENTS |
| dwh.vDimSpecialty | lhbronze.erp_erp.DOCTORS |
| dwh.vDimTerritory | lhbronze.erp_erp.EMPLOYEES |
| dwh.vDimWarehouse | lhbronze.erp_erp.WAREHOUSES |
| dwh.vFctAdverseEvent | lhbronze.erp_erp.ADVERSE_EVENTS |
| dwh.vFctInventoryMovement | lhbronze.erp_erp.INVENTORY_MOVEMENTS |
| dwh.vFctPrescription | lhbronze.erp_erp.PRESCRIPTIONS |
| dwh.vFctSales | lhbronze.erp_erp.SALES_ORDERS |
| dwh.vFctVisit | lhbronze.erp_erp.DOCTOR_VISITS |
| dwh.vRefClientAccount | lhbronze.erp_erp.CUSTOMERS |
| dwh.vRefDoctor | lhbronze.erp_erp.DOCTORS |
| dwh.vRefEmployee | lhbronze.erp_erp.EMPLOYEES |
| dwh.vRefMovementType | lhbronze.erp_erp.INVENTORY_MOVEMENTS |
| dwh.vRefProduct | lhbronze.erp_erp.PRODUCTS |
| dwh.vRefWarehouse | lhbronze.erp_erp.WAREHOUSES |

## 3. Об'єкти без залежностей

Наповнюються напряму міграціями (статичний словник, без джерельного view):
`dwh.DimDate`, `dwh.DimSrcSystem`, `dwh.DimCurrency`, `dwh.DimAtcClass`,
`dwh.DimMovementType`, `dwh.DimOrderStatus`.

## 4. Цикл за задумом

`dwh.vDimEmployee` → `dwh.DimEmployee` — self-reference на керівника
(`SKEmployeeManagerKeyID`). Це єдиний цикл у графі; він розривається двома прогонами
`spUpsertSCDDimension` для `DimEmployee` (див. `spSilverFullLoad`): перший створює рядки,
другий проставляє ключі керівників.

## 5. Процедури

| Object | DependOnObject |
|---|---|
| dwh.spUpsertSCDDimension | dwh.spSchemaValidation |
| dwh.spSilverFullLoad | dwh.spUpsertSCDDimension |
| dwh.spSilverFullLoad | dwh.spFullFct |

## 6. Silver table -> bronze table

### 6.1. Прямі (33 ребра) — bronze, який читає власний view таблиці

| Object | DependOnObject |
|---|---|
| dwh.DimActivityType | lhbronze.erp_erp.DOCTOR_VISITS |
| dwh.DimAeOutcome | lhbronze.erp_erp.ADVERSE_EVENTS |
| dwh.DimAeSeriousness | lhbronze.erp_erp.ADVERSE_EVENTS |
| dwh.DimChain | lhbronze.erp_erp.CUSTOMERS |
| dwh.DimCity | lhbronze.erp_erp.CUSTOMERS |
| dwh.DimCity | lhbronze.erp_erp.DOCTORS |
| dwh.DimCity | lhbronze.erp_erp.WAREHOUSES |
| dwh.DimClientAccount | lhbronze.erp_erp.CUSTOMERS |
| dwh.DimDoctor | lhbronze.erp_erp.DOCTORS |
| dwh.DimEmployee | lhbronze.erp_erp.EMPLOYEES |
| dwh.DimLegalEntity | lhbronze.erp_erp.CUSTOMERS |
| dwh.DimLpu | lhbronze.erp_erp.DOCTORS |
| dwh.DimManufacturer | lhbronze.erp_erp.PRODUCTS |
| dwh.DimProduct | lhbronze.erp_erp.PRODUCTS |
| dwh.DimRegion | lhbronze.erp_erp.ADVERSE_EVENTS |
| dwh.DimRegion | lhbronze.erp_erp.CUSTOMERS |
| dwh.DimRegion | lhbronze.erp_erp.DOCTORS |
| dwh.DimRegion | lhbronze.erp_erp.WAREHOUSES |
| dwh.DimReportSource | lhbronze.erp_erp.ADVERSE_EVENTS |
| dwh.DimSpecialty | lhbronze.erp_erp.DOCTORS |
| dwh.DimTerritory | lhbronze.erp_erp.EMPLOYEES |
| dwh.DimWarehouse | lhbronze.erp_erp.WAREHOUSES |
| dwh.FctAdverseEvent | lhbronze.erp_erp.ADVERSE_EVENTS |
| dwh.FctInventoryMovement | lhbronze.erp_erp.INVENTORY_MOVEMENTS |
| dwh.FctPrescription | lhbronze.erp_erp.PRESCRIPTIONS |
| dwh.FctSales | lhbronze.erp_erp.SALES_ORDERS |
| dwh.FctVisit | lhbronze.erp_erp.DOCTOR_VISITS |
| dwh.RefClientAccount | lhbronze.erp_erp.CUSTOMERS |
| dwh.RefDoctor | lhbronze.erp_erp.DOCTORS |
| dwh.RefEmployee | lhbronze.erp_erp.EMPLOYEES |
| dwh.RefMovementType | lhbronze.erp_erp.INVENTORY_MOVEMENTS |
| dwh.RefProduct | lhbronze.erp_erp.PRODUCTS |
| dwh.RefWarehouse | lhbronze.erp_erp.WAREHOUSES |

### 6.2. Транзитивні (83 ребра) — уся лінія до bronze, включно з залежностями через інші Dim/Ref

Для impact-аналізу: «зміна в bronze-таблиці X зачіпає ось ці silver-таблиці».

| Object | DependOnObject |
|---|---|
| dwh.DimActivityType | lhbronze.erp_erp.DOCTOR_VISITS |
| dwh.DimAeOutcome | lhbronze.erp_erp.ADVERSE_EVENTS |
| dwh.DimAeSeriousness | lhbronze.erp_erp.ADVERSE_EVENTS |
| dwh.DimChain | lhbronze.erp_erp.CUSTOMERS |
| dwh.DimCity | lhbronze.erp_erp.ADVERSE_EVENTS |
| dwh.DimCity | lhbronze.erp_erp.CUSTOMERS |
| dwh.DimCity | lhbronze.erp_erp.DOCTORS |
| dwh.DimCity | lhbronze.erp_erp.WAREHOUSES |
| dwh.DimClientAccount | lhbronze.erp_erp.ADVERSE_EVENTS |
| dwh.DimClientAccount | lhbronze.erp_erp.CUSTOMERS |
| dwh.DimClientAccount | lhbronze.erp_erp.DOCTORS |
| dwh.DimClientAccount | lhbronze.erp_erp.WAREHOUSES |
| dwh.DimDoctor | lhbronze.erp_erp.ADVERSE_EVENTS |
| dwh.DimDoctor | lhbronze.erp_erp.CUSTOMERS |
| dwh.DimDoctor | lhbronze.erp_erp.DOCTORS |
| dwh.DimDoctor | lhbronze.erp_erp.WAREHOUSES |
| dwh.DimEmployee | lhbronze.erp_erp.EMPLOYEES |
| dwh.DimLegalEntity | lhbronze.erp_erp.CUSTOMERS |
| dwh.DimLpu | lhbronze.erp_erp.ADVERSE_EVENTS |
| dwh.DimLpu | lhbronze.erp_erp.CUSTOMERS |
| dwh.DimLpu | lhbronze.erp_erp.DOCTORS |
| dwh.DimLpu | lhbronze.erp_erp.WAREHOUSES |
| dwh.DimManufacturer | lhbronze.erp_erp.PRODUCTS |
| dwh.DimProduct | lhbronze.erp_erp.PRODUCTS |
| dwh.DimRegion | lhbronze.erp_erp.ADVERSE_EVENTS |
| dwh.DimRegion | lhbronze.erp_erp.CUSTOMERS |
| dwh.DimRegion | lhbronze.erp_erp.DOCTORS |
| dwh.DimRegion | lhbronze.erp_erp.WAREHOUSES |
| dwh.DimReportSource | lhbronze.erp_erp.ADVERSE_EVENTS |
| dwh.DimSpecialty | lhbronze.erp_erp.DOCTORS |
| dwh.DimTerritory | lhbronze.erp_erp.EMPLOYEES |
| dwh.DimWarehouse | lhbronze.erp_erp.ADVERSE_EVENTS |
| dwh.DimWarehouse | lhbronze.erp_erp.CUSTOMERS |
| dwh.DimWarehouse | lhbronze.erp_erp.DOCTORS |
| dwh.DimWarehouse | lhbronze.erp_erp.WAREHOUSES |
| dwh.FctAdverseEvent | lhbronze.erp_erp.ADVERSE_EVENTS |
| dwh.FctAdverseEvent | lhbronze.erp_erp.CUSTOMERS |
| dwh.FctAdverseEvent | lhbronze.erp_erp.DOCTORS |
| dwh.FctAdverseEvent | lhbronze.erp_erp.PRODUCTS |
| dwh.FctAdverseEvent | lhbronze.erp_erp.WAREHOUSES |
| dwh.FctInventoryMovement | lhbronze.erp_erp.ADVERSE_EVENTS |
| dwh.FctInventoryMovement | lhbronze.erp_erp.CUSTOMERS |
| dwh.FctInventoryMovement | lhbronze.erp_erp.DOCTORS |
| dwh.FctInventoryMovement | lhbronze.erp_erp.EMPLOYEES |
| dwh.FctInventoryMovement | lhbronze.erp_erp.INVENTORY_MOVEMENTS |
| dwh.FctInventoryMovement | lhbronze.erp_erp.PRODUCTS |
| dwh.FctInventoryMovement | lhbronze.erp_erp.WAREHOUSES |
| dwh.FctPrescription | lhbronze.erp_erp.ADVERSE_EVENTS |
| dwh.FctPrescription | lhbronze.erp_erp.CUSTOMERS |
| dwh.FctPrescription | lhbronze.erp_erp.DOCTORS |
| dwh.FctPrescription | lhbronze.erp_erp.EMPLOYEES |
| dwh.FctPrescription | lhbronze.erp_erp.PRESCRIPTIONS |
| dwh.FctPrescription | lhbronze.erp_erp.PRODUCTS |
| dwh.FctPrescription | lhbronze.erp_erp.WAREHOUSES |
| dwh.FctSales | lhbronze.erp_erp.ADVERSE_EVENTS |
| dwh.FctSales | lhbronze.erp_erp.CUSTOMERS |
| dwh.FctSales | lhbronze.erp_erp.DOCTORS |
| dwh.FctSales | lhbronze.erp_erp.EMPLOYEES |
| dwh.FctSales | lhbronze.erp_erp.PRODUCTS |
| dwh.FctSales | lhbronze.erp_erp.SALES_ORDERS |
| dwh.FctSales | lhbronze.erp_erp.WAREHOUSES |
| dwh.FctVisit | lhbronze.erp_erp.ADVERSE_EVENTS |
| dwh.FctVisit | lhbronze.erp_erp.CUSTOMERS |
| dwh.FctVisit | lhbronze.erp_erp.DOCTORS |
| dwh.FctVisit | lhbronze.erp_erp.DOCTOR_VISITS |
| dwh.FctVisit | lhbronze.erp_erp.EMPLOYEES |
| dwh.FctVisit | lhbronze.erp_erp.PRODUCTS |
| dwh.FctVisit | lhbronze.erp_erp.WAREHOUSES |
| dwh.RefClientAccount | lhbronze.erp_erp.ADVERSE_EVENTS |
| dwh.RefClientAccount | lhbronze.erp_erp.CUSTOMERS |
| dwh.RefClientAccount | lhbronze.erp_erp.DOCTORS |
| dwh.RefClientAccount | lhbronze.erp_erp.WAREHOUSES |
| dwh.RefDoctor | lhbronze.erp_erp.ADVERSE_EVENTS |
| dwh.RefDoctor | lhbronze.erp_erp.CUSTOMERS |
| dwh.RefDoctor | lhbronze.erp_erp.DOCTORS |
| dwh.RefDoctor | lhbronze.erp_erp.WAREHOUSES |
| dwh.RefEmployee | lhbronze.erp_erp.EMPLOYEES |
| dwh.RefMovementType | lhbronze.erp_erp.INVENTORY_MOVEMENTS |
| dwh.RefProduct | lhbronze.erp_erp.PRODUCTS |
| dwh.RefWarehouse | lhbronze.erp_erp.ADVERSE_EVENTS |
| dwh.RefWarehouse | lhbronze.erp_erp.CUSTOMERS |
| dwh.RefWarehouse | lhbronze.erp_erp.DOCTORS |
| dwh.RefWarehouse | lhbronze.erp_erp.WAREHOUSES |

### 6.3. Без bronze-залежностей

`dwh.DimDate`, `dwh.DimSrcSystem`, `dwh.DimCurrency`, `dwh.DimAtcClass`, `dwh.DimMovementType`, `dwh.DimOrderStatus` — наповнюються напряму міграціями.
