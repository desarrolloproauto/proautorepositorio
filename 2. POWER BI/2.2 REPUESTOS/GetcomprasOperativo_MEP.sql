USE [dms_smd3]
GO
/****** Object:  StoredProcedure [dbo].[GetcomprasOperativo_MEP]    Script Date: 07/02/2022 2:34:13 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ===========================================================================================================================================
-- Author:		<Angelica Pinos>
-- Create date: <2021-04-05>
-- Modulo:		<BI>
-- Description:	<Procedimiento para obtener las Compras del Modulo de Repuestos  (Reporte 100016 Advance)
-- Historial de Cambios:
-- 2021-08-13   Se modifica para que se obtengan no solo Repuestos sino tambien Accesorios y Dispositivos. (JCHB)
-- 2021-08-30   Se agrega un cruce con la tabla [fe_documentos_electronicos] y se agrega el campo [Nº_AUTORIZACION] con el cual se valida si 
--              es una factura física o electrónica. (APF)
-- 2021-08-31   Se cambia la tabla en el JOIN [fe_documentos_electronicos] por [cot_cotizacion_mas]. (APF)
-- ============================================================================================================================================

-- exec [dbo].[GetComprasOperativo_MEP] 605,'0','','',2021,7,0,0,0,0
-- Exec GetcomprasOperativo_MEP '605','1182','0','0','2021','8','0','0','0','11848';

ALTER PROCEDURE [dbo].[GetcomprasOperativo_MEP]
(
	@Emp	 int,
	@bod      VARCHAR(MAX),
	@Gru	 int,
	@Sub	 int,
	@Ano	 int,
	@Mes	 int,
	@Sub3	 int	 = 0,
	@Sub4	 int	 = 0,
	@Sub5	 int	 = 0,
	@Usuario INT	 = 0 --Usuario para control de permiso 160 para ver costos y utilidad  
)
AS

--nombre de subgrupo en texto
DECLARE @NombreSubgrupo VARCHAR(50) = dbo.NombreSubgrupo(@gru, @sub)
IF @NombreSubgrupo <> ''
	SET @sub = 0 --apagamos el subgrupo como tal
--/nombre de subgrupo en texto	

-- control de permiso 160 para ver costos y utilidad  
DECLARE @Costo tinyint = dbo.TienePermiso(@Usuario,435,160)
DECLARE @bodega AS TABLE
( 
	id INT,
	descripcion VARCHAR(200),
	ecu_establecimiento VARCHAR(6)
)
IF @bod = '0'
		INSERT @bodega
		SELECT 
			id,
			descripcion,
			ecu_establecimiento
		FROM dbo.cot_bodega
		WHERE id_emp = @emp
	ELSE
		INSERT @bodega
		SELECT 
			CAST(f.val AS INT),
			c.descripcion,
			c.ecu_establecimiento
		FROM dbo.fnsplit(@bod,',') f
		JOIN dbo.cot_bodega c
		ON c.id = CAST(f.val AS INT)
 
SELECT
    Bodega=cb.descripcion,
	Razon=cc.razon_social,
	Fecha=c.fecha,
	Tipo=t.descripcion,
	[Numero cotizacion]=c.numero_cotizacion,
	[Id documento]=c.id,
	Grupo = g.descripcion,
	Subgrupo = s.descripcion,
	Subgrupo3 = s3.descripcion,
	Subgrupo4 = s4.descripcion,
	Subgrupo5 = s5.descripcion,
    [Linea]=ti.descripcion,
    [Original-alterno]=cv.campo_5,
    [Fuente (cor)*]=cv.campo_4 ,
	Codigo = ci.codigo,
	Descripcion = (ci.descripcion),
	Cantidad = (CASE WHEN t.sw = -1 THEN -1 * v.cantidad ELSE v.cantidad END),
	[Costo]=v.costo_und,
	--[Precio Total] =CASE
 --                        WHEN v.precio_cotizado = 0 THEN
 --                            NULL
 --                        ELSE
 --                            v.precio_cotizado * v.cantidad --* dbo.DecidaTasa(mo.id, mo.dividir, z.tasa)
 --                    END
	--				  *
	--				 CASE WHEN t.sw = -1 THEN -1 end ,
	[Costo Total] =  NULLIF((CASE WHEN t.sw = -1 THEN -1 *   v.costo_und * v.cantidad ELSE   v.costo_und * v.cantidad END) * @Costo, 0),												  
	[Notas]=isnull(c.notas,''),	
	--[Valor Utilidad] = NULLIF((CASE WHEN t.sw = -1 THEN -1 * v.[Valor Utilidad] ELSE v.[Valor Utilidad] END) * @Costo, 0),										  
	--[%Uti] = NULLIF((CASE WHEN (v.[Precio Total]) > 0 THEN ((v.[Precio Total]) - (v.[Costo Total])) * 100 / SUM(v.[Precio Total])ELSE NULL END) * @Costo, 0) ,
	[Factura Proveedor]= (RIGHT('000000000' + CAST(c.docref_numero AS VARCHAR), 9)),
	c.total_iva,
	total_iva_det=(v.cantidad* v.precio_cotizado*v.porcentaje_iva/100),
	c.ret1,
	c.ret2,
	c.ret3,
	c.ret4,
	c.ret5,
	c.ret6, 
	v.id_cot_item,
	v.id_cot_item_lote ,
	c.id, 
	c.id_cot_tipo
	into #compras
FROM @bodega b
	join cot_cotizacion c on c.id_cot_bodega=b.id
	join dbo.cot_cotizacion_item v on c.id=v.id_cot_cotizacion
	join cot_cliente cc on cc.id=c.id_cot_cliente
	join cot_tipo t on t.id=c.id_cot_tipo
	join cot_bodega cb on cb.id=c.id_cot_bodega
	JOIN dbo.cot_item ci ON ci.id = v.id_cot_item
	join cot_item_talla ti on ti.id=ci.id_cot_item_talla
	JOIN dbo.cot_grupo_sub s ON s.id = ci.id_cot_grupo_sub
	JOIN dbo.cot_grupo g ON g.id = s.id_cot_grupo
	LEFT JOIN dbo.cot_grupo_sub5 s5 ON s5.id = ci.id_cot_grupo_sub5
	LEFT JOIN dbo.cot_grupo_sub4 s4 ON s4.id = s5.id_cot_grupo_sub4
	LEFT JOIN dbo.cot_grupo_sub3 s3 ON s3.id = s4.id_cot_grupo_sub3
	LEFT JOIN v_campos_varios cv  on cv.id_cot_item=ci.id
WHERE c.id_emp = @Emp
	and t.sw IN (-4, 4)
	AND --solo compras 
	((@Ano = 0 OR YEAR(c.fecha) = @Ano) AND (@Mes = 0 OR MONTH(c.fecha) = @Mes))
	AND (@Sub = 0 OR ci.id_cot_grupo_sub = @Sub)
	AND (@Sub3 = 0 OR s3.id = @Sub3)
	AND (@Sub4 = 0 OR s4.id = @Sub4)
	AND (@Sub5 = 0 OR s5.id = @Sub5)
	AND (@Gru = 0 OR s.id_cot_grupo = @Gru)
	AND (@NombreSubgrupo = '' OR s.descripcion = @NombreSubgrupo
) --truco para acostallantas
	
 ------- cargar la informacion de los vehiculos para adcionar al reporte y  para el estado del vh   
SELECT DISTINCT
       aa.Id,
       aa.id_cot_tipo,
       aa.id_cot_item,
       aa.id_cot_item_lote,
	   l.vin
INTO #vh
FROM #compras aa
    JOIN dbo.cot_item_lote l ON l.id_cot_item = aa.id_cot_item AND l.id = aa.id_cot_item_lote
where l.vin is not null

    --JOIN dbo.cot_item i
    --    ON i.id = ci.id_cot_item
    --JOIN dbo.veh_linea vl
    --    ON vl.id = i.id_veh_linea
    --JOIN dbo.veh_marca m
    --    ON m.id = vl.id_veh_marca

 SELECT v.Id,
       v.id_cot_tipo,
       Pagado = CASE
                    WHEN SUM(ABS(C.total_total - ISNULL(s.valor_aplicado, 0))) > 0 THEN --GMAH 742  
                        'NP'
                    ELSE
                        'P'
                END
INTO #estadoFacVh
FROM #vh v
    JOIN dbo.cot_cotizacion_item ci ON v.id_cot_item = ci.id_cot_item AND v.id_cot_item_lote = ci.id_cot_item_lote
    JOIN dbo.cot_cotizacion C ON C.id = ci.id_cot_cotizacion
    JOIN dbo.cot_tipo ct ON ct.id = C.id_cot_tipo
    JOIN dbo.v_cot_factura_saldo s ON s.id_cot_cotizacion = C.id
WHERE ct.sw = 4
--GMAH 742  
GROUP BY v.Id, v.id_cot_tipo

select	a.[Bodega]
	,a.[Razon]
	,a.[Fecha]
	,a.[Tipo]
	,a.[Numero cotizacion]
	,a.[Id documento]
	,a.[Grupo]
	,a.[Subgrupo]
	,a.[Subgrupo3]
	,a.[Subgrupo4]
	,a.[Subgrupo5]
	,a.[Linea]
	,a.[Original-alterno]
	,a.[Fuente (cor)*]
	,a.[Codigo]
	,[VIN]=vh.vin
	,a.[Descripcion]
	,a.[Cantidad]
	,a.[Costo]
	,a.[Costo Total]
	,a.[Notas]
	,a.[Factura Proveedor]
	,a.[total_iva]
	,a.[total_iva_det]
	,a.[ret1]
	,a.[ret2]
	,a.[ret3]
	,a.[ret4]
	,a.[ret5]
	,a.[ret6]
	,a.[id_cot_item]
	,a.[id_cot_item_lote]
	,a.[id]
	,a.[id_cot_tipo]
	,a.[Id]
	,a.[id_cot_tipo]
	,[Estado Compra VH]=v.Pagado
	-- Se adicionan dos campos para conocer el numero de autorizacion del documento y determinar si es fisico o electronico
	,[Nº_AUTORIZACION] = mas.numero_electr
	,TIPO_FACTURA = CASE 
						WHEN LEN (mas.numero_electr) = 49 THEN 'ELECTRÓNICA'
						ELSE 'FÍSICA'
					END
from #compras a
	left join #vh vh ON a.Id=vh.id and a.id_cot_tipo=vh.id and a.id_cot_item=vh.id_cot_item and a.id_cot_item_lote=vh.id_cot_item_lote 
	LEFT join #estadoFacVh v on v.id=a.id and v.id_cot_tipo=a.id_cot_tipo
	-- Se agrega para conocer el numero de autorizacion del documento
	LEFT JOIN cot_cotizacion_mas mas ON mas.id_cot_cotizacion = a.id