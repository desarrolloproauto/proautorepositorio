USE [DWH_Repuestos]
GO

alter proc [dbo].[Corp_Proauto_FactInventarioRepuesto_Borrador] 
as

BEGIN
	declare @fecha date
	select @fecha = fecha from DimTiempo where MesVigente = 1 and DiaVigente = 1
	set @fecha = '2022-02-28'
	print @fecha

	DELETE FROM [DWH_Repuestos].[dbo].[FactCorpInventarioRepuestos]
	WHERE CodigoEmpresa = 1
	and year(Fecha) =	year(@fecha)
	and month(Fecha) = month(@fecha)

	INSERT INTO [DWH_Repuestos].[dbo].[FactCorpInventarioRepuestos]
	SELECT [Fecha]
           ,CONCAT('1', [id_cot_bodega]) AS CodigoBodegaProducto
           ,CONCAT('1', [CodigoItem]) AS CodigoProducto
	       ,([Costo Stock Disponible] + [Costo Reserva]) AS Valor
           ,[ultima_compra] AS [FechaUltimaCompra]
           ,[Costo Unidad Promedio Empresa] AS [CostoPromedio]
	       ,[Stocktotal] AS Stock
	       ,CASE WHEN [Edad Inventario] IS NULL THEN 'N'	ELSE 'S' END AS [EsObsoleto]
	       ,1 AS [CodigoEmpresa]
	       ,m.Marca
	       ,id_marca
    FROM [DWH_Repuestos].[dbo].[FactInventarioRepuestos] i
    left join DWH_Repuestos.dbo.DimMarca m on m.Id = i.id_marca
	WHERE year(Fecha) =	year(@fecha)
    and month(Fecha) = month(@fecha)
END

