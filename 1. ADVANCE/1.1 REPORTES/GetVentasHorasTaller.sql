USE [dms_smd3]
GO

/****** Object:  StoredProcedure [dbo].[GetVentasHorasTaller]    Script Date: 16/3/2022 16:14:13 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- ==============================================================================================================================================================================
-- Author:		<Juan Carlos Martos>
-- Create date: <0000-00-00>
-- Modulo:		<Reporteria>
-- Description:	<Procedimiento para obtener informacion resumida de las ventas tanto repuestos como taller y tot,  (Reporte 100021 Advance)
-- Historial de Cambios:
-- 27/ago/2021    Se agrega un procedimiento para obtener las ordenes de garantias y consolidados
-- 06/ago/2021    Se reversa a la version de la fecha 02/jul/2021 (JCH - APF)
-- 13/ago/2021    Se regula el cálculo para el Subtotal de la Factura (MQR - JCH) 
-- 23/ago/2021    Se modifican los nombres de los siguientes campos: Marca por MarcaVH_original
--                                                                  tipo_orden por clase_operacion
--                                                                  canal por canal_cita (JCHB)
-- 23/ago/2021  Se agrega el campo Marca_VH el cual contiene las marcas de Vehiculos que se manejan dentro del negocio como son: (Chevrolet, GAC, VolksWagen y Multimarca) 
--              Se aplica para las Linea de Negocio TALLER y TOT (JCHB) 
-- 27/ago/2021  Se modifica el campo Marca_VH para que se calcule para lo Items que tienen una Orden de Trabajo. (JCHB)
-- 07/sep/2021	Se modifica el JOIN con la tabla #citas2 con la columna del id_cot_bodega a fin de evitar duplicados en las citas. (APF)
-- 21/sep/2021	Se agrega la línea de varios
-- 27/sep/2021	Se agrega un join con la tabla ot_consolidadas_nc a fin de obtener la ot original de las devoluciones
--					para ello se modifica la tabla #Docs con la validacion hacia las nc y de igual forma la tabla detdatos
-- 05/oct/2021	Se agrega un case para obtener informacion en base a la factura de aquellas ot que no registan id
-- 25/nov/2021	Se iguala el script al reporte 100017
-- 27/ene/2022	Se corrige script para que obtenga información de acuerdo al parametro bodega ingresado desde Advance (JCB)
-- 16/mar/2022	Se ajusta el largo del campo notas (JCB)
-- ===============================================================================================================================================================================
-- Exec GetVentasHorasTaller_Borrador '605','1183','20220101 00:00:00','20220131 23:59:59','0'  
alter PROCEDURE [dbo].[GetVentasHorasTaller] 
(
	@emp INT,
	@Bod VARCHAR(MAX),
	@fecIni DATE,
	@fecFin DATE,
	@cli INT=0
)
AS

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE @Devoluciones AS TABLE (
		id INT,
		factura VARCHAR(20),
		id_factura INT,
		concepto VARCHAR(200)
	)

	--- REGLAS DE NEGOCIO 186 PARA OBTENER LAS BODEGAS TEMPORAL O PROD. EN PROCESO
	DECLARE @bodegas_reglas_negocio as table
	(
		id_emp int,
        id_regla int,
	    id_cot_bodega int,
		descripcion varchar(100),
		id_cot_bodega_rn int,
	    descripcion_rn varchar(100)
	)
	insert @bodegas_reglas_negocio
	select r.id_emp,
           r.id_reglas,
	       id_cot_bodega = cast(substring(r.llave,9,4) as INT),
		   b_tal.descripcion,
	       r.respuesta,
		   b_pp.descripcion
	from reglas_emp r
	join cot_bodega b_tal on cast(substring(r.llave,9,4) as INT) = b_tal.id
	join cot_bodega b_pp on b_pp.id = r.respuesta
	where r.id_emp = @emp
	and r.id_reglas = 186
	and r.llave like '%bod_temp%'


	--- REGLAS DE NEGOCIO 114 PARA OBTENER LAS BODEGAS TEMPORAL O PROD. EN PROCESO
	insert @bodegas_reglas_negocio
	select r.id_emp,
           r.id_reglas,
	       id_cot_bodega = cast(substring(r.llave,4,4) as INT),
		   b_rep.descripcion,
	       r.respuesta,
		   b_consig.descripcion
	from reglas_emp r
	join cot_bodega b_rep on cast(substring(r.llave,4,4) as INT) = b_rep.id
	join cot_bodega b_consig on b_consig.id = r.respuesta
	where r.id_emp = @emp
	and r.id_reglas = 114
	and r.respuesta > 1

	-- RAZONES DE INGRESO
	SELECT * 
	INTO #razon_ingreso
	FROM dbo.tal_motivo_ingreso
	WHERE id_emp=@emp 

	CREATE TABLE #docco (
		id INT,
		id_cot_tipo INT,
		codcentro VARCHAR(100),
		cuota_nro int
	)

	CREATE TABLE #RtosPLista (
		id INT,
		id_cot_cotizacion_item INT,
		id_cot_item INT, 
		id_cot_item_lote INT,
		Fac_Preciolista DECIMAL (10,2),
		Fac_Preciocotizado DECIMAL (10,2),
		tras_Preciolista DECIMAL (10,2),
		tras_Preciocotizado DECIMAL (10,2),
		id2 INT

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

	---- TEMPORAL PARA ALMACENAR LA LINEA DE NEGOCIO DE ACUERDO A GRUPO Y SUBGRUPO
	DECLARE @LINEA AS TABLE (
		id_item INT,
		linea VARCHAR(50)
	)

	------------------FILTROS INICIALES
	DECLARE @BodegasSplit AS TABLE 
	(
		id INT,
		descripcion VARCHAR(200),
		ecu_establecimiento VARCHAR(6)
	)

	DECLARE @Bodega AS TABLE 
	(
		id INT,
		descripcion VARCHAR(200),
		ecu_establecimiento VARCHAR(6)
	)

	IF @Bod = '0'
	begin
		INSERT @Bodega
		(
			id,
			descripcion,
			ecu_establecimiento
		)
		SELECT id,
			   descripcion,
			   ecu_establecimiento
		FROM dbo.cot_bodega
		where id_emp=@emp
	end
	ELSE
	BEGIN
	    
		INSERT @BodegasSplit
		(
			id,
			descripcion,
			ecu_establecimiento
		)
		SELECT id_cot_bodega = CAST(f.val AS INT),
				c.descripcion,
				c.ecu_establecimiento
		FROM dbo.fnSplit(@Bod, ',') f
			JOIN dbo.cot_bodega c
				ON c.id = CAST(f.val AS INT)

		INSERT @Bodega
		(
			id,
			descripcion,
			ecu_establecimiento
		)
		select distinct x.id_cot_bodega,
			   x.descripcion,
			   x.ecu_establecimiento
		from
		(
			select  id_cot_bodega = rn.id_cot_bodega_rn,
					descripcion = rn.descripcion_rn,
					bod.ecu_establecimiento
			from @BodegasSplit b
			join @bodegas_reglas_negocio rn on (b.id = rn.id_cot_bodega)
			join cot_bodega bod on bod.id = rn.id_cot_bodega_rn
			union all
			select  s.id,
					s.descripcion,
					s.ecu_establecimiento
			from @BodegasSplit s
		)x


	END

	
	----NUEVO PROCESO DE GARANTIAS Y CONSOLIDADAS----------
	create table #OTs_CONSOLIDADAS_GARATIAS (
		id_factura int,
		IdOrden int
	)
	insert #OTs_CONSOLIDADAS_GARATIAS exec [dbo].[GetOrdenesFacturasTaller] @emp,0,@fecIni,@fecFin

	create table #OTs_CONSOLIDADAS_GARATIAS_NC (
		id_factura int,
		IdOrden int
	)
	insert #OTs_CONSOLIDADAS_GARATIAS_NC exec [dbo].[GetOrdenesNCTaller] @emp,0


	-----PRIMERA INSERCION EN DOCS --------------------------------------------------------
	INSERT #Docs (
		id,
		id_cot_tipo,
		id_cot_bodega,
		id_cot_cliente,
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
		sw,
		saldo,
		id_cot_pedido_item, 
		docref_tipo, 
		docref_numero,
		id_veh_hn_enc ,
		id_cot_cliente_contacto,
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
	SELECT
	       c.id,
		   c.id_cot_tipo,
		   id_cot_bodega = v.id_cot_bodega,
		   c.id_cot_cliente,
		   c.numero_cotizacion,
		   c.fecha,
		   notas = cast(c.notas as varchar(MAX)),
		   ci.id_cot_item,
		   ci.id_cot_item_lote,
		   cantidad_und= ci.cantidad_und*t.sw,
		   tiempo=case WHEN t.sw =-1 THEN 
							(select ci1.tiempo from cot_cotizacion_item ci1 where ci1.id=ci.id_cot_cotizacion_item_dev)*-1
							ELSE
						ci.tiempo
						END,
		   ci.precio_lista,
		   ci.precio_cotizado,
		   ci.costo_und,
		   ci.porcentaje_descuento,
		   ci.porcentaje_descuento2,
		   ci.porcentaje_iva,
		   b.descripcion,
		   c.id_com_orden_concep,
		   b.ecu_establecimiento,
		   c.id_usuario_vende,
		   c.id_cot_forma_pago,
		   t.sw,
		   saldo = c.total_total - ISNULL(s.valor_aplicado, 0),
		   ci.id_cot_pedido_item, 
		   c.docref_tipo, 
		   c.docref_numero,
		   c.id_veh_hn_enc,
		   c.id_cot_cliente_contacto ,
		   id_cot_cotizacion_item=ci.id,
		   c.total_total,
		   ci.facturar_a,
		   ci.tipo_operacion	,
		   c.id_cot_item_lote ,
		   c.id_cot_cotizacion_sig,
		   ci.id_operario,
		   valor_hora=case WHEN t.sw =-1 THEN 
							(select ci1.precio_cotizado from cot_cotizacion_item ci1 where ci1.id=ci.id_cot_cotizacion_item_dev)*-1
							ELSE
						ci.valor_hora
						END,
		   ci.renglon,
		   ci.notas,
		   c.id_cot_cotizacion_sig,
		   tipo_orden='F',
		   id_item=ci.id_componenteprincipalEst
	FROM dbo.cot_cotizacion c 
	JOIN dbo.cot_tipo t ON (t.id = c.id_cot_tipo) 
    JOIN dbo.cot_cotizacion_item ci ON (ci.id_cot_cotizacion = c.id)
	JOIN v_cot_cotizacion_item_todos v on v.id = ci.id
	JOIN @Bodega b ON v.id_cot_bodega = b.id  
    LEFT JOIN dbo.v_cot_factura_saldo s ON (s.id_cot_cotizacion = c.id)
	LEFT JOIN dbo.v_cot_cotizacion_factura_dev fdev ON (t.sw = -1 AND fdev.id_cot_cotizacion = c.id)
	where c.id_emp = @emp
	and  CAST(c.fecha AS DATE) BETWEEN @fecIni AND @fecFin
	AND t.sw IN ( 1, -1 ) 
    and isnull(c.anulada,0) <> 4 	
	and t.es_remision is  null 
    and t.es_traslado is   null 
    AND (t.sw = 1 AND (c.id NOT IN (select g.id_factura from #OTs_CONSOLIDADAS_GARATIAS g)) 
		OR t.sw = -1 AND (ISNULL (fdev.id_cot_cotizacion_factura, 0) NOT IN (select g.id_factura from #OTs_CONSOLIDADAS_GARATIAS_NC g)))
    and (@cli=0 or c.id_cot_cliente=@cli)
    AND (ISNULL (ci.facturar_a, 'NULL') <> 'S') -- Excluimos los ítems que corresponden a insumos

		
	--------------------INSERTAMOS EN DOCS LA INFROMACION DE GARANTIAS Y CONSOLIDADAS------------------------
	--- PRIMERO BUSCAMOS LA ORDEN ORIGINAL Y LA INSERTAMOS EN UNA TABLA TEMPORAL
	SELECT 	id_factura=ci.id_cot_cotizacion,
			t.sw, 
			ci.id,
			c.id_cot_cotizacion_sig,
			ci.id_cot_item,
			ci.cantidad,
			ci.facturar_a,
			ci.precio_cotizado,
			ci.tipo_operacion,
			ci.id_componenteprincipalest
	into #detdatos 
	FROM dbo.cot_cotizacion c
			 JOIN dbo.cot_tipo t ON (t.id = c.id_cot_tipo) 
		LEFT JOIN dbo.v_cot_cotizacion_factura_dev fdev ON fdev.id_cot_cotizacion = CASE WHEN t.sw = -1 THEN c.id ELSE NULL END
			 JOIN dbo.cot_cotizacion_item ci ON ci.id_cot_cotizacion = CASE WHEN t.sw = -1 THEN fdev.id_cot_cotizacion_factura ELSE c.id END
	WHERE (t.sw = 1 AND (c.id IN (select g.id_factura from #OTs_CONSOLIDADAS_GARATIAS g)) 
		OR t.sw = -1 AND (fdev.id_cot_cotizacion_factura IN (select g.id_factura from #OTs_CONSOLIDADAS_GARATIAS_NC g)));

	----GMAH PERSONALIZADO
	CREATE TABLE #detad (
	id_factura int, 
	id_det_fac int,
	id_det_orden int,
	id_otfinal int, 
	id_otori int,
	id_tal_garantia_clase int, 
	ClaseGarantia  varchar(150),
	facturar_a varchar(5)
	)

	INSERT #detad (
		id_factura, 
		id_det_fac,
		id_det_orden,
		id_otfinal, 
		id_otori ,
		id_tal_garantia_clase, 
		ClaseGarantia,
		facturar_a
	)
	SELECT	DISTINCT
		d.id_factura,
		id_det_fac=d.id,
		id_det_orden=c.id,
		id_otfinal=d.id_cot_cotizacion_sig,
		ot_id_ordeÑn=isnull(c3.idv,c2.id),
		ccim.id_tal_garantia_clase,
	clasegarantia=ISNULL(tgc.descripcion,''),
	d.facturar_a
	FROM dbo.cot_cotizacion ct
	JOIN dbo.cot_cotizacion_item c ON c.id_cot_cotizacion = ct.id
	LEFT JOIN dbo.cot_cotizacion_item_mas ccim  ON c.id = ccim.id_cot_cotizacion_item
	LEFT JOIN dbo.cot_tipo tt ON tt.id = c.id_cot_tipo_tran
	LEFT JOIN dbo.v_cot_cotizacion_item cci ON cci.id = c.id_cot_cotizacion_item_dev
	LEFT JOIN dbo.v_cot_cotizacion_item_dev2 dev ON dev.id_cot_cotizacion_item = c.id
	LEFT JOIN dbo.cot_cotizacion c3 ON c3.id = c.id_cot_cotizacion
	LEFT JOIN cot_cotizacion c2 ON c2.id = ISNULL(c3.id_cot_cotizacion_sig,c.id_cot_cotizacion)
	LEFT JOIN dbo.cot_tipo tjd 	ON tjd.id = c3.id_cot_tipo
	LEFT JOIN dbo.cot_cotizacion cc ON cc.id = ct.id_cot_cotizacion_sig
	LEFT JOIN dbo.tal_garantia_clase tgc ON tgc.id = ccim.id_tal_garantia_clase
	JOIN #detdatos d ON (ct.id = d.id_cot_cotizacion_sig 
		                    OR ct.id_cot_cotizacion_sig = d.id_cot_cotizacion_sig 
							OR c.id_prd_orden_estruc = d.id_cot_cotizacion_sig 
							OR c.id_prd_orden_estructurapt = d.id_cot_cotizacion_sig) 		 
	WHERE ISNULL(tjd.sw,0) <> 1 
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
		id_veh_hn_enc, 
		id_cot_cotizacion_item,
		total_total,
		facturar_a,
		tipo_operacion, 
		id_cot_item_vhtal,
		id_cot_cotizacion_sig,
		id_operario ,
		valor_hora,
		renglon,
		notas_item,
		ot_final,
		tipo_orden,
		id_item
	)

	SELECT --distinct 
		c.id_cot_cotizacion,
		t.id,
		b.id,
		cc.id_cot_cliente,
		cc.id_cot_cliente_contacto,
		cc.numero_cotizacion,
		fecha=CAST (cc.fecha AS DATE), 
		notas = cast(cc.notas as varchar(max)),
		c.id_cot_item,
		id_cot_item_lote=0, --revisar este campo
		cantidad_und=c.cantidad_und * t.sw,
		 tiempo=case WHEN t.sw =-1 THEN 
							(select ci1.tiempo from cot_cotizacion_item ci1 where ci1.id=c.id_cot_cotizacion_item_dev)*-1
							ELSE
						c.tiempo
						END,
		[Precio Lista] =c.precio_lista ,
		[Precio Cotizado] = c.precio_cotizado,
		[Costo Und] = NULLIF(c.costo_und,0),
		[% dcto] =  c.porcentaje_descuento ,
		[% dcto 2] = c.porcentaje_descuento2, --jdms 739
		[%Iva] = c.porcentaje_iva,
		[Bodega] = b.descripcion,
		cc.id_com_orden_concep,
		b.ecu_establecimiento,
		cco.id_usuario_vende,
		cc.id_cot_forma_pago,
		cc.docref_numero,
		cc.docref_tipo, 
		t.sw,
		saldo = cc.total_total - ISNULL(sal.valor_aplicado, 0),
		c.id_cot_pedido_item,
		cc.id_veh_hn_enc,
		id_cot_cotizacion_item=c.id,
		cc.total_total,
		c.facturar_a,
		cci2.tipo_operacion, -- MEP
		cco.id_cot_item_lote ,
		adi.id_otori, --GMAH PERSONALIZADO
		c.id_operario,
		valor_hora=case WHEN t.sw =-1 THEN 
							(select ci1.precio_cotizado from cot_cotizacion_item ci1 where ci1.id=c.id_cot_cotizacion_item_dev)*-1
							ELSE
						c.valor_hora
						END,
		c.renglon,
		c.notas,
		adi.id_otfinal,
		adi.facturar_a,
		c.id_componenteprincipalEst
	FROM dbo.v_cot_cotizacion_item_todos_mep c
	LEFT JOIN cot_cotizacion cc ON cc.id=c.id_cot_cotizacion and cc.id_emp=605 and isnull(cc.anulada,0) <>4 	 and  CAST(cc.fecha AS DATE)  BETWEEN @fecIni AND @fecFin  --and  CAST(cc.fecha AS DATE)  BETWEEN @fecIni AND @fecFin
	LEFT JOIN dbo.v_cot_factura_saldo sal ON sal.id_cot_cotizacion = cc.id
	LEFT JOIN dbo.cot_tipo t ON t.id = cc.id_cot_tipo
	LEFT JOIN dbo.v_cot_cotizacion_item cci ON cci.id = c.id_cot_cotizacion_item_dev
	LEFT JOIN dbo.v_cot_cotizacion_item cci2 ON cci2.id = c.id --MEP
	LEFT JOIN dbo.v_cot_cotizacion_factura_dev fdev ON fdev.id_cot_cotizacion = CASE WHEN t.sw = -1 THEN c.id_cot_cotizacion ELSE NULL END
	LEFT JOIN #detad adi ON adi.id_det_fac= CASE WHEN t.sw = -1 THEN cci.id ELSE c.id END --GMAH PERSONALIZADO
	LEFT JOIN cot_cotizacion cco ON cco.id=adi.id_otori and cco.id_emp=@emp
	LEFT JOIN @Bodega b ON b.id = CASE WHEN cco.id_cot_bodega IS NULL THEN cc.id_cot_bodega ELSE cco.id_cot_bodega END
	WHERE (t.sw = 1 AND (c.id_cot_cotizacion IN (select g.id_factura from #OTs_CONSOLIDADAS_GARATIAS g)) 
		OR t.sw = -1 AND (fdev.id_cot_cotizacion_factura IN (select g.id_factura from #OTs_CONSOLIDADAS_GARATIAS_NC g)))
	AND (c.id_cot_cotizacion_item IS NULL)
	and t.sw IN ( 1, -1 ) 
	and t.es_remision is null 
    and t.es_traslado is null 
    and (@cli=0 or cc.id_cot_cliente=@cli)
	AND (ISNULL (c.facturar_a, 'NULL') <> 'S') -- Excluimos los ítems que corresponden a insumos

	--- validacion notas credito 
	INSERT @Devoluciones
	(
		id,
		factura,
		id_factura,
		concepto
	)
	SELECT DISTINCT 
	d.id,
		   Factura = CAST(ISNULL(bd.ecu_establecimiento, '') AS VARCHAR(4))
					 + CAST(ISNULL(t3.ecu_emision, '') AS VARCHAR(4)) COLLATE Modern_Spanish_CI_AI + ''
					 + RIGHT('000000000' + CAST(cc3.numero_cotizacion AS VARCHAR(100)), 9),
			id_factura = fdev.id_cot_cotizacion_factura,
			concepto = ISNULL (conc.descripcion, '')
	FROM #Docs d
	JOIN dbo.v_cot_cotizacion_factura_dev fdev ON (d.sw = -1 AND fdev.id_cot_cotizacion = d.id)
	JOIN dbo.cot_cotizacion cc3 ON cc3.id = fdev.id_cot_cotizacion_factura
	JOIN dbo.cot_tipo t3 ON t3.id = cc3.id_cot_tipo
	JOIN @Bodega bd ON bd.id = cc3.id_cot_bodega
	LEFT JOIN com_orden_concep conc ON conc.id = cc3.id_com_orden_concep

	-----PARA SACAR EL CANAL (DE ACUERDO AL CONCEPTO DE LA VENTA EN REPUESTOS)
	INSERT #docco
	(
		id,
		id_cot_tipo,
		codcentro,
		cuota_nro
	)
	SELECT DISTINCT
		   aa.Id,
		   aa.id_cot_tipo,
		   co.descripcion,
		   cuota_nro=0
	FROM #Docs aa
		JOIN dbo.con_mov_enc cme
			ON cme.id_origen = aa.Id
			   AND cme.id_cot_tipo = aa.id_cot_tipo
			   AND cme.numero = aa.numero_cotizacion
		JOIN dbo.con_mov cm
			ON cm.id_con_mov_enc = cme.id
		JOIN dbo.con_cco co
			ON co.id = cm.id_con_cco
	WHERE cm.id =
	(
		SELECT MIN(cm2.id)
		FROM dbo.con_mov cm2
		WHERE cm.id_con_mov_enc = cm2.id_con_mov_enc
		AND cm2.id_con_cco IS NOT NULL
	)

---------------------------------------------------------------------------------
	INSERT #RtosPLista
	(
		id,
		id_cot_cotizacion_item,
		id_cot_item , 
		id_cot_item_lote,
		Fac_Preciolista,
		Fac_Preciocotizado ,
		tras_Preciolista ,
		tras_Preciocotizado ,
		id2 
	)
	select
	d.id, 
	d.id_cot_cotizacion_item, 
	f.id_cot_item, 
	f.id_cot_item_lote,
	f.precio_lista,
	f.precio_cotizado,
	ottraslado.precio_lista,
	ottraslado.precio_cotizado,
	ottaller.id_cot_cotizacion 	  
	From  #docs d
	JOIN cot_cotizacion_item f 	on f.id_cot_cotizacion=d.id and f.id=d.id_cot_cotizacion_item
	join cot_cotizacion_item  ottaller 	on ottaller.id=f.id_componenteprincipalest
	join cot_cotizacion_item ottraslado 	on ottraslado.id=abs(ottaller.renglon)  

	INSERT #RtosPLista
	(
		id,
		id_cot_cotizacion_item,
		id_cot_item , 
		id_cot_item_lote,
		Fac_Preciolista,
		Fac_Preciocotizado ,
		tras_Preciolista ,
		tras_Preciocotizado ,
		id2
	)
	select
	    d.id, 
	    d.id_cot_cotizacion_item, 
	    f.id_cot_item, 
	    f.id_cot_item_lote,
	    f.precio_lista,
	    f.precio_cotizado,
	    ottraslado.precio_lista,
	    ottraslado.precio_cotizado,
	    ottaller.id_cot_cotizacion 	  
	    From  #docs d
	    JOIN cot_cotizacion_item f 	on f.id_cot_cotizacion=d.id and f.id=d.id_cot_cotizacion_item
	    JOIN cot_cotizacion_item cf on cf.id=f.id_cot_cotizacion_item_dev
	    join cot_cotizacion_item  ottaller 	on ottaller.id=cf.id_componenteprincipalest
	    join cot_cotizacion_item ottraslado 	on ottraslado.id=abs(ottaller.renglon) 
	    where d.sw=-1 

	-----------FLOTAS TALLER----
	select DISTINCT 
	d.id,
	d.id_cot_tipo,
	d.id_cot_item_vhtal,
	tf.codigo, 
	tf.descripcion,
	tf.fechaini,
	tf.fechafin,
	id_tal_flota=tf.id,
	ClaseCliente=tc.descripcion,
	EstaEnFlota=case when d.fecha between tf.fechaini and tf.fechafin then 'S' else 'N' end
	into #flotasTaller					   
	from  #docs d
	join tal_flota_veh fv on fv.id_cot_item_lote=d.id_cot_item_vhtal and (fv.inactivo <> 1 OR fv.inactivo IS NULL) -- SE AGREGA LA CONDICION IS NULL PARA VERIFICAR QUE EL VEHICULO ESTE ACTIVO EN LA FLOTA
	join tal_flota tf on tf.id=fv.id_tal_flota
	join tal_flota_clase	 tc on tc.id=tf.id_tal_flota_clase

	-----AGENDAMIENTO DE CITAS
	select DISTINCT id,id_cot_cotizacion,id_tal_camp_enc
	INTO #citas
	from tal_citas

	SELECT id_id,min(id_usuario) id_usuario 
	INTO #audi
	FROM cot_auditoria
	where  id_tabla=139 and que like '%fecha inicia%' and id_emp=@emp
	GROUP BY ID_ID
	order by id_id

	SELECT c.Id, 
		  [Fecha Cita] = c.fecha_cita,
		   fecha_creacion_cita=c.fecha_creacion,
		   id_cot_bodega = b.id,
		   bodega=b.descripcion,
		   razon_cita=c.notas,
		   Mantenimiento = p.descripcion,
		   Campaña = en.titulo,
		   nit_usuario_cita=us.cedula_nit,
		   usuario_cita=us.nombre,
		   tecnico=u.nombre,
		   Tipo = ti.descripcion,
		   Canal = ca.descripcion,
		   OT = ct.id,
		   Ubicación = ub.descripcion,
	       [Fecha Entrega] = te.fecha,
		   IdVh = l.id,
		   Id_Estado = CAST(CASE
								WHEN c.id_cot_item_lote IS NULL THEN
									NULL
								WHEN te.id IS NOT NULL THEN
									8   --Entregada
								WHEN ISNULL(ct.anulada, 0) = 1
									 AND tip.sw = 46 THEN
									7   --Facturada
								WHEN ISNULL(ct.anulada, 0) = 2 THEN
									6   --Cerrada
								WHEN e.cuantas > 0
									 AND e.terminada >= e.cuantas THEN
									5   --Terminada
								WHEN e.cuantas > 0
									 AND e.pausa >= e.cuantas THEN
									4   --Pausada
								WHEN e.proceso > 0 THEN
									3   --Proceso
								WHEN c.id_cot_cotizacion IS NOT NULL THEN
									2   --En OT
								WHEN c.estado = 101 THEN
									101 --Llegó
								WHEN c.estado = 102 THEN
									102 --No cumplida
								WHEN c.id_cot_cotizacion IS NULL
									 AND GETDATE() <= c.fecha_cita THEN
									1   --Agendada
								WHEN c.id_cot_cotizacion IS NULL
									 AND GETDATE() > c.fecha_cita THEN
									100 --Atrasada
							END AS VARCHAR),
		Estado = CAST(CASE
								WHEN c.id_cot_item_lote IS NULL THEN
									NULL
								WHEN te.id IS NOT NULL THEN
									'Entregada'
								WHEN ISNULL(ct.anulada, 0) = 1
									 AND tip.sw = 46 THEN
									'Facturada'
								WHEN ISNULL(ct.anulada, 0) = 2 THEN
									'Cerrada'
								WHEN e.cuantas > 0
									 AND e.terminada >= e.cuantas THEN
									'Terminada'
								WHEN e.cuantas > 0
									 AND e.pausa >= e.cuantas THEN
									'Pausada'
								WHEN e.proceso > 0 THEN
									'Proceso'
								WHEN c.id_cot_cotizacion IS NOT NULL THEN
									'En OT'
								WHEN c.estado = 101 THEN
									'Llegó'
								WHEN c.estado = 102 THEN
									'No cumplida'
								WHEN c.id_cot_cotizacion IS NULL
									 AND GETDATE() <= c.fecha_cita THEN
									'Agendada'
								WHEN c.id_cot_cotizacion IS NULL
									 AND GETDATE() > c.fecha_cita THEN
									'Atrasada'
							END AS VARCHAR)
	INTO #citas2
	FROM #citas cc 
	JOIN dbo.tal_citas c ON c.id = cc.id
	JOIN dbo.cot_item_lote l ON l.id = c.id_cot_item_lote
	JOIN dbo.cot_cliente_contacto co ON co.id = l.id_cot_cliente_contacto
	JOIN dbo.cot_cliente cl ON cl.id = co.id_cot_cliente
	JOIN dbo.v_cot_item_descripcion d ON d.id = l.id_cot_item
	JOIN dbo.usuario u ON u.id = c.id_usuario
	JOIN @Bodega b ON b.id = c.id_cot_bodega
	LEFT JOIN dbo.tal_citas_canal ca ON ca.id = c.id_tal_citas_canal
	LEFT JOIN dbo.tal_citas_tipo ti ON ti.id = c.id_tal_citas_tipo
	LEFT JOIN dbo.tal_planes p ON p.id = c.id_tal_planes
	LEFT JOIN dbo.tal_camp_enc en ON en.id = cc.id_tal_camp_enc
	LEFT JOIN dbo.cot_cotizacion ct ON ct.id = c.id_cot_cotizacion
	LEFT JOIN dbo.cot_tipo tip ON tip.id = ct.id_cot_tipo
	  AND tip.sw IN ( 46 )
	LEFT JOIN dbo.v_tal_operaciones_estado e ON e.id_cot_cotizacion = ct.id
	LEFT JOIN dbo.cot_bodega_ubicacion ub ON ub.id = ct.id_cot_bodega_ubicacion
	LEFT JOIN dbo.tra_cargue_enc te ON te.id_cot_cotizacion = c.id_cot_cotizacion
	LEFT JOIN #audi au ON au.id_id=cc.id 
	LEFT JOIN dbo.usuario us ON us.id=au.id_usuario
	
	---- @LINEA - INSERTAMOS LA LINEA DE LOS ITEMS DEL GRUPO REPUESTOS, TALLER Y TOT
	
	INSERT @LINEA 
	SELECT 	id_item = item.id, 
			linea = CASE WHEN grup.id = 1337 THEN 'TOT' ELSE grup.descripcion END
	FROM #Docs docs 
		JOIN dbo.cot_item item ON item.id = docs.id_cot_item
		JOIN dbo.cot_grupo_sub gsub ON gsub.id = item.id_cot_grupo_sub
		JOIN dbo.cot_grupo grup ON grup.id = gsub.id_cot_grupo
	WHERE grup.id IN (1321, 1322, 1323, 1326, 1337)
	GROUP BY item.id, grup.id, grup.descripcion;
	
	---- @LINEA - INSERTAMOS LA LINEA DE LOS ITEMS DE DESCUENTOS Y DEVOLUCIONES EN VENTA
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


	----- SELECT FINAL -----
	SELECT	SW = t.sw, 
		BODEGA = b1.descripcion,
		ID_FACTURA_NC_D = d.id,
		NUMERO_DOCUMENTO = d.numero_cotizacion,
		--FACTURA = CASE
		--	WHEN t.sw = -1 THEN dv.factura
		--	ELSE CAST (ISNULL (b1.ecu_establecimiento, '') AS VARCHAR(4)) + CAST (ISNULL (ct.ecu_emision, '') AS VARCHAR(4)) COLLATE modern_spanish_ci_ai + '' + RIGHT ('000000000' + CAST (d.numero_cotizacion AS VARCHAR(100)), 9)
		--END,
		FACTURA=CASE
				WHEN t.sw = -1
				THEN dv.factura ELSE CAST(ISNULL(bod.ecu_establecimiento,'') AS VARCHAR(4)) + CAST(ISNULL(t.ecu_emision,'') AS VARCHAR(4)) COLLATE modern_spanish_ci_ai + '' + RIGHT('000000000' + CAST(d.numero_cotizacion AS VARCHAR(100)),9)
				END,
		FECHA = d.fecha,
		NRO_ORDEN = ISNULL (d.id_cot_cotizacion_sig, 0),
		TIPO_ORDEN = ISNULL(cv.campo_1, ''), 
		CLIENTE = cc.razon_social,
		SERIE = ISNULL (vhl.chasis, ''),
		VEHICULO = ic2.descripcion,
		PLACA = ISNULL (vhl.placa, ''),
		MARCA = ISNULL ((CASE
			WHEN m.descripcion LIKE '%MULTIMARCA' THEN
				CASE
					WHEN cv6.campo_11 = '' OR cv6.campo_11 IS NULL THEN m.descripcion
					ELSE SUBSTRING (cv6.campo_11,3, 100)
				END
			ELSE 
				CASE
					WHEN ic.codigo LIKE '%ALL%' THEN
						CASE
							WHEN cv6.campo_11 = '' OR cv6.campo_11 IS NULL THEN m.descripcion
							ELSE SUBSTRING (cv6.campo_11,3, 100)
						END
					ELSE m.descripcion
				END
		END),
		(CASE
			WHEN m2.descripcion LIKE '%MULTIMARCA%' THEN
				CASE
					WHEN cv7.campo_11 = '' OR cv7.campo_11 IS NULL THEN m2.descripcion
					ELSE SUBSTRING (cv7.campo_11,3, 100)
				END
			ELSE 
				CASE
					WHEN ic2.codigo LIKE '%ALL%' THEN
						CASE
							WHEN cv7.campo_11 = '' OR cv6.campo_11 IS NULL THEN m2.descripcion
							ELSE SUBSTRING (cv7.campo_11,3, 100)
						END
					ELSE m2.descripcion
				END
		END)), 
		VENDEDOR = u.nombre,
		RAZON_INGRESO = ri.descripcion,
		OPERARIO = up.nombre, 
		OPERACION = i.codigo,
		DESCRIPCION = i.descripcion,
		CLASIFICACION_CATEGORIA = ISNULL(gen.descripcion, ''),
		TIPO_OPERACION = CASE
			WHEN i.costo_emergencia <> 0 AND ABS (i.precio) <> 0 THEN 'V'
			ELSE 'T'
		END,		
		CANTIDAD = d.cantidad_und, 
		TIEMPO= case when t.sw = -1 then 
						case when (d.cantidad_und)*-1 <>1 and d.cantidad_und<>0
								then 
								round((isnull( d.tiempo/d.cantidad_und ,0)*-1),4)
							else
								round((isnull( d.tiempo,0)),4)
							end
				else 
							case when (d.cantidad_und)<>1 and d.cantidad_und<>0
							then 
								round((isnull( d.tiempo/d.cantidad_und,0)),4)
							else
								round((isnull( d.tiempo ,0)),4)
							end
				end,
		VALOR_HORA = ISNULL (d.valor_hora, 0),
		'NUMERO_HORAS (cant x tiempo)' = 
		CASE
			WHEN i.costo_emergencia <> 0 AND ABS (i.precio) <> 0 THEN 0
			ELSE CASE WHEN d.sw = -1 
			THEN 
			CASE 
				WHEN (d.cantidad_und) * -1 <> 1 AND d.cantidad_und <> 0
					THEN ROUND ((ISNULL (d.tiempo / d.cantidad_und, 0) * -1) ,4)
					ELSE ROUND ((ISNULL (d.tiempo, 0)), 4)
			END
			ELSE 
				CASE WHEN (d.cantidad_und) <> 1 AND d.cantidad_und <> 0
					THEN ROUND ((ISNULL (d.tiempo / d.cantidad_und, 0)), 4)
					ELSE ROUND ((ISNULL (d.tiempo, 0)), 4)
				END
		END * ABS (d.cantidad_und) END,				
		PRECIO_LISTA=isnull(abs(pl.tras_Preciolista)*abs(d.cantidad_und)*case when d.sw=1 then 1 else -1 end,

							CASE WHEN i.costo_emergencia<>0 AND ABS(i.precio)<>0 
								THEN
									ABS (d.cantidad_und) * ABS (d.precio_lista) *
										case 
											when d.sw=1 then 1 else -1 
										end 
							
								ELSE
								
									ABS (isnull( d.tiempo ,0))* ABS (isnull(d.valor_hora,0))* case when d.sw = 1 then 1 else -1 end
								
								
								END
						),
		 DESCUENTO=CASE WHEN (isnull(abs(pl.tras_Preciolista)*abs(d.cantidad_und)*case when d.sw=1 then 1 else -1 end,
						
				

							CASE WHEN i.costo_emergencia<>0 AND ABS(i.precio)<>0 
								THEN
									ABS (d.cantidad_und) * ABS (d.precio_lista) *
										case 
											when d.sw=1 then 1 else -1 
										end 
							
								ELSE
								
									ABS (isnull( d.tiempo ,0))* ABS (isnull(d.valor_hora,0))* case when d.sw = 1 then 1 else -1 end
								
								
								END
						))=0 THEN 0
						ELSE
	
	
		(isnull(abs(pl.tras_Preciolista)*abs(d.cantidad_und)*case when d.sw=1 then 1 else -1 end,
						
				

							CASE WHEN i.costo_emergencia<>0 AND ABS(i.precio)<>0 
								THEN
									ABS (d.cantidad_und) * ABS (d.precio_lista) *
										case 
											when d.sw=1 then 1 else -1 
										end 
							
								ELSE
								
									ABS (isnull( d.tiempo ,0))* ABS (isnull(d.valor_hora,0))* case when d.sw = 1 then 1 else -1 end
								
								
								END
						)-(abs(d.cantidad_und)*abs(d.precio_lista)*
								case 
									when d.sw=1 then 1 else -1 
								end ))END ,
		PRECIO_BRUTO_TOTAL = CONVERT (DECIMAL(18,2),(case when (d.precio_lista * cantidad_und) - ((isnull((abs(d.cantidad_und)*abs(d.precio_lista)*(d.porcentaje_descuento)/100),0))* case when d.sw = 1 then 1 
				                                                                                                                                                                             else -1 
																																													    end) = (abs(precio_cotizado) * abs(cantidad_und))
															then convert(DECIMAL(18,2),abs(d.cantidad_und)*abs(d.precio_lista)*case when d.sw=1 then 1 
																																				else -1 
																																	end)
															else ((abs(d.precio_cotizado) *abs(case when d.cantidad_und=0 then 1 
																									else d.cantidad_und 
																							   end)) * case when d.sw = 1 then 1 
																											else -1 
																									   end) + ((isnull((abs(d.cantidad_und)*abs(d.precio_lista) * (d.porcentaje_descuento)/100),0)) * case when d.sw = 1 then 1 
																																																							else -1 
																																																						end)
													end)
													),
		PRECIO_NETO_TOTAL = ( ABS (d.precio_cotizado) 
						* ABS (case when d.cantidad_und = 0 then 1 
							else d.cantidad_und end))
						* case when d.sw=1 then 1 else -1 end
	FROM #Docs d
	JOIN @LINEA line ON line.id_item = d.id_cot_item
	JOIN dbo.cot_tipo t ON t.id = d.id_cot_tipo
	JOIN v_cot_bodega_taller b1 ON b1.id = d.id_cot_bodega
	JOIN @Bodega b on b.id=b1.id 
	JOIN dbo.cot_cotizacion cb ON cb.id = d.id
	JOIN dbo.cot_bodega bod ON bod.id = cb.id_cot_bodega
	JOIN cot_zona_sub zs on zs.id = bod.id_cot_zona_sub
	join cot_zona z on z.id=zs.id_cot_zona
	JOIN dbo.cot_cliente cc ON cc.id = d.id_cot_cliente
	LEFT JOIN dbo.usuario u ON u.id = d.id_usuario_ven
	JOIN dbo.cot_item i ON i.id = d.id_cot_item
	LEFT JOIN @Devoluciones dv ON dv.id = d.id
	--------------------------------------
	LEFT JOIN dbo.cot_cotizacion cct ON cct.id = d.id_cot_cotizacion_sig
	LEFT JOIN dbo.cot_item_lote ih ON ih.id = d.id_cot_item_vhtal
	LEFT JOIN dbo.cot_item ic ON ic.id = ih.id_cot_item
	LEFT JOIN dbo.veh_linea_modelo l ON l.id = ic.id_veh_linea_modelo
	LEFT JOIN dbo.veh_linea v ON v.id = ic.id_veh_linea
	LEFT JOIN dbo.veh_marca m ON m.id = v.id_veh_marca
	LEFT JOIN dbo.cot_item_talla ct ON ct.id = ic.id_cot_item_talla
	LEFT JOIN dbo.v_campos_varios cv6 ON cv6.id_cot_item_lote = ih.id
	--------------------------------------
	LEFT JOIN dbo.cot_item_lote vhl ON vhl.id = cct.id_cot_item_lote
	LEFT JOIN dbo.v_campos_varios cv ON cv.id_cot_cotizacion = cct.id AND cv.campo_1 IS NOT NULL
	LEFT JOIN dbo.cot_item ic2 ON ic2.id = vhl.id_cot_item
	LEFT JOIN dbo.veh_linea_modelo l2 ON l2.id = ic2.id_veh_linea_modelo
	LEFT JOIN dbo.veh_linea vl2 ON vl2.id = ic2.id_veh_linea

	LEFT JOIN dbo.veh_marca m2 ON m2.id = vl2.id_veh_marca
	LEFT JOIN dbo.cot_item_talla ct3 ON ct3.id = ic2.id_cot_item_talla
	LEFT JOIN dbo.v_campos_varios cv7 ON cv7.id_cot_item_lote = vhl.id
	LEFT JOIN dbo.usuario up ON up.id = d.id_operario
	--------------------------------------
	LEFT JOIN #RtosPLista pl ON pl.id=d.id and pl.id_cot_cotizacion_item=d.id_cot_cotizacion_item and pl.id_cot_item=d.id_cot_item
	LEFT JOIN dbo.cot_item_color gen ON gen.id = i.id_cot_item_color
	LEFT JOIN v_tal_motivo_ingreso ri ON ri.id = cct.id_tal_motivo_ingreso
	WHERE line.linea = 'TALLER';
GO


