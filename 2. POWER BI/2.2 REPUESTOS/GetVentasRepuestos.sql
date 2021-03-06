USE [dms_smd3]
GO
/****** Object:  StoredProcedure [dbo].[GetVentasRepuestos]    Script Date: 11/2/2022 12:38:59 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



-- =================================================================================================================================================================
-- Author:		<Angelica .>
-- Create date: <0000-00-00>
-- Modulo:		<Reporteria>
-- Description:	<Procedimiento para obtener informacion detallada de Ventas de Repuestos,  (Reporte 100025 Advance)
-- Historial de Cambios:
-- 2021-07-06	Se modifica el campo CONCEPTO para obtener unicamente los valores Mostrador, Externas, Taller y Vehiculos (JCH)
-- 2021-07-06	Se agrega la tabla temporal linea, y se modifica el campo LINEA para obtener la linea de negocio sin quemar los elementos en el código
--				Se cambian las tablas temporales por tablas del tipo # debido a la velocidad de respuesta
-- 2021-07-07   Agregacion del campo SUBGRUPO3 (JCH)
-- 2021-08-24   Se cambia el nombre del campo Marca por MarcaVH_original (JCH)
-- 2021-08-24   Se modifica el campo CONCEPTO para obtener el "Canal de Venta" de igual manera como se obtiene en el BI. (JCHB)
-- 2021-08-24   Se agrega el campo MarcaVH que contiene las marcas del Negocio (Chevrolet, GAC, VolksWagen y Multimarca)
-- 2021-09-14   Agregacion de los campos TELEFONO, EMAIL Y DIRECCION DEL CLIENTE (JCHB)
-- 2021-10-25   Al igual que el reporte 100017, se ajusta el SP para la distribucion de bodegas en los Items de las Notas de Credito a Facturas Consolidadas (JCB)
-- 22/nov/2021	Se modifica para que se obtenga la bodega de los Items de la factura, tal como se visualiza en la opcion de Advance 1104 (JCB)
-- 06/DIC/2021	Se agrega el NIT del Vendedor y NIT del Cliente (JCB)
-- 11/02/2022	Se agregan las ventas por el grupo Aplicaciones (JCB)
-- =================================================================================================================================================================

-- EXEC [dbo].[GetVentasRepuestos] 605,0,'20220101','20220131',0

alter PROCEDURE [dbo].[GetVentasRepuestos]
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

	DECLARE @Devoluciones AS TABLE
	(
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
	select distinct r.id_emp,
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
	

   --select COUNT(*) from @bodegas_reglas_negocio
   -- EXEC [dbo].[GetVentasRepuestos_advance] 605,0,'2021-11-01','2021-11-22',0

	------------------------------------------------------------------------------------
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

	--IF @Bod = '0'
	--begin
	--	INSERT @Bodega
	--	(
	--		id,
	--		descripcion,
	--		ecu_establecimiento
	--	)
	--	SELECT id,
	--		   descripcion,
	--		   ecu_establecimiento
	--	FROM dbo.cot_bodega
	--	where id_emp=@emp
	--end
	--ELSE
	--BEGIN

	--	INSERT @Bodega
	--	(
	--		id,
	--		descripcion,
	--		ecu_establecimiento
	--	)
	--	SELECT DISTINCT x.id_cot_bodega,
	--	       x.descripcion,
	--		   x.ecu_establecimiento
	--	FROM
	--	(
	--		SELECT id_cot_bodega = CAST(f.val AS INT),
	--			   c.descripcion,
	--			   c.ecu_establecimiento
	--		FROM dbo.fnSplit(@Bod, ',') f
	--			JOIN dbo.cot_bodega c
	--				ON c.id = CAST(f.val AS INT)
	--		UNION ALL
	--		select rn.id_cot_bodega_rn,
	--			   rn.descripcion_rn,
	--			   bod.ecu_establecimiento
	--		from @Bodega b
	--		join @bodegas_reglas_negocio rn on (b.id = rn.id_cot_bodega)
	--		join cot_bodega bod on bod.id = rn.id_cot_bodega_rn
	--	)x
	--END

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
	    
		-- Se obtienen la bodegas no duplicadas ya que afecta el numero de registros del reporte
		--INSERT @Bodega
		--(
		--	id,
		--	descripcion,
		--	ecu_establecimiento
		--)
		--SELECT DISTINCT x.id_cot_bodega,
		--       x.descripcion,
		--	   x.ecu_establecimiento
		--FROM
		--(
		--	SELECT id_cot_bodega = CAST(f.val AS INT),
		--		   c.descripcion,
		--		   c.ecu_establecimiento
		--	FROM dbo.fnSplit(@Bod, ',') f
		--		JOIN dbo.cot_bodega c
		--			ON c.id = CAST(f.val AS INT)
		--	UNION ALL
		--	select rn.id_cot_bodega_rn,
		--		   rn.descripcion_rn,
		--		   bod.ecu_establecimiento
		--	from @Bodega b
		--	join @bodegas_reglas_negocio rn on (b.id = rn.id_cot_bodega)
		--	join cot_bodega bod on bod.id = rn.id_cot_bodega_rn
		--)x


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
	end

   
	-- RAZONES DE INGRESO
	SELECT * 
	INTO #razon_ingreso
	FROM dbo.tal_motivo_ingreso
	where id_emp=@emp 

	--select COUNT(*) from #razon_ingreso
   -- EXEC [dbo].[GetVentasRepuestos_advance] 605,0,'2021-11-01','2021-11-22',0
   
   	  
	--------- NUEVO PROCESO DE GARANTIAS Y CONSOLIDADAS---------------------------------------------
	create table #OTs_CONSOLIDADAS_GARATIAS
	(
		id_factura int,
		IdOrden int
	)

	insert #OTs_CONSOLIDADAS_GARATIAS
	exec [dbo].[GetOrdenesFacturasTaller] @emp,0,@fecIni,@fecFin

	create table #OTs_CONSOLIDADAS_GARATIAS_NC (
		id_factura int,
		IdOrden int
	)
	insert #OTs_CONSOLIDADAS_GARATIAS_NC exec [dbo].[GetOrdenesNCTaller] @emp,0

	--select COUNT(*) from #OTs_CONSOLIDADAS_GARATIAS
   -- EXEC [dbo].[GetVentasRepuestos_advance] 605,0,'2021-11-01','2021-11-22',0

   	--select COUNT(*) from #OTs_CONSOLIDADAS_GARATIAS_NC
   -- EXEC [dbo].[GetVentasRepuestos_advance] 605,0,'2021-10-15','2021-10-30',0

   
	-----PRIMERA INSERCION EN DOCS --------------------------------------------------------
	CREATE TABLE #Docs
	(
		id INT,
		id_cot_tipo INT,
		id_cot_bodega INT,
		id_cot_cliente INT,
		id_cot_cliente_contacto INT,
		numero_cotizacion INT,
		fecha DATE,
		notas VARCHAR(1000),
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
		   v.id_cot_bodega,
		   c.id_cot_cliente,
		   c.numero_cotizacion,
		   c.fecha,
		   c.notas,
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
	--join cot_item i on i.id = ci.id_cot_item 
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
	

   --select COUNT(*) from #docs
   -- EXEC [dbo].[GetVentasRepuestos_advance] 605,0,'2021-11-01','2021-11-22',0

   
	------------------------------INSERTAMOS EN DOCS LA INFROMACION DE GARANTIAS Y CONSOLIDADAS------------------------
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


	--select COUNT(*) from #detdatos
    -- EXEC [dbo].[GetVentasRepuestos_advance] 605,0,'2021-11-01','2021-11-22',0

	
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
		ot_id_orden=isnull(c3.idv,c2.id),
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
		
	--select COUNT(*) from #detad
    -- EXEC [dbo].[GetVentasRepuestos_advance] 605,0,'2021-10-15','2021-10-30',0

    
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
		cc.notas,
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

	--Validacion Fac con devolución
	--insert @FacConDev
	--(id, tiene)
	--select distinct 
	--d.id, 
	--tipo= case when tv.tiene_devol=1 then 'Si' else 'No' end
	--from #Docs d
	--JOIN dbo.v_cot_tiene_devolucion tv ON tv.id_cot_cotizacion = d.id
	-- where d.sw=1

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

	-----PARA SACAR EL CANAL (DE ACUERDO AL CONCEPTO DE LA VENTA EN REPUESTOS)-----------------
	CREATE TABLE #docco
	(
		id INT,
		id_cot_tipo INT,
		codcentro VARCHAR(100),
		cuota_nro int
	)
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
	CREATE TABLE #RtosPLista
	(
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

	--select id_componenteprincipalest, * from cot_cotizacion_item where id_cot_cotizacion = 51499 and id= 25823076
	--select * from cot_cotizacion_item where id= 25823076

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

	---- @LINEA - INSERTAMOS LA LINEA DE LOS ITEMS DEL GRUPO REPUESTOS, TALLER Y TOT
	DECLARE @LINEA AS TABLE
	(
		id_item INT,
		linea VARCHAR(50)
	)
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
	WHERE grup.id IN (1332, 1341, 1343, 1345)
	GROUP BY item.id, grup.descripcion, grup.id, gsub.descripcion;

	
	----- SELECT FINAL -----
	SELECT	SW = ct.sw, 
		ZONA = CASE WHEN zs.descripcion ='NORTE' THEN 'ZONA 1'
					WHEN z.descripcion = 'COSTA' AND zs.descripcion IN ('CENTRO', 'SUR') THEN 'ZONA 2'
					WHEN z.descripcion = 'SIERRA' AND zs.descripcion IN ('SUR') THEN 'ZONA 3'
		END,
		--BODEGA = tb.descripcion,
		Bodega = CASE when b.id in (select rn.id_cot_bodega_rn from @bodegas_reglas_negocio rn) then brn.descripcion else b.descripcion end,
		LINEA_NEGOCIO = line.linea,
		ID_FACTURA_NC_D = td.id,
		NUMERO_DOCUMENTO = td.numero_cotizacion,
		FACTURA = CASE
			WHEN ct.sw = -1 THEN tde.factura
			ELSE CAST (ISNULL (tb.ecu_establecimiento, '') AS VARCHAR(4)) + CAST (ISNULL (ct.ecu_emision, '') AS VARCHAR(4)) COLLATE modern_spanish_ci_ai + '' + RIGHT ('000000000' + CAST (td.numero_cotizacion AS VARCHAR(100)), 9)
		END,
		FECHA = td.fecha,
		NRO_ORDEN = ISNULL (td.id_cot_cotizacion_sig, 0),
		TIPO_ORDEN = ISNULL(vcv3.campo_1, ''), 
		CLIENTE = ccl.razon_social,
		NIT_CLIENTE = ccl.nit,
		TELEFONO = ISNULL(ccl.tel_1,ccl.tel_2),
		EMAIL = ccl.[url],
		DIRECCION = ccl.direccion,
		SERIE = ISNULL (cil3.chasis, ''),
		VEHICULO = ISNULL (ci3.descripcion, ''),
		PLACA = ISNULL (cil3.placa, ''),
		MarcaVH_original = ISNULL (ISNULL ((CASE
			WHEN vm1.descripcion LIKE '%MULTIMARCA' THEN
				CASE
					WHEN vcv2.campo_11 = '' OR vcv2.campo_11 IS NULL THEN vm1.descripcion
					ELSE SUBSTRING (vcv2.campo_11,3, 100)
				END
			ELSE 
				CASE
					WHEN ci2.codigo LIKE '%ALL%' THEN
						CASE
							WHEN vcv2.campo_11 = '' OR vcv2.campo_11 IS NULL THEN vm1.descripcion
							ELSE SUBSTRING (vcv2.campo_11,3, 100)
						END
					ELSE vm1.descripcion
				END
		END),
		(CASE
			WHEN vm2.descripcion LIKE '%MULTIMARCA%' THEN
				CASE
					WHEN vcv4.campo_11 = '' OR vcv4.campo_11 IS NULL THEN vm2.descripcion
					ELSE SUBSTRING (vcv4.campo_11,3, 100)
				END
			ELSE 
				CASE
					WHEN ci3.codigo LIKE '%ALL%' THEN
						CASE
							WHEN vcv4.campo_11 = '' OR vcv2.campo_11 IS NULL THEN vm2.descripcion
							ELSE SUBSTRING (vcv4.campo_11,3, 100)
						END
					ELSE vm2.descripcion
				END
		END)), ''),
		LINEA_VH = ISNULL (ISNULL (cit2.descripcion, cit3.descripcion), ''),
		ORIGINAL_ALTERNO = ISNULL(vcv1.campo_5, ''),
		
		VENDEDOR = CASE 
						WHEN td.id_cot_cotizacion_sig <> 0 THEN ust.nombre
				        ELSE uv.nombre 
				   END, --DE LA ORDEN ORIGINAL
		NIT_VENDEDOR = CASE 
						WHEN td.id_cot_cotizacion_sig <> 0 THEN ust.cedula_nit
				        ELSE uv.cedula_nit 
				   END, --DE LA ORDEN ORIGINAL
		
		CARGO_VENDEDOR = 
		 CASE WHEN   td.id_cot_cotizacion_sig <>0
				THEN 
					car2.descripcion
				else car.descripcion end, --DE LA ORDEN ORIGINAL
		RAZON_INGRESO = ISNULL (tri.descripcion, ''),
		--OPERARIO = ISNULL (uo.nombre, ''),
		CODIGO = ci1.codigo,
		LINEA_REP=citr.descripcion,
		DESCRIPCION = ci1.descripcion,
		CLASIFICACION_CATEGORIA = ISNULL(cic.descripcion, ''),
		GRUPO = cg.descripcion,
		SUBGRUPO = cgs.descripcion,
		
		CANTIDAD = td.cantidad_und, 
		PRECIO = CASE WHEN td.sw = -1 THEN td.precio_cotizado * -1
			ELSE td.precio_lista
		END,
		precio_lista=td.precio_lista,
		precio_cotizado=td.precio_cotizado,
		COSTO = --CASE WHEN td.sw = -1 THEN td.precio_cotizado * -1
			--ELSE 
			td.costo*case when td.sw = -1 then -1 else 1 end,
		--END,
		COSTO_TOTAL = td.costo * td.cantidad_und,
		--PRECIO_BRUTO = (td.precio_lista * td.cantidad_und)* case when td.sw = -1 then -1 else 1 end,
		PRECIO_BRUTO = CONVERT (DECIMAL(18,2),(case 
                            when (td.precio_lista * cantidad_und) - ((isnull((abs(td.cantidad_und)*abs(td.precio_lista)*
                            (td.porcentaje_descuento) / 100),0))* case when td.sw = 1 then 1 else -1 end) = (abs(precio_cotizado) * abs(cantidad_und))
                            then convert(DECIMAL(18,2),abs(td.cantidad_und)*abs(td.precio_lista)*case when td.sw=1 then 1 else -1 end)
                            else ((abs(td.precio_cotizado) *abs(case when td.cantidad_und = 0 then 1 else td.cantidad_und end ))* case when td.sw = 1 then 1 else -1 end) +
                            ((isnull((abs(td.cantidad_und)*abs(td.precio_lista)*
                            (td.porcentaje_descuento)/100),0))* case when td.sw = 1 then 1 else -1 end)
                    end)),
		_DESCUENTO = ISNULL (td.porcentaje_descuento, 0),
		DESCUENTO = ISNULL (((td.precio_lista * td.cantidad_und) * td.porcentaje_descuento) / 100, 0),
		PRECIO_NETO = ( ABS (td.precio_cotizado) 
						* ABS (case when td.cantidad_und = 0 then 1 
							else td.cantidad_und end))
						* case when td.sw=1 then 1 else -1 end,
		_IVA = ISNULL (td.porcentaje_iva, 0),
		IVA = ISNULL (((td.precio_cotizado * td.cantidad_und) * td.porcentaje_iva) / 100, 0),
		TOTAL = CASE WHEN td.sw = -1 THEN (( ABS (td.precio_cotizado * ( 1 + td.porcentaje_iva / 100 ))
						* ABS (case when td.cantidad_und = 0 then 1 
							else td.cantidad_und end))
						* case when td.sw = 1 then 1 else -1 end) * -1
				ELSE ( ABS (td.precio_cotizado * ( 1 + td.porcentaje_iva / 100 ))
						* ABS (case when td.cantidad_und = 0 then 1 
							else td.cantidad_und end))
						* case when td.sw = 1 then 1 else -1 end
		END,
		--CONCEPTO = CASE WHEN ct.sw = -1	THEN ISNULL (tde.concepto, '') ELSE ISNULL (coc.descripcion, '') END
		CONCEPTO = CASE 
				WHEN ct.sw = 1 THEN
				CASE
					WHEN tb.descripcion LIKE '%TAL%' THEN CASE	
															WHEN ISNULL(vcv3.campo_1, '') LIKE '%Latoner%' then 'Latonería' 
															ELSE 'Mecánica'
															END

					WHEN tb.descripcion LIKE '%VEH%' AND cg.descripcion = 'REPUESTOS' AND ISNULL(vcv3.campo_1, '') = '' THEN 'Mostrador'
					WHEN tb.descripcion LIKE '%VEH%' AND cg.descripcion IN ('ACCESORIOS','DISPOSITIVOS') AND ISNULL(vcv3.campo_1, '') = '' THEN 'Vehiculos'

					--WHEN tb.descripcion LIKE '%REP%' AND cg.descripcion = 'REPUESTOS' AND ISNULL(vcv3.campo_1, '') = '' AND coc.descripcion = 'TALLER' THEN 'MECANICA'
					ELSE IIF(coc.descripcion = 'TALLER','Mecánica',ISNULL(coc.descripcion,'Otro Canal'))
				END
				WHEN ct.sw = -1 THEN
				case
					WHEN tb.descripcion LIKE '%TAL%' THEN CASE	
															WHEN ISNULL(vcv3.campo_1, '') LIKE '%Latoner%' then 'Latonería' 
															ELSE 'Mecánica'
															END
					WHEN tb.descripcion LIKE '%VEH%' AND cg.descripcion = 'REPUESTOS' AND ISNULL(vcv3.campo_1, '') = '' THEN 'Mostrador'
					WHEN tb.descripcion LIKE '%VEH%' AND cg.descripcion IN ('ACCESORIOS','DISPOSITIVOS') AND ISNULL(vcv3.campo_1, '') = '' THEN 'Vehiculos'
					ELSE IIF(coc.descripcion = 'TALLER','Mecánica',
					IIF(ISNULL(coc.descripcion,'') = '' AND ISNULL(tde.concepto,'') = '','Otro Canal',ISNULL(coc.descripcion,tde.concepto)))
					--ISNULL(ISNULL(coc.descripcion,tde.concepto),'Otro Canal'))

					--ELSE ISNULL(ISNULL (coc.descripcion,tde.concepto),'')
				end
						
			END
	INTO #Resultado
	FROM #Docs td
			JOIN dbo.cot_tipo ct ON ct.id = td.id_cot_tipo
			JOIN @Bodega tb ON tb.id = td.id_cot_bodega
			JOIN cot_bodega b on b.id = tb.id 
			JOIN cot_zona_sub zs on zs.id = b.id_cot_zona_sub
			JOIN cot_zona z on z.id=zs.id_cot_zona
	JOIN @LINEA line ON line.id_item = td.id_cot_item 
	LEFT JOIN dbo.com_orden_concep coc ON coc.id = td.id_com_orden_concepto
			 JOIN dbo.cot_cliente ccl ON ccl.id = td.id_cot_cliente
	LEFT JOIN dbo.cot_cliente_perfil ccp ON ccp.id = ccl.id_cot_cliente_perfil
	LEFT JOIN dbo.usuario uv ON uv.id = td.id_usuario_ven
			 JOIN dbo.cot_item ci1 ON ci1.id = td.id_cot_item 
			 LEFT JOIN dbo.cot_item_talla citr on citr.id=ci1.id_cot_item_talla and citr.id_emp=@emp
	LEFT JOIN dbo.cot_item_lote cil1 ON cil1.id_cot_item = td.id_cot_item AND cil1.id = td.id_cot_item_lote
			 JOIN dbo.cot_grupo_sub cgs ON cgs.id = ci1.id_cot_grupo_sub
			 JOIN dbo.cot_grupo cg ON cg.id = cgs.id_cot_grupo
	LEFT JOIN dbo.cot_forma_pago cfp ON cfp.id = td.id_forma_pago
	LEFT JOIN @Devoluciones tde ON tde.id = td.id
	LEFT JOIN dbo.ecu_tipo_comprobante etc ON etc.id = ct.id_ecu_tipo_comprobante
	LEFT JOIN dbo.cot_grupo_sub5 cgs5 ON cgs5.id = ci1.id_cot_grupo_sub5
	LEFT JOIN dbo.cot_grupo_sub4 cgs4 ON cgs4.id = cgs5.id_cot_grupo_sub4
	LEFT JOIN dbo.cot_grupo_sub3 cgs3 ON cgs3.id = cgs4.id_cot_grupo_sub3
	LEFT JOIN cot_cliente_contacto ccc1 ON ccc1.id = td.id_cot_cliente_contacto AND ccc1.id_cot_cliente = td.id_cot_cliente
	LEFT JOIN dbo.cot_item_talla cit1 ON cit1.id = ci1.id_cot_item_talla
	LEFT JOIN dbo.v_cot_cotizacion_item_dev2 vccif ON vccif.id_cot_cotizacion_item = td.id_cot_cotizacion_item AND vccif.cantidad_devuelta <> 0
	LEFT JOIN dbo.v_campos_varios vcv1 ON vcv1.id_cot_item = ci1.id
	LEFT JOIN dbo.cot_cotizacion cc ON cc.id = td.id_cot_cotizacion_sig
	--LEFT JOIN dbo.cot_cotizacion_item cci ON cci.id = td.id_item_orden
	--LEFT JOIN dbo.cot_cotizacion_item ccd ON ccd.id = td.id_item_orden_devolucion
	LEFT JOIN dbo.cot_item_lote cil2 ON cil2.id = td.id_cot_item_vhtal
	LEFT JOIN dbo.cot_item ci2 ON ci2.id = cil2.id_cot_item
	LEFT JOIN dbo.veh_linea_modelo vlm1 ON vlm1.id = ci2.id_veh_linea_modelo
	LEFT JOIN dbo.veh_linea vl1 ON vl1.id = ci2.id_veh_linea
	LEFT JOIN dbo.veh_marca vm1 ON vm1.id = vl1.id_veh_marca
	LEFT JOIN dbo.cot_item_talla cit2 ON cit2.id = ci2.id_cot_item_talla
	LEFT JOIN dbo.v_campos_varios vcv2 ON vcv2.id_cot_item_lote = cil2.id
	LEFT JOIN dbo.cot_cotizacion_mas ccm ON ccm.id_cot_cotizacion = cc.id
	LEFT JOIN dbo.cot_item_lote cil3 ON cil3.id = cc.id_cot_item_lote
	LEFT JOIN dbo.v_campos_varios vcv3 ON vcv3.id_cot_cotizacion = cc.id AND vcv3.campo_1 IS NOT NULL
	LEFT JOIN dbo.veh_color vc1 ON cil3.id_veh_color = vc1.id
	LEFT JOIN dbo.veh_color vc2 ON cil2.id_veh_color_int = vc2.id
	LEFT JOIN dbo.cot_item ci3 ON ci3.id = cil3.id_cot_item
	LEFT JOIN dbo.veh_linea_modelo vlm2 ON vlm2.id = ci3.id_veh_linea_modelo
	LEFT JOIN dbo.veh_linea vl2 ON vl2.id = ci3.id_veh_linea
	LEFT JOIN dbo.veh_marca vm2 ON vm2.id = vl2.id_veh_marca
	LEFT JOIN dbo.cot_item_talla cit3 ON cit3.id = ci3.id_cot_item_talla
	LEFT JOIN dbo.v_campos_varios vcv4 ON vcv4.id_cot_item_lote = cil3.id
	LEFT JOIN dbo.usuario uo ON uo.id = td.id_operario
	LEFT JOIN dbo.cot_item ci4 ON ci4.id = cc.id_cot_item
	LEFT JOIN dbo.cot_cliente_contacto ccc2 ON ccc2.id = cil3.id_cot_cliente_contacto
	LEFT JOIN dbo.cot_cliente ccla ON ccla.id = cc.id_cot_cliente2
	LEFT JOIN dbo.cot_cliente cclp ON cclp.id = ccc2.id_cot_cliente AND cclp.id_emp = 605
	LEFT JOIN dbo.cot_bodega_ubicacion cbu ON cbu.id = cc.id_cot_bodega_ubicacion
	LEFT JOIN dbo.cot_item_color cic ON cic.id = ci1.id_cot_item_color
	LEFT JOIN #razon_ingreso tri ON tri.id = cc.id_tal_motivo_ingreso
	LEFT JOIN usuario_cargo car ON car.id = uv.id_usuario_cargo
	LEFT JOIN #RtosPLista pl ON pl.id=td.id and pl.id_cot_cotizacion_item=td.id_cot_cotizacion_item and pl.id_cot_item=td.id_cot_item
	LEFT JOIN cot_cotizacion tras on tras.id=pl.id2
	LEFT JOIN usuario ust on ust.id = tras.id_usuario_vende
	LEFT JOIN usuario_cargo car2 ON car2.id = ust.id_usuario_cargo
	LEFT JOIN @bodegas_reglas_negocio brn on td.id_cot_bodega = brn.id_cot_bodega_rn
	WHERE line.linea IN ('REPUESTOS','ACCESORIOS','DISPOSITIVOS','APLICACIONES')

	------------------------------------------
	----------RESULTADO-----------------------
	------------------------------------------
	SELECT r.SW,
		   r.ZONA,
		   r.BODEGA,
		   r.LINEA_NEGOCIO,
		   r.ID_FACTURA_NC_D,
		   r.NUMERO_DOCUMENTO,
		   r.FACTURA,
		   r.FECHA,
		   r.NRO_ORDEN,
		   r.TIPO_ORDEN,
		   r.CLIENTE,
		   r.NIT_CLIENTE,
		   r.TELEFONO,
		   r.EMAIL,
		   r.DIRECCION,
		   r.SERIE,
		   r.VEHICULO,
		   r.PLACA,
		   r.MarcaVH_original,
		   r.LINEA_VH,
		   r.ORIGINAL_ALTERNO,
		   r.VENDEDOR,
		   r.NIT_VENDEDOR,
		   r.CARGO_VENDEDOR,
		   r.RAZON_INGRESO,
		   r.CODIGO,
		   r.LINEA_REP,
		   r.DESCRIPCION,
		   r.CLASIFICACION_CATEGORIA,
		   r.GRUPO,
		   r.SUBGRUPO,
		   r.CANTIDAD,
		   r.PRECIO,
		   r.precio_lista,
		   r.precio_cotizado,
		   r.COSTO,
		   r.COSTO_TOTAL,
		   r.PRECIO_BRUTO,
		   r._DESCUENTO,
		   r.DESCUENTO,
		   r.PRECIO_NETO,
		   r._IVA,
		   r.IVA,
		   r.TOTAL,
		   r.CONCEPTO,
           Marca_VH =  CASE WHEN r.Tipo_orden like '%Mec%nica%' OR r.Tipo_orden like '%Latoner%' OR r.Tipo_orden like '%Garant%' THEN 
			                               CASE WHEN r.MarcaVH_original LIKE '%CHEVROLET%' THEN 'Chevrolet'
									            WHEN r.MarcaVH_original LIKE '%GAC%' THEN 'Gac'
									            WHEN r.MarcaVH_original LIKE '%VOLKSWAGEN%' THEN 'VolksWagen'
									            WHEN r.MarcaVH_original LIKE '%MULTIMARCA%' THEN 'Multimarca'
										        ELSE 'Multimarca'
                                           END
									  ELSE r.MarcaVH_original
								 END
	FROM #Resultado r
	