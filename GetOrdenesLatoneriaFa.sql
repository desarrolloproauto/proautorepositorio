SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



-- ========================================================================================================================================
-- Author:		<Angelica Pinos>
-- Create date: <0000-00-00>
-- Modulo:		<Reporteria>
-- Description:	<Procedimiento para obtener las ordenes de latoneria de taller que se encuentran facturadas (Reporte 100031 Advance)
-- Ejecucion:	EXEC [dbo].[GetOrdenesLatoneriaFa] 605, 0, '2021-07-01', '2021-07-22', 0;
-- Historial de Cambios:
-- 2021-07-27	Se agrega un procedimiento para obtener las ordenes de garantias y consolidados	
-- 2021-08-17   Se agrega el campo EMAIL del Cliente
-- 2021-08-24   Se modifica el campo DIAS_RETRASO para que nos muestre correctamente la diferencia entre la fecha de promesa de entrega
--              y la fecha de entrega del vehiculo al Cliente. (JCHB)     
-- 2021-08-24   Se modifica el campo EMAIL para que muestre el EMAIL de la Aseguradora o caso contrario del Cliente. (JCHB)
-- 2021-08-24   Se modifica el campo FECHA_AUTORIZACION_ASEGURADORA para que se muestre unicamente en las Facturas a Aseguradoras. (JCHB)
-- 2021-08-31	Se agrega la union con la tabla cot_cliente_contacto y cot_cliente para obetner el campo propietario
-- 2021-11-29	Se agrega la cedula o ruc del cliente
-- ========================================================================================================================================
--  exec [dbo].[GetOrdenesLatoneriaFa] 605,'0','2021-08-01','2021-08-31','0'

ALTER PROCEDURE [dbo].[GetOrdenesLatoneriaFa]
(
		@emp INT, 
		@Bod VARCHAR(MAX),
		@fecIni DATE,
		@fecFin DATE,
		@cli INT = '0'
)	
AS

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
set nocount on;

DECLARE @Bodega AS TABLE (
    id INT,
    descripcion VARCHAR(200),
    ecu_establecimiento VARCHAR(6)
)

-------------------------------TEMPORALES DISCO

-- INSERT #Bodega --> Bodegas que fueron seleccionadas en el filtro.
IF @Bod = '0'
    INSERT @Bodega (
        id,
        descripcion,
        ecu_establecimiento
    )
    SELECT id,
           descripcion,
           ecu_establecimiento
    FROM dbo.cot_bodega
	WHERE id_emp = @emp
ELSE
    INSERT @Bodega (
        id,
        descripcion,
        ecu_establecimiento
    )
    SELECT CAST(f.val AS INT),
           c.descripcion,
           c.ecu_establecimiento
    FROM dbo.fnSplit(@Bod, ',') f
    JOIN dbo.cot_bodega c ON c.id = CAST(f.val AS INT)

----NUEVO PROCESO DE GARANTIAS Y CONSOLIDADAS----------

CREATE TABLE #GARANTIAS 
(
	id_factura int,
	IdOrden int
)
INSERT #GARANTIAS EXEC [dbo].[GetOrdenesFacturasTaller] @emp, @Bod, @fecIni, @fecFin;
	
------------------------------INSERTAMOS EN DOCS LA INFROMACION DE GARANTIAS Y CONSOLIDADAS------------------------

-- INTO #Detdatos
SELECT	id_factura = c.id,
		ci.id,
		c.id_cot_cotizacion_sig,
		ci.id_cot_item,
		ci.cantidad,
		ci.facturar_a,
		ci.precio_cotizado,
		ci.tipo_operacion,
		ci.id_componenteprincipalest
INTO #Detdatos 
FROM dbo.cot_cotizacion c
JOIN dbo.cot_cotizacion_item ci ON ci.id_cot_cotizacion = c.id
WHERE c.id IN (SELECT g.id_factura FROM #GARANTIAS g);

----GMAH PERSONALIZADO

-- INTO #Detad
SELECT	id_factura = d.id_factura,
		id_det_fac = d.id,
		id_det_orden = c.id,
		id_otfinal = d.id_cot_cotizacion_sig,
		id_otori = ISNULL (c3.idv,c2.id),
		id_tal_garantia_clase = ccim.id_tal_garantia_clase,
		clasegarantia = ISNULL (tgc.descripcion, ''),
		facturar_a = d.facturar_a
INTO #Detad
FROM dbo.cot_cotizacion ct
JOIN dbo.cot_cotizacion_item c ON c.id_cot_cotizacion = ct.id
LEFT JOIN dbo.cot_cotizacion_item_mas ccim 	ON c.id = ccim.id_cot_cotizacion_item
LEFT JOIN dbo.cot_tipo tt ON tt.id = c.id_cot_tipo_tran
LEFT JOIN dbo.v_cot_cotizacion_item cci ON cci.id = c.id_cot_cotizacion_item_dev
LEFT JOIN dbo.v_cot_cotizacion_item_dev2 dev ON dev.id_cot_cotizacion_item = c.id
LEFT JOIN dbo.cot_cotizacion c3 ON c3.id = c.id_cot_cotizacion
LEFT JOIN cot_cotizacion c2 ON c2.id = ISNULL (c3.id_cot_cotizacion_sig, c.id_cot_cotizacion)
LEFT JOIN dbo.cot_tipo tjd ON tjd.id = c3.id_cot_tipo
LEFT JOIN dbo.cot_cotizacion cc ON cc.id = ct.id_cot_cotizacion_sig
LEFT JOIN dbo.tal_garantia_clase tgc ON tgc.id = ccim.id_tal_garantia_clase
JOIN #detdatos d ON (ct.id = d.id_cot_cotizacion_sig 
					OR ct.id_cot_cotizacion_sig = d.id_cot_cotizacion_sig 
					OR c.id_prd_orden_estruc = d.id_cot_cotizacion_sig 
					OR c.id_prd_orden_estructurapt = d.id_cot_cotizacion_sig) 
				AND d.id_componenteprincipalest = c.id
WHERE ISNULL (tjd.sw, 0) <> 1 
AND (tt.sw NOT IN (2, -1, 46, 47) OR tt.sw = 12 OR tt.sw IS NULL) 
AND c.cantidad - ISNULL(dev.cantidad_devuelta,0) > 0 
AND (c.tipo_operacion IS NOT NULL OR tt.sw = 47);





-- INTO #Docs --> Los ids de todas las órdenes incluidas las de garantías y consolidados
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
INTO #Docs
FROM dbo.cot_tipo t
JOIN  dbo.cot_cotizacion c ON t.id = c.id_cot_tipo AND c.id_emp = @emp	 
												   AND t.sw IN (1, -1)	  
												   AND ISNULL (c.anulada, 0) <> 4 	
												   AND CAST (c.fecha AS DATE) BETWEEN @fecIni AND @fecFin
JOIN @Bodega b ON b.id = c.id_cot_bodega     
JOIN dbo.cot_cotizacion_item i ON i.id_cot_cotizacion = c.id
LEFT JOIN dbo.v_cot_factura_saldo s ON s.id_cot_cotizacion = c.id
WHERE t.es_remision IS NULL
AND t.es_traslado IS NULL
AND c.id NOT IN (SELECT g.id_factura FROM #GARANTIAS g) -- c.id  in (select g.id_factura  from #GARANTIAS g) se pone in  para sacra consolidadas y grantias y not in para sacar todo lo demas
AND (@cli = 0 OR c.id_cot_cliente = @cli)
UNION
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
LEFT JOIN cot_cotizacion cc ON cc.id = c.id_cot_cotizacion AND cc.id_emp = @emp 
															AND ISNULL (cc.anulada, 0) <> 4 	 
															AND CAST (cc.fecha AS DATE) BETWEEN @fecIni AND @fecFin  
LEFT JOIN dbo.v_cot_factura_saldo sal ON sal.id_cot_cotizacion = cc.id
LEFT JOIN dbo.cot_tipo t ON t.id = cc.id_cot_tipo
LEFT JOIN dbo.v_cot_cotizacion_item cci ON cci.id = c.id_cot_cotizacion_item_dev
LEFT JOIN dbo.v_cot_cotizacion_item_dev2 dev ON dev.id_cot_cotizacion_item = c.id
LEFT JOIN dbo.v_cot_cotizacion_item cci2 ON cci2.id = c.id --MEP
LEFT JOIN #Detad adi ON adi.id_det_fac =	c.id	--GMAH PERSONALIZADO
LEFT JOIN cot_cotizacion cco ON cco.id=adi.id_otori AND cco.id_emp = @emp
LEFT JOIN dbo.cot_bodega b ON b.id = cco.id_cot_bodega
WHERE c.id_cot_cotizacion IN (SELECT g.id_factura FROM #GARANTIAS g) 
AND (c.id_cot_cotizacion_item IS NULL)
AND t.sw IN (1, -1) AND t.es_remision IS NULL AND t.es_traslado IS NULL
AND (@cli=0 or cc.id_cot_cliente = @cli);


-- INTO #Devolciones --> Validación notas credito 
SELECT DISTINCT id = d.id,
       factura = CAST (ISNULL (bd.ecu_establecimiento, '') AS VARCHAR(4))
                 + CAST(ISNULL(t3.ecu_emision, '') AS VARCHAR(4)) COLLATE Modern_Spanish_CI_AI + ''
                 + RIGHT('000000000' + CAST(cc3.numero_cotizacion AS VARCHAR(100)), 9),
		id_factura = fdev.id_cot_cotizacion_factura,
		concepto = ISNULL (conc.descripcion, '')
INTO #Devoluciones
FROM #Docs d
JOIN dbo.v_cot_cotizacion_factura_dev fdev ON d.sw = -1 AND fdev.id_cot_cotizacion = d.id
JOIN dbo.cot_cotizacion cc3 ON cc3.id = fdev.id_cot_cotizacion_factura
JOIN dbo.cot_tipo t3 ON t3.id = cc3.id_cot_tipo
JOIN dbo.cot_bodega bd ON bd.id = cc3.id_cot_bodega
LEFT JOIN com_orden_concep conc ON conc.id = cc3.id_com_orden_concep;

-- INTO #Linea --> INSERTAMOS LA LINEA DE LOS ITEMS DEL GRUPO REPUESTOS, TALLER Y TOT
SELECT 	id_item = item.id, 
		linea = CASE WHEN grup.id = 1337 THEN 'TOT' ELSE grup.descripcion END
INTO #Linea
FROM #Docs docs 
	JOIN dbo.cot_item item ON item.id = docs.id_cot_item
	JOIN dbo.cot_grupo_sub gsub ON gsub.id = item.id_cot_grupo_sub
	JOIN dbo.cot_grupo grup ON grup.id = gsub.id_cot_grupo
WHERE grup.id IN (1321, 1322, 1323, 1326, 1337)
GROUP BY item.id, grup.id, grup.descripcion
UNION
SELECT 	id_item = item.id, 
		linea = CASE WHEN gsub.descripcion LIKE '%TAL%' THEN
							SUBSTRING(gsub.descripcion, CHARINDEX ('-', gsub.descripcion) + 1, 6) 
					 ELSE 'VEHICULOS'
				END
FROM #Docs docs 
	JOIN dbo.cot_item item ON item.id = docs.id_cot_item
	JOIN dbo.cot_grupo_sub gsub ON gsub.id = item.id_cot_grupo_sub
	JOIN dbo.cot_grupo grup ON grup.id = gsub.id_cot_grupo
WHERE grup.id IN (1332, 1341)
GROUP BY item.id, gsub.descripcion;



----- SELECT FINAL -----
SELECT	SW = tfac.sw, 
		BODEGA = bod.descripcion,
		VIN = vhl.vin,
		NRO_ORDEN = ISNULL (d.id_cot_cotizacion_sig, 0),
		[CI/RUC] = CASE WHEN tfac.sw = 1 THEN	
						(SELECT TOP 1 c.nit
							FROM #Docs d
							JOIN cot_cliente c ON c.id = d.id_cot_cliente
							JOIN cot_tipo tipo ON tipo.id = d.id_cot_tipo
							WHERE d.id_cot_cotizacion_sig = ot.id AND tipo.descripcion NOT LIKE 'NC%' ORDER BY tipo.descripcion DESC)
					ELSE (SELECT TOP 1 c.razon_social
							FROM #Docs d
							JOIN cot_cliente c ON c.id = d.id_cot_cliente
							JOIN cot_tipo tipo ON tipo.id = d.id_cot_tipo
							WHERE d.id_cot_cotizacion_sig = ot.id AND tipo.descripcion LIKE 'NC%')
					END,
		NOMBRES = CASE WHEN tfac.sw = 1 THEN	
						(SELECT TOP 1 c.razon_social
							FROM #Docs d
							JOIN cot_cliente c ON c.id = d.id_cot_cliente
							JOIN cot_tipo tipo ON tipo.id = d.id_cot_tipo
							WHERE d.id_cot_cotizacion_sig = ot.id AND tipo.descripcion NOT LIKE 'NC%' ORDER BY tipo.descripcion DESC)
					ELSE (SELECT TOP 1 c.razon_social
							FROM #Docs d
							JOIN cot_cliente c ON c.id = d.id_cot_cliente
							JOIN cot_tipo tipo ON tipo.id = d.id_cot_tipo
							WHERE d.id_cot_cotizacion_sig = ot.id AND tipo.descripcion LIKE 'NC%')
					END,
		TIPO_DOCUMENTO = CASE WHEN tfac.sw = 1 THEN	
						(SELECT TOP 1 tipo.descripcion
							FROM #Docs d
							JOIN cot_cliente c ON c.id = d.id_cot_cliente
							JOIN cot_tipo tipo ON tipo.id = d.id_cot_tipo
							WHERE d.id_cot_cotizacion_sig = ot.id AND tipo.descripcion NOT LIKE 'NC%' ORDER BY tipo.descripcion DESC)
					ELSE (SELECT TOP 1 tipo.descripcion
							FROM #Docs d
							JOIN cot_cliente c ON c.id = d.id_cot_cliente
							JOIN cot_tipo tipo ON tipo.id = d.id_cot_tipo
							WHERE d.id_cot_cotizacion_sig = ot.id AND tipo.descripcion LIKE 'NC%')
					END,
		ID_DOCUMENTO = CASE WHEN tfac.sw = 1 THEN	
						(SELECT TOP 1 d.id
							FROM #Docs d
							JOIN cot_cliente c ON c.id = d.id_cot_cliente
							JOIN cot_tipo tipo ON tipo.id = d.id_cot_tipo
							WHERE d.id_cot_cotizacion_sig = ot.id AND tipo.descripcion NOT LIKE 'NC%' ORDER BY tipo.descripcion DESC)
					ELSE (SELECT TOP 1 d.id
							FROM #Docs d
							JOIN cot_cliente c ON c.id = d.id_cot_cliente
							JOIN cot_tipo tipo ON tipo.id = d.id_cot_tipo
							WHERE d.id_cot_cotizacion_sig = ot.id AND tipo.descripcion LIKE 'NC%')
					END,
		FACTURA = CASE WHEN tfac.sw = 1 THEN	
						(SELECT TOP 1 CASE
											WHEN tipo.sw = -1 THEN de.factura
											ELSE CAST (ISNULL (b.ecu_establecimiento, '') AS VARCHAR(4)) + CAST (ISNULL (tipo.ecu_emision, '') AS VARCHAR(4)) COLLATE modern_spanish_ci_ai + '' + RIGHT ('000000000' + CAST (d.numero_cotizacion AS VARCHAR(100)), 9)
										END
								FROM #Docs d
								JOIN @Bodega b ON b.id = d.id_cot_bodega
								LEFT JOIN #Devoluciones de ON de.id = d.id
								JOIN cot_tipo tipo ON tipo.id = d.id_cot_tipo
							WHERE d.id_cot_cotizacion_sig = ot.id AND tipo.descripcion NOT LIKE 'NC%' ORDER BY tipo.descripcion DESC)
					ELSE (SELECT TOP 1 CASE
										WHEN tipo.sw = -1 THEN de.factura
										ELSE CAST (ISNULL (b.ecu_establecimiento, '') AS VARCHAR(4)) + CAST (ISNULL (tipo.ecu_emision, '') AS VARCHAR(4)) COLLATE modern_spanish_ci_ai + '' + RIGHT ('000000000' + CAST (d.numero_cotizacion AS VARCHAR(100)), 9)
									END
							FROM #Docs d
							JOIN @Bodega b ON b.id = d.id_cot_bodega
							LEFT JOIN #Devoluciones de ON de.id = d.id
							JOIN cot_tipo tipo ON tipo.id = d.id_cot_tipo
							WHERE d.id_cot_cotizacion_sig = ot.id AND tipo.descripcion LIKE 'NC%')
					END,
		FECHA_INGRESO = ot.fecha_creacion,
		FECHA_PROMESA = ot.fecha_estimada,
		FECHA_FACTURACION = CASE WHEN tfac.sw = 1 THEN	
								(SELECT TOP 1 d.fecha
									FROM #Docs d
									JOIN cot_cliente c ON c.id = d.id_cot_cliente
									JOIN cot_tipo tipo ON tipo.id = d.id_cot_tipo
									WHERE d.id_cot_cotizacion_sig = ot.id AND tipo.descripcion NOT LIKE 'NC%' ORDER BY tipo.descripcion DESC)
							ELSE (SELECT TOP 1 d.fecha
									FROM #Docs d
									JOIN cot_cliente c ON c.id = d.id_cot_cliente
									JOIN cot_tipo tipo ON tipo.id = d.id_cot_tipo
									WHERE d.id_cot_cotizacion_sig = ot.id AND tipo.descripcion LIKE 'NC%')
							END,
		FECHA_ENTREGA_REAL = ot.fecha_cambio_status_final,
		--DIAS_RETRASO = DATEDIFF (DAY, ot.fecha_estimada, getdate()),
		ANIO = ISNULL((CASE WHEN m.descripcion like '%MULTIMARCA%'
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
	END)),
		MARCA = ISNULL((CASE WHEN m.descripcion like '%MULTIMARCA%'
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
	END)), 
		DESCRIPCION = ISNULL(( CASE WHEN m.descripcion like '%MULTIMARCA%'
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
		COLOR = isnull(col.descripcion,''),
		TELEFONO_1 = CASE WHEN tfac.sw = 1 THEN	
						(SELECT TOP 1 ISNULL (c.tel_1, '')
							FROM #Docs d
							JOIN cot_cliente c ON c.id = d.id_cot_cliente
							JOIN cot_tipo tipo ON tipo.id = d.id_cot_tipo
							WHERE d.id_cot_cotizacion_sig = ot.id AND tipo.descripcion NOT LIKE 'NC%' ORDER BY tipo.descripcion DESC)
					ELSE (SELECT TOP 1 ISNULL (c.tel_1, '')
							FROM #Docs d
							JOIN cot_cliente c ON c.id = d.id_cot_cliente
							JOIN cot_tipo tipo ON tipo.id = d.id_cot_tipo
							WHERE d.id_cot_cotizacion_sig = ot.id AND tipo.descripcion LIKE 'NC%')
					END,
		TELEFONO_2 = CASE WHEN tfac.sw = 1 THEN	
						(SELECT TOP 1 ISNULL (c.tel_2, '')
							FROM #Docs d
							JOIN cot_cliente c ON c.id = d.id_cot_cliente
							JOIN cot_tipo tipo ON tipo.id = d.id_cot_tipo
							WHERE d.id_cot_cotizacion_sig = ot.id AND tipo.descripcion NOT LIKE 'NC%' ORDER BY tipo.descripcion DESC)
					ELSE (SELECT TOP 1 ISNULL (c.tel_2, '')
							FROM #Docs d
							JOIN cot_cliente c ON c.id = d.id_cot_cliente
							JOIN cot_tipo tipo ON tipo.id = d.id_cot_tipo
							WHERE d.id_cot_cotizacion_sig = ot.id AND tipo.descripcion LIKE 'NC%')
					END,
		EMAIL = clia.[url],
		EMAIL2 = clia2.[url],
		ASEGURADORA = ISNULL (clia.razon_social,''),
		ESTADO_VH = ubod.descripcion,
		PLACA = ISNULL(vhl.placa,''),
		FECHA_ENVIO_COTIZACION = cmas.fecha_envio_ase,
		FECHA_AUTORIZACION_ASEGURADORA = ot.fecha_cartera,

		NO_REP_APROBADOS = ISNULL (d.docref_numero, ''),
		PRIMER_SERVIDO = CASE WHEN clia.razon_social IS NULL 
							  THEN ISNULL ((SELECT SUM (it.cantidad)
										FROM #Docs d
										LEFT JOIN cot_cotizacion_item it on it.id = d.id_cot_cotizacion_item
										JOIN #Linea lin ON lin.id_item = d.id_cot_item 
										WHERE it.id_cot_cotizacion = ot.id
										AND lin.linea = 'REPUESTOS'
										AND it.fecha_tran >= ot.fecha
										AND it.fecha_tran <= DATEADD (DAY, 2, ot.fecha)), 0)
							  ELSE ISNULL ((SELECT SUM (it.cantidad)
										FROM #Docs d
										LEFT JOIN cot_cotizacion_item it on it.id = d.id_cot_cotizacion_item
										JOIN #Linea lin ON lin.id_item = d.id_cot_item 
										WHERE it.id_cot_cotizacion = ot.id
										AND lin.linea = 'REPUESTOS'
										AND it.fecha_tran >= ot.fecha_cartera
										AND it.fecha_tran <= DATEADD (DAY, 2, ot.fecha_cartera)), 0)
							END,
		SERVIDO_ACTUAL = CASE WHEN clia.razon_social IS NULL 
							  THEN ISNULL ((SELECT SUM (it.cantidad)
											FROM #Docs d
											LEFT JOIN cot_cotizacion_item it on it.id = d.id_cot_cotizacion_item
											JOIN #Linea lin ON lin.id_item = d.id_cot_item 
											WHERE it.id_cot_cotizacion = ot.id
											AND lin.linea = 'REPUESTOS'
											AND it.fecha_tran >= ot.fecha), 0)
							  ELSE ISNULL ((SELECT SUM (it.cantidad)
											FROM #Docs d
											LEFT JOIN cot_cotizacion_item it on it.id = d.id_cot_cotizacion_item
											JOIN #Linea lin ON lin.id_item = d.id_cot_item 
											WHERE it.id_cot_cotizacion = ot.id
											AND lin.linea = 'REPUESTOS'
											AND it.fecha_tran >= ot.fecha_cartera), 0)
							END,
		HORAS_ENVIO_COTIZACION = ISNULL (DATEDIFF (HOUR, ot.fecha, cmas.fecha_envio_ase), 0),
		HORAS_AUTORIZACION_ASEGURADORA = ISNULL (DATEDIFF (HOUR, cmas.fecha_envio_ase, ot.fecha_cartera), 0),
		HORAS_ENTREGA_REAL = DATEDIFF (HOUR, ot.fecha_estimada, ot.fecha_cambio_status_final),
		HORAS_PERMANENCIA = ISNULL (DATEDIFF (HOUR , ot.fecha, ot.fecha_cambio_status_final), 
										DATEDIFF(HOUR, ot.fecha, GETDATE())),
		DIAS_PERMANENCIA = ISNULL (DATEDIFF (DAY, ot.fecha, ot.fecha_cambio_status_final), 
								 DATEDIFF(DAY, ot.fecha, GETDATE())), 
		VALOR_NETO_FACTURADO = SUM (CASE WHEN d.facturar_a <> 'S' THEN ABS (d.precio_cotizado) * ABS (d.cantidad_und) * CASE WHEN tfac.sw = 1 THEN 1 ELSE -1 END ELSE 0 END),
		-- Se agrega subselect para obtener el total neto de los items registrados en la orden del taller
		VALOR_NETO_PENDIENTE = ISNULL ((SELECT SUM (CASE WHEN it.facturar_a <> 'S' THEN ABS (it.precio_cotizado) * ABS (it.cantidad_und) ELSE 0 END)
								FROM cot_cotizacion ottr
								JOIN cot_cotizacion_item it ON it.id_cot_cotizacion = ottr.id
								JOIN cot_tipo ti on ti.id = ottr.id_cot_tipo
								WHERE (ottr.id = ot.id OR ottr.id_cot_cotizacion_sig = ot.id)
								AND ti.sw IN (2,46) AND it.facturar_a IS NOT NULL
								AND it.id NOT IN (SELECT it.id FROM v_tal_orden_item_facturados_mep_proauto WHERE id_componenteprincipalEst = it.id)) 
							* CASE WHEN tfac.sw = 1 THEN 1 ELSE -1 END, 0),
		VALOR_TOTAL_FACTURADO = SUM (CASE WHEN d.facturar_a <> 'S' THEN ABS (d.precio_cotizado) * ABS (d.cantidad_und) * ( 1 + d.porcentaje_iva / 100 ) * CASE WHEN tfac.sw = 1 THEN 1 ELSE -1 END  ELSE 0 END),
		-- Se agrega subselect para obtener el total total de los items registrados en la orden del taller
		VALOR_TOTAL_PENDIENTE = ISNULL ((	SELECT SUM (CASE WHEN it.facturar_a <> 'S' THEN it.precio_cotizado * it.cantidad_und * ( 1 + it.porcentaje_iva / 100 ) ELSE 0 END)
									FROM cot_cotizacion ottr
									JOIN cot_cotizacion_item it ON it.id_cot_cotizacion = ottr.id
									JOIN cot_tipo ti on ti.id = ottr.id_cot_tipo
									WHERE (ottr.id = ot.id OR ottr.id_cot_cotizacion_sig = ot.id)
									AND ti.sw IN (2,46) AND it.facturar_a IS NOT NULL
									AND it.id NOT IN (SELECT it.id FROM v_tal_orden_item_facturados_mep_proauto WHERE id_componenteprincipalEst = it.id))  
								* CASE WHEN tfac.sw = 1 THEN 1 ELSE -1 END, 0),
		INSUMO_NETO_FACTURADO = SUM (CASE WHEN d.facturar_a = 'S' THEN ABS (d.precio_cotizado) * ABS (d.cantidad_und) * CASE WHEN tfac.sw = 1 THEN 1 ELSE -1 END ELSE 0 END),
		-- Se agrega subselect para obtener el total neto de los insumos registrados en la orden del taller
		INSUMO_NETO_PENDIENTE = ISNULL ((	SELECT SUM (CASE WHEN it.facturar_a = 'S' THEN ABS (it.precio_cotizado) * ABS (it.cantidad_und) ELSE 0 END)
									FROM cot_cotizacion ottr
									JOIN cot_cotizacion_item it ON it.id_cot_cotizacion = ottr.id
									JOIN cot_tipo ti on ti.id = ottr.id_cot_tipo
									WHERE (ottr.id = ot.id OR ottr.id_cot_cotizacion_sig = ot.id)
									AND ti.sw IN (2,46) AND it.facturar_a IS NOT NULL
									AND it.id NOT IN (SELECT it.id FROM v_tal_orden_item_facturados_mep_proauto WHERE id_componenteprincipalEst = it.id))  
								* CASE WHEN tfac.sw = 1 THEN 1 ELSE -1 END, 0),
		INSUMO_TOTAL_FACTURADO = SUM (CASE WHEN d.facturar_a = 'S' THEN d.precio_cotizado * d.cantidad_und * ( 1 + d.porcentaje_iva / 100 ) * CASE WHEN tfac.sw = 1 THEN 1 ELSE -1 END  ELSE 0 END),
		-- Se agrega subselect para obtener el total total de los insumos registrados en la orden del taller
		INSUMO_TOTAL_PENDIENTE = ISNULL ((	SELECT SUM (CASE WHEN it.facturar_a = 'S' THEN it.precio_cotizado * it.cantidad_und * ( 1 + it.porcentaje_iva / 100 ) ELSE 0 END)
									FROM cot_cotizacion ottr
									JOIN cot_cotizacion_item it ON it.id_cot_cotizacion = ottr.id
									JOIN cot_tipo ti on ti.id = ottr.id_cot_tipo
									WHERE (ottr.id = ot.id OR ottr.id_cot_cotizacion_sig = ot.id)
									AND ti.sw IN (2,46) AND it.facturar_a IS NOT NULL
									AND it.id NOT IN (SELECT it.id FROM v_tal_orden_item_facturados_mep_proauto WHERE id_componenteprincipalEst = it.id))  
								* CASE WHEN tfac.sw = 1 THEN 1 ELSE -1 END, 0),
		COMENTARIO = '',
		ASESOR_SERVICIO = uven.nombre,
		--PROPIETARIO = cli3.razon_social,
		PROPIETARIO = p.razon_social,
		--EMAIL_PROPIETARIO = cli3.url,
		EMAIL_PROPIETARIO = p.url,
		--TELF1 = cli3.tel_1,
		--TELF2 = cli3.tel_2,
		TELF1 = p.tel_1,
		TELF2 = p.tel_2
into #Resultado
FROM #docs d
JOIN #Linea line ON line.id_item = d.id_cot_item
JOIN dbo.cot_tipo tfac ON tfac.id = d.id_cot_tipo 
JOIN @Bodega b1         ON b1.id = d.id_cot_bodega 
JOIN cot_bodega b on b.id=b1.id 
		 JOIN dbo.cot_cotizacion cb ON cb.id = d.id
		 JOIN dbo.cot_bodega bod ON bod.id = cb.id_cot_bodega
LEFT JOIN dbo.usuario uven ON uven.id = d.id_usuario_ven
LEFT JOIN dbo.cot_cotizacion ot on ot.id=d.id_cot_cotizacion_sig
LEFT JOIN cot_cliente p on p.id = ot.id_cot_cliente

LEFT join cot_item_lote ih on ih.id=d.id_cot_item_vhtal
LEFT join cot_item ic on ic.id=ih.id_cot_item
left Join veh_linea_modelo l on l.id=ic.id_veh_linea_modelo
left Join veh_linea v on v.id=ic.id_veh_linea
left Join veh_marca m on m.id=v.id_veh_marca
LEFT JOIN cot_item_talla ct on ct.id=ic.id_cot_item_talla
left join v_campos_varios cv6 on cv6.id_cot_item_lote=ih.id
LEFT JOIN dbo.cot_cotizacion_mas cmas ON cmas.id_cot_cotizacion=ot.id
LEFT JOIN cot_item_lote vhl ON VHl.id=ot.id_cot_item_lote
--LEFT JOIN cot_cliente_contacto cli on cli.id=vhl.id_cot_cliente_contacto

--LEFT JOIN dbo.cot_cliente cli3 ON cli3.id = cli.id_cot_cliente and cli3.id_emp=@emp

LEFT JOIN v_campos_varios cv On cv.id_cot_cotizacion=ot.id and cv.campo_1 is not null
left Join veh_color col on vhl.id_veh_color=col.id
left Join veh_color col2 on ih.id_veh_color_int=col2.id
LEFT join cot_item ic2 on ic2.id=vhl.id_cot_item
left Join veh_linea_modelo l2 on l2.id=ic2.id_veh_linea_modelo
left Join veh_linea v2 on v2.id=ic2.id_veh_linea
left Join veh_marca m2 on m2.id=v2.id_veh_marca
left join v_campos_varios cv7 on cv7.id_cot_item_lote=vhl.id
LEFT JOIN dbo.cot_cliente clia ON clia.id = ot.id_cot_cliente2  --Saca el email del cliente que son Aseguradoras
LEFT JOIN dbo.cot_cliente clia2 ON clia2.id = ot.id_cot_cliente --Para sacar el email del cliente que no son Aseguradoras
LEFT JOIN cot_bodega_ubicacion ubod ON ubod.id=ot.id_cot_bodega_ubicacion
WHERE cv.campo_1 LIKE '02%' 
----AND fac.id in (360453,351746,352656)
GROUP BY tfac.sw, bod.descripcion, vhl.vin, d.id_cot_cotizacion_sig, ot.id, ot.fecha_creacion, ot.fecha_estimada, ot.fecha_cambio_status_final,
			m.descripcion, cv6.campo_13, ic.id_veh_ano, ic.codigo, m2.descripcion, cv7.campo_13, ic2.id_veh_ano, ic2.codigo, 
			cv6.campo_11, cv7.campo_11, cv6.campo_12, ic.descripcion, cv7.campo_12, ic2.descripcion, col.descripcion,
			clia.razon_social,clia2.[url],clia.[url], ubod.descripcion, vhl.placa, ot.fecha, cmas.fecha_envio_ase, 
			ot.fecha_cartera, d.docref_numero, uven.nombre, --cli3.razon_social,cli3.url,cli3.tel_1,cli3.tel_2,
			p.razon_social,p.tel_1,p.tel_2,p.url
ORDER BY 4;

--  exec [dbo].[GetOrdenesLatoneriaFa] 605,'0','2021-08-01','2021-08-31','0'


-- SELECT FINAL
SELECT 	r.SW,
		r.BODEGA,
		r.[CI/RUC],
		FACTURADO_A = r.NOMBRES,
		TELF_FACTURA = r.TELEFONO_1,
		TELF2_FACTURA = r.TELEFONO_2,
		EMAIL_FACTURA = IIF(ISNULL(r.EMAIL,'0')='0',r.EMAIL2,r.EMAIL), -- Se saca el EMAIL de la Aseguradora o caso contrario del Cliente
		r.ASEGURADORA,
		r.TIPO_DOCUMENTO,
		r.ID_DOCUMENTO,
		r.FACTURA,
		r.FECHA_INGRESO,
		r.FECHA_PROMESA,
		r.FECHA_FACTURACION,
		r.FECHA_ENTREGA_REAL,
		DIAS_RETRASO = DATEDIFF (DAY, r.FECHA_PROMESA, r.FECHA_FACTURACION),
		r.ANIO,
		r.MARCA,
		r.DESCRIPCION,
		r.COLOR,
		--r.EMAIL2,
		r.ESTADO_VH,
		r.PLACA,
		r.VIN,
		r.NRO_ORDEN,
		r.PROPIETARIO,
		--r.PROPIETARIO2,
		r.EMAIL_PROPIETARIO,
		r.TELF1,
		r.TELF2,
		r.FECHA_ENVIO_COTIZACION,
		FECHA_AUTORIZACION_ASEGURADORA = CASE	
			WHEN LEN(r.ASEGURADORA) > 0 THEN r.FECHA_AUTORIZACION_ASEGURADORA
		END, -- Se saca la FECHA_AUTORIZACION_ASEGURADORA unicamente de las Facturas que fueron realizadas a Aseguradora
		r.NO_REP_APROBADOS,
		r.PRIMER_SERVIDO,
		r.SERVIDO_ACTUAL,
		r.HORAS_ENVIO_COTIZACION,
		r.HORAS_AUTORIZACION_ASEGURADORA,
		r.HORAS_ENTREGA_REAL,
		r.HORAS_PERMANENCIA,
		r.DIAS_PERMANENCIA,
		r.VALOR_NETO_FACTURADO,
		r.VALOR_NETO_PENDIENTE,
		r.VALOR_TOTAL_FACTURADO,
		r.VALOR_TOTAL_PENDIENTE,
		r.INSUMO_NETO_FACTURADO,
		r.INSUMO_NETO_PENDIENTE,
		r.INSUMO_TOTAL_FACTURADO,
		r.INSUMO_TOTAL_PENDIENTE,
		r.COMENTARIO,
		r.ASESOR_SERVICIO
FROM #Resultado r

-- Eliminar tablas Temporales
drop table #Resultado
drop table #GARANTIAS
drop table #Detdatos
drop table #Detad
drop table #Docs
drop table #Devoluciones
drop table #Linea

GO
