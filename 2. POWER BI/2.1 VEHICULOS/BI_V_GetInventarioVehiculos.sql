USE [dms_smd3]
GO
/****** Object:  StoredProcedure [dbo].[BI_V_GetInventarioVehiculos]    Script Date: 5/3/2022 10:07:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
===========================================================================================================================================
2021-09-21 Se agrega el campo [hoja_negocio] es campo indica cuando un vehiculo esta Reservado, fue solicitado por la migracion de Emaulme (JCHB)
2021-09-17 Se ajusta la tabla @vhReserva para obtener un solo registro por VIN cuanso de tenga mas de una hoja de negocio para un Vehiculo
2021-09-19 Se modifica el campo Segmento para obtener los valores (PASAJERO, SUV, PICKUP CAMION)
2022-03-05 Se agrega el campo Familia2 que es el mismo campo que la estructura FactVentaVehiculos (JCB)
===========================================================================================================================================
*/
-- EXEC [dbo].[BI_V_GetInventarioVehiculos] '2022-02-28'
ALTER PROCEDURE [dbo].[BI_V_GetInventarioVehiculos]
(
	@fecActual date
)
as

	DECLARE @fecha DATETIME = EOMONTH(@fecActual)
	PRINT @fecActual PRINT @fecha
	DECLARE @emp INT = 605,
    --@fecha DATETIME = '2021-05-31',
    @ite INT = 0,
    @Bod VARCHAR(max)='0',
    --@Gru INT = 0,
	@Gru INT = 1327,
    @Sub VARCHAR(MAX) = '0',
    @Sub3 VARCHAR(MAX) = '0',
    @soloStock BIT = 1,
	@Tipovh SMALLINT  =0, --GMAH 747
	--@usu  INT = 11071
	@usu  INT = 12104

--NULL NUEVO
--1 USADO COMPRADO
--2 USADO CONSIGNADO
--3 USADO RETOMADO
--4 VEHICULO PARA TALLER
 --hacer temporal

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


declare @todo SMALLINT = 1
--EXEC dbo.PutCotStockTemp @Emp, @usu, 0, @Gru, @Sub, @ite, @todo


DECLARE @EsAbcBod INT


DECLARE @Bodega AS TABLE
(
    id INT,
    descripcion VARCHAR(200),
    ecu_establecimiento VARCHAR(4)
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
    FROM dbo.cot_bodega WITH(NOLOCK)
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
        JOIN dbo.cot_bodega c WITH(NOLOCK)
            ON c.id = CAST(f.val AS INT)


SET @EsAbcBod = dbo.ReglaDeNegocio(@emp, 153, 'abc_bod', 0) -- GMAH DT: 1509



DECLARE @subgrupo AS TABLE
(
    id INT
)
INSERT @subgrupo
(
    id
)
SELECT CAST(f.val AS INT)
FROM dbo.fnSplit(@Sub, ',') f
DECLARE @Varios TINYINT = 0
IF EXISTS (SELECT COUNT(1) FROM @subgrupo HAVING COUNT(1) > 1)
    SET @Varios = 1




--nombre de subgrupo en texto
DECLARE @NombreSubgrupo VARCHAR(50) = '' --jdms 709: se quita la inicialización

IF @Varios = 0
    SET @NombreSubgrupo = dbo.NombreSubgrupo(@Gru, CAST(@Sub AS INT))

IF @NombreSubgrupo <> ''
    SET @Sub = '0' --apagamos el subgrupo como tal
--/nombre de subgrupo en texto	


DECLARE @fecha2 AS VARCHAR(25)
SET @fecha2 = dbo.FormatoFechaSinHoraPlana(@fecha) + ' 23:59:59'

-----------------------------------------------------------------------------
--MOvs


declare @mov as table
(
	[Agencia] [varchar](4) ,
	[id_cot_item] [int] ,
	[id_cot_item_lote] [int] ,
	[codigo] [varchar](30) ,
	[Producto] [nvarchar](50) ,
	[modelo] [varchar](500) ,
	[Aplicacion] [varchar](max) ,
	[Año] [int] ,
	[id_cot_bodega] [int] ,
	[Bodega] [varchar](200) ,
	[Grupo] [nvarchar](50) ,
	[Categoria] [nvarchar](50) ,
	[Linea] [nvarchar](50) ,
	[Estatus] [varchar](2) ,
	[ubicacion] [varchar](20) ,
	[stock] [decimal](38, 8) ,
	[CanOt] [int] ,
	[Reservas] [int] ,
	[Fecha_Creacion] [varchar](10) ,
	[Costo] [decimal](38, 6) ,
	[costound] [money] ,
	[CostoOT] [int] ,
	[PrecioSinIva] [money] ,
	[VhPagado] [varchar](1) ,
	[UltimaCompra] [varchar](1) ,
	[Ultimaventa] [int] ,
	[DiasInventario] [int] ,
	[color] [nvarchar](30) ,
	[color_interno] [nvarchar](30) ,
	[UbicacionVehiculo] [varchar](80) ,
	[accesorios] [varchar](1) ,
	[reservado] [varchar](1) ,
	[nombrereserva] [varchar](1) ,
	[vin] [nvarchar](50) ,
	[RAMV] [varchar](20) ,
	[Motor] [varchar](50) ,
	[id_veh_linea_modelo] [int] ,
	[subgrupo3] [varchar](50) ,
	[subgrupo4] [varchar](50) ,
	[subgrupo5] [varchar](50) ,
	[calificacion_abc] [varchar](2) ,
	[seguro_obligatorio] [varchar](20) ,
	[Categoria_Precio] [varchar](100)
)
INSERT @mov
SELECT Agencia = MAX(b.ecu_establecimiento),		
       c.id_cot_item,
       c.id_cot_item_lote,
       codigo = MAX(i.codigo),
       Producto = (CASE
                       WHEN l.vin IS NULL THEN
                           i.codigo
                       ELSE
                           l.vin
                   END
                  ),
       --NombreProducto = MAX(i.descripcion),
	   modelo = MAX(i.descripcion),
       Aplicacion = MAX(CONVERT(VARCHAR(MAX), i.notas)),
       [Año] = ISNULL(MAX(i.id_veh_ano), 0),
       c.id_cot_bodega,
       Bodega = MAX(b.descripcion),
       Grupo = MAX(g.descripcion),
       Categoria = MAX(s.descripcion),
       Linea = MAX(ct.descripcion),
	  -- subgrupo3=MAX(s3.descripcion),
       Estatus = CASE
                     WHEN @EsAbcBod = 1 THEN
                         MAX(ib.calificacion_abc)
                     ELSE
                         MAX(i.calificacion_abc)
                 END,
       ubicacion = MAX(ub.ubicacion),
       stock = -- CASE
       --   WHEN ISNULL(c.id_cot_item_lote, 0) = 0 THEN
       SUM(   CASE
                  WHEN t.sw IN ( 1, 2, -4, 11 ) THEN
                      c.cantidad * -1
                  ELSE
                      CASE
                          WHEN t.sw IN ( -1, 4, 12 ) THEN
                              c.cantidad
                          ELSE
                              0
                      END
              END
          ),
       --  ELSE
       --        1
       -- END,
       CanOt = 0,
       Reservas = 0,
       Fecha_Creacion = dbo.FormatoFechaSinHora(MAX(   CASE
                                                           WHEN l.vin IS NOT NULL THEN
                                                               l.fecha_creacion
                                                           ELSE
                                                               i.fecha_creacion
                                                       END
                                                   )
                                               ),
       Costo = SUM(   CASE
                          WHEN t.sw IN ( 1, 2, -4, 11, 13 ) THEN
                              c.cantidad * ISNULL(c.costo_und, 0) * -1
                          ELSE
                              c.cantidad * ISNULL(c.costo_und, 0)
                      END
                  ),
       costound = MAX(   CASE
                             WHEN t.sw IN ( 1, 2, -4, 11, 13 ) THEN
                                 ISNULL(c.costo_und, 0) * -1
                             ELSE
                                 ISNULL(c.costo_und, 0)
                         END
                     ),
       CostoOT = 0,
       PrecioSinIva = MAX(i.precio),
       VhPagado = '',
       UltimaCompra = '',
       Ultimaventa = 0,
       DiasInventario = 0,
	   --GMAH 747
	   color=max(isnull(vc.descripcion,'')),
	   color_interno = max(isnull(vci.descripcion,'')),
	   UbicacionVehiculo =max(isnull(u.descripcion,'')),
	   accesorios='',
	   reservado='',
	   nombrereserva='',
	   vin=max(l.vin) ,
	   RAMV=max(l.ramv),
	   Motor=max(l.motor),
	   id_veh_linea_modelo=max(i.id_veh_linea_modelo) ,
	   subgrupo3=max(s3.descripcion),
	   subgrupo4=max(s4.descripcion),
	   subgrupo5=max(s5.descripcion), 
	   calificacion_abc=max(i.calificacion_abc),
	   seguro_obligatorio=max(l.seguro_obligatorio), -- GMB migracion mirasol
	   Categoria_Precio=MAX(cic.descripcion) --GMAH 750
	  
FROM dbo.cot_cotizacion_item c with(nolock)
    JOIN dbo.cot_item i with(nolock)
        ON i.id = c.id_cot_item
           AND ISNULL(i.maneja_stock, 0) IN ( 1, 2 )
    LEFT JOIN dbo.cot_item_lote l with(nolock)
        ON l.id = c.id_cot_item_lote
           AND l.id_cot_item = c.id_cot_item
    JOIN dbo.cot_cotizacion z with(nolock)
        ON z.id = c.id_cot_cotizacion -- and (c.id_cot_tipo_tran is not null or IsNull(z.anulada,0)=1)
    JOIN dbo.cot_tipo t with(nolock)
        ON t.id = ISNULL(c.id_cot_tipo_tran, z.id_cot_tipo)
           AND t.sw IN ( -1, 1, 2, 4, -4, 11, 12, 13, 14, 16 )
    JOIN @Bodega b
        ON b.id = c.id_cot_bodega
    JOIN dbo.cot_grupo_sub s with(nolock)
        ON s.id = i.id_cot_grupo_sub
    JOIN dbo.cot_grupo g with(nolock)
        ON g.id = s.id_cot_grupo
    LEFT JOIN dbo.cot_item_bodega ib with(nolock)
        ON ib.id_cot_bodega = c.id_cot_bodega
           AND ib.id_cot_item = c.id_cot_item
    LEFT JOIN dbo.cot_item_ubicacion ub with(nolock)
        ON ub.id = ib.id_cot_item_ubicacion
    LEFT JOIN @subgrupo s2 
        ON s2.id = i.id_cot_grupo_sub
    --LEFT JOIN dbo.cot_grupo_sub3 sg3
    --    ON sg3.id_cot_grupo_sub = s2.id
	LEFT JOIN cot_grupo_sub5 s5 with(nolock)
		on s5.id=i.id_cot_grupo_sub5
	LEFT JOIN cot_grupo_sub4 s4 with(nolock)
		on s4.id=s5.id_cot_grupo_sub4
	LEFT JOIN cot_grupo_sub3 S3 with(nolock)
		ON S3.ID=S4.id_cot_grupo_sub3
	LEFT  JOIN 	veh_color vc with(nolock)	--	 GMAH 747
	  ON vc.id=l.id_veh_color
    LEFT  JOIN 	veh_color vci with(nolock)	--	 GMB 
	  ON vci.id=l.id_veh_color_INT
	 LEFT JOIN dbo.cot_bodega_ubicacion u with(nolock) ON u.id = l.id_cot_bodega_ubicacion --	 GMAH 747
	
	LEFT JOIN  cot_item_talla ct with(nolock)
	ON ct.id=i.id_cot_item_talla
	--LEFT JOIN  v_campos_varios cvm
	--on cvm.id_veh_linea_modelo=i.id_veh_linea_modelo

	----LEFT JOIN veh_linea_modelo vl
	----ON VL.ID=i.id_veh_linea_modelo
	----left join veh_linea vb
	----on vb.id=vl.id_veh_linea
	----left join veh_clase  vcl
	----on vcl.id=vb.clase
	LEFT JOIN cot_item_categoria cic with(nolock) 
	ON cic.id=i.id_cot_item_categoria --GMAH 750

      WHERE i.id_emp = @emp
      AND ISNULL(i.anulado, 0) <> 1
      AND
      (
          @ite = 0
          OR i.id = @ite
      )
      AND
      (
          @Gru = 0
          OR s.id_cot_grupo = @Gru
      )
      AND
      (
          @Sub = '0'
          OR s2.id IS NOT NULL
      )

      AND z.fecha <= @fecha2
      AND
      (
          c.id_cot_tipo_tran IS NOT NULL
          OR
          (
              t.sw = 2
              AND ISNULL(z.anulada, 0) = 0
          )
          OR
          (
              t.sw <> 2
              AND ISNULL(z.anulada, 0) = 1
          )
      )
	AND  
	(
	
	@Tipovh=0 
	OR l.vin IS NOT null and isnull(l.tipo_veh,99)=CASE 
			 WHEN @Tipovh=1 THEN 99
			 WHEN @Tipovh=2 THEN 1
			 WHEN @Tipovh=3 THEN 2
			 WHEN @Tipovh=4 THEN 3
			 WHEN @Tipovh=5 THEN 4
			end
	
		   
	) 

   --and l.id = 159533--158334
   GROUP BY c.id_cot_bodega,
         c.id_cot_item,
         (CASE
              WHEN l.vin IS NULL THEN
                  i.codigo
              ELSE
                  l.vin
          END
         ),
         c.id_cot_item_lote


 
 -------AJUSTE PARA VALIDAR DATO DE STOCK EN TALLER
 --solicitud expresa serño Francisco salas
    declare @bodtransito as table
	(
			[bodrep] [int],
	        [bodtran] [int]
	)
	insert @bodtransito
	SELECT 
	bodrep=cast(SUBSTRING(llave,4,LEN(llave)) as int),
	bodtran=cast(respuesta as int)
	FROM reglas_emp with(nolock)
	WHERE id_emp = @emp AND 
	id_reglas = 172 AND 
	llave LIKE 'bod%'
	and llave not like '%rep%'
    AND not llave like '%tra'

	-----------------------------------------------------
	declare @stocktransitotaller as table
	(
			[id_cot_item] [int] ,
			[id_cot_item_lote] [int] ,
			[bodrep] [int] ,
			[bodtran] [int] ,
			[stock] [decimal](38, 8) 
	)
	insert @stocktransitotaller
	select 
	id_cot_item,
	id_cot_item_lote,
	bodrep,
	bodtran,
	stock
	from @mov a
	join @bodtransito b
	on a.id_cot_bodega = b.bodtran

	



 ------------------------------------------------
 
declare @datosvh as table
(
	[id_cot_item] [int] ,
	[id_cot_item_lote] [int] ,
	[tipo] [varchar](5000) ,
	[segmento] [varchar](50) ,
	clase varchar(50),
	[familia] [varchar](50) 
)
insert @datosvh
select i.id_cot_item, 
	   i.id_cot_item_lote,	 
	   tipo=max(cvm.campo_2),
	   segmento=max(vcl.descripcion),
	   clase=max(vcl.descripcion),
	   familia=max(vb.descripcion)
from @mov i
LEFT JOIN v_campos_varios cvm with(nolock)
on cvm.id_veh_linea_modelo=i.id_veh_linea_modelo and isnull(i.id_cot_item_lote,0)<>0
JOIN veh_linea_modelo vl with(nolock) ON VL.ID=i.id_veh_linea_modelo
left join veh_linea vb with(nolock) on vb.id=vl.id_veh_linea
left join veh_clase vcl with(nolock) on vcl.id=vb.clase	
 group by i.id_cot_item, 
 i.id_cot_item_lote

 --select *
 --from @datosvh

declare  @Tipocosto int = dbo.ReglaDeNegocio(@emp, 153, 'costo', 0) -- GMAH

declare @costoemp as table
(
	id_cot_item int, 
	id_cot_item_lote int,
	costo_emp decimal(18,2)
)

if  @Tipocosto=3
insert @costoemp
(
	id_cot_item,
	id_cot_item_lote, 
	costo_emp
)
select m.id_cot_item,
       m.id_cot_item_lote,
       --costo_und=sum(CASE WHEN m.stock <> 0 THEN m.costo / m.stock ELSE NULL END)
       CASE WHEN sum(m.stock) <> 0 THEN sum(m.costo) / sum(m.stock) ELSE NULL END
from @mov m
group by m.id_cot_item,
m.id_cot_item_lote



--------------------------------------------
--EXEC [dbo].[GetCotItemStockFecha_ecuadorv2_Borrar]
declare @items as table
(
	[id_cot_item] [int] ,
	[id_cot_item_lote] [int] ,
	[seguro_obligatorio] [varchar](20) 
)
insert @items
SELECT DISTINCT
       id_cot_item,
       id_cot_item_lote,
	   seguro_obligatorio --gmb Mirasol
FROM @mov



--- NO MOSTRAR BODEGAS TRANSITO .
--- SOLICITUD EXPRESA FRANCISCO SALAS
	delete a 
	from @mov a
	join @bodtransito b
	on a.id_cot_bodega = b.bodtran

  --- datos varios rpt
  declare @items_camposvarios as table
  (
	   [id_cot_item] [int] ,
	   [id_cot_item_lote] [int] ,
	   [campo_1] [varchar](5000) ,
	   [campo_2] [varchar](5000) ,
	   [campo_3] [varchar](5000) ,
	   [campo_4] [varchar](5000) ,
	   [campo_5] [varchar](5000) ,
	   [campo_6] [varchar](5000) ,
	   [campo_7] [varchar](5000) ,
	   [campo_8] [varchar](5000) ,
	   [campo_9] [varchar](5000) ,
	   [campo_10] [varchar](5000) ,
	   [Explicacion_adicional] [varchar](150) 
  )
  insert @items_camposvarios
  select 
	  i.id_cot_item,
	  i.id_cot_item_lote,
	  vc.campo_1,
	  vc.campo_2,
	  vc.campo_3,
	  vc.campo_4,
	  vc.campo_5,
	  vc.campo_6,
	  vc.campo_7,
	  vc.campo_8,
	  vc.campo_9,
	  vc.campo_10, 
	  [Explicacion_adicional]=pa.descripcion
  from @items i
  join v_campos_varios vc with(nolock)
  on vc.id_cot_item=i.id_cot_item
  LEFT JOIN  [cot_item_cabas] a with(nolock) ON a.id_cot_item=i.id_cot_item
  LEFT JOIN cot_item_cabas_principio pa with(nolock) on pa.id=a.id_cot_item_cabas_principio
  where isnull(i.id_cot_item_lote,0)=0


-----------------------------------

declare @pedidos as table
(
    idped INT,
    id_cot_tipo INT,
    idpedit INT,
    id_cot_bodega INT,
    id_cot_item INT,
    id_cot_item_lote INT,
    cantidad DECIMAL(18, 4)
)

-- Ped Ptes   a corte
INSERT @pedidos
(
    idped,
    id_cot_tipo,
    idpedit,
    id_cot_bodega,
    id_cot_item,
    id_cot_item_lote,
    cantidad
)
SELECT idped = c.id,
       c.id_cot_tipo,
       idpedit = ip.id,
       c.id_cot_bodega,
       ip.id_cot_item,
       ip.id_cot_item_lote,
       cantidad = SUM(ip.cantidad_und)
FROM @items ii
    JOIN dbo.cot_pedido_item ip with(nolock)
        ON ip.id_cot_item = ii.id_cot_item
           AND isnull(ip.id_cot_item_lote,0) = isnull(ii.id_cot_item_lote,0)
    JOIN dbo.cot_pedido c with(nolock)
        ON c.id = ip.id_cot_pedido
    JOIN @Bodega b
        ON b.id = c.id_cot_bodega
WHERE c.id_emp = @emp
      AND CAST(c.fecha AS DATE) <= @fecha
GROUP BY c.id,
         c.id_cot_tipo,
         ip.id,
         ip.id_cot_item,
         ip.id_cot_item_lote,
         c.id_cot_bodega



declare @facturasPed as table
(
    idped INT,
    idpedit INT,
    id_cot_bodega INT,
    id_cot_item INT,
    id_cot_item_lote INT,
    cantidad DECIMAL(18, 4)
)
INSERT @facturasPed
SELECT p.idped,
       p.idpedit,
       p.id_cot_bodega,
       p.id_cot_item,
       p.id_cot_item_lote,
       cantidad = i.cantidad_und
FROM @pedidos p
    JOIN dbo.cot_cotizacion_item i with(nolock)
        ON i.id_cot_pedido_item = p.idpedit
    JOIN dbo.cot_cotizacion c with(nolock)
        ON c.id = i.id_cot_cotizacion
    JOIN dbo.cot_tipo t with(nolock)
        ON t.id = c.id_cot_tipo
    --JOIN @Bodega b
    --    ON b.id = c.id_cot_bodega
--WHERE t.sw = 1
WHERE t.sw in( 1,2)
AND CAST(c.fecha AS DATE) <= cast(@fecha as date)

	  
declare @PedidosPendientes AS TABLE
(
   
	id_cot_item INT,
    id_cot_item_lote INT,
    id_cot_bodega INT,
    pendiente DECIMAL(18, 4)
)
INSERT @PedidosPendientes
SELECT 
p.id_cot_item,
       p.id_cot_item_lote,
       p.id_cot_bodega,
       Pendiente = SUM(p.cantidad) - sum(ISNULL(f.cantidad, 0))
FROM @pedidos p
    LEFT JOIN @facturasPed f
        ON f.idped = p.idped
           AND f.idpedit = f.idpedit
           AND f.id_cot_item = p.id_cot_item
           AND f.id_cot_item_lote = p.id_cot_item_lote
GROUP BY p.id_cot_item,
         p.id_cot_item_lote,
         p.id_cot_bodega


-- ultima compras 
declare @ultimasfechas as table
(
	[id_cot_item] [int],
	[id_cot_item_lote] [int],
	[ultima_venta] [datetime],
	[ultima_Dev_venta] [datetime],
	[ultima_compra] [datetime],
	[ultima_entrada] [datetime],
	[notas] [varchar](500)
)
insert @ultimasfechas
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
                           ),max(l.notas) notas ---GMB vh migracion
--INTO #ultimasfechas
--INTO [dms_smd3_pruebas].[dbo].[bi__uLTIMASFECHAS]
FROM dbo.cot_cotizacion_item d WITH(NOLOCK)
    JOIN @items ii
        ON ii.id_cot_item = d.id_cot_item
           AND ii.id_cot_item_lote = d.id_cot_item_lote
    JOIN dbo.cot_cotizacion c WITH(NOLOCK)
        ON d.id_cot_cotizacion = c.id
    JOIN dbo.cot_tipo t WITH(NOLOCK)
        ON c.id_cot_tipo = t.id
    LEFT JOIN dbo.cot_item_lote l WITH(NOLOCK)
        ON l.id = d.id_cot_item_lote
           AND l.id_cot_item = d.id_cot_item
WHERE ISNULL(c.anulada, 0) <> 4
      AND t.id_emp = @emp
      AND t.sw IN ( 1, 4, 12,-1 )
GROUP BY d.id_cot_item,
         d.id_cot_item_lote



------- cargar la informacion de los vehiculos para adcionar al reporte y  para el estado del vh 

declare @vh as table
(
    [id_cot_item] [int],
	[id_cot_item_lote] [int],
	[vin] [nvarchar](50),
	[Marca] [nvarchar](50),
	[Nuevo_usado] [varchar](5),
	[seguro_obligatorio] [varchar](20),
	[Segmento] [varchar](50) NULL,
	Familia2  varchar(100)
)
insert @vh
SELECT aa.id_cot_item,
       aa.id_cot_item_lote,
       l.vin,
       Marca = m.descripcion ,
	   Nuevo_usado=case when l.tipo_veh is null then 'Nuevo' else 'Usado' end,
	   aa.seguro_obligatorio,
	   Segmento = case when cv.campo_2 in ('AUTOMOVIL') then
					CASE 
						WHEN i.id_veh_linea IN (794,818,860,867) then 'SUV'
						ELSE 'PASAJERO'
					END
						
				--when v2001.descripcion in ('AUTOMOVIL', 'CAMIONETA') then 'PASAJERO' 
				when cv.campo_2 in ('') then 'PICKUP'
				when cv.campo_2 in ('JEEP') then 'SUV'
				when cv.campo_2 in ('CAMION') then 'CAMION'
	  END,
	  Familia2 = cv.campo_7
								
--INTO #vh
FROM @items aa
JOIN dbo.cot_item_lote l with(nolock) ON (l.id_cot_item = aa.id_cot_item AND l.id = aa.id_cot_item_lote)
JOIN dbo.cot_item i with(nolock) ON i.id = aa.id_cot_item
JOIN dbo.veh_linea vl with(nolock) ON vl.id = i.id_veh_linea
LEFT JOIN [dbo].[v_campos_varios] cv on cv.id_veh_linea_modelo = i.id_veh_linea_modelo
JOIN dbo.veh_marca m with(nolock) ON m.id = vl.id_veh_marca




------------------VALIDACION DEL ESTADO DEL VH
declare @estadoFacVh as table
(
	[id_cot_item] [int],
	[id_cot_item_lote] [int],
	[Pagado] [varchar](2)
)
insert @estadoFacVh
SELECT v.id_cot_item,
       v.id_cot_item_lote,
       Pagado = 

                    case   WHEN ABS(C.total_total - ISNULL(s.valor_aplicado, 0)) > 1 THEN
                        'NP'
                    ELSE
                        'P'
                END
FROM @vh v
    JOIN dbo.cot_cotizacion_item ci with(nolock)
        ON v.id_cot_item = ci.id_cot_item
           AND v.id_cot_item_lote = ci.id_cot_item_lote
    JOIN dbo.cot_cotizacion C with(nolock)
        ON C.id = ci.id_cot_cotizacion
    JOIN dbo.cot_tipo ct with(nolock)
        ON ct.id = C.id_cot_tipo 
    JOIN dbo.v_cot_factura_saldo s with(nolock)
        ON s.id_cot_cotizacion = C.id
	LEFT JOIN dbo.v_cot_cotizacion_factura_dev fdev with(nolock) on fdev.id_cot_cotizacion_factura = c.id --GMAH 05042020
WHERE ct.sw = 4
AND fdev.id_cot_cotizacion_factura IS NULL --GMAH 05042020



--left join [dbo].[v_campos_varios] cv with(nolock) on cv.id_veh_linea_modelo = coti.id_veh_linea_modelo
--------------------------------------------------
 --GMAH 747	  --validar accesorios
declare @itevehacc as table
(
	[id_cot_item] [int],
	[id_cot_item_lote] [int],
	[accesorios] [varchar](1)
)
insert @itevehacc
SELECT
i.id_cot_item , 
i.id_cot_item_lote,
accesorios = case when max(a.id_cot_item) is null then 'N' else 'S' end
--into #itemvehacc
FROM @items i
LEFT JOIN cot_item_lote_accesorios a with(nolock)
on a.id_cot_item_lote=i.id_cot_item_lote 
group by i.id_cot_item, i.id_cot_item_lote


--GMAH 747	  --validar reserva
declare @vhReserva as table
(
	[id_cot_item] [int],
	[id_cot_item_lote] [int],
	[esta_reserva] [int],
	[id_hn] [int],
	[pedreserva] [int],
	[nombrereserva] [nvarchar](358),
	[fecha_creacion] datetime
)
insert @vhReserva
select x.id_cot_item, 
       x.id_cot_item_lote,
	   x.esta_reserva,
	   x.id_hn,
	   x.pedreserva,
	   x.nombrereserva,
	   x.fecha_creacion
from
(
	SELECT 
		im.id_cot_item,
		im.id_cot_item_lote,
		esta_reserva=CASE
					 WHEN ISNULL(i.id_cot_item,0) = 0
					 THEN NULL ELSE 1
					 END,
		id_hn=p.id_veh_hn_enc,
		pedreserva=p.id_cot_pedido,
		nombrereserva=ccc.nombre + ' - ' + u.codigo_usuario,
		ve.fecha_creacion,
		rank() over(partition by im.id_cot_item_lote order by ve.fecha_creacion desc) as fila

	FROM @items im
	JOIN dbo.cot_pedido_item i with(nolock)
	ON i.id_cot_item = im.id_cot_item AND 
	   i.id_cot_item_lote = im.id_cot_item_lote
	JOIN dbo.cot_item it with(nolock)
	ON it.id = i.id_cot_item
	JOIN dbo.veh_hn_pedidos p with(nolock)
	ON i.id_cot_pedido = p.id_cot_pedido
	JOIN dbo.veh_hn_enc ve with(nolock)
	ON ve.id = p.id_veh_hn_enc
	JOIN cot_cliente_contacto ccc with(nolock)
			  ON ccc.id = ve.id_cot_cliente_contacto
	JOIN cot_cliente cc with(nolock)
			  ON cc.id_cot_cliente_contacto = ccc.id
	join usuario u with(nolock) on u.id = ve.id_usuario_vende
	WHERE im.id_cot_item_lote <> 0 
--and ve.fecha_reserva IS NOT NULL
)x
where x.fila=1
--EXEC [dbo].[Get_BI_V_FactInventarioVehiculos_Borrador20210917]
--select *
--from @vhReserva


---------CASO ACCESORIOS INSTALADOS 2003 GMAH 749
declare @AccesoriosInstalados as table
(
	[id_cot_item] [int],
	[id_cot_item_lote] [int],
	[id_cot_bodega] [int],
	[cantidad] [money],
	[id_cot_pedido_item] [int]
)
insert @AccesoriosInstalados
select 
cl.id_cot_item,
cl.id_cot_item_lote,
id_cot_bodega=isnull(cp.id_cot_bodega,0),
cantidad=cl.cantidad ,
cl.id_cot_pedido_item
--into #AccesoriosInstalados
from @items i 
join cot_item_lote_accesorios cl with(nolock)
on cl.id_cot_item = i.id_cot_item
left join cot_pedido_item cpi with(nolock) on cpi.id=cl.id_cot_pedido_item
left join cot_pedido cp with(nolock) on  cp.id=cpi.id_cot_pedido
left join cot_cotizacion_item ci with(nolock)
on ci.id_cot_pedido_item=cl.id_cot_pedido_item
left  join cot_cotizacion cc with(nolock)
on cc.id=ci.id_cot_cotizacion 
where (cc.fecha is null or cast(cc.fecha as date)>=@fecha2 )


--Cuando no existe pedido,se toma  la bodega donde esta el invetario de vh GMAH 749
update  a set id_cot_bodega= s.id_cot_bodega
from @AccesoriosInstalados a
join v_cot_item_stock_real s
on s.id_cot_item_lote=a.id_cot_item_lote
where a.id_cot_bodega =0 and  s.stock<>0


																  
--- resultado final GMAH 749
declare @AccesoriosInstaladosresumen AS TABLE
(
	[id_cot_item] [int] NULL,
	[id_cot_item_lote] [int] NOT NULL,
	[id_cot_bodega] [int] NULL,
	[cantidad] [money] NULL
)
INSERT @AccesoriosInstaladosresumen
select cl.id_cot_item,
       id_cot_item_lote=0,
       cl.id_cot_bodega,
       cantidad=sum(cl.cantidad)
--into  #AccesoriosInstaladosresumen
from @AccesoriosInstalados cl
where cl.id_cot_pedido_item is null
group by 
cl.id_cot_item,
cl.id_cot_bodega

-------------------------------------------------------

---calificacion abc por bodega -- SE INCLUYE PARA QUE SE CONSULTE LA CALIFICACION ABC POR BODEGA 25/05/2021 GM
declare @calificacion_bodega as table
(
	[id_cot_item] [int],
	[id_cot_bodega] [int],
	[Obsolescencia_bodega] [varchar](2)
)
insert @calificacion_bodega
select 
ib.id_cot_item,
ib.id_cot_bodega,
ib.calificacion_abc as Obsolescencia_bodega 
--into  #calificacion_bodega 
from cot_item_bodega ib with(nolock)
join cot_item i with(nolock) on i.id=ib.id_cot_item and i.id_emp=605 and ib.calificacion_abc is not null

--------------------------------------------------
declare @Resultado as table
(
	[Agencia] [varchar](4) ,
	[Bodega] [varchar](200) ,
	[codigo] [nvarchar](100) ,
	[Producto] [nvarchar](50) ,
	[modelo] [varchar](500) ,
	[Aplicacion] [varchar](max) ,
	[id_cot_bodega] [int] ,
	[id_cot_item] [int] ,
	[Año] [int] ,
	[color] [nvarchar](30) ,
	[color_interno] [nvarchar](30) ,
	[ubicacionvehiculo] [varchar](80) ,
	[Grupo] [nvarchar](50) ,
	[Categoria] [nvarchar](50) ,
	[Linea] [nvarchar](50) ,
	[ubicacion] [varchar](20) ,
	[Costo] [decimal](38, 6) ,
	[costound] [money] ,
	[Stock Disponible] [decimal](38, 8) ,
	[CanOt] [decimal](38, 8) ,
	[Reservas] [decimal](19, 4) ,
	[AccesoriosReserva] [money] ,
	[Stocktotal] [decimal](38, 8) ,
	[Fecha_Creacion] [date] ,
	[Costo Unidad Promedio Empresa] [decimal](18, 2) ,
	[Costo Stock Disponible] [decimal](18, 2) ,
	[Costo  OT] [decimal](18, 2) ,
	[Costo  Reserva] [decimal](18, 2),
	[Costo Total Promedio Empresa] [decimal](18, 2),
	[PrecioSinIva] [money] ,
	[VhPagado] [nvarchar](10) ,
	[UltimaCompra] [datetime] ,
	[Ultimaventa] [datetime] ,
	[UltimaDevVenta] [datetime] ,
	[DiasInventario] [int] ,
	[VhTieneAccesorios] [nvarchar](10) ,
	[VhReservado] [nvarchar](10) ,
	[VhNombreRervado] [nvarchar](358) ,
	[hoja_negocio] [int],
	[RAMV] [varchar](20),
	[Nuevo_usado] [nvarchar](30) ,
	[Motor] [varchar](50) ,
	[Tipo] [varchar](5000) ,
	[Segmento] [varchar](100) ,
	[Clase] [varchar] (50),
	[Familia] [varchar](50) ,
	[subgrupo3] [varchar](50) ,
	[subgrupo4] [varchar](50) ,
	[subgrupo5] [varchar](50) ,
	[Explicacion_adicional] [varchar](150) ,
	[Original-alterno] [varchar](5000) ,
	[Fuente (cor)*] [varchar](5000) ,
	[Obsolescencia bodega] [varchar](2) ,
	[Obsolescencia General] [varchar](2) ,
	[Edad Inventario] [varchar](25) ,
	[Categoria_Precio] [varchar](100) ,
	[Proveedor] [nvarchar](100),
	id_cot_item_lote int,
	Familia2  varchar(100)
)
INSERT @Resultado
SELECT 

       m.Agencia,
       m.Bodega,
       m.codigo,
       m.Producto,
       m.modelo,
       m.Aplicacion,
	   m.id_cot_bodega,
	   m.id_cot_item,
       m.Año,
	   m.color, 
	   m.color_interno,
	   m.ubicacionvehiculo,
       m.Grupo,
       m.Categoria,
       m.Linea,
	   --m.Estatus,
       m.ubicacion,
	   m.Costo,
	   m.costound,

       [Stock Disponible]=isnull(m.stock,0) - 
	   isnull(case 
	   when cast(year(getdate()) as varchar) +''+  cast(month(getdate()) as varchar) <>	cast(year(@fecha) as varchar) +''+  cast(month(@fecha) as varchar)
         then 
		  --0
		
		case when pp.pendiente<>0 and isnull(m.stock,0)=0 then 0 else pp.pendiente end
		 else  isnull(v.pen,0)
	  end,0) 
	  -isnull(acc.cantidad,0) --GMAH 750
	  ,
	   CanOt =isnull(p.stock,0),--m.stock,-- ot.cantidad,
       Reservas =
	   isnull(case 
	   when cast(year(getdate()) as varchar) +''+  cast(month(getdate()) as varchar) <>	cast(year(@fecha) as varchar) +''+  cast(month(@fecha) as varchar)
       then 
	   --0
	   case when pp.pendiente<>0 and isnull(m.stock,0)=0 then 0 else pp.pendiente end
	  else	   
	   v.pen --(v.stock_total) - (v.stock),--p.pendiente,
	   end,0),	
	   AccesoriosReserva=isnull(acc.cantidad,0), --GMAH 749
       Stocktotal= isnull(m.stock,0) + isnull(p.stock,0)	   ,
	  -- - 
	  -- case 
		 -- when cast(year(getdate()) as varchar) +''+  cast(month(getdate()) as varchar) <>	cast(year(@fecha) as varchar) +''+  cast(month(@fecha) as varchar)
   --    then 0
	  -- else
			--isnull(v.pen,0)
	  -- end ,
	   Fecha_Creacion=cast(m.Fecha_Creacion as date) ,
       --m.Costo,
       --m.costound,
	 --  costo_und = CASE WHEN m.stock <> 0 THEN m.costo / m.stock ELSE NULL END,
	   [Costo Unidad Promedio Empresa]=isnull(cp.costo_emp,0),
	   [Costo Stock Disponible]= (isnull(m.stock,0) - 
	   isnull(case 
	   when cast(year(getdate()) as varchar) +''+  cast(month(getdate()) as varchar) <>	cast(year(@fecha) as varchar) +''+  cast(month(@fecha) as varchar)
         then 
		  --0
		case when pp.pendiente<>0 and isnull(m.stock,0)=0 then 0 else pp.pendiente end
		 else  isnull(v.pen,0)
	  end,0)) *	 isnull(cp.costo_emp,0),


	   [Costo  OT]= isnull(p.stock,0) *isnull(cp.costo_emp,0),
	   [Costo  Reserva]= isnull(cp.costo_emp,0)
	  *
	  (
	   isnull(case 
	   when cast(year(getdate()) as varchar) +''+  cast(month(getdate()) as varchar) <>	cast(year(@fecha) as varchar) +''+  cast(month(@fecha) as varchar)
       then 
	   --0
	  case when pp.pendiente<>0 and isnull(m.stock,0)=0 then 0 else pp.pendiente end
	  else	   
	   v.pen --(v.stock_total) - (v.stock),--p.pendiente,
	   end,0))
	   ,
       [Costo Total Promedio Empresa]=isnull(cp.costo_emp,0)*(isnull(m.stock,0)+ isnull(p.stock,0)  ),
	   --CostoOT = CASE
       --              WHEN ot.cantidad = 0 THEN
       --                  0
       --              ELSE
       --                  ot.costototal / ot.cantidad
       --          END,
       m.PrecioSinIva,
       VhPagado = case when vh.seguro_obligatorio is null then ef.Pagado else vh.seguro_obligatorio end,
       UltimaCompra = F.ultima_compra,
       Ultimaventa = F.ultima_venta,
	   UltimaDevVenta=F.ultima_Dev_venta,
       --DiasInventario = CASE
       --                     WHEN F.ultima_venta IS NULL AND F.ultima_Dev_venta IS  NULL THEN
       --                      --GMAH 747
							-- CASE WHEN @emp	=601 THEN 	
							--		DATEDIFF(DD, CAST(F.ultima_compra AS DATE), CAST(GETDATE() AS DATE))
       --                        ELSE
							--	    DATEDIFF(DD, CAST(m.Fecha_Creacion AS DATE), CAST(GETDATE() AS DATE))
							--   end
							--  --/GMAH 747
							--WHEN F.ultima_venta IS not NULL AND F.ultima_Dev_venta IS not null THEN
       --                         DATEDIFF(DD, CAST(F.ultima_compra AS DATE), CAST(GETDATE() AS DATE))
		     --               ELSE
       --                         DATEDIFF(DD, CAST(F.ultima_compra AS DATE), CAST(F.ultima_venta AS DATE))
       --                 END, 
	   DiasInventario = CASE
                            WHEN F.ultima_venta IS NULL AND F.ultima_Dev_venta IS  NULL THEN
                             --GMAH 747
							 CASE WHEN @emp	=601 THEN 	
									DATEDIFF(DD, CAST(F.ultima_compra AS DATE), CAST(@fecha AS DATE))
                               ELSE
								    DATEDIFF(DD, CAST(m.Fecha_Creacion AS DATE), CAST(@fecha AS DATE))
							   end
							  --/GMAH 747
							WHEN F.ultima_venta IS not NULL AND F.ultima_Dev_venta IS not null THEN
                                case when F.notas = 'Importado BD Proauto' then
								  DATEDIFF(DD, CAST(m.Fecha_Creacion AS DATE), CAST(@fecha AS DATE))
								  else
								DATEDIFF(DD, CAST(F.ultima_compra AS DATE), CAST(@fecha AS DATE))
								end
		                    ELSE
                                DATEDIFF(DD, CAST(F.ultima_compra AS DATE), CAST(F.ultima_venta AS DATE))
                        END, 
						
		VhTieneAccesorios=case when m.vin is null then '' else ia.accesorios end , 
		VhReservado=case when m.vin is null then '' else case when  ir.esta_reserva is null then 'N' else 'S' end end,
		VhNombreRervado=case when m.vin is null then '' else isnull(ir.nombrereserva,'') end,
		ir.id_hn,
		RAMV=m.RAMV,
		vh.Nuevo_usado,
		Motor=m.motor,
		dv.Tipo,
		--Segmento = cast(dv.Tipo as varchar(100)),
		Segmento = vh.Segmento,
		--Segmento = case when cv.campo_2 in ('AUTOMOVIL') then
		--							CASE 
		--								WHEN coti.id_veh_linea IN (794,818,860,867) then 'SUV'
		--								ELSE 'PASAJERO'
		--							END
						
		--						--when v2001.descripcion in ('AUTOMOVIL', 'CAMIONETA') then 'PASAJERO' 
		--						when cv.campo_2 in ('') then 'PICKUP'
		--						when cv.campo_2 in ('JEEP') then 'SUV'
		--						when cv.campo_2 in ('CAMION') then 'CAMION'
		--						ELSE cv.campo_2 
		--				   END
				
		dv.clase,
		dv.Familia ,

		m.subgrupo3,
	    m.subgrupo4,
	    m.subgrupo5, 
	   [Explicacion_adicional]=cv.[Explicacion_adicional] ,
	   [Original-alterno]=cv.campo_5,
	   [Fuente (cor)*]=cv.campo_4 ,
	   [Obsolescencia bodega]=cb.Obsolescencia_bodega, -- SE INCLUYE PARA QUE SE CONSULTE LA CALIFICACION ABC POR BODEGA 25/05/2021 GM
	   [Obsolescencia General]=m.calificacion_abc,

	   [Edad Inventario]=
	   case 
		    when calificacion_abc in ('A') then 'Inventario 0 a 12 meses'
		    when calificacion_abc in ('B') then 'Inventario 0 a 12 meses'
			when calificacion_abc in ('C') then 'Inventario 0 a 12 meses'
			when calificacion_abc in ('D') then 'Inventario 0 a 12 meses'
			when calificacion_abc in ('E') then 'Inventario12 a 24 meses'
			when calificacion_abc in ('F') then 'Inventario 24 o más meses'
			when calificacion_abc in ('G') then 'Inventario12 a 24 meses'
			when calificacion_abc in ('H') then 'Inventario 24 o más meses'
			when calificacion_abc in ('Z') then 'Inventario 0 a 12 meses'			
   	   END,
	   m.Categoria_Precio
	   ,[Proveedor] = (Select top 1 cc.razon_social from cot_cotizacion c with(nolock)
		           join cot_cotizacion_item ci with(nolock) on ci.id_cot_cotizacion = c.id
		           join cot_tipo ct with(nolock) on ct.id = c.id_cot_tipo
		           join cot_cliente cc with(nolock) on cc.id = c.id_cot_cliente
		           where ci.id_cot_item_lote = m.id_cot_item_lote and ct.sw = 4 and c.id_emp =605 )
	   ,m.id_cot_item_lote
	   ,vh.Familia2
		
--INTO #Resultado
--INTO [dms_smd3_pruebas].[dbo].[BI__Resultado]
FROM @mov m
LEFT JOIN @PedidosPendientes pp ON pp.id_cot_item = m.id_cot_item AND pp.id_cot_bodega = m.id_cot_bodega
           AND pp.id_cot_item_lote = m.id_cot_item_lote
LEFT JOIN @stocktransitotaller p
	      ON p.id_cot_item = m.id_cot_item
           AND p.bodrep = m.id_cot_bodega
           AND p.id_cot_item_lote = m.id_cot_item_lote

LEFT JOIN @ultimasfechas F
        ON F.id_cot_item = m.id_cot_item
           AND F.id_cot_item_lote = m.id_cot_item_lote
    --LEFT JOIN #TmpItemOrdenes ot
    --    ON ot.id_cot_item = m.id_cot_item
    --       AND ot.id_cot_item_lote = m.id_cot_item_lote
		  -- AND ot.id_cot_bodegas=m.id_cot_bodega
LEFT JOIN @estadoFacVh ef
        ON ef.id_cot_item = m.id_cot_item
           AND ef.id_cot_item_lote = m.id_cot_item_lote
LEFT JOIN @itevehacc ia on ia.id_cot_item=m.id_cot_item AND ia.id_cot_item_lote=m.id_cot_item_lote 
LEFT JOIN @vhReserva ir on ir.id_cot_item=m.id_cot_item	AND ir.id_cot_item_lote=m.id_cot_item_lote 
LEFT JOIN dbo.cot_item_stock_tem v WITH(NOLOCK) -- por solicitud para que se presente el mismo dato del  reporte 0250
        ON v.id_usuario = @usu
           AND v.id_cot_bodega = m.id_cot_bodega
           AND v.id_cot_item = m.id_cot_item
		   AND isnull(v.id_cot_item_lote,0) = isnull(m.id_cot_item_lote,0)
 left join @costoemp cp
  on  cp.id_cot_item = m.id_cot_item
		   AND isnull(cp.id_cot_item_lote,0) = isnull(m.id_cot_item_lote,0)
 left join @vh vh
 on  vh.id_cot_item = m.id_cot_item
		   AND isnull(vh.id_cot_item_lote,0) = isnull(m.id_cot_item_lote,0)
 LEFT JOIN @datosvh	  dv
 on  dv.id_cot_item = m.id_cot_item
		   AND isnull(dv.id_cot_item_lote,0) = isnull(m.id_cot_item_lote,0)
LEFT JOIN  @items_camposvarios  cv
 on  cv.id_cot_item = m.id_cot_item
		   AND isnull(cv.id_cot_item_lote,0) = isnull(m.id_cot_item_lote,0)
LEFT JOIN @AccesoriosInstaladosresumen acc  --GMAH 749
 on  acc.id_cot_item = m.id_cot_item
		   AND isnull(acc.id_cot_item_lote,0) = isnull(m.id_cot_item_lote,0)
		   and acc.id_cot_bodega=m.id_cot_bodega

left join @calificacion_bodega cb on cb.id_cot_item=m.id_cot_item and cb.id_cot_bodega=m.id_cot_bodega -- SE INCLUYE PARA QUE SE CONSULTE LA CALIFICACION ABC POR BODEGA 25/05/2021 GM

WHERE (
          @soloStock = 0
          OR (isnull(m.stock,0) + isnull(p.stock,0)) <> 0
      )
--  OR ABS(m.Costo) > 1

ORDER BY m.Producto,
         m.Bodega


select DISTINCT Fecha = @fecha,  --Obtiene el ultimo dia del mes actual
		       CodigoTiempo = CONVERT(VARCHAR(8),@fecha,112),
		       --m.Agencia,
		       --m.Bodega,
		       r.id_cot_bodega,
		       r.id_cot_item,
		       r.id_cot_item_lote,
		       --m.codigo,
		       --r.Codigo,
			   r.Producto,
		       r.Modelo,
		       r.[Año],
		       r.color, 
		       r.ubicacionvehiculo,
		       r.Grupo,
		       r.Categoria,
			   Marca = r.Categoria,
		       --r.Marca,
		       r.Linea,
		       --m.Estatus,
		       --m.ubicacion,
		       r.[Stock Disponible] ,
		       r.Reservas,	
		       --AccesoriosReserva = isnull(r.cantidad,0), --GMAH 749
			   r.[AccesoriosReserva],
		       r.Stocktotal,
		       r.Fecha_Creacion,
		       r.costo,
		       r.costound,
		       r.[Costo Unidad Promedio Empresa],
		       r.[Costo Stock Disponible],
		       r.[Costo  Reserva],
		       r.[Costo Total Promedio Empresa],
		       r.PrecioSinIva,
		       r.VhPagado,
		       r.UltimaCompra,
		       r.Ultimaventa,
		       r.UltimaDevVenta,
		       r.DiasInventario,
			   r.VhTieneAccesorios, --= case when m.vin is null then '' else ia.accesorios end, 
			   r.VhReservado, -- = case when m.vin is null then '' else case when ir.esta_reserva is null then 'N' else 'S' end end,
			   r.VhNombreRervado,-- = case when m.vin is null then '' else isnull(ir.nombrereserva,'') end,
			   r.RAMV, --= m.RAMV,
			   r.Nuevo_usado,
			   r.motor,
			   r.segmento,
		       r.clase,
			   r.Familia,
			   --r.subgrupo3,
			   --r.subgrupo4,
			   --r.[Original-alterno],
	     --      r.[Fuente (cor)*],
			   --r.[Explicacion_adicional],
	     --      r.[Obsolescencia General],
			   r.[Edad Inventario],
			   case
					when @emp = 605 then 1
					when @emp = 601 then 4
					end IdEmpresa,
			   r.hoja_negocio,
			   r.Familia2
			   
--INTO [dms_smd3_pruebas].dbo.FactInventarioRepuestos
from @Resultado r
--where r.Grupo IN ('VEHICULOS')







