USE [DWH_Repuestos]
GO

-- ========================================================================================================
-- Author:		<>
-- Historial de Cambios:
-- 2021-08-31	Se agrega el campo Subcanal para diferenciar entre Mecánica y Latonería (JCB)
-- ========================================================================================================

alter PROCEDURE [dbo].[Corp_Proauto_FactVentaRepuesto]
AS
BEGIN

declare @fecha date

select @fecha=fecha from DimTiempo where MesVigente=1 and DiaVigente=1

DELETE FROM [DWH_Repuestos].[dbo].[FactCorpVentaRepuesto]
WHERE CodigoEmpresa = 1
and year(Fecha) =	year(@fecha)
and month(Fecha) = month(@fecha)

--ELIMINAR TABLAS TEMPORALES
IF OBJECT_ID(N'tempdb.dbo.#Repuestos',N'U') IS NOT NULL
DROP TABLE #Repuestos



SELECT       
      [FECHA] AS [Fecha]
	  ,NULL AS [TipoDocumento]
	  ,[NUMERO_DOCUMENTO] AS [NumeroDocumento]
	  ,CONCAT('1', id_cot_bodega) AS [CodigoBodega]
	  ,CONCAT('1', [CODIGO]) AS [CodigoProducto]
      ,NIT_VENDEDOR AS [CodigoAsesor]
	  ,[NIT_CLIENTE] AS [CodigoCliente]
      ,[PRECIO_NETO] AS [ValorVenta]
	  ,[COSTO_TOTAL] AS [ValorCostoVenta]
	  ,CASE 
			WHEN r.id_canal_venta IN ('2.2.1', '2.3.1') THEN 'VEHICULOS'
			WHEN r.id_canal_venta IN ('2.1.4', '2.2.4', '2.2.3', '2.3.2', '2.1.3') THEN 'TALLER'
			WHEN r.id_canal_venta IN ('2.1.1', '2.1.2', '2.2.2') THEN 'MOSTRADOR'
			WHEN r.id_linea_negocio = ('2.1') THEN 'TALLER'
			WHEN r.id_linea_negocio IN ('2.2', '2.3') THEN 'VEHICULOS'
			ELSE NULL
	   END AS [Canal]
	  ,[Subcanal] = v.canal_venta
      ,1 AS [CodigoEmpresa]
	  ,dp.marca
	  ,r.MarcaVH_original
INTO #Repuestos
FROM [DWH_Repuestos].[dbo].[FactVentaRepuestos] r
join DWH_Repuestos..DimLineaNegocio ln on ln.id_linea_negocio = r.id_linea_negocio
join DWH_Repuestos..DimCanalVenta v on v.id_canal_venta = r.id_canal_venta
left join DimCorpProducto dp on dp.CodigoProducto = concat(1,R.CODIGO)
WHERE CodigoEmpresa = 1
and year(Fecha) =	year(@fecha)
and month(Fecha) = month(@fecha)


INSERT INTO [DWH_Repuestos].[dbo].[FactCorpVentaRepuesto]
SELECT *
FROM #Repuestos

END