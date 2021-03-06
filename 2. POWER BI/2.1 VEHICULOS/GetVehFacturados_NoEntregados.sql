USE [dms_smd3]
GO
/****** Object:  StoredProcedure [dbo].[GetVehFacturados_NoEntregados]    Script Date: 5/3/2022 13:27:40 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ========================================================================================================================================================
-- Author:		<>
-- Create date: <>
-- Description:	<Procedimiento para obtener informacion de Vehiculos No Entregados. Reporte 100013 Advance>
-- Historial:	2022-03-05 - Se ajusta script para No obtener Vehiculos vendidos o transferidos a Concesionarios (JCB)
-- Historial:	2022-03-05 - Se ajusta script para No obtener Vehiculos vendidos o transferidos a Relacionadas (JCB)
-- ========================================================================================================================================================

-- EXEC [dbo].[GetVehFacturados_NoEntregados] 605,'2018-08-01','2022-08-31','0'

ALTER procedure  [dbo].[GetVehFacturados_NoEntregados]
(
@emp int, 
@fecIni date,
@fecFin date,
@Bod varchar(max)=''

)
as


DECLARE @Bodega AS TABLE
(
    id INT,
    descripcion VARCHAR(200),
    ecu_establecimiento VARCHAR(6)
)
DECLARE @HojasNegocio AS TABLE
(
    id INT,
    FechaEntrega DATETIME,
	notas VARCHAR(500)
)
DECLARE @Devoluciones AS TABLE
(
    id INT,
    factura VARCHAR(20)
)
  DECLARE @accesoriosvehiculos AS TABLE
(
    id INT,
    ValorAccesorios DECIMAL(18, 2),
    costoAccesorios DECIMAL(18, 2)
)


CREATE TABLE #docco
(
    id INT,
    id_cot_tipo INT,
    codcentro VARCHAR(100),
	cuota_nro int
)
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


			SELECT
c.id,
       c.id_cot_tipo,
       c.id_cot_bodega,
       c.id_cot_cliente,
       c.numero_cotizacion,
       c.fecha,
	   c.fecha_estimada,
       c.notas,
       i.id_cot_item,
       i.id_cot_item_lote,
       cantidad_und= i.cantidad_und*t.sw,
	   i.tiempo,
       i.precio_lista,
       i.precio_cotizado,
       i.costo_und,
       i.porcentaje_descuento,
       i.porcentaje_descuento2,
       i.porcentaje_iva,
       b.descripcion,
       c.id_com_orden_concep,
       b.ecu_establecimiento,
       c.id_usuario_vende,
       c.id_cot_forma_pago,
       t.sw,
	   abono=ISNULL(s.valor_aplicado, 0),
       saldo = c.total_total - ISNULL(s.valor_aplicado, 0),
       i.id_cot_pedido_item, 
	   c.docref_tipo, 
	   c.docref_numero,
	   c.id_veh_hn_enc,
	   c.id_cot_cliente_contacto ,
	   id_cot_cotizacion_item=i.id,
	   costo=i.costo_und,
	   l.lote
	--   l.notas as notas_lote
	 
	   into #Docs
FROM dbo.cot_cotizacion c
    JOIN @Bodega b
        ON b.id = c.id_cot_bodega
    JOIN dbo.cot_tipo t
        ON t.id = c.id_cot_tipo
    JOIN dbo.cot_cotizacion_item i
        ON i.id_cot_cotizacion = c.id
   JOIN cot_item_lote l 
   on l.id_cot_item=i.id_cot_item and l.id=i.id_cot_item_lote and l.vin is not null
   LEFT JOIN dbo.v_cot_factura_saldo s
        ON s.id_cot_cotizacion = c.id
 WHERE c.id_emp = @emp
      AND t.sw IN ( 1, -1 )
      AND CAST(c.fecha AS DATE)
 		  BETWEEN @fecIni AND @fecFin
		 and isnull(c.id_cot_cotizacion_estado,0) <> 794 and isnull(c.id_cot_cotizacion_estado,0) <> 802

-- Eliminar registros de factura que tienen devoluciones
--Select  ci_dev.*
delete d
From #Docs d 
	inner join v_cot_cotizacion_factura_dev dev on dev.id_cot_cotizacion_factura = d.id
	inner join cot_cotizacion_item ci_dev on dev.id_cot_cotizacion = ci_dev.id_cot_cotizacion and d.id_cot_item = ci_dev.id_cot_item
Where d.sw = 1
	and ci_dev.cantidad_und = 1		-- Diferencia, si es una nc de devolucion de vehiculo o una nota de credito de descuento

-- Eliminar notas de credito
Delete From #Docs Where sw = -1
-- Eliminar registros duplicados, vehiculos vueltos a facturar
Delete From #Docs Where id in (
								Select min (id)
								From #Docs
								Group By id_cot_item_lote
								having count(*) > 1
								)
-- Eliminar registros duplicados, vehiculos vueltos a facturar
Delete From #Docs Where id in (
								Select min (id)
								From #Docs
								Group By id_cot_item_lote
								having count(*) > 1
								)

		  --select * from #Docs	where lote = '9BGEA76C0MB136475'
 select 
 d.id, 
 i.id_cot_item , 
costo=i.costo_und  ,
i.id_cot_pedido_item,
i.cantidad_und
into #Docsacc 
 from #Docs  d
  JOIN dbo.cot_cotizacion_item i
        ON i.id_cot_cotizacion = d.id
   JOIN cot_item_lote l 
   on l.id_cot_item=i.id_cot_item and l.id=i.id_cot_item_lote and l.vin is  null

	  
--validación hojas de negocio para fecha de entrega vh
INSERT @HojasNegocio
(
    id,
    FechaEntrega,
	notas
)
SELECT DISTINCT  
d.id,
       vhe.fecha_modificacion, 
	   cast(vhe.notas as varchar(500))
FROM #Docs d
	JOIN dbo.veh_hn_enc vhe
     ON vhe.id = d.id_veh_hn_enc

WHERE d.sw = 1
      AND vhe.estado = 575
 
--- validacion notas credito 
INSERT @Devoluciones
(
    id,
    factura
)
SELECT DISTINCT 
d.id,
       Factura = CAST(ISNULL(bd.ecu_establecimiento, '') AS VARCHAR(4))
                 + CAST(ISNULL(t3.ecu_emision, '') AS VARCHAR(4)) COLLATE Modern_Spanish_CI_AI + ''
                 + RIGHT('000000000' + CAST(cc3.numero_cotizacion AS VARCHAR(100)), 9)
FROM #Docs d
    LEFT JOIN dbo.v_cot_cotizacion_factura_dev fdev
        ON d.sw = -1
           AND fdev.id_cot_cotizacion = d.id
    LEFT JOIN dbo.cot_cotizacion cc3
        ON cc3.id = fdev.id_cot_cotizacion_factura
    JOIN dbo.cot_tipo t3
        ON t3.id = cc3.id_cot_tipo
    JOIN dbo.cot_bodega bd
        ON bd.id = cc3.id_cot_bodega


  -------- datos accesorios vehiculos 
INSERT @accesoriosvehiculos
(
    id,
    ValorAccesorios,
    costoAccesorios
)
SELECT d.id,
       valoraccesorios = pd.precio_cotizado * pd.cantidad_und,
       costoAccesorios = d.costo * d.cantidad_und
FROM #Docsacc d
    JOIN dbo.cot_pedido_item pd
        ON d.id_cot_pedido_item = pd.id
    JOIN dbo.cot_pedido p
        ON pd.id_cot_pedido = p.id
    JOIN dbo.veh_hn_pedidos vhp
        ON vhp.id_cot_pedido = p.id
WHERE d.id_cot_item <> pd.id_cot_item 


-- DATOS VH    precio lista  descuento   
SELECT DISTINCT 
i.id,
i.id_cot_item,
i.id_cot_item_lote,
i.docref_numero ,
l.vin,
i.id_veh_hn_enc
INTO  #VH 
FROM #Docs i
JOIN cot_item_lote l
ON l.id=i.id_cot_item_lote 
AND  l.id_cot_item=i.id_cot_item
WHERE l.vin IS NOT null

--Flota_Retail


SELECT 
	v.id,
	v.id_cot_item,
	v.id_cot_item_lote,
	i.id_cot_pedido,
	flota=ISNULL(d.descripcion,''),
	dsctoflota=ISNULL(d.porcentaje_descuento,0)
INTO 
	#flota
FROM dbo.veh_hn_pedidos vhp
JOIN #vh v
ON v.id_veh_hn_enc = vhp.id_veh_hn_enc
JOIN dbo.cot_pedido_item i
ON i.id_cot_pedido = vhp.id_cot_pedido
--JOIN dbo.cot_pedido_item_descuentos c
--ON c.id_cot_pedido_item = i.id
JOIN dbo.cot_descuento d
ON d.id = i.id_cot_descuento_prov

SELECT 
v.id,
v.id_cot_item,
v.id_cot_item_lote,
i.precio,
i.max_dcto
INTO #datoslista_dcto
FROM #VH v 
JOIN  cot_item i
ON i.id=v.id_cot_item
						
 INSERT #docco
(
    id,
    id_cot_tipo,
    codcentro,
	cuota_nro
)
SELECT DISTINCT
       aa.Id,
       aa.id_cot_tipo,
       co.descripcion,
	   cuota_nro=0
FROM #Docs aa
    JOIN dbo.con_mov_enc cme
        ON cme.id_origen = aa.Id
           AND cme.id_cot_tipo = aa.id_cot_tipo
           AND cme.numero = aa.numero_cotizacion
    JOIN dbo.con_mov cm
        ON cm.id_con_mov_enc = cme.id
    JOIN dbo.con_cco co
        ON co.id = cm.id_con_cco
WHERE cm.id =
(
    SELECT MIN(cm2.id)
    FROM dbo.con_mov cm2
    WHERE cm.id_con_mov_enc = cm2.id_con_mov_enc
          AND cm2.id_con_cco IS NOT NULL
)


select distinct 
d.id,
id_hn=e.id, 
vf.id_veh_tipo_pago,
c.razon_social
into #financiera 
FROM #Docs d
JOIN veh_hn_enc e
ON e.id=d.id_veh_hn_enc
JOIN dbo.veh_hn_forma_pago vf
ON vf.id_veh_hn_enc = e.id 
join cot_cliente_contacto cc
on cc.id=vf.id_cot_cliente_contacto
join cot_cliente c
on c.id_cot_cliente_contacto=cc.id
where  vf.id_veh_tipo_pago=3

 select 
[AGENCIA_ID]=d.id_cot_bodega
,[NOMBRE_AGENCIA]=cb.descripcion
,[LINEA_ID]=dcc.codcentro
,[NOMBRE_LINEA]=dcc.codcentro
,[FACTURA]=CASE
                       WHEN t.sw = -1 THEN
                           dv.factura
                       ELSE
                           CAST(ISNULL(d.ecu_establecimiento, '') AS VARCHAR(4))
                           + CAST(ISNULL(t.ecu_emision, '') AS VARCHAR(4)) COLLATE Modern_Spanish_CI_AI + ''
                           + RIGHT('000000000' + CAST(d.numero_cotizacion AS VARCHAR(100)), 9)
                   END
,[FEC_FACTURA]= d.fecha
,[FECHA DE VENCIMIENTO]=d.fecha_estimada
,[PERSONA_ID]=cc.nit
,[RAZON_SOCIAL]=cc.razon_social
,[CLASE_CLIENTE]=cp.descripcion
,[VENDEDOR]=u.nombre
,[PRODUCTO_ID]=il.vin
,[NOMBRE_PRODUCTO]=i.descripcion
,RUC_FLOTA = IsNull((
					Select top 1 cliente.nit
					From veh_hn_pedidos hnp
						inner join cot_pedido_item cp on hnp.id_cot_pedido = cp.id_cot_pedido
						inner join cot_pedido_item_descuentos cpi on cp.id = cpi.id_cot_pedido_item 
						inner join cot_descuento descu on cpi.id_cot_descuento = descu.id
						inner join cot_cliente cliente on descu.id_cot_cliente_d = cliente.id
					where hnp.id_veh_hn_enc = d.id_veh_hn_enc
					),'')
,NOMBRE_FLOTA = IsNull((
	Select top 1 cliente.razon_social
	From veh_hn_pedidos hnp
		inner join cot_pedido_item cp on hnp.id_cot_pedido = cp.id_cot_pedido
		inner join cot_pedido_item_descuentos cpi on cp.id = cpi.id_cot_pedido_item 
		inner join cot_descuento descu on cpi.id_cot_descuento = descu.id
		inner join cot_cliente cliente on descu.id_cot_cliente_d = cliente.id
	where hnp.id_veh_hn_enc = d.id_veh_hn_enc
	),'')
,COLOR_EXTERNO = col1.descripcion
,[AÑO DEL VEHICULO]=i.id_veh_ano
,[BODEGA_ID]=cb.id
,[NOMBRE_BODEGA]=cb.descripcion
,[CANTIDAD]=d.cantidad_und
,[COSTO_TOT_TOT]=d.cantidad_und * d.costo
,[PRECIO_UNI]=d.precio_lista
,[PRECIO_BRUTO]=d.cantidad_und * d.precio_lista
,[PORCENTAJE_DESCUENTO]=d.porcentaje_descuento
,[DESCUENTO]=(d.cantidad_und * d.precio_cotizado) * (d.porcentaje_descuento / 100)
,[OTROS_INCLUIDOS]=CASE
                               WHEN d.id_cot_item_lote <> 0 THEN
                                   av.ValorAccesorios
                               ELSE
                                   0
                           END
,[COSTO_ACC_OBLIGA]=CASE
                                WHEN d.id_cot_item_lote <> 0 THEN
                                 av.costoAccesorios
                                ELSE
                                    0
                            END
,[PRECIO_LISTA]=isnull(ld.precio,0)
,[DESCUENTO_MARCA]=isnull(ld.max_dcto,0)
,[FORMA_PAGO]=fp.descripcion
,[FINANCIERA]=fn.razon_social
,[CLIENTE_DE]=case when f.flota is null then  'RETAIL' else 'FLOTA' end 
,[DETALLE]=isnull(cast(d.notas as varchar(500)),'') + '' + isnull(cast(h.notas as varchar(500)),'')
,[PRECIO_NETO]=d.precio_cotizado
,[ABONOS]=abono
,[SALDO]=d.saldo
,[DIAS MORA]=datediff(dd,d.fecha_estimada, getdate())
, ID_FACTURA = d.id
, GRUPO = g.descripcion
, SUBGRUPO = s.descripcion
,[notas_lote]=' '
,[ubicacionvehiculo] = (Select cbu.descripcion 
						from cot_item_lote cil join  cot_bodega_ubicacion cbu on cbu.id = cil.id_cot_bodega_ubicacion 
						where cil.id= d.id_cot_item_lote)
from #docs d 
left join @HojasNegocio h
on h.id=d.id
join cot_bodega cb
on cb.id=d.id_cot_bodega
JOIN dbo.cot_tipo t
        ON t.id = d.id_cot_tipo
    LEFT JOIN dbo.com_orden_concep co
        ON co.id = d.id_com_orden_concep
    left JOIN dbo.cot_cliente cc
        ON cc.id = d.id_cot_cliente
    LEFT JOIN dbo.cot_cliente_Perfil cp
        ON cp.id = cc.id_cot_cliente_perfil
    LEFT JOIN dbo.usuario u
        ON u.id = d.id_usuario_vende
		JOIN dbo.cot_item i
    ON i.id = d.id_cot_item
	 LEFT JOIN dbo.cot_item_lote il
        ON il.id_cot_item = d.id_cot_item
           AND il.id = d.id_cot_item_lote
		   left join veh_color col1 on col1.id=il.id_veh_color
 JOIN dbo.cot_grupo_sub s ON s.id = i.id_cot_grupo_sub
 JOIN dbo.cot_grupo g ON g.id = s.id_cot_grupo
 LEFT JOIN dbo.cot_forma_pago fp ON fp.id = d.id_cot_forma_pago
 LEFT JOIN @Devoluciones dv ON dv.id = d.id
 LEFT JOIN dbo.ecu_tipo_comprobante et ON et.id = t.id_ecu_tipo_comprobante
 LEFT JOIN @accesoriosvehiculos av ON av.id = d.id 
 LEFT JOIN #datoslista_dcto ld ON ld.id_cot_item=d.id_cot_item
  AND ld.id_cot_item_lote=d.id_cot_item_lote
  AND  ld.id=d.id
   LEFT JOIN #flota f
  ON f.id_cot_item=d.id_cot_item
  AND f.id_cot_item_lote=d.id_cot_item_lote
  and f.id=d.id
      LEFT JOIN #docco dcc
        ON dcc.id = d.Id
           AND dcc.id_cot_tipo = d.id_cot_tipo

		  
 	left join  #financiera  fn on fn.id=d.id

	    where h.id is null
		and isnull(cp.descripcion,'0') NOT IN ('CONCESIONARIO','RELACIONADAS')
		--AND il.vin = '8LBETF4W4N0005269'



		
UNION ALL


select 
[AGENCIA_ID]=0
,[NOMBRE_AGENCIA]=(select Agencia from Veh_visor_historia vvh where vvh.chasis = cl.LOTE )
,[LINEA_ID]=''
,[NOMBRE_LINEA]=''
,[FACTURA]=''
,[FEC_FACTURA]= (select fecha_fac from Veh_visor_historia vvh where vvh.chasis = cl.LOTE )
,[FECHA DE VENCIMIENTO]=NULL
,[PERSONA_ID]=C.NIT
,[RAZON_SOCIAL]=C.RAZON_SOCIAL
,[CLASE_CLIENTE]=cp.descripcion
,[VENDEDOR]=(select Vendedor from Veh_visor_historia vvh where vvh.chasis = cl.LOTE )
,[PRODUCTO_ID]=cl.LOTE
,[NOMBRE_PRODUCTO]=ci.descripcion
,RUC_FLOTA = ''
,NOMBRE_FLOTA = ''
,COLOR_EXTERNO = CO.DESCRIPCION
,[AÑO DEL VEHICULO]=ci.id_veh_ano
,[BODEGA_ID]=0
,[NOMBRE_BODEGA]=''
,[CANTIDAD]=0
,[COSTO_TOT_TOT]=0
,[PRECIO_UNI]=0
,[PRECIO_BRUTO]=0
,[PORCENTAJE_DESCUENTO]=0
,[DESCUENTO]=0
,[OTROS_INCLUIDOS]=0
,[COSTO_ACC_OBLIGA]=0
,[PRECIO_LISTA]=0
,[DESCUENTO_MARCA]=0
,[FORMA_PAGO]=''
,[FINANCIERA]=(select Financiera from Veh_visor_historia vvh where vvh.chasis = cl.LOTE )
,[CLIENTE_DE]=''
,[DETALLE]=''
,[PRECIO_NETO]=0 --
,[ABONOS]=0
,[SALDO] = case s.descripcion when 'CHEVROLET' then  (select top 1 sf.saldo from cot_cotizacion cc 
join cot_cliente cl on cl.id = cc.id_cot_cliente
join v_cot_factura_saldo sf on sf.id_cot_cotizacion = cc.id
where cl.nit = C.NIT
and cc.id_cot_tipo in(1493,1420)) else (select top 1 sf.saldo from cot_cotizacion cc 
join cot_cliente cl on cl.id = cc.id_cot_cliente
join v_cot_factura_saldo sf on sf.id_cot_cotizacion = cc.id
where cl.nit = C.NIT
and cc.id_cot_tipo =1497) end 
,[DIAS MORA]=0
, ID_FACTURA = 0
, GRUPO = g.descripcion
, SUBGRUPO = s.descripcion
,cl.notas as notas_lote
,[ubicacionvehiculo] = ' '
from veh_eventos_vin e 
LEFT JOIN veh_eventos2 EV ON EV.ID=E.id_veh_eventos2
left join cot_item_lote cl on cl.id=e.id_cot_item_lote
LEFT JOIN veh_color CO ON CO.ID=CL.ID_VEH_COLOR
left join cot_item ci on ci.id=cl.id_cot_item
left join cot_cliente_contacto cc on cc.id=cl.id_cot_cliente_contacto
left join cot_cliente c on c.id=cc.id_cot_cliente
LEFT JOIN dbo.cot_cliente_Perfil cp ON cp.id = c.id_cot_cliente_perfil
JOIN dbo.cot_grupo_sub s ON s.id = ci.id_cot_grupo_sub
JOIN dbo.cot_grupo g ON g.id = s.id_cot_grupo
WHERE E.id_veh_eventos2 =1 and ci.id_emp in (605) and e.id_cot_item_lote  
not in (select e1.id_cot_item_lote from veh_eventos_vin e1 
        LEFT JOIN veh_eventos2 EV ON EV.ID=E1.id_veh_eventos2
        left join cot_item_lote cl on cl.id=e1.id_cot_item_lote
        LEFT JOIN veh_color CO ON CO.ID=CL.ID_VEH_COLOR
left join cot_item ci on ci.id=cl.id_cot_item
left join cot_cliente_contacto cc on cc.id=cl.id_cot_cliente_contacto
left join cot_cliente c on c.id=cc.id_cot_cliente
WHERE E1.id_veh_eventos2 in(2))



