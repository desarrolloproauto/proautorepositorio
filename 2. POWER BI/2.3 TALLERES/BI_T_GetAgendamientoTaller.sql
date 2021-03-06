USE [dms_smd3]
GO
/****** Object:  StoredProcedure [dbo].[BI_T_GetAgendamientoTaller]    Script Date: 14/1/2022 12:10:21 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =================================================================================
-- Author:		<Javier Chogllo / INNOVA>
-- Create date: <2021-03-23>
-- Description:	<Procedimiento que obtiene el agendamiento por cada Operario
--               Basado en la opcion Advance 4166 (Sistema de Agendamiento Advance)>
-- Historial:
-- <>    
-- =================================================================================

-- Exec [dbo].[BI_T_GetAgendamientoTaller] 11568,1183,'2021-10-20','2021-10-20'   ---763 registros
ALTER PROCEDURE [dbo].[BI_T_GetAgendamientoTaller]
(
	@operario int,
	@bod int,
    @fecha_desde DATE,
	@fecha_fin DATE 
)  
AS  
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	
	DECLARE @no_cump TINYINT = 0
	declare @id_fijo INT = 0
	declare @estados VARCHAR(MAX) = ''

	--print @fecha_desde print  @fecha_fin

	declare @simple as table
	(
		operario int,
		id_tal_horario int,
		hora_inicia time,
		hora_termina time,
		ocupado tinyint,
		descripcion varchar(100),
		dia int
	)
	insert @simple
	SELECT operario = ub.id_usuario,
		   d.id_tal_horario,
		   d.hora_inicia,
		   d.hora_termina,
		   d.ocupado,
		   d.descripcion,
		   di.dia
	FROM dbo.usuario_bodega ub
	JOIN dbo.cot_bodega b ON b.id = ub.id_cot_bodega
	JOIN dbo.tal_horario_det d ON d.id_tal_horario = ISNULL(ub.id_tal_horario, b.id_tal_horario)
	JOIN dbo.tal_horario_det_dia di ON di.id_tal_horario_det = d.id
	WHERE b.id = @bod and ub.id_usuario=@operario;

	
	------------------------------------------------------
	--Horario máximo y mínimo de la bodega
	------------------------------------------------------
	declare @max as table
	(
		id_tal_horario int,
		fecha_inicia date,
		fecha_termina date,
		inicia time,
		termina time
	)
    insert @max
	SELECT id_tal_horario = MAX(d.id_tal_horario),
		   fecha_inicia = @fecha_desde,
		   fecha_termina = @fecha_fin,
		   inicia = MIN(d.hora_inicia),
		   termina = MAX(d.hora_termina)
	FROM dbo.cot_bodega b
	JOIN dbo.tal_horario_det d ON d.id_tal_horario = b.id_tal_horario
	WHERE b.id = @bod

	----
	;WITH dias
	AS (SELECT dia1 = 1
		UNION ALL
		SELECT dia1 + 1
		FROM dias
		WHERE dia1 < 8)
	INSERT @simple
	(
		operario,
		id_tal_horario,
		dia,
		hora_inicia,
		hora_termina,
		ocupado,
		descripcion
	)
	SELECT DISTINCT
		   ss.operario,
		   ss.id_tal_horario,
		   d.dia1,
		   m.inicia,
		   m.termina,
		   1,
		   'No disponible'
	FROM @simple ss
		CROSS APPLY dias d
		CROSS APPLY @max m
		LEFT JOIN @simple s
			ON s.id_tal_horario = ss.id_tal_horario
			   AND s.operario = ss.operario
			   AND s.dia = d.dia1
	WHERE s.id_tal_horario IS NULL

	---------------------------------------------------
	----------------------------------------------------
	
	DECLARE @hi TIME,
			@ht TIME,
			@ht_max TIME,
			@dia INT,
			@dia_ant INT,
			@hi_ant TIME,
			@hi_min TIME,
			@id_tal_horario INT,
			@ope INT,
			@ope_ant INT

	SELECT @hi_ant = inicia,
		   @hi_min = inicia,
		   @ht_max = termina
	FROM @max

	DECLARE hor CURSOR FOR
	SELECT id_tal_horario,
		   hora_inicia,
		   hora_termina,
		   dia,
		   operario
	FROM @simple
	ORDER BY operario,
			 dia,
			 hora_inicia
	OPEN hor

	FETCH NEXT FROM hor
	INTO @id_tal_horario,
		 @hi,
		 @ht,
		 @dia,
		 @ope

	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF @dia_ant <> @dia
		   OR @dia = 8
		   OR @ope_ant <> @ope
		BEGIN
			IF @hi_ant < @ht_max
				INSERT @simple
				(
					operario,
					id_tal_horario,
					hora_inicia,
					hora_termina,
					ocupado,
					descripcion,
					dia
				)
				VALUES
				(@ope_ant, @id_tal_horario, @hi_ant, @ht_max, 1, 'No disponible', @dia_ant)

			SELECT @hi_ant = @hi_min
		END

		IF @hi > @hi_ant
			INSERT @simple
			(
				operario,
				id_tal_horario,
				hora_inicia,
				hora_termina,
				ocupado,
				descripcion,
				dia
			)
			VALUES
			(@ope, @id_tal_horario, @hi_ant, @hi, 1, 'No disponible', @dia)

		SELECT @hi_ant = @ht,
			   @dia_ant = @dia,
			   @ope_ant = @ope
		FETCH NEXT FROM hor
		INTO @id_tal_horario,
			 @hi,
			 @ht,
			 @dia,
			 @ope
	END
	CLOSE hor
	DEALLOCATE hor


	-----------------------------------------------------
	------------------------------------------------------
	-- CUALES
	declare @cuales as table
	(
		id int,
		idcamp int,
		ope int
	)
	insert @cuales
	SELECT c.id, idcamp = MAX(ca.id_tal_camp_enc), ope = MAX(o.id)
	FROM dbo.tal_citas c
	LEFT JOIN dbo.tal_citas_camp ca ON ca.id_tal_citas = c.id
	LEFT JOIN dbo.tal_citas_ope o ON o.id_tal_citas = c.id
	WHERE (c.id_cot_bodega = @bod AND CAST(c.fecha_cita AS DATE) BETWEEN @fecha_desde AND @fecha_fin
	AND (@no_cump = 1 OR ISNULL(c.estado,0)<>102))
		OR c.id = @id_fijo
	GROUP BY c.id

	--- CITAS
	declare @Citas as table
	(
		cita int,
		operario int,
		fecha datetime,
		hora_inicia varchar(50),
		hora_termina varchar(50),
		contenido varchar(250),
		inicia datetime,
		termina datetime,
		ocupado bit,
		dia int,
		placa varchar(20),
		id_cot_bodega int,
		bodega varchar(50),
		nombre nvarchar(160),
		id_cot_item_lote int,
		id_cot_item int,
		descripcion varchar(500),
		vin nvarchar(100),
		id_cliente int,
		cliente nvarchar(200),
		id_contacto int,
		contacto nvarchar(200),
		idplan int,
		idcamp int,
		[label] varchar(10),
		duracion decimal,
		horas decimal(38,7),
		nom_plan varchar(80),
		nom_camp varchar(250),
		email varchar(50),
		tel_1 nvarchar(40),
		id_tal_citas_tipo int,
		id_tal_citas_canal int,
		ope int,
		ubicacion varchar(80),
		ot int,
		transporte tinyint,
		id_veh_linea int,
		id_veh_linea_modelo int,
		id_veh_marca int,
		automatica int,
		st int
	)
	insert @Citas
	SELECT cita = c.id,
		operario = c.id_usuario,
		fecha = c.fecha_cita,
		hora_inicia = CONVERT(VARCHAR, c.fecha_cita, 108),
		hora_termina = CONVERT(VARCHAR, c.fecha_termina, 108),
		contenido = c.notas,
		inicia = c.fecha_cita,
		termina = c.fecha_termina,
		ocupado = 1,
		dia = DATEPART(WEEKDAY, c.fecha_cita),
		placa = ISNULL(l.placa,c.placa),
		id_cot_bodega = b.id,
		bodega = b.descripcion,
		nombre = u.nombre,
		id_cot_item_lote = l.id,
		id_cot_item = ISNULL(c.id_cot_item,l.id_cot_item),
		cast(d.descripcion as varchar),
		l.vin,
		id_cliente = cli.id,
		cliente = CASE
						WHEN cli.id IS NULL AND c.placa IS NULL THEN
							'Novedad'
						ELSE
							ISNULL(cli.razon_social,c.responsable)
					END,
		id_contacto = co.id,
		contacto = co.nombre,
		idplan = c.id_tal_planes,
		idcamp = cu.idcamp,
		label = CASE
					WHEN cli.id IS NULL AND c.placa IS NULL THEN
						'Novedad'
					ELSE
						'Cita'
				END,
		duracion = CAST(DATEDIFF(MINUTE, c.fecha_cita, c.fecha_termina) AS REAL) / 60,
		horas = ISNULL(vt.tiempo,0),
		nom_plan = pl.descripcion,
		nom_camp = ce.titulo,
		co.email,
		co.tel_1,
		c.id_tal_citas_tipo,
		c.id_tal_citas_canal,
		cu.ope,
		ubicacion = ub.descripcion,
		ot = c.id_cot_cotizacion,
		c.transporte,
		d.id_veh_linea,
		d.id_veh_linea_modelo,
		d.id_veh_marca,
		c.automatica,
		st = CAST(CASE WHEN c.id_cot_item_lote IS NULL AND c.placa IS NULL THEN NULL
						WHEN te.id IS NOT NULL THEN
							8 --Entregada
						WHEN ISNULL(ct.anulada, 0) = 1
							AND tip.sw = 46 THEN
							7 --Facturada
						WHEN ISNULL(ct.anulada, 0) = 2 THEN
							6 --Cerrada
						WHEN e.cuantas > 0
							AND e.terminada >= e.cuantas THEN
							5 --Terminada
						WHEN e.cuantas > 0
							AND e.pausa >= e.cuantas THEN
							4 --Pausada
						WHEN e.proceso > 0 THEN
							3 --Proceso
						WHEN c.id_cot_cotizacion IS NOT NULL THEN
							2 --En OT
						WHEN c.estado = 101 THEN
							101 --Llegó
						WHEN c.estado = 102 THEN
							102 --No cumplida
						WHEN c.id_cot_cotizacion IS NULL AND GETDATE()<=c.fecha_cita AND ISNULL(c.automatica,0)<>1 THEN
							1 --Agendada
						WHEN c.id_cot_cotizacion IS NULL AND GETDATE()>c.fecha_cita THEN
							100 --Atrasada
						WHEN c.id_cot_cotizacion IS NULL AND GETDATE()<=c.fecha_cita AND ISNULL(c.automatica,0)=1 THEN
							103 --Sin confirmar
					END AS VARCHAR)
	--INTO #citas
	FROM @cuales cu
	JOIN dbo.tal_citas c ON c.id = cu.id
	JOIN dbo.usuario u ON u.id = c.id_usuario
	JOIN dbo.cot_bodega b ON b.id = c.id_cot_bodega
		--LEFT JOIN #operarios o
		--	ON o.id = u.id
	LEFT JOIN dbo.tal_camp_enc ce ON ce.id = cu.idcamp
	LEFT JOIN dbo.tal_planes pl ON pl.id = c.id_tal_planes
	LEFT JOIN dbo.cot_cotizacion ct ON ct.id = c.id_cot_cotizacion
	LEFT JOIN dbo.cot_tipo tip ON tip.id = ct.id_cot_tipo AND tip.sw IN ( 46 )
	LEFT JOIN dbo.v_tal_operaciones_estado e ON e.id_cot_cotizacion = ct.id
	LEFT JOIN dbo.cot_item_lote l ON l.id = c.id_cot_item_lote
	LEFT JOIN dbo.v_cot_item_descripcion d ON d.id = ISNULL(c.id_cot_item,l.id_cot_item)
	LEFT JOIN dbo.cot_cliente_contacto co ON co.id = l.id_cot_cliente_contacto
	LEFT JOIN dbo.cot_cliente cli ON cli.id = co.id_cot_cliente
	LEFT JOIN dbo.cot_bodega_ubicacion ub ON ub.id = ct.id_cot_bodega_ubicacion
	LEFT JOIN dbo.tra_cargue_enc te ON te.id_cot_cotizacion = c.id_cot_cotizacion
	LEFT JOIN dbo.v_tal_citas_tiempo vt ON vt.id_tal_citas = c.id
	WHERE u.id=@operario --IS NOT NULL OR c.id = @id_fijo
	
	
	/*********************************/
	declare @mes as table
	(
		[cita] [bigint],
		[operario] [int],
		[fecha] [datetime],
		[hora_inicia] [time](7),
		[hora_termina] [time](7),
		[asunto] [int],
		[inicia] [datetime],
		[termina] [datetime],
		[ocupado] [tinyint],
		[dia] [int],
		[placa] [varchar](20),
		[nombre] [nvarchar](160),
		[id_cot_bodega] [int],
		[bodega] [varchar](50),
		[id_cot_item_lote] [int],
		[id_cot_item] [int],
		[descripcion] [varchar](500),
		[vin] [nvarchar](100),
		[id_cliente] [int],
		[id_contacto] [int],
		[cliente] [nvarchar](200),
		[contacto] [nvarchar](200),
		[idplan] [int],
		[idcamp] [int],
		[nom_plan] [varchar](80),
		[nom_camp] [varchar](250),
		[restringida] [tinyint],
		[contenido] [varchar](250),
		[label] [varchar](10),
		[st] [int],
		[duracion] [decimal](18, 0),
		[horas] [decimal](38, 7),
		[adicional] [int],
		[montada] [int],
		[email] [varchar](50),
		[tel_1] [nvarchar](40),
		[estado] [varchar](15),
		[id_tal_citas_tipo] [int],
		[id_tal_citas_canal] [int],
		[transporte] [tinyint],
		[ope] [int],
		[ot] [int],
		[mas] [varchar](max),
		[id_veh_linea] [int],
		[id_veh_linea_modelo] [int],
		[id_veh_marca] [int],
		[automatica] [int] 
	)
	

	;WITH Mes
	AS (SELECT fecha = @fecha_fin
		UNION ALL
		SELECT DATEADD(DAY, -1, fecha)
		FROM Mes
		WHERE fecha
		BETWEEN DATEADD(DAY, 1, @fecha_desde) AND @fecha_fin)
	--0) Horario del mes 
	insert @mes
	SELECT cita = CAST(CAST(d.operario AS VARCHAR) + CONVERT(VARCHAR, m.fecha, 112)
					   + CAST(DATEPART(HOUR, d.hora_inicia) AS VARCHAR) + CAST(DATEPART(MINUTE, d.hora_inicia) AS VARCHAR) AS BIGINT)
				  * -1,
		   d.operario,
		   m.fecha,
		   d.hora_inicia,
		   d.hora_termina,
		   asunto = NULL,
		   inicia = CAST(CONVERT(VARCHAR, m.fecha, 112) + ' ' + CONVERT(VARCHAR, d.hora_inicia, 108) AS DATETIME),
		   termina = CAST(CONVERT(VARCHAR, m.fecha, 112) + ' ' + CONVERT(VARCHAR, d.hora_termina, 108) AS DATETIME),
		   d.ocupado,
		   d.dia,
		   placa = NULL,
		   nombre = NULL,
		   id_cot_bodega = NULL,
		   bodega = NULL,
		   id_cot_item_lote = NULL,
		   id_cot_item = NULL,
		   descripcion = NULL,
		   vin = NULL,
		   id_cliente = NULL,
		   id_contacto = NULL,
		   cliente = NULL,
		   contacto = NULL,
		   idplan = NULL,
		   idcamp = NULL,
		   nom_plan = NULL,
		   nom_camp = NULL,
		   restringida = d.ocupado,
		   contenido = CASE
						   WHEN d.ocupado IS NULL THEN
							   d.descripcion
						   ELSE
							   NULL
					   END,
		   label = 'No',
		   st = '0',
		   duracion = CAST(NULL AS INTEGER),
		   horas = CAST(NULL AS INTEGER),
		   adicional = CAST(NULL AS INTEGER),
		   montada = c.cita,
		   email = NULL,
		   tel_1 = NULL,
		   estado = NULL,
		   id_tal_citas_tipo = NULL,
		   id_tal_citas_canal = NULL,
		   transporte = NULL,
		   ope = NULL,
		   ot = NULL,
		   mas = NULL,
		   id_veh_linea = NULL,
		   id_veh_linea_modelo = NULL,
		   id_veh_marca = NULL,
		   automatica = NULL
	--INTO #mes
	FROM dbo.tal_horario h
	JOIN @simple d ON d.id_tal_horario = h.id
	JOIN Mes m ON DATEPART(WEEKDAY, m.fecha) = d.dia
	LEFT JOIN @citas c
			ON CAST(c.inicia AS DATE) = CAST(m.fecha AS DATE)
			   AND d.hora_inicia
			   BETWEEN c.hora_inicia AND c.hora_termina
			   AND c.operario = d.operario
	WHERE d.ocupado IS NOT NULL
		UNION
	SELECT c.cita,
		   c.operario,
		   c.fecha,
		   c.hora_inicia,
		   c.hora_termina,
		   asunto = NULL,
		   c.inicia,
		   c.termina,
		   c.ocupado,
		   c.dia,
		   c.placa,
		   c.nombre,
		   c.id_cot_bodega,
		   c.bodega,
		   c.id_cot_item_lote,
		   c.id_cot_item,
		   c.descripcion,
		   c.vin,
		   c.id_cliente,
		   c.id_contacto,
		   c.cliente,
		   c.contacto,
		   c.idplan,
		   c.idcamp,
		   c.nom_plan,
		   c.nom_camp,
		   restringida = NULL,
		   c.contenido,
		   c.label,
		   c.st,
		   c.duracion,
		   c.horas,
		   adicional = CAST(NULL AS INTEGER),
		   montada = NULL,
		   c.email,
		   c.tel_1,
		   estado = e.descripcion,
		   c.id_tal_citas_tipo,
		   c.id_tal_citas_canal,
		   c.transporte,
		   c.ope,
		   c.ot,
		   mas = CASE WHEN c.ubicacion IS NOT NULL THEN '<b>Ubicación:</b> ' + c.ubicacion + dbo.DMSCr(1) ELSE '' END +
				 '<b>Estado:</b> ' + e.descripcion,
		   c.id_veh_linea,
		   c.id_veh_linea_modelo,
		   c.id_veh_marca,
		   c.automatica
	FROM @citas c
	LEFT JOIN dbo.v_tal_citas_estado e ON e.id = c.st

	
	SELECT m.cita,
		   m.operario,
		   m.fecha,
		   m.hora_inicia,
		   m.hora_termina,
		   m.asunto,
		   m.inicia,
		   m.termina,
		   m.ocupado,
		   m.dia,
		   m.placa,
		   m.nombre,
		   m.id_cot_bodega,
		   m.bodega,
		   m.id_cot_item_lote,
		   m.id_cot_item,
		   m.descripcion,
		   m.vin,
		   m.id_cliente,
		   m.id_contacto,
		   m.cliente,
		   m.contacto,
		   m.idplan,
		   m.idcamp,
		   m.nom_plan,
		   m.nom_camp,
		   m.restringida,
		   m.contenido,
		   m.label,
		   duracion = m.duracion - ISNULL(CAST(DATEDIFF(MINUTE, m2.inicia, m2.termina) AS REAL) / 60, 0),
		   m.horas,
		   adicional = ISNULL(CAST(DATEDIFF(MINUTE, m2.inicia, m2.termina) AS REAL) / 60, 0),
		   m.montada,
		   m.st,
		   m.email,
		   m.tel_1,
		   m.estado,
		   m.id_tal_citas_tipo,
		   m.id_tal_citas_canal,
		   m.transporte,
		   id2 = NULL,
		   id = NULL,
		   label2 = CASE WHEN m.id_cot_item_lote IS NULL THEN 'Novedad' ELSE 'Color' + CAST(m.st AS VARCHAR) END,
		   m.ope,
		   m.ot,
		   m.mas,
		   m.id_veh_linea,
		   m.id_veh_linea_modelo,
		   m.id_veh_marca,
		   m.automatica
	FROM @mes m
	LEFT JOIN @mes m2 ON m.cita = m2.montada AND m2.ocupado IS NOT NULL
	ORDER BY m.operario,m.inicia
	

