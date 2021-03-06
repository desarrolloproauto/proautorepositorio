USE [dms_smd3]
GO
/****** Object:  StoredProcedure [dbo].[GetFormatosImpresionSW_Enca_Tal_mep_proauto]    Script Date: 21/2/2022 21:08:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ===========================================================================================================================================================================
-- Description:	<Procedimiento para obtener informacion para reporte de prefactura de taller
-- Historial de Cambios:
--> 22/02/2022  --> Se realiza condicion para que si alguien de torre de control modifica en campo KM de campos varios se presente ese, sino se presenta el km habitual (RPC)
-- ===========================================================================================================================================================================


--exec [GetFormatosImpresionSW_Enca_Tal_mep_proauto] 412581, 1
ALTER PROCEDURE [dbo].[GetFormatosImpresionSW_Enca_Tal_mep_proauto]
(
	@id			 INT,
	@id_contacto INT
)
AS


SELECT
	[Bodega] = b.descripcion,
	ciudad_bodega=pb.descripcion,
	[Tipo Doc] = tip.descripcion,
	c.id_cot_tipo,
	[Numero] = c.numero_cotizacion,
	[Id] = c.id,
	[Doc Ref] = dbo.Documento_Ref(c.docref_tipo, c.docref_numero),
	[Fecha Doc] = c.fecha,
	c.fecha_cartera,
	[Fecha Vcmto] = c.fecha_estimada,
	[Cliente] = cli.razon_social,
	[Contacto] = con.nombre,
	[Vendedor] = u2.nombre,
	nit_vendedor=u2.cedula_nit,
	Sigla_URL = cli.url,
	tabla = 46,
	id_kon = NULL,
	c.tal_ope,
	Estado = CASE ISNULL(c.anulada, 0)WHEN 0 THEN NULL --obligatorio dejarlo en NULL
			 WHEN 1 THEN 'Fact'
			 WHEN 2 THEN 'Bloq'
			 WHEN 3 THEN 'Parc'
			 --jdms 670
			 --WHEN 4 THEN 'Anu' ELSE 'Otr' END,
			WHEN 4 THEN CASE WHEN LEFT(CAST(c.notas AS VARCHAR(6)),6)='*cons*' THEN 'Cons' ELSE 'Anu' END 
			ELSE 'Otr' 
			END,
	[Dias validez] = c.dias_validez,
	[Precio Nro] = c.precio_nro,
	[Subtotal] = c.total_sub,
	[Descuento] = c.total_descuento,
	[Ajuste] = c.ajuste,
	[Fletes] = c.deducible_minimo,
	[Valor IVA] = c.total_iva,
	[Valor IVA2] = c.total_iva2,
	[Valor Total] = c.total_total,
	[Direccion] = cli.direccion,
	[Tel 1] = cli.tel_1,
	[Tel 2] = cli.tel_2,
	[Nit] = cli.nit,
	[Digito] = cli.digito,
	[Zona] = z.descripcion,
	[Subzona] = s.descripcion,
	[Cupo credito] = cli.cupo_credito,
	[IVA Fletes] = CASE WHEN tip.sw = 46 THEN NULL ELSE c.valor_proyecto END, --jdms 654,
	[Valor hora] = CASE WHEN tip.sw = 46 THEN c.valor_proyecto ELSE NULL END, --jdms 654

	[EMail Contacto] = con.email,
	[Tel Contacto] = con.tel_1,
	[cedula] = con.cedula,
	[Dir Contacto] = con.direccion,
	[Cargo Contacto] = a.descripcion,
	Ciudad_Contacto = ciu.descripcion,
	[Autorizo] = u3.nombre,
	[Moneda] = ISNULL(mone.descripcion, '(Local)'),
	[Tasa] = CASE WHEN mone.dividir IS NULL THEN c.tasa ELSE c.tasa * -1 END,
	[Nombre Usuario] = u1.nombre,
	[Cargo Usuario] = g.descripcion,
	[EMail Usuario] = u1.email,
	[Notas] = c.notas,
	[Notas Internas] = c.notas_internas,
	[Dir Bodega] = b.direccion,
	[Tel Bodega] = b.telefonos,
	[Publicidad] = b.publicidad,
	[EMail Vendedor] = u2.email,
	[Tel Vendedor] = u2.tel_tra,
	[Ext Vendedor] = u2.ext_tra,
	[Cel Vendedor] = u2.tel_cel,
	[Cargo Vendedor] = g2.descripcion,
	Clase = NULL,
	[Placa] = lo.placa,
	[Vehiculo] = i2.descripcion,
	--[Km] = c.km,
	[Km] = case when (select count(*) 
						from cot_auditoria a 
						inner join usuario u on u.id=a.id_usuario and u.id_usuario_subgrupo=2692--2629
						where id_id=@id and  que like '%km%') >= 1 
			then SUBSTRING(va.campo_5, 1, len(va.campo_5)-3) 
			else c.km end,
	[Rombo] = rom.rombo,
	notas_tipo1 = tip.notas,
	notas_tipo2 = tip.notas2,
	notas_tipo3 = tip.notas3,
	otras_notas = tip.otras_notas,
	c.id_usuario_vende,
	contacto_id = con.id,
	Cliente_ID = c.id_cot_cliente,
	[Fecha Creación] = c.fecha_creacion,
	[Fecha Modificación] = c.fecha_cambio_status_final,
	interes = inte.total,
	pai.pais,
	pai.departamento,
	pai.ciudad,
	Id_Ant = c.id_cot_cotizacion_ant,
	Id_Sig = c.id_cot_cotizacion_sig,
	c.factibilidad,
	c.id_proyectos,
	c.valor_proyecto,
	c.deducible,
	c.deducible_minimo,
	Aseguradora = cli2.razon_social,
	[Id Orden] = c.id_prd_orden,
	firma = fir.imagen,
	va.campo_1,
	va.campo_2,
	va.campo_3,
	va.campo_4,
	va.campo_5,
	va.campo_6,
	va.campo_7,
	va.campo_8,
	va.campo_9,
	va.campo_10,
	va.campo_11,
	va.campo_12,
	va.campo_13,
	va.campo_14,
	va.campo_15,
	va.campo_16,
	va.campo_17,
	va.campo_18,
	va.campo_19,
	va.campo_20,
	Motivo_ingreso = mi.descripcion,
	c.id_veh_hn_enc,														  --esta factura viene de que hoja de negocio
	plan_mto = pl.descripcion,
	Id_Orden_Salida = os.id,
	Fecha_Salida = os.fecha,
	CondicionPago = fp.descripcion,
	Entrego = med.razon_social,
	Fecha_Venta = (select Top 1 fv_c.Fecha
					from cot_cotizacion fv_c
						inner join cot_tipo fv_t on fv_c.id_cot_tipo = fv_t.id
						inner join cot_bodega fv_b on fv_c.id_cot_bodega = fv_b.id
					where fv_t.sw = 1 and fv_c.id_emp = c.id_emp
						and fv_b.descripcion like '%VEHICULO%'
						and fv_c.id_cot_item_lote = c.id_cot_item_lote),
	respuesta1g= dbo.Respuesta_GM (c.id,1),
	respuesta2g= dbo.Respuesta_GM (c.id,2),
	respuesta3g= dbo.Respuesta_GM (c.id,3),
	respuesta4g= dbo.Respuesta_GM (c.id,4),
	respuesta5g= dbo.Respuesta_GM (c.id,5),
	respuesta6g= dbo.Respuesta_GM (c.id,6),
	respuesta7g= dbo.Respuesta_GM (c.id,7),
	respuesta8g= dbo.Respuesta_GM (c.id,8),
	respuesta9g= dbo.Respuesta_GM (c.id,9),
	respuesta10g= dbo.Respuesta_GM (c.id,10),
	respuesta11g= dbo.Respuesta_GM (c.id,11),

Jefe_taller	=u.nombre,--GMAG 747 MEP
	Recomendacion= '',
	--isnull(  (select
	-- stuff(( select DISTINCT '  ' + descripcion + ' ,  ' from  dbo.tal_Orden_Recomendaciones r2   where r2.id_cot_cotizacion=@id	 AND r2.resuelto IS null 
 --        FOR xml path('') ), 1, 1, '')),0)	,	--GMAG 747 MEP
	 FI=dbo.codigo_fec_imp (GETDATE()),
	logo_bodega=b.imagen
	,prueba=null
	
	
FROM dbo.cot_cotizacion c
LEFT JOIN dbo.v_cot_int_mora inte ON inte.id_cot_cliente = c.id_cot_cliente
LEFT JOIN dbo.cot_moneda mone ON mone.id = c.id_cot_moneda
LEFT JOIN dbo.v_cot_item_descripcion i2 ON i2.id = c.id_cot_item
LEFT JOIN dbo.cot_item_lote lo ON lo.id = c.id_cot_item_lote
LEFT JOIN dbo.cot_tipo tip ON tip.id = c.id_cot_tipo
LEFT JOIN dbo.cot_cotizacion c2 ON c2.id = c.id_cot_cotizacion_ant
LEFT JOIN dbo.cot_bodega b ON b.id = c.id_cot_bodega
LEFT JOIN dbo.cot_cotizacion_rombo rom ON rom.id_cot_cotizacion = c.id
LEFT JOIN dbo.usuario u1 ON u1.id = c.id_usuario
LEFT JOIN dbo.usuario_cargo g ON u1.id_usuario_cargo = g.id
LEFT JOIN dbo.usuario u2 ON u2.id = c.id_usuario_vende
LEFT JOIN dbo.usuario_cargo g2 ON u2.id_usuario_cargo = g2.id
LEFT JOIN dbo.usuario u3 ON u3.id = c.id_usuario_autoriza
LEFT JOIN dbo.cot_cliente cli ON cli.id = c.id_cot_cliente
LEFT JOIN dbo.cot_cliente cli2 ON cli2.id = c.id_cot_cliente2
LEFT JOIN dbo.cot_cliente_contacto con ON con.id = @id_contacto
LEFT JOIN dbo.cot_cliente_pais pb ON pb.id=b.id_cot_cliente_pais
LEFT JOIN dbo.cot_cliente_pais ciu ON ciu.id = con.id_cot_cliente_pais
LEFT JOIN dbo.v_cot_cliente_pais pai ON pai.id_cot_cliente = c.id_cot_cliente
LEFT JOIN dbo.cot_cliente_cargo a ON con.id_cot_cliente_cargo = a.id
LEFT JOIN dbo.cot_zona_sub s ON s.id = cli.id_cot_zona_sub
LEFT JOIN dbo.cot_zona z ON z.id = s.id_cot_zona
LEFT JOIN dbo.v_campos_varios va ON va.id_cot_cotizacion = c.id
LEFT JOIN dbo.cot_cotizacion_firma fir ON fir.id_cot_cotizacion = c.id
LEFT JOIN dbo.tal_motivo_ingreso mi ON mi.id = c.id_tal_motivo_ingreso
LEFT JOIN dbo.cot_cotizacion_mas ma ON ma.id_cot_cotizacion = c.id
LEFT JOIN dbo.tal_planes pl ON pl.id = ma.id_tal_planes
LEFT JOIN dbo.v_orden_salida_veh os ON os.id_cot_cotizacion = c.id
LEFT JOIN dbo.cot_forma_pago fp ON fp.id = cli.id_cot_forma_pago
LEFT JOIN dbo.cot_cliente med ON med.id = c.id_cot_cliente_medico
LEFT JOIN dbo.usuario u ON b.id_usuario_jefe = u.id	   --GMAG 747 MEP


WHERE
	c.id = @id

