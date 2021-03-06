USE [dms_smd3]
GO
/****** Object:  StoredProcedure [dbo].[BI_T_GetVentasResumidoTaller]    Script Date: 8/5/2022 22:58:19 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =====================================================================================================================
-- Author:		<Angelica Pinos>
-- Create date: <2021-00-00>
-- Modulo:		<Reporteria>
-- Description:	<Procedimiento para obtener informacion resumida de las ventas tanto repuestos como taller y tot,  (Reporte 100021 Advance)
-- Historial de Cambios:
-->	27/07/2021 --> Se agrega un procedimiento para obtener las ordenes de garantias y consolidados	
--> 19/08/2021 --> Se elimina la tabla temporal #Vehiculos ya que no se esta utilizando en el Repore (APF / JCHB)
--> 19/08/2021 --> Se cambia el tipo de tabla de temporal #Devoluciones a tabla de sesion @Devoluciones  (APF / JCHB)
--> 20/08/2021 --> Se agrega join con la tabla temporal @LINEA la cual almacena los Items con los grupos: (JCHB)
-->					REPUESTOS
-->					ACCESORIOS
-->					DISPOSITIVOS
-->					TALLER
-->					TRABAJOS OTROS TALLERES
--> 27/08/2021 --> Se cambia el nombre del campo MARCA_VH por MarcaVH_original (JCHB)
--> 27/08/2021 --> Se agrega el campo MARCA_VH que contiene unicamente las marcas que maneja el Negocio (Chevrolet, GAC, VolksWagen y Multimarca) (JCHB)
--> 02/09/2021 --> Se agrega un join con cot_forma_pago y se obtiene la columna con la descripción de la forma de pago (APF)
--> 18/10/2021 --> Se modifica el tipo del campo FECHAFACTURA de date por datetime (JCB) 
--> 15/11/2021 --> Se agregan los campos FAC_ORIGINAL y FECHA_FAC_ORIGINAL que se require para el calculo de las Unidades por Taller (JCB)
--> 22/02/2022 --> Se modifica el campo razon_social a 200 carcateres por un cambio en el sistema DMS (JCB)
--> 22/02/2022 --> Se agrega el campo estado_ot (JCB)
--> 24/02/2022 --> Se agrega el campo numero_cotizacion (JCB)
--> 2022-03-10 --> Se corrige el tamaño del campo notas (JCB)
--> 09/MAY/2022 --> Se agrega las ventas del Grupo Aplicaciones (JCB)
-- =====================================================================================================================

-- exec [dbo].[BI_T_GetVentasResumidoTaller] 605,'0','2022-03-01','2022-03-31',0
        
ALTER PROCEDURE [dbo].[BI_T_GetVentasResumidoTaller]
(
	@emp INT,
	@Bod VARCHAR(MAX),
	@fecIni DATE,
	@fecFin DATE,
	@cli INT=0
)
AS

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DECLARE @Bodega AS TABLE 
	(
		id INT,
		descripcion VARCHAR(200),
		ecu_establecimiento VARCHAR(6),
		id_emp int
	)

	DECLARE @BodegasSplit AS TABLE 
	(
		id INT,
		descripcion VARCHAR(200),
		ecu_establecimiento VARCHAR(6),
		id_emp int
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
	inner join cot_bodega b_rep on cast(substring(r.llave,4,4) as INT) = b_rep.id
	inner join cot_bodega b_consig on b_consig.id = r.respuesta
	where r.id_emp = @emp
	and r.id_reglas = 114
	and r.respuesta > 1

	DECLARE @Docs AS TABLE
	(
		id INT,
		id_cot_tipo INT,
		id_cot_bodega INT,
		id_cot_cliente INT,
		id_cot_cliente_contacto INT,
		numero_cotizacion INT,
		fecha DATETIME,
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
	DECLARE @LINEA AS TABLE
	(
		id_item INT,
		linea VARCHAR(50)
	)

	-- INSERT #Bodega --> Bodegas que fueron seleccionadas en el filtro.
	IF @Bod = '0'
	begin
		INSERT @Bodega
		(
			id,
			descripcion,
			ecu_establecimiento,
			id_emp
		)
		SELECT id,
			   descripcion,
			   ecu_establecimiento,
			   id_emp
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
	END

	
	--RAZONES DE INGRESO
	declare @razon_ingreso as table
	(
		id_emp int,
		id int,
		descripcion varchar(80),
		anulado smallint,
		id_tal_motivo_ingreso_grupo int
	)
	insert @razon_ingreso
	SELECT * 		   
	FROM dbo.tal_motivo_ingreso
	where id_emp=@emp 

	----NUEVO PROCESO DE GARANTIAS Y CONSOLIDADAS----------		   
 	declare @OTs_CONSOLIDADAS_GARATIAS as table
	(
		id_factura int,
		IdOrden int
	)
	insert @OTs_CONSOLIDADAS_GARATIAS
	exec [dbo].[GetOrdenesFacturasTaller] @emp,@bod,@fecIni,@fecFin

	declare @OTs_CONSOLIDADAS_GARATIAS_NC as table 
	(
		id_factura int,
		IdOrden int
	)
	insert @OTs_CONSOLIDADAS_GARATIAS_NC exec [dbo].[GetOrdenesNCTaller] @emp,0
		
	-- INTO @Docs --> Los ids de todas las órdenes incluidas las de garantías y consolidados
	INSERT @Docs
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
		   v.id_cot_bodega,
		   id_cot_cliente = c.id_cot_cliente,
		   id_cot_cliente_contacto = c.id_cot_cliente_contacto ,
		   numero_cotizacion = c.numero_cotizacion,
		   fecha = c.fecha,
		   notas = cAST (c.notas  AS varchar(MAX)), 
		   id_cot_item = ci.id_cot_item,
		   id_cot_item_lote = ci.id_cot_item_lote,
		   cantidad_und = ci.cantidad_und * t.sw,
		   tiempo = CASE WHEN t.sw =-1 THEN (SELECT ci1.tiempo 
											FROM cot_cotizacion_item ci1 
											WHERE ci1.id = ci.id_cot_cotizacion_item_dev) * -1
						ELSE ci.tiempo 
					END,
		   precio_lista = ci.precio_lista,
		   precio_cotizado = ci.precio_cotizado,
		   costo = ci.costo_und,
		   porcentaje_descuento = ci.porcentaje_descuento,
		   porcentaje_descuento2 = ci.porcentaje_descuento2,
		   porcentaje_iva = ci.porcentaje_iva,
		   DesBod = b.descripcion,
		   id_com_orden_concepto = c.id_com_orden_concep,
		   ecu_establecimiento = b.ecu_establecimiento,
		   id_usuario_ven = c.id_usuario_vende,
		   id_forma_pago = c.id_cot_forma_pago,
		   docref_numero = c.docref_numero,
		   docref_tipo = c.docref_tipo, 
		   sw = t.sw,
		   saldo = c.total_total - ISNULL(s.valor_aplicado, 0),
		   id_cot_pedido_item = ci.id_cot_pedido_item, 
		   id_veh_hn_enc = c.id_veh_hn_enc,
		   id_cot_cotizacion_item = ci.id,
		   total_total = c.total_total,
		   facturar_a = ci.facturar_a,
		   tipo_operacion = ci.tipo_operacion	,
		   id_cot_item_vhtal = c.id_cot_item_lote ,
		   id_cot_cotizacion_sig = c.id_cot_cotizacion_sig,
		   id_operario = ci.id_operario,
		   valor_hora = CASE WHEN t.sw =-1 THEN (SELECT ci1.precio_cotizado 
												FROM cot_cotizacion_item ci1 
												WHERE ci1.id = ci.id_cot_cotizacion_item_dev) * -1
							ELSE ci.valor_hora
						END,
		   renglon = ci.renglon,
		   notas_item = ci.notas,
		   ot_final = c.id_cot_cotizacion_sig,
		   tipo_orden = 'F',
		   id_item = ci.id_componenteprincipalEst
	--INTO @Docs
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
    AND (t.sw = 1 AND (c.id NOT IN (select g.id_factura from @OTs_CONSOLIDADAS_GARATIAS g)) 
		OR t.sw = -1 AND (ISNULL (fdev.id_cot_cotizacion_factura, 0) NOT IN (select g.id_factura from @OTs_CONSOLIDADAS_GARATIAS_NC g)))
    and (@cli=0 or c.id_cot_cliente=@cli)
    AND (ISNULL (ci.facturar_a, 'NULL') <> 'S') -- Excluimos los ítems que corresponden a insumos

	------------------------------INSERTAMOS EN DOCS LA INFROMACION DE GARANTIAS Y CONSOLIDADAS------------------------
	--- PRIMERO BUSCAMOS LA ORDEN ORIGINAL Y LA INSERTAMOS EN UNA TABLA TEMPORAL
    DECLARE @detdatos AS TABLE
	(
			id_factura int,
			id int,
			id_cot_cotizacion_sig int,
			id_cot_item int,
			cantidad decimal(38,10),
			facturar_a char(1),
			precio_cotizado money,
			tipo_operacion char(1),
			id_componenteprincipalest int
	)
	insert @detdatos
	SELECT	id_factura = c.id,
			ci.id,
			c.id_cot_cotizacion_sig,
			ci.id_cot_item,
			ci.cantidad,
			ci.facturar_a,
			ci.precio_cotizado,
			ci.tipo_operacion,
			ci.id_componenteprincipalest
	FROM dbo.cot_cotizacion c
	JOIN dbo.cot_tipo t ON (t.id = c.id_cot_tipo) 
	LEFT JOIN dbo.v_cot_cotizacion_factura_dev fdev ON fdev.id_cot_cotizacion = CASE WHEN t.sw = -1 THEN c.id ELSE NULL END
	JOIN dbo.cot_cotizacion_item ci ON ci.id_cot_cotizacion = CASE WHEN t.sw = -1 THEN fdev.id_cot_cotizacion_factura ELSE c.id END
	WHERE (t.sw = 1 AND (c.id IN (select g.id_factura from @OTs_CONSOLIDADAS_GARATIAS g)) 
		OR t.sw = -1 AND (fdev.id_cot_cotizacion_factura IN (select g.id_factura from @OTs_CONSOLIDADAS_GARATIAS_NC g)));

	

	----GMAH PERSONALIZADO
	declare @detad as table
	(
		id_factura int, 
		id_det_fac int,
		id_det_orden int,
		id_otfinal int, 
		id_otori int,
		id_tal_garantia_clase int, 
		ClaseGarantia  varchar(150),
		facturar_a varchar(5)
	)
	insert @detad
	SELECT	id_factura = d.id_factura,
			id_det_fac = d.id,
			id_det_orden = c.id,
			id_otfinal = d.id_cot_cotizacion_sig,
			id_otori = ISNULL (c3.idv,c2.id),
			id_tal_garantia_clase = ccim.id_tal_garantia_clase,
			clasegarantia = ISNULL (tgc.descripcion, ''),
			facturar_a = d.facturar_a
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
	JOIN @detdatos d ON (ct.id = d.id_cot_cotizacion_sig 
		                    OR ct.id_cot_cotizacion_sig = d.id_cot_cotizacion_sig 
							OR c.id_prd_orden_estruc = d.id_cot_cotizacion_sig 
							OR c.id_prd_orden_estructurapt = d.id_cot_cotizacion_sig) 		 
	WHERE ISNULL(tjd.sw,0) <> 1 
	AND (tt.sw NOT IN ( 2,-1,46,47 ) OR tt.sw = 12 OR tt.sw IS NULL) 
	AND c.cantidad - ISNULL(dev.cantidad_devuelta,0) > 0 
	AND ( c.tipo_operacion IS NOT NULL OR tt.sw = 47)
	AND  d.id_componenteprincipalest = c.id
	
	--CREATE CLUSTERED INDEX ix_Detad ON @detad ([id_det_fac]);

	
	-- SEGUNDO INSERTAMOS LAS ORDENES DE GARANTIAS Y CONSOLIDADAS EN @Docs
	INSERT @Docs
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
			fecha = cc.fecha, 
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
	LEFT JOIN @detad adi ON adi.id_det_fac= CASE WHEN t.sw = -1 THEN cci.id ELSE c.id END --GMAH PERSONALIZADO
	LEFT JOIN cot_cotizacion cco ON cco.id=adi.id_otori and cco.id_emp=@emp
	LEFT JOIN dbo.cot_bodega b ON b.id = CASE WHEN cco.id_cot_bodega IS NULL THEN cc.id_cot_bodega ELSE cco.id_cot_bodega END
	WHERE (t.sw = 1 AND (c.id_cot_cotizacion IN (select g.id_factura from @OTs_CONSOLIDADAS_GARATIAS g)) 
		OR t.sw = -1 AND (fdev.id_cot_cotizacion_factura IN (select g.id_factura from @OTs_CONSOLIDADAS_GARATIAS_NC g)))
	AND (c.id_cot_cotizacion_item IS NULL)
	and t.sw IN ( 1, -1 ) 
	and t.es_remision is null 
    and t.es_traslado is null 
    and (@cli=0 or cc.id_cot_cliente=@cli)
	AND (ISNULL (c.facturar_a, 'NULL') <> 'S') -- Excluimos los ítems que corresponden a insumos


	
	
	--CREATE CLUSTERED INDEX ix_Docs ON @Docs ([id]);
	--CREATE nonCLUSTERED INDEX ix_Docs2 ON @Docs (id_cot_cotizacion_sig);
	--CREATE nonCLUSTERED INDEX ix_Docs3 ON @Docs (id_cot_item_vhtal);

		
	
	DECLARE @Devoluciones AS TABLE
	(
		id int,
		factura varchar(20),
		id_factura int,
		fecha datetime,
		concepto varchar(200)
	)
	insert @Devoluciones
	SELECT DISTINCT id = d.id,
		   factura = CAST (ISNULL (bd.ecu_establecimiento, '') AS VARCHAR(4))
					 + CAST(ISNULL(t3.ecu_emision, '') AS VARCHAR(4)) COLLATE Modern_Spanish_CI_AI + ''
					 + RIGHT('000000000' + CAST(cc3.numero_cotizacion AS VARCHAR(100)), 9),
		   id_factura = fdev.id_cot_cotizacion_factura,
		   cc3.fecha,
		   concepto = ISNULL (conc.descripcion, '')
	FROM @Docs d
	JOIN dbo.v_cot_cotizacion_factura_dev fdev ON d.sw = -1 AND fdev.id_cot_cotizacion = d.id
	JOIN dbo.cot_cotizacion cc3 ON cc3.id = fdev.id_cot_cotizacion_factura
	JOIN dbo.cot_tipo t3 ON t3.id = cc3.id_cot_tipo
	JOIN dbo.cot_bodega bd ON bd.id = cc3.id_cot_bodega
	LEFT JOIN com_orden_concep conc ON conc.id = cc3.id_com_orden_concep;


	
	-----------FLOTAS TALLER----
	declare @flotasTaller as table
	(
		id int,
		id_cot_tipo int,
		id_cot_item_vhtal int,
		codigo varchar(20), 
		descripcion varchar(100),
		fechaini date,
		fechafin date,
		id_tal_flota int,
		ClaseCliente varchar(80),
		EstaEnFlota char(1)
	)
	
	INSERT @flotasTaller
	SELECT	DISTINCT d.id,
			d.id_cot_tipo,
			d.id_cot_item_vhtal,
			tf.codigo, 
			tf.descripcion,
			tf.fechaini,
			tf.fechafin,
			id_tal_flota = tf.id,
			ClaseCliente = tc.descripcion,
			EstaEnFlota = CASE WHEN d.fecha BETWEEN tf.fechaini AND tf.fechafin THEN 'S' ELSE 'N' END					   
	FROM @Docs d
	JOIN tal_flota_veh fv ON fv.id_cot_item_lote = d.id_cot_item_vhtal AND (fv.inactivo <> 1 OR fv.inactivo IS NULL) -- SE AGREGA LA CONDICION IS NULL PARA VERIFICAR QUE EL VEHICULO ESTE ACTIVO EN LA FLOTA
	JOIN tal_flota tf ON tf.id = fv.id_tal_flota
	JOIN tal_flota_clase tc ON tc.id = tf.id_tal_flota_clase;

	
	---- @LINEA - INSERTAMOS LA LINEA DE LOS ITEMS DE DESCUENTOS Y DEVOLUCIONES EN VENTA
	INSERT @LINEA 
	SELECT 	id_item = item.id, 
			linea = CASE WHEN grup.id = 1337 THEN 'TOT' ELSE grup.descripcion END
	FROM @Docs docs 
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
	FROM @Docs docs 
		JOIN dbo.cot_item item ON item.id = docs.id_cot_item
		JOIN dbo.cot_grupo_sub gsub ON gsub.id = item.id_cot_grupo_sub
		JOIN dbo.cot_grupo grup ON grup.id = gsub.id_cot_grupo
	WHERE grup.id IN (1332, 1341, 1343)
	GROUP BY item.id, grup.descripcion, grup.id, gsub.descripcion;


	-- RESULTADO
	DECLARE @Resultado as table
	(
		[SW] [smallint] ,
		--[LineaNegocio] [varchar](50) ,
		[Id_Factura_NC_ND] [int] ,
		[BODEGA] [varchar](200) ,
		[Zona] [varchar](6) ,
		[VENDEDOR] [nvarchar](80) ,
		[FECHA_ENTRADA] [datetime] ,
		[FECHA_PROMESA] [datetime] ,
		[TIPO_IDENTIFICACION] [varchar](11) ,
		[NIT_CLIENTE] [nvarchar](20) ,
		[CLIENTE] [nvarchar](200) ,
		[CLASE_CLIENTE] [nvarchar](50) ,
		[FECHA_FACTURA] [datetime] ,
		[FECHA_SALIDA] [datetime] ,
		[TIPO_FACTURA] [nvarchar](50) ,
		[SERIE_FACTURA] [varchar](20) ,
		[FAC_ORIGINAL] INT,
		[FECHA_FAC_ORIGINAL] DATETIME,
		[TIPO_ORDEN] [varchar](5000) ,
		[VIN] [nvarchar](50) ,
		[MOTOR] [varchar](50) ,
		[MODELO] [varchar](5000) ,
		[AÑO] [decimal](18, 0) ,
		[KILOMETRAJE] [int] ,
		[PLACAS] [varchar](50) ,
		[LINEA_VH] [nvarchar](50) ,
		[NRO_ORDEN] [int] ,
		[PROPIETARIO] [nvarchar](200) ,
		[PERTENECE_FLOTA] [char](1) ,
		[TIPO_FLOTA] [varchar](80) ,
		[MarcaVH_original] [nvarchar](100) ,
		[RAZON_INGRESO] [varchar](80) ,
		--[DIAS] [int] ,
		[DEVOLUCION] [varchar](2) ,
		[NETO_REP] [decimal](38, 4) ,
		[NETO_TOT_REP] [decimal](37, 4) ,
		[COSTO_TOT_REP] [decimal](37, 4) ,
		[MARGEN_REP] [decimal](38, 6) ,
		[NETO_MO] [decimal](38, 4) ,
		[NETO_MO_VALORHORA_CANTIDAD_TIEMPO] [decimal](38, 6) ,
		[NETO_TOT_MO] [decimal](37, 4) ,
		[COSTO_TOT_MO] [decimal](37, 4) ,
		[MARGEN_MO] [decimal](38, 6) ,
		[NETO_TOTAL] [decimal](38, 4) ,
		[FORMA_PAGO] [nvarchar](50),
		[ID_EMP] INT,
		[id_cot_bodega] INT,
		Id_Asesor INT,
		id_cot_tipo  int,
		estado_ot varchar(100),
		numero_cotizacion int
	)
	INSERT @Resultado
	SELECT	SW = ct.sw,
	        --LineaNegocio = line.linea,
			Id_Factura_NC_ND=td.id,
			--BODEGA = tb.descripcion,
			Bodega = CASE when tb.id in (select rn.id_cot_bodega_rn from @bodegas_reglas_negocio rn) then brn.descripcion else tb.descripcion end,
            Zona= CASE WHEN zs.descripcion ='NORTE' THEN 'Zona 1'
				WHEN z.descripcion='COSTA' AND zs.descripcion in ('CENTRO', 'SUR') THEN 'Zona 2'
				WHEN z.descripcion='SIERRA' AND zs.descripcion in ('SUR') THEN 'Zona 3'
				end,
			VENDEDOR = uv.nombre,
			FECHA_ENTRADA = ISNULL (cc.fecha, ''),
			FECHA_PROMESA = ISNULL (cc.fecha_estimada, ''),
			TIPO_IDENTIFICACION = CASE
				WHEN ccl.tipo_identificacion = 'C' THEN 'Natural'
				WHEN ccl.tipo_identificacion = 'E' THEN 'Extranjería'
				WHEN ccl.tipo_identificacion = 'N' THEN 'Privado'
				WHEN ccl.tipo_identificacion = 'O' THEN 'Público'
				ELSE ''
			END,
			NIT_CLIENTE = ccl.nit,
			CLIENTE = ccl.razon_social,
			CLASE_CLIENTE = ISNULL (ccp.descripcion, ''),
			FECHA_FACTURA = td.fecha,
			FECHA_SALIDA = ISNULL(te.fecha_modif,te.fecha),
			TIPO_FACTURA = ct.descripcion,
			SERIE_FACTURA = CASE
				WHEN ct.sw = -1 THEN tde.factura
				ELSE CAST (ISNULL (tb.ecu_establecimiento, '') AS VARCHAR(4)) + CAST (ISNULL (ct.ecu_emision, '') AS VARCHAR(4)) COLLATE modern_spanish_ci_ai + '' + RIGHT ('000000000' + CAST (td.numero_cotizacion AS VARCHAR(100)), 9)
			END,
			fac_original = tde.id_factura,
			FECHA_FAC_ORIGINAL = tde.fecha,
			TIPO_ORDEN = ISNULL(vcv3.campo_1, ''), 
			VIN = ISNULL (cil3.vin, ''),
			MOTOR = ISNULL (cil3.motor, ''),
			MODELO = ISNULL (ISNULL(( CASE
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
			END)), ''),
			AÑO = ISNULL (ISNULL((CASE 
				WHEN vm1.descripcion LIKE '%MULTIMARCA%' THEN
					CASE
						WHEN CONVERT (DECIMAL, vcv2.campo_13, 0) = 0 OR vcv2.campo_13 IS NULL THEN ci2.id_veh_ano
						ELSE CONVERT (DECIMAL, vcv2.campo_13, 0)
					END
				ELSE
					CASE 
						WHEN ci2.codigo LIKE '%ALL%' THEN
							CASE
								WHEN CONVERT (DECIMAL, vcv2.campo_13, 0) = 0 OR vcv2.campo_13 IS NULL THEN ci2.id_veh_ano
								ELSE CONVERT(decimal, vcv2.campo_13,0) 
							END
						ELSE ci2.id_veh_ano
					END
			END),
			(CASE 
				WHEN vm2.descripcion LIKE '%MULTIMARCA%' THEN
					CASE
						WHEN CONVERT (DECIMAL, vcv4.campo_13, 0) = 0 OR vcv4.campo_13 IS NULL THEN ci3.id_veh_ano
						ELSE CONVERT (DECIMAL, vcv4.campo_13, 0)
					END
				ELSE
					CASE
						WHEN ci3.codigo LIKE '%ALL%' THEN
							CASE
								WHEN CONVERT (DECIMAL, vcv4.campo_13, 0) = 0 OR vcv4.campo_13 IS NULL THEN ci3.id_veh_ano
								ELSE CONVERT (DECIMAL, vcv4.campo_13, 0) 
							END
								ELSE ci3.id_veh_ano
						END
			END)), 0),
			KILOMETRAJE = ISNULL (cc.km, ''),
			PLACAS = ISNULL (cil3.placa, ''),
			LINEA_VH = ISNULL (ISNULL (cit2.descripcion, cit3.descripcion), ''),
			NRO_ORDEN = ISNULL (td.id_cot_cotizacion_sig, 0),		
			PROPIETARIO = ISNULL (cclp.razon_social, ''),
			PERTENECE_FLOTA = ISNULL (tft.EstaEnFlota, 'N'),
			TIPO_FLOTA = ISNULL (tft.ClaseCliente, ''),		
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
			END)), ''), --DE LA ORDEN ORIGINAL
			RAZON_INGRESO = ISNULL (tri.descripcion, ''),
			--DIAS = ISNULL ((DATEDIFF (DAY, cc.fecha_estimada, td.fecha)), 0),
			DEVOLUCION = CASE WHEN vccif.id_cot_cotizacion_item IS NOT NULL THEN 'Si' ELSE 'No' END,
			NETO_REP = CASE 
				--WHEN cg.id NOT IN (1326, 1337) THEN (ABS (td.precio_cotizado) 
				WHEN cg.descripcion + ' ' + cgs.descripcion LIKE '%REPUESTOS%' OR 
					cg.descripcion + ' ' + cgs.descripcion LIKE '%ACCESORIOS%'
				THEN (ABS (td.precio_cotizado) 
										* ABS (CASE WHEN td.cantidad_und = 0 THEN 1 ELSE td.cantidad_und END)) 
										* CASE WHEN td.sw = 1 THEN 1 ELSE -1 END
				ELSE 0
			END,
			NETO_TOT_REP = CASE 
				WHEN ci1.codigo LIKE '%TOT%REP%' AND cg.id IN (1337) THEN ISNULL (td.cantidad_und * td.precio_cotizado, 0)
				ELSE 0
			END,
			COSTO_TOT_REP = CASE 
				WHEN ci1.codigo LIKE '%TOT%REP%' AND cg.id IN (1337) THEN ISNULL (td.cantidad_und * td.costo, 0)
				ELSE 0
			END,
			MARGEN_REP = CASE 
				WHEN ci1.codigo LIKE '%TOT%REP%' AND cg.id IN (1337) THEN 
				CASE WHEN ISNULL ((td.cantidad_und * td.costo), 0) = 0
					THEN 0
					ELSE (1-((td.cantidad_und * td.costo) / ((ABS (IIF(td.precio_cotizado=0,1,td.precio_cotizado)) 
						* ABS (CASE WHEN td.cantidad_und = 0 THEN 1 ELSE td.cantidad_und END)) 
						* CASE WHEN td.sw = 1 THEN 1 ELSE -1 END))) * 100
					END
				END,
			/*ISNULL (td.cantidad_und * td.precio_cotizado, 0)
				ELSE 0
			END)
			- SUM (CASE 
				WHEN ci1.codigo LIKE '%TOT%REP%' AND cg.id IN (1337) THEN ISNULL (td.costo, 0)
				ELSE 0
			END)),*/
			NETO_MO = CASE 
				--WHEN cg.id = 1326 THEN (ABS (td.precio_cotizado) 
				WHEN cg.descripcion + ' ' + cgs.descripcion LIKE '%TALLER%' AND
					cg.id NOT IN (1337) THEN (ABS (td.precio_cotizado) 
										* ABS (CASE WHEN td.cantidad_und = 0 THEN 1 ELSE td.cantidad_und END)) 
										* CASE WHEN td.sw = 1 THEN 1 ELSE -1 END
				ELSE 0
			END,
			NETO_MO_VALORHORA_CANTIDAD_TIEMPO = ISNULL(
			CASE
				WHEN ISNULL (ci1.costo_emergencia, 0) <> 0 AND ABS (ci1.precio) <> 0 THEN 0
				ELSE td.cantidad_und 
				* CASE WHEN td.sw = -1 
				THEN CASE 
					WHEN (td.cantidad_und) * -1 <> 1 AND td.cantidad_und <> 0
						THEN ROUND ((ISNULL (td.tiempo / td.cantidad_und, 0) * -1) ,4)
						ELSE ROUND ((ISNULL (td.tiempo, 0)), 4)
				END
				ELSE 
					CASE WHEN (td.cantidad_und) <> 1 AND td.cantidad_und <> 0
						THEN ROUND ((ISNULL (td.tiempo / td.cantidad_und, 0)), 4)
						ELSE ROUND ((ISNULL (td.tiempo, 0)), 4)
					END
				END
				* ISNULL (td.valor_hora, 0) END, 0), 
			NETO_TOT_MO = CASE 
				WHEN ci1.codigo LIKE '%TOT%MDO%' AND cg.id IN (1337) THEN ISNULL (td.cantidad_und * td.precio_cotizado, 0)
				ELSE 0
			END,
			COSTO_TOT_MO = CASE 
				WHEN ci1.codigo LIKE '%TOT%MDO%' AND cg.id IN (1337) THEN ISNULL (td.cantidad_und * td.costo, 0)
				ELSE 0
			END,
			/*CASE WHEN ISNULL ((td.cantidad_und * td.costo), 0) = 0
					THEN 0
					ELSE (1-((td.cantidad_und * td.costo) / ((ABS (td.precio_cotizado) 
						* ABS (CASE WHEN td.cantidad_und = 0 THEN 1 ELSE td.cantidad_und END)) 
						* CASE WHEN td.sw = 1 THEN 1 ELSE -1 END))) * 100
					END*/
			MARGEN_MO = ABS ( 
			CASE 
				WHEN ci1.codigo LIKE '%TOT%MDO%' AND cg.id IN (1337) THEN 
				CASE WHEN ISNULL ((td.cantidad_und * td.costo), 0) = 0
					THEN 0
					ELSE (1-((td.cantidad_und * td.costo) / ((ABS (IIF(td.precio_cotizado=0,1,td.precio_cotizado)) 
						* ABS (CASE WHEN td.cantidad_und = 0 THEN 1 ELSE td.cantidad_und END)) 
						* CASE WHEN td.sw = 1 THEN 1 ELSE -1 END))) * 100
					END
				END),
				/*ISNULL (td.cantidad_und * td.precio_cotizado, 0)
				ELSE 0
			END)
			- SUM (CASE 
				WHEN ci1.codigo LIKE '%TOT%MDO%' AND cg.id IN (1337) THEN ISNULL (td.cantidad_und * td.costo, 0)
				ELSE 0
			END)),*/
			NETO_TOTAL = CASE 
				WHEN cg.id NOT IN (1326, 1337) THEN (ABS (td.precio_cotizado) 
										* ABS (CASE WHEN td.cantidad_und = 0 THEN 1 ELSE td.cantidad_und END)) 
										* CASE WHEN td.sw = 1 THEN 1 ELSE -1 END
				ELSE 0
			END
			+ CASE 
				WHEN ci1.codigo LIKE '%TOT%REP%' AND cg.id IN (1337) THEN ISNULL (td.cantidad_und * td.precio_cotizado, 0)
				ELSE 0
			END
			+ CASE 
				WHEN cg.id = 1326 THEN (ABS (td.precio_cotizado) 
										* ABS (CASE WHEN td.cantidad_und = 0 THEN 1 ELSE td.cantidad_und END)) 
										* CASE WHEN td.sw = 1 THEN 1 ELSE -1 END
				ELSE 0
			END
			+CASE 
				WHEN ci1.codigo LIKE '%TOT%MDO%' AND cg.id IN (1337) THEN ISNULL (td.cantidad_und * td.precio_cotizado, 0)
				ELSE 0
			END,
			-- Campo con la descripción de la forma de pago
			FORMA_PAGO = ISNULL (fp.descripcion, ''),
			tb.id_emp,
			--id_cot_bodega = tb.id,
			id_cot_bodega = CASE when tb.id in (select rn.id_cot_bodega_rn from @bodegas_reglas_negocio rn) then brn.id_cot_bodega else tb.id end,
			Id_Asesor = uv.id,
			ct.id,
			estado_ot=ubi.descripcion,
			td.numero_cotizacion
	
	FROM @Docs td
	JOIN @LINEA line ON line.id_item = td.id_cot_item 
	JOIN dbo.cot_tipo ct ON ct.id = td.id_cot_tipo
	JOIN @Bodega tb ON tb.id = td.id_cot_bodega
	JOIN cot_bodega b on b.id=tb.id 
	JOIN cot_zona_sub zs on zs.id=b.id_cot_zona_sub
	JOIN cot_zona z on z.id=zs.id_cot_zona
	JOIN dbo.cot_cliente ccl ON ccl.id = td.id_cot_cliente
	LEFT JOIN dbo.cot_cliente_perfil ccp ON ccp.id = ccl.id_cot_cliente_perfil
	LEFT JOIN dbo.usuario uv ON uv.id = td.id_usuario_ven
			 JOIN dbo.cot_item ci1 ON ci1.id = td.id_cot_item
			 JOIN dbo.cot_grupo_sub cgs ON cgs.id = ci1.id_cot_grupo_sub
			 JOIN dbo.cot_grupo cg ON cg.id = cgs.id_cot_grupo
	LEFT JOIN @Devoluciones tde ON tde.id = td.id
	LEFT JOIN dbo.ecu_tipo_comprobante etc ON etc.id = ct.id_ecu_tipo_comprobante
	LEFT JOIN dbo.v_cot_cotizacion_item_dev2 vccif ON vccif.id_cot_cotizacion_item = td.id_cot_cotizacion_item AND vccif.cantidad_devuelta <> 0
	LEFT JOIN dbo.v_campos_varios vcv1 ON vcv1.id_cot_item = ci1.id
	LEFT JOIN dbo.cot_cotizacion cc ON cc.id = td.id_cot_cotizacion_sig
	LEFT JOIN cot_bodega_ubicacion ubi ON ubi.id=cc.id_cot_bodega_ubicacion
	LEFT JOIN dbo.tra_cargue_enc te on te.id_cot_cotizacion = cc.id AND te.anulado IS NULL --ADMG 740: Se agrega AND te.anulado IS NULL

	LEFT JOIN dbo.cot_item_lote cil2 ON cil2.id = td.id_cot_item_vhtal
	LEFT JOIN dbo.cot_item ci2 ON ci2.id = cil2.id_cot_item
	LEFT JOIN dbo.veh_linea vl1 ON vl1.id = ci2.id_veh_linea
	LEFT JOIN dbo.veh_marca vm1 ON vm1.id = vl1.id_veh_marca
	LEFT JOIN dbo.cot_item_talla cit2 ON cit2.id = ci2.id_cot_item_talla
	LEFT JOIN dbo.v_campos_varios vcv2 ON vcv2.id_cot_item_lote = cil2.id
	LEFT JOIN dbo.cot_item_lote cil3 ON cil3.id = cc.id_cot_item_lote
	LEFT JOIN dbo.v_campos_varios vcv3 ON vcv3.id_cot_cotizacion = cc.id AND vcv3.campo_1 IS NOT NULL
	LEFT JOIN dbo.cot_item ci3 ON ci3.id = cil3.id_cot_item
	LEFT JOIN dbo.veh_linea vl2 ON vl2.id = ci3.id_veh_linea
	LEFT JOIN dbo.veh_marca vm2 ON vm2.id = vl2.id_veh_marca
	LEFT JOIN dbo.cot_item_talla cit3 ON cit3.id = ci3.id_cot_item_talla
	LEFT JOIN dbo.v_campos_varios vcv4 ON vcv4.id_cot_item_lote = cil3.id
	LEFT JOIN dbo.cot_cliente_contacto ccc2 ON ccc2.id = cil3.id_cot_cliente_contacto
	LEFT JOIN dbo.cot_cliente cclp ON cclp.id = ccc2.id_cot_cliente AND cclp.id_emp = 605
	LEFT JOIN @flotasTaller tft ON tft.id = td.id AND tft.id_cot_item_vhtal = td.id_cot_item_vhtal
	LEFT JOIN @razon_ingreso tri ON tri.id = cc.id_tal_motivo_ingreso
	-- Cruce para obtener la forma de pago
	LEFT JOIN dbo.cot_forma_pago fp ON fp.id = td.id_forma_pago
	LEFT JOIN @bodegas_reglas_negocio brn on td.id_cot_bodega = brn.id_cot_bodega_rn
	WHERE line.linea <> 'VEHICULOS'

	----------------------------------------------------------
	declare @Resultado_Final as table
	(
		[SW] [smallint] NULL,
		--[LineaNegocio] [varchar](50) ,
		[Id_Factura_NC_ND] [int] NULL,
		[BODEGA] [varchar](200) NULL,
		[Zona] [varchar](6) NULL,
		[VENDEDOR] [nvarchar](80) NULL,
		[FECHA_ENTRADA] [datetime] NULL,
		[FECHA_PROMESA] [datetime] NULL,
		[TIPO_IDENTIFICACION] [varchar](11) NULL,
		[NIT_CLIENTE] [nvarchar](20) NULL,
		[CLIENTE] [nvarchar](200) NULL,
		[CLASE_CLIENTE] [nvarchar](50) NULL,
		[FECHA_SALIDA] [datetime],
		[FECHA_FACTURA] [datetime] NULL,
		[TIPO_FACTURA] [nvarchar](50) NULL,
		[SERIE_FACTURA] [varchar](20) NULL,
		[FAC_ORIGINAL] INT,
		FECHA_FAC_ORIGINAL DATETIME,
		[FORMA_PAGO] [nvarchar](50) NULL,
		[TIPO_ORDEN] [varchar](5000) NULL,
		[VIN] [nvarchar](50) NULL,
		[MOTOR] [varchar](50) NULL,
		[MODELO] [varchar](5000) NULL,
		[AÑO] [decimal](18, 0) NULL,
		[KILOMETRAJE] [int] NULL,
		[PLACAS] [varchar](50) NULL,
		[LINEA_VH] [nvarchar](50) NULL,
		[NRO_ORDEN] [int] NULL,
		[PROPIETARIO] [nvarchar](200) NULL,
		[PERTENECE_FLOTA] [char](1) NULL,
		[TIPO_FLOTA] [varchar](80) NULL,
		[MarcaVH_original] [nvarchar](100) NULL,
		[Marca_VH] [varchar](10) NOT NULL,
		[RAZON_INGRESO] [varchar](80) NULL,
		[DIAS] [int] NULL,
		[DEVOLUCION] [varchar](2) NULL,
		[NETO_REP] [decimal](38, 4) NULL,
		[NETO_TOT_REP] [decimal](38, 4) NULL,
		[COSTO_TOT_REP] [decimal](38, 4) NULL,
		[MARGEN_REP] [decimal](38, 6) NULL,
		[NETO_MO] [decimal](38, 4) NULL,
		[NETO_MO_VALORHORA_CANTIDAD_TIEMPO] [decimal](38, 6) NULL,
		[NETO_TOT_MO] [decimal](38, 4) NULL,
		[COSTO_TOT_MO] [decimal](38, 4) NULL,
		[MARGEN_MO] [decimal](38, 6) NULL,
		[NETO_TOTAL] [decimal](38, 4) NULL,
		[ID_EMP] INT,
		id_cot_bodega int,
		Id_Asesor INT,
		id_cot_tipo int,
		estado_ot varchar(100),
		numero_cotizacion int
	)
	insert @Resultado_Final
	select r.SW,
	       --r.LineaNegocio,
		   r.Id_Factura_NC_ND,	
		   r.BODEGA,	
		   r.Zona,	
		   r.VENDEDOR,	
		   r.FECHA_ENTRADA,	
		   r.FECHA_PROMESA,	
		   r.TIPO_IDENTIFICACION,	
		   r.NIT_CLIENTE,
		   r.CLIENTE,	
		   r.CLASE_CLIENTE,
		   r.FECHA_SALIDA,
		   r.FECHA_FACTURA,	
		   r.TIPO_FACTURA,
		   r.SERIE_FACTURA,	
		   r.FAC_ORIGINAL,
		   r.FECHA_FAC_ORIGINAL,
		   r.FORMA_PAGO,
		   r.TIPO_ORDEN,	
		   r.VIN,	
		   r.MOTOR,	
		   r.MODELO,	
		   r.AÑO,	
		   r.KILOMETRAJE,	
		   r.PLACAS,	
		   r.LINEA_VH,	
		   r.NRO_ORDEN,	
		   r.PROPIETARIO,
		   r.PERTENECE_FLOTA,
		   r.TIPO_FLOTA,
		   r.MarcaVH_original,
		   Marca_VH = CASE WHEN r.TIPO_ORDEN like '%Latoner%' OR r.TIPO_ORDEN like '%Mec%' OR r.TIPO_ORDEN like '%Garant%' 
			               THEN CASE
									WHEN RTRIM(LTRIM(r.MarcaVH_original)) = 'CHEVROLET' THEN 'Chevrolet'
									WHEN RTRIM(LTRIM(r.MarcaVH_original)) = 'GAC' THEN 'Gac'
									WHEN RTRIM(LTRIM(r.MarcaVH_original)) = 'VOLKSWAGEN' THEN 'VolksWagen'
									ELSE 'Multimarca'
								END
							ELSE ''
			          END,
		   r.RAZON_INGRESO,
		   --r.DIAS,
		   DIAS = case 
						when r.NRO_ORDEN =0 then 0
						else DATEDIFF (DAY, r.FECHA_PROMESA, ISNULL(r.FECHA_SALIDA,r.FECHA_FACTURA))
						end,
		   r.DEVOLUCION,
		   NETO_REP = SUM(r.NETO_REP),
		   NETO_TOT_REP = SUM(r.NETO_TOT_REP),
		   COSTO_TOT_REP = SUM(r.COSTO_TOT_REP),
		   MARGEN_REP = SUM(r.MARGEN_REP),
		   NETO_MO = SUM(r.NETO_MO),
		   NETO_MO_VALORHORA_CANTIDAD_TIEMPO = SUM(r.NETO_MO_VALORHORA_CANTIDAD_TIEMPO),
		   NETO_TOT_MO = SUM(r.NETO_TOT_MO),
		   COSTO_TOT_MO = SUM(r.COSTO_TOT_MO),
		   MARGEN_MO = SUM(r.MARGEN_MO),
		   NETO_TOTAL = SUM(r.NETO_TOTAL),
		   r.id_emp,
		   r.id_cot_bodega,
		   r.Id_Asesor,
		   r.id_cot_tipo,
		   r.estado_ot,
		   r.numero_cotizacion
	--into [dms_smd3_soporte]..Resultado2_20210902
	from @Resultado r
	GROUP BY r.sw, 
	         --r.LineaNegocio,
	         r.Id_Factura_NC_ND, 
			 r.BODEGA, 
			 r.Zona,
			 r.VENDEDOR,
			 r.FECHA_ENTRADA,
			 r.FECHA_PROMESA,
			 r.TIPO_IDENTIFICACION,
		     r.NIT_CLIENTE, 
			 r.CLIENTE, 
			 r.CLASE_CLIENTE, 
			 r.FECHA_SALIDA,
			 r.FECHA_FACTURA, 
			 r.TIPO_FACTURA, 
			 r.SERIE_FACTURA,
			 r.FAC_ORIGINAL,
			 r.FECHA_FAC_ORIGINAL,
		     r.FORMA_PAGO,
			 r.TIPO_ORDEN, 
			 r.vin, 
			 r.motor, 
			 r.MODELO,  
			 r.[AÑO],
			 r.KILOMETRAJE, 
			 r.PLACAS, 
			 r.LINEA_VH,
			 r.NRO_ORDEN,
		     r.PROPIETARIO, 
			 r.PERTENECE_FLOTA, 
			 r.TIPO_FLOTA, 
			 r.MarcaVH_original,
			 r.RAZON_INGRESO, 
			 r.DEVOLUCION,
			 r.ID_EMP,
			 r.id_cot_bodega,
			 r.Id_Asesor,
			 r.id_cot_tipo,
			 r.estado_ot,
			 r.numero_cotizacion

	select * from @Resultado_Final


    
	
	