USE [MEPA_Reportes]
GO
/****** Object:  StoredProcedure [dbo].[Get_RS_T_NumeroVINsTaller_GM]    Script Date: 8/4/2022 23:39:14 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =========================================================================================================
-- Author:		<Javier Chogllo>
-- Create date: <2021-11-04>
-- Description:	<Compara el numero de unidades de las tablas FactVentaTaller y FactVentaResumido>
-- Historial:
--			    <2022-04-09> Se agrega información de Zona2 JCB
-- =========================================================================================================
-- EXEC [dbo].[Get_RS_T_NumeroVINsTaller_GM] 'Zona 1'
alter PROCEDURE [dbo].[Get_RS_T_NumeroVINsTaller_GM]  
(
	@zona VARCHAR (10)
)
AS
BEGIN
	
	SET NOCOUNT ON;
	declare @nro_ordenes int
	DECLARE @devoluciones int

	DECLARE @fecActual	DATE 
	select @fecActual = fecha from DWH_Repuestos..DimTiempo where diaVigente = 1

	-- FactVentaResumidoTaller
	select r.Id_Factura_NC_ND,
	       r.id_tipo_transaccion,
	       r.NRO_ORDEN,
		   z.zona,
		   r.id_marca_vehiculo,
		   r.id_tipo_orden,
		   r.id_linea_vehiculo,
		   r.DEVOLUCION,
		   r.FAC_ORIGINAL
	into #ingresos
	from [DWH_Talleres]..FactVentaResumidoTaller r
	JOIN [DWH_Talleres]..DimBodega b on r.id_cot_bodega = b.Id
	JOIN [DWH_Talleres]..[DimZona] z ON b.id_zona = z.id_zona
	where year(r.FECHA_FACTURA) = year(@fecActual) AND month(r.FECHA_FACTURA) =  month(@fecActual)
	and id_tipo_transaccion = 1
	and z.zona = @zona
	and NRO_ORDEN <> 0

	select r.Id_Factura_NC_ND,
	       r.id_tipo_transaccion,
	       r.NRO_ORDEN,
		   z.zona,
		   r.id_marca_vehiculo,
		   r.id_tipo_orden,
		   r.id_linea_vehiculo,
		   r.DEVOLUCION,
		   r.FAC_ORIGINAL
	into #devoluciones
	from [DWH_Talleres]..FactVentaResumidoTaller r
	left JOIN [DWH_Talleres]..DimBodega b on r.id_cot_bodega = b.Id
	left JOIN [DWH_Talleres]..[DimZona] z ON b.id_zona = z.id_zona
	where year(r.FECHA_FACTURA) = year(@fecActual) AND month(r.FECHA_FACTURA) =  month(@fecActual)
	and id_tipo_transaccion = -1
	and z.zona = @zona
	and NRO_ORDEN <> 0


	-- Resultado
	select *
	into #resultado
	from #ingresos
	union all
	select *
	from #devoluciones
	order by NRO_ORDEN

	-------------------------------------------------------------------------------------------------------------------------------------------------------
	-------- Las devoluciones se deben considerar (restar Numero Unidades Taller) solo cuando son a facturas realizadas en meses anteriores ---------------
	-------------------------------------------------------------------------------------------------------------------------------------------------------
	select DISTINCT 
	       SW=r.id_tipo_transaccion,
		   r.NRO_ORDEN,
		   --r.Id_Factura_NC_ND,
		   ZONA = UPPER (r.zona),
		   MARCA_VH = ISNULL (UPPER (m.marca), ''),
		   TIPO_ORDEN = ISNULL (UPPER (t.tipo_orden), ''),
		   LINEA_VH = ISNULL (l.linea_vehiculo, '')
	into #resultado_final
	from #resultado r
	left JOIN [DWH_Talleres].[dbo].[DimMarca] m ON r.id_marca_vehiculo = m.id_marca
	left JOIN [DWH_Talleres].[dbo].[DimLineaVehiculo] l ON r.id_linea_vehiculo = l.id_linea_vehiculo
	LEFT JOIN [DWH_Talleres].[dbo].[DimTipoOrden] t ON r.id_tipo_orden = t.id_tipo_orden
	where (r.id_tipo_transaccion = 1 and r.DEVOLUCION = 'No')
	OR (r.id_tipo_transaccion = -1 and r.FAC_ORIGINAL not in (select distinct dev.Id_Factura_NC_ND from #resultado dev where dev.id_tipo_transaccion = 1))
	
	-- Resultado Final
	SELECT x.ZONA,
	       x.MARCA_VH,
		   x.TIPO_ORDEN,
		   x.LINEA_VH,
		   x.num_unidades
	FROM
	(
		select f.ZONA,
			   f.MARCA_VH,
			   f.TIPO_ORDEN,
			   f.LINEA_VH,
			   num_unidades = sum(SW)
		from #resultado_final f
		group by f.ZONA,f.MARCA_VH,f.TIPO_ORDEN,f.LINEA_VH
	
		UNION ALL
		--Agregado para Zona2----------------------------------------------
		select ZONA = 'ZONA 2',
			   MARCA_VH = r2.Marca,
			   TIPO_ORDEN = r2.Orden,
			   LINEA_VH = r2.Tipo,
			   num_unidades = sum(r2.Valor)
		from DWH_Repuestos..v_FactVentaResumidoTaller_Zona2_OT r2
		where r2.Anio =  year(@fecActual) AND r2.Mes =  month(@fecActual)
		group by r2.Marca,r2.Orden,r2.Tipo
		-------------------------------------------------------------------
	)x
	where x.ZONA = @zona
	and x.num_unidades > 0
	

	-- eliminar temporales
	drop table #resultado_final
	drop table #ingresos
	drop table #devoluciones
	drop table #resultado

END