# Silver — залежності між об'єктами

Згенеровано з міграцій `V260819.1000` (таблиці) та `V260819.1020` (view).
Читається як «**Object** не можна створити/завантажити, поки не готовий **DependOnObject**».

Два типи ребер:

* `dwh.<Table>` → `dwh.v<Table>` — таблиця наповнюється зі свого джерельного view
  (`spUpsertSCDDimension` для `Dim*`/`Ref*`, `spFullFct` для `Fct*`);
* `dwh.v<Object>` → `dwh.<Object>` — view читає вже завантажений silver-об'єкт
  (резолв durable keys).

## 1. Залежності всередині silver (92 ребер)

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

## 2. Залежності від bronze (33 ребер)

| Object | DependOnObject |
|---|---|
| dwh.vDimActivityType | lhbronzead.pharma_erp.DOCTOR_VISITS |
| dwh.vDimAeOutcome | lhbronzead.pharma_erp.ADVERSE_EVENTS |
| dwh.vDimAeSeriousness | lhbronzead.pharma_erp.ADVERSE_EVENTS |
| dwh.vDimChain | lhbronzead.pharma_erp.CUSTOMERS |
| dwh.vDimCity | lhbronzead.pharma_erp.CUSTOMERS |
| dwh.vDimCity | lhbronzead.pharma_erp.DOCTORS |
| dwh.vDimCity | lhbronzead.pharma_erp.WAREHOUSES |
| dwh.vDimClientAccount | lhbronzead.pharma_erp.CUSTOMERS |
| dwh.vDimDoctor | lhbronzead.pharma_erp.DOCTORS |
| dwh.vDimEmployee | lhbronzead.pharma_erp.EMPLOYEES |
| dwh.vDimLegalEntity | lhbronzead.pharma_erp.CUSTOMERS |
| dwh.vDimLpu | lhbronzead.pharma_erp.DOCTORS |
| dwh.vDimManufacturer | lhbronzead.pharma_erp.PRODUCTS |
| dwh.vDimProduct | lhbronzead.pharma_erp.PRODUCTS |
| dwh.vDimRegion | lhbronzead.pharma_erp.ADVERSE_EVENTS |
| dwh.vDimRegion | lhbronzead.pharma_erp.CUSTOMERS |
| dwh.vDimRegion | lhbronzead.pharma_erp.DOCTORS |
| dwh.vDimRegion | lhbronzead.pharma_erp.WAREHOUSES |
| dwh.vDimReportSource | lhbronzead.pharma_erp.ADVERSE_EVENTS |
| dwh.vDimSpecialty | lhbronzead.pharma_erp.DOCTORS |
| dwh.vDimTerritory | lhbronzead.pharma_erp.EMPLOYEES |
| dwh.vDimWarehouse | lhbronzead.pharma_erp.WAREHOUSES |
| dwh.vFctAdverseEvent | lhbronzead.pharma_erp.ADVERSE_EVENTS |
| dwh.vFctInventoryMovement | lhbronzead.pharma_erp.INVENTORY_MOVEMENTS |
| dwh.vFctPrescription | lhbronzead.pharma_erp.PRESCRIPTIONS |
| dwh.vFctSales | lhbronzead.pharma_erp.SALES_ORDERS |
| dwh.vFctVisit | lhbronzead.pharma_erp.DOCTOR_VISITS |
| dwh.vRefClientAccount | lhbronzead.pharma_erp.CUSTOMERS |
| dwh.vRefDoctor | lhbronzead.pharma_erp.DOCTORS |
| dwh.vRefEmployee | lhbronzead.pharma_erp.EMPLOYEES |
| dwh.vRefMovementType | lhbronzead.pharma_erp.INVENTORY_MOVEMENTS |
| dwh.vRefProduct | lhbronzead.pharma_erp.PRODUCTS |
| dwh.vRefWarehouse | lhbronzead.pharma_erp.WAREHOUSES |

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
