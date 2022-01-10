SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =======================================================================================================================================
-- Author:		<Javier Chogllo / INNOVA>
-- Create date: <2021-02-17>
-- Description:	<Procedimiento que obtiene informacion del proceso de Ventas de Vehiculos, se utiliza para 
--				 alimentar la tabla FactVentaVehiculos que se utiliza en el Datawarehouse de Proauto 

--              2021-03-09 Modificado Javier Chogllo agrgacion de la tabla @Compras para obtener inf de compras de veh.
--              28-04-2021 (Ajuste de los valores con Rebate / SP utlizado SP_GETVISOR_MAPAI_v2) JCH/INNOVA>
--				21-05-2021 (Modificacion para encontrar devoluciones del sistema anterior (Kairoz))
--				21-05-2021 (Ajuste de los valores con Rebate / SP utlizado GetVentasProducto JCH/INNOVA)
--              24-09-2021 (Se modifica la tabla temporal @Bodegas para que utilice unicamente las bodegas de Vehiculos) (JCB)
--              24-09-2021 (Se elimina el campo NotasDebito, las notas de debito se van a insertar como registros en la tabla FactVentaVehiculos) (JCB)
--              28-09-2021 (Se agrega la tabla @ComplementosGAC que contiene el costo de los complementos que deben sumarse al cosot del vehiculo) (JCB)
--              30-09-2021 (Se modifica el calculo de la columna Rebate para que sume mas de un rebate por vehiculo) (JCB)
--              30-09-2021 (Se cambia el nombre a BI_GetVentaVehiculos y se modifica para que reciba como parametro las fecha inicio y fin )
--              01-10-2021 (Se ajusta para que el valor del complemente se sume a la venta Neta) (JCB)
--              02-12-2021 (Se ajusta la venta de accesorios con el Vehiculo, se toma unicamente el GRUPO "ACCESORIOS") (JCB)
--				03-12-2021 (Se ajusta las notas de debito para que se obtenga solo de la empresa 605) (JCB)
--				13-12-2021 (Se ajusta la suma de KIT Mandatorio a los vehiculos de la marca VolkWagen) (JCB)
--				27-12-2021 (Se agrega el campo NitCliente, que es el cliente al que se factura el Vehiculo) (JCB)
-- =======================================================================================================================================

-- exec [dbo].[BI_V_GetVentaVehiculos] '2021-11-01','2021-11-30'
ALTER PROCEDURE [dbo].[BI_V_GetVentaVehiculos]
(
	@FecDesde DATE,
	@FecHasta DATE 
)
AS
BEGIN

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DECLARE @emp INT = 601 -- Autofactor
	DECLARE @emp2 INT = 605 -- Proauto

    -------------------------------------------------------------------------------
	----------------------------     BODEGAS    --------------------------------
	-------------------------------------------------------------------------------	
	DECLARE @Bodega AS TABLE
	(
		id INT,
		descripcion VARCHAR(200),
		ecu_establecimiento VARCHAR(6)
	)
	INSERT @Bodega
	(
		id,
		descripcion,
		ecu_establecimiento
	)
	SELECT  b.id,
			b.descripcion,
			b.ecu_establecimiento
	FROM dbo.cot_bodega b 
	where b.id_emp IN (@emp2)
	and b.descripcion NOT like '% REP%' AND b.descripcion NOT like '% TAL%'  --QUITAMOS BODEGAS DE REPUESTOS Y TALLERES
	AND  b.descripcion NOT like '% ADM%'  -- QUITAMOS BODEGAS DE ADMINISTRACION
	AND  b.descripcion NOT IN ('999-BODEGA DCTOS FISICOS',
	                           'TRANSITO TRASLADOS',
							   '002 - CAJA ESPECIAL',
							   '101PM - VEHICULOS QUITO GAC PRUEBAS MANEJO',
							   '99.9.1 - TRANSITO VEHICULOS',
							   'ZZZZZ - QTO (NO USAR)')
	

	-------------------------------------------------------------------------------
	----------------------------    INFO DOCUMENTOS    --------------------------------
	-------------------------------------------------------------------------------
	DECLARE @Docs AS TABLE
	(
		id INT,
		id_cot_tipo INT,
		id_cot_bodega INT,
		id_cot_cliente INT,
		id_cot_cliente_contacto INT,
		numero_cotizacion INT,
		fecha DATE,
		id_cot_item INT,
		id_cot_item_lote INT,
		cantidad_und DECIMAL(18, 2),
		precio_lista DECIMAL(18, 2),
		precio_cotizado DECIMAL(18, 2),
		costo DECIMAL(18, 2),
		porcentaje_descuento DECIMAL(18, 2),
		porcentaje_descuento2 DECIMAL(18, 2),
		porcentaje_iva DECIMAL(18, 2),
		id_com_orden_concepto INT,
		ecu_establecimiento VARCHAR(4),
		id_usuario_ven INT,
		id_forma_pago INT,
		sw INT,
		saldo DECIMAL(18, 2),
		id_cot_pedido_item INT,
		docref_tipo VARCHAR(20),
		docref_numero VARCHAR(30),
		id_veh_hn_enc iNT, 
		id_cot_cotizacion_item int,
		total_total money,
		total_descuento money,
		tipo_operacion char(2), 
		id_cot_item_lote_cab  int ,
		id_cot_cotizacion_sig int ,
		id_operario int,
		id_usuario_fac int,
		id_emp int
	)

	INSERT @Docs
	SELECT
	   cotz.id,
       cotz.id_cot_tipo,
       cotz.id_cot_bodega,			 
       cotz.id_cot_cliente,
	   cotz.id_cot_cliente_contacto ,
       cotz.numero_cotizacion,
       cotz.fecha,
       cotci.id_cot_item,
       cotci.id_cot_item_lote,
       cantidad_und = cotci.cantidad_und*cott.sw,
       cotci.precio_lista,
       cotci.precio_cotizado,
       cotci.costo_und,
       cotci.porcentaje_descuento,
       cotci.porcentaje_descuento2,
       cotci.porcentaje_iva,
	   cotz.id_com_orden_concep,
       cotb.ecu_establecimiento,
       cotz.id_usuario_vende,
       cotz.id_cot_forma_pago,
       cott.sw,
       saldo = cotz.total_total - ISNULL(s.valor_aplicado, 0),
       cotci.id_cot_pedido_item, 
	   cotz.docref_tipo, 
	   cotz.docref_numero,
	   cotz.id_veh_hn_enc,
	   id_cot_cotizacion_item=cotci.id,
	   cotz.total_total,
	   cotz.total_descuento,
	   cotci.tipo_operacion	,
	   cotz.id_cot_item_lote,
	   cotz.id_cot_cotizacion_sig,
	   cotci.id_operario,
	   cotz.id_usuario,
	   cotz.id_emp--gmb,
	FROM dbo.cot_cotizacion cotz 
	JOIN dbo.cot_tipo cott ON cott.id = cotz.id_cot_tipo
	JOIN dbo.cot_cotizacion_item cotci ON cotci.id_cot_cotizacion = cotz.id
	JOIN @Bodega cotb ON cotb.id = cotci.id_cot_bodega
	LEFT JOIN dbo.v_cot_factura_saldo s  ON s.id_cot_cotizacion = cotz.id
	WHERE cotz.id_emp in (@emp2)
	AND cott.sw in (1, -1)
	--AND cotz.fecha BETWEEN '2021-02-01 00:00:00.000' AND '2021-02-28 23:59:59.000' --Test febrero 248 registros / 14 devoluciones kairos
	AND cast(cotz.fecha as date) between @FecDesde and @FecHasta
	AND ISNULL(cotz.anulada,0) = 1
	
	-----------------------------------------------------------------------------------------------------
	----------Validad Complementos (Kit Mandatorios) en la marca GAC    --------------------------------
	-----------------------------------------------------------------------------------------------------
	--declare @ComplementosGAC AS table
	--(
	--	id int,
	--	id_cot_cotizacion_item int,
	--	id_cot_item int,
	--	descripcion varchar(200),
	--	cantidad_und DECIMAL(18, 2),
	--	costo DECIMAL(18, 2),
	--	precio_cotizado decimal(18,2),
	--	precio_lista decimal(18,2)
	--)
	--insert @ComplementosGAC
	--select d.id,
	--       d.id_cot_cotizacion_item,
	--	   ci.id_cot_item,
	--	   i.descripcion,
	--	   cantidad_und = ci.cantidad_und * d.sw,
	--	   ci.costo_und,
	--	   ci.precio_cotizado,
	--	   ci.precio_lista
	--from @Docs d
	--join cot_cotizacion_item ci on ci.id = d.id_cot_cotizacion_item
	--join cot_item i on i.id = d.id_cot_item
	--join cot_grupo_sub s on (s.id = i.id_cot_grupo_sub AND s.descripcion = 'GAC')
	--join cot_grupo g on (g.id = s.id_cot_grupo and g.id = 1324) --kit mandatorio
	--join v_cot_item_descripcion vi on vi.id = i.id

	---------------------------------------------------------------------------------------------------
	--------Validad Complementos (Kit Mandatorios) en la marca GAC    --------------------------------
	---------------------------------------------------------------------------------------------------
	declare @Complementos_GAC_VW AS table
	(
		id int,
		id_cot_cotizacion_item int,
		id_cot_item int,
		descripcion varchar(200),
		cantidad_und DECIMAL(18, 2),
		costo DECIMAL(18, 2),
		precio_cotizado decimal(18,2),
		precio_lista decimal(18,2)
	)
	insert @Complementos_GAC_VW
	select d.id,
	       d.id_cot_cotizacion_item,
		   ci.id_cot_item,
		   i.descripcion,
		   cantidad_und = ci.cantidad_und * d.sw,
		   ci.costo_und,
		   ci.precio_cotizado,
		   ci.precio_lista
	from @Docs d
	join cot_cotizacion_item ci on ci.id = d.id_cot_cotizacion_item
	join cot_item i on i.id = d.id_cot_item
	join cot_grupo_sub s on (s.id = i.id_cot_grupo_sub AND s.descripcion in ('GAC','VOLKSWAGEN'))
	join cot_grupo g on (g.id = s.id_cot_grupo and g.id = 1324) --kit mandatorio
	join v_cot_item_descripcion vi on vi.id = i.id

	-- exec [dbo].[BI_V_GetVentaVehiculos_Dispositivos] '2021-11-01','2021-11-30'

		
	--- Incrementamos el valor del costo de compra de vehiculos GAC con Complemento
	--update d set d.costo = ABS((d.costo * d.cantidad_und) + (k.cantidad_und * k.costo)),
	--             d.precio_cotizado = ABS((d.precio_cotizado * d.cantidad_und) + (k.cantidad_und * k.precio_cotizado)),
	--			 d.precio_lista = ABS((d.precio_lista * d.cantidad_und) + (k.cantidad_und * k.precio_lista))
	--from @Docs d
	--join @ComplementosGAC k on (k.id = d.id and k.id_cot_item != d.id_cot_item)

	

	update d set d.costo = ABS((d.costo * d.cantidad_und) + (k.cantidad_und * k.costo)),
	             d.precio_cotizado = ABS((d.precio_cotizado * d.cantidad_und) + (k.cantidad_und * k.precio_cotizado)),
				 d.precio_lista = ABS((d.precio_lista * d.cantidad_und) + (k.cantidad_und * k.precio_lista))
	from @Docs d
	JOIN cot_item i on i.id = d.id_cot_item
	JOIN dbo.cot_grupo_sub s ON s.id = i.id_cot_grupo_sub
	JOIN dbo.cot_grupo g ON (g.id = s.id_cot_grupo AND g.descripcion = 'VEHICULOS')
	join @Complementos_GAC_VW k on d.id = k.id
		
	---------------------------------------------------------------------------------------------------
	-------- Obtenemos las Notas de Debito relacionadas a un vehiculo   --------------------------------
	---------------------------------------------------------------------------------------------------
	declare @NotasDebito as table
	(
		id int,
		numero_cotizacion_ref int,
		id_cot_bodega int,
		id_cot_cliente int,
		id_emp int,
		fecha datetime,
		sw int,
		TipoDocumento nvarchar(100),
		anulada smallint,
		total_sub int,
		total_iva int,
		total_total int,
		vin nvarchar(100),
		id_cot_item_lote int,
		id_cot_item int
	)
	insert @NotasDebito
	select          n.id,
					numero_cotizacion_ref = cast(n.docref_numero as int),
					n.id_cot_bodega,
					n.id_cot_cliente,
					n.id_emp,
					n.fecha,
					t.sw,
					t.descripcion,
					n.anulada,
					n.total_sub,
					n.total_iva,
					n.total_total,
					l.vin,
					id_cot_item_lote = l.id,
					l.id_cot_item
	from cot_cotizacion n 
	join cot_tipo t  on t.id = n.id_cot_tipo
	join v_cot_factura_saldo s on n.id = s.id_cot_cotizacion
	join cot_item_cam c on (n.id = c.id_cot_cotizacion)
	join cot_item_lote l on RTRIM(LTRIM(l.vin)) = RTRIM(LTRIM(c.contenido))
	join cot_item i on l.id_cot_item = i.id and i.id_emp = @emp2
	where t.sw = 1 and t.descripcion like '%not%debit%'
	--and n.docref_numero is not null 
	AND ISNULL(n.anulada,0) <> 4 --excluir anuladas
	and n.id_emp = @emp2
	and cast(n.fecha as date) between @FecDesde and @FecHasta
	
	-- Actualizamos el campo [id_cot_item_lote] en las notas de debito que tienen un CHASIS de referencia
	update d set d.id_cot_item_lote = nd.id_cot_item_lote, d.id_cot_item = nd.id_cot_item
	from @Docs d 
	join @NotasDebito nd on (d.id = nd.id )

	
    ------------------------------------------------------------------------------------------------------------------------------
	----------------------------    VALIDAR NOTAS DE CREDITO SISTEMA KAIROZ "CON FACTURA RELACIONADA"  ----------------------------
    -- Obtenemos las notas de credito migradas del sistema anterior Kairoz (sw=-1), para las cuales se quemo en 
	-- el campo id_cot_item_lote enla cabecera (cot_cotizacion) el codido del vehiculo, para poder relacionar 
	-- con la factura original
	------------------------------------------------------------------------------------------------------------------------------
    declare @NC_DevolucionesKAIROZ_ConFacturaOrigen table
	(
		devKairozCF_id int not null,
		devKairozCF_id_cot_item_lote int not null,
		devKairozCF_id_cot_item int not null,
		devKairozCF_id_cot_bodega int not null,
		id_FacturaOrigen int not null,
		id_cot_item_lote_FacturaOrigen int not null,
		id_cot_item_FacturaOrigen int not null,
		id_cot_bodega_FacturaOrigen int not null
	)
	insert into @NC_DevolucionesKAIROZ_ConFacturaOrigen
	select --distinct 
	       dev_kairoz_CF.id,
		   dev_kairoz_CF.id_cot_item_lote_cab,
		   dev_kairoz_CF.id_cot_item,
		   dev_kairoz_CF.id_cot_bodega,
		   d.id,
		   d.id_cot_item_lote,
		   d.id_cot_item,
		   d.id_cot_bodega
	from @Docs dev_kairoz_CF --Devolucion Con Factura
	--join dbo.cot_item i  on (i.id = dev_kairoz_CF.id_cot_item and i.descripcion like '%VENTA%VEH%KAIROS') 
	join dbo.cot_item i  on (i.id = dev_kairoz_CF.id_cot_item and i.descripcion like '%DEVOLUCION%NC%AFECTA%VEH%SISTEMA%ANTERIOR%') 
	
	join @Docs d on d.id_cot_item_lote = dev_kairoz_CF.id_cot_item_lote_cab
	where isnull(dev_kairoz_CF.id_cot_item_lote_cab,0) > 0
	and dev_kairoz_CF.sw = -1

	update d set d.id_cot_item_lote = k.id_cot_item_lote_FacturaOrigen,
				d.id_cot_item = k.id_cot_item_FacturaOrigen,
				d.id_cot_bodega = k.id_cot_bodega_FacturaOrigen
	from @Docs d
	--join dbo.cot_item i  on (i.id = d.id_cot_item and i.descripcion like '%VENTA%VEH%KAIROS') 	
	join dbo.cot_item i  on (i.id = d.id_cot_item and i.descripcion like '%DEVOLUCION%NC%AFECTA%VEH%SISTEMA%ANTERIOR%') 	
	join @NC_DevolucionesKAIROZ_ConFacturaOrigen k on (d.id = k.devKairozCF_id and 
										d.id_cot_item = k.devKairozCF_id_cot_item and 
										d.id_cot_bodega = k.devKairozCF_id_cot_bodega and
										d.id_cot_item_lote_cab = k.devKairozCF_id_cot_item_lote)
	
    -----------------------------------------------------------------------------------------------------------------------------------------------
	----------------------------    VALIDAR NOTAS DE CREDITO SISTEMA KAIROZ "SIN FACTURA RELACIONADA"   -------------------------------------------
    -- Obtenemos las notas de credito migradas del sistema anterior Kairoz (sw=-1), para las cuales se quemo manualmente en 
	-- el campo id_cot_item_lote en la cabecera (cot_cotizacion) el codido del vehiculo, en este caso relacionamos con el Vehiculo (COT_ITEM_LOTE)
	-- directamente debido a que no existe la Factura Original
	-----------------------------------------------------------------------------------------------------------------------------------------------
	
	declare @NC_DevolucionesKAIROZ_SinFacturaOrigen table
	(
		devKairozSF_id int not null,
		devKairozSF_id_cot_item_lote int not null,
		devKairozSF_id_cot_item int not null,
		devKairozSF_id_cot_bodega int not null,
		--id int not null,
		id_cot_item_lote int not null,
		id_cot_item int not null
		--id_cot_bodega int not null
	)
	insert into @NC_DevolucionesKAIROZ_SinFacturaOrigen
	select --distinct 
	       dev_kairoz_SF.id,
		   dev_kairoz_SF.id_cot_item_lote_cab,
		   dev_kairoz_SF.id_cot_item,
		   dev_kairoz_SF.id_cot_bodega,
		   l.id,
		   l.id_cot_item
	from @Docs dev_kairoz_SF
	--join dbo.cot_item i  on (i.id = dev_kairoz_SF.id_cot_item and i.descripcion like '%VENTA%VEH%KAIROS') 
	join dbo.cot_item i  on (i.id = dev_kairoz_SF.id_cot_item and i.descripcion like '%DEVOLUCION%NC%AFECTA%VEH%SISTEMA%ANTERIOR%') 
	JOIN dbo.cot_item_lote l  on dev_kairoz_SF.id_cot_item_lote_cab = l.id
	--join dbo.cot_cotizacion_item ci on ci.id_cot_item_lote = l.id
	--join cot_item il on il.id = ci.id_cot_item
	where isnull(dev_kairoz_SF.id_cot_item_lote_cab,0) > 0
	and dev_kairoz_SF.id not in (select devKairozCF_id FROM @NC_DevolucionesKAIROZ_ConFacturaOrigen )
	and dev_kairoz_SF.sw = -1

	update d set d.id_cot_item_lote = k.id_cot_item_lote,
				d.id_cot_item = k.id_cot_item
    from @Docs d
	--join dbo.cot_item i  on (i.id = d.id_cot_item and i.descripcion like '%VENTA%VEH%KAIROS') 
	join dbo.cot_item i  on (i.id = d.id_cot_item and i.descripcion like '%DEVOLUCION%NC%AFECTA%VEH%SISTEMA%ANTERIOR%') 
	join @NC_DevolucionesKAIROZ_SinFacturaOrigen k on (d.id = k.devKairozSF_id and 
										d.id_cot_item = k.devKairozSF_id_cot_item and 
										d.id_cot_bodega = k.devKairozSF_id_cot_bodega and
										d.id_cot_item_lote_cab = k.devKairozSF_id_cot_item_lote)
	
	--------------------------------------------------------------------------
	----------------------------   REBATES   ----------------------------------
	--------------------------------------------------------------------------
	DECLARE @NotaRebate AS TABLE
	(
		[id] INT,
		[idnota] INT NOT NULL,
		[total_sub] MONEY
	)
	INSERT INTO @NotaRebate
	SELECT DISTINCT 
	d.id,
	idnota=n.id, 
	n.total_sub
	FROM dbo.cot_notas_deb_cre n
	JOIN @Docs d
	ON cast(d.id AS VARCHAR(10)) = n.docref_numero	
	where n.id_emp IN (601,605)
	and cast(n.fecha as date) between @FecDesde and @FecHasta
	AND n.anulada is NULL

	----------------------------------------------------------------------------------------------------
	----------------   Rebate del mes actual aplicados a facturas de meses anteriores   ----------------
	----------------------------------------------------------------------------------------------------
	declare @Rebates_Facturas_Anteriores as table
	(
		id_rebate int,
		id_cot_tipo int,
		fecha date,
		total_sub money,
		docref_tipo varchar(50),
		docref_numero varchar(50),
		id_cot_cotizacion_item int,
		id_factura int,
		id_cot_item_lote int,
		id_cot_item int,
		id_emp int
	)

	insert @Rebates_Facturas_Anteriores
	SELECT DISTINCT 
		   n.id,
		   n.id_cot_tipo,
		   cast(n.fecha as date),
		   n.total_sub,
		   n.docref_tipo,
		   n.docref_numero,
		   ci.id_cot_cotizacion_item,
		   id_factura = fac.id,
		   ci.id_cot_item_lote,
		   ci.id_cot_item,
		   n.id_emp
	FROM dbo.cot_notas_deb_cre n
	JOIN cot_cotizacion fac ON cast(fac.id AS VARCHAR(10)) = n.docref_numero
	join cot_cotizacion_item ci on ci.id_cot_cotizacion = fac.id
	join cot_item_lote l on l.id = ci.id_cot_item_lote and ci.id_cot_item = l.id_cot_item
	join cot_tipo t on (t.id = fac.id_cot_tipo and t.sw = 1)
	--join cot_tipo tn on n.id_cot_tipo = tn.id
	where cast(n.fecha as date) between @FecDesde and @FecHasta
	and ISNULL(fac.anulada,0) = 1
	and n.id_emp IN (601,605)
	AND n.anulada is NULL
	and n.id not in (select idnota from @NotaRebate)
	
	-- Insertamos en Docs informacion relacionada con las proviciones
	insert @Docs
	SELECT r.id_rebate,
		   r.id_cot_tipo,
		   c.id_cot_bodega,
		   c.id_cot_cliente,
		   c.id_cot_cliente_contacto,
		   c.numero_cotizacion,
		   fecha_rebate = cast(r.fecha as date),
		   r.id_cot_item,
		   r.id_cot_item_lote,
		   cantidad_und = 0,
		   precio_lista = 0,
		   precio_cotizado = 0,
		   costo = 0,
		   total_descu = 0,
		   porcentaje_descuento2 = 0,
		   porcentaje_iva = 0,
		   id_com_orden_concepto = 0,
		   ecu_establecimiento=0,
		   c.id_usuario_vende,
		   c.id_cot_forma_pago,
		   tr.sw,
		   saldo = 0,
		   id_cot_pedido_item = 0,
		   r.docref_tipo,
		   r.docref_numero,
		   c.id_veh_hn_enc,
		   r.id_cot_cotizacion_item,
		   total_total = 0,
		   total_descu = 0,
		   NULL,
		   NULL,
		   NULL,
		   NULL,
		   id_usuario_fac = 0,
		   r.id_emp
	from @Rebates_Facturas_Anteriores r
	join cot_cotizacion c on (c.id = r.id_factura and c.id_emp in (@emp,@emp2))
	join cot_tipo t on t.id = c.id_cot_tipo
	join cot_bodega b on b.id = c.id_cot_bodega
	join cot_tipo tr on tr.id = r.id_cot_tipo
	
	
	
	-------------------------------------------------------------------------------
	----------------------------    INFO VEHICULOS    --------------------------------
	-------------------------------------------------------------------------------
	DECLARE @VH AS TABLE
	(
		[id] INT,
		[id_cot_item] INT,
		[id_cot_item_lote] INT,
		[docref_numero] VARCHAR(30),
		[vin] NVARCHAR(50) NOT NULL,
		[id_veh_hn_enc] INT,
		id_veh_estado INT,
		id_cot_tipo INT,
		sw int,
		id_emp int
	)
	INSERT @VH
	SELECT  x.id,x.id_cot_item,x.id_cot_item_lote,x.docref_numero,x.vin,x.id_veh_hn_enc,x.id_veh_estado,x.id_cot_tipo,x.sw,x.id_emp
	FROM (
			SELECT DISTINCT 
					d.id,
					d.id_cot_item,
					d.id_cot_item_lote,
					d.docref_numero ,
					cotil.vin,
					d.id_veh_hn_enc,
					id_veh_estado = e.id,
					d.id_cot_tipo,
					d.sw,
					d.id_emp
			FROM @Docs d
			JOIN dbo.cot_item_lote cotil  ON cotil.id=d.id_cot_item_lote AND cotil.id_cot_item=d.id_cot_item
			LEFT JOIN dbo.veh_hn_enc v  on v.id = d.id_veh_hn_enc
			LEFT JOIN [dbo].[veh_estado] e  on e.id = v.estado
			WHERE d.sw = 1 and cotil.vin IS NOT NULL
			UNION ALL
			SELECT DISTINCT 
					d.id,
					d.id_cot_item,
					d.id_cot_item_lote,
					d.docref_numero ,
					cotil.vin,
					id_veh_hn_enc = cotz.id_veh_hn_enc,
					id_veh_estado = e.id,
					d.id_cot_tipo,
					d.sw,
					d.id_emp
			FROM @Docs d
			LEFT JOIN dbo.v_cot_cotizacion_factura_dev fdev  ON fdev.id_cot_cotizacion = d.id
			JOIN dbo.cot_cotizacion cotz  ON cotz.id = fdev.id_cot_cotizacion_factura
			JOIN dbo.cot_item_lote cotil  ON cotil.id = d.id_cot_item_lote AND cotil.id_cot_item=d.id_cot_item
			LEFT JOIN dbo.veh_hn_enc v  on v.id = d.id_veh_hn_enc
			LEFT JOIN [dbo].[veh_estado] e  on e.id = v.estado
			WHERE d.sw=-1 and cotil.vin IS NOT null
	)x
		--PRINT 'Verificar update'
	--UPDATE d set id_veh_hn_enc = v.id_veh_hn_enc
	--from @Docs d
	--join @VH v on d.id=v.id 
	--and d.id_cot_item=v.id_cot_item
	--and d.id_cot_item_lote=v.id_cot_item_lote
	--where d.sw=-1

	-------------------------------------------------------------------------------------------
	----------------------------    ACCESORIOS FACTURAS VH    ---------------------------------
	-------------------------------------------------------------------------------------------
	--declare @VehAccesorios table
	--(
	--	id int,
	--	id_cot_item_lote int,
	--	Accesorios varchar(max),
	--	CantidadAccesorios  money,	
	--	TotalAccesorios money
	--)
	--insert @VehAccesorios
	--select x.id,
	--       x.id_cot_item_lote,
	--	   Accesorios = STRING_AGG(x.Accesorio,' / '),
	--	   CantidadAccesorios = SUM(x.CantidadAccesorio),
	--	   TotalAccesorios = SUM(X.Precio)
	--from
	--(
	--		SELECT  vh.id, 
	--			vh.id_cot_item_lote,
	--			Accesorio = CONCAT(item_acc.codigo,'-',item_acc.descripcion),
	--			CantidadAccesorio = t.cantidad,
	--			--Precio = t.precio,
	--			Precio = t.precio * t.cantidad,
	--			cotg.descripcion
	--		FROM @VH vh
	--		join cot_item_lote_accesorios t  on t.id_cot_item_lote  =vh.id_cot_item_lote
	--		join cot_item item_acc  on item_acc.id = t.id_cot_item
	--		join cot_item i on t.id_cot_item = i.id
	--		JOIN dbo.cot_grupo_sub cotsg ON cotsg.id = i.id_cot_grupo_sub
	--		JOIN dbo.cot_grupo cotg ON cotg.id = cotsg.id_cot_grupo
	--		where vh.sw in (1)
	--		and cotg.descripcion = 'ACCESORIOS'
	--)x
	--group by x.id, x.id_cot_item_lote

	-- Obtenemos las Facturas y Notas de Credito de Vehiculos
	declare @docs_vehiculos as table
	(
		id_documento int,
		sw int,
		id_cot_item_lote int,
		grupo nvarchar(50)
	)
	insert @docs_vehiculos
	select id_documento = d.id, 
	       d.sw,
		   d.id_cot_item_lote,
		   cotg.descripcion
	from @Docs d
	JOIN cot_item i on i.id = d.id_cot_item
	JOIN dbo.cot_grupo_sub cotsg ON cotsg.id = i.id_cot_grupo_sub
	JOIN dbo.cot_grupo cotg ON cotg.id = cotsg.id_cot_grupo
	where cotg.descripcion = 'VEHICULOS'
	--and d.id = 450139--455121--465848


	----Obtenemos las Facturas y Notas de Credito de Dispositivos
	declare @docs_dispositivos as table
	(
		id_documento int,
		sw int,
		id_cot_item int,
		cantidad int,
		precio_cotizado DECIMAL(18, 2),
		precio DECIMAL(18, 2),
		grupo nvarchar(50),
		descripcion varchar(200)
	)
	insert @docs_dispositivos
    select d.id,
	       d.sw,
		   d.id_cot_item,
		   cast(d.cantidad_und as int),
		   d.precio_cotizado,
		   --precio = d.precio_cotizado * IIF(d.cantidad_und=0,1,d.cantidad_und) * IIF(d.sw = 1,1,-1),
		   precio = CONVERT(decimal(18,2),(ABS(d.precio_cotizado) * ABS(IIF(d.cantidad_und=0,1,d.cantidad_und))) * IIF(d.sw = 1,1,-1)),
		   cotg.descripcion,
		   i.descripcion
    from @Docs d
	JOIN cot_item i on i.id = d.id_cot_item
	JOIN dbo.cot_grupo_sub cotsg ON cotsg.id = i.id_cot_grupo_sub
	JOIN dbo.cot_grupo cotg ON cotg.id = cotsg.id_cot_grupo
	where cotg.descripcion = 'DISPOSITIVOS'
	--and d.id = 450139--455121--465848


	-- Obtenemos las Facturas y Notas de Credito de Vehiculos con Dispositivos
	declare @vehiculos_con_dispositivos as table
	(
		id_documento int,
		sw int,
		id_cot_item_lote int,
		cantidad_disp DECIMAL(18, 2),
		total_dispositivos DECIMAL(18, 2)		
	)
	insert @vehiculos_con_dispositivos
	select vh.id_documento,
	       vh.sw,
	       vh.id_cot_item_lote,
		   SUM(disp.cantidad),
		   SUM(disp.precio)   
	from @docs_vehiculos vh
	JOIN @docs_dispositivos disp on vh.id_documento = disp.id_documento and vh.sw = disp.sw
	group by vh.id_documento,vh.sw,vh.id_cot_item_lote


	----Obtenemos las Facturas y Notas de Credito de Accesorios
	declare @docs_accesorios as table
	(
		id_documento int,
		sw int,
		id_cot_item int,
		cantidad int,
		precio_cotizado DECIMAL(18, 2),
		precio DECIMAL(18, 2),
		grupo nvarchar(50),
		descripcion varchar(200)
	)
	insert @docs_accesorios
    select d.id,
	       d.sw,
		   d.id_cot_item,
		   cast(d.cantidad_und as int),
		   d.precio_cotizado,
		   --precio = d.precio_cotizado * IIF(d.cantidad_und=0,1,d.cantidad_und) * IIF(d.sw = 1,1,-1),
		   precio = CONVERT(decimal(18,2),(ABS(d.precio_cotizado) * ABS(IIF(d.cantidad_und=0,1,d.cantidad_und))) * IIF(d.sw = 1,1,-1)),
		   cotg.descripcion,
		   i.descripcion
    from @Docs d
	JOIN cot_item i on i.id = d.id_cot_item
	JOIN dbo.cot_grupo_sub cotsg ON cotsg.id = i.id_cot_grupo_sub
	JOIN dbo.cot_grupo cotg ON cotg.id = cotsg.id_cot_grupo
	where cotg.descripcion = 'ACCESORIOS'
	--and d.id = 450139--455121--465848

	
	-- Obtenemos las Facturas y Notas de Credito de Vehiculos con Accesorios
	declare @vehiculos_con_accesorios as table
	(
		id_documento int,
		sw int,
		id_cot_item_lote int,
		cantidad_acc DECIMAL(18, 2),
		total_accesorios DECIMAL(18, 2)		
	)
	insert @vehiculos_con_accesorios
	select vh.id_documento,
	       vh.sw,
	       vh.id_cot_item_lote,
		   SUM(acc.cantidad),
		   SUM(acc.precio)   
	from @docs_vehiculos vh
	JOIN @docs_accesorios acc on vh.id_documento = acc.id_documento and vh.sw = acc.sw
	group by vh.id_documento,vh.sw,vh.id_cot_item_lote

	
    -------------------------------------------------------------------------------------------
	----------------------------    DATOS FACTURAS VH ASOCIADOS AL PEDIDO    ------------------
	-------------------------------------------------------------------------------------------
	--declare @DatosHN_Ped table
	--(
	--	id int,
	--    id_cot_item int,
	--	id_cot_item_lote int,
	--	id_veh_hn_enc int,
	--	Apli_rebate NVARCHAR(10),
	--	Val_Rebate money,
	--	id_emp int

	--)
	--INSERT @DatosHN_Ped
	--select distinct 
	--	vhe.id, 
	--	vhe.id_cot_item,
	--	vhe.id_cot_item_lote,
	--	vhe.id_veh_hn_enc,
	--	Apli_rebate=case when isnull(va.id_rebate,0)>0 then 'SI' else 'NO'end,
	--	Val_Rebate=isnull(va.valor_rebate,0),
	--	vhe.id_emp
	----into #DatosHN_Ped
	--FROM @VH vhe
	--join dbo.veh_hn_pedidos pe on (pe.id_veh_hn_enc=vhe.id_veh_hn_enc and vhe.sw = 1) 
	--join dbo.cot_pedido p on p.id=pe.id_cot_pedido
	--left join v_veh_pedido_asignado va ON va.id_cot_pedido=p.id


	--SELECT DISTINCT 
	--		d.id,
	--		idnota=n.id, 
	--		n.total_sub
	--INTO #NotaRebate
	--FROM cot_notas_deb_cre n
	--JOIN @Docs d ON cast(d.id AS varchar) = n.docref_numero	
	--where n.id_emp=605 
	--and n.anulada is null


	------------------------------------------------------------------------------------------
	----------------------------    Campos asociados a la HN  --------------------------------
	------------------------------------------------------------------------------------------
	DECLARE @DatosHN_Enc TABLE
	(
		    id INT, 
			id_cot_item int,
			id_cot_item_lote int,
			id_hn int,
			fecha_estimada_entrega datetime,
			Tipo_Negocio varchar(65),
			--Nomb_flota=isnull(vf.flota,''),
			ChevyPlan varchar(50),
			Tipo_Credito varchar(50),
			Dispositivo varchar(50),
			Aseguradora nvarchar(100) ,
			Estado varchar(50), 
			VH_Entregado varchar(50),
			id_veh_hn_tipo_negocio int,
			id_emp int
	)
	
	---
	insert @DatosHN_Enc
	select	vh.id, 
			vh.id_cot_item,
			vh.id_cot_item_lote,
			id_hn=hn.id,
			hn.fecha_estimada_entrega ,
			Tipo_Negocio=vtn.descripcion,
			--Nomb_flota=isnull(vf.flota,''),
			ChevyPlan=isnull(cv.campo_3,'NO'),
			Tipo_Credito=isnull(cv.campo_2,'') ,
			Dispositivo=isnull(cv.campo_5,'NO') ,
			Aseguradora=isnull(c.razon_social,'') ,
			Estado=isnull(ve.campo_1,'') ,
			VH_Entregado=	(select convert(varchar,max(cast(fecha as datetime))) from v_cot_auditoria va where va.id_id=hn.id and accion ='E:575'),
			hn.id_veh_hn_tipo_negocio,
			vh.id_emp
	from  @VH vh
	join veh_hn_enc hn on hn.id = vh.id_veh_hn_enc and vh.id_emp = hn.id_emp
	left join veh_hn_tipo_negocio vtn on vtn.id = hn.id_veh_hn_tipo_negocio
	--left join V_FLOTAS_VH vf on vf.id_hn=hn.id
	left join v_campos_varios cv on cv.id_veh_hn_enc=hn.id and cv.id_veh_estado is null
	left join cot_cliente_contacto cc on cc.id=hn.id_cot_cliente_contacto_aseguradora
	left join cot_cliente c on c.id_cot_cliente_contacto=cc.id
	left join v_campos_varios ve on ve.id_veh_estado=575 and ve.id_veh_hn_enc=hn.id
	where vh.sw = 1
	------------------------------------------------------------------------------------------
	----------------------------    Datos Asociados a las formas de pago  --------------------
	------------------------------------------------------------------------------------------ 
	DECLARE @DatosHN_Formap TABLE
	(
		    id int, 
			id_cot_item int,
			id_cot_item_lote int,
			id_hn int,
			id_veh_tipo_pago int,
			valor money,
			id_cot_cotizacion int,
			id_cot_cliente_contacto int,
			id_emp int
	)
	insert @DatosHN_Formap
	select 	e.id, 
			e.id_cot_item,
			e.id_cot_item_lote,
			e.id_hn,
			fhn.id_veh_tipo_pago,
			fhn.valor ,
			fhn.id_cot_cotizacion,
			fhn.id_cot_cliente_contacto,
			e.id_emp
	from @DatosHN_Enc e
	join veh_hn_forma_pago fhn on fhn.id_veh_hn_enc = e.id_hn
	left join cot_cliente_contacto cc on cc.id=fhn.id_cot_cliente_contacto
	LEFT JOIN v_cot_factura_saldo vs on vs.id_cot_cotizacion=e.id	 and fhn.id_veh_tipo_pago in (3) 

	----------------------------------------------------------------------------------------------------
	-------------- evaluar estado de factura forma de pago credito , doc financiera --------------------
	---------------------------------------------------------------------------------------------------- 
	declare @DatosHN_Formap_finan table
	 (
	 	 id int, 
	     id_cot_item_lote int,
	     id_hn int,
	     id_cot_cliente_contacto int,
	     Valor money,
	     valor_fac money,
	     Saldo_Finan money,
		 id_emp int
	 )
	 insert @DatosHN_Formap_finan
	 select  DISTINCT   
			 fp.id, 
			 fp.id_cot_item_lote,
			 fp.id_hn,
			 fp.id_cot_cliente_contacto,
			 Valor=fp.valor,
			 valor_fac=a.total_total,
			 Saldo_Finan=vs.saldo,
			 fp.id_emp
	 from @DatosHN_Formap fp
	 JOIN dbo.cot_cotizacion a  on a.id_veh_hn_enc = fp.id_hn and a.id_cot_cliente_contacto=fp.id_cot_cliente_contacto
	 LEFT JOIN v_cot_factura_saldo vs on vs.id_cot_cotizacion=a.id 
	 where 	 fp.id_veh_tipo_pago in (3) 


	 --Resumen formas de pago
	 declare @DatosHN_Formapresumen table
	 (
		id int, 
	    id_cot_item int,
	    id_cot_item_lote int,
	    Forma_Pago NVARCHAR(50),
		id_emp int
	 )
	 
	 insert @DatosHN_Formapresumen
	 select
	 e.id, 
	 e.id_cot_item,
	 e.id_cot_item_lote,
	 Forma_Pago=case when (select isnull(max(fhn.id),'') from @DatosHN_Formap fhn where fhn.id_veh_tipo_pago in (3) 
	 				and  fhn.id_hn=e.id_hn)=''
	 				then 'Contado' else 'Crédito'end,
	 e.id_emp
	 --Financiera=max(e.financiera),
	 --Fec_Apro_fi=max(case when e.id_veh_tipo_pago in (3) then e.fecha_hora else null end),
	 --Valor_anti=sum(case when e.id_veh_tipo_pago in (1,7,10) then e.valor else 0 end),
	 --Valor_fin=sum(case when e.id_veh_tipo_pago in (3) then e.valor else 0 end),
	 --Valor_NotaCredito=sum(case when e.id_veh_tipo_pago in (5) then e.valor else 0 end),
	 --Valor_Vh_US=sum(case when e.id_veh_tipo_pago in (2,6) then e.valor else 0 end),
	 --Saldo_Finan=sum(
	 --case 
	 --when e.id_veh_tipo_pago in (3) and e.id_cot_cotizacion is null then e.valor 
	 --when e.id_veh_tipo_pago in (3) and e.id_cot_cotizacion is not null then isnull(b.Saldo_Finan,b.valor_fac)
	 --end ), 
	 --valor_CreditoCon= max(case when e.id_veh_tipo_pago in (8) then e.valor else null end)
	 from @DatosHN_Formap e
	 left join @DatosHN_Formap_finan b on b.id=e.id and b.id_cot_item_lote=b.id_cot_item_lote and e.id_emp = b.id_emp
	 group by 
	 e.id, 
	 e.id_cot_item,
	 e.id_cot_item_lote,
	 e.id_hn,
	 e.id_emp
	
	-------------------------------------------------------------------------------
	----------------------------    INFO FLOTAS    --------------------------------
	-------------------------------------------------------------------------------
    DECLARE @flota AS TABLE
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
	INSERT INTO @flota
	SELECT   	
		v.id,		v.id_cot_item,
		v.id_cot_item_lote,		id_hn=vhne.id,
		id_flota = MAX(cpid.id_cot_descuento), 		flota = MAX(lo.descripcion),
		porce_flota = MAX(cpid.porcentaje),		Nit_Flota=cli.nit,
		Nombreflota=cli.razon_social,		TipoNegocio=max(tn.descripcion)
	FROM dbo.veh_hn_pedidos vhp 
	JOIN @VH v ON v.id_veh_hn_enc = vhp.id_veh_hn_enc
	JOIN dbo.cot_pedido cotp  on cotp.id = vhp.id_cot_pedido
	JOIN dbo.cot_pedido_item cotpi  ON cotpi.id_cot_pedido = cotp.id 
	JOIN dbo.veh_hn_enc vhne  ON vhne.id = vhp.id_veh_hn_enc 
	JOIN dbo.cot_pedido_item_descuentos cpid  ON cpid.id_cot_pedido_item = cotpi.id
	JOIN dbo.cot_descuento lo  ON lo.id = cpid.id_cot_descuento AND ISNULL(lo.es_flota,0) = 1
	--and  lo.id=it.id_cot_descuento_prov
	JOIN dbo.cot_cliente cli  on cli.id=lo.id_cot_cliente_d
	LEFT JOIN dbo.veh_hn_tipo_negocio tn  on tn.id=vhne.id_veh_hn_tipo_negocio
	where lo.es_flota=1
	GROUP BY vhp.id_cot_pedido,vhne.id,cli.nit,cli.razon_social  ,
	v.id,
	v.id_cot_item,
	v.id_cot_item_lote,
	vhne.id


	----------------------------------------------------------------------------------------------------------
	----------------------------    VALIDAR DEVOLUCIONES Y NOTAS DE CREDITO   --------------------------------
	----------------------------------------------------------------------------------------------------------
	DECLARE @Devoluciones AS TABLE
	(
		id INT,
		factura VARCHAR(20)
	)
	INSERT @Devoluciones
	SELECT DISTINCT 
		   d.id,
		   Factura = CAST(ISNULL(bd.ecu_establecimiento, '') AS VARCHAR(4))
					 + CAST(ISNULL(t3.ecu_emision, '') AS VARCHAR(4)) COLLATE Modern_Spanish_CI_AI + ''
					 + RIGHT('000000000' + CAST(cc3.numero_cotizacion AS VARCHAR(100)), 9)
	FROM @Docs d
	JOIN dbo.v_cot_cotizacion_factura_dev fdev  ON fdev.id_cot_cotizacion = d.id
	JOIN dbo.cot_cotizacion cc3  ON cc3.id = fdev.id_cot_cotizacion_factura
	JOIN dbo.cot_tipo t3  ON t3.id = cc3.id_cot_tipo
	JOIN @bodega bd ON bd.id = cc3.id_cot_bodega
	WHERE d.sw = -1

	--Validacion Fac con devolución
	--insert @FacConDev
	--(id, tiene)
	--select distinct 
	--d.id, 
	--tipo= case when tv.tiene_devol=1 then 'Si' else 'No' end
	--from #Docs d
	--JOIN dbo.v_cot_tiene_devolucion tv ON tv.id_cot_cotizacion = d.id
	-- where d.sw=1

	-------------------------------------------------------------------------------
	---------------------------- OBTENER LINEA DEL VEHICULO -----------------------
	-------------------------------------------------------------------------------
	DECLARE @vhtaller TABLE 
	(
		[id] INT,
		[placa] VARCHAR(50),
		[LineaTaller] NVARCHAR(50),
		[id_ot] INT,
		[marca] NVARCHAR(100),
		[modelo] NVARCHAR(100),
		[año] NVARCHAR(50),
		[vin] NVARCHAR(50) NOT NULL,
		[motor] VARCHAR(50),
		[km] INT
	)
	INSERT @vhtaller
	SELECT x.id,x.placa,x.LineaTaller,x.id_ot,x.marca,x.modelo,x.año,x.vin,x.motor,x.km
	FROM (
	 	SELECT distinct 
	 		 d.id,
	 		 placa=cotil.placa,
	 		 LineaTaller=cotit.descripcion,
	 		 id_ot=d.id_cot_cotizacion_sig,
	 		 marca=CAST(ISNULL(cv.campo_11,'') AS NVARCHAR(100)), 
	 		 modelo=CAST(ISNULL(cv.campo_12,'') AS NVARCHAR(100)),
	 		 año=CAST(ISNULL(cv.campo_13,'') AS NVARCHAR(50)),
	 		 cotil.vin,
	 		 cotil.motor ,
	 		 km=cotz.km
	 	from @Docs	d
	 	join dbo.cot_cotizacion cotz  on cotz.id=d.id_cot_cotizacion_sig
	 	join dbo.cot_item_lote cotil  on cotil.id=d.id_cot_item_lote_cab
	 	join dbo.cot_item coti  on coti.id=cotil.id_cot_item
	 	LEFT JOIN dbo.cot_item_talla cotit  on cotit.id=coti.id_cot_item_talla
	 	LEFT JOIN dbo.v_campos_varios cv  on cv.id_cot_item_lote=cotil.id 
	 	where d.sw in (1)
	 	UNION ALL
	 	select DISTINCT 
	 			 d.id, 
	 			 placa=cotil.placa, 
	 			 LineaTaller=cotit.descripcion,
	 			 id_ot = cotz.id_cot_cotizacion_sig,
	 			 marca=isnull(cv.campo_11,''), 
	 			 modelo=isnull(cv.campo_12,''),
	 			 [año]=isnull(cv.campo_13,''),
	 			 cotil.vin,
	 			 cotil.motor ,
	 			 km=coo.km
	 	from @Docs d
	 	JOIN dbo.v_cot_cotizacion_factura_dev fdev  ON fdev.id_cot_cotizacion = d.id
	 	JOIN dbo.cot_cotizacion cotz  on cotz.id= fdev.id_cot_cotizacion_factura
	 	JOIN dbo.cot_item_lote cotil  on cotil.id = cotz.id_cot_item_lote
	 	JOIN dbo.cot_item coti  on coti.id = cotil.id_cot_item
	 	LEFT join dbo.cot_item_talla cotit  on cotit.id = coti.id_cot_item_talla
	 	LEFT JOIN dbo.v_campos_varios cv  on cv.id_cot_item_lote = cotil.id
	 	JOIN dbo.cot_cotizacion coo  on coo.id = d.id_cot_cotizacion_sig
	 	where d.sw in (-1)
	 )x
	

	-------------------------------------------------------------------------
	-----------------------------FINANCIERA----------------------------------
	-------------------------------------------------------------------------		
	DECLARE @financiera AS TABLE
	(
		id int, 
		id_cot_item int,
		id_cot_item_lote int,
		id_hn int,
		financiera varchar(200),
		valor money
	)
	INSERT INTO @financiera
	SELECT
		v.id,
		v.id_cot_item,
		v.id_cot_item_lote,
		id_hn=v.id_veh_hn_enc	,
		financiera = cli.razon_social	,
		valor=fp.valor
	FROM @VH v
	JOIN dbo.veh_hn_forma_pago fp  ON fp.id_veh_hn_enc = v.id_veh_hn_enc	
	JOIN dbo.cot_cliente_contacto cotcc  ON cotcc.id = fp.id_cot_cliente_contacto
	JOIN dbo.cot_cliente cli  ON cli.id = cotcc.id_cot_cliente
	WHERE fp.id_veh_tipo_pago=3

	----------------------------------------------------------------------------------------------
	-----------------------------PARA OBTENER DIAS DE INVENTARIO----------------------------------
	----------------------------------------------------------------------------------------------
	DECLARE @HistorialFechasVH TABLE
	(
		[id_cot_item] INT,
		[id_cot_item_lote] INT,
		[ultima_venta] DATETIME,
		[ultima_Dev_venta] DATETIME,
		[ultima_compra] DATETIME,
		[ultima_entrada] DATETIME
	)
	INSERT INTO @HistorialFechasVH
	SELECT v.id_cot_item,v.id_cot_item_lote,
		   ultima_venta =    MAX(CASE
									 WHEN t.sw IN ( 1 ) THEN
								 (z.fecha)
									 ELSE
										 NULL
								 END),
		   ultima_Dev_venta =  MAX(CASE
									 WHEN t.sw IN ( -1 ) THEN
								 (z.fecha)
									 ELSE
										 NULL
								 END),
		   ultima_compra =	   MAX(CASE
									  WHEN t.sw IN ( 4 ) THEN
								  (z.fecha)
									  ELSE
										  NULL
								  END),
		   ultima_entrada =    MAX(CASE
									   WHEN t.sw IN ( 12 ) THEN
								   (z.fecha)
									   ELSE
										   NULL
								   END)		 
	FROM dbo.cot_cotizacion_item ci 
	join @VH v ON v.id_cot_item = ci.id_cot_item AND v.id_cot_item_lote = ci.id_cot_item_lote
	join dbo. cot_cotizacion z  on z.id = ci.id_cot_cotizacion
	join cot_tipo t  on t.id = z.id_cot_tipo
	join cot_item_lote l  on l.id = v.id_cot_item_lote and l.id_cot_item = v.id_cot_item
	WHERE ISNULL(z.anulada, 0) <> 4
	and t.id_emp in (601,605)
	AND t.sw IN ( 1, 4, 12,-1 )
	group by v.id_cot_item,v.id_cot_item_lote

	----------------------------------------------------------------------------------------------
	-----------------------------INFORMACION DE COMPRAS VEHICULOS----------------------------------
	----------------------------------------------------------------------------------------------
	declare @Compras as table
	(
		[id] INT,
		[id_cot_item] INT,
		[id_cot_item_lote] INT,
		[fechacompra] DATETIME NOT NULL,
		[facproveedor] varchar(50),
		[id_compra] INT NOT NULL,
		[proveedor] NVARCHAR(100) NOT NULL
	)
	insert @Compras
	select x.id,x.id_cot_item,x.id_cot_item_lote,x.fechacompra,x.facproveedor,x.id_compra,x.proveedor
	from
	(
		SELECT distinct 
			vh.id,
			vh.id_cot_item,
			vh.id_cot_item_lote,
			fechacompra=z.fecha,
			rank() over (partition by vh.id,vh.id_cot_item,vh.id_cot_item_lote order by z.fecha desc) as fila,
			facproveedor=RIGHT('000000' + cast(z.numero_cotizacion_original as varchar(50)),6) + '' +RIGHT('000000000' + CAST(z.docref_numero AS VARCHAR(50)), 9),
			id_compra=z.id, 
			proveedor=cc.razon_social
		from @VH vh
		JOIN dbo.cot_cotizacion_item ci  on ci.id_cot_item=vh.id_cot_item and ci.id_cot_item_lote=vh.id_cot_item_lote
		JOIN dbo.cot_cotizacion z  on z.id=ci.id_cot_cotizacion
		JOIN dbo.cot_tipo t  on (t.id=z.id_cot_tipo and t.sw = 4)
		join dbo.cot_cliente cc  on cc.id=z.id_cot_cliente
	)x
	where x.fila = 1 --Toma la fecha mas actual de compra del vehiculo muestra z.id = 87877
	
	
	-----------------------------------------------------------------------------------------
	------------------- UTILIZAR PARA PRUEBAS ESPECIFICAS ----------------------------------
	-----------------------------------------------------------------------------------------
	--select d.id,
	--       d.sw,
	--	   d.fecha,
	--	   d.precio_cotizado,
	--	   d.cantidad_und,
	--	   d.docref_numero,
	--	   Rebate = case
	--					when d.sw = 21 then r.total_sub 
	--					when d.sw = 23 then r.total_sub * -1
	--					else
						
						
	--					case cotg.descripcion when 'VEHICULOS' then (select sum(total_sub) 
	--			                                                      from @NotaRebate 
	--																  where id = d.id) 
	--														   else 0
	--					end
	--				 end
	--from @Docs d
	--JOIN dbo.cot_item coti  ON coti.id = d.id_cot_item --AND i.maneja_stock IN (0)
	--JOIN dbo.cot_grupo_sub cotsg  ON cotsg.id = coti.id_cot_grupo_sub
	--JOIN dbo.cot_grupo cotg  ON cotg.id = cotsg.id_cot_grupo
	--JOIN dbo.cot_item_lote cotil  ON cotil.id_cot_item = coti.id AND cotil.id = d.id_cot_item_lote --Solo venta de vehiculos con chasis
	--left join @Rebates_Facturas_Anteriores r on r.id_rebate = d.id
	--where d.id in (376331,133321,131918,131919,131921,133321,133324,133325,133882,135675)

	-- exec [dbo].[BI_GetVentaVehiculos_AgregarRebates] '2021-08-01','2021-08-31'
	---------------------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------- RESULTADO -------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------
	
	declare @Resultado table 
	(
			[id_cot_bodega] [int] NULL,
			[id_tipo_transaccion] [smallint] NULL,
			[id_cot_tipo] [int] NOT NULL,
			[TipoDocumento] [nvarchar](50) NOT NULL,
			[Id_Factura] [int] NOT NULL,
			[NumeroDocumento] [int] NULL,
			[FechaComprobante] [date] NULL,
			[CodigoTiempo] [varchar](8) NULL,
			[Id_Asesor] [int] NOT NULL,
			[HojaNegocio] [int] NULL,
			[FormaPago] [nvarchar](50) NULL,
			[NitCliente] nvarchar(40),
			[FlotaNit] [varchar](100) NULL,
			[CanalComercial] [nvarchar](50) NULL,
			[Flota] [varchar](10) NULL,
			[Transito] [varchar](10) NULL,
			[ChevyPlan] [varchar](10) NULL,
			[ISSFA] [varchar](10) NULL,
			[TipoVehiculo] [nvarchar](50) NULL,
			[CodigoItem] [nvarchar](50) NULL,
			[Linea] [nvarchar](50) NULL,
			[Segmento] [nvarchar](50) NULL,
			[Clase] [varchar](50) NULL,
			[Familia] [varchar](50) NULL,
			Familia2 varchar(100) null,
			[Modelo] [nvarchar](150) NULL,
			[Cantidad] [int] NULL,
			[CostoCompra] [decimal](18, 2) NULL,
			--[CostoCompraComplemento] [decimal](18, 2) NULL,
			[PrecioVenta] [decimal](18, 2) NULL,
			[Descuento] [decimal](18, 2) NULL,
			[VentaNeta] [decimal](18, 2) NULL,
			[Total_IVA] [decimal](18, 2) NULL,
			[Rebate] [decimal](18, 2) NULL,
			--[NotasDebito] [decimal](18, 2) NULL,
			[FechaCompra] [date] NULL,
			[DiasInventario] [int] NULL,
			[CostoFinanciero] [decimal](18, 2) NULL,
			[AplicativoNeto] [decimal](18, 2) NULL,
			[AplicativoCosto] [decimal](18, 2) NULL,
			[PendienteEntrega] [varchar](10) NULL,
			[Financiamiento] [decimal](18, 2) NULL,
			[Marca] [nvarchar](50) NULL,
			CantidadAccesorios money,	
		    TotalAccesorios money,
			CantidadDisp money,	
		    TotalDisp money,
			[IdEmpresa] [int],
			id_veh_ano int
	)

	;WITH Resultado (id_cot_bodega,id_tipo_transaccion,id_cot_tipo,TipoDocumento,Id_Factura,NumeroDocumento,FechaComprobante,
	                 CodigoTiempo,Id_Asesor,HojaNegocio,FormaPago,NitCliente,FlotaNit,CanalComercial,Flota,Transito,ChevyPlan,ISSFA,TipoVehiculo,
					 CodigoItem,Linea,Segmento,Clase,Familia,Familia2,Modelo,Cantidad,CostoCompra,PrecioVenta,Descuento,VentaNeta,Total_IVA,
					 Rebate,
					 FechaCompra,DiasInventario,CostoFinanciero,AplicativoNeto,AplicativoCosto,PendienteEntrega,Financiamiento,Marca,
					 CantidadAccesorios,TotalAccesorios,CantidadDisp,TotalDisp,IdEmpresa,id_veh_ano,EsNotaDebito
					 ) as
	(
	
		SELECT 
			   d.id_cot_bodega,
			   id_tipo_transaccion  = cott.sw,
			   --TIPO_COCUMENTO = cott.descripcion,
			   id_cot_tipo = cott.id,
			   TipoDocumento = CASE 
					WHEN cott.descripcion LIKE '%-%' THEN LEFT(TRIM(REPLACE(cott.descripcion,' ','')),CHARINDEX('-',TRIM(REPLACE(cott.descripcion,' ','')))-1)
					WHEN cott.descripcion = 'NC.17.9.9 NC DEVOLUCION VTAS SISTEMA ANTERIOR' THEN 'NC.17.9.9'
					WHEN cott.descripcion = 'RCD.99.99 RUBROS CRED. DIRECTO' THEN 'RCD.99.99'
					ELSE cott.descripcion
			   END ,
			   Id_Factura = d.id,
			   NumeroDocumento = d.numero_cotizacion,
			   FechaComprobante = d.fecha,
			   CodigoTiempo = CONVERT(VARCHAR(8), d.fecha, 112),
			   Id_Asesor = u.id,
			   HojaNegocio = d.id_veh_hn_enc,
			   FormaPago=isnull(fpr.Forma_Pago,'Contado'),
			   cli.nit,
			   FlotaNit = ISNULL(f.Nit_flota,''),
			   CanalComercial=
					case 
						when  cotcp.descripcion in ('RELACIONADAS','CONCESIONARIO') then 'TRANSFERENCIAS'
						when ISNULL(f.Nit_Flota,'0') = '0' then 'VENTAS RETAIL'
						when ISNULL(f.Nit_Flota,'0') <> '0' and f.Nit_Flota <> '1791927966001' then 'VENTAS FLOTAS'
						--when ISNULL(f.Nit_Flota,'0') <> '0' and f.Nit_Flota = '1791927966001' then 'VENTAS VEHICULOS CHEVYPLAN'
						when ISNULL(f.Nit_Flota,'0') <> '0' and f.Nit_Flota = '1791927966001' then 'VENTAS FLOTAS'
						else
						''
					end,
				Flota=
					CASE
						WHEN ISNULL(f.Nit_Flota,'0') = '0' THEN '0'
						WHEN ISNULL(f.Nit_Flota,'0') <> '0' AND f.Nit_Flota <> '1791927966001' THEN '1'
						WHEN ISNULL(f.Nit_Flota,'0') <> '0' AND f.Nit_Flota = '1791927966001' THEN '0'
						ELSE ''
					END,
					Transito = '0',
				ChevyPlan=
				CASE 
					WHEN ISNULL(f.Nit_Flota,'0') <> '0' and f.Nit_Flota = '1791927966001' THEN '1'
					ELSE '0'
				END,
				ISSFA = '0',
				TipoVehiculo = CASE WHEN cotil.tipo_veh in (1,2,3) then 'USADO' ELSE 'NUEVO' END,
				CodigoItem=
				CASE
					WHEN d.id_cot_item_lote = 0
					THEN CAST(coti.codigo AS NVARCHAR(50)) ELSE cotil.vin
				END,
				Linea=isnull(CASE 
								WHEN isnull(cotit.descripcion,'') = '' THEN vt.LineaTaller 
								ELSE cotit.descripcion 
							 END,'LIVIANOS'),

				Segmento = case when cv.campo_2 in ('AUTOMOVIL') then
									CASE 
										WHEN coti.id_veh_linea IN (794,818,860,867) then 'SUV'
										ELSE 'PASAJERO'
									END
						
								--when v2001.descripcion in ('AUTOMOVIL', 'CAMIONETA') then 'PASAJERO' 
								when cv.campo_2 in ('') then 'PICKUP'
								when cv.campo_2 in ('JEEP') then 'SUV'
								when cv.campo_2 in ('CAMION') then 'CAMION'
								ELSE cv.campo_2 
						   END
				,Clase = clase.descripcion,
				Familia = vi.Linea,
				Familia2 = cv.campo_7,
				Modelo = coti.descripcion,
				Cantidad = CAST(d.cantidad_und AS INT),
				--VentaNeta = d.precio_cotizado * (case cott.sw when 1 then 1 else -1 end),
				CostoCompra = d.cantidad_und * d.costo,
				--k.CostoCompraComplemento,
				--PrecioVenta = (d.cantidad_und * d.precio_lista) * IIF(d.sw = 1,1,-1),
				PrecioVenta = CONVERT(DECIMAL(18,2),d.cantidad_und * d.precio_lista),
				Descuento = CONVERT(DECIMAL(18,2),ISNULL(((d.cantidad_und * d.precio_lista ) * d.porcentaje_descuento / 100),0)),
				VentaNeta = CONVERT(decimal(18,2),(ABS(d.precio_cotizado) * ABS(IIF(d.cantidad_und=0,1,d.cantidad_und))) * IIF(d.sw = 1,1,-1)),
				Total_IVA = CONVERT(DECIMAL(18,2),d.total_total * IIF(d.sw=1,1,-1)),
			    Rebate = case
						when d.sw = 21 then r.total_sub 
						when d.sw = 23 then r.total_sub * -1
						else
						
						
						case cotg.descripcion when 'VEHICULOS' then (select sum(total_sub) 
				                                                      from @NotaRebate 
																	  where id = d.id) 
															   else 0
						end
					 end,
				FechaCompra = cast(com.fechacompra as date),
			    DiasInventario = CASE
									WHEN hfec.ultima_venta IS NULL AND hfec.ultima_Dev_venta IS NULL THEN
									--GMAH 747
										CASE WHEN @emp = 601 THEN (
																		DATEDIFF(DD, CAST(hfec.ultima_compra AS DATE), CAST(d.fecha AS DATE))
																		-
																		[dbo].[fn_dias_nolaborales](CAST(hfec.ultima_compra AS DATE), CAST(d.fecha AS DATE))
																  )
															 ELSE ( 
																		DATEDIFF(DD, CAST(cotil.Fecha_Creacion AS DATE), CAST(d.fecha AS DATE))
																		-
																		[dbo].[fn_dias_nolaborales](CAST(cotil.Fecha_Creacion AS DATE), CAST(d.fecha AS DATE))
															      )
										END
									WHEN hfec.ultima_venta IS NOT NULL AND hfec.ultima_Dev_venta IS NOT NULL 
										 THEN (
													DATEDIFF(DD, CAST(hfec.ultima_compra AS DATE), CAST(d.fecha AS DATE))
													-
													[dbo].[fn_dias_nolaborales](CAST(hfec.ultima_compra AS DATE), CAST(d.fecha AS DATE))
										      )
									     ELSE (
													DATEDIFF(DD, CAST(hfec.ultima_compra AS DATE), CAST(hfec.ultima_venta AS DATE))
													-
													[dbo].[fn_dias_nolaborales](CAST(hfec.ultima_compra AS DATE), CAST(hfec.ultima_venta AS DATE))
										 )
								  END,
				CostoFinanciero = ((d.cantidad_und * d.costo) * 10.39) / 100,
				AplicativoNeto = CONVERT(DECIMAL(18,2),0),
				AplicativoCosto = CONVERT(DECIMAL(18,2),0),
				PendienteEntrega = 
								CASE
									WHEN vh.id_veh_estado IN (500,550) then 1
									when isnull(vh.id_veh_estado,'0') = '0' then vh.id_veh_estado
									else 0
								end,
		
				Financiamiento=CONVERT(DECIMAL(18,2),ISNULL(fn.valor,0)),
			
				Marca = vi.Marca,
				veh_acc.cantidad_acc,
				veh_acc.total_accesorios,
				veh_disp.cantidad_disp,
				veh_disp.total_dispositivos,
				IdEmpresa = case when cott.id_emp = @emp then 4 
								 when cott.id_emp = @emp2 then 1 else 0 
							END,
				--d.id_cot_cliente
				coti.id_veh_ano,
				EsNotaDebito = IIF(isnull(nd.id,0)=0,0,1)
				
		FROM @Docs d
		JOIN dbo.cot_tipo cott  ON cott.id = d.id_cot_tipo
		JOIN dbo.cot_item coti  ON coti.id = d.id_cot_item --AND i.maneja_stock IN (0)
		JOIN dbo.veh_linea line  on line.id = coti.id_veh_linea
		join veh_clase clase  on clase.id = line.clase

		--JOIN dbo.veh_linea_modelo m  on m.id = coti.id_veh_linea
		--join veh_linea l on l.id = m.id_veh_linea
		
		JOIN dbo.cot_item_lote cotil  ON cotil.id_cot_item = coti.id AND cotil.id = d.id_cot_item_lote --Solo venta de vehiculos con chasis
		JOIN dbo.cot_cliente cli  ON cli.id = d.id_cot_cliente
		JOIN dbo.v_cot_item_descripcion vi  ON vi.id=coti.id
		JOIN dbo.cot_grupo_sub cotsg  ON cotsg.id = coti.id_cot_grupo_sub
		JOIN dbo.cot_grupo cotg  ON cotg.id = cotsg.id_cot_grupo

		LEFT JOIN dbo.cot_cliente_perfil cotcp  ON cotcp.id = cli.id_cot_cliente_perfil
		LEFT JOIN dbo.cot_item_talla cotit  on cotit.id = coti.id_cot_item_talla
		LEFT JOIN @vhtaller vt on vt.id = d.id

		--LEFT JOIN @NotaRebate nr ON nr.id = d.id
		LEFT JOIN @flota f ON f.id_cot_item = d.id_cot_item AND f.id_cot_item_lote = d.id_cot_item_lote AND f.id = d.id
		--left join @DatosHN_Ped hnp on hnp.id = d.id and hnp.id_cot_item_lote = d.id_cot_item_lote
		LEFT JOIN @financiera fn ON fn.id_cot_item = d.id_cot_item AND fn.id_cot_item_lote = d.id_cot_item_lote AND fn.id = d.id
		LEFT JOIN dbo.usuario u  ON u.id = d.id_usuario_ven
		LEFT JOIN dbo.cot_forma_pago cotfp  ON cotfp.id = d.id_forma_pago

		LEFT JOIN [dbo].[v_campos_varios] cv  on cv.id_veh_linea_modelo = coti.id_veh_linea_modelo

		--LEFT JOIN @VehAccesorios veh_acc ON veh_acc.id = d.id and veh_acc.id_cot_item_lote = d.id_cot_item_lote
		LEFT JOIN @vehiculos_con_accesorios veh_acc ON veh_acc.id_documento = d.id and veh_acc.id_cot_item_lote = d.id_cot_item_lote
		LEFT JOIN @vehiculos_con_dispositivos veh_disp ON veh_disp.id_documento = d.id and veh_disp.id_cot_item_lote = d.id_cot_item_lote
		
		LEFT JOIN @DatosHN_Formapresumen fpr on fpr.id=d.id and fpr.id_cot_item_lote=d.id_cot_item_lote

		LEFT JOIN @VH vh on vh.id = d.id AND vh.id_veh_hn_enc = d.id_veh_hn_enc AND vh.id_cot_item_lote = d.id_cot_item_lote
		LEFT JOIN @HistorialFechasVH hfec ON hfec.id_cot_item = d.id_cot_item AND hfec.id_cot_item_lote = d.id_cot_item_lote
		LEFT JOIN @compras com ON com.id_cot_item = d.id_cot_item AND com.id_cot_item_lote = d.id_cot_item_lote AND com.id = d.id
		LEFT JOIN @NotasDebito nd on d.id = nd.id
		LEFT JOIN @Complementos_GAC_VW k on k.id = d.id
		LEFT JOIN @Rebates_Facturas_Anteriores r on r.id_rebate = d.id
		--LEFT JOIN @DocsNDB nd on (d.numero_cotizacion = nd.numero_cotizacion_ref and
		--				 d.id_cot_bodega = nd.id_cot_bodega and
		--				 d.id_emp = nd.id_emp and
		--				 d.id_cot_cliente = nd.id_cot_cliente)
	
	)

	INSERT @Resultado
	select  r.id_cot_bodega,
			r.id_tipo_transaccion,
			r.id_cot_tipo,
			r.TipoDocumento,
			r.Id_Factura,
			r.NumeroDocumento,
			r.FechaComprobante,
			r.CodigoTiempo,
			r.Id_Asesor,
			r.HojaNegocio,
			FormaPago = CASE WHEN r.id_tipo_transaccion = 1 AND ISNULL(r.HojaNegocio,'0') <> '0' AND  r.CanalComercial NOT IN ('TRANSFERENCIAS')
					               THEN r.FormaPago
							       ELSE NULL
							  END,
			
			r.NitCliente,
			r.FlotaNit,
			r.CanalComercial,
			r.Flota,
			r.Transito,
			r.ChevyPlan,
			r.ISSFA,
			r.TipoVehiculo,
			r.CodigoItem,
			r.Linea,
			r.Segmento,
			r.Clase,
			r.Familia,
			r.Familia2,
			r.Modelo,
			cantidad_vh = IIF(r.EsNotaDebito=1,0,r.Cantidad),
			r.CostoCompra,
			--r.CostoCompraComplemento,
			r.PrecioVenta,
			r.Descuento,
			r.VentaNeta,
			r.Total_IVA,
			r.Rebate,
			--r.NotasDebito,
			r.FechaCompra,
			--DiasInventario = 
			--		CASE
			--				WHEN   (CASE WHEN ISNULL(r.HojaNegocio,'0') <> '0' AND r.id_tipo_transaccion = 1 
			--								 THEN RANK() OVER(PARTITION BY r.CodigoItem,r.id_tipo_transaccion order by r.FechaComprobante desc) 
			--							ELSE 0
			--					   END) = 1
			--				THEN r.DiasInventario
			--				ELSE null
			--		END,
			DiasInventario = CASE WHEN r.id_tipo_transaccion = 1 AND ISNULL(r.HojaNegocio,'0') <> '0' AND  r.CanalComercial NOT IN ('TRANSFERENCIAS')
					               THEN CASE WHEN RANK() OVER(PARTITION BY r.id_tipo_transaccion, r.CodigoItem  order by r.FechaComprobante desc) = 1
								             THEN r.DiasInventario
											 ELSE 0
										END
							       ELSE NULL
							  END,


			--CostoFinanciero = 
			--					CASE
			--							WHEN   (CASE	
			--										WHEN ISNULL(r.HojaNegocio,'0') <> '0' AND r.id_tipo_transaccion = 1 
			--											 THEN RANK() OVER(PARTITION BY r.CodigoItem,r.id_tipo_transaccion order by r.FechaComprobante desc) 
			--										ELSE 0
			--								   END) = 1 AND r.DiasInventario > 30
			--							THEN CONVERT(DECIMAL(18,2),r.CostoFinanciero)
			--							ELSE null
			--					END,
			CostoFinanciero =  CASE WHEN r.id_tipo_transaccion = 1 AND ISNULL(r.HojaNegocio,'0') <> '0' AND  r.CanalComercial NOT IN ('TRANSFERENCIAS')
								     THEN CASE WHEN RANK() OVER(PARTITION BY r.id_tipo_transaccion, r.CodigoItem order by r.FechaComprobante desc) = 1 AND r.DiasInventario > 30
										       THEN CONVERT(DECIMAL(18,2),(r.CostoFinanciero * r.DiasInventario)/360)
										       ELSE 0
										  END
									 ELSE NULL
								END,
			r.AplicativoNeto,
			r.AplicativoCosto,
			PendienteEntrega = CASE WHEN (CASE WHEN ISNULL(r.HojaNegocio,'0') <> '0' AND r.id_tipo_transaccion = 1 
											   THEN RANK() OVER(PARTITION BY r.CodigoItem,r.id_tipo_transaccion order by r.FechaComprobante desc) 
										       ELSE 0
									      END) = 1
							              THEN r.PendienteEntrega
							              ELSE null
					END,
			r.Financiamiento,
			r.Marca,
			r.CantidadAccesorios,
			r.TotalAccesorios,
			r.CantidadDisp,
			r.TotalDisp,
			r.IdEmpresa,
			r.id_veh_ano
	from Resultado r
	

	
	SELECT * 
	FROM @Resultado
	
	

END



GO
