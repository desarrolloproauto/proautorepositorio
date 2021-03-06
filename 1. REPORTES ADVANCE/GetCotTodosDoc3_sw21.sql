USE [dms_smd3]
GO
/****** Object:  StoredProcedure [dbo].[GetCotTodosDoc3_sw21]    Script Date: 24/01/2022 10:58:50 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-- 2022-01-24 Original de Produccion
*/



ALTER PROCEDURE [dbo].[GetCotTodosDoc3_sw21]
(
	@Emp		   INT,
	@IdCli		   INT,
	@bod		   INT		   = 0,
	@sw			   INT		   = -100,
	@tipo		   INT		   = 0,
	@docref_tipo   VARCHAR(5)  = '',
	@docref_numero VARCHAR(10) = '',
	@numero		   BIGINT		   = 0, --MAR 743: BIGINT - ETICOS --@numero INT = 0,
	@FecInf		   DATETIME	   = '19501231',
	@FecSup		   DATETIME	   = '20601231',
	@SoloFinan	   SMALLINT	   = 0,
	@SoloSaldo	   SMALLINT	   = 0,
	@ExcAnu		   SMALLINT	   = 0,
	@numeroSup	   BIGINT		   = 0, --MAR 743: BIGINT - ETICOS --@numeroSup INT = 0,
	@esFechaReal   BIT		   = 0,
	@Cuantos AS	   INT		   = 500,
	@IdPlaca	   INT		   = 0,
	@Bodegas varchar(max) = '', -- DHT 751
	@Sws varchar(max) = '' --DHT 751
)
AS

SELECT id_cot_bodega=cast(t.val as integer)
INTO #bodegas
FROM dbo.fnSplit(@Bodegas,',') t

SELECT id_cot_sw=cast(t.val as integer)
INTO #sws
FROM dbo.fnSplit(@Sws,',') t

--/DHT 751

--ADMG 733
DECLARE	@IdPrdOrd INT = 0
IF @IdPlaca < 0
BEGIN
	set @IdPrdOrd = abs(@IdPlaca)
	set @IdPlaca = 0
END
--/ADMG 733

IF @docref_numero = '0'
	SET @docref_numero = ''


SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

IF @numeroSup = 0
	SET @numeroSup = @numero

	SELECT TOP (@Cuantos)
		c.id,
		c.Nit, --MAR 743: Nit del tercero - (Eticos)
		c.Tercero,
		Contacto = con.nombre,
		c.Tipo,
		Concepto = co.descripcion, --SGQ-749
		c.id_cot_tipo,
		c.Numero,
		c.Fecha,
		c.Fecha_real, --rml 736
		c.[Valor Neto],
		Total = ABS(c.Valor),
		Aplicado = ABS(c.Aplicado),
		Saldo = ABS(c.Saldo),
		c.Vencimiento,
		c.Bodega,
		c.Vendedor,
		c.anulado,
		c.notas,
		c.sw,
		Egreso = CASE WHEN c.sw = 6 THEN ISNULL(t.Contacto, '') + ' ' + ISNULL(t.notas, '') + ' ' + ISNULL(t.Banco, '')ELSE NULL END,
		tv.tiene_devol,
		--c.fecha_real, --rml 736
		[!c] = CASE WHEN c.anulado IS NOT NULL THEN 1 ELSE CASE tv.tiene_devol WHEN 1 THEN 3 ELSE NULL END END --SGQ-744
	INTO #docs
	FROM dbo.v_cot_cartera_historia_total_sw21 c
	LEFT JOIN dbo.cot_cliente_contacto con ON con.id = c.id_cot_cliente_contacto
	LEFT JOIN dbo.v_tes_egreso_pago_uno t ON t.id_tes_egreso = c.id
											 AND c.sw = 6
	LEFT JOIN dbo.v_cot_tiene_devolucion tv ON tv.id_cot_cotizacion = c.id
	LEFT JOIN dbo.com_orden_concep co ON co.id = c.id_com_orden_concep --SGQ-749
	LEFT JOIN #bodegas b ON b.id_cot_bodega=c.id_cot_bodega --DHT 751
	LEFT JOIN #sws s ON s.id_cot_sw=c.sw --DHT 751
	WHERE
		--c.anulado IS NULL AND SGQ-744: Esto viene por parámetro
		c.id_emp = @Emp
		AND
		(
			@IdCli = 0
			OR c.id_cot_cliente = @IdCli
		)
		AND
		(
			@bod = 0
			OR c.id_cot_bodega = @bod
		)
		AND
		(
			@tipo = 0
			OR c.id_cot_tipo = @tipo
		)
		AND
		--(@numero=0 or c.numero=@numero) and
		(
			(
				@numero = 0
				AND @numeroSup = 0
			)
			OR c.Numero BETWEEN @numero AND @numeroSup
		)
		AND
		(
			@sw = -100
			OR c.sw = @sw
		)
		AND
		(
			@esFechaReal = 1
			OR c.Fecha BETWEEN @FecInf AND @FecSup
		)
		AND --esto es para ver si usa la fecha cartera o la real
		(
			@esFechaReal = 0
			OR c.fecha_real BETWEEN @FecInf AND @FecSup
		)
		AND --esto es para ver si usa la fecha cartera o la real
		(
			@SoloFinan = 0
			OR c.sw IN (1, -1, 5, 6, 21, 22, 23, 31, 32, 33)
		)
		AND
		(
			@ExcAnu = 0
			OR c.anulado IS NULL
		)
		--DHT 751
		AND
		(
			@Bodegas = ''
			OR c.id_cot_bodega =b.id_cot_bodega
		)
		AND
		(
			@Sws =''
			OR c.sw =s.id_cot_sw
		)
		--/DHT 751
	ORDER BY
		c.Fecha DESC,
		c.id DESC

--JFG-749 si busca por placa, incluye los que tienen placa en el detalle
IF @IdPlaca = 0
   SELECT * FROM #docs
ELSE
BEGIN
    SELECT * FROM #docs
    UNION ALL
	SELECT TOP (@Cuantos)
		c.id,
		c.Nit, --MAR 743: Nit del tercero - (Eticos)
		c.Tercero,
		Contacto = con.nombre,
		c.Tipo,
		Concepto = co.descripcion, --SGQ-749
		c.id_cot_tipo,
		c.Numero,
		c.Fecha,
		c.Fecha_real, --rml 736
		c.[Valor Neto],
		Total = ABS(c.Valor),
		c.Vencimiento,
		c.Bodega,
		c.Vendedor,
		c.anulado,
		c.notas,
		c.sw,
		Egreso = CASE WHEN c.sw = 6 THEN ISNULL(t.Contacto, '') + ' ' + ISNULL(t.notas, '') + ' ' + ISNULL(t.Banco, '')ELSE NULL END,
		tv.tiene_devol,
		--c.fecha_real, --rml 736
		[!c] = CASE WHEN c.anulado IS NOT NULL THEN 1 ELSE CASE tv.tiene_devol WHEN 1 THEN 3 ELSE NULL END END --SGQ-744
	FROM dbo.v_cot_cartera_historia_total_sw21 c
	LEFT JOIN dbo.cot_cotizacion_item ci ON ci.id_cot_cotizacion = c.id AND ISNULL(ci.id_cot_item_lote,0) = @idplaca AND ISNULL(c.id_cot_item_lote,0) <> @IdPlaca
	LEFT JOIN dbo.cot_pedido_item cip ON cip.id_cot_pedido = c.id AND ISNULL(cip.id_cot_item_lote,0) = @idplaca AND ISNULL(c.id_cot_item_lote,0) <> @IdPlaca
	LEFT JOIN dbo.cot_cliente_contacto con ON con.id = c.id_cot_cliente_contacto
	LEFT JOIN dbo.v_tes_egreso_pago_uno t ON t.id_tes_egreso = c.id
											 AND c.sw = 6
	LEFT JOIN dbo.v_cot_tiene_devolucion tv ON tv.id_cot_cotizacion = c.id
	LEFT JOIN dbo.com_orden_concep co ON co.id = c.id_com_orden_concep --SGQ-749
	WHERE
		--c.anulado IS NULL AND SGQ-744: Esto viene por parámetro
		c.id_emp = @Emp
		AND
		(
			@IdCli = 0
			OR c.id_cot_cliente = @IdCli
		)
		AND
		(
			@bod = 0
			OR c.id_cot_bodega = @bod
		)
		AND
		(
			@tipo = 0
			OR c.id_cot_tipo = @tipo
		)
		AND
		--(@numero=0 or c.numero=@numero) and
		(
			(
				@numero = 0
				AND @numeroSup = 0
			)
			OR c.Numero BETWEEN @numero AND @numeroSup
		)
		AND
		(
			@sw = -100
			OR c.sw = @sw
		)
		AND
		(
			@esFechaReal = 1
			OR c.Fecha BETWEEN @FecInf AND @FecSup
		)
		AND --esto es para ver si usa la fecha cartera o la real
		(
			@esFechaReal = 0
			OR c.fecha_real BETWEEN @FecInf AND @FecSup
		)
		AND --esto es para ver si usa la fecha cartera o la real
		(
			@SoloFinan = 0
			OR c.sw IN (1, -1, 5, 6, 21, 22, 23, 31, 32, 33)
		)
		AND
		(
			@ExcAnu = 0
			OR c.anulado IS NULL
		)
		AND
		(@IdPlaca = CASE WHEN @sw = 41 THEN isnull(cip.id_cot_item_lote,0) ELSE isnull(ci.id_cot_item_lote,0) END)
END
--/JFG-749

