USE [dms_smd3]
GO
/****** Object:  StoredProcedure [dbo].[GetPerfilClientesGM]    Script Date: 15/3/2022 18:59:36 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ===========================================================================================================================================================================
-- Author:		<Angelica Pinos>
-- Create date: <2021-00-00>
-- Modulo:		<Reporteria>
-- Description:	<Procedimiento para obtener informacion del perfil de clientes GM  (Reporte 100040 Advance)
-- Historial de Cambios:
--> 07/10/2021	-->	Se utiliza como base el reporte 100021 para obtener la información
--> 27/08/2021  --> Se ajusta el repore a los cambios realizados en el 100021 (JCB)
--> 08/11/2021	-->	Se agrega total mo y se cambia la columna forma de pago al final de los totales (APF)
--> 16/11/2021	-->	Se ajusta el campo SEGMENTO del Vehiculo (JCB)
--> 17/11/2021  --> Se ajusta el campo TIPO_ORDEN para que indique si la orden es Externa o Interna, requerido solo para este formato para la marca GM
--> 06/01/2022  --> Se cambia el Orden de los campos segun formato enviado por Cesar Torres, Y se agrega el Campo Trabajos_Realizados (MQR)
--> 19/01/2022  --> Se eliminan campos y joins innecesarios para mejorar rendimiento (de 00:01:47 a 00:01:05) (RPC)
--> 10/02/2022  --> Se elimina la insercion en tabla temporal de cliente y se hace solo el join respectivo (RPC)
--> 10/02/2022  --> Se ajusta tamaño campo notas (RPC)
-- ===========================================================================================================================================================================

-- EXEC [dbo].[GetPerfilClientesGM] '2022-02-01','2022-02-28'


ALTER PROCEDURE [dbo].[GetPerfilClientesGM]
	(				
		@fecIni DATE,
		@fecFin DATE			
	)
	AS

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	SET NOCOUNT ON;

	declare @emp INT = 605
	declare @Bod VARCHAR(MAX)=0
	declare @cli INT=0

	DECLARE @Razones_Ingreso AS TABLE (
		îd	INT
		,razon VARCHAR(MAX)
		,grupo VARCHAR(MAX)
		,colision INT
		,mantenimiento INT
		,accesorios INT
		,garantia INT
		,mecanica INT
	)

	---- TEMPORAL PARA ALMACENAR LA LINEA DE NEGOCIO DE ACUERDO A GRUPO Y SUBGRUPO
	DECLARE @Linea AS TABLE (
		id_item INT,
		linea VARCHAR(50)
	)

	CREATE TABLE #Docs (
		id INT,
		id_cot_tipo INT,
		id_cot_bodega INT,
		id_cot_cliente INT,
		id_cot_cliente_contacto INT,
		numero_cotizacion INT,
		fecha DATE,
		notas VARCHAR(MAX),
		id_cot_item INT,
		id_cot_item_lote INT,
		cantidad_und DECIMAL(18, 2),
		tiempo DECIMAL(18,2),
		precio_lista DECIMAL(18, 2),
		precio_cotizado DECIMAL(18, 2),
		costo DECIMAL(18, 2),
		porcentaje_descuento DECIMAL(18, 2),
		porcentaje_descuento2 DECIMAL(18, 2),
		porcentaje_iva DECIMAL(18, 2),
		DesBod VARCHAR(300),
		id_com_orden_concepto INT,
		ecu_establecimiento VARCHAR(4),
		id_usuario_ven INT,
		id_forma_pago INT,
		docref_numero VARCHAR(30),
		docref_tipo VARCHAR(20),
		sw INT,
		saldo DECIMAL(18, 2),
		id_cot_pedido_item INT,
		ot INT,
		id_veh_hn_enc iNT, 
		id_cot_cotizacion_item int,
		total_total money,
		facturar_a char(2) ,
		tipo_operacion char(2) , 
		id_cot_item_vhtal  int ,
		id_cot_cotizacion_sig int ,
		id_operario int,
		valor_hora DECIMAL(18, 2),
		renglon int,
		notas_item VARCHAR(500) COLLATE Modern_Spanish_CI_AI,
		ot_final int,
		tipo_orden varchar(5),
		id_item int
	
	)
	
	------------------FILTROS INICIALES	  
	DECLARE @Bodega AS TABLE 
	(
		id INT,
		descripcion VARCHAR(200),
		ecu_establecimiento VARCHAR(6)
	)

	insert @Bodega
	select distinct b.id,
	       b.descripcion,
		   b.ecu_establecimiento
	from cot_bodega b
	--join cot_cotizacion c on (b.id = c.id_cot_bodega)
	--join cot_tipo t on (t.id = c.id_cot_tipo and t.sw = 46)
	where b.id_emp = 605
	and b.descripcion like '% TAL'

	

	----NUEVO PROCESO DE GARANTIAS Y CONSOLIDADAS----------
	create table #OTs_CONSOLIDADAS_GARATIAS
	(
		id_factura int,
		IdOrden int
	)
	insert #OTs_CONSOLIDADAS_GARATIAS
	exec [dbo].[GetOrdenesFacturasTaller] @emp,@Bod,@fecIni,@fecFin --inicial 18 seg.
	create table #OTs_CONSOLIDADAS_GARATIAS_NC 
	(
		id_factura int,
		IdOrden int
	)
	insert #OTs_CONSOLIDADAS_GARATIAS_NC exec [dbo].[GetOrdenesNCTaller] @emp,0

		-----PRIMERA INSERCION EN DOCS --------------------------------------------------------
	INSERT #Docs
	(
		id,
		id_cot_tipo,
		id_cot_bodega,
		id_cot_cliente,
		id_cot_cliente_contacto,
		numero_cotizacion,
		fecha,
		notas,
		id_cot_item,
		id_cot_item_lote,
		cantidad_und,
		tiempo,
		precio_lista,
		precio_cotizado,
		costo,
		porcentaje_descuento,
		porcentaje_descuento2,
		porcentaje_iva,
		DesBod,
		id_com_orden_concepto,
		ecu_establecimiento,
		id_usuario_ven,
		id_forma_pago,
		docref_numero,
		docref_tipo, 									 
		sw,
		saldo,
		id_cot_pedido_item, 
		id_veh_hn_enc ,
		id_cot_cotizacion_item ,
		total_total,
		facturar_a,
		tipo_operacion ,
		id_cot_item_vhtal,
		id_cot_cotizacion_sig,
		id_operario,												 
		valor_hora,
		renglon,
		notas_item,
		ot_final,
		tipo_orden,
		id_item
	)
	SELECT id = c.id,
		   id_cot_tipo = c.id_cot_tipo,
		   id_cot_bodega = c.id_cot_bodega,
		   id_cot_cliente = c.id_cot_cliente,
		   id_cot_cliente_contacto = c.id_cot_cliente_contacto ,
		   numero_cotizacion = c.numero_cotizacion,
		   fecha = c.fecha,
		   notas = cAST (c.notas  AS varchar(MAX)), 
		   id_cot_item = i.id_cot_item,
		   id_cot_item_lote = i.id_cot_item_lote,
		   cantidad_und = i.cantidad_und * t.sw,
		   tiempo = CASE WHEN t.sw =-1 THEN (SELECT ci1.tiempo 
											FROM cot_cotizacion_item ci1 
											WHERE ci1.id = i.id_cot_cotizacion_item_dev) * -1
						ELSE i.tiempo 
					END,
		   precio_lista = i.precio_lista,
		   precio_cotizado = i.precio_cotizado,
		   costo = i.costo_und,
		   porcentaje_descuento = i.porcentaje_descuento,
		   porcentaje_descuento2 = i.porcentaje_descuento2,
		   porcentaje_iva = i.porcentaje_iva,
		   DesBod = b.descripcion,
		   id_com_orden_concepto = c.id_com_orden_concep,
		   ecu_establecimiento = b.ecu_establecimiento,
		   id_usuario_ven = c.id_usuario_vende,
		   id_forma_pago = c.id_cot_forma_pago,
		   docref_numero = c.docref_numero,
		   docref_tipo = c.docref_tipo, 
		   sw = t.sw,
		   saldo = c.total_total - ISNULL(s.valor_aplicado, 0),
		   id_cot_pedido_item = i.id_cot_pedido_item, 
		   id_veh_hn_enc = c.id_veh_hn_enc,
		   id_cot_cotizacion_item = i.id,
		   total_total = c.total_total,
		   facturar_a = i.facturar_a,
		   tipo_operacion = i.tipo_operacion	,
		   id_cot_item_vhtal = c.id_cot_item_lote ,
		   id_cot_cotizacion_sig = c.id_cot_cotizacion_sig,
		   id_operario = i.id_operario,
		   valor_hora = CASE WHEN t.sw =-1 THEN (SELECT ci1.precio_cotizado 
												FROM cot_cotizacion_item ci1 
												WHERE ci1.id = i.id_cot_cotizacion_item_dev) * -1
							ELSE i.valor_hora
						END,
		   renglon = i.renglon,
		   notas_item = i.notas,
		   ot_final = c.id_cot_cotizacion_sig,
		   tipo_orden = 'F',
		   id_item = i.id_componenteprincipalEst
	FROM dbo.cot_cotizacion c 
	JOIN dbo.cot_tipo t ON (t.id = c.id_cot_tipo) 
    JOIN @Bodega b ON (b.id = c.id_cot_bodega)     
	JOIN dbo.cot_cotizacion_item i ON (i.id_cot_cotizacion = c.id)
    LEFT JOIN dbo.v_cot_factura_saldo s ON (s.id_cot_cotizacion = c.id)
	LEFT JOIN dbo.v_cot_cotizacion_factura_dev fdev ON (t.sw = -1 AND fdev.id_cot_cotizacion = c.id)
	where c.id_emp = @emp	  -- AND C.ID=39681
	  and  CAST(c.fecha AS DATE) BETWEEN @fecIni AND @fecFin
	  AND t.sw IN ( 1, -1 ) 
	  and isnull(c.anulada,0) <> 4 	
	  and t.es_remision is  null 
	  and t.es_traslado is   null 
	  AND (t.sw = 1 AND (c.id NOT IN (select g.id_factura from #OTs_CONSOLIDADAS_GARATIAS g)) 
	  	OR t.sw = -1 AND (ISNULL (fdev.id_cot_cotizacion_factura, 0) NOT IN (select g.id_factura from #OTs_CONSOLIDADAS_GARATIAS_NC g)))
	  and (@cli=0 or c.id_cot_cliente=@cli)
	  AND (ISNULL (i.facturar_a, 'NULL') <> 'S') -- Excluimos los ítems que corresponden a insumos
	
	------------------------------INSERTAMOS EN DOCS LA INFROMACION DE GARANTIAS Y CONSOLIDADAS------------------------
	--- PRIMERO BUSCAMOS LA ORDEN ORIGINAL Y LA INSERTAMOS EN UNA TABLA TEMPORAL
	SELECT 	id_factura=ci.id_cot_cotizacion,
			--t.sw, 
			ci.id,
			c.id_cot_cotizacion_sig,
			--ci.id_cot_item,
			--ci.cantidad,
			ci.facturar_a,
			--ci.precio_cotizado,
			--ci.tipo_operacion,
			ci.id_componenteprincipalest
	into #detdatos 
	FROM dbo.cot_cotizacion c
	JOIN dbo.cot_tipo t ON (t.id = c.id_cot_tipo) 
	LEFT JOIN dbo.v_cot_cotizacion_factura_dev fdev ON fdev.id_cot_cotizacion = CASE WHEN t.sw = -1 THEN c.id ELSE NULL END
	JOIN dbo.cot_cotizacion_item ci ON ci.id_cot_cotizacion = CASE WHEN t.sw = -1 THEN fdev.id_cot_cotizacion_factura ELSE c.id END
	WHERE c.id_emp=@emp
	  and (t.sw = 1 AND (c.id IN (select g.id_factura from #OTs_CONSOLIDADAS_GARATIAS g)) 
	   OR t.sw = -1 AND (fdev.id_cot_cotizacion_factura IN (select g.id_factura from #OTs_CONSOLIDADAS_GARATIAS_NC g)));

	----GMAH PERSONALIZADO
	CREATE TABLE #detad
	(
		id_factura int, 
		id_det_fac int,
		id_det_orden int,
		id_otfinal int, 
		id_otori int,
		--id_tal_garantia_clase int, 
		--ClaseGarantia  varchar(150),
		facturar_a varchar(5)
	)

	INSERT #detad
	(
		id_factura, 
		id_det_fac,
		id_det_orden,
		id_otfinal, 
		id_otori ,
		--id_tal_garantia_clase, 
		--ClaseGarantia,
		facturar_a
	)
	SELECT	id_factura = d.id_factura,
			id_det_fac = d.id,
			id_det_orden = c.id,
			id_otfinal = d.id_cot_cotizacion_sig,
			id_otori = ISNULL (c3.idv,c2.id),
			--id_tal_garantia_clase = ccim.id_tal_garantia_clase,
			--clasegarantia = ISNULL (tgc.descripcion, ''),
			facturar_a = d.facturar_a
	FROM dbo.cot_cotizacion ct
	JOIN dbo.cot_cotizacion_item c ON c.id_cot_cotizacion = ct.id
	--LEFT JOIN dbo.cot_cotizacion_item_mas ccim  ON c.id = ccim.id_cot_cotizacion_item
	LEFT JOIN dbo.cot_tipo tt ON tt.id = c.id_cot_tipo_tran
	--LEFT JOIN dbo.v_cot_cotizacion_item cci ON cci.id = c.id_cot_cotizacion_item_dev
	LEFT JOIN dbo.v_cot_cotizacion_item_dev2 dev ON dev.id_cot_cotizacion_item = c.id
	LEFT JOIN dbo.cot_cotizacion c3 ON c3.id = c.id_cot_cotizacion
	LEFT JOIN cot_cotizacion c2 ON c2.id = ISNULL(c3.id_cot_cotizacion_sig,c.id_cot_cotizacion)
	LEFT JOIN dbo.cot_tipo tjd 	ON tjd.id = c3.id_cot_tipo
	--LEFT JOIN dbo.cot_cotizacion cc ON cc.id = ct.id_cot_cotizacion_sig
	--LEFT JOIN dbo.tal_garantia_clase tgc ON tgc.id = ccim.id_tal_garantia_clase
	JOIN #detdatos d ON (ct.id = d.id_cot_cotizacion_sig 
		                    OR ct.id_cot_cotizacion_sig = d.id_cot_cotizacion_sig 
							OR c.id_prd_orden_estruc = d.id_cot_cotizacion_sig 
							OR c.id_prd_orden_estructurapt = d.id_cot_cotizacion_sig) 		 
	WHERE ct.id_emp=@emp
	AND ISNULL(tjd.sw,0) <> 1 
	AND (tt.sw NOT IN ( 2,-1,46,47 ) OR tt.sw = 12 OR tt.sw IS NULL) 
	AND c.cantidad - ISNULL(dev.cantidad_devuelta,0) > 0 
	AND ( c.tipo_operacion IS NOT NULL OR tt.sw = 47)
	AND  d.id_componenteprincipalest = c.id

	-- SEGUNDO INSERTAMOS LAS ORDENES DE GARANTIAS Y CONSOLIDADAS EN #DOCS
	INSERT #Docs
	(
		id,
		id_cot_tipo,
		id_cot_bodega,
		id_cot_cliente,
		id_cot_cliente_contacto,
		numero_cotizacion,
		fecha,
		notas,
		id_cot_item,
		id_cot_item_lote,
		cantidad_und,
		tiempo,
		precio_lista,
		precio_cotizado,
		costo,
		porcentaje_descuento,
		porcentaje_descuento2,
		porcentaje_iva,
		DesBod,
		id_com_orden_concepto,
		ecu_establecimiento,
		id_usuario_ven,
		id_forma_pago,
		docref_numero,
		docref_tipo, 									 
		sw,
		saldo,
		id_cot_pedido_item, 
		id_veh_hn_enc ,
		id_cot_cotizacion_item ,
		total_total,
		facturar_a,
		tipo_operacion ,
		id_cot_item_vhtal,
		id_cot_cotizacion_sig,
		id_operario,												 
		valor_hora,
		renglon,
		notas_item,
		ot_final,
		tipo_orden,
		id_item
	)

	SELECT	id = c.id_cot_cotizacion,
			id_cot_tipo = cc.id_cot_tipo,
			id_cot_bodega = cco.id_cot_bodega,
			id_cot_cliente = cc.id_cot_cliente,
			id_cot_cliente_contacto = cc.id_cot_cliente_contacto,
			numero_cotizacion = cc.numero_cotizacion,
			fecha = CAST (cc.fecha AS DATE), 
			notas = cAST (cc.notas  AS varchar(MAX)), 
			id_cot_item = c.id_cot_item,
			id_cot_item_lote = 0, --revisar este campo
			cantidad_und = c.cantidad_und * t.sw,
			tiempo = CASE WHEN t.sw =-1 THEN (SELECT ci1.tiempo 
											  FROM cot_cotizacion_item ci1 
											  WHERE ci1.id = c.id_cot_cotizacion_item_dev) * -1
						  ELSE c.tiempo
					 END,
			precio_lista = c.precio_lista ,
			precio_cotizado = c.precio_cotizado,
			costo = NULLIF (c.costo_und, 0),
			porcentaje_descuento =  c.porcentaje_descuento ,
			porcentaje_descuento2 = c.porcentaje_descuento2, --jdms 739
			porcentaje_iva = c.porcentaje_iva,
			DesBod = b.descripcion,
			id_com_orden_concepto = cc.id_com_orden_concep,
			ecu_establecimiento = b.ecu_establecimiento,
			id_usuario_ven = cco.id_usuario_vende,
			id_forma_pago = cc.id_cot_forma_pago,
			docref_numero = cc.docref_numero,
			docref_tipo = cc.docref_tipo, 
			sw = t.sw,
			saldo = cc.total_total - ISNULL(sal.valor_aplicado, 0),
			id_cot_pedido_item = c.id_cot_pedido_item,
			id_veh_hn_enc = cc.id_veh_hn_enc,
			id_cot_cotizacion_item = c.id,
			total_total = cc.total_total,
			facturar_a = c.facturar_a,
			tipo_operacion = cci2.tipo_operacion, -- MEP
			id_cot_item_vhtal = cco.id_cot_item_lote ,
			id_cot_cotizacion_sig = adi.id_otori, --GMAH PERSONALIZADO
			id_operario = c.id_operario,
			valor_hora = CASE WHEN t.sw =-1 THEN (SELECT ci1.precio_cotizado 
												  FROM cot_cotizacion_item ci1 
												  WHERE ci1.id = c.id_cot_cotizacion_item_dev) * -1
								ELSE c.valor_hora
							END,
			renglon = c.renglon,
			notas_item = c.notas,
			ot_final = adi.id_otfinal,
			tipo_orden = adi.facturar_a,
			id_item = c.id_componenteprincipalEst
	FROM dbo.v_cot_cotizacion_item_todos_mep c
	LEFT JOIN cot_cotizacion cc ON cc.id=c.id_cot_cotizacion and cc.id_emp=605 and isnull(cc.anulada,0) <>4 	 and  CAST(cc.fecha AS DATE)  BETWEEN @fecIni AND @fecFin  --and  CAST(cc.fecha AS DATE)  BETWEEN @fecIni AND @fecFin
	LEFT JOIN dbo.v_cot_factura_saldo sal ON sal.id_cot_cotizacion = cc.id
	LEFT JOIN dbo.cot_tipo t ON t.id = cc.id_cot_tipo
	LEFT JOIN dbo.v_cot_cotizacion_item cci ON cci.id = c.id_cot_cotizacion_item_dev
	LEFT JOIN dbo.v_cot_cotizacion_item cci2 ON cci2.id = c.id --MEP
	LEFT JOIN dbo.v_cot_cotizacion_factura_dev fdev ON fdev.id_cot_cotizacion = CASE WHEN t.sw = -1 THEN c.id_cot_cotizacion ELSE NULL END
	LEFT JOIN #detad adi ON adi.id_det_fac= CASE WHEN t.sw = -1 THEN cci.id ELSE c.id END --GMAH PERSONALIZADO
	LEFT JOIN cot_cotizacion cco ON cco.id=adi.id_otori and cco.id_emp=@emp
	LEFT JOIN dbo.cot_bodega b ON b.id = CASE WHEN cco.id_cot_bodega IS NULL THEN cc.id_cot_bodega ELSE cco.id_cot_bodega END
	WHERE (t.sw = 1 AND (c.id_cot_cotizacion IN (select g.id_factura from #OTs_CONSOLIDADAS_GARATIAS g)) 
		OR t.sw = -1 AND (fdev.id_cot_cotizacion_factura IN (select g.id_factura from #OTs_CONSOLIDADAS_GARATIAS_NC g)))
	AND (c.id_cot_cotizacion_item IS NULL)
	and t.sw IN ( 1, -1 ) 
	and t.es_remision is null 
    and t.es_traslado is null 
    and (@cli=0 or cc.id_cot_cliente=@cli)
	AND (ISNULL (c.facturar_a, 'NULL') <> 'S') -- Excluimos los ítems que corresponden a insumos

	--- validacion notas credito 
		
	DECLARE @Devoluciones AS TABLE (
		id_factura INT,
		--id_nc INT,
		fecha DATE,
		ot INT
	)

	INSERT @Devoluciones
	SELECT DISTINCT 
			id_factura = ISNULL (fact.id, '')
			--,id_nc = ISNULL (devo.id, '')
			,fecha = devo.fecha
			,ot = ot.id
	FROM #Docs fact
	JOIN dbo.v_cot_cotizacion_factura_dev fdev ON (fact.sw = 1 AND fdev.id_cot_cotizacion_factura = fact.id)
	JOIN dbo.cot_cotizacion devo ON fdev.id_cot_cotizacion = devo.id
	JOIN dbo.cot_cotizacion ot ON devo.id_cot_cotizacion_sig = ot.id

	-----------FLOTAS TALLER----
	select DISTINCT 
	d.id,
	--d.id_cot_tipo,
	d.id_cot_item_vhtal,
	--tf.codigo, 
	--tf.descripcion,
	--tf.fechaini,
	--tf.fechafin,
	--id_tal_flota=tf.id,
	ClaseCliente=tc.descripcion,
	EstaEnFlota=case when d.fecha between tf.fechaini and tf.fechafin then 'S' else 'N' end
	into #flotasTaller					   
	from  #docs d
	join tal_flota_veh fv on fv.id_cot_item_lote=d.id_cot_item_vhtal and (fv.inactivo <> 1 OR fv.inactivo IS NULL) -- SE AGREGA LA CONDICION IS NULL PARA VERIFICAR QUE EL VEHICULO ESTE ACTIVO EN LA FLOTA
	join tal_flota tf on tf.id=fv.id_tal_flota
	join tal_flota_clase	 tc on tc.id=tf.id_tal_flota_clase
		
	---- @Linea - INSERTAMOS LA LINEA DE LOS ITEMS DEL GRUPO REPUESTOS, TALLER Y TOT
	INSERT @Linea
	SELECT 	id_item = item.id, 
			linea = CASE WHEN grup.id = 1337 THEN 'TOT' ELSE grup.descripcion END
	FROM #Docs docs 
		JOIN dbo.cot_item item ON item.id = docs.id_cot_item
		JOIN dbo.cot_grupo_sub gsub ON gsub.id = item.id_cot_grupo_sub
		JOIN dbo.cot_grupo grup ON grup.id = gsub.id_cot_grupo
	WHERE grup.id IN (1321, 1322, 1323, 1326, 1337)
	GROUP BY item.id, grup.id, grup.descripcion;

	---- @Linea - INSERTAMOS LA LINEA DE LOS ITEMS DE DESCUENTOS Y DEVOLUCIONES EN VENTA
	INSERT @LINEA 
	SELECT 	id_item = item.id, 
			linea = CASE
						WHEN gsub.descripcion LIKE '%TAL%' THEN 'TALLER'
						WHEN gsub.descripcion LIKE '%REP%' THEN 'REPUESTOS'
						WHEN gsub.descripcion LIKE '%VEH%' THEN 'VEHICULOS'
						WHEN gsub.descripcion LIKE '%ACCESOR%' THEN 'ACCESORIOS'
						WHEN gsub.descripcion LIKE '%DISPO%' THEN 'DISPOSITIVOS'
						--WHEN gsub.descripcion LIKE '%MOT%' THEN 'VEHICULOS' --Las motos son obsequios que se regalan en la venta de vehiculos
						WHEN grup.id = 1343 THEN CASE WHEN gsub.descripcion LIKE '%MOTO%ELEC%' THEN 'VEHICULOS'
						                              ELSE 'ACCESORIOS'
												 END						
					END
	FROM #Docs docs 
		JOIN dbo.cot_item item ON item.id = docs.id_cot_item
		JOIN dbo.cot_grupo_sub gsub ON gsub.id = item.id_cot_grupo_sub
		JOIN dbo.cot_grupo grup ON grup.id = gsub.id_cot_grupo
	WHERE grup.id IN (1332, 1341, 1343)
	GROUP BY item.id, grup.descripcion, grup.id, gsub.descripcion;

	SELECT	DISTINCT 
			[id] = ti.id
			,[razon] = ti.descripcion, ti.id_tal_motivo_ingreso_grupo
			,[grupo] = tg.descripcion
			,colision = CASE
							WHEN tg.id = 5 THEN 1
							ELSE 0
						END
			,mantenimiento = CASE
								WHEN tg.id IN (2, 7) THEN 1
								ELSE 0
							END
			,accesorios = CASE
							WHEN tg.id = 1 THEN 1
							ELSE 0
						END
			,garantia = CASE
							WHEN tg.id = 6 THEN 1
							ELSE 0
						END
			,mecanica = CASE
							WHEN tg.id = 4 THEN 1
							ELSE 0
						END
		INTO #razon_ingreso
		FROM dbo.tal_motivo_ingreso ti 
			LEFT JOIN dbo.tal_motivo_ingreso_grupo tg ON tg.id = ti.id_tal_motivo_ingreso_grupo 
		WHERE ti.id_emp = @emp;
	/*
	--4.Cargar información de terceros
	SELECT	DISTINCT
			[id] = c.id,
			[razon_social] = c.razon_social,
	        [nombres] =	ISNULL(cn.nom1 + ' ' + cn.nom2, c.razon_social),
	        [apellidos] = ISNULL(cn.ape1 + ' ' + cn.ape2, ''),
	        [nit] = c.nit,
		    [tipo] = CASE 
		   						WHEN c.tipo_identificacion = 'O' THEN 'GOBIERNO'
		                    	WHEN c.tipo_identificacion = 'N' THEN 'CORPORATIVO'
								ELSE 'RETAIL' END, 
		    [sexo] = CASE
		   				WHEN cc.sexo = 1 THEN 'Masculino'
                       	WHEN cc.sexo = 2 THEN 'Femenino'
                       	ELSE ''
					END,
		    [fecha_nacimiento] = CASE 
									WHEN cn.ape1 + cn.ape2 IS NULL THEN 'No aplica'
									ELSE IIF(ISNULL(cc.mes_dia_cumple, '0') <> '0' AND ISNULL(cc.ano_cumple,'0')<>'0' ,CONCAT(cc.ano_cumple,'-', CASE	WHEN LEN(cc.mes_dia_cumple) = 3 THEN CONCAT('0',LEFT(mes_dia_cumple,1))
														ELSE LEFT(mes_dia_cumple,2)
												END,'-',RIGHT(mes_dia_cumple,2)),'No aplica')
								END,
	        [celular] = CASE 
							WHEN LEN (c.tel_2) = 10 THEN c.tel_2
							WHEN LEN (c.tel_1) = 10 THEN c.tel_1
							ELSE ''
						END,
	        [convencional] = c.tel_1,
	        [ciudad] = ISNULL(pc.descripcion, ''),
	        [provincia] = ISNULL(REPLACE(pd.descripcion, '.', ''), ''),
	        [pais] = ISNULL(p.descripcion, ''),
	        [direccion] = c.direccion,
	        [mail] = cc.email,
			[perfil] = ccp.descripcion
	INTO #Clientes
	FROM dbo.cot_cliente c
		 --JOIN #Docs do on do.id_cot_cliente=c.id
	LEFT JOIN dbo.cot_cliente_perfil ccp ON ccp.id = c.id_cot_cliente_perfil
		 JOIN dbo.cot_cliente_pais pc ON pc.id = c.id_cot_cliente_pais
		 JOIN dbo.cot_cliente_pais pd ON pd.id = pc.id_cot_cliente_pais
	     JOIN dbo.cot_cliente_pais p ON p.id = pd.id_cot_cliente_pais
	     JOIN dbo.cot_cliente_contacto cc ON cc.id = c.id_cot_cliente_contacto
	LEFT JOIN dbo.cot_cliente_nom cn ON cn.id_cot_cliente = c.id
	*/
	--5.Cargar información del vehiculo
	SELECT	DISTINCT 
			[id] = cil2.id, id_ot = cc.id
			,[placa] = ISNULL (cil3.placa, '')
			,[vin] = ISNULL (cil3.vin, '')
			,[longitud] = LEN (cil3.vin)
			--,[segmento] = ISNULL (ISNULL (cit2.descripcion, cit3.descripcion), '')
		    --,ci2.id_veh_linea
			--,cv2.campo_2
			,SEGMENTO = case when cv2.campo_2 in ('AUTOMOVIL') then
									CASE 
										WHEN ci2.id_veh_linea IN (794,818,860,867) then 'SUV'
										ELSE 'PASAJERO'
									END
						
								--when v2001.descripcion in ('AUTOMOVIL', 'CAMIONETA') then 'PASAJERO' 
								when cv2.campo_2 in ('') then 'PICKUP'
								when cv2.campo_2 in ('JEEP') then 'SUV'
								when cv2.campo_2 in ('CAMION') then 'CAMION'
								when isnull(cv2.campo_2,'0') = '0' then 
									CASE 
										WHEN ci2.id_veh_linea IN (838,831,830,901,833) then 'CAMIONETA' --LUV DMAX
										WHEN ci2.id_veh_linea IN (826) then 'AUTOMOVIL' --CRUZE 1.8L
										WHEN ci2.id_veh_linea IN (819) then 'SUV' --CAPTIVA LT TURBO 5 PAS AC 1.5 5P 4X2 TM
										WHEN ci2.id_veh_linea IN (847) then 'VAN' --N300 MOVE PSAJEROS FULL AC 1.2
										WHEN ci2.id_veh_linea IN (903) then 'CAMION' --MULTIMARCA CAMION
										
									END
								ELSE cv2.campo_2 
						   END
			,[clase_marca] = ISNULL(cv2.campo_2, '')
			,[modelo] = ISNULL (ISNULL(( CASE
							WHEN vm1.descripcion LIKE '%MULTIMARCA%' THEN
								CASE
									WHEN vcv2.campo_12 = '' OR vcv2.campo_12 IS NULL THEN ci2.descripcion
									ELSE vcv2.campo_12
								END
							ELSE 
								CASE
									WHEN ci2.codigo LIKE '%ALL%' THEN
										CASE
											WHEN vcv2.campo_12 ='' OR vcv2.campo_12 IS NULL THEN ci2.descripcion
											ELSE vcv2.campo_12
										END
									ELSE ci2.descripcion
								END
						END),
						(CASE
							WHEN vm2.descripcion LIKE '%MULTIMARCA%' THEN
								CASE
									WHEN vcv4.campo_12 = '' OR vcv4.campo_12 IS NULL THEN ci3.descripcion
									ELSE vcv4.campo_12
								END
							ELSE 
								CASE
									WHEN ci3.codigo LIKE '%ALL%' THEN
										CASE
											WHEN vcv4.campo_12 = '' OR vcv4.campo_12 IS NULL THEN ci3.descripcion
											ELSE vcv4.campo_12
										END
									ELSE ci3.descripcion
								END
						END)), '')
			,[familia] = ISNULL(cv2.campo_7, '')
			,[kilometraje] = ISNULL (cc.km, '')
			,[propietario] = ISNULL (cclp.razon_social, '')
			--,[año] = ISNULL (ISNULL((CASE 
			--	WHEN vm1.descripcion LIKE '%MULTIMARCA%' THEN
			--		CASE
			--			WHEN CONVERT (DECIMAL, vcv2.campo_13, 0) = 0 OR vcv2.campo_13 IS NULL THEN ci2.id_veh_ano
			--			ELSE CONVERT (DECIMAL, vcv2.campo_13, 0)
			--		END
			--	ELSE
			--		CASE 
			--			WHEN ci2.codigo LIKE '%ALL%' THEN
			--				CASE
			--					WHEN CONVERT (DECIMAL, vcv2.campo_13, 0) = 0 OR vcv2.campo_13 IS NULL THEN ci2.id_veh_ano
			--					ELSE CONVERT(decimal, vcv2.campo_13,0) 
			--				END
			--			ELSE ci2.id_veh_ano
			--		END
			--END),
			--(CASE 
			--	WHEN vm2.descripcion LIKE '%MULTIMARCA%' THEN
			--		CASE
			--			WHEN CONVERT (DECIMAL, vcv4.campo_13, 0) = 0 OR vcv4.campo_13 IS NULL THEN ci3.id_veh_ano
			--			ELSE CONVERT (DECIMAL, vcv4.campo_13, 0)
			--		END
			--	ELSE
			--		CASE
			--			WHEN ci3.codigo LIKE '%ALL%' THEN
			--				CASE
			--					WHEN CONVERT (DECIMAL, vcv4.campo_13, 0) = 0 OR vcv4.campo_13 IS NULL THEN ci3.id_veh_ano
			--					ELSE CONVERT (DECIMAL, vcv4.campo_13, 0) 
			--				END
			--					ELSE ci3.id_veh_ano
			--			END
			--END)), 0)
			,id_modelo = ISNULL (ci3.codigo, ci2.codigo) --0982629948
			
	INTO #Vehiculos
	FROM #Docs td
		LEFT JOIN dbo.cot_item_lote cil2 ON cil2.id = td.id_cot_item_vhtal
		LEFT JOIN dbo.cot_item ci2 ON ci2.id = cil2.id_cot_item
		LEFT JOIN dbo.v_campos_varios cv2 ON ci2.id_veh_linea_modelo = cv2.id_veh_linea_modelo

		LEFT JOIN dbo.veh_linea vl1 ON vl1.id = ci2.id_veh_linea
		LEFT JOIN dbo.veh_marca vm1 ON vm1.id = vl1.id_veh_marca
		--LEFT JOIN dbo.cot_item_talla cit2 ON cit2.id = ci2.id_cot_item_talla
		LEFT JOIN dbo.v_campos_varios vcv2 ON vcv2.id_cot_item_lote = cil2.id
		LEFT JOIN dbo.cot_cotizacion cc ON cc.id = td.id_cot_cotizacion_sig
		--LEFT JOIN v_campos_varios cv On cv.id_cot_cotizacion=cc.id and cv.campo_1 is not null
		LEFT JOIN dbo.cot_item_lote cil3 ON cil3.id = cc.id_cot_item_lote

		
		LEFT JOIN dbo.cot_item ci3 ON ci3.id = cil3.id_cot_item
		--LEFT JOIN dbo.v_campos_varios cv3 ON ci3.id_veh_linea_modelo = cv3.id_veh_linea_modelo
		LEFT JOIN dbo.veh_linea vl2 ON vl2.id = ci3.id_veh_linea
		LEFT JOIN dbo.veh_marca vm2 ON vm2.id = vl2.id_veh_marca
		LEFT JOIN dbo.cot_item_talla cit3 ON cit3.id = ci3.id_cot_item_talla
		LEFT JOIN dbo.v_campos_varios vcv4 ON vcv4.id_cot_item_lote = cil3.id
		LEFT JOIN dbo.cot_cliente_contacto ccc2 ON ccc2.id = cil3.id_cot_cliente_contacto
		LEFT JOIN dbo.cot_cliente cclp ON cclp.id = ccc2.id_cot_cliente AND cclp.id_emp = @emp	

	--SELECT FINAL
	SELECT	 FECHA_FACTURA = CAST(td.fecha AS date)
	        ,BARCODE = ISNULL(cvbo.campo_1, '')
			,TALLER = ISNULL(tb.descripcion,'')
			,ASESOR = ISNULL(uv.nombre, '')
			,NRO_ORDEN = ISNULL (cc.id, 0)
			,RAZON_SOCIAL = cli.razon_social
			,NOMBRES_OT = ISNULL(cn.nom1 + ' ' + cn.nom2, cli.razon_social)
			,APELLIDOS_OT = ISNULL(cn.ape1 + ' ' + cn.ape2, '')
			,CEDULA_RUC_OT = cli.nit
			,TIPO_TERCERO = CASE 
		   						WHEN cli.tipo_identificacion = 'O' THEN 'GOBIERNO'
		                    	WHEN cli.tipo_identificacion = 'N' THEN 'CORPORATIVO'
								ELSE 'RETAIL' END
			,GENERO = CASE
		   				WHEN clc.sexo = 1 THEN 'Masculino'
                       	WHEN clc.sexo = 2 THEN 'Femenino'
                       	ELSE ''
					END
			,FECHA_NACIMIENTO = CASE 
									WHEN cn.ape1 + cn.ape2 IS NULL THEN 'No aplica'
									ELSE IIF(ISNULL(clc.mes_dia_cumple, '0') <> '0' AND ISNULL(clc.ano_cumple,'0')<>'0' ,CONCAT(clc.ano_cumple,'-', CASE	WHEN LEN(clc.mes_dia_cumple) = 3 THEN CONCAT('0',LEFT(clc.mes_dia_cumple,1))
														ELSE LEFT(clc.mes_dia_cumple,2)
												END,'-',RIGHT(clc.mes_dia_cumple,2)),'No aplica')
								END
			,CONVENCIONAL = cli.tel_1
			,CELULAR = CASE 
							WHEN LEN (cli.tel_2) = 10 THEN cli.tel_2
							WHEN LEN (cli.tel_1) = 10 THEN cli.tel_1
							ELSE ''
						END
			,CIUDAD = ISNULL(pc.descripcion, '')
			,PROVINCIA = ISNULL(REPLACE(pd.descripcion, '.', ''), '')
			,PAIS = ISNULL(p.descripcion, '')
			,DIRECCION = cli.direccion
			,MAIL = clc.email
			,PLACA = vehi.placa
			,SERIE = vehi.vin
			,LONGITUD = vehi.longitud
			,SEGMENTO = vehi.segmento
			,CLASE_MARCA = vehi.clase_marca
			,MODELO = vehi.modelo
			,FAMILIA = vehi.familia
			,KILOMETRAJE = vehi.kilometraje
			,COLISION = tri.colision
			,MANTENIMIENTO = tri.mantenimiento
			,ACCESORIOS = tri.accesorios
			,GARANTIA = tri.garantia
			,MECANICA = tri.mecanica
			,FECHA_ENTRADA_VH = ISNULL (cc.fecha, '')
			--,FECHA_SALIDA_VH = ISNULL (cc.fecha_cambio_status_final, '')
			,FECHA_SALIDA_VH = ISNULL(te.fecha_modif,te.fecha)
			,NETO_REP = CASE 
							WHEN cg.descripcion + ' ' + cgs.descripcion LIKE '%REPUESTOS%' OR 
								cg.descripcion + ' ' + cgs.descripcion LIKE '%ACCESORIOS%'
							THEN (ABS (td.precio_cotizado) 
													* ABS (CASE WHEN td.cantidad_und = 0 THEN 1 ELSE td.cantidad_und END)) 
													* CASE WHEN td.sw = 1 THEN 1 ELSE -1 END
							ELSE 0
						END
			,NETO_MO = CASE 
							WHEN cg.descripcion + ' ' + cgs.descripcion LIKE '%TALLER%' AND
								cg.id NOT IN (1337) THEN (ABS (td.precio_cotizado) 
													* ABS (CASE WHEN td.cantidad_und = 0 THEN 1 ELSE td.cantidad_und END)) 
													* CASE WHEN td.sw = 1 THEN 1 ELSE -1 END
							ELSE 0
						END
			,NETO_TOT_REP = CASE 
								WHEN ci1.codigo LIKE '%TOT%REP%' AND cg.id IN (1337) THEN ISNULL (td.cantidad_und * td.precio_cotizado, 0)
								ELSE 0
							END
			,NETO_TOT_MO = CASE 
								WHEN ci1.codigo LIKE '%TOT%MDO%' AND cg.id IN (1337) THEN ISNULL (td.cantidad_und * td.precio_cotizado, 0)
								ELSE 0
							END
			,FORMA_PAGO = ISNULL (fp.descripcion, '')
			,TIPO_CLIENTE = ccp.descripcion
			,FLOTA = ISNULL (tft.EstaEnFlota, 'N')
			,CLASIFICACION_FLOTA = ISNULL (tft.ClaseCliente, '')
			,CEDULA_VENDEDOR = uv.cedula_nit 
			,ORDENES_INTERNAS = CASE
                                     WHEN vf.tal_ope IN ( 'C', 'G' ) THEN 'EXTERNA'
                                     ELSE 'INTERNA'
                                 END
			,TIPO = ct.descripcion
			,NUMERO = cc.numero_cotizacion
			,NUMERO_OT_ANULADA = devo.ot
			,FACTURADO_A = clfa.razon_social
			,FECHA_DEVOLUCION = devo.fecha
			,OT_ANTERIOR = cc.id_cot_cotizacion_ant
			,PROPIETARIO = vehi.propietario
			,RAZON_INGRESO = ISNULL (tri.razon, '')
			,GRUPO_INGRESO = tri.grupo
			,ID_MOD_AÑO = vehi.id_modelo
			,ID_FAC = td.id
			,vehi.vin
			,TIPO_SERVICIO=
				CASE
					   when b.id_usuario_jefe is not null then 'VENTAS TALLER '  + isnull(CASE 
																				 WHEN  td.facturar_a in ('C','O') then 'CLIENTE'
																   				 WHEN  td.facturar_a in ('G') then 'GARANTÍA'
																				 WHEN  td.facturar_a NOT IN ('C','G') then 'INTERNO'
																				 ELSE ''
																			   END,'MECANICA')	
																			   +  ' ' +
																			  ISNULL( case 
																					when  td.tipo_operacion in ('L','P') THEN  'COLISIÓN'
																					when  td.tipo_operacion in ('0','M') THEN  'MECÁNICA'
																					when  td.tipo_operacion in ('I') THEN  'MECÁNICA'
																					when  td.tipo_operacion in ('O') THEN  'MECÁNICA'


																				end ,'MECANICA')

				END
		--Tipo_orden=ISNULL(vcv3.campo_1,'')
		,Trabajos_Realizados=dbo.Trabajos_realizados(cc.id)
	INTO #Resultado
	FROM #Docs td
	join cot_bodega b on b.id = td.id_cot_bodega
	JOIN @LINEA line ON line.id_item = td.id_cot_item 
	JOIN dbo.cot_tipo ct ON ct.id = td.id_cot_tipo
	JOIN @Bodega tb ON tb.id = td.id_cot_bodega
	LEFT JOIN	dbo.v_campos_varios cvbo    ON	tb.id = cvbo.id_cot_bodega
		left JOIN dbo.cot_cliente clfa ON clfa.id = td.id_cot_cliente
	LEFT JOIN dbo.usuario uv ON uv.id = td.id_usuario_ven
	JOIN dbo.cot_item ci1 ON ci1.id = td.id_cot_item
	   		 JOIN dbo.cot_grupo_sub cgs ON cgs.id = ci1.id_cot_grupo_sub
			 JOIN dbo.cot_grupo cg ON cg.id = cgs.id_cot_grupo
	LEFT JOIN @Devoluciones devo ON td.id = devo.id_factura
	LEFT JOIN dbo.cot_cotizacion cc ON cc.id = td.id_cot_cotizacion_sig
		 --left JOIN #Clientes clot ON clot.id = cc.id_cot_cliente
	left JOIN dbo.cot_cliente cli ON cli.id = cc.id_cot_cliente
	LEFT JOIN dbo.cot_cliente_perfil ccp ON ccp.id = cli.id_cot_cliente_perfil
		 JOIN dbo.cot_cliente_pais pc ON pc.id = cli.id_cot_cliente_pais
		 JOIN dbo.cot_cliente_pais pd ON pd.id = pc.id_cot_cliente_pais
	     JOIN dbo.cot_cliente_pais p ON p.id = pd.id_cot_cliente_pais
	     JOIN dbo.cot_cliente_contacto clc ON clc.id = cli.id_cot_cliente_contacto
	LEFT JOIN dbo.cot_cliente_nom cn ON cn.id_cot_cliente = cli.id

		left JOIN dbo.v_tal_ya_fue_facturado vf ON td.id = vf.id_cot_cotizacion
	LEFT JOIN dbo.tra_cargue_enc te on te.id_cot_cotizacion = cc.id AND te.anulado IS NULL --ADMG 740: Se agrega AND te.anulado IS NULL
	--LEFT JOIN dbo.v_campos_varios vcv3 ON vcv3.id_cot_cotizacion = cc.id AND vcv3.campo_1 IS NOT NULL
	LEFT JOIN #Vehiculos vehi ON vehi.id = td.id_cot_item_vhtal AND vehi.id_ot = cc.id
	LEFT JOIN #FlotasTaller tft ON tft.id = td.id AND tft.id_cot_item_vhtal = td.id_cot_item_vhtal
	LEFT JOIN #razon_Ingreso tri ON tri.id = cc.id_tal_motivo_ingreso
	LEFT JOIN dbo.cot_forma_pago fp ON fp.id = td.id_forma_pago
	--WHERE ct.sw = 1			
	WHERE line.linea <> 'VEHICULOS'

	-- RESULTADO
	-- EXEC [dbo].[GetPerfilClientesGM_borrador] '2021-10-01','2021-10-01'

	SELECT	BARCODE
			,TALLER
			,ASESOR
			,NRO_ORDEN
			,NOMBRES_OT
			,APELLIDOS_OT
			,CEDULA_RUC_OT
			,GENERO
			,FECHA_NACIMIENTO
			,CELULAR
			,CONVENCIONAL 
			,CIUDAD
			,PROVINCIA
			,PAIS
			,DIRECCION
			,MAIL
			,PLACA
			,VIN = vin
			,SEGMENTO
			,MODELO
			,KILOMETRAJE
			,TIPO_SERVICIO
			,FECHA_ENTRADA_VH
			,FECHA_SALIDA_VH
			,NETO_REP = SUM (NETO_REP)
			,NETO_MO = SUM (NETO_MO)
			,FORMA_PAGO 
			,[NETO_TOT_REP+NETO_TOT_MO] = SUM (NETO_TOT_REP) + SUM (NETO_TOT_MO)
			--,PROPIETARIO
			,TIPO_CLIENTE
			,FLOTA
			,CEDULA_VENDEDOR
			,TIPO_ORDEN = ORDENES_INTERNAS  --Requerido para este reporte por GM
			,FAMILIA
			,CONCESIONARIO = 'CORPORACIÓN PROAUTO'
			,RAZON_INGRESO
			,FACTURADO_A 
			,TRABAJOS_REALIZADOS
			,RAZON_SOCIAL
			,FECHA_FACTURA
			--,TIPO_TERCERO
			--,SERIE
			--,LONGITUD
			--,CLASE_MARCA
			--,COLISION = SUM(colision)
			--,MANTENIMIENTO = SUM(mantenimiento)
			--,ACCESORIOS = SUM(accesorios)
			--,GARANTIA = SUM(garantia)
			--,MECANICA = SUM(mecanica)
			
			--,CLASIFICACION_FLOTA
			
			--,TIPO_DOCUMENTO = TIPO
			--,NUMERO 
			--,NUMERO_OT_ANULADA = MAX(NUMERO_OT_ANULADA)
			
			--,FECHA_DEVOLUCION = MAX(FECHA_DEVOLUCION)
			--,OT_ANTERIOR
			--,RAZON_INGRESO
			--,GRUPO_INGRESO
			--,ID_MOD_AÑO
			--,ID_FAC
	FROM #Resultado r
	--WHERE r.CEDULA_RUC_OT = '1103349187'
	GROUP BY FECHA_FACTURA
	        ,BARCODE
			,TALLER
			,ASESOR
			,NRO_ORDEN
			,RAZON_SOCIAL
			,NOMBRES_OT
			,APELLIDOS_OT
			,CEDULA_RUC_OT
			,GENERO
			,FECHA_NACIMIENTO
			,CELULAR
			,CONVENCIONAL 
			,CIUDAD
			,PROVINCIA
			,PAIS
			,DIRECCION
			,MAIL
			,PLACA
			,vin
			,SEGMENTO
			,MODELO
			,KILOMETRAJE
			,TIPO_SERVICIO
			,FECHA_ENTRADA_VH
			,FECHA_SALIDA_VH
			,FORMA_PAGO 
			,PROPIETARIO
			,TIPO_CLIENTE
			,FLOTA
			,CEDULA_VENDEDOR
			,ORDENES_INTERNAS
			,FAMILIA
			,FACTURADO_A
			,RAZON_INGRESO
			,TRABAJOS_REALIZADOS
			