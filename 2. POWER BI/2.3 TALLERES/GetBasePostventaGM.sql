USE [dms_smd3]
GO
/****** Object:  StoredProcedure [dbo].[GetBasePostventaGM]    Script Date: 15/2/2022 11:47:32 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ===========================================================================================================================================================================
-- Author:		<Ramiro Paredes>
-- Create date: <28-01-2022>
-- Modulo:		<Reporteria>
-- Description:	<Procedimiento para obtener informacion de base de postventa para GM  (basado en SP GetPerfilClientesGM)>
-- Historial de Cambios:
--> 28-01-2022	-->	Pase a produccion
--> 31-01-2022  --> Se cambian nombres de columnas y se extrae el TIPO_SERVICIO según indicaciones de Ximena
--> 01-02-2022  --> Se cambia nombre de columna ORDEN_DE_TRABAJO y se presenta fecha de salida (Pedido por Alex Acosta)
--> 15-02-2022  --> Se aumenta campos TIPO y AGENCIA. Se quita consulta masiva de clientes (RPC)
-- ===========================================================================================================================================================================

-- EXEC [dbo].[GetBasePostventaGM] '2022-01-01','2022-01-31'


ALTER PROCEDURE [dbo].[GetBasePostventaGM]
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
		id_cot_item INT,
		id_usuario_ven INT,
		sw INT,
		ot INT,
		id_veh_hn_enc iNT, 
		id_cot_cotizacion_item int,
		facturar_a char(2) ,
		tipo_operacion char(2) , 
		id_cot_item_vhtal  int ,
		id_cot_cotizacion_sig int ,
		id_operario int,
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
	where b.id_emp = 605
	and b.descripcion like '% TAL'

	

	----NUEVO PROCESO DE GARANTIAS Y CONSOLIDADAS----------
	create table #OTs_CONSOLIDADAS_GARATIAS
	(
		id_factura int,
		IdOrden int
	)
	insert #OTs_CONSOLIDADAS_GARATIAS
	exec [dbo].[GetOrdenesFacturasTaller] @emp,@Bod,@fecIni,@fecFin
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
		id_cot_item,
		id_usuario_ven,
		sw,
		id_veh_hn_enc ,
		id_cot_cotizacion_item ,
		facturar_a,
		tipo_operacion ,
		id_cot_item_vhtal,
		id_cot_cotizacion_sig,
		id_operario,												 
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
		   id_cot_item = i.id_cot_item,
		   id_usuario_ven = c.id_usuario_vende,
		   sw = t.sw,
		   id_veh_hn_enc = c.id_veh_hn_enc,
		   id_cot_cotizacion_item = i.id,
		   facturar_a = i.facturar_a,
		   tipo_operacion = i.tipo_operacion	,
		   id_cot_item_vhtal = c.id_cot_item_lote ,
		   id_cot_cotizacion_sig = c.id_cot_cotizacion_sig,
		   id_operario = i.id_operario,
		   ot_final = c.id_cot_cotizacion_sig,
		   tipo_orden = 'F',
		   id_item = i.id_componenteprincipalEst
	FROM dbo.cot_cotizacion c 
	JOIN dbo.cot_tipo t ON (t.id = c.id_cot_tipo) 
    JOIN @Bodega b ON (b.id = c.id_cot_bodega)     
	JOIN dbo.cot_cotizacion_item i ON (i.id_cot_cotizacion = c.id)
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
			ci.id,
			c.id_cot_cotizacion_sig,
			ci.facturar_a,
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
		facturar_a varchar(5)
	)

	INSERT #detad
	(
		id_factura, 
		id_det_fac,
		id_det_orden,
		id_otfinal, 
		id_otori ,
		facturar_a
	)
	SELECT	id_factura = d.id_factura,
			id_det_fac = d.id,
			id_det_orden = c.id,
			id_otfinal = d.id_cot_cotizacion_sig,
			id_otori = ISNULL (c3.idv,c2.id),
			facturar_a = d.facturar_a
	FROM dbo.cot_cotizacion ct
	JOIN dbo.cot_cotizacion_item c ON c.id_cot_cotizacion = ct.id
	LEFT JOIN dbo.cot_tipo tt ON tt.id = c.id_cot_tipo_tran
	LEFT JOIN dbo.v_cot_cotizacion_item_dev2 dev ON dev.id_cot_cotizacion_item = c.id
	LEFT JOIN dbo.cot_cotizacion c3 ON c3.id = c.id_cot_cotizacion
	LEFT JOIN cot_cotizacion c2 ON c2.id = ISNULL(c3.id_cot_cotizacion_sig,c.id_cot_cotizacion)
	LEFT JOIN dbo.cot_tipo tjd 	ON tjd.id = c3.id_cot_tipo
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
		id_cot_item,
		id_usuario_ven,
		sw,
		id_veh_hn_enc ,
		id_cot_cotizacion_item ,
		facturar_a,
		tipo_operacion ,
		id_cot_item_vhtal,
		id_cot_cotizacion_sig,
		id_operario,												 
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
			id_cot_item = c.id_cot_item,
			id_usuario_ven = cco.id_usuario_vende,
			sw = t.sw,
			id_veh_hn_enc = cc.id_veh_hn_enc,
			id_cot_cotizacion_item = c.id,
			facturar_a = c.facturar_a,
			tipo_operacion = cci2.tipo_operacion, -- MEP
			id_cot_item_vhtal = cco.id_cot_item_lote ,
			id_cot_cotizacion_sig = adi.id_otori, --GMAH PERSONALIZADO
			id_operario = c.id_operario,
			ot_final = adi.id_otfinal,
			tipo_orden = adi.facturar_a,
			id_item = c.id_componenteprincipalEst
	FROM dbo.v_cot_cotizacion_item_todos_mep c
	inner JOIN cot_cotizacion cc ON cc.id=c.id_cot_cotizacion and cc.id_emp=605 and isnull(cc.anulada,0) <>4 	 and  CAST(cc.fecha AS DATE)  BETWEEN @fecIni AND @fecFin  --and  CAST(cc.fecha AS DATE)  BETWEEN @fecIni AND @fecFin
	LEFT JOIN dbo.cot_tipo t ON t.id = cc.id_cot_tipo
	LEFT JOIN dbo.v_cot_cotizacion_item cci ON cci.id = c.id_cot_cotizacion_item_dev
	LEFT JOIN dbo.v_cot_cotizacion_item cci2 ON cci2.id = c.id --MEP
	LEFT JOIN dbo.v_cot_cotizacion_factura_dev fdev ON fdev.id_cot_cotizacion = CASE WHEN t.sw = -1 THEN c.id_cot_cotizacion ELSE NULL END
	LEFT JOIN #detad adi ON adi.id_det_fac= CASE WHEN t.sw = -1 THEN cci.id ELSE c.id END --GMAH PERSONALIZADO
	LEFT JOIN cot_cotizacion cco ON cco.id=adi.id_otori and cco.id_emp=@emp
	WHERE (t.sw = 1 AND (c.id_cot_cotizacion IN (select g.id_factura from #OTs_CONSOLIDADAS_GARATIAS g)) 
		OR t.sw = -1 AND (fdev.id_cot_cotizacion_factura IN (select g.id_factura from #OTs_CONSOLIDADAS_GARATIAS_NC g)))
	AND (c.id_cot_cotizacion_item IS NULL)
	and t.sw IN ( 1, -1 ) 
	and t.es_remision is null 
    and t.es_traslado is null 
    and (@cli=0 or cc.id_cot_cliente=@cli)
	AND (ISNULL (c.facturar_a, 'NULL') <> 'S') -- Excluimos los ítems que corresponden a insumos

	
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
	
	/*
	--4.Cargar información de terceros
	SELECT	DISTINCT
			[id] = c.id,
			[razon_social] = c.razon_social,
	        [nombres] =	ISNULL(cn.nom1 + ' ' + cn.nom2, c.razon_social),
	        [apellidos] = ISNULL(cn.ape1 + ' ' + cn.ape2, ''),
	        [nit] = c.nit,
		    [Telefono_1] = CASE 
							WHEN LEN (cc.tel_1) >= 6 and LEN (cc.tel_1) <= 10 THEN cc.tel_1
							ELSE ''
						END,
	        [Telefono_2] = CASE 
							WHEN LEN (c.tel_1) >= 6 and LEN (c.tel_1) <= 10 THEN c.tel_1
							ELSE ''
						END,
	        [pais] = ISNULL(p.descripcion, ''),
	        [mail] = cc.email
	INTO #Clientes
	FROM dbo.cot_cliente c
		 JOIN dbo.cot_cliente_pais pc ON pc.id = c.id_cot_cliente_pais
		 JOIN dbo.cot_cliente_pais pd ON pd.id = pc.id_cot_cliente_pais
	     JOIN dbo.cot_cliente_pais p ON p.id = pd.id_cot_cliente_pais
	     JOIN dbo.cot_cliente_contacto cc ON cc.id = c.id_cot_cliente_contacto
	LEFT JOIN dbo.cot_cliente_nom cn ON cn.id_cot_cliente = c.id
	*/

	--5.Cargar información del vehiculo
	SELECT	DISTINCT 
			[id] = cil2.id, 
			id_ot = cc.id
			,[vin] = ISNULL (cil3.vin, '')
			--,[propietario] = ISNULL (cclp.razon_social, '')
			,id_modelo = ISNULL (ci3.codigo, ci2.codigo) 
			,anio_modelo = ISNULL (ci3.id_veh_ano, ci2.id_veh_ano)
			,descripcion_modelo = ISNULL (ci3.descripcion, ci2.descripcion)
			,Tipo = case when isnull(f.id_tal_flota, 0) != 0 then 'FLOTA' else 'RETAIL' end
	INTO #Vehiculos
	FROM #Docs td
		LEFT JOIN dbo.cot_item_lote cil2 ON cil2.id = td.id_cot_item_vhtal
		LEFT JOIN dbo.cot_item ci2 ON ci2.id = cil2.id_cot_item
		LEFT JOIN dbo.cot_cotizacion cc ON cc.id = td.id_cot_cotizacion_sig
		LEFT JOIN dbo.cot_item_lote cil3 ON cil3.id = cc.id_cot_item_lote
		LEFT JOIN dbo.cot_item ci3 ON ci3.id = cil3.id_cot_item
		LEFT JOIN dbo.tal_flota_veh f on cil2.id=f.id_cot_item_lote


	--SELECT FINAL
	SELECT	 BARCODE = ISNULL(cvbo.campo_1, '')
			,NOMBRE_ASESOR = ISNULL(uv.nombre, '')
			,NUMERO_DE_ORDEN = ISNULL (cc.id, 0)
			,RAZON_SOCIAL = clot.razon_social
			,NOMBRES_OT = ISNULL(cn.nom1 + ' ' + cn.nom2, clot.razon_social) --clot.nombres
			,APELLIDOS_OT = ISNULL(cn.ape1 + ' ' + cn.ape2, '') --clot.apellidos
			,CEDULA_RUC_OT = clot.nit
			,TELEFONO_1 = CASE 
							WHEN LEN (cont.tel_1) >= 6 and LEN (cont.tel_1) <= 10 THEN cont.tel_1
							ELSE ''
						END
						--clot.Telefono_1
			,TELEFONO_2 = CASE 
							WHEN LEN (clot.tel_1) >= 6 and LEN (clot.tel_1) <= 10 THEN clot.tel_1
							ELSE ''
						END
						--clot.Telefono_2
			,PAIS = ISNULL(p.descripcion, '')--clot.pais
			,MAIL = cont.email--clot.mail
			,VIN = vehi.vin
			,ANIO_MODELO
			,FECHA_ENTRADA_VH = ISNULL (cc.fecha, '')
			--,FECHA_SALIDA_VH = ISNULL(te.fecha_modif,te.fecha)
			,FECHA_SALIDA_VH = ISNULL(te.fecha_modif,cc.fecha)
			,CEDULA_ASESOR = uv.cedula_nit 
			,CODIGO_MODELO = vehi.id_modelo
			,ID_FAC = td.id
			,TIPO_TRANSACCION=
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
		,Trabajos_Realizados=dbo.Trabajos_realizados(cc.id)
		,TIPO_SERVICIO = case when td.facturar_a = 'G' then '02' else '01' end
		,vehi.descripcion_modelo
		,vehi.TIPO
		,AGENCIA = bo.DESCRIPCION
	INTO #Resultado
	FROM #Docs td
	join cot_bodega b on b.id = td.id_cot_bodega
	JOIN @LINEA line ON line.id_item = td.id_cot_item 
	JOIN dbo.cot_tipo ct ON ct.id = td.id_cot_tipo
	JOIN @Bodega tb ON tb.id = td.id_cot_bodega
	LEFT JOIN dbo.v_campos_varios cvbo    ON	tb.id = cvbo.id_cot_bodega
	LEFT JOIN dbo.usuario uv ON uv.id = td.id_usuario_ven
	LEFT JOIN dbo.cot_cotizacion cc ON cc.id = td.id_cot_cotizacion_sig
	LEFT JOIN dbo.cot_bodega bo on bo.id=cc.id_cot_bodega
	--LEFT JOIN #Clientes clot ON clot.id = cc.id_cot_cliente
	LEFT JOIN dbo.cot_cliente clot on clot.id = cc.id_cot_cliente
		 JOIN dbo.cot_cliente_pais pc ON pc.id = clot.id_cot_cliente_pais
		 JOIN dbo.cot_cliente_pais pd ON pd.id = pc.id_cot_cliente_pais
	     JOIN dbo.cot_cliente_pais p ON p.id = pd.id_cot_cliente_pais
	     JOIN dbo.cot_cliente_contacto cont ON cont.id = clot.id_cot_cliente_contacto
	LEFT JOIN dbo.cot_cliente_nom cn ON cn.id_cot_cliente = clot.id

	LEFT JOIN dbo.tra_cargue_enc te on te.id_cot_cotizacion = cc.id AND te.anulado IS NULL
	LEFT JOIN #Vehiculos vehi ON vehi.id = td.id_cot_item_vhtal AND vehi.id_ot = cc.id
	WHERE line.linea <> 'VEHICULOS'



	SELECT	distinct
			PAIS
			,FECHAORDEN=FECHA_SALIDA_VH
			,VIN
			,CODIGO_MODELO
			,ANIO_MODELO
			,NUMERO_DE_ORDEN
			,NOMBREYAPELLIDO = NOMBRES_OT +' '+ APELLIDOS_OT
			,MAIL
			,TELEFONO_1
			,TELEFONO_2 
			,CEDULA_ASESOR
			,NOMBRE_ASESOR
			,TIPO_SERVICIO
			,BARCODE
			,TIPO_TRANSACCION
			,DESCRIPCION_MODELO
			,TIPO
			,AGENCIA
	FROM #Resultado r
	where vin not in (select l.vin from cot_item_lote l where l.id_cot_cliente_contacto in (select id from cot_cliente_contacto c where c.id_cot_cliente= 376941))
	GROUP BY PAIS
			,FECHA_SALIDA_VH
			,VIN
			,CODIGO_MODELO
			,ANIO_MODELO
			,NUMERO_DE_ORDEN
			,NOMBRES_OT +' '+ APELLIDOS_OT
			,MAIL
			,Telefono_1
			,Telefono_2 
			,CEDULA_ASESOR
			,NOMBRE_ASESOR
			,TIPO_SERVICIO
			,BARCODE
			,TIPO_TRANSACCION
			,DESCRIPCION_MODELO
			,TIPO
			,AGENCIA
