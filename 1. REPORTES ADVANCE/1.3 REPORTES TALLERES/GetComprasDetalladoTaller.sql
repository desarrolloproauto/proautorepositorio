USE [dms_smd3]
GO

-- =====================================================================================================================
-- COORP. PROAUTO (DEPARTAMENTO DE TECNOLOGIA)
-- Author:		<Angelica .>
-- Create date: <0000-00-00>
-- Modulo:		<Reporteria>
-- Description:	<Procedimiento para obtener informacion detallada de Compras de TOT,  (Reporte 100027 Advance)
-- Historial de Cambios:
-->	04-10-2021	Se agrega la fecha de facturacion de la TOT
-->	09-11-2021	Se corrige algunas bodegas que no estaban saliendo, ademas de los ids de ot origen y final
--> 16-12-2021  Cambio solicitado por Angelica
--> 21-01-2022  Se cambia el filtro de fecha para que se considere correctamente las compras
--> 28-03-2022  Se agrega el campo "VENDEDOR" que es el usuario que registra la compra (JCB)
-- =====================================================================================================================

-- Exec [GetComprasDetalladoTaller] '605','0','20220301 00:00:00','20220331 23:59:59'
alter PROCEDURE [dbo].[GetComprasDetalladoTaller]
	(
		@emp INT,
		@Bod VARCHAR(MAX),
		@fecIni DATE,
		@fecFin DATE
	)
	AS

begin

	DECLARE @Bodega AS TABLE (
		id INT,
		descripcion VARCHAR(200),
		ecu_establecimiento VARCHAR(6)
	)

	-- INSERT #Bodega --> Bodegas que fueron seleccionadas en el filtro.
	IF @Bod = '0'
		INSERT @Bodega 
		SELECT id,
			   descripcion,
			   ecu_establecimiento
		FROM dbo.cot_bodega
		WHERE id_emp = @emp
	ELSE
		INSERT @Bodega 
		SELECT CAST(f.val AS INT),
			   c.descripcion,
			   c.ecu_establecimiento
		FROM dbo.fnSplit(@Bod, ',') f
		JOIN dbo.cot_bodega c ON c.id = CAST(f.val AS INT);

	-- TABLAS TEMPORALES PARA OBTENER LA INFORMACIÓN DE LAS ORDENES DE TALLER
	SELECT	id_factura = c.id,
			ci.id,
			c.id_cot_cotizacion_sig,
			ci.id_componenteprincipalest
	INTO #DetDatos 
	FROM dbo.cot_cotizacion c
	JOIN dbo.cot_cotizacion_item ci ON ci.id_cot_cotizacion = c.id
	where c.id_emp = @emp
	and c.fecha between @fecIni and @fecFin


	SELECT	id_det_fac = d.id,
			id_det_orden = c.id,
			id_otfinal = d.id_cot_cotizacion_sig,
			id_otori = ISNULL(c3.idv, c2.id)
	INTO #Detad
	FROM dbo.cot_cotizacion ct
			 JOIN dbo.cot_cotizacion_item c ON c.id_cot_cotizacion = ct.id
		LEFT JOIN dbo.cot_tipo tt 			ON tt.id = c.id_cot_tipo_tran
		LEFT JOIN dbo.cot_cotizacion c3		ON c3.id = c.id_cot_cotizacion
		LEFT JOIN cot_cotizacion c2 		ON c2.id = ISNULL(c3.id_cot_cotizacion_sig, c.id_cot_cotizacion)
		LEFT JOIN dbo.cot_tipo tjd 			ON tjd.id = c3.id_cot_tipo
			 JOIN #DetDatos d				ON ( ct.id = d.id_cot_cotizacion_sig 
				 OR ct.id_cot_cotizacion_sig = d.id_cot_cotizacion_sig 
				 OR c.id_prd_orden_estruc = d.id_cot_cotizacion_sig 
				 OR c.id_prd_orden_estructurapt = d.id_cot_cotizacion_sig) 
				 AND d.id_componenteprincipalest = c.id
	WHERE ISNULL(tjd.sw,0) <> 1 
		AND (tt.sw NOT IN (2,-1,46,47) OR tt.sw = 12 OR tt.sw IS NULL) 
		AND (c.tipo_operacion IS NOT NULL OR tt.sw = 47);

	-- #OrdenesFacturas
	SELECT	id_item = c.id_componenteprincipalEst
			,codigo_item = i.codigo
			,orden = ot.id
			,ot_origen = adi.id_otori, ot.id
			,ot_final = adi.id_otfinal
			,cantidad = ci.cantidad
			,por_deducible = ot.deducible
			,val_deducible = (ci.precio_lista * ot.deducible)
			,iva = (ci.precio_lista * ci.porcentaje_iva) / 100
			,valor = ci.can_tot_dis * ci.cantidad
			,estado = CASE 
						WHEN ot.anulada IS NULL THEN ''
						WHEN ot.anulada = 1 THEN 'Facturada'
						WHEN ot.anulada = 2 THEN 'Cerrada'
						WHEN ot.anulada = 3 THEN 'Parcial'
						WHEN ot.anulada = 4 AND SUBSTRING(ot.notas, 1, 6) = '*cons*' THEN 'Consolidada'
						WHEN ot.anulada = 4 THEN 'Anulada'
						WHEN ot.anulada > 4 THEN 'Orden no se puede usar: ' + CAST(ot.anulada AS VARCHAR)
						ELSE ''
					END
			,id_cot_cliente = ot.id_cot_cliente
			,id_usuario = ot.id_usuario
			,bodega = b.descripcion
			,venta = c.id_cot_cotizacion
			,fecha_venta = cc.fecha
			,compra = comp.id
			,vehiculo = ot.id_cot_item_lote
	INTO #OrdenesFacturadas
	FROM dbo.v_cot_cotizacion_item_todos_mep c
		LEFT JOIN cot_cotizacion cc			ON cc.id = c.id_cot_cotizacion AND cc.id_emp = 605 AND ISNULL(cc.anulada, 0) <> 4
		LEFT JOIN dbo.cot_tipo t			ON t.id = cc.id_cot_tipo
		LEFT JOIN #detad adi				ON adi.id_det_fac = c.id
		LEFT JOIN cot_cotizacion ot			ON adi.id_otori = ot.id
			 JOIN @Bodega b					ON ot.id_cot_bodega = b.id
		LEFT JOIN cot_cotizacion_item ite	ON c.id_componenteprincipalEst = ite.id
		LEFT JOIN cot_cotizacion comp		ON ite.id_cot_cotizacion = comp.id
		LEFT JOIN cot_cotizacion_item ci	ON ci.id = c.id_componenteprincipalEst
		LEFT JOIN cot_item i				ON i.id = ci.id_cot_item
	WHERE --ot.fecha between @fecini and @fecfin and ot.id_emp = @emp
		 (c.id_cot_cotizacion_item IS NULL) 
		AND t.sw IN ( 1, -1 ) AND t.es_remision IS NULL
		AND t.es_traslado IS NULL  
		AND i.codigo LIKE 'TOT%';
	
	-- #OrdenesNoFacturadas
	SELECT	DISTINCT
			id_item = ciot.id
			,codigo_item = i.codigo
			,orden = ISNULL (ot.id_cot_cotizacion_sig, ot.id)
			,ot_origen = ISNULL (ot.id_cot_cotizacion_sig, ot.id)
			,ot_final = ISNULL (ot.id_cot_cotizacion_sig, ot.id)
			,cantidad = ciot.cantidad
			,por_deducible = ot.deducible
			,val_deducible = (ciot.precio_lista * ot.deducible)
			,iva = (ciot.precio_lista * ciot.porcentaje_iva) / 100
			,valor = ciot.can_tot_dis * ciot.cantidad
			,estado = CASE 
						WHEN ot.anulada IS NULL THEN ''
						WHEN ot.anulada = 1 THEN 'Facturada'
						WHEN ot.anulada = 2 THEN 'Cerrada'
						WHEN ot.anulada = 3 THEN 'Parcial'
						WHEN ot.anulada = 4 AND SUBSTRING(ot.notas, 1, 6) = '*cons*' THEN 'Consolidada'
						WHEN ot.anulada = 4 THEN 'Anulada'
						WHEN ot.anulada > 4 THEN 'Orden no se puede usar: ' + CAST(ot.anulada AS VARCHAR)
						ELSE ''
					END
			,id_cot_cliente = ot.id_cot_cliente
			,id_usuario = ot.id_usuario
			,bodega = b.descripcion
			,venta = ''
			,fecha_venta = null
			,compra = comp.id
			,vehiculo = ot.id_cot_item_lote
	INTO #OrdenesNoFacturadas
	FROM dbo.cot_cotizacion ot
		LEFT JOIN cot_tipo tiot ON ot.id_cot_tipo = tiot.id 
		LEFT JOIN cot_cotizacion rep ON rep.id_cot_cotizacion_sig = ot.id 
		LEFT JOIN cot_tipo tire ON rep.id_cot_tipo = tire.id
		LEFT JOIN cot_cotizacion_item ciot ON (rep.id = ciot.id_cot_cotizacion)
		LEFT JOIN cot_item itot ON ciot.id_cot_item = itot.id
		LEFT JOIN #detad adi	ON adi.id_otori = ISNULL (ot.id_cot_cotizacion_sig, ot.id)
		JOIN @Bodega b					ON ot.id_cot_bodega = b.id
		LEFT JOIN cot_cotizacion_item ite	ON ciot.id = ite.id
		LEFT JOIN cot_cotizacion comp		ON ite.id_cot_cotizacion = comp.id
		LEFT JOIN cot_cotizacion_item ci	ON ci.id = ciot.id
		LEFT JOIN cot_item i				ON i.id = ci.id_cot_item
	WHERE --CAST (ot.fecha AS date) BETWEEN @fecini AND @fecfin AND 
		ot.id_emp = @emp 
		AND tiot.sw = 46 AND (tire.sw = 4) AND ciot.tipo_operacion IS NOT NULL AND ciot.facturar_a IS NOT NULL
		AND ciot.id IS NOT NULL AND adi.id_det_fac IS NULL
		--AND ISNULL (ot.id_cot_cotizacion_sig, ot.id) = 465216
	ORDER BY 1;

	SELECT	f.id_item 
			,f.codigo_item 
			,f.orden 
			,f.ot_origen
			,f.ot_final 
			,f.cantidad 
			,f.por_deducible 
			,f.val_deducible 
			,f.iva 
			,f.valor 
			,f.estado
			,f.id_cot_cliente
			,f.id_usuario
			,f.bodega
			,f.venta 
			,f.fecha_venta 
			,f.compra 
			,f.vehiculo
	INTO #Ordenes
	FROM #OrdenesFacturadas f
	UNION ALL
	SELECT nf.id_item 
			,nf.codigo_item 
			,nf.orden 
			,nf.ot_origen
			,nf.ot_final 
			,nf.cantidad 
			,nf.por_deducible 
			,nf.val_deducible 
			,nf.iva 
			,nf.valor 
			,nf.estado
			,nf.id_cot_cliente
			,nf.id_usuario
			,nf.bodega
			,nf.venta 
			,nf.fecha_venta 
			,nf.compra 
			,nf.vehiculo
	FROM #OrdenesNoFacturadas nf;

	-- #Vehiculo
	SELECT	id = ih.id
			,vin = ISNULL (ih.vin, '')
			,modelo =	CASE	
						WHEN m.descripcion LIKE'%MULTIMARCA%' THEN 
							CASE	
								WHEN cv6.campo_12 = '' OR cv6.campo_12 IS NULL THEN ic.descripcion
								ELSE CAST (cv6.campo_12 AS VARCHAR(500)) 
							END 
						ELSE
							CASE 
								WHEN ic.codigo LIKE '%ALL%' THEN
									CASE 
										WHEN cv6.campo_12 = '' OR cv6.campo_12 IS NULL THEN ic.descripcion
										ELSE CAST (cv6.campo_12 AS VARCHAR(500)) 
									END 
								ELSE ic.descripcion
							END
					END
			,motor = ISNULL (ih.motor, '')
			,color = ISNULL (col.descripcion, '')
			,año = CASE	
					WHEN m.descripcion LIKE '%MULTIMARCA%' THEN 
						CASE 
							WHEN CONVERT (decimal, cv6.campo_13, 0) = 0 OR cv6.campo_13 IS NULL THEN ic.id_veh_ano
							ELSE CONVERT (decimal, cv6.campo_13, 0) 
						END
					ELSE
						CASE 
							WHEN ic.codigo LIKE '%ALL%' THEN
								CASE 
									WHEN CONVERT (decimal, cv6.campo_13, 0) = 0 OR cv6.campo_13 IS NULL THEN ic.id_veh_ano
									ELSE CONVERT (decimal, cv6.campo_13,0) 
								END
							ELSE ic.id_veh_ano
						END
				END
			,placa = ISNULL (ih.placa, '')
			,km = ISNULL (ih.km, 0)
			,fecha_creacion = ih.fecha_creacion 
			,precio_usado = ih.precio_usado
			,propietario = ISNULL (clpr.razon_social, '')
	INTO	#Vehiculos
	FROM	#Ordenes ot
		LEFT JOIN	cot_item_lote ih ON ot.vehiculo = ih.id
			 JOIN	cot_item ic ON ic.id=ih.id_cot_item
		LEFT JOIN	veh_linea_modelo l ON l.id=ic.id_veh_linea_modelo
		LEFT JOIN	veh_linea v ON v.id=ic.id_veh_linea
		LEFT JOIN	veh_marca m ON m.id = v.id_veh_marca
		LEFT JOIN	cot_item_talla ct ON ct.id=ic.id_cot_item_talla
		LEFT JOIN	v_campos_varios cv6 ON cv6.id_cot_item_lote=ih.id
		LEFT JOIN	veh_color col ON col.id = ih.id_veh_color
		LEFT JOIN	cot_cliente_contacto clco ON clco.id = ih.id_cot_cliente_contacto
		LEFT JOIN	cot_cliente clpr ON clpr.id = clco.id_cot_cliente AND clpr.id_emp = @emp;

	-- #Compras
	SELECT	DISTINCT sw = tico.sw
			,tipo = tico.descripcion
			,id = comp.id
			,numero = comp.numero_cotizacion
			,nit_proveedor = prov.nit
			,proveedor = prov.razon_social
			,fecha_registro = comp.fecha
			,vencimiento = comp.fecha_estimada
			,docref_numero = ISNULL (comp.docref_numero, '')
			,ant = ISNULL (comp.id_cot_cotizacion_ant, '')
			,anulado = ISNULL (CASE WHEN comp.anulada = 4 THEN 'Anulada' ELSE '' END, '')
			,notas= ISNULL (dcom.notas, '')
			,cantidad = dcom.cantidad
			,por_deducible = comp.deducible
			,val_deducible = (dcom.precio_lista * comp.deducible) / 100
			,iva = (dcom.precio_lista * dcom.porcentaje_iva) / 100
			,valor_neto = ISNULL (dcom.precio_cotizado * dcom.cantidad, 0)
			--,valor_neto = dcom.precio_cotizado
			,total = (((dcom.precio_cotizado * dcom.cantidad) * dcom.porcentaje_iva) / 100) + (dcom.precio_cotizado * dcom.cantidad)
			,clase = dcom.facturar_a
			,item = icom.codigo
			,id_item = dcom.id
			,vendedor = vend.nombre
	INTO #Compras
	FROM	#Ordenes ot 
		 LEFT JOIN	cot_cotizacion comp			ON ot.compra = comp.id
		 LEFT JOIN	cot_cotizacion_item dcom	ON	comp.id = dcom.id_cot_cotizacion
		 LEFT JOIN	cot_item icom				ON	icom.id = dcom.id_cot_item
			  JOIN	cot_tipo tico				ON	comp.id_cot_tipo = tico.id	AND tico.sw = 4 
         LEFT JOIN	cot_cliente prov			ON	prov.id = comp.id_cot_cliente
         LEFT JOIN	cot_bodega bode				ON	bode.id = comp.id_cot_bodega
		 --
		 left JOIN usuario vend ON comp.id_usuario_vende = vend.id
	ORDER BY comp.id;

	-- SELECT FINAL
	SELECT	DISTINCT SW = comp.sw
			,TIPO = comp.tipo
			,ID = comp.id
			,NUMERO = comp.numero
			,NIT_PROVEEDOR = comp.nit_proveedor
			,PROVEEDOR = comp.proveedor
			,FECHA_REGISTRO = comp.fecha_registro
			,VENCIMIENTO = comp.vencimiento
			,DOCREF_NUMERO = comp.docref_numero
			,ANT = comp.ant
			,ESTADO_CO = comp.anulado
			,MODELO = vehi.modelo
			,VIN = vehi.vin
			,PLACA = vehi.placa
			,PROPIETARIO_VH = vehi.propietario
			,ITEM = comp.item
			,NOTAS = comp.notas
			,CANTIDAD = ot.cantidad	
			,VALOR_NETO = comp.valor_neto
			,IVA = ot.iva
			,TOTAL = comp.total
			,VALOR_OT = ISNULL (ot.valor, 0)
			,VALOR_RECARGO_ESTABLE = comp.valor_neto + comp.val_deducible
			,PORCENTAJE_RECARGO_ESTABLE = comp.por_deducible
			,PORCENTAJE_RECARGO_COBRADO = ABS (((100 * ot.valor) /case when  isnull (comp.valor_neto,  0) = 0 then 1 else comp.valor_neto end) - 100)
			,ORDEN = ot.orden
			,BODEGA_OT = ot.bodega
			,CLIENTE = clie.razon_social
			,CLASE = comp.clase
			,USUARIO_OT = usu.nombre
			,VENDEDOR = comp.vendedor
			,ESTADO_OT = ot.estado
			,FINAL = ot.ot_final
			,FACTURA = ot.venta
			,FECHA_FACTURA = ot.fecha_venta
	FROM #Ordenes ot
		JOIN #Compras comp		ON ot.compra = comp.id AND ot.id_item = comp.id_item
		JOIN #Vehiculos vehi	ON ot.vehiculo = vehi.id
		JOIN cot_cliente clie	ON	ot.id_cot_cliente = clie.id
		JOIN usuario usu		ON	ot.id_usuario = usu.id
	where convert(date,comp.fecha_registro) between @fecIni and @fecFin
end