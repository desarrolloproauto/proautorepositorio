USE [dms_smd3]
GO
/****** Object:  StoredProcedure [dbo].[BI_T_GetProductoProcesoDetalladoTaller]    Script Date: 22/3/2022 14:26:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ===============================================================================================================================
-- Author:		<Javier Chogllo / INNOVA>
-- Create date: <2021-02-12>
-- Description:	<Procedimiento para obtener informacion del Producto en Proceso en Talleres, se utiliza para 
--				 alimentar la tabla FactProductoEnProceso en la base de datos Datawarehouse de Proauto.
--               Se almacena informacion historica del ultimo dia de cada mes>

-- Historial de Cambios:
-- (2022-03-23)  Se corrige las bodegas que salian en NULL para algunas OTs (JCB)
-- ===============================================================================================================================

-- EXEC [dbo].[BI_T_GetProductoProcesoDetalladoTaller]
ALTER PROCEDURE [dbo].[BI_T_GetProductoProcesoDetalladoTaller]
AS
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	DECLARE @emp int = 605
	DECLARE @Bod VARCHAR(MAX) = 0
	DECLARE @cli INT=0				
	DECLARE @sw int=46
  
	----------------SE CREA LA TABLA @BODEGA para poder enviar como parametro una bodega
	DECLARE @Bodega AS TABLE
	(
		id INT,
		descripcion VARCHAR(200),
		ecu_establecimiento VARCHAR(6)
	)

	-----AGENDAMIENTO DE CITAS
	select DISTINCT id
	INTO #citas2
	from tal_citas

	------------------------------FIN CITAS---------------------------------------------
	-------------------------------SACAMOS LAS ORDENES QUE TIENEN FACTURAS----------------------------
	select DISTINCT
		IdOrden=ot.id,
		id_factura=ifac.id_cot_cotizacion
	into #Facturas
	from dbo.cot_cotizacion ot 
	left join dbo.cot_tipo tpo on tpo.id=ot.id_cot_tipo 
	left join dbo.cot_cotizacion ct on ct.id=ot.id
	left join dbo.cot_cotizacion cc on cc.id = ct.id_cot_cotizacion_sig
	join dbo.cot_tipo tt on tt.id = ct.id_cot_tipo and isnull(tt.sw,0) <> -1
	join dbo.cot_cotizacion_item i on i.id_cot_cotizacion = ct.id
	left join dbo.v_tal_orden_item_facturados ifac on ifac.id_componenteprincipalest = i.id 
	left join cot_cotizacion fac on fac.id=ifac.id_cot_cotizacion
	where tpo.sw=46 and ct.id_emp=@emp
	and 
		(
			ct.id = ot.id
			or ct.id_cot_cotizacion_sig = ot.id
			or i.id_prd_orden_estruc = ot.id --para garantías
			or i.id_prd_orden_estructurapt = ot.id --para consolidados
		) and ifac.id_cot_cotizacion is not null 



	-----------------------------
	select DISTINCT
   		id_factura
		into #IDFacturas
	FROM #Facturas

	--Sacamos los items que han sido facturados
	select 
	distinct 
	cifac.id_componenteprincipalEst
	into #itemfact
	from cot_cotizacion_item ci
	JOIN cot_item i on i.id=ci.id_cot_item
	left join cot_cotizacion_item cifac on cifac.id_componenteprincipalEst=ci.id
	where cifac.id_cot_cotizacion IN (SELECT id_factura FROM #IDFacturas)

	--sacamos el ID de todas las ordenes con su repectivo estado
	Select 
		ot.id as Id_OrdTaller,
		Estado = CASE ISNULL(ot.anulada, 0) 
					WHEN 0 THEN CASE WHEN ISNULL(ot.debe,0)=7 THEN 'Bloq' ELSE '' END  --CSP 744 CASE ISNULL(ot.anulada, 0)WHEN 0 THEN NULL obligatorio dejarlo en NULL
					WHEN 1 THEN CASE WHEN tp.sw = 46 THEN 'Fact' ELSE 'Conv' END
					WHEN 2 THEN 'Cerr'
					WHEN 3 THEN 'Parc'
					WHEN 4 THEN CASE WHEN LEFT(CAST(ot.notas AS VARCHAR(6)),6)='*cons*' THEN 'Cons' ELSE 'Anu' END 
					ELSE 'Otr' 
					END,
		ot.id_cot_cliente, ot.id_usuario_vende, ot.id_cot_item_lote, ot.fecha
	INTO #EncTaller
	from dbo.cot_cotizacion ot
	left join cot_tipo tp on tp.id=ot.id_cot_tipo 
	where ot.id_emp=@emp and tp.sw=@sw 

	--De la tabla temporal #EncTaller sacamos solo las ordenes que no han sido facturdas con sus respectivos estados
	SELECT * 
	into #Ordenes 
	FROM #EncTaller c
	WHERE c.Estado<>'Fact' AND c.Estado<>'Anu' AND c.Estado<>'Cons' order by 1

	------------TEMPORALES---------------------------------------------------

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


	--1 Llenamos la tabla @BODEGA
	IF @Bod = '0'
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
	ELSE
		INSERT @Bodega
		(
			id,
			descripcion,
			ecu_establecimiento
		)
		SELECT CAST(f.val AS INT),
			   c.descripcion,
			   c.ecu_establecimiento
		FROM dbo.fnSplit(@Bod, ',') f
			JOIN dbo.cot_bodega c
				ON c.id = CAST(f.val AS INT)

	--2 Solo clientes con una orden abierta
	SELECT distinct id,razon_social,tel_1,tel_2,nit,id_cot_cliente_perfil 
	INTO #cot_cliente
	FROM cot_cliente c
	JOIN #ordenes o ON o.id_cot_cliente=c.id
	where id_emp=@emp 

	--3 Usuarios
	select distinct id,u.codigo_usuario,nombre,cedula_nit 
	INTO #usuario
	from usuario u
	JOIN #ordenes o ON o.id_usuario_vende=u.id

	--4 FLOTAS TALLER
	select DISTINCT 
	d.Id_OrdTaller,
	d.id_cot_item_lote,
	tf.descripcion,
	tf.fechaini,
	tf.fechafin,
	id_tal_flota=tf.id,
	ClaseCliente=tc.descripcion,
	EstaEnFlota=case when d.fecha between tf.fechaini and tf.fechafin then 'S' else 'N' end
	into #flotasTaller					   
	from  #ordenes d
	join tal_flota_veh fv on fv.id_cot_item_lote=d.id_cot_item_lote and fv.inactivo<>1
	join tal_flota tf on tf.id=fv.id_tal_flota
	join tal_flota_clase tc on tc.id=tf.id_tal_flota_clase

	----------SACAMOS LAS CABECERAS DE TODAS LAS OT---------------------
	select 
	sw=@sw,id_orden= case when tt.sw =@sw
						then   ct.id
						else
							ct.id_cot_cotizacion_sig
						end,
						fecha=CASE WHEN tt.sw =@sw
										THEN 
											ct.fecha
										ELSE
											cc1.fecha
										END,
						promesa_entrega=CASE WHEN tt.sw =@sw
										THEN 
											ct.fecha_estimada
										ELSE
											cc1.fecha_estimada
										END,
						id_cot_cliente=CASE WHEN tt.sw =@sw
										THEN 
											ct.id_cot_cliente
										ELSE
											cc1.id_cot_cliente
										END,
						id_cot_bodega=CASE WHEN tt.sw =@sw
										THEN 
											ct.id_cot_bodega
										ELSE
											cc1.id_cot_bodega
										END,
						id_usuario_vende=CASE WHEN tt.sw =@sw
										THEN 
											ct.id_usuario_vende
										ELSE
											cc1.id_usuario_vende
										END,
						ct_id=ct.id,
						id_cot_item_vhtal=CASE WHEN tt.sw =@sw
										THEN 
											ct.id_cot_item_lote
										ELSE
											cc1.id_cot_item_lote
										END,
						km=CASE WHEN tt.sw =@sw
										THEN 
											ct.km
										ELSE
											cc1.km
										END,
						id_cot_bodega_ubicacion =CASE WHEN tt.sw =@sw
										THEN 
											ct.id_cot_bodega_ubicacion
										ELSE
											cc1.id_cot_bodega_ubicacion
										END,
						id_cot_cliente2 =CASE WHEN tt.sw =@sw
										THEN 
											ct.id_cot_cliente2
										ELSE
											cc1.id_cot_cliente2
										END,
						fecha_cartera =CASE WHEN tt.sw =@sw
										THEN 
											ct.fecha_cartera
										ELSE
											cc1.fecha_cartera
										END,
						notas =CASE WHEN tt.sw =@sw
										THEN 
											(ct.notas)
										ELSE
											(cc1.notas)
										END,
						notas2 =CASE WHEN tt.sw =@sw
										THEN 
											ct.notas_internas
										ELSE
											cc1.notas_internas
										END
		into #cabecera
		from cot_cotizacion ct
		LEFT JOIN cot_cotizacion cc1 ON cc1.id=ct.id_cot_cotizacion_sig
		Left Join cot_tipo tt On tt.id = ct.id_cot_tipo
		Where	(
				 ct.id in (select Id_OrdTaller from #Ordenes)
				)
			
				And (
					 @sw Not In (2,-1,47)
				
					) 

	------INSERTAMOS EN UNA TABLA #CABEZERADETALLE LOS DETALLES DE LA CABECERA 
	select cb.sw,
	       cb.id_orden,
		   Nit_Cliente=cc.nit,
	       Nombres_Cliente=cc.razon_social, 
		   Bodega=b.descripcion,
		   id_cot_bodega=b.id,
		   Nit_vendedor=u.cedula_nit,
	       Vendedor=u.nombre,
		   Marca=CASE WHEN m.descripcion like '%MULTIMARCA%'
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
				END, --DE LA ORDEN ORIGINAL
			[Modelo_Año]=  CASE WHEN m.descripcion like '%MULTIMARCA%'
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
				END,
			[Año]=CASE WHEN m.descripcion like '%MULTIMARCA%'
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
			END,
		[VIN Taller]=ih.vin,
		[Motor]=isnull(ih.motor,''),  --DE LA ORDEN ORIGINAL
		[Color Vh]=isnull(col.descripcion,''),
		cb.fecha,
		[Placa]=ISNULL(ih.placa,''), 
		Nit_propietario=isnull(cli3.nit,''), --DE LA ORDEN ORIGINAL
		Propietario=isnull(cli3.razon_social,''),
		LineaVH=ISNULL(ct.descripcion,''),--DE LA ORDEN ORIGINAL
		Clase_cliente=isnull(cp.descripcion,''), Clase_cliente_flota=isnull(flo.ClaseCliente,''),
		Pertenece_flota= isnull(flo.EstaEnFlota,'N'), Fec_Apertura_OT=cb.fecha,
		Promesa_Entrega=cb.promesa_entrega, DIAS=ISNULL((DATEDIFF (DAY,cb.fecha , getdate())),0),   
		cb.ct_id,
		cb.km, 
		Tipo_orden=ISNULL(cv.campo_1,''),
		Trabajos_realizados=dbo.Trabajos_realizados (cb.id_orden),
	    estado_ot=ubi.descripcion, Nit_Aseguradora=isnull(cli2.nit,''),
		Aseguradora = isnull(cli2.razon_social,''),
		fec_Aut_Aseguradora=cb.fecha_cartera,
		fec_env_aut_aseguradora=cmas.fecha_envio_ase,
		tiene_cita=CASE WHEN  ct2.id IS null OR ct2.id=''  then 'NO' ELSE 'SI' END,
		notas=cb.notas,
		Factura=isnull((select max(id_factura) from #Facturas where IdOrden=cb.id_orden ),0),
		notas2=cb.notas2
	into #CABEZERADETALLE 
	from #cabecera cb
	JOIN @Bodega b ON b.id=cb.id_cot_bodega
	JOIN #cot_cliente cc ON cc.id = cb.id_cot_cliente
	LEFT JOIN dbo.cot_cliente_perfil cp ON cp.id = cc.id_cot_cliente_perfil
	JOIN #usuario u ON u.id=cb.id_usuario_vende
	LEFT join cot_item_lote ih on ih.id=cb.id_cot_item_vhtal
	LEFT join cot_item ic on ic.id=ih.id_cot_item
	left Join veh_linea_modelo l on l.id=ic.id_veh_linea_modelo
	left Join veh_linea v on v.id=ic.id_veh_linea
	left Join veh_marca m on m.id=v.id_veh_marca
	LEFT JOIN cot_item_talla ct on ct.id=ic.id_cot_item_talla
	left join v_campos_varios cv6 on cv6.id_cot_item_lote=ih.id
	left Join veh_color col on ih.id_veh_color=col.id
	LEFT JOIN cot_cliente_contacto cli on cli.id=ih.id_cot_cliente_contacto
	LEFT JOIN #cot_cliente cli2 ON cli2.id = cb.id_cot_cliente2
	LEFT JOIN #cot_cliente cli3 ON cli3.id = cli.id_cot_cliente 
	LEFT JOIN #flotasTaller	 flo ON flo.Id_OrdTaller = cb.id_orden and flo.id_cot_item_lote=cb.id_cot_item_vhtal
	LEFT JOIN v_campos_varios cv On cv.id_cot_cotizacion=cb.id_orden and cv.campo_1 is not null
	LEFT JOIN cot_bodega_ubicacion ubi ON ubi.id=cb.id_cot_bodega_ubicacion
	LEFT JOIN dbo.cot_cotizacion_mas cmas ON cmas.id_cot_cotizacion=cb.id_orden
	LEFT JOIN #citas2 ct2 ON ct2.id=cb.id_orden
	where  (@cli=0 or cb.id_cot_cliente=@cli)
	AND cb.id_orden in (select Id_OrdTaller from #Ordenes)
	AND (SELECT COUNT (*)
			FROM cot_cotizacion_item c
			JOIN cot_cotizacion ct ON ct.id = c.id_cot_cotizacion 
			Where ct.id = cb.id_orden OR ct.id_cot_cotizacion_sig = cb.id_orden 
			AND c.facturar_a IS NOT NULL AND id_operario IS NOT NULL) = 0

	-------------------------------------------------------------------------
	--SACAMOS LA TABLA TEMPORAL #DOCS CON LOS DETALLES SOLO DE LAS ORDENTES QUE TIENEN CARGADADAS OPERACIONES
	select 
	sw=@sw,
	id_orden= case when tjd.sw =@sw
						then   ct.id
						else
							ct.id_cot_cotizacion_sig
						end,
						fecha=CASE WHEN tjd.sw =@sw
										THEN 
									
										ct.fecha
										ELSE
											cc1.fecha
										END,
						promesa_entrega=CASE WHEN tjd.sw =@sw
										THEN 
											ct.fecha_estimada
										ELSE
											cc1.fecha_estimada
										END,
						id_cot_cliente=CASE WHEN tjd.sw =@sw
										THEN 
											ct.id_cot_cliente
										ELSE
											cc1.id_cot_cliente
										END,
						id_cot_bodega=CASE WHEN tjd.sw =@sw
										THEN 
											ct.id_cot_bodega
										ELSE
											cc1.id_cot_bodega
										END,
						id_usuario_vende=CASE WHEN tjd.sw =@sw
										THEN 
											ct.id_usuario_vende
										ELSE
											cc1.id_usuario_vende
										END,
						i.id_cot_grupo_sub,
						ct.id,
						id_cot_item_vhtal=CASE WHEN tjd.sw =@sw
										THEN 
											ct.id_cot_item_lote
										ELSE
											cc1.id_cot_item_lote
										END,
						km=CASE WHEN tjd.sw =@sw
										THEN 
											ct.km
										ELSE
											cc1.km
										END,
						i.codigo,
						i.descripcion,
						id_item=i.id,
						id_cot_cotizacion_item=c.id,
						notas_item=i.notas,
						i.id_cot_grupo_sub5,
						i.id_cot_item_color,
						cantidad_und = case When dtotc.descripcion Is Not Null Then dtotc.cantidad_und	--TOT con especificaciones detalladas
								else
									c.cantidad_und - IsNull(dev.cantidad_devuelta,0)
								end,
						c.tiempo,
						c.valor_hora,
						c.costo_und,
						c.id_cot_item,
						precio_lista = case when cci2.tipo_operacion = 'O' then c.can_tot_dis
								else
									c.precio_lista
								end,
						precio_cotizado = case when cci2.tipo_operacion = 'O' then c.can_tot_dis
								else
									c.precio_cotizado
								end,
						porcentaje_descuento=case when cci2.tipo_operacion = 'O' then 0
									else c.porcentaje_descuento
								end,
					
						c.porcentaje_iva,
						c.renglon,
						cci2.tipo_operacion,
						can_tot_dis=isnull(c.can_tot_dis,0),
						total_total= CASE WHEN tjd.sw =@sw
										THEN 
											ct.total_total
										ELSE
											cc1.total_total
										END,
						c.id_operario,
						id_cot_bodega_ubicacion =CASE WHEN tjd.sw =@sw
										THEN 
											ct.id_cot_bodega_ubicacion
										ELSE
											cc1.id_cot_bodega_ubicacion
										END,
						id_cot_cliente2 =CASE WHEN tjd.sw =@sw
										THEN 
											ct.id_cot_cliente2
										ELSE
											cc1.id_cot_cliente2
										END,
						fecha_cartera=CASE WHEN tjd.sw =@sw
										THEN 
											ct.fecha_cartera
										ELSE
											cc1.fecha_cartera
										END,
						notas =CASE WHEN tt.sw =@sw
										THEN 
											ct.notas
										ELSE
											cc1.notas
										END,
						clase_trabajo =c.facturar_a,
						notas2 =CASE WHEN tt.sw =@sw
										THEN 
											ct.notas_internas
										ELSE
											cc1.notas_internas
										END
		into #docs
		from cot_cotizacion ct
		Join	cot_cotizacion_item c On c.id_cot_cotizacion = ct.id
		Join	cot_item i On i.id = c.id_cot_item
		LEFT JOIN cot_cotizacion cc1 ON cc1.id=ct.id_cot_cotizacion_sig
		Left Join cot_tipo tt On tt.id = c.id_cot_tipo_tran
		Left Join v_cot_cotizacion_item_dev2 dev On dev.id_cot_cotizacion_item = c.id
		--para el vehículo de la garantía
		LEFT JOIN cot_cotizacion c3 On c3.id = c.id_cot_cotizacion
		LEFT JOIN dbo.v_cot_cotizacion_item cci2 ON cci2.id = c.id
		LEFT JOIN cot_tipo tjd ON tjd.id=c3.id_cot_tipo
		Left Join v_detalle_tot dtotc on ct.id = dtotc.id_cot_cotizacion and c.Renglon = dtotc.Renglon
		Where	(
				 ct.id in (select Id_OrdTaller from #Ordenes)
				 Or ct.id_cot_cotizacion_sig  in (select Id_OrdTaller from #Ordenes)
				 Or c.id_prd_orden_estruc  in (select Id_OrdTaller from #Ordenes)
				 Or c.id_prd_orden_estructuraPT  IN (select Id_OrdTaller from #Ordenes)
				)
				AND ISNULL(tjd.sw,0)<>1 --jdms
				And (c.id_cot_cotizacion_item Is Null) --para no traer los items que son parte de la estructura
				And (@sw Not In (2,-1,46,47) Or tt.sw = 12 --para que coja la entrada del traslado que es donde están los datos
					 Or tt.sw Is Null) -- si es remisión mostrar la salida, el null es para taller
				And (c.cantidad - IsNull(dev.cantidad_devuelta,0)) > 0
				and c.facturar_a is not null
				And (c.tipo_operacion Is Not NULL OR @sw = 47) --esto para que no coja los dos renglones del traslado --JFG-740 sw 47 cotizaciòn para que traiga las corizaciones de repuestos 
				AND ISNULL(tjd.sw, 0) <> - 1 --MAR 735: No traer ítems devufeltos	
				AND c.id NOT IN (SELECT id_componenteprincipalEst FROM #itemfact)
	--------------
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
						   
   
	----------------------------------
	select d.sw,
	LineaNegocio=lin.linea,
	d.id_orden,Nit_Cliente=cc.nit,
	Nombres_Cliente=cc.razon_social,
	/**/
	id_cot_bodega = b.id,
	/**/
	Bodega=b.descripcion,
	Nit_vendedor=u.cedula_nit, --DE LA ORDEN ORIGINAL
	Vendedor=u.nombre,
	Marca=CASE WHEN m.descripcion like '%MULTIMARCA%'
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
		END, --DE LA ORDEN ORIGINAL
	[Modelo_Año]=  CASE WHEN m.descripcion like '%MULTIMARCA%'
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
		END,
	[Año]=CASE WHEN m.descripcion like '%MULTIMARCA%'
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
		END,--DE LA ORDEN ORIGINAL
		[VIN_Taller]=ih.vin,
		[Motor]=isnull(ih.motor,''),  --DE LA ORDEN ORIGINAL
		[Color_Vh]=isnull(col.descripcion,''), --DE LA ORDEN ORIGINAL
		d.km,
		[Placa]=ISNULL(ih.placa,''),
		Nit_propietario=isnull(cli3.nit,''), --DE LA ORDEN ORIGINAL
		Propietario=isnull(cli3.razon_social,''),
		LineaVH=ISNULL(ct.descripcion,''),--DE LA ORDEN ORIGINAL
		Clase_cliente=isnull(cp.descripcion,''),
		Clase_cliente_flota=isnull(flo.ClaseCliente,''),
		Pertenece_flota= isnull(flo.EstaEnFlota,'N'),
		Fec_Apertura_OT=d.fecha,
		Promesa_Entrega=d.promesa_entrega,
		DIAS=ISNULL((DATEDIFF (DAY,d.fecha , getdate())),0),
		Tipo_orden=ISNULL(cv.campo_1,''),
		[CODIGO_DE_MO]= d.codigo,
		[DESCRIPCION_MO]=CASE WHEN flo.EstaEnFlota ='S'  
								THEN
									CASE WHEN tfpr.desc_cod_flota is NULL
										THEN 
											CASE WHEN d.codigo  like '%TOT%'
												THEN
													CASE WHEN  d.notas_item is null 
														THEN
														d.descripcion
														ELSE
														d.notas_item
													END
												ELSE 
												d.descripcion
											END
									END
								ELSE 
									CASE WHEN d.codigo  like '%TOT%'
												THEN
													CASE WHEN   d.notas_item is null 
														THEN
														d.descripcion
														ELSE
														d.notas_item
													END
												ELSE 
												d.descripcion
											END
			END,
			Grupo=g.descripcion,
			[Subgrupo]=s.descripcion,
			[SubGrupo3]=ISNULL(s3.descripcion,''),
			[SubGrupo4]=ISNULL(s4.descripcion,''),
			[ORIGINAL ALTERNO]=ISNULL(va.campo_5,''),
			generico=ISNULL(gen.descripcion,''),
			grupo_cor=ISNULL(s3.descripcion,''),
			FUENTE_COR=ISNULL(va.campo_4,''),
			cantidad=d.cantidad_und,
			tiempo=isnull((case when d.tiempo<0 then 0 else d.tiempo end),0),
			valor_hora=isnull(d.valor_hora,0),
			costo=isnull((d.cantidad_und * d.costo_und),0),
			d.precio_lista,
			Precio_venta=d.precio_lista,
			precio_bruto= d.cantidad_und * d.precio_lista,
			porcentaje_descuento=isnull(d.porcentaje_descuento,0),
			descuento=ROUND(isnull((( d.cantidad_und * d.precio_lista) * d.porcentaje_descuento / 100),0),2),
			precio_neto=(d.cantidad_und * d.precio_lista) - ROUND(isnull((( d.cantidad_und * d.precio_lista) * d.porcentaje_descuento / 100),0),2),
			margen=CASE WHEN isnull((d.cantidad_und * d.costo_und),0)=0
					THEN	
						0
					ELSE
					 (1-((d.cantidad_und * d.costo_und)/(abs(d.precio_cotizado) *abs(case when d.cantidad_und=0 then 1 else d.cantidad_und end ))))*100
					END,
			porcentaje_iva=d.porcentaje_iva,
				iva=CASE
				WHEN d.porcentaje_iva <> 0
				THEN (d.cantidad_und * d.precio_lista) - ROUND(isnull((( d.cantidad_und * d.precio_lista) * d.porcentaje_descuento / 100),0),2) ELSE 0
				END * d.porcentaje_iva / 100,
			[total]=((d.cantidad_und * d.precio_lista) - ROUND(isnull((( d.cantidad_und * d.precio_lista) * d.porcentaje_descuento / 100),0),2))+(CASE
				WHEN d.porcentaje_iva <> 0
				THEN (d.cantidad_und * d.precio_lista) - ROUND(isnull((( d.cantidad_und * d.precio_lista) * d.porcentaje_descuento / 100),0),2) ELSE 0
				END * d.porcentaje_iva / 100), 
			[TOTAL_ORDEN]=D.total_total,
			Nit_Operario=ISNULL(up.cedula_nit,''), --DE LA ORDEN ORIGINAL
			operario=up.nombre, --DE LA ORDEN ORIGINAL
			Trabajos_realizados=dbo.Trabajos_realizados (d.id_orden),
			estado_ot=ubi.descripcion,
			Nit_Aseguradora=isnull(cli2.nit,''),
			Aseguradora = isnull(cli2.razon_social,''),
			fec_Aut_Aseguradora=d.fecha_cartera,
			fec_env_aut_aseguradora=cmas.fecha_envio_ase,
			tiene_cita=CASE WHEN  ct2.id IS null OR ct2.id=''  then 'NO' ELSE 'SI' END,
			d.notas,
			d.notas2,
			d.clase_trabajo,
			d.tipo_operacion,
			Factura=isnull((select max(id_factura) from #Facturas where IdOrden=d.id_orden),0)
	into #detalle
	from #docs d
	JOIN #Linea lin ON lin.id_item = d.id_cot_item											  
	JOIN @Bodega b ON b.id=d.id_cot_bodega
	JOIN #cot_cliente cc ON cc.id = d.id_cot_cliente
	LEFT JOIN dbo.cot_cliente_perfil cp ON cp.id = cc.id_cot_cliente_perfil
	JOIN dbo.cot_grupo_sub s ON s.id = d.id_cot_grupo_sub
	JOIN dbo.cot_grupo g ON g.id = s.id_cot_grupo
	LEFT JOIN dbo.cot_grupo_sub5 s5 ON s5.id = d.id_cot_grupo_sub5
	LEFT JOIN dbo.cot_grupo_sub4 s4 ON s4.id = s5.id_cot_grupo_sub4
	LEFT JOIN dbo.cot_grupo_sub3 s3 ON s3.id = s4.id_cot_grupo_sub3
	JOIN #usuario u ON u.id=d.id_usuario_vende
	LEFT join cot_item_lote ih on ih.id=d.id_cot_item_vhtal
	JOIN dbo.cot_item i ON i.id = d.id_cot_item --AND i.maneja_stock IN (0)
	LEFT join cot_item ic on ic.id=ih.id_cot_item
	left Join veh_linea_modelo l on l.id=ic.id_veh_linea_modelo
	left Join veh_linea v on v.id=ic.id_veh_linea
	left Join veh_marca m on m.id=v.id_veh_marca
	LEFT JOIN cot_item_talla ct on ct.id=ic.id_cot_item_talla
	left join v_campos_varios cv6 on cv6.id_cot_item_lote=ih.id
	left Join veh_color col on ih.id_veh_color=col.id
	LEFT JOIN cot_item_color gen ON gen.id=d.id_cot_item_color
	LEFT JOIN v_campos_varios cv On cv.id_cot_cotizacion=d.id_orden and cv.campo_1 is not null
	LEFT JOIN cot_cliente_contacto cli on cli.id=ih.id_cot_cliente_contacto
	LEFT JOIN #cot_cliente cli2 ON cli2.id = d.id_cot_cliente2
	LEFT JOIN #cot_cliente cli3 ON cli3.id = cli.id_cot_cliente 
	LEFT JOIN #flotasTaller	 flo ON flo.Id_OrdTaller = d.id_orden and flo.id_cot_item_lote=d.id_cot_item_vhtal
	LEFT JOIN tal_flota_precios tfpr on tfpr.id_tal_flota= flo.id_tal_flota AND tfpr.id_cot_item_ope =d.id_item
	LEFT JOIN dbo.v_campos_varios va ON va.id_cot_item=d.id_item
	LEFT JOIN dbo.usuario up ON up.id = d.id_operario
	LEFT JOIN #RtosPLista pl ON pl.id=d.id and pl.id_cot_cotizacion_item=d.id_cot_cotizacion_item and pl.id_cot_item=d.id_cot_item
	LEFT JOIN cot_bodega_ubicacion ubi ON ubi.id=d.id_cot_bodega_ubicacion
	LEFT JOIN dbo.cot_cotizacion_mas cmas ON cmas.id_cot_cotizacion=d.id_orden
	LEFT JOIN #citas2 ct2 ON ct2.id=d.id_orden
	where  (@cli=0 or d.id_cot_cliente=@cli)



	
	
	--------------------UNIMOS LAS DOS TABLAS CON FULL OUTER JOIN YA QUE NO ME ESTABA SACANDO LAS CABECERAS DE LAS ORDENES QUE NO TENIAN CARGADAS OPERACIONES
	select sw=isnull(dt.sw,cb.sw),
	       linea_negocio=isnull(dt.LineaNegocio,''),
	       id_orden=isnull(dt.id_orden,cb.id_orden), 
		   Nit_Cliente=isnull(dt.Nit_Cliente,cb.Nit_Cliente),
	       Nombres_Cliente=isnull(dt.Nombres_Cliente,cb.Nombres_Cliente),
	      /**/
	      id_cot_bodega = ISNULL(dt.id_cot_bodega,cb.id_cot_bodega),
	      /**/
	      Bodega=isnull(dt.Bodega,cb.Bodega),
	      Nit_vendedor=isnull(dt.Nit_vendedor,cb.Nit_vendedor),
		  Vendedor=isnull(dt.Vendedor,cb.Vendedor),
	      Marca = isnull(dt.Marca,cb.Marca),
		  Modelo_Año= isnull(dt.Modelo_Año,cb.Modelo_Año), 
	      Año = isnull(dt.Año,cb.Año),
		  VIN_Taller= isnull(dt.VIN_Taller,cb.[VIN Taller]), 
		  Motor =isnull(dt.Motor,cb.Motor),
	      Color_Vh =isnull(dt.Color_Vh,cb.[Color Vh]),
		  km=isnull(dt.km,cb.km),
		  Placa=isnull(dt.Placa,cb.Placa),
		  Nit_propietario=isnull(dt.Nit_propietario,cb.Nit_propietario),
	      Propietario=isnull(dt.Propietario,cb.Propietario), 
		  LineaVH =isnull(dt.LineaVH,cb.LineaVH),
		  Clase_cliente=isnull(dt.Clase_cliente,cb.Clase_cliente),
	      Clase_cliente_flota=isnull(dt.Clase_cliente_flota,cb.Clase_cliente_flota), 
		  Pertenece_flota=isnull(dt.Pertenece_flota,cb.Pertenece_flota),
	      Fec_Apertura_OT =isnull(dt.Fec_Apertura_OT,cb.Fec_Apertura_OT), 
		  Promesa_Entrega=isnull(dt.Promesa_Entrega,cb.Promesa_Entrega), 
		  DIAS=isnull(dt.DIAS,cb.DIAS),
	      Tipo_orden =isnull(dt.Tipo_orden,cb.Tipo_orden),
		  CODIGO_DE_MO=isnull(dt.CODIGO_DE_MO,''), 
		  Descripcion_MO=isnull(dt.DESCRIPCION_MO,''),
	      Grupo=isnull(dt.Grupo,''),
		  Subgrupo =isnull(dt.Subgrupo,''), 
		  SubGrupo3 =isnull(dt.SubGrupo3,''), 
		  SubGrupo4 =isnull(dt.SubGrupo4,''),		
	      ORIGINAL_ALTERNO=isnull(dt.[ORIGINAL ALTERNO],''), 
		  generico=isnull(dt.generico,''), 
		  grupo_cor=isnull(dt.grupo_cor,''),
		  FUENTE_COR =isnull(dt.FUENTE_COR,''),	
	      cantidad=isnull(dt.cantidad,0), 
		  tiempo=isnull(dt.tiempo,0), 
		  valor_hora=isnull(dt.valor_hora,0), 
		  costo=isnull(dt.costo,0), 
		  precio_lista=isnull(dt.precio_lista,0),
	      Precio_venta=isnull(dt.Precio_venta,0), 
		  precio_bruto=isnull(dt.precio_bruto,0),	
		  porcentaje_descuento=isnull(dt.porcentaje_descuento,0),
	      descuento=isnull(dt.descuento,0),
		  precio_neto=isnull(dt.precio_neto,0), 
		  margen=isnull(dt.margen,0), 
		  porcentaje_iva=isnull(dt.porcentaje_iva,0),
		  iva=isnull(dt.iva,0),
	      total=isnull(dt.total,0),
		  TOTAL_ORDEN=isnull(DT.TOTAL_ORDEN,0),
		  Nit_Operario=isnull(dt.Nit_Operario,''),
		  operario=isnull(dt.operario,''),
	      Trabajos_realizados=isnull(dt.Trabajos_realizados,cb.Trabajos_realizados),
		  estado_ot=isnull(dt.estado_ot,cb.estado_ot),
	      Nit_Aseguradora=isnull(dt.Nit_Aseguradora,cb.Nit_Aseguradora),
		  Aseguradora=isnull(dt.Aseguradora,cb.Aseguradora),
	      fec_Aut_Aseguradora=ISNULL(dt.fec_Aut_Aseguradora,cb.fec_Aut_Aseguradora),
		  fec_env_aut_aseguradora=ISNULL(dt.fec_env_aut_aseguradora,cb.fec_env_aut_aseguradora),
	      tiene_cita=ISNULL(dt.tiene_cita,cb.tiene_cita), 
		  notas=ISNULL(dt.notas,cb.notas),
		  notas_internas=ISNULL(dt.notas2,cb.notas2),
		  clase_trabajo=ISNULL(dt.clase_trabajo,''),
	      tipo_operacion=ISNULL(dt.tipo_operacion,''),
		  Id_Factura=0
	INTO #ResultadoFinal
	from #detalle dt
	FULL OUTER join #CABEZERADETALLE cb ON cb.id_orden=dt.id_orden
	 
	SELECT *
	FROM #ResultadoFinal 
	----where Id_Orden = 436218
	
END
