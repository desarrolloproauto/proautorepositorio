USE [dms_smd3]
GO
/****** Object:  StoredProcedure [dbo].[GetRetencionesRegistradas_ecuador]    Script Date: 25/2/2022 9:58:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[GetRetencionesRegistradas_ecuador]
(
    @Emp INT,
    @Bod VARCHAR(MAX),
    @Cli INT = 0,
    @porcenRet VARCHAR(MAX) = '0',
   @fechaini DATE,
    @fechafin DATE
   
)
AS
--temporal con terceros  

DECLARE @posretfte AS INT = dbo.ReglaDeNegocio(@Emp, 3, 'retfte', 0);
DECLARE @posretiva AS INT = dbo.ReglaDeNegocio(@Emp, 3, 'retiva', 0);


DECLARE @cliente TABLE
(
    id INT,
    nit VARCHAR(20),
    razonsocial VARCHAR(300)
);
INSERT @cliente
(
    id,
    nit,
    razonsocial
)
SELECT i.id,
       i.nit,
       i.razon_social
FROM dbo.cot_cliente i
    JOIN dbo.cot_zona_sub sub
        ON sub.id = i.id_cot_zona_sub
WHERE i.id_emp = @Emp
      AND
      (
          @Cli = 0
          OR i.id = @Cli
      );


DECLARE @Bodega AS TABLE
(
    id INT,
    descripcion VARCHAR(200),
    ecu_establecimiento VARCHAR(4)
);

IF @Bod = '0'
BEGIN
    INSERT @Bodega
    (
        id,
        descripcion
    )
    SELECT id,
           descripcion
    FROM dbo.cot_bodega
    WHERE id_emp = @Emp;

END;
ELSE
    INSERT @Bodega
    (
        id,
        descripcion
    )
    SELECT CAST(f.val AS INT),
           c.descripcion
    FROM dbo.fnSplit(@Bod, ',') f
        JOIN dbo.cot_bodega c
            ON c.id = CAST(f.val AS INT)
    WHERE c.id_emp = @Emp;



DECLARE @ret TABLE
(
    porcentaje DECIMAL(18, 2)
);
IF @porcenRet = '0'
   OR @porcenRet = ''
    INSERT @ret
    (
        porcentaje
    )
    SELECT DISTINCT
           porcentaje
    FROM dbo.cot_conceptos_retencion
    WHERE id_emp = @Emp;
ELSE
    INSERT @ret
    (
        porcentaje
    )
    SELECT CAST(f.val AS DECIMAL(18, 2))
    FROM dbo.fnSplit(@porcenRet, ',') f;




SELECT c.id,
       c.id_cot_tipo,
       c.numero,
       c.fecha,
       rm.emision,
       rm.num_doc,
       rm.numero_electr,
       rm.fecha_emision,
       rm.fecha_caduca,
       rm.numero_imprenta,
       rm.idPago,
       rm.id_cot_cotizacion,
       rm.base_ret_1,
       rm.id_cot_conceptos_retencion1,
       rm.porc_ret_1,
       rm.base_ret_2,
       rm.id_cot_conceptos_retencion2,
       rm.porc_ret_2,
       rm.base_iva_1,
       rm.concepto_retiva1,
       rm.porc_iva_1,
       rm.base_iva_2,
       rm.concepto_retiva2,
       rm.porc_iva_2,
       cl.nit,
       cl.razonsocial,
       Ret1_Rc = NULL,
       Ret2_Rc = NULL
INTO #rcret
FROM dbo.cot_recibo c
    JOIN dbo.cot_recibo_mas rm
        ON rm.id_cot_recibo = c.id
    JOIN @Bodega b
        ON b.id = c.id_cot_bodega
    JOIN @cliente cl
        ON cl.id = c.id_cot_cliente
    LEFT JOIN @ret r
        ON r.porcentaje = ISNULL(rm.porc_ret_1, rm.porc_ret_2)
WHERE c.id_emp = @Emp
      AND ISNULL(c.anulado, 0) <> 1
      AND CAST(c.fecha AS DATE)
      BETWEEN @fechaini AND @fechafin
UNION ALL
SELECT c.id,
       c.id_cot_tipo,
       c.numero,
       c.fecha,
       emision = '000000',
       num_doc = ISNULL(crp.documento, '000000000'),
       numero_electr = NULL,
       fecha_emision = NULL,
       fecha_caduca = NULL,
       numero_imprenta = NULL,
       idPago = NULL,
       id_cot_cotizacion = NULL,
       base_ret_1 = NULL,
       d_cot_conceptos_retencion1 = NULL,
       porc_ret_1 = NULL,
       base_ret_2 = NULL,
       id_cot_conceptos_retencion2 = NULL,
       porc_ret_2 = NULL,
       base_iva_1 = NULL,
       concepto_retiva1 = NULL,
       porc_iva_1 = NULL,
       base_iva_2 = NULL,
       concepto_retiva2 = NULL,
       porc_iva_2 = NULL,
       cl.nit,
       cl.razonsocial,
       Ret1_Rc = ce.ret1,
       Ret2_Rc = ce.ret2
FROM dbo.cot_recibo c
    JOIN con_mov_enc ce
        ON ce.id_origen = c.id
           AND ce.origen = 1
    LEFT JOIN cot_recibo_pago crp
        ON crp.id_cot_recibo = c.id
    JOIN com_orden_concep co
        ON co.id = c.id_com_orden_concep
    JOIN @Bodega b
        ON b.id = c.id_cot_bodega
    JOIN @cliente cl
        ON cl.id = c.id_cot_cliente
    LEFT JOIN dbo.cot_recibo_mas rm
        ON rm.id_cot_recibo = c.id
    LEFT JOIN @ret r
        ON r.porcentaje = ISNULL(rm.porc_ret_1, rm.porc_ret_2)
WHERE c.id_emp = @Emp
      AND ISNULL(c.anulado, 0) <> 1
      AND rm.id_cot_recibo IS NULL
      AND CAST(c.fecha AS DATE)
      BETWEEN @fechaini AND @fechafin
      AND
      (
          ce.ret1 IS NOT NULL
          OR ce.ret2 IS NOT NULL
      );



SELECT [Ruc/Cédula] = rt.nit,
       Cliente = rt.razonsocial,
       [Fecha Retención] = ISNULL(rt.fecha_emision, rt.fecha),
       [Número Retención] = CASE
                                WHEN rt.numero_electr IS NULL
                                     AND RIGHT('000000' + CAST(ISNULL(rt.emision, '') AS VARCHAR), 6) <> '000000' THEN
                                    RIGHT('000000' + CAST(ISNULL(rt.emision, '') AS VARCHAR), 6) + ''
                                    + RIGHT('000000000' + CAST(ISNULL(rt.num_doc, '') AS VARCHAR), 12)
                                WHEN rt.numero_electr IS NULL
                                     AND RIGHT('000000' + CAST(ISNULL(rt.emision, '') AS VARCHAR), 6) = '000000' THEN
                                    RIGHT('000000000' + CAST(ISNULL(rt.num_doc, '') AS VARCHAR), 15)
                                ELSE
                                    RIGHT('000000' + CAST(ISNULL(rt.emision, '') AS VARCHAR), 6) + ''
                                    + RIGHT('000000000' + CAST(ISNULL(rt.num_doc, '') AS VARCHAR), 9)
                            END,
       [Número Autorizacion] = rt.numero_electr,
       [Factura] = RIGHT('000' + CAST(b.ecu_establecimiento AS VARCHAR), 3) + ''
                   + RIGHT('000' + CAST(ct.ecu_emision AS VARCHAR), 3) + ''
                   + RIGHT('000000000' + CAST(cc.numero_cotizacion AS VARCHAR), 9),
       [Asiento] = ctr.descripcion + '-' + CAST(rt.numero AS VARCHAR),
       [Número Asiento] = rt.numero,
       [Id] = rt.id,
       [RetFuente1_Base] = rt.base_ret_1,
       [RetFuente1_% Retención] = rt.porc_ret_1,
       [RetFuente1_Valor Retención] = ISNULL(rt.base_ret_1 * (rt.porc_ret_1 / 100), rt.Ret1_Rc),
       [RetFuente2_Base] = rt.base_ret_2,
       [RetFuente2_% Retención] = rt.porc_ret_2,
       [RetFuente2_Valor Retención] = rt.base_ret_2 * (rt.porc_ret_2 / 100),
       [RetIva1_base] = rt.base_iva_1,
       [RetIva1_% Retención] = rt.porc_iva_1,
       [RetIva1_Valor Retención] = ISNULL(rt.base_iva_1 * (rt.porc_iva_1 / 100), rt.Ret2_Rc),
       [RetIva2_base] = rt.base_iva_2,
       [RetIva2_% Retención] = rt.porc_iva_2,
       [RetIva2_Valor Retención] = rt.base_iva_2 * (rt.porc_iva_2 / 100) , 
	   [Fecha registro]=rt.fecha,
	   [Fecha emisión Ret] =rt.fecha_emision, 
	   [Fecha vencimiento Ret]=rt.fecha_caduca, 
	   [Fecha emisión factura]=	cc.fecha


FROM #rcret rt
    JOIN dbo.cot_tipo ctr
        ON ctr.id = rt.id_cot_tipo
    LEFT JOIN dbo.cot_cotizacion cc
        ON cc.id = rt.id_cot_cotizacion
    LEFT JOIN dbo.cot_bodega b
        ON b.id = cc.id_cot_bodega
    LEFT JOIN dbo.cot_tipo ct
        ON ct.id = cc.id_cot_tipo;

SELECT Agencia = CASE
                     WHEN @Bod = '0' THEN
                         'Todas'
                     ELSE
                         @Bod
                 END,
       Cliente = CASE
                     WHEN @Cli = '0' THEN
                         'Todas'
                     ELSE
                         CAST(@Cli AS VARCHAR)
                 END,
       Retencion = CASE
                       WHEN @porcenRet = '0' THEN
                           'Todas'
                       ELSE
                           CAST(@porcenRet AS VARCHAR)
                   END,
       FechaInicial = @fechaini,
       FechaFinal = @fechafin,
       Empresa = e.nombre_empresa
FROM dbo.emp e
WHERE e.id = @Emp;

