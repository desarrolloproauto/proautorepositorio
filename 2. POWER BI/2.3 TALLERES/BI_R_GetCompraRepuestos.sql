USE [dms_smd3]
GO
/****** Object:  StoredProcedure [dbo].[BI_R_GetCompraRepuestos]    Script Date: 21/1/2022 17:14:59 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--EXEC [dbo].[Get_BI_R_FactCompraRepuestos]
ALTER PROCEDURE [dbo].[BI_R_GetCompraRepuestos]
(
	@fec_actual date
)
AS

DECLARE @Sub3 int = 0	
DECLARE @Sub4 int = 0	
DECLARE @Sub5 int = 0
--@Usuario INT	 = 0 --Usuario para control de permiso 160 para ver costos y utilidad  

--Empresas
declare @emp int = 605
--Fechas
--declare @fec_actual date
declare @fec_ini date
declare @fec_fin date
DECLARE @Ano INT
DECLARE @Mes INT

---------------------------------------------------------------------
set @fec_actual = cast(getdate() as date)
--set @fec_actual = cast(DATEADD(MONTH,-1,getdate())as date)
---------------------------------------------------------------------

--set @fec_ini = DATEADD(DAY,1,EOMONTH(DATEADD(MONTH,-1,@fec_actual)))
--SET @fec_fin = EOMONTH(@fec_actual)
SET @Ano = YEAR(@fec_actual)
SET @Mes = MONTH(@fec_actual)
PRINT  @fec_actual 


declare @BI_GetcomprasOperativo_MEP AS TABLE
(
	[id_cot_bodega] int,
	[id_cot_cliente] int,
	[id_emp] int,
	[Bodega] [varchar](50) NOT NULL,
	[Razon] [nvarchar](100) NOT NULL,
	[Fecha] [datetime] NOT NULL,
	[Tipo] [nvarchar](50) NOT NULL,
	[Numero cotizacion] [int] NOT NULL,
	[Id documento] [int] NOT NULL,
	[Grupo] [nvarchar](50) NOT NULL,
	[Subgrupo] [nvarchar](50) NOT NULL,
	[Subgrupo3] [varchar](50) NULL,
	[Subgrupo4] [varchar](50) NULL,
	[Subgrupo5] [varchar](50) NULL,
	[Linea] [nvarchar](50) NOT NULL,
	[Original-alterno] [varchar](200) NULL,
	[Fuente (cor)*] [varchar](200) NULL,
	[Codigo] [varchar](30) NULL,
	[VIN] [nvarchar](50) NULL,
	[Descripcion] [varchar](500) NULL,
	[Cantidad] [decimal](38, 8) NULL,
	[Costo] [money] NULL,
	[Costo Total] [decimal](38, 6) NULL,
	[Notas] [text] NOT NULL,
	[Factura Proveedor] [varchar](9) NULL,
	[total_iva] [money] NULL,
	[total_iva_det] [decimal](38, 6) NULL,
	[ret1] [money] NULL,
	[ret2] [money] NULL,
	[ret3] [money] NULL,
	[ret4] [money] NULL,
	[ret5] [money] NULL,
	[ret6] [money] NULL,
	[id_cot_item] [int] NOT NULL,
	[id_cot_item_lote] [int] NULL,
	[id] [int] NOT NULL,
	[id_cot_tipo] [int] NOT NULL,
	[Estado Compra VH] [varchar](2) NULL
)
INSERT @BI_GetcomprasOperativo_MEP
EXEC [dbo].[BI_R_GetcomprasOperativo_MEP] @Ano,@Mes


---------------------------------------------------------------------------------
---------------------------RESULTADO---------------------------------------------
---------------------------------------------------------------------------------

select
	 a.id_cot_bodega
	--,a.Bodega
	,a.Razon
	,a.[Fecha]
	,a.Tipo

	,a.[Numero cotizacion]
	,a.[Id documento]
	,id_linea_negocio = CASE
					WHEN a.Grupo LIKE '%REPUESTOS%' THEN '2.1'
					WHEN a.Grupo LIKE '%ACCESORIOS%' THEN '2.2'
					WHEN a.Grupo LIKE '%DISPOSITIVOS%' THEN '2.3'
					ELSE '0'
				END
	--,a.[Grupo]
	,id_marca = CASE 
			WHEN a.[Subgrupo] LIKE '%CHEVRO%' THEN 1
			WHEN a.[Subgrupo] LIKE '%GAC%' THEN 2
			WHEN a.[Subgrupo] LIKE '%VOLKSWAG%' THEN 3
			WHEN a.[Subgrupo] LIKE '%VW%' THEN 3
			WHEN a.[Subgrupo] LIKE '%MULTI%' THEN 9
			else 0
		END,
	--,a.[Subgrupo]
	--,a.[Subgrupo3]
	--,Subgrupo3 = ISNULL(a.[Subgrupo3],'Sin asignar')
	id_subgrupo = CASE	
							WHEN a.SUBGRUPO3 like '%Aros%' then 1
							WHEN a.SUBGRUPO3 like '%Audio%' then 2
							WHEN a.SUBGRUPO3 like '%Chevystar%' then 3
							WHEN a.SUBGRUPO3 like '%Climatizaci%' then 4
							WHEN a.SUBGRUPO3 like '%Colisi%' then 5
							WHEN a.SUBGRUPO3 like '%Desgaste%' then 6
							WHEN a.SUBGRUPO3 like '%Exteriores%' then 7
							WHEN a.SUBGRUPO3 like '%Iluminaci%' then 8
							WHEN a.SUBGRUPO3 like '%Insumos%' then 9
							WHEN a.SUBGRUPO3 like '%Interiores%' then 10
							WHEN a.SUBGRUPO3 like '%Llantas%' then 11
							WHEN a.SUBGRUPO3 like '%Lubricantes%' then 12
							WHEN a.SUBGRUPO3 like '%Mant%Prepagado%' then 13
							WHEN a.SUBGRUPO3 like '%Mantenimiento%' then 14
							WHEN a.SUBGRUPO3 like '%Miscel%' then 15
							WHEN a.SUBGRUPO3 like '%Seguridad%' then 16
							WHEN a.SUBGRUPO3 like '%Suspensi%' then 17
							WHEN a.SUBGRUPO3 like '%Tapicer%' then 18
							WHEN a.SUBGRUPO3 like '%Car%Care%' then 19 
							WHEN a.SUBGRUPO3 like '%Frenos%' then 20 
							WHEN a.SUBGRUPO3 like '%Mant%programado%' then 21 
							WHEN a.SUBGRUPO3 like '%Neum%ticos%' then 22 
							WHEN a.SUBGRUPO3 like '%Sistema%direcci%' then 23 
							WHEN a.SUBGRUPO3 like '%Sistema%ctrico%' then 24 
							WHEN a.SUBGRUPO3 like '%Tren%motr%' then 25 
							else 0
						END,
	 Subgrupo4 = ISNULL(a.[Subgrupo4],'Sin asignar')
	,id_linea_repuesto =  CASE
			WHEN a.[Linea] LIKE '%LIVIAN%' THEN 1
			WHEN a.[Linea] LIKE '%PESADO%' THEN 2
			ELSE 1
			END
	--,a.[Linea]
	,a.[Original-alterno]
	,a.[Fuente (cor)*]
	,a.[Codigo]

	,a.[Descripcion]
	,a.[Cantidad]
	,a.[Costo]
	,a.[Costo Total]
	,a.[Factura Proveedor]

	,a.[total_iva]
	,a.[ret1]
	,a.[ret2]
	,a.[id_cot_item]
	,a.[id_cot_tipo]
	--,a.CanalComercial,
	
	,CanalComercial =
					case 
						when  cotcp.descripcion in ('CONCESIONARIO') then 'Compras Dealers'
						when  cotcp.descripcion in ('MARCA / IMPORTADORA') then 'Compras'
						when  a.Razon like '%impofactor%' or a.Razon like '%impoventu%' then 'Compras'
						ELSE  'Compras Otros'
					end,
	 IdEmpresa = IIF(a.id_emp=605,1,4)

 
from @BI_GetcomprasOperativo_MEP a
LEFT JOIN dbo.cot_cliente cli with(nolock) ON cli.id = a.id_cot_cliente
LEFT JOIN dbo.cot_cliente_perfil cotcp with(nolock) ON cotcp.id = cli.id_cot_cliente_perfil
WHERE a.Grupo LIKE '%REPUESTOS%' OR a.Grupo LIKE '%ACCESORIOS%' OR a.Grupo LIKE '%DISPOSITIVOS%'

--SELECT * FROM @Resultado
