-- whsilver.dwh.FctInventoryMovement
DROP TABLE IF EXISTS [dwh].[FctInventoryMovement]
GO
CREATE TABLE [dwh].[FctInventoryMovement]
(
	[SKFctInventoryMovementID] [bigint] NULL,
	[CreatedBy] [varchar](100) NOT NULL,
	[CreatedAt] [datetime2](3) NULL,
	[SKSrcSystemKeyID] [bigint] NOT NULL,
	[DocumentNumber] [varchar](50) NULL,           -- reference_document
	[ItemId] [varchar](30) NOT NULL,               -- movement_id
	[Period] [datetime2](3) NULL,                  -- movement_date
	[SKDateID] [int] NOT NULL,
	[SKRefWarehouseKeyID] [bigint] NOT NULL,
	[SKRefProductKeyID] [bigint] NOT NULL,
	[SKRefEmployeeKeyID] [bigint] NOT NULL,
	[SKRefMovementTypeKeyID] [bigint] NOT NULL,
	[Qty] [decimal](18,3) NULL,                    -- сира кількість джерела
	[QtySigned] [decimal](18,3) NULL,              -- Qty * DimMovementType.QtySign
	[IsQtyOutlier] [bit] NOT NULL,                 -- |Qty| > 100 000
	[IsSrcDuplicate] [bit] NOT NULL,
	[SrcModifiedAt] [datetime2](3) NULL
)
GO
