USE [dms_smd3]
GO
/****** Object:  StoredProcedure [dbo].[GetVentasDetalladaTaller]    Script Date: 8/5/2022 22:41:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ===========================================================================================================================================================================
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
-- 22/nov/2021	Se modifica para que se obtenga la bodega de los Items de la factura, tal como se visualiza en la opcion de Advance 1104 (JCB)
-- 20/dic/2021  Se agrega el campo NIT_PROVEEDOR el cual almacena el NIT de los proveedores en las TOT's (JCB)
-- 22/dic/2021  Se ajusta el campo NIT_PROVEEDOR para que obtenga el NIT del Proveedor en las Notas de Credito (JCB)
-- 22/dic/2021  Se ajusta el calculo del campo precio_neto para que considere los dos descuentos [%desc1] y [%desc2] ya que hay descuadres con el Contable (JCB)
-- 11/MAR/2022  Se ajusta el tamaño del campo notas de la tabla cot_cotizacion (JCB)
-- 11/ABR/2022  Se quema en codigo la OT 559280 debido a que 359 citas (JCB)
-- 09/MAY/2022  Se agrega las ventas del Grupo Aplicaciones (JCB)
-- ============================================================================================================================================================================

-- Exec [dbo].[GetVentasDetalladaTaller_Deshabilitado] '605','0','20220401','20220430','0'   --34296 REGISTROS
ALTER PROCEDURE [dbo].[GetVentasDetalladaTaller] 
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
	inner join cot_bodega b_tal on cast(substring(r.llave,9,4) as INT) = b_tal.id
	inner join cot_bodega b_pp on b_pp.id = r.respuesta
	where r.id_emp = 605
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
	inner join cot_bodega b_rep on cast(substring(r.llave,4,4) as INT) = b_rep.id
	inner join cot_bodega b_consig on b_consig.id = r.respuesta
	where r.id_emp = 605
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
		id_item int,
		id_compra int
	
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
		id_item,
		id_compra
	)
	SELECT
	c.id,
		   c.id_cot_tipo,
		   id_cot_bodega = v.id_cot_bodega,
		   c.id_cot_cliente,
		   c.numero_cotizacion,
		   c.fecha,
		   notas = CAST(c.notas AS VARCHAR(MAX)),
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
		   id_item=ci.id_componenteprincipalEst,
		   id_compra = 0
	FROM dbo.cot_cotizacion c 
	JOIN dbo.cot_tipo t ON (t.id = c.id_cot_tipo) 
    JOIN dbo.cot_cotizacion_item ci ON (ci.id_cot_cotizacion = c.id)
	JOIN v_cot_cotizacion_item_todos v on v.id = ci.id
	JOIN @Bodega b ON v.id_cot_bodega = b.id   
	--join dbo.v_cot_cotizacion_item_todos vc on (vc.id_cot_cotizacion_item = i.id)
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
    AND (ISNULL (ci.facturar_a, 'NULL') <> 'S') -- Excluimos los ítems que corresponden a insumos
	--and c.id in (464226,461074)
	

--Exec GetVentasDetalladaTaller '605','0','20220301','20220308','0' 
--select * from #Docs

	
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
		id_item,
		id_compra
	)

	SELECT --distinct 
		c.id_cot_cotizacion,
		t.id,
		b.id,
		cc.id_cot_cliente,
		cc.id_cot_cliente_contacto,
		cc.numero_cotizacion,
		fecha=CAST (cc.fecha AS DATE), 
		--cc.notas,
		notas = CAST(c.notas AS VARCHAR(MAX)),
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
		c.id_componenteprincipalEst,
		id_compra = 0
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
	-- Compra
	--LEFT JOIN cot_cotizacion cp on cp.id_cot_cotizacion_sig = adi.id_otori
	WHERE (t.sw = 1 AND (c.id_cot_cotizacion IN (select g.id_factura from #OTs_CONSOLIDADAS_GARATIAS g)) 
		OR t.sw = -1 AND (fdev.id_cot_cotizacion_factura IN (select g.id_factura from #OTs_CONSOLIDADAS_GARATIAS_NC g)))
	AND (c.id_cot_cotizacion_item IS NULL)
	and t.sw IN ( 1, -1 ) 
	and t.es_remision is null 
    and t.es_traslado is null 
    and (@cli=0 or cc.id_cot_cliente=@cli)
	AND (ISNULL (c.facturar_a, 'NULL') <> 'S') -- Excluimos los ítems que corresponden a insumos
	--and cc.id in (464226,461074)


	
	---------------------------------------------------------------------------------------------------------------------------------------------
	-- OBTENER INFORMACIÓN DE PROVEEDORES EN LAS TOT
	-- El campo IdcomponenetePrincipalEst de la tabla cot_cotizacion_item es el mismo que el campo id_cot_cotizacion_item de la Compra.
	---------------------------------------------------------------------------------------------------------------------------------------------
	--select id_fac_nc = d.id,
	--       d.sw,
	--       d.id_cot_cotizacion_item,
	--	   id_ot = d.id_cot_cotizacion_sig,
	--	   --d.ot_final,
	--	   id_compra = c.id,
	--	   id_cot_cotizacion_item_compra = cic.id,
	--	   cc.nit,
	--	   cic.tipo_operacion,
	--	   id_cot_item = cic.id_cot_item
	----into #Proveedores_TOT
	--from #Docs d
	---- cruzamos para encontrar la compra
 --   join cot_cotizacion c on c.id_cot_cotizacion_sig = d.id_cot_cotizacion_sig
	--join cot_cotizacion_item cic on cic.id_cot_cotizacion = c.id and d.id_item = cic.id
	--join cot_cliente cc on cc.id = c.id_cot_cliente
	---- 
	--join cot_tipo tc on tc.id = c.id_cot_tipo
	--where d.tipo_operacion = 'O'
	--and tc.sw = 4
	--and d.id = @id_factura---464226--464226--461074
	----and d.id_cot_cotizacion_sig = 424893

	

	
	------------------------------------------------------------------------------------------------------------------------------
	-- OBTENER INFORMACIÓN DEL PROVEEDOR EN LAS TOT
	------------------------------------------------------------------------------------------------------------------------------

	-- Exec GetVentasDetalladaTaller_Compras_TOT '605','0','20211124','20211124','0'   --34296 REGISTROS

	--SELECT DISTINCT id_fac_nc = d.id,
	--	   d.sw,
	--	   d.id_cot_cotizacion_item,
	--       id_ot = ot.id,
	--	   --id_compra = compra.id,
	--	   cc.nit,
	--	   id_cot_item = ci_compra.id_cot_item,
	--	   ci_compra.tipo_operacion
	--	   --id_cot_cotizacion_item_ot = ci.id  --El ID del Item de la Compra es el mismo que el ID de la OT, pero no es el mismo que el ID del Item de la Factura
		   
	--into #Proveedores_TOT
	--from #Docs d
	--join cot_cotizacion fac on fac.id = d.id
	--join cot_cotizacion_item ci on ci.id_cot_cotizacion = fac.id and ci.id = d.id_cot_cotizacion_item
	--join cot_tipo tt on tt.id = fac.id_cot_tipo
	--join cot_cotizacion ot on fac.id_cot_cotizacion_sig = ot.id
	--join cot_cotizacion_item ci_ot on ci_ot.id_cot_cotizacion = ot.id

	--JOIN cot_cotizacion compra on compra.id_cot_cotizacion_sig = ot.id 
	--join cot_tipo tot on tot.id = ot.id_cot_tipo
	--join cot_cotizacion_item ci_compra on ci_compra.id_cot_cotizacion = compra.id and ci.id_componenteprincipalEst = ci_compra.id--and ci_ot.id_cot_item = ci_compra.id_cot_item
	--join cot_tipo t on t.id = compra.id_cot_tipo
	--join cot_cliente cc on cc.id = compra.id_cot_cliente
	----join cot_cotizacion ot 
	----join cot_cotizacion_item ci on ci.id_cot_cotizacion = fac.id and ci.id = d.id_cot_cotizacion_item
	--where t.sw = 4
	--and tot.sw = 46  -- OT
	--and tt.sw in (1,-1)
	--and d.tipo_operacion = 'O'  -- Otros
	--and d.id = 461074--464226--452167--456740--452167--452771
	

	
	--select *
	--from #Docs d
	--where d.id = 461074

	--select * from #Proveedores_TOT
	
	
	--select t.sw,t.descripcion,c.*
	--from cot_cotizacion c
	--join cot_tipo t on t.id = c.id_cot_tipo
	--where t.sw in (1,-1)
	--and c.id = 452771
	
	   
	
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
	JOIN dbo.cot_bodega bd ON bd.id = cc3.id_cot_bodega
	LEFT JOIN com_orden_concep conc ON conc.id = cc3.id_com_orden_concep


	--select *
	--from @Devoluciones d
	--where d.id = 452059
	
	--select *
	--from #Docs d
	--where d.id = 449795
	---------------------------------------------------------------------------------------------------------------------------------------------
	-- OBTENER INFORMACIÓN DE PROVEEDORES EN LAS TOT
	-- El campo IdcomponenetePrincipalEst de la tabla cot_cotizacion_item es el mismo que el campo id_cot_cotizacion_item de la Compra.
	---------------------------------------------------------------------------------------------------------------------------------------------
	-- y en PO

	--select *
	--from #Docs d
	--WHERE d.id = 452059


	declare @Info_Compras_TOTs as table
	(
		id_fac_nc int,
		sw int,
		id_cot_cotizacion_item int,
		id_ot int,
		id_compra int,
		nit_proveedor_tot nvarchar(50),
		tipo_operacion char(10)

	)
	INSERT @Info_Compras_TOTs
	select id_fac_nc = d.id,
	       d.sw,
	       d.id_cot_cotizacion_item,
		   id_ot = d.id_cot_cotizacion_sig,
		   id_compra = c.id,
		   --id_cot_cotizacion_item_compra = cic.id,
		   cc.nit,
		   cic.tipo_operacion
		   --id_cot_item = cic.id_cot_item
	from #Docs d
	join cot_cotizacion_item cic on cic.id = d.id_item
	join cot_cotizacion c on c.id = cic.id_cot_cotizacion
	join cot_cliente cc on cc.id = c.id_cot_cliente
	-- 
	join cot_tipo tc on tc.id = c.id_cot_tipo
	where d.tipo_operacion = 'O'
	and d.sw = 1
	and tc.sw = 4
	--and d.id = 449795
	--and d.id_cot_cotizacion_sig = 417490

	INSERT @Info_Compras_TOTs
	select id_dev = d.id,
	       d.sw,
	       d.id_cot_cotizacion_item,
		   id_ot = d.id_cot_cotizacion_sig,
		   id_compra = c.id,
		   --id_factura = dev.id_factura,
		   cc.nit,
		   cic.tipo_operacion
	from #Docs d
	join @Devoluciones dev on dev.id = d.id
	join v_cot_cotizacion_item_dev vi on vi.id_cot_cotizacion_item_dev = d.id_cot_cotizacion_item
	join cot_cotizacion_item ci on ci.id = vi.id
	join cot_cotizacion_item cic on cic.id = ci.id_componenteprincipalEst
	join cot_cotizacion c on c.id = cic.id_cot_cotizacion --compra
	join cot_cliente cc on cc.id = c.id_cot_cliente
	--
	join cot_tipo tc on tc.id = c.id_cot_tipo
	WHERE d.sw = -1
	and d.tipo_operacion = 'O'
	and tc.sw = 4
	--AND d.id = 452059


	
    -- Exec GetVentasDetalladaTaller_Compras_TOT '605','0','20211101','20211130','0'   --34296 REGISTROS

	

	--Validacion Fac con devolución
	--insert @FacConDev
	--(id, tiene)
	--select distinct 
	--d.id, 
	--tipo= case when tv.tiene_devol=1 then 'Si' else 'No' end
	--from #Docs d
	--JOIN dbo.v_cot_tiene_devolucion tv ON tv.id_cot_cotizacion = d.id
	--where d.sw=1

	----------------- validacion Orden de taller
	--INSERT @FacOT
	--(
	--	id,
	--	id_ot
	--)
	--SELECT DISTINCT
	--	   d.id,
	--	   id_ot = o.id_cot_cotizacion_sig
	--FROM #Docs d	
	--	JOIN dbo.v_tal_ya_fue_facturado o
	--		ON o.id_cot_cotizacion = d.id

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
	JOIN dbo.cot_bodega b ON b.id = c.id_cot_bodega
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
	WHERE grup.id IN (1321, 1322, 1323, 1326, 1337, 1345)
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



	--SELECT FINAL
	SELECT
	sw=t.sw,
	LineaNegocio=line.linea,
	-- SE AGREGA EL CASE PARA COLOCAR EL CANAL DE ACUERDO A LA BODEGA Y A LA LINEA 
	canal = CASE WHEN t.sw = 1 THEN
				CASE WHEN b.descripcion LIKE '%TAL%' THEN
					CASE WHEN line.linea = 'TALLER' THEN
						CASE WHEN cv.campo_1 = '01 Mecánica' THEN
								CASE WHEN ct2.id <> 0 THEN 'AGENDAMIENTO'
									 WHEN flo.EstaEnFlota = 'S' THEN 'FLOTAS'
									 ELSE 'RETAIL' 
								END
							 WHEN cv.campo_1 = '02 Latoneria- Pintura' THEN
								CASE WHEN cli2.nit IS NOT NULL THEN 'ASEGURADORA'
									 WHEN ubi.descripcion LIKE '%EXPRESS%' THEN 'EXPRESS'
									 ELSE 'RETAIL' 
								END
							 WHEN cv.campo_1 = '03 Garantías' THEN 'RETAIL'
							 ELSE 'VACIO'
						END
					 WHEN line.linea = 'TOT' THEN 'TOT'
						ELSE 'REPUESTOS' --
			 		 END
					ELSE ISNULL (co.descripcion, '')
				END
			ELSE ISNULL (dv.concepto, '')
			END,
	--Bodega = b.descripcion,
	Bodega = CASE when b.id in (select rn.id_cot_bodega_rn from @bodegas_reglas_negocio rn) then brn.descripcion else b.descripcion end,
	Zona= CASE WHEN zs.descripcion ='NORTE' THEN 'Zona 1'
				WHEN z.descripcion='COSTA' AND zs.descripcion in ('CENTRO', 'SUR') THEN 'Zona 2'
				WHEN z.descripcion='SIERRA' AND zs.descripcion in ('SUR') THEN 'Zona 3'
				end,
	Nit_Facturado_a=cc.nit,
	Facturado_a=cc.razon_social,	
	--Id_Factura_NC_ND=d.id,
	Id_Documento=d.id,
	Numero_Documento=d.numero_cotizacion,
	Comprobante=CAST(ISNULL(bod.ecu_establecimiento,'') AS VARCHAR(4)) + CAST(ISNULL(t.ecu_emision,'') AS VARCHAR(4)) COLLATE modern_spanish_ci_ai + '' + RIGHT('000000000' + CAST(d.numero_cotizacion AS VARCHAR(100)),9),
	Factura=CASE
				WHEN t.sw = -1
				THEN dv.factura ELSE CAST(ISNULL(bod.ecu_establecimiento,'') AS VARCHAR(4)) + CAST(ISNULL(t.ecu_emision,'') AS VARCHAR(4)) COLLATE modern_spanish_ci_ai + '' + RIGHT('000000000' + CAST(d.numero_cotizacion AS VARCHAR(100)),9)
				END,
	Tipo_documento=t.descripcion,
	Fec_comprobante=d.fecha,
	Forma_pago=fp.descripcion,		
	Nit_vendedor=u.cedula_nit, --DE LA ORDEN ORIGINAL
	Vendedor=u.nombre,	--DE LA ORDEN ORIGINAL
	MarcaVH_original = ISNULL((CASE WHEN m.descripcion like '%MULTIMARCA%'
			THEN
				CASE WHEN cv6.campo_11 ='' OR cv6.campo_11 IS NULL  THEN m.descripcion
				ELSE substring ( cv6.campo_11,3,100) END 
		ELSE
			CASE WHEN ic.codigo LIKE '%ALL%'
				THEN
					CASE WHEN cv6.campo_11 ='' OR cv6.campo_11 IS NULL  THEN m.descripcion
					ELSE substring ( cv6.campo_11,3,100) END 
				ELSE
				m.descripcion
				END
		END),(CASE WHEN m2.descripcion like '%MULTIMARCA%'
			THEN
				CASE WHEN cv7.campo_11 ='' OR cv7.campo_11 IS NULL  THEN m2.descripcion
				ELSE substring ( cv7.campo_11,3,100) END 
		ELSE
			CASE WHEN ic2.codigo LIKE '%ALL%'
				THEN
					CASE WHEN cv7.campo_11 ='' OR cv6.campo_11 IS NULL  THEN m2.descripcion
					ELSE substring ( cv7.campo_11,3,100) END 
				ELSE
				m2.descripcion
				END
		END)), --DE LA ORDEN ORIGINAL
	[Modelo Año]= ISNULL(( CASE WHEN m.descripcion like '%MULTIMARCA%'
			THEN
				CASE WHEN cv6.campo_12 ='' OR cv6.campo_12 IS NULL THEN ic.descripcion
				ELSE cv6.campo_12 END 
		ELSE
			CASE WHEN ic.codigo LIKE '%ALL%'
				THEN
					CASE WHEN cv6.campo_12 ='' OR cv6.campo_12 IS NULL THEN ic.descripcion
				ELSE cv6.campo_12 END 
				ELSE
					ic.descripcion
				END
		END),(CASE WHEN m2.descripcion like '%MULTIMARCA%'
			THEN
				CASE WHEN cv7.campo_12 ='' OR cv7.campo_12 IS NULL THEN ic2.descripcion
				ELSE cv7.campo_12 END 
		ELSE
			CASE WHEN ic2.codigo LIKE '%ALL%'
				THEN
					CASE WHEN cv7.campo_12 ='' OR cv7.campo_12 IS NULL THEN ic2.descripcion
				ELSE cv7.campo_12 END 
				ELSE
					ic2.descripcion
				END
		END)),
	[Año]=ISNULL((CASE WHEN m.descripcion like '%MULTIMARCA%'
			THEN
				CASE WHEN CONVERT(decimal, cv6.campo_13,0) =0 or cv6.campo_13 IS NULL THEN ic.id_veh_ano
				ELSE CONVERT(decimal, cv6.campo_13,0) end
		ELSE
			CASE WHEN ic.codigo LIKE '%ALL%'
				THEN
					CASE WHEN CONVERT(decimal, cv6.campo_13,0) =0 or cv6.campo_13 IS NULL THEN ic.id_veh_ano
					ELSE CONVERT(decimal, cv6.campo_13,0) end
				ELSE
					ic.id_veh_ano
				END
		END),(CASE WHEN m2.descripcion like '%MULTIMARCA%'
			THEN
				CASE WHEN CONVERT(decimal, cv7.campo_13,0) =0 or cv7.campo_13 IS NULL THEN ic2.id_veh_ano
				ELSE CONVERT(decimal, cv7.campo_13,0) end
		ELSE
			CASE WHEN ic2.codigo LIKE '%ALL%'
				THEN
					CASE WHEN CONVERT(decimal, cv7.campo_13,0) =0 or cv7.campo_13 IS NULL THEN ic2.id_veh_ano
					ELSE CONVERT(decimal, cv7.campo_13,0) end
				ELSE
					ic2.id_veh_ano
				END
		END)),--DE LA ORDEN ORIGINAL
	--Serie=vhl.chasis, --DE LA ORDEN ORIGINAL
	[VIN Taller]=vhl.vin, --DE LA ORDEN ORIGINAL
	[Motor]=isnull(vhl.motor,'') , --DE LA ORDEN ORIGINAL
	[Color Vh]=isnull(col.descripcion,''), --DE LA ORDEN ORIGINAL
	[KM]=cct.km, --DE LA ORDEN ORIGINAL
	[Placa]=ISNULL(vhl.placa,''), --DE LA ORDEN ORIGINAL
	Nit_propietario=isnull(cli3.nit,''), --DE LA ORDEN ORIGINAL
	Propietario=isnull(cli3.razon_social,''), --DE LA ORDEN ORIGINAL
	--LineaMaestro=isnull(case when isnull(tl.descripcion,'')='' then  vt.LineaTaller else  tl.descripcion end ,''), Saca si no esta la descripcio de la linea en el item saca la del VH
	LineaVH=ISNULL(ct.descripcion,ct3.descripcion),
	Clase_cliente=cp.descripcion,
	Clase_cliente_flota=flo.ClaseCliente,
	Pertenece_flota= isnull(flo.EstaEnFlota,'N'),
	----FALTA AGREGAR VIGENCIA DE FLOTA SE DEFINIRA PRIMERO-------
	Familia=isnull (v.descripcion,v2.descripcion),
	[ID_Orden Taller]=ISNULL(d.id_cot_cotizacion_sig,0),--ot.id_ot,
	razon_ingreso=ri.descripcion,
	--Numero_OT=ISNULL(cct.numero_cotizacion,0) ,
	Fec_Apertura_OT=cct.fecha,
	Promesa_Entrega=cct.fecha_estimada,
	---FALTA FECHA ENTREGA VH
	DIAS=ISNULL((DATEDIFF (DAY,cct.fecha , d.fecha)),0),
	Tipo_orden=ISNULL(cv.campo_1,''),
	id_cot_item=d.id_cot_item,	
	[CODIGO DE MO]=CASE
					WHEN d.id_cot_item_lote = 0
					THEN i.codigo ELSE il.vin
					END,
	[DESCRIPCION MO]=CASE WHEN flo.EstaEnFlota ='S'  
								THEN
									CASE WHEN tfpr.desc_cod_flota is NULL
										THEN 
											CASE WHEN i.codigo  like '%TOT%'
												THEN
													CASE WHEN  d.notas_item='' or d.notas_item is null 
														THEN
														i.descripcion
														ELSE
														d.notas_item
													END
												ELSE 
												i.descripcion
											END
									END
								ELSE 
									CASE WHEN i.codigo  like '%TOT%'
												THEN
													CASE WHEN  d.notas_item='' or d.notas_item is null 
														THEN
														i.descripcion
														ELSE
														d.notas_item
													END
												ELSE 
												i.descripcion
											END
			END,
					
		--NIT_PROVEEDOR = tot.nit_proveedor_tot,
	
		--nombre_bodega=g.descripcion,
		Grupo=g.descripcion,
		[Subgrupo]=s.descripcion,
		[SubGrupo3]=ISNULL(s3.descripcion,''),
		[SubGrupo4]=ISNULL(s4.descripcion,''),
		[ORIGINAL ALTERNO]=ISNULL(va.campo_5,''),
		Clasificacion_Tarea=ISNULL(gen.descripcion,''),
		grupo_cor=ISNULL(s3.descripcion,''),
		[FUENTE COR]=ISNULL(va.campo_4,''),
		Linea_Rep=ISNULL (lr.descripcion,''),
		cantidad=d.cantidad_und,
		tiempo= case when t.sw = -1 then 
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

		tiempo_total=	
		case when g.descripcion='REPUESTOS'  or g.descripcion='ACCESORIOS' or g.id=1337
						THEN 0
						ELSE 
							CASE WHEN i.costo_emergencia<>0 AND ABS(i.precio)<>0
								THEN
									0
								ELSE
									isnull( d.tiempo ,0)
								END
						END,
	
		-- isnull( d.tiempo ,0),
		valor_hora=isnull(d.valor_hora,0),
		costo=isnull((d.cantidad_und * d.costo),0),
		precio_lista=isnull(abs(pl.tras_Preciolista)*abs(d.cantidad_und)*case when d.sw=1 then 1 else -1 end,
						
				

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
		Desc1=CASE WHEN (isnull(abs(pl.tras_Preciolista)*abs(d.cantidad_und)*case when d.sw=1 then 1 else -1 end,
						
				

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
	
				precio_bruto = CONVERT (DECIMAL(18,2),(case 
                                            when (d.precio_lista * cantidad_und) - ((isnull((abs(d.cantidad_und)*abs(d.precio_lista)*
                                            (d.porcentaje_descuento)/100),0))* case when d.sw = 1 then 1 else -1 end) = (abs(precio_cotizado) * abs(cantidad_und))
                                            then convert(DECIMAL(18,2),abs(d.cantidad_und)*abs(d.precio_lista)*case when d.sw=1 then 1 else -1 end)
                                            else ((abs(d.precio_cotizado) *abs(case when d.cantidad_und=0 then 1 else d.cantidad_und end ))* case when d.sw=1 then 1 else -1 end) +
                                            ((isnull((abs(d.cantidad_und)*abs(d.precio_lista)*
                                            (d.porcentaje_descuento)/100),0))* case when d.sw = 1 then 1 else -1 end)
                                    end)),

		porcentaje_descuento=isnull(d.porcentaje_descuento,0)* case when d.sw = 1 then 1 else -1 end,
		descuento=(isnull((abs(d.cantidad_und)*abs(d.precio_lista)*
								(d.porcentaje_descuento)/100),0))*case when d.sw = 1 then 1 else -1 end,
	
	
	
	
		--ROUND(isnull((( d.cantidad_und * d.precio_lista) * d.porcentaje_descuento / 100),0),2),
		--precio_neto = (abs(d.precio_cotizado) * abs(case when d.cantidad_und = 0 then 1 
		--                                                 else d.cantidad_und 
		--											 end)) * case when d.sw=1 then 1 else -1 end,
		precio_neto = (abs(d.precio_cotizado * (1 - ISNULL(d.porcentaje_descuento2,0)/100)) * abs(IIF(d.cantidad_und=0,1,d.cantidad_und)) ) * IIF(t.sw = 1,1,-1),

		margen=CASE WHEN isnull((d.cantidad_und * d.costo),0)=0
					THEN	
						0
					ELSE
					 (1-((d.cantidad_und * d.costo)/((abs(IIF(d.precio_cotizado=0,1,d.precio_cotizado)) *abs(case when d.cantidad_und=0 then 1 else d.cantidad_und end ))* case when d.sw=1 then 1 else -1 end )))*100
					END,
		porcentaje_iva=d.porcentaje_iva,
		iva=CASE
			WHEN d.porcentaje_iva <> 0
			THEN d.cantidad_und * d.precio_cotizado ELSE 0
			END * d.porcentaje_iva / 100,
		[total]=(case when d.cantidad_und=0 then 1 else d.cantidad_und end * d.precio_cotizado * ( 1 + d.porcentaje_iva / 100 ))*case when d.sw=1 then 1 else -1 end ,
	
		[TOTAL_FACTURA]=D.total_total *case when d.sw=1 then 1 else -1 end ,
		Operario_NIT= CASE WHEN  g.descripcion + ' ' + s.descripcion like '%REPUESTOS%' or g.descripcion + ' ' + s.descripcion like '%ACCESORIOS%' or g.descripcion + ' ' + s.descripcion like '%DISPOSITIVOS%'
					THEN 
						ust.cedula_nit
					else 
			ISNULL(up.cedula_nit,'')end, --DE LA ORDEN ORIGINAL

		operario= CASE WHEN  g.descripcion + ' ' + s.descripcion like '%REPUESTOS%' or g.descripcion + ' ' + s.descripcion like '%ACCESORIOS%' or g.descripcion + ' ' + s.descripcion like '%DISPOSITIVOS%'
					THEN 
						ust.nombre
					else up.nombre end, --DE LA ORDEN ORIGINAL
		Trabajos_realizados=dbo.Trabajos_realizados (cct.id),
		estado_ot=ubi.descripcion,
		TieneDevolucion=case when dev.id_cot_cotizacion_item is not null then 'Si' else 'No' end ,
		---FALTA ID DEVOLUCION Y FECHA DE DEVOLUCION


		--id_cot_cotizacion_item=ISNULL(dev.id_cot_cotizacion_item,0) ,
		Nit_Aseguradora=isnull(cli2.nit,''),
		Aseguradora = isnull(cli2.razon_social,''),
		fec_Aut_Aseguradora=cct.fecha_cartera,
		fec_env_aut_aseguradora=cmas.fecha_envio_ase,
		saldo_Factura=d.saldo,
		--int_tributable=et.descripcion,
		[Centro Costos]=dcc.codcentro,
		Id_cita=isnull(ct2.id,0),
		canal_cita = isnull(ct2.Canal,''),
		Fecha_Hora_Cita=ct2.[Fecha Cita],
		Nit_usuario=ct2.nit_usuario_cita,
		Usuario=ct2.usuario_cita,
		Estado_Cita=isnull(ct2.Estado,''),
		Razon_Cita=isnull(ct2.razon_cita,''),
		Tipo_cita=isnull(ct2.Tipo,''),
		[CANAL SERVICIO]=
		CASE
			   when b.id_usuario_jefe is not null then 'VENTAS TALLER '  + isnull(CASE 
																		 WHEN  d.facturar_a in ('C','O') then 'CLIENTE'
																   		 WHEN  d.facturar_a in ('G') then 'GARANTÍA'
																		 WHEN  d.facturar_a NOT IN ('C','G') then 'INTERNO'
																		 ELSE ''
																	   END,'MECANICA')	
																	   +  ' ' +
																	  ISNULL( case 
																			when  d.tipo_operacion in ('L','P') THEN  'COLISIÓN'
																			when  d.tipo_operacion in ('0','M') THEN  'MECÁNICA'
																			when  d.tipo_operacion in ('I') THEN  'MECÁNICA'
																			when  d.tipo_operacion in ('O') THEN  'MECÁNICA'


																		end ,'MECANICA')

		END,
		d.ot_final,-----AGREGAR OT FINAL DE GARANTIAS Y CONSOLIDADAS
		clase_operacion = d.tipo_orden,
		Notas=dbo.RTF2Text(d.notas),
		tipo_tarea=case when g.descripcion='REPUESTOS'  or g.descripcion='ACCESORIOS'
						THEN 'V' 
						ELSE 
							CASE WHEN i.costo_emergencia<>0 AND ABS(i.precio)<>0
								THEN
									'V'
								ELSE
									'T'
								END
						END



    INTO #Resultado
	FROM #docs d
	JOIN @LINEA line ON line.id_item = d.id_cot_item 
	JOIN dbo.cot_tipo t ON t.id = d.id_cot_tipo 
	JOIN @Bodega b1 ON b1.id = d.id_cot_bodega 
	JOIN cot_bodega b on b.id = b1.id 
	JOIN dbo.cot_cotizacion cb ON cb.id = d.id
	JOIN dbo.cot_bodega bod ON bod.id = cb.id_cot_bodega

	JOIN cot_zona_sub zs on zs.id=b.id_cot_zona_sub
	join cot_zona z on z.id=zs.id_cot_zona
	LEFT JOIN dbo.com_orden_concep co ON co.id = d.id_com_orden_concepto
	JOIN dbo.cot_cliente cc ON cc.id = d.id_cot_cliente
	LEFT JOIN dbo.cot_cliente_perfil cp ON cp.id = cc.id_cot_cliente_perfil
	LEFT JOIN dbo.usuario u ON u.id = d.id_usuario_ven
	JOIN dbo.cot_item i ON i.id = d.id_cot_item --AND i.maneja_stock IN (0)
	left JOIN dbo.cot_item_talla lr on lr.id = i.id_cot_item_talla
	--LEFT JOIN @tipoinventario ti
	--ON ti.id = i.maneja_stock
	LEFT JOIN dbo.cot_item_lote il ON il.id_cot_item = d.id_cot_item AND 
	   il.id = d.id_cot_item_lote
	JOIN dbo.cot_grupo_sub s ON s.id = i.id_cot_grupo_sub
	JOIN dbo.cot_grupo g ON g.id = s.id_cot_grupo
	LEFT JOIN dbo.cot_forma_pago fp ON fp.id = d.id_forma_pago
	LEFT JOIN @devoluciones dv ON dv.id = d.id
	LEFT JOIN dbo.ecu_tipo_comprobante et ON et.id = t.id_ecu_tipo_comprobante
	LEFT JOIN dbo.cot_grupo_sub5 s5 ON s5.id = i.id_cot_grupo_sub5
	LEFT JOIN dbo.cot_grupo_sub4 s4 ON s4.id = s5.id_cot_grupo_sub4
	LEFT JOIN dbo.cot_grupo_sub3 s3 ON s3.id = s4.id_cot_grupo_sub3
	--LEFT JOIN @facot ot ON ot.id = d.id
	LEFT JOIN cot_cliente_contacto ccc ON ccc.id = d.id_cot_cliente_contacto AND 
	   ccc.id_cot_cliente = d.id_cot_cliente
	LEFT JOIN #docco dcc ON dcc.id = d.id AND 
	   dcc.id_cot_tipo = d.id_cot_tipo
	--LEFT JOIN @FacConDev fv on fv.id=d.id

	LEFT JOIN cot_item_talla tl on tl.id=i.id_cot_item_talla
	LEFT JOIN dbo.v_cot_cotizacion_item_dev2 dev ON dev.id_cot_cotizacion_item = d.id_cot_cotizacion_item
		AND dev.cantidad_devuelta<>0
	LEFT JOIN dbo.v_campos_varios va ON va.id_cot_item=i.id
	--left join  #vhtaller vt  on vt.id=d.id
	--------------------------------------
	LEFT JOIN dbo.cot_cotizacion cct  on cct.id=d.id_cot_cotizacion_sig
	LEFT join cot_item_lote ih on ih.id=d.id_cot_item_vhtal
	LEFT join cot_item ic on ic.id=ih.id_cot_item
	left Join veh_linea_modelo l on l.id=ic.id_veh_linea_modelo
	left Join veh_linea v on v.id=ic.id_veh_linea
	left Join veh_marca m on m.id=v.id_veh_marca
	LEFT JOIN cot_item_talla ct on ct.id=ic.id_cot_item_talla
	left join v_campos_varios cv6 on cv6.id_cot_item_lote=ih.id
	--------------------------------------------
	LEFT JOIN dbo.cot_cotizacion_mas cmas ON cmas.id_cot_cotizacion=cct.id
	--------------------------------------------
	LEFT JOIN cot_item_lote vhl ON VHl.id=cct.id_cot_item_lote
	LEFT JOIN v_campos_varios cv On cv.id_cot_cotizacion=cct.id and cv.campo_1 is not null
	left Join veh_color col on vhl.id_veh_color=col.id
	left Join veh_color col2 on ih.id_veh_color_int=col2.id
	LEFT join cot_item ic2 on ic2.id=vhl.id_cot_item
	left Join veh_linea_modelo l2 on l2.id=ic2.id_veh_linea_modelo
	left Join veh_linea v2 on v2.id=ic2.id_veh_linea
	left Join veh_marca m2 on m2.id=v2.id_veh_marca
	LEFT JOIN cot_item_talla ct3 on ct3.id=ic2.id_cot_item_talla
	left join v_campos_varios cv7 on cv7.id_cot_item_lote=vhl.id
	LEFT JOIN dbo.usuario up ON up.id = d.id_operario
	--LEFT JOIN cot_item cvh ON cvh.id=cct.id_cot_item
	LEFT JOIN cot_cliente_contacto cli on cli.id=vhl.id_cot_cliente_contacto
	LEFT JOIN dbo.cot_cliente cli2 ON cli2.id = cct.id_cot_cliente2
	LEFT JOIN dbo.cot_cliente cli3 ON cli3.id = cli.id_cot_cliente and cli3.id_emp=@emp
	LEFT JOIN cot_bodega_ubicacion ubi ON ubi.id=cct.id_cot_bodega_ubicacion
	LEFT JOIN #RtosPLista pl ON pl.id=d.id and pl.id_cot_cotizacion_item=d.id_cot_cotizacion_item and pl.id_cot_item=d.id_cot_item
	LEFT JOIN cot_item_color gen ON gen.id=i.id_cot_item_color
	LEFT JOIN #flotasTaller	 flo ON flo.id = d.id and flo.id_cot_item_vhtal=d.id_cot_item_vhtal
	LEFT JOIN tal_flota_precios tfpr on tfpr.id_tal_flota= flo.id_tal_flota AND tfpr.id_cot_item_ope =i.id
	--LEFT JOIN #citas2 ct2 ON ct2.ot=cct.id AND ct2.id_cot_bodega = b.id 
	LEFT JOIN #citas2 ct2 on (ct2.ot = cct.id AND ct2.id_cot_bodega = b.id and cct.id not in (559280))

	LEFT JOIN #razon_ingreso ri ON ri.id=cct.id_tal_motivo_ingreso
	LEFT JOIN cot_cotizacion tras on tras.id=pl.id2
	LEFT JOIN usuario ust on ust.id = tras.id_usuario_vende
	LEFT JOIN @bodegas_reglas_negocio brn on d.id_cot_bodega = brn.id_cot_bodega_rn
	LEFT JOIN @Info_Compras_TOTs tot on tot.id_fac_nc = d.id 
	                                   and tot.sw = d.sw 
									   and tot.id_ot = d.id_cot_cotizacion_sig 
									  -- and tot.id_cot_item = d.id_cot_item
									   and d.id_cot_cotizacion_item = tot.id_cot_cotizacion_item
									   and d.tipo_operacion = tot.tipo_operacion collate SQL_Latin1_General_CP1_CI_AS

	WHERE line.linea <> 'VEHICULOS' 
	
	SELECT *
	FROM #Resultado r 
	--where r.Id_Documento = 354147;
	
	