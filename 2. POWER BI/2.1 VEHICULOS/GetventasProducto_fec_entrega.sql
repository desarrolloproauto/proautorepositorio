USE [dms_smd3]
GO
/****** Object:  StoredProcedure [dbo].[GetventasProducto_fec_entrega]    Script Date: 24/2/2022 23:11:20 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[GetventasProducto_fec_entrega]
	(
		@emp INT,
		@Bod VARCHAR(MAX),
		@fecha DATE,
	    @fecha_fin DATE,
		@SoloInventario INT = 0,
		@soloServicio INT = 0
	)
	AS

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

--- se declara este filtro para el manejo de los item con o sin inventario.
DECLARE @idtipoinventario VARCHAR(10) = ''
SET @idtipoinventario = CASE
                            WHEN @SoloInventario = 0
                                 AND @soloServicio = 0 THEN
                                '0,1,2,3'
                            WHEN @SoloInventario = 1
                                 AND @soloServicio = 0 THEN
                                '1,2,3'
                            WHEN @SoloInventario = 0
                                 AND @soloServicio = 1 THEN
                                '0'
                            ELSE
                                '0,1,2,3'
                        END


--DECLARACION DE TABLAS
---------------------------------TEMPORALES MEMORIA
DECLARE @tipoinventario AS TABLE
(
    id INT
)

DECLARE @Bodega AS TABLE
(
    id INT,
    descripcion VARCHAR(200),
    ecu_establecimiento VARCHAR(6)
)

DECLARE @Devoluciones AS TABLE
(
    id INT,
    factura VARCHAR(20)
)
DECLARE @HojasNegocio AS TABLE
(
    id INT,
    FechaEntrega DATETIME
)

DECLARE @accesoriosvehiculos AS TABLE
(
    id INT,
    ValorAccesorios DECIMAL(18, 2),
    costoAccesorios DECIMAL(18, 2)
)
DECLARE @FacOT AS TABLE
(
    id INT,
    id_ot INT
)
DECLARE @FacConDev AS TABLE
(
    id INT,
    Tiene char(2)
)

-------------------------------TEMPORALES DISCO
CREATE TABLE #docco
(
    id INT,
    id_cot_tipo INT,
    codcentro VARCHAR(100),
	cuota_nro int
)



CREATE TABLE #Docs
(
    id INT,
    id_cot_tipo INT,
    id_cot_bodega INT,
    id_cot_cliente INT,
	id_cot_cliente_contacto INT,
    numero_cotizacion INT,
    fecha DATE,
    notas VARCHAR(2000),
    id_cot_item INT,
    id_cot_item_lote INT,
    cantidad_und DECIMAL(18, 2),
	tiempo DECIMAL(18,2),
    precio_lista DECIMAL(18, 2),
    precio_cotizado DECIMAL(18, 2),
    costo DECIMAL(18, 2),
    porcentaje_descuento DECIMAL(18, 2),
    porcentaje_descuento2 DECIMAL(18, 2),
    porcentaje_iva DECIMAL(18, 2),
    DesBod VARCHAR(300) null,
    id_com_orden_concepto INT,
    ecu_establecimiento VARCHAR(4),
    id_usuario_ven INT,
    id_forma_pago INT,
    docref_numero VARCHAR(30),
    docref_tipo VARCHAR(20),
    sw INT,
    saldo DECIMAL(18, 2),
    id_cot_pedido_item INT,
    ot INT,
	id_veh_hn_enc iNT, 
	id_cot_cotizacion_item int,
	total_total money,
	facturar_a char(2) ,
	tipo_operacion char(2) , 
	id_cot_item_vhtal  int ,
	id_cot_cotizacion_sig int ,
	id_operario int,
	id_usuario_fac int,  ---GMB
	total_descuento DECIMAL(18, 2)

)



create table  #flota
(
id int, 
id_cot_item int,
id_cot_item_lote int,
id_hn int,
id_flota int,
flota varchar(100),
dsctoflota decimal(18,2),
Nit_flota varchar(100)  ,
Nombreflota	varchar(200) ,
tiponegocio	varchar(100)

)

create table  #financiera
(
id int, 
id_cot_item int,
id_cot_item_lote int,
id_hn int,
financiera varchar(200),
valor money
)

create table  #financiera_CC -- Tabla para los creditos de Consumo
(
id int, 
id_cot_item int,
id_cot_item_lote int,
id_hn int,
financiera varchar(200),
valor money
)

create table  #forma_pago
(
id_cot_cotizacion int, 
forma VARCHAR(50),
valor money

)


------------------FILTROS INICIALES

INSERT @tipoinventario
(
    id
)
SELECT CAST(f.val AS INT)
FROM dbo.fnSplit(@idtipoinventario, ',') f


------------------------------------------------------------------------------------

   


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
	where id_emp=605
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



INSERT #Docs
(
    id,
    id_cot_tipo,
    id_cot_bodega,
    id_cot_cliente,
    numero_cotizacion,
    fecha,
    notas,
    id_cot_item,
    id_cot_item_lote,
    cantidad_und,
	tiempo,
    precio_lista,
    precio_cotizado,
    costo,
    porcentaje_descuento,
    porcentaje_descuento2,
    porcentaje_iva,
    DesBod,
    id_com_orden_concepto,
    ecu_establecimiento,
    id_usuario_ven,
    id_forma_pago,
    sw,
    saldo,
    id_cot_pedido_item, 
	docref_tipo, 
	docref_numero,
	id_veh_hn_enc ,
	id_cot_cliente_contacto,
	id_cot_cotizacion_item ,
	total_total,
	facturar_a,
	tipo_operacion ,
	id_cot_item_vhtal,
	id_cot_cotizacion_sig,
	id_operario,
	id_usuario_fac,   --gmb
	total_descuento
)
SELECT
c.id,
       c.id_cot_tipo,
       c.id_cot_bodega,
       c.id_cot_cliente,
       c.numero_cotizacion,
       c.fecha,
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
      -- b.descripcion,
       null,
	   c.id_com_orden_concep,
       b.ecu_establecimiento,
       c.id_usuario_vende,
       c.id_cot_forma_pago,
       t.sw,
       saldo = c.total_total - ISNULL(s.valor_aplicado, 0),
       i.id_cot_pedido_item, 
	   c.docref_tipo, 
	   c.docref_numero,
	   c.id_veh_hn_enc,
	   c.id_cot_cliente_contacto ,
	   id_cot_cotizacion_item=i.id,
	   c.total_total,
	   i.facturar_a,
	   i.tipo_operacion	,
	   c.id_cot_item_lote ,
	   c.id_cot_cotizacion_sig,
	   i.id_operario,
	   c.id_usuario, --gmb
	   c.total_descuento
FROM dbo.cot_tipo t
JOIN  dbo.cot_cotizacion c 
   ON t.id = c.id_cot_tipo and c.id_emp = 605	  -- AND C.ID=39681
      AND t.sw IN ( 1, -1 )	and isnull(c.anulada,0) <>4 
--	and  CAST(c.fecha AS DATE) BETWEEN @fecIni AND @fecFin
JOIN @Bodega b ON b.id = c.id_cot_bodega     
JOIN dbo.cot_cotizacion_item i ON i.id_cot_cotizacion = c.id
LEFT JOIN dbo.v_cot_factura_saldo s ON s.id_cot_cotizacion = c.id
where t.es_remision is  null and t.es_traslado is null      


			


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
    JOIN dbo.v_cot_cotizacion_factura_dev fdev
        ON d.sw = -1
           AND fdev.id_cot_cotizacion = d.id
     JOIN dbo.cot_cotizacion cc3
        ON cc3.id = fdev.id_cot_cotizacion_factura
    JOIN dbo.cot_tipo t3
        ON t3.id = cc3.id_cot_tipo
    JOIN dbo.cot_bodega bd
        ON bd.id = cc3.id_cot_bodega

--Validacion Fac con devolución
insert @FacConDev
(id, tiene)
select distinct 
d.id, 
tipo= case when tv.tiene_devol=1 then 'Si' else 'No' end
from #Docs d
JOIN dbo.v_cot_tiene_devolucion tv ON tv.id_cot_cotizacion = d.id
 where d.sw=1





  
--validación hojas de negocio para fecha de entrega vh
INSERT @HojasNegocio
(
    id,
    FechaEntrega
)
SELECT   
d.id,
       min(vhe.fecha_hora) fecha_hora
FROM #Docs d
JOIN dbo.cot_auditoria vhe
        ON vhe.id_id = d.id_veh_hn_enc
WHERE d.sw = 1
      AND vhe.que  like 'E:575%'
	  and vhe.id_emp = 605 ---GMB: para que tome de la auditoria el estado Entregado el VH
	  group by   d.id              

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
FROM #Docs d
    JOIN dbo.cot_pedido_item pd
        ON d.id_cot_pedido_item = pd.id
    JOIN dbo.cot_pedido p
        ON pd.id_cot_pedido = p.id
    JOIN dbo.veh_hn_pedidos vhp
        ON vhp.id_cot_pedido = p.id
WHERE d.id_cot_item <> pd.id_cot_item

----------------- validacion Orden de taller

INSERT @FacOT
(
    id,
    id_ot
)
SELECT DISTINCT
       d.id,
       id_ot = o.id_cot_cotizacion_sig
FROM #Docs d
    JOIN dbo.v_tal_ya_fue_facturado o
        ON o.id_cot_cotizacion = d.id

--------------------

		
	
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
WHERE i.sw=1 and l.vin IS NOT null
---GMAH 12/01/2021
UNION ALL
SELECT DISTINCT 
i.id,
i.id_cot_item,
i.id_cot_item_lote,
i.docref_numero ,
l.vin,
id_veh_hn_enc=cf.id_veh_hn_enc 
FROM #Docs i
LEFT JOIN dbo.v_cot_cotizacion_factura_dev fdev 
on fdev.id_cot_cotizacion = i.id
join cot_cotizacion cf 
on cf.id=id_cot_cotizacion_factura
JOIN cot_item_lote l
ON l.id=i.id_cot_item_lote 
AND  l.id_cot_item=i.id_cot_item
WHERE i.sw=-1 and l.vin IS NOT null

update d set id_veh_hn_enc=v.id_veh_hn_enc
from #Docs d
join #VH v
on d.id=v.id 
and d.id_cot_item=v.id_cot_item
and d.id_cot_item_lote=v.id_cot_item_lote
where d.sw=-1
---/GMAH 12/01/2021


SELECT 
v.id,
v.id_cot_item,
v.id_cot_item_lote,
i.precio,
i.max_dcto,
i.id_veh_ano   ---GMB: Año VH nuevos
INTO #datoslista_dcto
FROM #VH v 
JOIN  cot_item i
ON i.id=v.id_cot_item
								
---- DATOS COMPRA VH
SELECT 
vh.id,
vh.id_cot_item,
vh.id_cot_item_lote,
fechacompra=c.fecha,
facproveedor=RIGHT('000000' + cast(c.numero_cotizacion_original as varchar),6) + '' +RIGHT('000000000' + CAST(c.docref_numero AS VARCHAR), 9),
id_compra=c.id, 
proveedor=cc.razon_social
into #compras
from #VH vh
JOIN cot_cotizacion_item ci
on ci.id_cot_item=vh.id_cot_item
and ci.id_cot_item_lote=vh.id_cot_item_lote
JOIN cot_cotizacion c
on c.id=ci.id_cot_cotizacion
JOIN cot_tipo t
on t.id=c.id_cot_tipo
and t.sw=4
join cot_cliente cc
on cc.id=c.id_cot_cliente
LEFT JOIN dbo.v_cot_cotizacion_factura_dev fdev on fdev.id_cot_cotizacion_factura = c.id --GMAH 08042021
WHERE fdev.id_cot_cotizacion_factura IS NULL --GMAH 08042021


-----------------complementos GAC

SELECT
d.id,
id_cot_item_lote=max(case when vin is null then null else a.id_cot_item_lote end )	,
totalsub=sum(d.cantidad_und*d.precio_cotizado)
INTO #Compfact
FROM #VH a
JOIN #Docs  d
ON d.id=a.id
join cot_item i
on i.id=d.id_cot_item
join cot_grupo_sub s
on s.id=i.id_cot_grupo_sub
join cot_grupo cg
on cg.id=s.id_cot_grupo 
where cg.id in (1324)
group by d.id

-----------------------------------------------

----ACCESORIOS FACTURA 

SELECT
d.id,
id_cot_item_lote=max(case when vin is null then null else a.id_cot_item_lote end )	,
totalsub=sum(d.cantidad_und*d.precio_cotizado)
INTO #Accfact
FROM #VH a
JOIN #Docs  d
ON d.id=a.id
join cot_item i
on i.id=d.id_cot_item
join cot_grupo_sub s
on s.id=i.id_cot_grupo_sub
join cot_grupo cg
on cg.id=s.id_cot_grupo 
where cg.id not in (1324,1327)
group by d.id

 ----Dispositivos FACTURA 

SELECT
d.id,
id_cot_item_lote=max(case when vin is null then null else a.id_cot_item_lote end )	,
totalsub=sum(d.cantidad_und*d.precio_cotizado) 
INTO #Dispfact
FROM #VH a
JOIN #Docs  d
ON d.id=a.id
join cot_item i
on i.id=d.id_cot_item
join cot_grupo_sub s
on s.id=i.id_cot_grupo_sub
join cot_grupo cg
on cg.id=s.id_cot_grupo 
where cg.descripcion like '%DISPOSITIVOS%'
group by d.id

--select * from #Dispfact 	
--Flota_Retail
--- validacion de flota

INSERT 	#flota
(
id,
id_cot_item,
id_cot_item_lote,
id_hn,
id_flota,
flota,
dsctoflota,
Nit_flota,
Nombreflota,
tiponegocio
)
select   	
v.id,
v.id_cot_item,
v.id_cot_item_lote,
id_hn=e.id,
id_flota = MAX(dcto.id_cot_descuento), 
flota = MAX(lo.descripcion),
porce_flota = MAX(dcto.porcentaje),
Nit_Flota=c.nit,
Nombreflota=c.razon_social,
TipoNegocio=max(tn.descripcion)
from	dbo.veh_hn_pedidos vhp
JOIN #vh v	 ON v.id_veh_hn_enc = vhp.id_veh_hn_enc
join	dbo.cot_pedido p on p.id=vhp.id_cot_pedido
JOIN    dbo.cot_pedido_item it ON it.id_cot_pedido = p.id 
 JOIN dbo.veh_hn_enc e ON e.id = vhp.id_veh_hn_enc 
 JOIN dbo.cot_pedido_item_descuentos dcto ON dcto.id_cot_pedido_item = it.id
 JOIN dbo.cot_descuento lo ON lo.id = dcto.id_cot_descuento AND ISNULL(lo.es_flota,0) = 1
 --and  lo.id=it.id_cot_descuento_prov
 JOIN cot_cliente c on c.id=lo.id_cot_cliente_d
 left join veh_hn_tipo_negocio tn
 on tn.id=e.id_veh_hn_tipo_negocio
where lo.es_flota=1
GROUP BY vhp.id_cot_pedido,e.id,c.nit,c.razon_social  ,
v.id,
v.id_cot_item,
v.id_cot_item_lote,
e.id





select distinct 
v.id,
v.id_cot_item,
v.id_cot_item_lote,
id_hn=e.id,
aseguradora=cc.nombre,
Dispositivo=vcv.campo_5	,
TipoNegocio=(tn.descripcion)

into #datosHN
from	dbo.veh_hn_pedidos vhp
JOIN #vh v	 ON v.id_veh_hn_enc = vhp.id_veh_hn_enc
join	dbo.cot_pedido p on p.id=vhp.id_cot_pedido
JOIN    dbo.cot_pedido_item it ON it.id_cot_pedido = p.id 
 JOIN dbo.veh_hn_enc e ON e.id = vhp.id_veh_hn_enc 
left join cot_cliente_contacto cc
on cc.id=e.id_cot_cliente_contacto_aseguradora
left JOIN v_campos_varios vcv
ON vcv.id_veh_hn_enc=e.id and id_veh_estado is null
 left join veh_hn_tipo_negocio tn
 on tn.id=e.id_veh_hn_tipo_negocio





---se hace esto por control, y evitar duplucidad en flota por datos en cot_pedido_item_descuentos
select id,id_cot_item,id_cot_item_lote, id_hn,q=count(id)
into #flotadu 
from #flota
group by id,id_cot_item,id_cot_item_lote, id_hn
having count(id)>1

delete 	 a
from #flota a
join #flotadu b
on  a.id=b.id and a.id_cot_item=b.id_cot_item 
and a.id_cot_item_lote=b.id_cot_item_lote 
and  a.id_hn=b.id_hn
 --------------------------------------------------

INSERT 	#flota
(
id,
id_cot_item,
id_cot_item_lote,
id_hn,
id_flota,
flota,
dsctoflota,
Nit_flota
)
select   	
v.id,
v.id_cot_item,
v.id_cot_item_lote,
id_hn=e.id,
id_flota = MAX(dcto.id_cot_descuento), 
flota = MAX(lo.descripcion),
porce_flota = MAX(dcto.porcentaje),
Nit_Flot=c.nit+ ' - '+c.razon_social
		    
from	dbo.veh_hn_pedidos vhp
JOIN #vh v	 ON v.id_veh_hn_enc = vhp.id_veh_hn_enc
join	dbo.cot_pedido p on p.id=vhp.id_cot_pedido
JOIN    dbo.cot_pedido_item it ON it.id_cot_pedido = p.id 
 JOIN dbo.veh_hn_enc e ON e.id = vhp.id_veh_hn_enc 
 JOIN dbo.cot_pedido_item_descuentos dcto ON dcto.id_cot_pedido_item = it.id
 JOIN dbo.cot_descuento lo ON lo.id = dcto.id_cot_descuento AND ISNULL(lo.es_flota,0) = 1
 and  lo.id=it.id_cot_descuento_prov
 JOIN cot_cliente c on c.id=lo.id_cot_cliente_d
 join #flotadu fl on fl.id=v.id and fl.id_cot_item=v.id_cot_item and fl.id_cot_item_lote=v.id_cot_item_lote
 and  fl.id_hn=e.id
where lo.es_flota=1
GROUP BY vhp.id_cot_pedido,e.id,c.nit,c.razon_social  ,
v.id,
v.id_cot_item,
v.id_cot_item_lote,
e.id

----------tabla temporal para incluir los tipos de pago -GMB-----CSC------

INSERT 	#forma_pago
(
id_cot_cotizacion,
forma,
valor
)
Select y.id_cot_cotizacion,max(y.forma),max(valor)
 from 
(select			c.id_cot_cotizacion,
				forma=f.descripcion,
				c.valor
		from	cot_recibo_pago c
		join	cot_tipo_pago f on f.id=c.id_cot_tipo_pago
		left join tes_bancos t on t.id=c.id_tes_bancos
		left join tes_bancos t2 on t2.id=c.id_tes_bancos_consig

		UNION ALL

		--pegamos los recibos de caja posibles de las ventas de contado de la Rn#173, activo=2, usado por ecuador
		select	cru.id_cot_cotizacion,
				forma=f.descripcion,
				c.valor
		from	cot_recibo_cruce cru
		JOIN cot_recibo_cruce cru2 ON cru2.id_cot_recibo_cruce_enc=cru.id_cot_recibo_cruce_enc AND cru2.id_cot_recibo IS NOT null
		JOIN cot_recibo_pago c ON c.id_cot_recibo=cru2.id_cot_recibo
		join	cot_tipo_pago f on f.id=c.id_cot_tipo_pago
		left join tes_bancos t on t.id=c.id_tes_bancos
		left join tes_bancos t2 on t2.id=c.id_tes_bancos_consig) y
		group by y.id_cot_cotizacion				 
----------------------

SELECT DISTINCT 
d.id,
idnota=n.id, 
n.total_sub
INTO #NotaRebate
FROM cot_notas_deb_cre n
JOIN #Docs d
ON cast(d.id AS varchar)=n.docref_numero	
where n.id_emp=605 and n.anulada is null



  	 
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
-----

-----------------------------FINANCIERA
INSERT #financiera
(
    id,
    id_cot_item,
    id_cot_item_lote,
    id_hn,
    financiera,
	valor
)


SELECT
v.id,
v.id_cot_item,
v.id_cot_item_lote,
id_hn=v.id_veh_hn_enc	,
financiera=  c.razon_social	,
valor=fp.valor
FROM #vh v
JOIN veh_hn_forma_pago fp
ON fp.id_veh_hn_enc = v.id_veh_hn_enc	
JOIN dbo.cot_cliente_contacto cc
ON cc.id = fp.id_cot_cliente_contacto
JOIN dbo.cot_cliente c
ON c.id = cc.id_cot_cliente
WHERE fp.id_veh_tipo_pago=3

-----------------------------FINANCIERA CREDITO DE CONSUMO
INSERT #financiera_CC
(
    id,
    id_cot_item,
    id_cot_item_lote,
    id_hn,
    financiera,
	valor
)


SELECT
v.id,
v.id_cot_item,
v.id_cot_item_lote,
id_hn=v.id_veh_hn_enc	,
financiera=  c.razon_social	,
valor=fp.valor
FROM #vh v
JOIN veh_hn_forma_pago fp
ON fp.id_veh_hn_enc = v.id_veh_hn_enc	
JOIN dbo.cot_cliente_contacto cc
ON cc.id = fp.id_cot_cliente_contacto
JOIN dbo.cot_cliente c
ON c.id = cc.id_cot_cliente
WHERE fp.id_veh_tipo_pago=7



 ------------------ vh taller  para traer la linea
 select distinct 
 d.id,
 placa=i.placa,
 LineaTaller=ct.descripcion,
 id_ot=d.id_cot_cotizacion_sig,
 marca=isnull(cv.campo_11,''), 
 modelo=isnull(cv.campo_12,''),
 año=isnull(cv.campo_13,''),
 i.vin,
 i.motor ,
 km=coo.km
 into  #vhtaller
 from #Docs	d
 join cot_cotizacion coo
 on coo.id=d.id_cot_cotizacion_sig
 join cot_item_lote i
on i.id=d.id_cot_item_vhtal
join cot_item ic
on ic.id=i.id_cot_item
LEFT JOIN cot_item_talla ct
on ct.id=ic.id_cot_item_talla
LEFT JOIN v_campos_varios cv
on cv.id_cot_item_lote=i.id 
where d.sw in (1)
UNION ALL
select DISTINCT 
 d.id, 
 placa=i.placa, 
 LineaTaller=ct.descripcion,
 id_ot=cc.id_cot_cotizacion_sig	,
  marca=isnull(cv.campo_11,''), 
 modelo=isnull(cv.campo_12,''),
 [año]=isnull(cv.campo_13,''),
  i.vin,
 i.motor ,
  km=coo.km

from #Docs d
JOIN dbo.v_cot_cotizacion_factura_dev fdev 
ON fdev.id_cot_cotizacion = d.id
join cot_cotizacion cc
on cc.id= fdev.id_cot_cotizacion_factura
 join cot_item_lote i
on i.id=cc.id_cot_item_lote
join cot_item ic
on ic.id=i.id_cot_item
LEFT join cot_item_talla ct
on ct.id=ic.id_cot_item_talla
LEFT JOIN v_campos_varios cv
on cv.id_cot_item_lote=i.id
join cot_cotizacion coo
 on coo.id=d.id_cot_cotizacion_sig
where d.sw in (-1)

-----

-- ultima compras 
SELECT d.id_cot_item,
       d.id_cot_item_lote,
       ultima_venta = MAX(   CASE
                                 WHEN t.sw IN ( 1 ) THEN
                             (c.fecha)
                                 ELSE
                                     NULL
                             END
                         ),
       ultima_Dev_venta = MAX(   CASE
                                 WHEN t.sw IN ( -1 ) THEN
                             (c.fecha)
                                 ELSE
                                     NULL
                             END
                         ),
       ultima_compra = MAX(   CASE
                                  WHEN t.sw IN ( 4 ) THEN
                              (c.fecha)
                                  ELSE
                                      NULL
                              END
                          ),
       ultima_entrada = MAX(   CASE
                                   WHEN t.sw IN ( 12 ) THEN
                               (c.fecha)
                                   ELSE
                                       NULL
                               END
                           )
INTO #ultimasfechas
FROM dbo.cot_cotizacion_item d
    JOIN #VH ii
        ON ii.id_cot_item = d.id_cot_item
           AND ii.id_cot_item_lote = d.id_cot_item_lote
    JOIN dbo.cot_cotizacion c
        ON d.id_cot_cotizacion = c.id
    JOIN dbo.cot_tipo t
        ON c.id_cot_tipo = t.id
    LEFT JOIN dbo.cot_item_lote l
        ON l.id = d.id_cot_item_lote
           AND l.id_cot_item = d.id_cot_item
WHERE ISNULL(c.anulada, 0) <> 4
      AND t.id_emp = 605
      AND t.sw IN ( 1, 4, 12,-1 )
GROUP BY d.id_cot_item,
         d.id_cot_item_lote



-------------------------------------------------------------------


SELECT
LineaNegocio=
case
when g.descripcion + ' ' + s.descripcion='VEHICULOS CHEVROLET' then 'VEHICULOS'
when g.descripcion + ' ' + s.descripcion='VEHICULOS GAC' then 'VEHICULOS'
when g.descripcion + ' ' + s.descripcion='KIT MANDATORIO GAC' then 'VEHICULOS'
when g.descripcion + ' ' + s.descripcion='VEHICULOS VOLKSWAGEN' then 'VEHICULOS'
when g.descripcion + ' ' + s.descripcion='VEHICULOS MULTIMARCA' then 'VEHICULOS'
when g.descripcion + ' ' + s.descripcion='VENTAS NETAS CHEVROLET-VEHICULOS' then 'VEHICULOS'
when g.descripcion + ' ' + s.descripcion='DEVOLUCION EN VENTAS CHEVROLET-VEH LIV RETAIL' then 'VEHICULOS'
when g.descripcion + ' ' + s.descripcion='DEVOLUCION EN VENTAS CHEVROLET-VEH PESADOS RETAIL' then 'VEHICULOS'
when g.descripcion + ' ' + s.descripcion='DEVOLUCION EN VENTAS CHEVROLET-VEH PESADOS FLOTAS' then 'VEHICULOS'
when g.descripcion + ' ' + s.descripcion='DESCUENTO EN VENTAS CHEVROLET VEH LIV RETAIL' then 'VEHICULOS'
when g.descripcion + ' ' + s.descripcion='DESCUENTO EN VENTAS CHEVROLET VEH LIV FLOTAS' then 'VEHICULOS'
when g.descripcion + ' ' + s.descripcion='DESCUENTO EN VENTAS CHEVROLET VEH PES FLOTAS' then 'VEHICULOS'
when g.descripcion + ' ' + s.descripcion='DESCUENTO EN VENTAS GAC-VEHICULOS' then 'VEHICULOS'
when g.descripcion + ' ' + s.descripcion='DESCUENTO EN VENTAS VOLKSWAGEN-VEHICULOS' then 'VEHICULOS'
when g.descripcion + ' ' + s.descripcion='DESCUENTO EN VENTAS VOLKSWAGEN-VEHICULOS RETAIL' then 'VEHICULOS'
when g.descripcion + ' ' + s.descripcion='REPUESTOS CHEVROLET' then 'REPUESTOS'
when g.descripcion + ' ' + s.descripcion='REPUESTOS VOLKSWAGEN' then 'REPUESTOS'
when g.descripcion + ' ' + s.descripcion='REPUESTOS GAC' then 'REPUESTOS'
when g.descripcion + ' ' + s.descripcion='DEVOLUCION EN VENTAS CHEVROLET-REPUESTOS' then 'REPUESTOS'
when g.descripcion + ' ' + s.descripcion='DEVOLUCION EN VENTAS VW-REPUESTOS' then 'REPUESTOS'
when g.descripcion + ' ' + s.descripcion='TALLER CHEVROLET' then 'TALLER'
when g.descripcion + ' ' + s.descripcion='TALLER GAC' then 'TALLER'
when g.descripcion + ' ' + s.descripcion='TALLER VOLKSWAGEN' then 'TALLER'
when g.descripcion + ' ' + s.descripcion='TALLER MULTIMARCA' then 'TALLER'
when g.descripcion + ' ' + s.descripcion='DEVOLUCION EN VENTAS CHEVROLET-TALLERES' then 'TALLER'
when g.descripcion + ' ' + s.descripcion='DEVOLUCION EN VENTAS GAC-TALLERES' then 'TALLER'
when g.descripcion + ' ' + s.descripcion='DESCUENTO EN VENTAS VOLKSWAGEN-TALLER' then 'TALLER'
when g.descripcion + ' ' + s.descripcion='DESCUENTO EN VENTAS CHEVROLET-TALLER' then 'TALLER'
when g.descripcion + ' ' + s.descripcion='VENTAS NETAS CHEVROLET-TALLER' then 'TALLER'
when g.descripcion + ' ' + s.descripcion='REPUESTOS MULTIMARCA' then 'REPUESTOS'
when g.descripcion + ' ' + s.descripcion='VENTAS NETAS CHEVROLET-REPUESTOS' then 'REPUESTOS'
when g.descripcion + ' ' + s.descripcion='DESCUENTO EN VENTAS CHEVROLET-REPUESTOS' then 'REPUESTOS'
when g.descripcion + ' ' + s.descripcion='ACCESORIOS CHEVROLET' then 'ACCESORIOS'
when g.descripcion + ' ' + s.descripcion='ACCESORIOS MULTIMARCA' then 'ACCESORIOS'
when g.descripcion + ' ' + s.descripcion='ACCESORIOS VOLKSWAGEN' then 'ACCESORIOS'
when g.descripcion + ' ' + s.descripcion='ACCESORIOS GAC' then 'ACCESORIOS'
when g.descripcion + ' ' + s.descripcion='DEVOLUCION EN VENTAS CHEVROLET-DISPOSITIVOS' then 'DISPOSITIVOS'
when g.descripcion + ' ' + s.descripcion='DISPOSITIVOS CHEVROLET' then 'DISPOSITIVOS'
when g.descripcion + ' ' + s.descripcion='DISPOSITIVOS GAC' then 'DISPOSITIVOS'
when g.descripcion + ' ' + s.descripcion='DISPOSITIVOS VOLKSWAGEN' then 'DISPOSITIVOS'
when g.descripcion + ' ' + s.descripcion='DEVOLUCION EN VENTAS CHEVROLET-ACCESORIOS' then 'ACCESORIOS'
when g.descripcion + ' ' + s.descripcion='TRABAJOS OTROS TALLERES CHEVROLET' then 'TOT'
when g.descripcion + ' ' + s.descripcion='TRABAJOS OTROS TALLERES MULTIMARCA' then 'TOT' --- GMB
when g.descripcion + ' ' + s.descripcion='TRABAJOS OTROS TALLERES VOLKSWAGEN' then 'TOT' --- GMB
when g.descripcion + ' ' + s.descripcion='TRABAJOS OTROS TALLERES GAC' then 'TOT' --- GMB
when g.descripcion + ' ' + s.descripcion='OTROS INGRESOS COMISIONES' then 'ITEMS CONTABLES'
when g.descripcion + ' ' + s.descripcion='OTROS INGRESOS COMISIONES USADOS' then 'ITEMS CONTABLES'
when g.descripcion + ' ' + s.descripcion='OTROS INGRESOS OTROS INGRESOS' then 'ITEMS CONTABLES'
when g.descripcion + ' ' + s.descripcion='COMPRAS ADMINISTRATIVAS ACTIVO CORRIENTE' then 'ITEMS CONTABLES'
when g.descripcion + ' ' + s.descripcion='OTROS INGRESOS SERVICIOS ADM.GESTION Y LOGISTICA' then 'ITEMS CONTABLES'
when g.descripcion + ' ' + s.descripcion='OTROS INGRESOS POLITICA COMERCIAL VEH' then 'ITEMS CONTABLES'
when g.descripcion + ' ' + s.descripcion='OTROS INGRESOS REBATES' then 'ITEMS CONTABLES'
when g.descripcion + ' ' + s.descripcion='OTROS INGRESOS POLITICA COMERCIAL POSVENTA' then 'ITEMS CONTABLES'
when g.descripcion + ' ' + s.descripcion='ACTIVOS CXC REFINANCIAMIENTO' then 'ITEMS CONTABLES'
when g.descripcion + ' ' + s.descripcion='COMPRAS ADMINISTRATIVAS ACTIVO FIJO' then 'ITEMS CONTABLES'
when g.descripcion + ' ' + s.descripcion='MERCANCIAS VARIAS MULTIMARCA-MOTOS' then 'VEHICULOS'

end 
,

	agencia=d.ecu_establecimiento,
	[punto emision]=t.ecu_emision,
	Bodega=b.descripcion,
	trx_inv_id=t.descripcion,
	nombre_transaccion=t.descripcion,
	numero=d.numero_cotizacion,
	int_tipo_transaccion=d.id_com_orden_concepto,
	sw=t.sw,
	int_tributable=et.descripcion,
	[Centro Costos]=dcc.codcentro,
	--nombre_linea=dcc.codcentro,
	LineaMaestro=isnull(case when isnull(tl.descripcion,'')='' then  vt.LineaTaller else  tl.descripcion end ,''),
	--[Linea Vh Taller]
	id=d.id,
	comprobante=CAST(ISNULL(d.ecu_establecimiento,'') AS VARCHAR(4)) + CAST(ISNULL(t.ecu_emision,'') AS VARCHAR(4)) COLLATE modern_spanish_ci_ai + '' + RIGHT('000000000' + CAST(d.numero_cotizacion AS VARCHAR(100)),9),
	factura=CASE
			WHEN t.sw = -1
			THEN dv.factura ELSE CAST(ISNULL(d.ecu_establecimiento,'') AS VARCHAR(4)) + CAST(ISNULL(t.ecu_emision,'') AS VARCHAR(4)) COLLATE modern_spanish_ci_ai + '' + RIGHT('000000000' + CAST(d.numero_cotizacion AS VARCHAR(100)),9)
			END,
	fec_comprobante=d.fecha,
	
	
	descuento_total=(( d.cantidad_und * d.precio_lista ) * d.porcentaje_descuento / 100)- isnull(case g.descripcion when 'VEHICULOS' then (select sum(total_sub) from #NotaRebate where id = d.id) else 0 end,0),
	base_iva=CASE
			 WHEN d.porcentaje_iva <> 0
			 THEN d.cantidad_und * d.precio_cotizado ELSE 0
			 END,
	porcentaje_iva=d.porcentaje_iva,
	iva=CASE
		WHEN d.porcentaje_iva <> 0
		THEN d.cantidad_und * d.precio_cotizado ELSE 0
		END * d.porcentaje_iva / 100,
	ice='',
	[total]=(case when d.cantidad_und=0 then 1 else d.cantidad_und end * d.precio_cotizado * ( 1 + d.porcentaje_iva / 100 ))*case when d.sw=1 then 1 else -1 end ,
	[TOTAL_TOTAL]=D.total_total * case when d.sw=1 then 1 else -1 end ,
	persona_id=cc.nit,
	razon_social=cc.razon_social,
	clase_cliente=cp.descripcion,
	vendedor=u.nombre,
	operario=up.nombre,
	[Modelo Año]=  isnull(
	CASE
				WHEN d.id_cot_item_lote = 0
				THEN '' ELSE i.codigo
				END,
				 vt.modelo
				
				),
	[Año Modelo]=isnull(cast(ld.id_veh_ano as varchar(4)),[año]),                                      
	[Marca Taller]=vt.marca,
	producto_id=CASE
				WHEN d.id_cot_item_lote = 0
				THEN i.codigo ELSE il.vin
				END,
	
	[VIN Taller]=vt.modelo,
	[Motor]=isnull(il.motor,vt.motor) ,
	nombre_producto=i.descripcion,
	[Color Vh]=isnull(colv.descripcion,''),
	Grupo=g.descripcion,
	--nombre_bodega=g.descripcion,
	[Subgrupo]=s.descripcion,
	[SubGrupo3]=s3.descripcion,
	[SubGrupo4]=s4.descripcion,
	cantidad=d.cantidad_und,
	[Cantidad Vh]=
	case
when g.descripcion + ' ' + s.descripcion='VEHICULOS CHEVROLET' then d.cantidad_und
when g.descripcion + ' ' + s.descripcion='VEHICULOS GAC' then d.cantidad_und
when g.descripcion + ' ' + s.descripcion='VEHICULOS VOLKSWAGEN' then d.cantidad_und
when g.descripcion + ' ' + s.descripcion='DEVOLUCION EN VENTAS CHEVROLET-VEH LIV RETAIL' then d.cantidad_und
when g.descripcion + ' ' + s.descripcion='DEVOLUCION EN VENTAS CHEVROLET-VEH PESADOS RETAIL' then d.cantidad_und
when g.descripcion + ' ' + s.descripcion='DEVOLUCION EN VENTAS CHEVROLET-VEH PESADOS FLOTAS' then d.cantidad_und
when g.descripcion + ' ' + s.descripcion='DESCUENTO EN VENTAS CHEVROLET VEH LIV RETAIL' then 0
when g.descripcion + ' ' + s.descripcion='DESCUENTO EN VENTAS VOLKSWAGEN-VEHICULOS' then 0
end, 
	
	tiempo=case when d.tiempo<0 then 0 else d.tiempo end,
	costo_tot_tot=d.cantidad_und * d.costo,
	precio_uni=d.precio_lista *case when d.sw=1 then 1 else -1 end,
	precio_bruto=(d.cantidad_und * d.precio_lista)+ISNULL(compf.totalsub,0) * case when d.sw=1 then 1 else -1 end,
	porcentaje_descuento=d.porcentaje_descuento,
	descuento=( d.cantidad_und * d.precio_lista ) * d.porcentaje_descuento / 100,
	precio_neto=(abs(d.precio_cotizado) *abs(case when d.cantidad_und=0 then 1 else d.cantidad_und end ))* case when d.sw=1 then 1 else -1 end  ,
	--otros_incluidos=CASE
	--				WHEN d.id_cot_item_lote <> 0
	--				THEN av.valoraccesorios ELSE 0
	--				END,
	[OTROS_INCLUIDOS]=ISNULL(af.totalsub,0)-ISNULL(df.totalsub,0) +(select  isnull(sum(cci.precio_cotizado*cci.cantidad),0) from cot_cotizacion cco 
												join cot_cotizacion_item cci on cci.id_cot_cotizacion = cco.id
												join cot_item it on it.id = cci.id_cot_item
												join cot_grupo_sub cgs on cgs.id = it.id_cot_grupo_sub
												join cot_grupo cg on cg.id = cgs.id_cot_grupo
												where cco.id_cot_item_lote =d.id_cot_item_lote and it.maneja_stock =2 and cg.id in (1322,1321) and isnull(cci.tipo_operacion,'R') not in ('M','L')
												and not exists (select 1 from v_cot_cotizacion_item_dev2 d2 
															  where d2.id_cot_cotizacion_item =cci.id))-
												isnull((select valor from cot_item_cam where id_cot_item_cam_def = 1526 and  id_veh_hn_enc = d.id_veh_hn_enc),0)
												,
	costo_acc_obliga=CASE
					 WHEN d.id_cot_item_lote <> 0
					 THEN av.costoaccesorios ELSE 0
					 END,
	precio_lista=ISNULL(ld.precio,0),
	descuento_marca=ISNULL(ld.max_dcto,0),
	forma_pago=fp.descripcion,
	flota_Nit=ISNULL(f.Nit_Flota,''),
	flota_Nombre=isnull(f.Nombreflota,''),
	TieneDevolucion=case when dev.id_cot_cotizacion_item is not null then 'Si' else 'No' end ,
	 dev.id_cot_cotizacion_item ,
	detalle=dbo.RTF2Text(d.notas),  ---d.notas,
	Dias_entregados = datediff(day,d.fecha,vh.fechaentrega),
	fec_entrega=vh.fechaentrega,
	[Placa]=isnull(il.placa,vt.placa),
	saldo=d.saldo,
	[Orden Taller]=vt.id_ot,--ot.id_ot,
    case g.descripcion when 'VEHICULOS' then (select sum(total_sub) from #NotaRebate where id = d.id) else 0 end as rebate, -- GMB para que solo salga el valor de rabate en VH
	--ISNULL(nr.total_sub,0) 
	[IdRebate] = case g.descripcion when 'VEHICULOS' then (select max(idnota) from #NotaRebate nr where nr.id = d.id) else '' end,
	[Hoja Negocios]=d.id_veh_hn_enc,
	[Fecha Compra]=com.fechacompra,
	[Factura Proveedor]=com.facproveedor ,
	[Razon Social Proveedor]=com.proveedor ,
	[Financiera HN]=fn.financiera ,
	[Financiera CreditosC]=fncc.financiera ,
	[Valor Financiera]=isnull(fn.valor,0),
	[Tipo de Negocio]=dhn.TipoNegocio	,
	[Aseguradora]=dhn.aseguradora,
	[Dispositivo]=dhn.Dispositivo,
	[CANAL COMERCIAL]=
	case 
		when  cp.descripcion in ('RELACIONADAS','CONCESIONARIO') then 'TRANSFERENCIAS'
		when ISNULL(f.Nit_Flota,'0') ='0' then 'VENTAS RETAIL'
		when ISNULL(f.Nit_Flota,'0') <>'0' and f.Nit_Flota<>'1791927966001' then 'VENTAS FLOTAS'
		when ISNULL(f.Nit_Flota,'0') <>'0' and  f.Nit_Flota='1791927966001' then 'VENTAS VEHICULOS CHEVYPLAN'
		else
		''
	end	,
	[CANAL REPUESTOS]=
	case
	    when b.id_usuario_jefe is not null then 'VENTAS TALLER '  + isnull(CASE 
																	 WHEN  d.facturar_a in ('C','O') then 'CLIENTE'
																   	 WHEN  d.facturar_a in ('G') then 'GARANTÍA'
																	 WHEN  d.facturar_a NOT IN ('C','G') then 'INTERNO'
																	 ELSE ''
																   END,'')	
																   +  ' ' +
																  ISNULL( case 
																		when  tipo_operacion in ('L','P') THEN  'COLISIÓN'
																		when  tipo_operacion in ('0','M') THEN  'MECÁNICA'
																		when  tipo_operacion in ('I') THEN  'MECÁNICA'
																		when  tipo_operacion in ('O') THEN  'MECÁNICA'


																	end ,'')
		when b.id_usuario_jefe is null 	   then 'VENTAS MOSTRADOR ' + isnull(con.descripcion,'')
	End
	,
	[CANAL SERVICIO]=
	CASE
		   when b.id_usuario_jefe is not null then 'VENTAS TALLER '  + isnull(CASE 
																	 WHEN  d.facturar_a in ('C','O') then 'CLIENTE'
																   	 WHEN  d.facturar_a in ('G') then 'GARANTÍA'
																	 WHEN  d.facturar_a NOT IN ('C','G') then 'INTERNO'
																	 ELSE ''
																   END,'MECANICA')	
																   +  ' ' +
																  ISNULL( case 
																		when  tipo_operacion in ('L','P') THEN  'COLISIÓN'
																		when  tipo_operacion in ('0','M') THEN  'MECÁNICA'
																		when  tipo_operacion in ('I') THEN  'MECÁNICA'
																		when  tipo_operacion in ('O') THEN  'MECÁNICA'


																	end ,'MECANICA')

	END ,
	[FUENTE COR]=va.campo_4,
	[ORIGINAL ALTERNO]=va.campo_5,
	[KM]=vt.km ,
	[MARGEN] =((abs(d.precio_cotizado) *abs(case when d.cantidad_und=0 then 1 else d.cantidad_und end ))* case when d.sw=1 then 1 else -1 end + (select isnull(sum(total_sub),0) from #NotaRebate where id = d.id) -
(select sum (total_total - total_iva) valor 
              from cot_cotizacion c
              join v_cot_cotizacion_factura_dev cf on cf.id_cot_cotizacion = c.id
              where cf.id_cot_cotizacion_factura = d.id and c.id_com_motivodev = 482)-
( d.cantidad_und * d.precio_lista ) * d.porcentaje_descuento / 100)
	- (d.cantidad_und * d.costo),
TIPO_VEHICULO=
case when il.vin is not null then 
case          
     when il.tipo_veh  IS  NULL then          
      'Nuevo'          
     when il.tipo_veh = 2 then          
      'Usado Comprado'          
     when il.tipo_veh = 3 then          
      'Usado Consignado'          
     when il.tipo_veh = 4 then          
      'Usado Retomado'          
     when il.tipo_veh = 5 then          
      'Vehiculo para Taller'          
     else          
      ''          
    end 
	else '' end,
[Usuario] = (select u.nombre from usuario u where u.id=d.id_usuario_fac) ,
cc.id_cot_cliente_perfil,
PerfilCiente=ccp.descripcion,
 DiasInventario = CASE
                            WHEN fec.ultima_venta IS NULL AND fec.ultima_Dev_venta IS  NULL THEN
                             --GMAH 747
							 CASE WHEN 605	=601 THEN 	
									DATEDIFF(DD, CAST(fec.ultima_compra AS DATE), CAST(@fecha AS DATE))
                               ELSE
								    DATEDIFF(DD, CAST(il.Fecha_Creacion AS DATE), CAST(@fecha AS DATE))
							   end
							  --/GMAH 747
							WHEN fec.ultima_venta IS not NULL AND fec.ultima_Dev_venta IS not null THEN
                                DATEDIFF(DD, CAST(fec.ultima_compra AS DATE), CAST(@fecha AS DATE))
		                    ELSE
                                DATEDIFF(DD, CAST(fec.ultima_compra AS DATE), CAST(fec.ultima_venta AS DATE))
                        END
,[NC_DESC] = (select sum (total_total - total_iva) valor 
              from cot_cotizacion c
              join v_cot_cotizacion_factura_dev cf on cf.id_cot_cotizacion = c.id
              where cf.id_cot_cotizacion_factura = d.id and c.id_com_motivodev = 482)

,[TIPO_PAGO] =	case when fp.dias_credito > 1 then 'Credito' else
					(Select forma from #forma_pago fp where fp.id_cot_cotizacion = d.id)
				end,
precio_cupon=(abs(d.precio_cotizado) *abs(case when d.cantidad_und=0 then 1 else d.cantidad_und end )*1.12)* case when d.sw=1 then 1 else -1 end,
percio_neto_total = ISNULL(af.totalsub,0) + (abs(d.precio_cotizado) *abs(case when d.cantidad_und=0 then 1 else d.cantidad_und end ))* case when d.sw=1 then 1 else -1 end
,flota_descuento=ISNULL(f.dsctoflota,0)
,[DISP_INCLUIDOS]=ISNULL(df.totalsub,0)+(select isnull(sum(cci.precio_cotizado*cantidad),0) from cot_cotizacion cco 
												join cot_cotizacion_item cci on cci.id_cot_cotizacion = cco.id
												join cot_item it on it.id = cci.id_cot_item
												join cot_grupo_sub cgs on cgs.id = it.id_cot_grupo_sub
												join cot_grupo cg on cg.id = cgs.id_cot_grupo
												where cco.id_cot_item_lote =d.id_cot_item_lote and it.maneja_stock =2 and cg.id =1323 and
												not exists (select 1 from v_cot_cotizacion_item_dev2 d2 
															  where d2.id_cot_cotizacion_item =cci.id))
,[Usado_notas]=(Select top 1 notas from veh_hn_forma_pago where  id_veh_hn_enc = d.id_veh_hn_enc and id_veh_tipo_pago =6)
,[Cantidad_Usado]=(Select sum(1) from veh_hn_forma_pago where  id_veh_hn_enc = d.id_veh_hn_enc and id_veh_tipo_pago =6)
,[chevyseguro] = (	select cc.descripcion from cot_item_cam_def cd
	                        join cot_item_cam ic on ic.id_cot_item_cam_def = cd.id
	                        join cot_item_cam_combo cc on cc.id = ic.id_cot_item_cam_combo
		                    where cd.id = 1523 and ic.id_veh_hn_enc = d.id_veh_hn_enc),
							VPN = (select ic.valor 
	from cot_item_cam ic
	join cot_cliente cl on cl.id = ic.id_cot_cliente
	where id_cot_item_cam_def = 1528 and cl.nit = u.cedula_nit)
FROM #docs d
JOIN dbo.cot_tipo t
ON t.id = d.id_cot_tipo
JOIN cot_bodega b
on b.id=d.id_cot_bodega
LEFT JOIN dbo.com_orden_concep co
ON co.id = d.id_com_orden_concepto
JOIN dbo.cot_cliente cc
ON cc.id = d.id_cot_cliente
LEFT JOIN dbo.cot_cliente_perfil cp
ON cp.id = cc.id_cot_cliente_perfil
LEFT JOIN dbo.usuario u
ON u.id = d.id_usuario_ven 
JOIN dbo.cot_item i
ON i.id = d.id_cot_item --AND i.maneja_stock IN (0)
LEFT JOIN @tipoinventario ti
ON ti.id = i.maneja_stock
LEFT JOIN dbo.cot_item_lote il
ON il.id_cot_item = d.id_cot_item AND 
   il.id = d.id_cot_item_lote
JOIN dbo.cot_grupo_sub s
ON s.id = i.id_cot_grupo_sub
JOIN dbo.cot_grupo g
ON g.id = s.id_cot_grupo
LEFT JOIN dbo.cot_forma_pago fp
ON fp.id = d.id_forma_pago
LEFT JOIN @devoluciones dv
ON dv.id = d.id
LEFT JOIN dbo.ecu_tipo_comprobante et
ON et.id = t.id_ecu_tipo_comprobante

LEFT JOIN dbo.cot_grupo_sub5 s5
ON s5.id = i.id_cot_grupo_sub5
LEFT JOIN dbo.cot_grupo_sub4 s4
ON s4.id = s5.id_cot_grupo_sub4
LEFT JOIN dbo.cot_grupo_sub3 s3
ON s3.id = s4.id_cot_grupo_sub3

LEFT JOIN @hojasnegocio vh
ON vh.id = d.id
LEFT JOIN @accesoriosvehiculos av
ON av.id = d.id
LEFT JOIN @facot ot
ON ot.id = d.id
LEFT JOIN #datoslista_dcto ld
ON ld.id_cot_item = d.id_cot_item AND 
   ld.id_cot_item_lote = d.id_cot_item_lote AND 
   ld.id = d.id
LEFT JOIN #flota f
ON f.id_cot_item = d.id_cot_item AND 
   f.id_cot_item_lote = d.id_cot_item_lote AND 
   f.id = d.id
--LEFT JOIN #notarebate nr
--ON nr.id = d.id
LEFT JOIN #accfact af
ON af.id = d.id AND 
   af.id_cot_item_lote = d.id_cot_item_lote
LEFT JOIN #Compfact compf
ON compf.id = d.id AND 
   compf.id_cot_item_lote = d.id_cot_item_lote
LEFT JOIN cot_cliente_contacto ccc
ON ccc.id = d.id_cot_cliente_contacto AND 
   ccc.id_cot_cliente = d.id_cot_cliente
LEFT JOIN #docco dcc
ON dcc.id = d.id AND 
   dcc.id_cot_tipo = d.id_cot_tipo
--LEFT JOIN #compras com
---ON com.id_cot_item = d.id_cot_item AND 
 --  com.id_cot_item_lote = d.id_cot_item_lote AND 
 --  com.id = d.id
LEFT JOIN @FacConDev fv
on fv.id=d.id
LEFT JOIN cot_item_talla tl
on tl.id=i.id_cot_item_talla

LEFT JOIN #Dispfact df
ON df.id = d.id AND 
   df.id_cot_item_lote = d.id_cot_item_lote

LEFT JOIN #financiera fn	 
ON fn.id_cot_item = d.id_cot_item AND 
   fn.id_cot_item_lote = d.id_cot_item_lote AND 
   fn.id = d.id

LEFT JOIN #financiera_cc fncc	 
ON fncc.id_cot_item = d.id_cot_item AND 
   fncc.id_cot_item_lote = d.id_cot_item_lote AND 
   fncc.id = d.id

LEFT JOIN dbo.v_cot_cotizacion_item_dev2 dev ON dev.id_cot_cotizacion_item = d.id_cot_cotizacion_item
AND dev.cantidad_devuelta<>0

left join  veh_color colv
on colv.id=il.id_veh_color

left join #datosHN  dhn
ON dhn.id_cot_item = d.id_cot_item AND 
   dhn.id_cot_item_lote = d.id_cot_item_lote AND 
   dhn.id = d.id

LEFT JOIN dbo.v_campos_varios va ON va.id_cot_item=i.id

LEFT JOIN com_orden_concep con on con.id=d.id_com_orden_concepto and con.id_cot_tipo=d.id_cot_tipo
left join  #vhtaller vt
on vt.id=d.id

LEFT JOIN dbo.usuario up ON up.id = d.id_operario
LEFT JOIN dbo.cot_cliente_perfil ccp ON ccp.id=cc.id_cot_cliente_perfil
 
 LEFT JOIN #ultimasfechas fec
        ON fec.id_cot_item = d.id_cot_item
           AND fec.id_cot_item_lote = d.id_cot_item_lote

LEFT JOIN #compras com
ON com.id_cot_item = d.id_cot_item AND 
   com.id_cot_item_lote = d.id_cot_item_lote AND 
   com.id = d.id and com.fechacompra = fec.ultima_compra

WHERE vh.fechaentrega>=@fecha and vh.fechaentrega <= @fecha_fin

ORDER BY 
	d.id,
	d.id_cot_cotizacion_item ASC
	