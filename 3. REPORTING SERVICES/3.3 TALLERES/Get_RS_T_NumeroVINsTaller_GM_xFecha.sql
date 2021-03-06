USE [MEPA_Reportes]
GO
/****** Object:  StoredProcedure [dbo].[Get_RS_T_NumeroVINsTaller_GM_xFecha]    Script Date: 11/4/2022 10:22:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Javier Chogllo>
-- Create date: <2021-11-04>
-- Description:	<Compara el numero de unidades de las tablas FactVentaTaller y FactVentaResumido>
-- =============================================
-- EXEC [dbo].[Get_RS_T_NumeroVINsTaller_GM_xFecha] 'Zona 1','2021-10-01','2021-10-31'
ALTER PROCEDURE [dbo].[Get_RS_T_NumeroVINsTaller_GM_xFecha]  
(
	@zona VARCHAR (10),
	@fecini date,
	@fecfin date
)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	declare @nro_ordenes int
	DECLARE @devoluciones int

   	/******* FactVentaResumidoTaller ***********************************************************/
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
	join [DWH_Talleres]..DimZona z on z.id_zona = b.id_zona
	where cast(r.FECHA_FACTURA as date) between @fecini and @fecfin
	and id_tipo_transaccion = 1
	and z.zona = @zona
	--and r.NRO_ORDEN in (415950,354213,371170,361343,383990,420860,436990,421858,437123)
	--and r.NRO_ORDEN in (321257)
	--and r.NRO_ORDEN in (436990)
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
	JOIN [DWH_Talleres]..DimBodega b on r.id_cot_bodega = b.Id
	JOIN [DWH_Talleres]..[DimZona] z ON b.id_zona = z.id_zona
	where cast(r.FECHA_FACTURA as date) between @fecini and @fecfin
	and id_tipo_transaccion = -1
	and z.zona = @zona
	--and r.NRO_ORDEN in (415950,354213,371170,361343,383990,420860,436990,421858,437123)
	--and r.NRO_ORDEN in (321257)
	--and r.NRO_ORDEN in (436990)
	--and (NETO_MO <> 0 or NETO_TOT_MO <> 0)
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
	-------- ya que  ---------------
	-------------------------------------------------------------------------------------------------------------------------------------------------------
	select DISTINCT 
	       SW=r.id_tipo_transaccion,
		   r.NRO_ORDEN,
		   --r.Id_Factura_NC_ND,
		   ZONA = UPPER (r.zona),
		   MARCA_VH = ISNULL (UPPER (m.marca), ''),
		   TIPO_ORDEN = ISNULL (UPPER (t.tipo_orden), ''),
		   LINEA_VH = ISNULL (l.linea_vehiculo, '')
	--into #resultado_final1
	from #resultado r
	--LEFT JOIN [DWH_Talleres]..[DimZona] z ON b.id_zona = z.id_zona
	LEFT JOIN [DWH_Talleres].[dbo].[DimMarca] m ON r.id_marca_vehiculo = m.id_marca
	LEFT JOIN [DWH_Talleres].[dbo].[DimLineaVehiculo] l ON r.id_linea_vehiculo = l.id_linea_vehiculo
	LEFT JOIN [DWH_Talleres].[dbo].[DimTipoOrden] t ON r.id_tipo_orden = t.id_tipo_orden
	where (r.id_tipo_transaccion = 1 and r.DEVOLUCION = 'No')
	OR (r.id_tipo_transaccion = -1 and r.FAC_ORIGINAL not in (select distinct dev.Id_Factura_NC_ND from #resultado dev where dev.id_tipo_transaccion = 1))
	
	--select distinct id_tipo_transaccion,NRO_ORDEN
	--into #resultado_final
	--from #resultado r
	--where (r.id_tipo_transaccion = 1 and r.DEVOLUCION = 'No')
	--OR (r.id_tipo_transaccion = -1 and r.FAC_ORIGINAL not in (select distinct dev.Id_Factura_NC_ND from #resultado dev where dev.id_tipo_transaccion = 1))
	--order by 2

	--select *
	--from #resultado_final r
	--join #resultado d on (d.id_tipo_transaccion = r.id_tipo_transaccion and d.NRO_ORDEN = r.NRO_ORDEN) 

	-- EXEC [dbo].[SP_DBA_T_CompararNumeroUnidadesTaller] 3,'2021-10-01','2021-10-31'

	-- eliminar temporales
	drop table #ingresos
	drop table #devoluciones
	drop table #resultado

END