USE [dms_smd3]
GO
/****** Object:  StoredProcedure [dbo].[Get_BI_R_FactInventarioRepuestos]    Script Date: 10/3/2022 18:19:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =================================================================================================================================
-- Author:		<Javier Chogllo>
-- Create date: <2021-02-12>
-- Modulo:		<BI>
-- Description:	<Procedimiento para obtener el Inventario de Repuestos (REPUESTOS - ACCESORIOS - DISPOSITIVOS - KIT MANDATORIO).
--				 Ejecuta el SP [Get_BI_R_FactInventarioRepuestos] el cual esta basado en el reporte 100002 (GetCotItemStockFecha_ecuadorv2)			 			
-- Historial de Cambios:
-- 2021-08-19    Se agrega el campo AccesoriosReserva el cual Indica los accesorios que se son obligatorios en el Vehiculos, con este campo
--               se obtiene el Inventario de Accesorios Obligatorios en Vehiculos (JCB) 
-- 2021-08-26    Se elimina el campo Subgrupo3 y se agrega el campo [id_subgrupo_rep] por el tema de Dimesionamiento. (JCB)	
-- 2022-03-10    Se agregan los campos Cant_OT y Costo_OT. (JCB)	
-- =================================================================================================================================

-- EXEC [dbo].[Get_BI_R_FactInventarioRepuestos]
ALTER PROCEDURE [dbo].[Get_BI_R_FactInventarioRepuestos]
as
    
	-------------------------------------------------------
	DECLARE @fecActual DATE = CAST(GETDATE() AS DATE)
	-------------------------------------------------------

	DECLARE @fecha DATETIME = EOMONTH(@fecActual)
	DECLARE @emp INT = 605

	DECLARE @Get_BI_R_FactInventarioRepuestos AS TABLE
	(
		[Agencia] [varchar](4) ,
		[Bodega] [varchar](200) ,
		[id_cot_bodega] int,
		[id_cot_item] int,
		[codigo] [varchar](30) ,
		[Producto] [nvarchar](50) ,
		[NombreProducto] [varchar](200) ,
		[Aplicacion] [varchar](max) ,
		[Año] [int] ,
		[color] [nvarchar](30) ,
		[color_interno] [nvarchar](30) ,
		[ubicacionvehiculo] [varchar](80) ,
		[Grupo] [nvarchar](50) ,
		[Categoria] [nvarchar](50) ,
		[Linea] [nvarchar](50) ,
		[ubicacion] [varchar](20) ,
		[Stock Disponible] [decimal](38, 8) ,
		[CanOt] [decimal](38, 8) ,
		[Reservas] [decimal](19, 4) ,
		[AccesoriosReserva] [int] ,
		[Stocktotal] [decimal](38, 8) ,
		[Fecha_Creacion] [date] ,
		[Costo Unidad Promedio Empresa] [decimal](18, 2) ,
		[Costo Stock Disponible] [decimal](38, 6) ,
		[Costo  OT] [decimal](38, 6) ,
		[Costo  Reserva] [decimal](38, 6) ,
		[Costo Total Promedio Empresa] [decimal](38, 6) ,
		[PrecioSinIva] [money] ,
		[VhPagado] [varchar](20) ,
		[UltimaCompra] [datetime] ,
		[Ultimaventa] [datetime] ,
		[UltimaDevVenta] [datetime] ,
		[DiasInventario] [int] ,
		[VhTieneAccesorios] [varchar](1) ,
		[VhReservado] [varchar](1) ,
		[VhNombreRervado] [nvarchar](358) ,
		[hoja_negocio] [int] ,
		[RAMV] [varchar](20) ,
		[Nuevo_usado] [varchar](5) ,
		[Motor] [varchar](50) ,
		[Tipo] [varchar](200) ,
		[Segmento] [varchar](50) ,
		[Familia] [varchar](50) ,
		[subgrupo3] [varchar](50) ,
		[subgrupo4] [varchar](50) ,
		[subgrupo5] [varchar](50) ,
		[Explicacion_adicional] [varchar](150) ,
		[Original-alterno] [varchar](200) ,
		[Fuente (cor)*] [varchar](200) ,
		[Obsolescencia bodega] [varchar](2) ,
		[Obsolescencia General] [varchar](2) ,
		[Edad Inventario] [varchar](25) ,
		[Categoria_Precio] [varchar](100) ,
		[Proveedor] [nvarchar](100),
		[IdEmp] int
	)
	INSERT @Get_BI_R_FactInventarioRepuestos
	EXEC [dbo].[BI_R_GetCotItemStockFecha_ecuadorv2] @fecha


	
	select  Fecha = @fecha,  --Obtiene el ultimo dia del mes actual
		    CodigoTiempo = CONVERT(VARCHAR(8),@fecha,112),
		    r.id_cot_bodega,
		    r.id_cot_item,
		    r.Codigo,
		    Modelo = r.NombreProducto,
		    r.Grupo,
			id_linea_negocio = CASE
								WHEN r.Grupo LIKE '%REPUESTOS%' THEN '2.1'
								WHEN r.Grupo LIKE '%ACCESORIOS%' THEN '2.2'
								WHEN r.Grupo LIKE '%DISPOSITIVOS%' THEN '2.3'
								WHEN r.Grupo LIKE '%KIT%MANDATO%' THEN '2.4'
								ELSE '0'
						  END,
		    id_marca = 
				   CASE 
						WHEN r.Categoria LIKE '%CHEVRO%' THEN 1
						WHEN r.Categoria LIKE '%GAC%' THEN 2
						WHEN r.Categoria LIKE '%VOLKSWAG%' OR r.Categoria LIKE '%VW%' THEN 3
						WHEN r.Categoria LIKE '%MULTI%' THEN 9
						ELSE 0 --Sin asignar
					END,
			   id_linea_vehiculo =  CASE
						WHEN r.Linea LIKE '%LIVIAN%' THEN 1
						WHEN r.Linea LIKE '%PESADO%' THEN 2
						ELSE 1
						END,
		       r.[Stock Disponible],
		       r.Reservas,	
		       r.AccesoriosReserva, --GMAH 749
		       r.Stocktotal,
		       r.Fecha_Creacion,
		       r.[Costo Unidad Promedio Empresa],
		       r.[Costo Stock Disponible],
		       r.[Costo  Reserva],
		       r.[Costo Total Promedio Empresa],
		       r.PrecioSinIva,
		       r.UltimaCompra,
		       r.Ultimaventa,
		       r.UltimaDevVenta,
		       r.DiasInventario,
			   id_subgrupo = CASE	
							WHEN r.SUBGRUPO3 like '%Aros%' then 1
							WHEN r.SUBGRUPO3 like '%Audio%' then 2
							WHEN r.SUBGRUPO3 like '%Chevystar%' then 3
							WHEN r.SUBGRUPO3 like '%Climatizaci%' then 4
							WHEN r.SUBGRUPO3 like '%Colisi%' then 5
							WHEN r.SUBGRUPO3 like '%Desgaste%' then 6
							WHEN r.SUBGRUPO3 like '%Exteriores%' then 7
							WHEN r.SUBGRUPO3 like '%Iluminaci%' then 8
							WHEN r.SUBGRUPO3 like '%Insumos%' then 9
							WHEN r.SUBGRUPO3 like '%Interiores%' then 10
							WHEN r.SUBGRUPO3 like '%Llantas%' then 11
							WHEN r.SUBGRUPO3 like '%Lubricantes%' then 12
							WHEN r.SUBGRUPO3 like '%Mant%Prepagado%' then 13
							WHEN r.SUBGRUPO3 like '%Mantenimiento%' then 14
							WHEN r.SUBGRUPO3 like '%Miscel%' then 15
							WHEN r.SUBGRUPO3 like '%Seguridad%' then 16
							WHEN r.SUBGRUPO3 like '%Suspensi%' then 17
							WHEN r.SUBGRUPO3 like '%Tapicer%' then 18
							WHEN r.SUBGRUPO3 like '%Car%Care%' then 19
							WHEN r.SUBGRUPO3 like '%Frenos%' then 20 
							WHEN r.SUBGRUPO3 like '%Mant%programado%' then 21 
							WHEN r.SUBGRUPO3 like '%Neum%ticos%' then 22 
							WHEN r.SUBGRUPO3 like '%Sistema%direcci%' then 23 
							WHEN r.SUBGRUPO3 like '%Sistema%ctrico%' then 24 
							WHEN r.SUBGRUPO3 like '%Tren%motr%' then 25 
							else 0
						END,
			   r.subgrupo4,
			   r.[Original-alterno],
	           r.[Fuente (cor)*],
			   r.[Explicacion_adicional],
	           r.[Obsolescencia General],
			   r.[Edad Inventario],
			   case
					when r.IdEmp = 605 then 1
					when r.IdEmp = 601 then 4
			   end IdEmpresa,
			   r.CanOt,
			   r.[Costo  OT]
from @Get_BI_R_FactInventarioRepuestos r
where r.Grupo IN ('REPUESTOS','ACCESORIOS','DISPOSITIVOS','KIT MANDATORIO')
