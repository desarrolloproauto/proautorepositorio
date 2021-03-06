USE [dms_smd3]
GO
--===================================================================================
/*Historial*/
-- <2022-02-06 Se agrega el campo Color del Vehiculo (JCB)>
--===================================================================================
-- Exec GetTalCitasTodo 605,'1222','','20220201 00:00:00','',0,'',''

ALTER PROCEDURE [dbo].[GetTalCitasTodo](
	@emp INT,
	@bod VARCHAR(MAX) = '',
	@ope VARCHAR(MAX) = '',
	@fecha_ini DATETIME = '',
	@fecha_fin DATETIME = '',
	@por_escena TINYINT = 0,
	@ase VARCHAR(MAX) = '',
	@escena VARCHAR(MAX) = '',
	@estados VARCHAR(MAX) = '',
	@vigente TINYINT = 0
)
AS

	CREATE TABLE #citas
	(
		id INT,
		id_cot_bodega INT,
		id_usuario INT,
		fecha_cita DATETIME,
		id_tal_camp_enc INT, 
		id_escenario INT, 
		id_asesor INT, 
		id_asignacion INT,
		id_mante INT,
		id_lote INT,
		segs INT,
		id_estado INT
	)

	--Todas las citas con o sin escenario
	INSERT #citas(id,id_cot_bodega, id_usuario, fecha_cita, id_tal_camp_enc, id_escenario, id_asesor, id_asignacion, id_mante, id_lote, id_estado)
	SELECT c.id, c.id_cot_bodega, c.id_usuario, c.fecha_cita, NULL, ac.id_veh_solicitudes_escenarios, ac.id_usuario, ac.id, ma.id, c.id_cot_item_lote, er.id_estado
	FROM dbo.tal_citas c
	JOIN dbo.cot_bodega b ON b.id = c.id_cot_bodega
	LEFT JOIN dbo.v_tal_citas_estado_real er ON er.id = c.id
	LEFT JOIN dbo.veh_agenda_cli ac ON ac.id_tal_citas = c.id
	LEFT JOIN dbo.veh_sug_mantenimiento ma ON ac.id_veh_solicitudes_escenarios = ma.id_veh_solicitudes_escenarios AND ac.id_cot_item_lote = ma.id_cot_item_lote AND ac.id_evento = ma.id_evento
	WHERE b.id_emp = @emp

	IF @por_escena = 1
		INSERT #citas(id,id_cot_bodega, id_usuario, fecha_cita, id_tal_camp_enc, id_escenario, id_asesor, id_asignacion, id_mante, id_lote)
		SELECT NULL, NULL, NULL, NULL, NULL, es.id, ac.id_usuario, ac.id, ma.id, ma.id_cot_item_lote
		FROM dbo.veh_solicitudes_escenarios es 
		JOIN dbo.veh_sug_mantenimiento ma ON ma.id_veh_solicitudes_escenarios = es.id
		LEFT JOIN dbo.veh_agenda_cli ac ON ac.id_veh_solicitudes_escenarios = ma.id_veh_solicitudes_escenarios AND ac.id_cot_item_lote = ma.id_cot_item_lote AND ac.id_evento = ma.id_evento
		WHERE es.id_emp = @emp AND ac.id_tal_citas IS NULL

	IF @bod<>''
		DELETE c
		FROM #citas c
		LEFT JOIN dbo.fnSplit(@bod,',') b ON b.val = c.id_cot_bodega
		WHERE b.id IS NULL

	IF @ope<>''
		DELETE c
		FROM #citas c
		LEFT JOIN dbo.fnSplit(@ope,',') b ON b.val = c.id_usuario
		WHERE b.id IS NULL

	IF @fecha_ini<>''
		DELETE c
		FROM #citas c
		WHERE CAST(ISNULL(c.fecha_cita,@fecha_ini) AS DATE)<CAST(@fecha_ini AS DATE)

	IF @fecha_fin<>''
		DELETE c
		FROM #citas c
		WHERE CAST(ISNULL(c.fecha_cita,@fecha_fin) AS DATE)>CAST(@fecha_fin AS DATE)

	IF @ase<>''
		DELETE c
		FROM #citas c
		LEFT JOIN dbo.fnSplit(@ase,',') b ON b.val = ISNULL(c.id_asesor,0)
		WHERE b.id IS NULL

	IF @escena<>''
		DELETE c
		FROM #citas c
		LEFT JOIN dbo.fnSplit(@escena,',') b ON b.val = ISNULL(c.id_escenario,0)
		WHERE b.id IS NULL OR (b.id IS NULL AND @por_escena = 0)

	IF @estados<>''
		DELETE c
		FROM #citas c
		LEFT JOIN dbo.fnSplit(@estados,',') b ON b.val = ISNULL(c.id_estado,0)
		WHERE b.id IS NULL

	IF @vigente = 1
		DELETE c
		FROM #citas c
		WHERE c.fecha_cita>GETDATE()

	;WITH cc AS (SELECT ci.id, ca.id_tal_camp_enc, fila = ROW_NUMBER() OVER(PARTITION BY ci.id ORDER BY ca.id_tal_camp_enc)
	FROM #citas ci
	JOIN dbo.tal_citas_camp ca ON ca.id_tal_citas = ci.id)
	UPDATE c
	SET c.id_tal_camp_enc = cc.id_tal_camp_enc
	FROM #citas c
	JOIN cc ON cc.id = c.id
	WHERE cc.fila = 1

	--Actualizar seguimientos
	SELECT cuantos = COUNT(s.id), s.id_veh_agenda_cli
	INTO #segs
	FROM #citas c
	JOIN dbo.veh_agenda_cli_seg s ON s.id_veh_agenda_cli = c.id_asignacion
	GROUP BY s.id_veh_agenda_cli

	UPDATE c
	SET c.segs = s.cuantos
	FROM #citas c
	JOIN #segs s ON s.id_veh_agenda_cli = c.id_asignacion

	--Más adelante crear vista con estado de la cita y reutilizar en GetlTalHorarioTodo
	SELECT c.Id,
	   Escenario = es.escenario,
	   Asesor = u2.nombre,
	   [Fecha Asigna] = ac.fecha_asigna,
	   [#Seg] = cc.segs,
       Cliente = ISNULL(cl.razon_social,c.responsable),
       Contacto = co.nombre,
       Vehículo = d.descripcion,
       Placa = ISNULL(l.Placa,c.placa),
	   [Vin] = l.vin,
	   Marca = m.descripcion,
	   Linea = li.descripcion,
	   Modelo = mo.descripcion,
	   Año = ISNULL(d.id_veh_ano,ci.id_veh_ano),
	   Color = vc.descripcion,
       Estado = ce.descripcion,
       [Descripción Cita] = c.notas,
       Operario = u.nombre,
       Bodega = b.descripcion,
       Mantenimiento = p.descripcion,
       Campaña = en.titulo,
       Tipo = ti.descripcion,
       Canal = ca.descripcion,
       OT = CASE WHEN tip.id IS NOT NULL THEN ct.id END,
       Ubicación = ub.descripcion,
	   [Fecha Entrega] = te.fecha,
       Telefono1 = co.tel_1,
       Telefono2 = cl.tel_1,
       Telefono3 = cl.tel_2,
       co.Email,
	   Transporte = CAST(ISNULL(c.transporte,0) AS BIT),
	   Recoger_Vh = CAST(ISNULL(c.recoger_vh,0) AS BIT),
	   [Fecha Crea Cita] = c.fecha_creacion,
	   [Fecha Cita] = c.fecha_cita,
       [Usuario Creo] = U3.nombre,
	   Conf_Nombre = CASE WHEN c.confirmar_cli IS NOT NULL THEN c.responsable END,
	   Conf_Tel = CASE WHEN c.confirmar_cli IS NOT NULL THEN c.telefono END,
	   Conf_Email = CASE WHEN c.confirmar_cli IS NOT NULL THEN c.email END,
	   IdVh = l.id,
	   cc.id_asignacion,
       Id_Estado = CAST(er.id_estado AS VARCHAR)
	FROM #citas cc
		LEFT JOIN dbo.tal_citas c
			ON c.id = cc.id
		LEFT JOIN dbo.cot_item ci ON ci.id = c.id_cot_item
		LEFT JOIN dbo.v_tal_citas_estado_real er ON er.id = c.id
		LEFT JOIN dbo.v_tal_citas_estado ce ON ce.id = er.id_estado
		LEFT JOIN dbo.usuario u
			ON u.id = c.id_usuario
		LEFT JOIN dbo.cot_bodega b
			ON b.id = c.id_cot_bodega
		LEFT JOIN dbo.cot_item_lote l 
			ON l.id = cc.id_lote
		LEFT JOIN dbo.cot_cliente_contacto co
			ON co.id = ISNULL(l.id_cot_cliente_contacto,c.id_cot_cliente_contacto)
		LEFT JOIN dbo.cot_cliente cl
			ON cl.id = co.id_cot_cliente
		LEFT JOIN dbo.v_cot_item_descripcion d
			ON d.id = l.id_cot_item
		LEFT JOIN dbo.veh_marca m ON m.id = ISNULL(d.id_veh_marca, ci.id_veh_marca)
		LEFT JOIN dbo.veh_linea li ON li.id = ISNULL(d.id_veh_linea,ci.id_veh_linea)
		LEFT JOIN dbo.veh_linea_modelo mo ON mo.id = ISNULL(d.id_veh_linea_modelo,ci.id_veh_linea_modelo)
		LEFT JOIN dbo.tal_citas_canal ca
			ON ca.id = c.id_tal_citas_canal
		LEFT JOIN dbo.tal_citas_tipo ti
			ON ti.id = c.id_tal_citas_tipo
		LEFT JOIN dbo.tal_planes p
			ON p.id = c.id_tal_planes
		LEFT JOIN dbo.tal_camp_enc en
			ON en.id = cc.id_tal_camp_enc
		LEFT JOIN dbo.cot_cotizacion ct
			ON ct.id = c.id_cot_cotizacion
		LEFT JOIN dbo.cot_tipo tip
			ON tip.id = ct.id_cot_tipo
			   AND tip.sw IN ( 46 )
		LEFT JOIN dbo.v_tal_operaciones_estado e
			ON e.id_cot_cotizacion = ct.id
		LEFT JOIN dbo.cot_bodega_ubicacion ub
			ON ub.id = ct.id_cot_bodega_ubicacion
		LEFT JOIN dbo.tra_cargue_enc te
			ON te.id_cot_cotizacion = c.id_cot_cotizacion
		LEFT JOIN dbo.veh_agenda_cli ac 
			ON ac.id = cc.id_asignacion
		LEFT JOIN dbo.veh_sug_mantenimiento ma 
			ON ma.id = cc.id_mante
		LEFT JOIN dbo.veh_solicitudes_escenarios es 
			ON es.id = ma.id_veh_solicitudes_escenarios
		LEFT JOIN dbo.usuario u2 
			ON u2.id = ac.id_usuario
		LEFT JOIN dbo.usuario u3 
			ON u3.id=c.id_usuario_crea
		LEFT JOIN veh_color vc on l.id_veh_color = vc.id
	ORDER BY c.fecha_cita DESC
