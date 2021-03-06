USE [dms_smd3]
GO
/****** Object:  StoredProcedure [dbo].[BI_V_GetVehFacturados_NoEntregados]    Script Date: 5/5/2022 15:25:12 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =======================================================================================================
-- Author:		<Javier Chogllo>
-- Create date: <2021-09-15>
-- Description:	<Procedimiento para obtener informacion de Vehiculos Facturados No Entregados
--               Se basa en el reporte 100013 (GetVehFacturados_NoEntregados)
--              Campos:
				--Forma_Pago: Contado / Crédito
				--Tipo_Cedito: CONTADO /CREDITO CONSUMO / CREDITO INTERNO / CREDITO VEHICULAR  
				--Aseguradora: Venta con aseguradora
				--Financiera: Venta con Financiera
				--Valor_ant: Valor anticipo del cliente
				--Valor_Finan: Valor que se está financiando el cliente
				--Valor_CredDirecto: Valor crédito directo con Proauto
				--Valor_CredConsumo
				--Saldo_Finan y Saldo_Cliente: estos dos valores representan la cartera es decir el dinero en cola que se espera.
				--Ubic_Veh: Localización actual del vehículo 
				--Fecha_tent_entrega: Fecha tentativa de entrega del Vehículo
				--Tot_dias_entre: diferencia entre( Fecha_tent_entrega y fecha actual)
				--Ejemplo: 
				---10 indica que faltan 10 días laborables para la entrega del vehículo
				--10 indica que ya se ha pasado 10 días que se debió entregar el vehículo
				--VH_Entregado: Si el valor es NULL es vehículo aún no ha sido entregado
				--anulado: indica que la venta ha sido anulada
				--ENTREGA_Estado: Estado de la entrega del vehículo (Instalando accesorio, Llego, No cumplida, Atrasada)
				--Nomb_flota: Nombre de la Flota si la venta se hizo a un cliente Flotista  
				--Dispositivo: Indica que el vehículo incluye dispositivo
				--Estado_disp: DISPOSITIVO INSTALADO / NO
				--FechaInstalacion: Fecha de instalación del dispositivo
				--Envio_Matricula: Fecha que se envió el vehículo a matricular
				--Matriculado: Fecha en la que se matriculó el vehículo
				--Dias_Matri: número de días que se demoró en matricular el vehículo
-- =======================================================================================================
-- HISTORIAL:
--               (2021-09-23) Se agrega el campo [Fecha_entrega_VH] para obtener tambien los vehiculos entregados (JCB)
--               (2022-01-11) Se ajusta la comparacion con la tabla v_cot_auditoria para obtener la fecha de entrega del vehiculo (JCB)
--               (2022-01-24) Se ajusta el SP ya que se presentaban valores repetidos (JCB)
--               (2022-03-03) Se ajusta el SP para que obtenga correctamente el tipo de vehiculo nuevo-usado (JCB)
--               (2022-03-05) Se ajusta el SP para que No obtenga las ventas de vehiculos a CONSECIONARIO (JCB)
--               (2022-03-05) Se ajusta el SP para que No obtenga las ventas de vehiculos a RELACIONADAS (JCB)
--               (2022-05-05) Se agrega los campos id_nota y desc_tipo_nota para control de anulación de facturas (JCB) 

-- EXEC [dbo].[BI_V_GetVehFacturados_NoEntregados] '2022-05-31' --5159
alter procedure [dbo].[BI_V_GetVehFacturados_NoEntregados]
(
	@fecFin date
)
AS
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	SET NOCOUNT ON;

	declare @fecIni date = '2019-01-01'
	--set @fecFin = '2021-11-30'

	declare @Bod varchar(max)='0'
	declare @emp int = 605

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

	DECLARE @accesoriosvehiculos AS TABLE
	(
		id INT,
		ValorAccesorios DECIMAL(18, 2),
		costoAccesorios DECIMAL(18, 2)
	)

	DECLARE @docco AS TABLE
	(
		id INT,
		id_cot_tipo INT,
		codcentro VARCHAR(100),
		cuota_nro int
	)

	-- Bodegas
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

	-- Docs
	declare @Docs as table
	(
	   id int,
       id_cot_tipo int,
       id_cot_bodega int,
       id_cot_cliente int,
       numero_cotizacion int,
       fecha datetime,
	   fecha_estimada DATETIME,
       notas VARCHAR(500),
       id_cot_item INT,
       id_cot_item_lote INT,
       cantidad_und MONEY,
	   tiempo DECIMAL(18,10),
       precio_lista MONEY,
       precio_cotizado MONEY,
       costo_und MONEY,
       porcentaje_descuento DECIMAL(18,10),
       porcentaje_descuento2 DECIMAL(4,2),
       porcentaje_iva DECIMAL(5,2),
       descripcion VARCHAR(50),
       id_com_orden_concep INT,
       ecu_establecimiento CHAR(3),
       id_usuario_vende INT,
       id_cot_forma_pago INT,
       sw INT,
	   abono MONEY,
       saldo MONEY,
	   total_total MONEY,
       id_cot_pedido_item INT, 
	   docref_tipo VARCHAR(6), 
	   docref_numero VARCHAR(20),
	   id_veh_hn_enc INT,
	   id_cot_cliente_contacto INT,
	   id_cot_cotizacion_item INT,
	   costo MONEY,
	   lote NVARCHAR(100),
	   anulado nvarchar(10)
	)
	INSERT @Docs
	SELECT
	   c.id,
       c.id_cot_tipo,
       c.id_cot_bodega,
       c.id_cot_cliente,
       c.numero_cotizacion,
       c.fecha,
	   c.fecha_estimada,
       CAST(c.notas AS VARCHAR(200)),
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
	   c.total_total,
       i.id_cot_pedido_item, 
	   c.docref_tipo, 
	   c.docref_numero,
	   c.id_veh_hn_enc,
	   c.id_cot_cliente_contacto ,
	   id_cot_cotizacion_item=i.id,
	   costo=i.costo_und,
	   l.lote,
	   anulado	= IIF(nc.id_nc > 0,'SI','NO')
	   FROM dbo.cot_cotizacion c
       JOIN @Bodega b ON b.id = c.id_cot_bodega
       JOIN dbo.cot_tipo t ON t.id = c.id_cot_tipo
       JOIN dbo.cot_cotizacion_item i ON i.id_cot_cotizacion = c.id
       JOIN cot_item_lote l on l.id_cot_item = i.id_cot_item and l.id=i.id_cot_item_lote 
       LEFT JOIN dbo.v_cot_factura_saldo s ON s.id_cot_cotizacion = c.id
	   left join v_id_nc nc with(nolock) on nc.id_cot_cotizacion = c.id
	   WHERE CAST(c.fecha AS DATE) BETWEEN @fecIni AND @fecFin
       AND c.id_emp = @emp
       AND t.sw IN ( 1, -1 )
       AND l.vin is not null
	   and isnull(c.id_cot_cotizacion_estado,0) <> 794 
	   and isnull(c.id_cot_cotizacion_estado,0) <> 802
	   --and c.id = 394162


	   
	   -- Eliminar registros de factura que tienen devoluciones
	   delete d
	   From @Docs d 
	   JOIN v_cot_cotizacion_factura_dev dev on dev.id_cot_cotizacion_factura = d.id
	   JOIN cot_cotizacion_item ci_dev on dev.id_cot_cotizacion = ci_dev.id_cot_cotizacion and d.id_cot_item = ci_dev.id_cot_item
	   Where d.sw = 1
	   and ci_dev.cantidad_und = 1		-- Diferencia, si es una nc de devolucion de vehiculo o una nota de credito de descuento

	   -- Eliminar notas de credito
	   Delete From @Docs Where sw = -1
	   
	   -- Eliminar registros duplicados, vehiculos vueltos a facturar
	   Delete From @Docs Where id in (
										Select min (id)
										From @Docs
										Group By id_cot_item_lote
										having count(*) > 1
										)

		-- @Docsacc
		DECLARE @Docsacc AS TABLE
		(
			id INT, 
			id_cot_item INT, 
			costo MONEY,
			id_cot_pedido_item INT,
			cantidad_und MONEY
		)
		INSERT @Docsacc
		select d.id, 
			i.id_cot_item , 
			costo = i.costo_und  ,
			i.id_cot_pedido_item,
			i.cantidad_und
		--into @Docsacc 
		from @Docs  d
		JOIN dbo.cot_cotizacion_item i ON i.id_cot_cotizacion = d.id
		JOIN cot_item_lote l on l.id_cot_item=i.id_cot_item and l.id=i.id_cot_item_lote and l.vin is null



		
	  	--validación hojas de negocio para fecha de entrega vh
		DECLARE @HojasNegocio AS TABLE
		(
			sw int,
			id_documento INT,
			id_cot_item_lote int,
			id_hn int,
			FechaCreacion DATETIME,
			FechaEstimadaEntrega DATETIME,
			FechaEntrega DATETIME,
			notas VARCHAR(500),
			--estado_hn varchar(50),
			Tipo_Negocio varchar(65),
			Nomb_flota nvarchar(100),
			ChevyPlan varchar(500),
			Tipo_Credito varchar(500),
			Dispositivo varchar(500),
			Aseguradora nvarchar(100),
			Id_Estado_HN smallint,
			Estado_HN varchar(500),
			VH_Entregado DATE,
			id_usuario int
		)
		INSERT @HojasNegocio
		SELECT DISTINCT d.sw,
		                d.id,
		                d.id_cot_item_lote,
		                hn.id,
						hn.fecha_creacion,
						hn.fecha_estimada_entrega,
						hn.fecha_modificacion,
						cast(hn.notas as varchar(500)),
						--ve.descripcion,
						Tipo_Negocio=vtn.descripcion,
						Nomb_flota=isnull(vf.flota,''),
						ChevyPlan=isnull(cv.campo_3,'NO'),
						Tipo_Credito=isnull(cv.campo_2,''),
						Dispositivo=isnull(cv.campo_5,'NO'),
						Aseguradora=isnull(c.razon_social,''),
						Id_Estado_HN = hn.estado,
						Estado_HN = isnull(ve.descripcion,''),
						VH_Entregado = (select convert(varchar,max(cast(va.fecha as datetime))) 
						                from v_cot_auditoria va 
										where va.id_id=hn.id 
										and accion LIKE '%E:575%'),
						hn.id_usuario
							
		FROM @Docs d
		left JOIN dbo.veh_hn_enc hn ON hn.id = d.id_veh_hn_enc
		left join veh_hn_tipo_negocio vtn on vtn.id = hn.id_veh_hn_tipo_negocio
		--left join veh_estado ve on ve.id = hn.estado
		left join V_FLOTAS_VH vf on vf.id_hn = hn.id
		left join v_campos_varios cv on cv.id_veh_hn_enc = hn.id and cv.id_veh_estado is null
		left join cot_cliente_contacto cc on cc.id = hn.id_cot_cliente_contacto_aseguradora
		left join cot_cliente c on c.id_cot_cliente_contacto=cc.id
		--left join v_campos_varios ve on ve.id_veh_hn_enc = hn.id
		left join veh_estado ve on ve.id = hn.estado
		WHERE d.sw = 1 
		--AND isnull(hn.estado,0) = 575


		declare @Notas_Especificas_HN AS TABLE
		(
			nota_especifica VARCHAR(250),
		    desc_tipo varchar(100),
			id int,
			id_veh_hn_enc int,
			id_veh_hn_notas1 int,
			id_veh_hn_notas2 int,
			fecha datetime ,
			id_usuario int
		)
		insert @Notas_Especificas_HN
		select x.nota_especifica,
		       x.desc_tipo,
			   x.id,
			   x.id_veh_hn_enc,
			   x.id_veh_hn_notas1,
			   x.id_veh_hn_notas2,
			   x.fecha,
			   x.id_usuario
		     
		from
		(
			select nota_especifica=d.nota,
				   desc_tipo=n1.descripcion,
				   d.id, 
				   d.id_veh_hn_enc,
				   d.id_veh_hn_notas1,
				   d.id_veh_hn_notas2,
				   d.fecha, --RML 743
				   id_usuario=ISNULL(d.id_usuario,e.id_usuario), --CSP 749
				   rank() over (partition by e.id_hn order by d.id desc ) as fila
			from @HojasNegocio e
			join veh_hn_notas_det d on e.id_hn = d.id_veh_hn_enc
			JOIN dbo.veh_hn_notas n1 ON n1.id=d.id_veh_hn_notas1
			JOIN dbo.usuario u ON u.id=ISNULL(d.id_usuario,e.id_usuario) -- CSP 749 u.id=e.id_usuario
			--where e.id_hn = 5237
		)x
		where x.fila = 1




	
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
		FROM @Docs d
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
		FROM @Docsacc d
			JOIN dbo.cot_pedido_item pd
				ON d.id_cot_pedido_item = pd.id
			JOIN dbo.cot_pedido p
				ON pd.id_cot_pedido = p.id
			JOIN dbo.veh_hn_pedidos vhp
				ON vhp.id_cot_pedido = p.id
		WHERE d.id_cot_item <> pd.id_cot_item 


		-- DATOS VH    precio lista  descuento
		DECLARE @VH AS TABLE
		(
			id_documento INT,
			id_cot_item INT,
			id_cot_item_lote INT,
			docref_numero VARCHAR(20) ,
			vin NVARCHAR(100),
			id_veh_hn_enc INT,
			id_cot_item_talla int,
			Familia varchar(100),
			Linea nvarchar(100),
			Segmento varchar(50),
			Nuevo_Usado varchar(10),
			Placa varchar(50)
		)
		INSERT @VH
		SELECT DISTINCT 
		       d.id,
		       d.id_cot_item,
		       d.id_cot_item_lote,
		       d.docref_numero ,
		       l.vin,
		       d.id_veh_hn_enc,
			   i.id_cot_item_talla,
			   familia = cast(cv.campo_7 as varchar(100)),
			   talla.descripcion,
			   Segmento = case when cv.campo_2 in ('AUTOMOVIL') then
								CASE 
									WHEN i.id_veh_linea IN (794,818,860,867) then 'SUV'
									ELSE 'PASAJERO'
								END
						
							--when v2001.descripcion in ('AUTOMOVIL', 'CAMIONETA') then 'PASAJERO' 
							when cv.campo_2 in ('') then 'PICKUP'
							when cv.campo_2 in ('JEEP') then 'SUV'
							when cv.campo_2 in ('CAMION') then 'CAMION'
						end,
				Nuevo_usado = case when l.tipo_veh is null then 'Nuevo' else 'Usado' end,
				Placa = case when ca.fecha is null then '' else l.placa end

		FROM @Docs d
		JOIN cot_cotizacion c on c.id = d.id
		JOIN cot_item i on d.id_cot_item = i.id
		JOIN cot_item_lote l ON l.id = d.id_cot_item_lote AND l.id_cot_item = d.id_cot_item
		LEFT JOIN dbo.cot_item_talla talla on talla.id = i.id_cot_item_talla
		LEFT JOIN [dbo].[v_campos_varios] cv on cv.id_veh_linea_modelo = i.id_veh_linea_modelo
		LEFT JOIN veh_eventos_vin ca on ca.id_cot_item_lote = l.id and ca.id_veh_eventos2 = 4
		WHERE l.vin IS NOT null

				
		--Flota_Retail
		DECLARE @flota AS TABLE
		(
			id INT,
			id_cot_item INT,
			id_cot_item_lote INT,
			id_cot_pedido INT,
			flota NVARCHAR(200),
			dsctoflota MONEY
		)
		INSERT @flota
		SELECT 
			v.id_documento,
			v.id_cot_item,
			v.id_cot_item_lote,
			i.id_cot_pedido,
			flota=ISNULL(d.descripcion,''),
			dsctoflota=ISNULL(d.porcentaje_descuento,0)
		FROM dbo.veh_hn_pedidos vhp
		JOIN @VH v
		ON v.id_veh_hn_enc = vhp.id_veh_hn_enc
		JOIN dbo.cot_pedido_item i
		ON i.id_cot_pedido = vhp.id_cot_pedido
		--JOIN dbo.cot_pedido_item_descuentos c
		--ON c.id_cot_pedido_item = i.id
		JOIN dbo.cot_descuento d
		ON d.id = i.id_cot_descuento_prov

		---- @datoslista_dcto
		DECLARE @datoslista_dcto AS TABLE
		(
				id INT,
				id_cot_item INT,
				id_cot_item_lote INT,
				precio MONEY,
				max_dcto DECIMAL(5,2)
		)
		INSERT @datoslista_dcto
		SELECT 
			v.id_documento,
			v.id_cot_item,
			v.id_cot_item_lote,
			i.precio,
			i.max_dcto
		FROM @VH v 
		JOIN  cot_item i
		ON i.id=v.id_cot_item
		
		---
		INSERT @docco
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
		FROM @Docs aa
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

		--FORMA DE PAGO DE LA HOJA DE NEGOCIO
		declare @DatosHN_Formap as table
		(
			id int,
			id_cot_item INT,
			id_cot_item_lote INT,
			id_hn int, 
			id_veh_tipo_pago int,
			id_cot_cotizacion int,
			valor money,
			id_cot_cliente_contacto int,
			id_usuario int,
			fecha_hora datetime,
			financiera nvarchar(200),
			Saldo_Finan money
		)
		INSERT @DatosHN_Formap
		select d.id,
		d.id_cot_item,
		d.id_cot_item_lote,
		e.id,
		vf.id_veh_tipo_pago,
		vf.id_cot_cotizacion,
		vf.valor,
		vf.id_cot_cliente_contacto,
		vf.id_usuario,
		vf.fecha_hora,
		financiera = cc.nombre,
		vs.saldo
		from @Docs d
		JOIN veh_hn_enc e ON e.id=d.id_veh_hn_enc
		JOIN dbo.veh_hn_forma_pago vf ON vf.id_veh_hn_enc = e.id
		left join cot_cliente_contacto cc on cc.id = vf.id_cot_cliente_contacto
	    LEFT JOIN v_cot_factura_saldo vs on vs.id_cot_cotizacion=e.id and vf.id_veh_tipo_pago in (3) 
		--where d.id_veh_hn_enc = 8406

		--FORMA DE PAGO CON FINANCIERA
		declare @DatosHN_Formap_finan as table
		(
			id int,
			id_cot_item int,
			id_cot_item_lote int,
			id_hn int, 
			id_veh_tipo_pago int,
			valor money,
			valor_fac money,
			Saldo_Finan money,
			fecha_hora datetime,
			razon_social nvarchar(200)
		)
		insert @DatosHN_Formap_finan
		select  distinct 
				d.id,
				d.id_cot_item,
				d.id_cot_item_lote,
				id_hn=e.id, 
				vf.id_veh_tipo_pago,
				vf.valor,
				d.total_total,
				Saldo_Finan = vs.saldo,
				vf.fecha_hora,
				c.razon_social
		from @Docs d
		JOIN veh_hn_enc e ON e.id = d.id_veh_hn_enc
		JOIN dbo.veh_hn_forma_pago vf ON vf.id_veh_hn_enc = e.id 
		join cot_cliente_contacto cc on cc.id=vf.id_cot_cliente_contacto
		join cot_cliente c on c.id_cot_cliente_contacto=cc.id
		LEFT JOIN v_cot_factura_saldo vs with(nolock) on vs.id_cot_cotizacion = d.id 
		where  vf.id_veh_tipo_pago=3
		--and e.id = 8406


		  -----------------------------------------------------------------------------------
		------- Datos sobre cuotas del pedido (Credito Directo)  ---------
		----------------------------------------------------------------------------------
		declare @DatosHN_CredDirecto table
		(
			id int, 
			id_cot_item int,
			id_cot_item_lote int,
			id_veh_hn_enc int,
			Valor_CD decimal(18,2)
		)
		insert @DatosHN_CredDirecto
		select 	d.id, 
				d.id_cot_item,
				d.id_cot_item_lote,
				d.id_veh_hn_enc,
				Valor_CD=CAST(sum(isnull(cc.valor_cuota,0))AS DECIMAL(18,2))
		from @Docs d
		JOIN veh_hn_enc e ON e.id = d.id_veh_hn_enc
		join dbo.veh_hn_pedidos hnp with(nolock) on hnp.id_veh_hn_enc = e.id
		LEFT JOIN cot_pedido_cuotas cc with(nolock) ON cc.id_cot_pedido=hnp.id_cot_pedido
		group by d.id, 
				 d.id_cot_item,
				 d.id_cot_item_lote,
				 d.id_veh_hn_enc


		-----------------------------------------------------------------------------------
		------- Resumen formas de pago  ---------
		-----------------------------------------------------------------------------------
		declare @DatosHN_FormapResumen table
		(
				id int, 
				id_hn int,
				id_cot_item int,
				id_cot_item_lote int,	
				Forma_Pago nvarchar(10),
				Financiera nvarchar(100),
				Fec_Apro_fi DATETIME,
				Valor_anti MONEY,
				Valor_fin MONEY,
				Valor_NotaCredito MONEY,
				Valor_Vh_US MONEY,
				Saldo_Finan MONEY,
				valor_CreditoCon MONEY
		)
		INSERT @DatosHN_FormapResumen
		select 	e.id, 
		        e.id_hn,
				e.id_cot_item,
				e.id_cot_item_lote,
				Forma_Pago=case when (select isnull(max(fhn.id),'') from @DatosHN_Formap fhn where fhn.id_veh_tipo_pago in (3) 
								and  fhn.id_hn=e.id_hn)=''
								then 'Contado' else 'Crédito'end,
				Financiera=max(e.financiera),
				Fec_Apro_fi=max(case when e.id_veh_tipo_pago in (3) then e.fecha_hora else null end),
				Valor_anti=sum(case when e.id_veh_tipo_pago in (1,7,10) then e.valor else 0 end),
				Valor_fin=sum(case when e.id_veh_tipo_pago in (3) then e.valor else 0 end),
				Valor_NotaCredito=sum(case when e.id_veh_tipo_pago in (5) then e.valor else 0 end),
				Valor_Vh_US=sum(case when e.id_veh_tipo_pago in (2,6) then e.valor else 0 end),
				Saldo_Finan=sum(
				case when e.id_veh_tipo_pago in (3) and e.id_cot_cotizacion is null then e.valor 
					 when e.id_veh_tipo_pago in (3) and e.id_cot_cotizacion is not null then isnull(f.Saldo_Finan,f.valor_fac)
				end ), 
				valor_CreditoCon= max(case when e.id_veh_tipo_pago in (8) then e.valor else null end)
		from @DatosHN_Formap e
		left join @DatosHN_Formap_finan f on e.id = f.id and e.id_cot_item_lote = f.id_cot_item_lote and e.id_hn = f.id_hn
		group by 
		e.id, 
		e.id_cot_item,
		e.id_cot_item_lote,
		e.id_hn


		-----------------------------------------------------------------------------------
		---- ---Datos de Eventos relacionados a la HN   --------------------------------
		-----------------------------------------------------------------------------------
		declare @VehEventos table
		(
			id_documento int, 
			id_cot_item_lote int,
			Entrega_Logis date,
			Dis_Solinstalacion varchar(80),
			Dis_instalado varchar(80),
			Envio_Matricula date,
			Matriculado date,
			Acceso_externa date,
			fecha_ent_acc_ext date,
			fecha_instal_dispo date,
			notas_acces_externa varchar(500),
			Recibido_Logistica date
		)
		insert @VehEventos
		select 	v.id_documento, 
				v.id_cot_item_lote,
				Entrega_Logis=case when ca.id_veh_eventos2=8 then cast(ca.fecha as date) else null end,
				Dis_Solinstalacion=case when ca.id_veh_eventos2=5 then v2.descripcion else null end,
				Dis_instalado=case when ca.id_veh_eventos2=6 then v2.descripcion else null end ,
				Envio_Matricula=case when ca.id_veh_eventos2=3 then cast(ca.fecha as date) else null end,
				Matriculado	=case when ca.id_veh_eventos2=4 then cast(ca.fecha as date) else null end,
				Acceso_externa=case when ca.id_veh_eventos2=7 then cast(ca.fecha as date) else null end,
				fecha_ent_acc_ext=case when ca.id_veh_eventos2=7 then cast(ca.fecha_modifica as date) else null end	,
				fecha_instal_dispo=case when ca.id_veh_eventos2=6 then cast(ca.fecha as date) else null end,
				notas_acces_externa=case when ca.id_veh_eventos2=7 then isnull(ca.notas,'') else null end,
				Recibido_Logistica=case when ca.id_veh_eventos2=12 then cast(ca.fecha as date) else null end
		from @VH v
		left join veh_eventos_vin ca on  ca.id_cot_item_lote=v.id_cot_item_lote  
		left join veh_eventos2 v2 on v2.id=ca.id_veh_eventos2

	
		-----------------------------------------------------------------------------------
		------- Resumen de Eventos relacionados ala HN  -----------------------------------
		-----------------------------------------------------------------------------------
		DECLARE @VehEventosResumen table
		(
			id int, 
			id_cot_item_lote int,
			Entrega_Logis date,
			Dis_Solinstalacion varchar(80),
			Dis_instalado varchar(80),
			Envio_Matricula date,
			Matriculado date,
			EstadoDispositivo varchar(80),
			Acceso_externa date,
			fecha_ent_acc_ext date,
			fecha_instal_dispo date,
			notas_acces_externa varchar(500),
			Recibido_Logistica date
		)
		insert @VehEventosResumen
		select	v.id_documento, 
				v.id_cot_item_lote,
				Entrega_Logis=max(Entrega_Logis),
				Dis_Solinstalacion=max(Dis_Solinstalacion),
				Dis_instalado=max(Dis_instalado),
				Envio_Matricula=max(Envio_Matricula) ,
				Matriculado=max(Matriculado),
				EstadoDispositivo=isnull(isnull(max(Dis_instalado),max(Dis_Solinstalacion)),'NO') ,
				Acceso_externa=max(Acceso_externa),
				fecha_ent_acc_ext=max(fecha_ent_acc_ext),
				fecha_instal_dispo=max(fecha_instal_dispo),
				notas_acces_externa=max(notas_acces_externa),
				Recibido_Logistica=max(Recibido_Logistica)
		from @VehEventos  v
		group by v.id_documento, v.id_cot_item_lote
		
		-------TEST---------------------------------------------------------------
		--EXEC [dbo].[BI_GetVehFacturados_NoEntregados] '2021-09-01','2021-09-30'
		--select *
		--from @Docs d 
		--JOIN @HojasNegocio h on (h.id_documento = d.id and h.id_cot_item_lote = d.id_cot_item_lote) --Obtenemos solo vehiculos facturados NO entregados
		--where d.id_cot_item_lote = 155512
		---------------------------------------------------------------------------
	
		declare @VehCitasPDIEntrega as table
		(
			id_cot_cotizacionfac int,
			id_tipo_cita int, 
			descripcion varchar(100),
			id int, 
			id_cot_bodega int, 
			id_cot_item_lote int, 
			fecha_creacion datetime, 
			fecha_cita datetime, 
			notas varchar(250),
			id_cot_cotizacion int,
			estado int,
			desestadocita NVARCHAR(50),
			bahia NVARCHAR(80)
		)
		INSERT @VehCitasPDIEntrega
		select	id_cot_cotizacionfac = v.id_documento,
				id_tipo_cita=t.id, 
				t.descripcion,
				tc.id, 
				tc.id_cot_bodega, 
				tc.id_cot_item_lote, 
				tc.fecha_creacion, 
				tc.fecha_cita, 
				tc.notas,
				tc.id_cot_cotizacion,
				tc.estado ,
				--desestadocita=isnull(ve.descripcion,case when cast(tc.fecha_cita as date)<cast(getdate()as date) then 'Atrasada' else   'agendada' end),
				desestadocita=CAST(CASE WHEN tc.id_cot_item_lote IS NULL AND tc.placa IS NULL THEN NULL
										WHEN te.id IS NOT NULL THEN 
												'Entregada'   --8
											WHEN ISNULL(ct.anulada, 0) = 1
												AND tip.sw = 46 THEN
												'Facturada'  --7
											WHEN ISNULL(ct.anulada, 0) = 2 THEN
												'Cerrada'		 --6
											WHEN e.cuantas > 0
												AND e.terminada >= e.cuantas THEN
												'Terminada'	  --5
											WHEN e.cuantas > 0
												AND e.pausa >= e.cuantas THEN
												'Pausada' --4 
											WHEN e.proceso > 0 THEN
												'Proceso' --3 
											WHEN tc.id_cot_cotizacion IS NOT NULL THEN
												'En OT'  --2 
											WHEN tc.estado = 101 THEN
												'Llegó'  --101 
											WHEN tc.estado = 102 THEN
												'No cumplida' --102 
											WHEN tc.id_cot_cotizacion IS NULL AND GETDATE()<=tc.fecha_cita THEN
												'Agendada' --1 Agendada
											WHEN tc.id_cot_cotizacion IS NULL AND GETDATE()>tc.fecha_cita THEN
												'Atrasada' --100 
										END AS VARCHAR),

				bahia=u.nombre
		from @VH v
		join tal_citas tc with(nolock) on tc.id_cot_item_lote=v.id_cot_item_lote
		join tal_citas_tipo t with(nolock) on t.id=tc.id_tal_citas_tipo
		join usuario u with(nolock) on u.id=tc.id_usuario
		left join v_tal_citas_estado ve with(nolock) on ve.id=tc.estado
		LEFT JOIN dbo.cot_cotizacion ct with(nolock) ON ct.id = tc.id_cot_cotizacion
		LEFT JOIN dbo.cot_tipo tip with(nolock) ON tip.id = ct.id_cot_tipo AND tip.sw IN ( 46 )
		LEFT JOIN dbo.v_tal_operaciones_estado e with(nolock) ON e.id_cot_cotizacion = ct.id
		LEFT JOIN dbo.tra_cargue_enc te ON te.id_cot_cotizacion = tc.id_cot_cotizacion
		where t.id in (3,7,8,9,10,11,12)


		
		---DATOS CITA DE ENTREGA VH
		declare @citaEntrega table
		(
			id_cot_cotizacionfac int,
			id_cot_item_lote int,
			[ENTREGA_Fecha de cita] datetime,
			[ENTREGA_Nro. Cita] int,
			[ENTREGA_Notas Cita] varchar(250),
			[ENTREGA_Bahía] nvarchar(80),
			[ENTREGA_Estado] varchar(80),
			[ENTREGA_Sede] varchar(50),
			Estadocita NVARCHAR(50)

		)
		insert @citaEntrega
		select 	c.id_cot_cotizacionfac,
				c.id_cot_item_lote,
				[ENTREGA_Fecha de cita]=c.fecha_cita  ,
				[ENTREGA_Nro. Cita]=  c.id ,
				[ENTREGA_Notas Cita]=c.notas ,
				[ENTREGA_Bahía]=  c.bahia ,
				--[ENTREGA_Estado]= case 
				--				when fv.id_cot_cotizacion is not null then 'OK' else otesat.descripcion 
				--				end 
				--				+ ' ' + CAST(co.id as varchar),
				[ENTREGA_Estado]= '',
				[ENTREGA_Sede] = cb.descripcion,
				Estadocita=c.desestadocita
		from @VehCitasPDIEntrega c
		join cot_bodega cb with(nolock) on cb.id=c.id_cot_bodega
		left join cot_cotizacion co with(nolock) on co.id=c.id_cot_cotizacion  
		left join cot_tipo t with(nolock) on t.sw=co.id_cot_tipo
		left join cot_bodega_ubicacion otesat with(nolock) on otesat.id=co.id_cot_bodega_ubicacion
		--left join v_tal_ya_fue_facturado fv with(nolock) on fv.id_cot_cotizacion_sig=co.id
		where c.id_tipo_cita=3 
		and c.id = (select max(id) from @VehCitasPDIEntrega c2 where c2.id_cot_item_lote=c.id_cot_item_lote and c2.id_tipo_cita=c.id_tipo_cita)

    
	-- SELECT FINAL
	DECLARE @Resultado as table
	(
		 id_cot_bodega int,
		 [BODEGA] VARCHAR(50),
		 [LINEA_ID] INT,
		 [NOMBRE_LINEA] varchar(100),
		 id_cot_tipo int,
		 Id_documento int,
		 id_hn int,
		 Estado_HN varchar(500),
		 Familia varchar(100),
		 Linea nvarchar(100),
		 [FACTURA] VARCHAR(100),
	     [FEC_FACTURA] DATETIME,
	     [FECHA DE VENCIMIENTO] DATETIME,
	     [NIT_CLIENTE] NVARCHAR(40),
	     [RAZON_SOCIAL] NVARCHAR(200),
	     [CLASE_CLIENTE] NVARCHAR(100),
	     [VENDEDOR] NVARCHAR(160),
		 --id_asesor int,
	     [VIN] NVARCHAR(100),
	     [MODELO] VARCHAR(500),
	     RUC_FLOTA NVARCHAR(40),
	     NOMBRE_FLOTA NVARCHAR(200),
	     COLOR_EXTERNO NVARCHAR(60),
	     [ANIO_VEHICULO] INT,
	     [CANTIDAD] MONEY,
	     [COSTO_TOT_TOT] MONEY,
	     [PRECIO_UNI] MONEY,
	     [PRECIO_BRUTO] MONEY,
	     [PORCENTAJE_DESCUENTO] DECIMAL(18,10),
	     [DESCUENTO] DECIMAL(18,2),
	     [OTROS_INCLUIDOS] DECIMAL(18,2),
	     [COSTO_ACC_OBLIGA] DECIMAL(18,2),
	     [PRECIO_LISTA] money,
	     [DESCUENTO_MARCA] decimal(5,2),
	     [FORMA_PAGO] nvarchar(100),
	     [FINANCIERA] nvarchar(100),
	     [CLIENTE_DE] varchar(10),
	     [DETALLE] VARCHAR(MAX),
	     [PRECIO_NETO] MONEY,
	     [ABONOS] MONEY,
	     [SALDO] MONEY,
	     [DIAS MORA] INT,
	     ID_FACTURA INT,
	     GRUPO NVARCHAR(100),
	     SUBGRUPO NVARCHAR(100),
	     [notas_lote] VARCHAR(500),
	     [ubicacionvehiculo] VARCHAR(80),
		 Segmento varchar(50),
		 Id_empresa int,
		 Nuevo_usado varchar(10),
		 Tipo_Negocio varchar(65),
		 ChevyPlan varchar(500),
		 Aseguradora nvarchar(100),
		 [Fec_Apro_finan] datetime,
		 Tipo_Credito varchar(500),
		 [Valor_anticipo] MONEY,
		 [Valor_Financiera] MONEY,
		 [Valor_CredDirecto] decimal(18,2),
		 [Valor_CredConsumo] MONEY,
		 [Saldo_Financiera] MONEY,
		 [Saldo_cliente] MONEY,
		 Dispositivo varchar(500),
		 EstadoDispositivo varchar(80),
		 [FechaInstalacion] date,
		 [Envio_Matricula] date,
		 [Matriculado] date,
		 [Dias_Matricula] int,
		 Placa varchar(50),
		 [Tecnico] nvarchar(80),
		 [ENTREGA_Estado] NVARCHAR(100),
		 FechaEstimadaEntrega DATE,
		 [Fec_tenta_entre] DATE,
		 [Tot_dias_Entre] INT,
		 [anulado] nvarchar(10),
		 Fecha_entrega_VH DATE,
		 id_nota int,
		 desc_tipo_nota varchar(100)
	)
	
	 INSERT @Resultado
     select 
	 [AGENCIA_ID]=d.id_cot_bodega
	,[NOMBRE_AGENCIA]=cb.descripcion
	,[LINEA_ID]=dcc.id
	,[NOMBRE_LINEA]=dcc.codcentro
	,id_cot_tipo = t.id
	,d.id
	,d.id_veh_hn_enc
	,h.Estado_HN
	,vh.Familia
	,vh.Linea
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
	--,id_asesor = u.id
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
							where cil.id= d.id_cot_item_lote),
	vh.Segmento,
	Id_empresa = CASE 	WHEN @emp = 605 then 1
						WHEN @emp = 601 then 4
					end,
	vh.Nuevo_Usado,
	h.Tipo_Negocio,
	h.ChevyPlan,
	h.Aseguradora,
	fpr.Fec_Apro_fi,
	h.Tipo_Credito,
	fpr.Valor_anti,
	fpr.Valor_fin,
	[Valor_CredDirecto] = hncd.Valor_CD,
	[valor_CredConsumo] = fpr.valor_CreditoCon,
	[Saldo_Finan]=fpr.Saldo_Finan,
	[Saldo_cliente]=vs.saldo,
	h.Dispositivo,
	[Estado_disp]=ver.EstadoDispositivo,
	[FechaInstalacion]=ver.fecha_instal_dispo,
	[Envio_Matricula]=ver.Envio_Matricula,
	[Matriculado]=ver.Matriculado,
	[Dias_Matricula]=datediff(day,cast(ver.Envio_Matricula as date),isnull(ver.Matriculado,cast(getdate() as date))) - dbo.fn_dias_nolaborales(cast(ver.Envio_Matricula as date),isnull(ver.Matriculado,cast(getdate() as date))),
	[Placa]=case when ver.Matriculado is null then '' else vh.placa	end,
	[Tecnico]=cent.[ENTREGA_Bahía],
	--[ENTREGA_Estado]=case when cent.[ENTREGA_Nro. Cita] is not null then isnull(cent.[ENTREGA_Estado],cent.Estadocita) else '' end,
	[ENTREGA_Estado]='',
	[FechaEstimadaEntrega]=CAST(h.FechaEstimadaEntrega AS DATE),
	-------------------------
	[Fec_tenta_entre]=
								 case 
								 -- se valida que la fecha termine  en sabado para pasar al lunes
								 when datepart(dw,case 
														when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,8,cast(d.fecha  as date)),cast(getdate() as date))) ),Dateadd(d,8,cast(d.fecha  as date)) 						)
														when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,18,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,18,cast(d.fecha  as date)) )
														when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,10,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,10,cast(d.fecha  as date)) )
														when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,20,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,20,cast(d.fecha  as date)) )
													end)=7 then  dateadd(d,2 ,					
																case 
																	when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,8,cast(d.fecha  as date)),cast(getdate() as date))) ),Dateadd(d,8,cast(d.fecha  as date)) 						)
																	when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,18,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,18,cast(d.fecha  as date)) )
																	when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,10,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,10,cast(d.fecha  as date)) )
																	when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,20,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,20,cast(d.fecha  as date)) )
																end	)
								-- se valida que la fecha termine en domingo  para pasar al lunes
								when datepart(dw,case 
														when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,8,cast(d.fecha  as date)),cast(getdate() as date))) ),Dateadd(d,8,cast(d.fecha  as date)) 						)
														when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,18,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,18,cast(d.fecha  as date)) )
														when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,10,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,10,cast(d.fecha  as date)) )
														when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,20,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,20,cast(d.fecha  as date)) )
													end)=1 then  dateadd(d,1 ,					
																case 
																	when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,8,cast(d.fecha  as date)),cast(getdate() as date))) ),Dateadd(d,8,cast(d.fecha  as date)) 						)
																	when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,18,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,18,cast(d.fecha  as date)) )
																	when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,10,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,10,cast(d.fecha  as date)) )
																	when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,20,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,20,cast(d.fecha  as date)) )
																end	)


								  else
									 case 
																	when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,8,cast(d.fecha  as date)),cast(getdate() as date))) ),Dateadd(d,8,cast(d.fecha  as date)) 						)
																	when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,18,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,18,cast(d.fecha  as date)) )
																	when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,10,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,10,cast(d.fecha  as date)) )
																	when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,20,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,20,cast(d.fecha  as date)) )
																end	

								  end,
			[Tot_dias_Entre]=datediff(d,
								(
								  case 
								 -- se valida que la fecha termine  en sabado para pasar al lunes
								 when datepart(dw,case 
														when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,8,cast(d.fecha  as date)),cast(getdate() as date))) ),Dateadd(d,8,cast(d.fecha  as date)) 						)
														when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,18,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,18,cast(d.fecha  as date)) )
														when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,10,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,10,cast(d.fecha  as date)) )
														when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,20,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,20,cast(d.fecha  as date)) )
													end)=7 then  dateadd(d,2 ,					
																case 
																	when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,8,cast(d.fecha  as date)),cast(getdate() as date))) ),Dateadd(d,8,cast(d.fecha  as date)) 						)
																	when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,18,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,18,cast(d.fecha  as date)) )
																	when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,10,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,10,cast(d.fecha  as date)) )
																	when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,20,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,20,cast(d.fecha  as date)) )
																end	)
								-- se valida que la fecha termine en domingo  para pasar al lunes
								when datepart(dw,case 
														when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,8,cast(d.fecha  as date)),cast(getdate() as date))) ),Dateadd(d,8,cast(d.fecha  as date)) 						)
														when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,18,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,18,cast(d.fecha  as date)) )
														when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,10,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,10,cast(d.fecha  as date)) )
														when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,20,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,20,cast(d.fecha  as date)) )
													end)=1 then  dateadd(d,1 ,					
																case 
																	when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,8,cast(d.fecha  as date)),cast(getdate() as date))) ),Dateadd(d,8,cast(d.fecha  as date)) 						)
																	when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,18,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,18,cast(d.fecha  as date)) )
																	when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,10,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,10,cast(d.fecha  as date)) )
																	when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,20,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,20,cast(d.fecha  as date)) )
																end	)


								  else
									 case 
																	when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,8,cast(d.fecha  as date)),cast(getdate() as date))) ),Dateadd(d,8,cast(d.fecha  as date)) 						)
																	when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,18,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,18,cast(d.fecha  as date)) )
																	when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,10,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,10,cast(d.fecha  as date)) )
																	when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,20,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,20,cast(d.fecha  as date)) )
																end	

								  end
								)
								,
								cast(isnull( h.VH_Entregado ,getdate() )as date)  
								) 
								-
								dbo.fn_dias_nolaborales  ---restar lo dias  no laboraes al final del calculo
								(
								 case 
								 -- se valida que la fecha termine  en sabado para pasar al lunes
								 when datepart(dw,case 
														when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,8,cast(d.fecha  as date)),cast(getdate() as date))) ),Dateadd(d,8,cast(d.fecha  as date)) 						)
														when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,18,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,18,cast(d.fecha  as date)) )
														when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,10,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,10,cast(d.fecha  as date)) )
														when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,20,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,20,cast(d.fecha  as date)) )
													end)=7 then  dateadd(d,2 ,					
																case 
																	when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,8,cast(d.fecha  as date)),cast(getdate() as date))) ),Dateadd(d,8,cast(d.fecha  as date)) 						)
																	when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,18,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,18,cast(d.fecha  as date)) )
																	when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,10,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,10,cast(d.fecha  as date)) )
																	when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,20,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,20,cast(d.fecha  as date)) )
																end	)
								-- se valida que la fecha termine en domingo  para pasar al lunes
								when datepart(dw,case 
														when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,8,cast(d.fecha  as date)),cast(getdate() as date))) ),Dateadd(d,8,cast(d.fecha  as date)) 						)
														when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,18,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,18,cast(d.fecha  as date)) )
														when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,10,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,10,cast(d.fecha  as date)) )
														when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,20,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,20,cast(d.fecha  as date)) )
													end)=1 then  dateadd(d,1 ,					
																case 
																	when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,8,cast(d.fecha  as date)),cast(getdate() as date))) ),Dateadd(d,8,cast(d.fecha  as date)) 						)
																	when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,18,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,18,cast(d.fecha  as date)) )
																	when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,10,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,10,cast(d.fecha  as date)) )
																	when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,20,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,20,cast(d.fecha  as date)) )
																end	)


								  else
									 case 
																	when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,8,cast(d.fecha  as date)),cast(getdate() as date))) ),Dateadd(d,8,cast(d.fecha  as date)) 						)
																	when vh.id_cot_item_talla=687  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,18,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,18,cast(d.fecha  as date)) )
																	when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Contado' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,10,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,10,cast(d.fecha  as date)) )
																	when vh.id_cot_item_talla=688  and isnull(fpr.Forma_Pago,'Contado')='Crédito' then dateadd(d,(dbo.fn_dias_nolaborales(cast(d.fecha as date),isnull(dateadd(d,20,cast(d.fecha  as date)),cast(getdate() as date))) ),dateadd(d,20,cast(d.fecha  as date)) )
																end	

								  end	

								 ,
								 cast(isnull( h.VH_Entregado ,getdate() )as date)  
								),
			d.anulado,
			h.VH_Entregado,
			id_nota = ne.id_veh_hn_notas1,
			desc_tipo_nota = ne.desc_tipo
								  
    
	from @Docs d
		--left join @HojasNegocio h on (h.id_documento = d.id and h.id_cot_item_lote = d.id_cot_item_lote and h.Estado_HN not in ('Entregado el vehículo'))
	JOIN @HojasNegocio h on (h.id_documento = d.id and h.id_cot_item_lote = d.id_cot_item_lote) --Obtenemos solo vehiculos facturados NO entregados
	JOIN dbo.cot_tipo t ON t.id = d.id_cot_tipo
	JOIN dbo.cot_item i ON i.id = d.id_cot_item
	LEFT JOIN @VH vh on d.id = vh.id_documento and d.id_cot_item_lote = vh.id_cot_item_lote
	LEFT JOIN cot_bodega cb on cb.id=d.id_cot_bodega
	LEFT JOIN dbo.com_orden_concep co ON co.id = d.id_com_orden_concep
    LEFT JOIN dbo.cot_cliente cc ON cc.id = d.id_cot_cliente
    LEFT JOIN dbo.cot_cliente_Perfil cp ON cp.id = cc.id_cot_cliente_perfil
    LEFT JOIN dbo.usuario u ON u.id = d.id_usuario_vende
	LEFT JOIN dbo.cot_item_lote il ON il.id_cot_item = d.id_cot_item AND il.id = d.id_cot_item_lote
    left join veh_color col1 on col1.id=il.id_veh_color
    JOIN dbo.cot_grupo_sub s ON s.id = i.id_cot_grupo_sub
    JOIN dbo.cot_grupo g ON g.id = s.id_cot_grupo
    LEFT JOIN dbo.cot_forma_pago fp ON fp.id = d.id_cot_forma_pago
    LEFT JOIN @Devoluciones dv ON dv.id = d.id
    LEFT JOIN dbo.ecu_tipo_comprobante et ON et.id = t.id_ecu_tipo_comprobante
	LEFT JOIN @accesoriosvehiculos av ON av.id = d.id
    LEFT JOIN @datoslista_dcto ld ON ld.id_cot_item=d.id_cot_item AND ld.id_cot_item_lote=d.id_cot_item_lote AND  ld.id=d.id
    LEFT JOIN @flota f ON f.id_cot_item=d.id_cot_item AND f.id_cot_item_lote=d.id_cot_item_lote and f.id=d.id
    LEFT JOIN @docco dcc ON dcc.id = d.Id AND dcc.id_cot_tipo = d.id_cot_tipo
    left join @DatosHN_Formap_finan fn on fn.id = d.id

	left join @DatosHN_FormapResumen fpr on fpr.id = d.id and fpr.id_cot_item_lote = d.id_cot_item_lote
	left join @DatosHN_CredDirecto hncd  on hncd.id = d.id and hncd.id_cot_item_lote = d.id_cot_item_lote
	left join v_cot_factura_saldo vs on vs.id_cot_cotizacion = d.id
	left join @VehEventosResumen ver on ver.id = d.id and ver.id_cot_item_lote = d.id_cot_item_lote
	left join @citaEntrega cent  on cent.id_cot_cotizacionfac = d.id and cent.id_cot_item_lote = d.id_cot_item_lote
    --where h.id_documento is null
	--where d.id = 401253
	left join @Notas_Especificas_HN ne on ne.id_veh_hn_enc = h.id_hn
	WHERE ISNULL(cp.descripcion,'0') not in ('CONCESIONARIO','RELACIONADAS')
	

	
		-- EXEC [dbo].[BI_V_GetVehFacturados_NoEntregados_Borrador20220505] '2021-03-31'
		
	-- SELECT FINAL
	SELECT 	 r.id_cot_bodega,
			 r.[BODEGA],
			 r.[LINEA_ID],
			 r.[NOMBRE_LINEA],
			 r.[FACTURA],
			 r.id_cot_tipo,
			 r.Id_documento,
			 r.id_hn,
			 r.Estado_HN,
			 r.Familia,
			 r.Linea,
			 r.[FEC_FACTURA],
			 r.[FECHA DE VENCIMIENTO],
			 r.[NIT_CLIENTE],
			 r.[RAZON_SOCIAL],
			 r.[CLASE_CLIENTE],
			 r.[VENDEDOR],
			 r.[VIN],
			 r.MODELO,
			 r.RUC_FLOTA,
			 r.NOMBRE_FLOTA,
			 r.COLOR_EXTERNO,
			 r.[ANIO_VEHICULO],
			 r.[CANTIDAD],
			 r.[COSTO_TOT_TOT],
			 r.[PRECIO_UNI],
			 r.[PRECIO_BRUTO],
			 r.[PORCENTAJE_DESCUENTO],
			 r.[DESCUENTO],
			 r.[OTROS_INCLUIDOS],
			 r.[COSTO_ACC_OBLIGA],
			 r.[PRECIO_LISTA],
			 r.[DESCUENTO_MARCA],
			 r.[FORMA_PAGO],
			 r.[FINANCIERA],
			 r.[CLIENTE_DE],
			 r.[DETALLE],
			 r.[PRECIO_NETO],
			 r.[ABONOS],
			 r.[SALDO],
			 r.[DIAS MORA],
			 r.ID_FACTURA,
			 r.GRUPO,
			 r.SUBGRUPO,
			 r.[notas_lote],
			 r.[ubicacionvehiculo],
			 r.Segmento,
			 r.Id_empresa,
			 r.Nuevo_usado,
			 r.Tipo_Negocio,
			 r.ChevyPlan,
			 r.Aseguradora,
			 r.Fec_Apro_finan,
			 r.Tipo_Credito,
			 r.Valor_anticipo,
			 r.Valor_Financiera,
			 r.Valor_CredDirecto,
			 r.Valor_CredConsumo,
			 r.[Saldo_Financiera],
			 r.Saldo_cliente,
			 r.Dispositivo,
			 r.EstadoDispositivo,
			 r.FechaInstalacion,
			 r.Envio_Matricula,
			 r.Matriculado,
			 r.[Dias_Matricula],
			 r.placa,
			 r.tecnico,
			 r.[ENTREGA_Estado],
			 r.[FechaEstimadaEntrega],
			 r.[Fec_tenta_entre],
			 r.[Tot_dias_Entre],
			 r.anulado,
			 r.Fecha_entrega_VH,
			 r.id_nota,
			 r.desc_tipo_nota
	FROM @Resultado r
	
	