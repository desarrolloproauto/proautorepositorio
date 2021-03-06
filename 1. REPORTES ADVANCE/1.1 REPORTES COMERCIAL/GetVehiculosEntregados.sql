USE [dms_smd3]
GO

-- ========================================================================================================================================================
-- Author:		<>
-- Create date: <2021-02-11>
-- Description:	<Procedimiento para obtener informacion de Vehiculos Entregados. Reporte 100016 Advance>
-- Historial:	<Se corrige el campo cliente_id (JCB)>
--              <2022-02-03 Se agrega el "km_ingreso" y "km_salida", indican el km con el que ingresa y el km con el que se entrega el VH al cliente
--              <2022-03-25 Se agrega "MARCA" y "LINEA" del Vehículo (JCB)
-- ========================================================================================================================================================

-- Exec[dbo].[GetVehiculosEntregados] '605','20220301 00:00:00','20220331 23:59:59'  --306 registros

ALTER PROCEDURE [dbo].[GetVehiculosEntregados]
(
	--@id_cot_cliente INT,
	@emp int,
	@desde date,
	@hasta date
)
AS
BEGIN


-- Obtenemos el ultimo km de loc vehiculos

	select x.*
	into #UltimoKM
	from
	(
		SELECT  ck.id_emp,
				ck.id_cot_item_lote,
				ck.fecha,
				ck.km,
				ck.id_cot_cotizacion,
				rank() over(partition by ck.id_cot_item_lote order by fecha desc) as fila
		FROM dbo.cot_item_lote_km ck 
		WHERE ck.id_emp=605 
	)x
	where x.fila = 1



    select x.*
	into #PrimerKM
	from
	(
		SELECT  ck.id_emp,
				ck.id_cot_item_lote,
				ck.fecha,
				ck.km,
				ck.id_cot_cotizacion,
				rank() over(partition by ck.id_cot_item_lote order by fecha ASC) as fila
		FROM dbo.cot_item_lote_km ck 
		WHERE ck.id_emp=605 
	)x
	where x.fila = 1


	SELECT 
	--ve.descripcion,
	ID_HN = vhe.id, 
	CHASIS = l.vin,
	AGENCIA_ID = b.descripcion,
	FACTURA = ISNULL(b.ecu_establecimiento, '') + '-' + ISNULL(t.ecu_emision, '') + '-' + REPLICATE('0',9-LEN(Convert(varchar,c.numero_cotizacion))) + Convert(VARCHAR,c.numero_cotizacion),
	FEC_COMPROBANTE = c.fecha,
	FEC_ENTREGA =avhe.fecha_hora,-- vhe.fecha_modificacion,
	CLIENTE = cli.razon_social,
	CORREO_ELECTRONICO = IsNull(con.email,''),
	TELEFONO_2 = IsNull(cli.tel_2,''),
	TELEFONO_MOVIL = IsNull(cli.tel_1,''),
	TELEFONO_1 = IsNull(con.tel_1,''),
	VENDEDOR = u2.nombre,
	PRODUCTO_ID = l.id,
	NOMBRE = i.descripcion,
    MARCA = vi.marca,
	LINEA =isnull(tal.descripcion,'LIVIANOS'),
	FLOTA = IsNull((Select d.descripcion
			From cot_pedido_item_descuentos id
				inner join cot_descuento d on id.id_cot_descuento = d.id
			where id.id_cot_pedido_item = cip.id),''),
	FLOTA_TIPO = '',
	CLIENTE_ID = cli.nit,
	FORMA_PAGO = case when (Select count(*) 
					from veh_hn_forma_pago fp
						join	veh_tipo_pago f on f.id=fp.id_veh_tipo_pago where fp.id_veh_hn_enc = vhe.id and f.id = 3) > 0 then 'CREDITO' else 'CONTADO' end,
	PLACA = IsNull(l.placa,''),
	KM_INGRESO = pkm.km,
	KM_SALIDA = ukm.km

	FROM dbo.veh_hn_enc vhe
	JOIN dbo.veh_estado ve ON ve.id=vhe.estado
	JOIN dbo.veh_hn_pedidos p ON  p.id_veh_hn_enc=vhe.id 
	JOIN dbo.cot_pedido_item cip ON cip.id_cot_pedido = p.id_cot_pedido
	JOIN cot_item_lote l ON (cip.id_cot_item = l.id_cot_item AND cip.id_cot_item_lote = l.id)
	JOIN cot_item i ON i.id=l.id_cot_item
	JOIN cot_cotizacion_item ci on l.id = ci.id_cot_item_lote
	--
	LEFT JOIN dbo.cot_item_talla tal  on tal.id = i.id_cot_item_talla
	JOIN dbo.v_cot_item_descripcion vi  ON vi.id=i.id
	--
	JOIN cot_cotizacion c on c.id = ci.id_cot_cotizacion
	LEFT JOIN dbo.cot_cliente cli ON cli.id = c.id_cot_cliente
	LEFT JOIN dbo.cot_cliente_contacto con ON con.id = cli.id_cot_cliente_contacto								  
	JOIN cot_tipo t on t.id = c.id_cot_tipo
	LEFT JOIN dbo.v_cot_cotizacion_item_dev2 dev ON dev.id_cot_cotizacion_item = ci.id
	LEFT JOIN dbo.usuario u2 ON u2.id = vhe.id_usuario_vende
	JOIN cot_bodega b ON c.id_cot_bodega = b.id 
	LEFT JOIN  dbo.cot_auditoria avhe ON avhe.id_id = vhe.id	   AND avhe.que  like 'E:575%'	---SOLICITADO GRUPO MEP GMAH
	LEFT JOIN #PrimerKM pkm on (l.id = pkm.id_cot_item_lote)
	LEFT JOIN #UltimoKM ukm on (l.id = ukm.id_cot_item_lote)
	WHERE ve.id=575
	AND vhe.id_emp=@emp
	and avhe.fecha_hora between @desde and @hasta
	and t.sw = 1
	and ci.cantidad-IsNull(dev.cantidad_devuelta,0) > 0

	
	UNION all
	
	-- Para los vehículos migrados de kairon pendientes por entregar 
	select 
	ID_HN = vev2.id, -- no se tiene HN se toma el dia del registor del vin 
	CHASIS = cil.vin,
	AGENCIA_ID = (select Agencia from Veh_visor_historia vvh where vvh.chasis = cil.LOTE ),
	FACTURA = '',
	FEC_COMPROBANTE = NULL,
	FEC_ENTREGA = vev2.fecha,
	CLIENTE = cli.razon_social,
	CORREO_ELECTRONICO = IsNull(con.email,''),
	TELEFONO_2 = IsNull(cli.tel_2,''),
	TELEFONO_MOVIL = IsNull(cli.tel_1,''),
	TELEFONO_1 = IsNull(con.tel_1,''),
	VENDEDOR = '',
	PRODUCTO_ID = cil.id,
	NOMBRE = ci.descripcion,
	MARCA = vi.marca,
	LINEA =isnull(tal.descripcion,'LIVIANOS'),
	FLOTA = '',
	FLOTA_TIPO = '',
	--CLIENTE_ID = '',
	CLIENTE_ID = cli.nit,
	FORMA_PAGO = '',
	PLACA = cil.placa,
	KM_INGRESO = pkm.km,
	KM_SALIDA = ukm.km 
	from dbo.veh_eventos_vin vev2
	JOIN dbo.veh_eventos2 ve ON ve.id =vev2.id_veh_eventos2 
	JOIN dbo.cot_item_lote cil ON cil.id = vev2.id_cot_item_lote 
	JOIN dbo.cot_item ci ON ci.id=cil.id_cot_item 
	--
	LEFT JOIN dbo.cot_item_talla tal  on tal.id = ci.id_cot_item_talla
	JOIN dbo.v_cot_item_descripcion vi  ON vi.id=ci.id
	--
	JOIN cot_cliente_contacto con on cil.id_cot_cliente_contacto = con.id
	JOIN cot_cliente cli on con.id_cot_cliente = cli.id
	LEFT JOIN #PrimerKM pkm on (cil.id = pkm.id_cot_item_lote)
	LEFT JOIN #UltimoKM ukm on (cil.id = ukm.id_cot_item_lote)
	WHERE ve.id=2
	AND ve.id_emp=@emp
	and vev2.fecha between @desde and @hasta
	
END


