-- ClickUp: PHARMA-SILVER-001
-- Ініціалізація silver: рядок -1 ("невідомо") у кожному вимірі/довіднику
-- + статичні (керовані) виміри, які не походять з даних джерела.
GO
--IMPORTANT
USE [whsilverad];
--IMPORTANT
GO

BEGIN TRANSACTION;

BEGIN TRY

/* =========================================================
   -1 РЯДКИ ВИМІРІВ
   ========================================================= */

INSERT INTO [whsilverad].[dwh].[DimSrcSystem] ([SKSrcSystemID],[SKSrcSystemKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[Name])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,-1,'N/A');

INSERT INTO [whsilverad].[dwh].[DimCurrency] ([SKCurrencyID],[SKCurrencyKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[Name],[FullName])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'N/A','N/A','N/A');

INSERT INTO [whsilverad].[dwh].[DimAtcClass] ([SKAtcClassID],[SKAtcClassKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[Name],[Description])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'?','N/A','N/A');  -- Id '?' щоб не конфліктувати з реальним класом 'N'

INSERT INTO [whsilverad].[dwh].[DimMovementType] ([SKMovementTypeID],[SKMovementTypeKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[Name],[Direction],[QtySign])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'N/A','N/A','N/A',0);

INSERT INTO [whsilverad].[dwh].[DimOrderStatus] ([SKOrderStatusID],[SKOrderStatusKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[Name],[IsSale],[IsReturn],[IsCancelled])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'N/A','N/A',0,0,0);

INSERT INTO [whsilverad].[dwh].[DimRegion] ([SKRegionID],[SKRegionKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[Name])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'N/A','N/A');

INSERT INTO [whsilverad].[dwh].[DimCity] ([SKCityID],[SKCityKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[Name],[SKRegionKeyID])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'N/A','N/A',-1);

INSERT INTO [whsilverad].[dwh].[DimTerritory] ([SKTerritoryID],[SKTerritoryKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[Name])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'N/A','N/A');

INSERT INTO [whsilverad].[dwh].[DimChain] ([SKChainID],[SKChainKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[Name])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'N/A','N/A');

INSERT INTO [whsilverad].[dwh].[DimLegalEntity] ([SKLegalEntityID],[SKLegalEntityKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[Name],[EDRPOU],[TaxId])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'N/A','N/A','N/A','N/A');

INSERT INTO [whsilverad].[dwh].[DimManufacturer] ([SKManufacturerID],[SKManufacturerKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[Name])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'N/A','N/A');

INSERT INTO [whsilverad].[dwh].[DimProduct] ([SKProductID],[SKProductKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[Name],[SkuCode],[Barcode],[RegistrationNumber],[INN],[AtcCode],[SKAtcClassKeyID],[ReleaseForm],[Dosage],[SKManufacturerKeyID],[RxOtcType],[BasePriceUAH],[IsActive],[IsAtcCodeValid],[SrcCreatedAt])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'N/A','N/A','N/A','N/A','N/A','N/A','N/A',-1,'N/A','N/A',-1,'N/A',NULL,0,0,NULL);

INSERT INTO [whsilverad].[dwh].[DimClientAccount] ([SKClientAccountID],[SKClientAccountKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[Name],[AccountType],[SKChainKeyID],[SKLegalEntityKeyID],[SKRegionKeyID],[SKCityKeyID],[Address],[IsActive],[SrcDuplicateCnt],[SrcCreatedAt])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'N/A','N/A','N/A',-1,-1,-1,-1,'N/A',0,0,NULL);

INSERT INTO [whsilverad].[dwh].[DimSpecialty] ([SKSpecialtyID],[SKSpecialtyKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[Name])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'N/A','N/A');

INSERT INTO [whsilverad].[dwh].[DimLpu] ([SKLpuID],[SKLpuKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[Name],[SKRegionKeyID],[SKCityKeyID])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'N/A','N/A',-1,-1);

INSERT INTO [whsilverad].[dwh].[DimDoctor] ([SKDoctorID],[SKDoctorKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[Name],[LastName],[FirstName],[MiddleName],[SKSpecialtyKeyID],[SKLpuKeyID],[SKRegionKeyID],[SKCityKeyID],[Segment],[IsTarget],[SrcDuplicateCnt],[SrcCreatedAt])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'N/A','N/A','N/A','N/A','N/A',-1,-1,-1,-1,'N',0,0,NULL);

INSERT INTO [whsilverad].[dwh].[DimEmployee] ([SKEmployeeID],[SKEmployeeKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[Name],[EmployeeRole],[SKTerritoryKeyID],[ProductLine],[SKEmployeeManagerKeyID],[HireDate],[IsActive],[SrcCreatedAt])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'N/A','N/A','N/A',-1,'N/A',-1,NULL,0,NULL);

INSERT INTO [whsilverad].[dwh].[DimWarehouse] ([SKWarehouseID],[SKWarehouseKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[Name],[WarehouseCode],[WarehouseType],[SKClientAccountOwnerKeyID],[SKRegionKeyID],[SKCityKeyID],[SrcCreatedAt])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'N/A','N/A','N/A','N/A',-1,-1,-1,NULL);

INSERT INTO [whsilverad].[dwh].[DimActivityType] ([SKActivityTypeID],[SKActivityTypeKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[Name],[IsRemote],[IsGroupEvent])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'N/A','N/A',0,0);

INSERT INTO [whsilverad].[dwh].[DimAeSeriousness] ([SKAeSeriousnessID],[SKAeSeriousnessKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[Name],[SeverityRank])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'N/A','N/A',0);

INSERT INTO [whsilverad].[dwh].[DimAeOutcome] ([SKAeOutcomeID],[SKAeOutcomeKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[Name],[IsFatal],[IsRecovered])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'N/A','N/A',0,0);

INSERT INTO [whsilverad].[dwh].[DimReportSource] ([SKReportSourceID],[SKReportSourceKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[Name],[IsHcpReported])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'N/A','N/A',0);

/* =========================================================
   -1 РЯДКИ REFERENCE-ТАБЛИЦЬ
   ========================================================= */

INSERT INTO [whsilverad].[dwh].[RefProduct] ([SKRefProductID],[SKRefProductKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[SKSrcSystemKeyID],[RawSkuCode],[RawBrandName],[SKProductKeyID])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'N/A',-1,'N/A','N/A',-1);

INSERT INTO [whsilverad].[dwh].[RefClientAccount] ([SKRefClientAccountID],[SKRefClientAccountKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[SKSrcSystemKeyID],[RawName],[RawEDRPOU],[IsGoldenRecord],[SKClientAccountKeyID])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'N/A',-1,'N/A','N/A',0,-1);

INSERT INTO [whsilverad].[dwh].[RefDoctor] ([SKRefDoctorID],[SKRefDoctorKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[SKSrcSystemKeyID],[RawFullName],[RawLpuName],[IsGoldenRecord],[SKDoctorKeyID])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'N/A',-1,'N/A','N/A',0,-1);

INSERT INTO [whsilverad].[dwh].[RefEmployee] ([SKRefEmployeeID],[SKRefEmployeeKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[SKSrcSystemKeyID],[RawFullName],[SKEmployeeKeyID])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'N/A',-1,'N/A',-1);

INSERT INTO [whsilverad].[dwh].[RefWarehouse] ([SKRefWarehouseID],[SKRefWarehouseKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[SKSrcSystemKeyID],[RawName],[SKWarehouseKeyID])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'N/A',-1,'N/A',-1);

INSERT INTO [whsilverad].[dwh].[RefMovementType] ([SKRefMovementTypeID],[SKRefMovementTypeKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[SKSrcSystemKeyID],[RawMovementType],[SKMovementTypeKeyID])
VALUES (-1,-1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'N/A',-1,'N/A',-1);

/* =========================================================
   СТАТИЧНІ ВИМІРИ (керований словник, не походить з джерела)
   SK*ID = SK*KeyID = стабільне мале ціле, задане вручну.
   ========================================================= */

-- Джерельні системи
INSERT INTO [whsilverad].[dwh].[DimSrcSystem] ([SKSrcSystemID],[SKSrcSystemKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[Name])
VALUES (1,1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,1,'PharmaERP');

-- Валюти
INSERT INTO [whsilverad].[dwh].[DimCurrency] ([SKCurrencyID],[SKCurrencyKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[Name],[FullName])
VALUES
	 (1,1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'UAH','грн','Українська гривня')
	,(2,2,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'USD','usd','Долар США')
	,(3,3,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'EUR','eur','Євро');

-- ATC, рівень 1 (анатомічна група)
INSERT INTO [whsilverad].[dwh].[DimAtcClass] ([SKAtcClassID],[SKAtcClassKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[Name],[Description])
VALUES
	 (1,1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'A','Alimentary tract and metabolism','Травний тракт та метаболізм')
	,(2,2,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'B','Blood and blood forming organs','Кров та система кровотворення')
	,(3,3,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'C','Cardiovascular system','Серцево-судинна система')
	,(4,4,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'D','Dermatologicals','Дерматологічні засоби')
	,(5,5,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'G','Genito-urinary system and sex hormones','Сечостатева система та статеві гормони')
	,(6,6,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'H','Systemic hormonal preparations','Гормональні препарати системної дії')
	,(7,7,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'J','Antiinfectives for systemic use','Протимікробні засоби системної дії')
	,(8,8,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'L','Antineoplastic and immunomodulating agents','Протипухлинні та імуномодулюючі засоби')
	,(9,9,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'M','Musculo-skeletal system','Опорно-руховий апарат')
	,(10,10,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'N','Nervous system','Нервова система')
	,(11,11,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'P','Antiparasitic products','Протипаразитарні засоби')
	,(12,12,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'R','Respiratory system','Дихальна система')
	,(13,13,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'S','Sensory organs','Органи чуття')
	,(14,14,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'V','Various','Інші засоби');

-- Типи складських рухів (канонічні); сирі значення джерела мапляться через RefMovementType
INSERT INTO [whsilverad].[dwh].[DimMovementType] ([SKMovementTypeID],[SKMovementTypeKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[Name],[Direction],[QtySign])
VALUES
	 (1,1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'IN','Прихід','IN',1)
	,(2,2,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'OUT','Видача','OUT',-1)
	,(3,3,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'TRANSFER','Переміщення','TRANSFER',0)
	,(4,4,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'WRITEOFF','Списання','OUT',-1);

-- Статуси замовлень
INSERT INTO [whsilverad].[dwh].[DimOrderStatus] ([SKOrderStatusID],[SKOrderStatusKeyID],[StartDate],[EndDate],[IsDeleted],[CreatedBy],[ModifiedBy],[CreatedAt],[ModifiedAt],[Id],[Name],[IsSale],[IsReturn],[IsCancelled])
VALUES
	 (1,1,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'NEW','Нове',0,0,0)
	,(2,2,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'CONFIRMED','Підтверджене',0,0,0)
	,(3,3,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'SHIPPED','Відвантажене',1,0,0)
	,(4,4,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'DELIVERED','Доставлене',1,0,0)
	,(5,5,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'CANCELLED','Скасоване',0,0,1)
	,(6,6,'2000-01-01',NULL,0,'init_insert',NULL,'2000-01-01',NULL,'RETURN','Повернення',0,1,0);

COMMIT TRANSACTION;

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
