USE [dms_smd3]
GO
/****** Object:  StoredProcedure [dbo].[GetOrdenesFacturasTaller]    Script Date: 24/3/2022 22:56:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =================================================================================================================================
-- Author:		  <Angelica Pinos / Javier Chogllo>
-- Create date:   <2021-07-27>
-- Modulo:		  <Reporteria MEPA>
-- Descripción:   <Reporte para obtener las ordenes de consolidados y garantias con sus respectivas facturas
-- Observaciones: <Procedimiento base dado por Jorge Arias (DMS)>
--				
-- Historial de Cambios:
-- 2021-08-02     <Se agrega condicion para las Ordenes Parciales que se facturaron en fechas diferentes, 
--                 Ejemplo Nro. de Orden 104794 (JCH)
--> 19/01/2022  --> Se eliminan joins innecesarios para mejorar rendimiento (RPC)	
--> 19/01/2022  --> Se crea la tabla tempotal #tipos para mejorar duración de script (JCB)	
-- =================================================================================================================================

-- exec [dbo].[GetOrdenesFacturasTaller] 605, 0, '2022-02-01','2022-02-28'

alter PROCEDURE [dbo].[GetOrdenesFacturasTaller]
(
	--Declaramos las variables para generar el reporte
	@emp INT, --ID de la empresa
	@Bod VARCHAR(MAX), -- Bodegas
	@fecIni DATE, -- Fecha Factura
	@fecFin DATE -- Fecha Factura
)	
AS
	--
	SELECT	t.sw, 
			t.id,
			t.descripcion , 
			t.es_remision, 
			t.es_traslado,
			t.ecu_emision, 
			t.id_ecu_tipo_comprobante
	INTO #tipos
	FROM dbo.cot_tipo t
	WHERE t.id_emp=@emp	
	--and t.sw=46
	CREATE NONCLUSTERED INDEX ix_idtipo ON #tipos (id)
	
	
	----NUEVO PROCESO DE GARANTIAS Y CONSOLIDADAS----------
    SELECT c.id_emp,
	       c.id as IdOrden,
		   c.fecha,
	       estado = c.anulada,
	       result = CASE WHEN c.anulada IS NULL THEN NULL
						 WHEN c.anulada = 1 THEN
							'Orden está Facturada'
						 WHEN c.anulada = 2 THEN
							'Orden está cerrada'
						 WHEN c.anulada = 3 THEN
							'Orden facturada Parcial'
						 WHEN c.anulada = 4 THEN
							'Anulado'
						 WHEN c.anulada > 4 THEN
							'Orden no se puede usar: ' + CAST(c.anulada AS VARCHAR)
                    END,
		   c.idv,
		   Notas = CAST(c.notas AS varchar(max))
   INTO #OrdenesDetalladas
   FROM dbo.cot_cotizacion c
   LEFT JOIN #tipos tp ON tp.id = c.id_cot_tipo --and tp.id_emp=@emp
   WHERE c.id_emp = @emp 
   and tp.sw=46
   GROUP BY c.id_emp,c.id,c.anulada,c.fecha,c.idv,CAST(c.notas AS varchar(max))

   --231993
   --select * from #OrdenesDetalladas

   

    Select distinct ct.id as IdDoc,tt.sw,tt.descripcion,ot.IdOrden,ot.fecha,ot.estado,ot.result,
		id_consol = CASE WHEN i.id_prd_orden_estructuraPT <> ot.IdOrden THEN i.id_prd_orden_estructuraPT ELSE NULL END,
		GTIA_Orden = CASE WHEN c2.id = ct.id THEN NULL ELSE c2.id END,
		GTIA_Madre = i.id_prd_orden_estruc,
		Id_Factura=ifac.id_cot_cotizacion,
		ifac.fecha_fac,
		Id_Devolucion=ifac.id_cot_cotizacion_dev,
		CAST(ot.notas AS varchar(max)) as Notas
	INTO #DocumentosOrdenes
	FROM #OrdenesDetalladas ot
    LEFT JOIN dbo.cot_cotizacion ct on ct.id=ot.IdOrden -- Enlazo de nuevo con la orden para traer el resto de la informacion de la orden 
	LEFT JOIN dbo.cot_cotizacion cc ON cc.id = ct.id_cot_cotizacion_sig --Para traer el id del cliente 
	LEFT JOIN dbo.cot_tipo tt ON tt.id = ct.id_cot_tipo AND ISNULL(tt.sw,0) <> -1 
	LEFT JOIN dbo.cot_cotizacion_item i ON i.id_cot_cotizacion = ct.id OR i.id_prd_orden_estruc = ct.id OR i.id_prd_orden_estructuraPT = ct.id
	LEFT JOIN dbo.cot_cotizacion c3 ON c3.id = i.id_cot_cotizacion
	LEFT JOIN dbo.cot_cotizacion c2 ON c2.id = ISNULL(c3.id_cot_cotizacion_sig, i.id_cot_cotizacion)
									   AND c2.id <>ot.IdOrden --para que no se traiga así misma
	LEFT JOIN dbo.v_tal_orden_item_facturados_mep_proauto ifac ON ifac.id_componenteprincipalEst = i.id 
	          AND ISNULL(ifac.id_cot_cotizacion_sig_dev,0) <> ot.IdOrden
			  AND (ifac.id_tal_orden = ot.IdOrden OR i.id_prd_orden_estruc IS NOT NULL) --Solo si es la misma o si viene de consolidada
	LEFT JOIN dbo.cot_cotizacion cs ON cs.id = ct.idv --Ver consolidadas en la original
	WHERE
		(
			ct.id = ot.IdOrden
			OR ct.id_cot_cotizacion_sig = ot.IdOrden
			OR (ct.idv = ot.IdOrden) AND CHARINDEX('cons',CAST(cs.notas AS VARCHAR))>0 
			OR i.id_prd_orden_estruc = ot.IdOrden--para garantías
			OR i.id_prd_orden_estructuraPT = ot.IdOrden --para consolidados
		) 

	--select * from #DocumentosOrdenes where IdOrden = 361372

	--OJO CONSULTAR QUE ES EL ESTADO 4
	Update #DocumentosOrdenes set result='Orden Consolidada' Where estado = 4 and substring(Notas,1,6)='*cons*'

	Select distinct d.id_consol,d.estado 
	INTO #Consolidadaordenes
	from #Documentosordenes d
	where d.estado = 4 and d.id_consol is not null 
	order by id_consol


	--ACTUALIZAR LA CONSOLIDAD MADRE EN LA ORDEN EN DONDE SE CONSOLIDO
	Update a set a.Id_consol = b.id_consol
	from #Documentosordenes a
	left join #Consolidadaordenes b on b.id_consol=a.IdOrden
	where a.id_consol is null and a.Id_Factura is not null

	-- Se cambia el select de garantias con un cruze a la vista de items facturados,
	-- para poder obetner la factura real en la cual fueron facturadas las operaciones de la orden
	-- Se toma entonces el id de la factura y la fecha de la vista para continuar con el proceso.
	select DISTINCT id_factura = vf.id_cot_cotizacion , d.IdOrden
	INTO #GARANTIAS 
	FROM #documentosordenes d
	left join v_tal_orden_item_facturados_mep_proauto vf on vf.id_tal_orden = d.idorden
	where (id_consol<>0  or GTIA_Madre<>0) 
	and CAST(vf.fecha_fac AS DATE) BETWEEN @fecIni AND @fecFin

	select * from #GARANTIAS;
	