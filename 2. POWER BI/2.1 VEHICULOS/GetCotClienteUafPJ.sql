USE [dms_smd3]
GO
/****** Object:  StoredProcedure [dbo].[GetCotClienteUafPJ]    Script Date: 18/2/2022 9:48:49 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- EXEC [dbo].[GetCotClienteUafPJ] 12815
ALTER PROCEDURE [dbo].[GetCotClienteUafPJ] 
(
	@id_hn INT
)
AS
/*
DECLARE @id_hn INT = 9859;
drop table if exists #hn;
drop table if exists #max_hn;
drop table if exists #transaccion;
*/

-- =====================================================================================================================
-- Author:		<>
-- Create date: <>
-- Modulo:		<Formatos>
-- Description:	<Procedimiento para obtener el formato de conozca a su cliente PJ>
-- Historial de Cambios:
-- 19-08-2021	Se agrega los campos de provincia y proveniencia de fondos
-- 20-08-2021	Se agrega campos relacionados con la tranasccion y el beneficiario
-- 08-09-2021	Se agrega campos relacionados con los socios y accionistas
-- 09-09-2021	Se agrega informacion del beneficiario y socios
-- 24-09-2021	Se quita la validacion de sexo del beneficiario ya que no existe aun el campo (APF)
-- 27-10-2021	Se agrega doble tabla donde se pueda obtener la nacionalidad del cliente (APF)
-- 27-10-2021	Se cambia la busqueda del vehiculo por item no por lote (APF)
-- 18-02-2022	Se corrige el porcentaje del valor del vehículo  (JCB)
-- =====================================================================================================================

-- #Hn -->	Obtenemos la hoja de negocio hecha al tercero 
SELECT	e.*, 
		c.id as id_cot_cliente, 
		b.descripcion as descBodega
INTO	#hn
FROM	dbo.veh_hn_enc e
	JOIN	dbo.cot_cliente_contacto cc ON cc.id = e.id_cot_cliente_contacto
	JOIN	dbo.cot_cliente c ON c.id = cc.id_cot_cliente
	JOIN	dbo.cot_bodega b on e.id_cot_bodega = b.id
WHERE	e.id = @id_hn;

-- @id_cot_cliente -->	Asignamos a la variale @id_cot_cliente el ID del cliente
Declare @id_cot_cliente int
SELECT @id_cot_cliente= c.id 
FROM	dbo.veh_hn_enc e
	JOIN	dbo.cot_cliente_contacto cc ON cc.id = e.id_cot_cliente_contacto
	JOIN	dbo.cot_cliente c ON c.id = cc.id_cot_cliente
WHERE	e.id = @id_hn;

-- Empresa -->	Obtener los datos de la persona jurídica
SELECT	DISTINCT
		nit = c.nit, c.id
		,nacionalidad = pais.pais
		,razon_social = ISNULL (UPPER(c.razon_social), '')
		,nombre_comercial = ISNULL (UPPER(p.nombre_comercial), '')
		,act_economica = ISNULL (UPPER( cca.descripcion), '') --rml 742 act.descripcion,
		,mail = ISNULL (c.url, ct.email)
		,provincia = pais.departamento -- Se agrega la provincia
		,ciudad = UPPER(pais.ciudad)
		,telefono = ISNULL (c.tel_2 + '/' + c.tel_1, '')
		,direccion = ISNULL (ct.direccion, c.direccion)
		,ce = CASE 
				WHEN c.nit IS NULL THEN 'RUC,'
				WHEN pais.pais IS NULL THEN 'NACIONALIDAD,'
				WHEN c.razon_social IS NULL THEN 'RAZON SOCIAL,'
				--WHEN p.nombre_comercial IS NULL THEN 'NOMBRE COMERCIAL,'
				WHEN cca.descripcion IS NULL THEN 'ACTIVIDAD ECOOMICA,'
				WHEN ISNULL (c.url, ct.email) IS NULL THEN 'EMAIL,'
				WHEN pais.departamento IS NULL THEN 'PROVINCIA,'
				WHEN pais.ciudad IS NULL THEN 'CIUDAD,'
				WHEN ISNULL (c.tel_2, c.tel_1) IS NULL THEN 'TELEFONO,'
				WHEN ISNULL (ct.direccion, c.direccion) IS NULL THEN 'DIRECCION,'
				ELSE ''
			END
FROM	dbo.cot_cliente c
		 JOIN	dbo.emp e ON e.id = c.id_emp -- CGS 633
	LEFT JOIN	dbo.cot_cliente_uaf p ON p.id_cot_cliente = c.id
	LEFT JOIN	dbo.cot_cliente_contacto ct ON ct.id = c.id_cot_cliente_contacto
	LEFT JOIN	dbo.cot_cliente_actividad cca ON cca.id = c.id_cot_cliente_actividad
	LEFT JOIN	dbo.v_cot_cliente_pais pais ON pais.id_cot_cliente = c.id
	LEFT JOIN	#hn hn ON hn.id_cot_cliente = c.id 
WHERE hn.id = @id_hn;

-- #Representante legal
SELECT	DISTINCT	
		nit = clrl.nit
		,nacionalidad = isnull(uaf11rl.descripcion, uaf10rl.descripcion)
		,razon_social = clrl.razon_social 
		,mail = CASE WHEN clrl.url = '' THEN corl.email ELSE clrl.url END
		,estado_civil = CASE corl.estado_civil	
							WHEN 1 THEN 'SOLTERO (A)'
							WHEN 2 THEN 'CASADO (A)'
							WHEN 3 THEN 'UNIÓN LIBRE'
							WHEN 4 THEN 'DIVORCIADO (A)'
							WHEN 5 THEN 'S.C LIQUIDADA'
							WHEN 6 THEN 'VIUDO (A)' -- Se agrega para el estado civil viudo
							ELSE 'NO APLICA' 
						END
		,genero = CASE
					WHEN corl.sexo = 1 THEN 'MASCULINO'
					WHEN corl.sexo = 2 THEN 'FEMENINO' 
					ELSE '' 
				END
		,identificacion_conyugue = p.identificacion_conyuge
		,apellido_conyugue = ISNULL (UPPER (p.apellido_conyuge + ' ' + p.nombre_conyuge), '')
		,provincia = UPPER (paisrl.departamento)
		,ciudad = UPPER (paisrl.ciudad)
		,telefono = CASE WHEN clrl.tel_2 = '' THEN corl.tel_1 ELSE clrl.tel_2 END
		,direccion = CASE WHEN clrl.direccion = '' THEN UPPER( corl.direccion) ELSE UPPER (clrl.direccion) END
		,cr = CASE 
				WHEN clrl.nit IS NULL THEN 'IDENTIFICACIÓN REPRESENTANTE LEGAL,'
				WHEN isnull(uaf11rl.descripcion, uaf10rl.descripcion) IS NULL THEN 'NACIONALIDAD REPRESENTANTE LEGAL,'
				WHEN clrl.razon_social IS NULL THEN 'RAZÓN SOCIAL REPRESENTANTE LEGAL,'
				WHEN ISNULL (clrl.url, corl.email) IS NULL THEN 'EMAIL REPRESENTANTE LEGAL,'
				WHEN corl.estado_civil IS NULL THEN 'ESTADO CIVIL REPRESENTANTE LEGAL,'
				WHEN corl.estado_civil = 2 THEN 
					CASE WHEN p.identificacion_conyuge IS NULL THEN 'CONYUGE REPRESENTANTE LEGAL,' ELSE '' END
				WHEN corl.sexo IS NULL THEN 'SEXO REPRESENTANTE LEGAL,'
				WHEN paisrl.departamento IS NULL THEN 'PROVINCIA REPRESENTANTE LEGAL,'
				WHEN paisrl.ciudad IS NULL THEN 'CIUDAD REPRESENTANTE LEGAL,'
				WHEN ISNULL (clrl.tel_2, corl.tel_1) IS NULL THEN 'TELEFONO REPRESENTANTE LEGAL,'
				WHEN ISNULL (clrl.direccion, corl.direccion) IS NULL THEN 'DIRECCION REPRESENTANTE LEGAL,'
				ELSE ''
			END
FROM	dbo.cot_item_cam cim 
	left join dbo.cot_item_cam_def d on d.id=cim.id_cot_item_cam_def
	left JOIN dbo.cot_cliente_contacto corl ON corl.id = cim.id_id AND d.tipo_dato = 10
	LEFT JOIN dbo.cot_cliente_uaf p ON p.id_cot_cliente = corl.id_cot_cliente
	left JOIN dbo.cot_cliente clrl ON clrl.id = corl.id_cot_cliente
	left JOIN dbo.cot_cliente_uaf prl ON prl.id_cot_cliente = clrl.id
	left JOIN dbo.cot_uaf uaf10rl ON uaf10rl.id = prl.id_cot_uaf10
	left JOIN dbo.cot_uaf uaf11rl ON uaf11rl.id = prl.id_cot_uaf11
	LEFT JOIN dbo.v_cot_cliente_pais paisrl ON paisrl.id_cot_cliente = clrl.id
	LEFT JOIN dbo.cot_uaf uaf15 ON uaf15.id = p.id_cot_uaf15
WHERE cim.id_cot_cliente = @id_cot_cliente;

-- #Max_hn -->	Temporal con última HN hecha al tercero
SELECT	TOP(1)
		MAX(e.id) AS id_hn,
		@id_cot_cliente AS id_cliente
INTO	#Max_hn
FROM	dbo.veh_hn_enc e
	JOIN	dbo.cot_cliente_contacto cc ON cc.id = e.id_cot_cliente_contacto
	JOIN	dbo.cot_cliente c ON c.id = cc.id_cot_cliente
WHERE c.id = @id_cot_cliente;

-- Accionistas
SELECT	nit = clco.cedula
		,nombres = clco.nombre
		,participacion = ISNULL (clco.cantidad_hijos, 0)
		,nacionalidad = ISNULL (pais.pais, '')
		,actividad = ISNULL (clco.reemplazo, '')
		,cargo = ISNULL (carg.descripcion, '')
		,tipo = ISNULL (coti.descripcion, '')
		,ca = CASE
				WHEN clco.cedula IS NULL THEN 'CEDULA ACCIONISTAS,'
				WHEN clco.nombre IS NULL THEN 'NOMBRES ACCIONISTAS,'
				WHEN clco.cantidad_hijos IS NULL THEN '% PARTICIPACION ACCIONISTAS,'
				WHEN pais.pais IS NULL THEN 'NACIONALIDAD ACCIONISTAS,'
				WHEN clco.reemplazo IS NULL THEN 'ACTIVIDAD ACCIONISTAS,'
				WHEN carg.descripcion IS NULL THEN 'CARGO ACCIONISTAS,'
				WHEN coti.descripcion IS NULL THEN 'TIPO ACCIONISTAS,'
				ELSE ''
			END
FROM	cot_cliente_contacto clco
	JOIN #Max_hn cli ON cli.id_cliente = clco.id_cot_cliente
	LEFT JOIN	v_ciudades_pais pais ON clco.id_cot_cliente_pais = pais.id_cot_cliente_ciudad
	LEFT JOIN	cot_cliente_cargo carg ON clco.id_cot_cliente_cargo = carg.id
	LEFT JOIN	cot_cliente_contacto_tipo coti ON clco.id_cot_cliente_contacto_tipo = coti.id
WHERE coti.descripcion IS NOT NULL;

SELECT	DISTINCT
		ingresos = ISNULL (p.otros_ingresos, 0) + ISNULL (p.ingresos_mes, 0) + ISNULL (p.otros_ingresos_p, 0) + ISNULL (p.ingresos_mes_p, 0)
		,egresos = ISNULL (p.egresos, 0) + ISNULL (p.egresos_mes_p, 0) + ISNULL (egresos_p, 0)
		,activos = ISNULL (p.total_activos, 0) + ISNULL (p.total_activos_p, 0)
		,pasivos = ISNULL (p.total_pasivos, 0) + ISNULL (p.total_pasivos_p, 0)
		,patrimonio = (ISNULL (p.total_activos, 0) + ISNULL (p.total_activos_p, 0)) - (ISNULL (p.total_pasivos, 0) + ISNULL (p.total_pasivos_p, 0))
		,fondos = uaf15.descripcion
		,fondos2 = uaf16.descripcion
		,cec = CASE
				WHEN ISNULL (p.otros_ingresos, 0) + ISNULL (p.ingresos_mes, 0) + ISNULL (p.otros_ingresos_p, 0) + ISNULL (p.ingresos_mes_p, 0) < 0 THEN 'MONTO DE INGRESOS, '
				WHEN ISNULL (p.egresos, 0) + ISNULL (p.egresos_mes_p, 0) + ISNULL (egresos_p, 0) < 0 THEN 'MONTO DE EGRESOS, '
				WHEN ISNULL (p.total_activos, 0) + ISNULL (p.total_activos_p, 0) < 0 THEN 'TOTAL ACTIVOS, '
				WHEN ISNULL (p.total_pasivos, 0) + ISNULL (p.total_pasivos_p, 0) < 0 THEN 'TOTAL PASIVOS, '
				WHEN uaf15.descripcion IS NULL THEN 'PROCEDENCIA DE FONDOS,'
				WHEN uaf16.descripcion IS NULL THEN 'PROCEDENCIA DE FONDOS,'
				ELSE ''
			END
FROM	dbo.cot_cliente_uaf p 
	LEFT JOIN	dbo.cot_uaf uaf15 ON uaf15.id = p.id_cot_uaf15
	LEFT JOIN	dbo.cot_uaf uaf16 ON uaf16.id = p.id_cot_uaf16
WHERE	p.id_cot_cliente = @id_cot_cliente;

-- #Transaccion	Obtenemos los datos de la transaccion de la hoja de negocio
SELECT	tipo_transaccion = 'COMPRA VEHÍCULO'
		,moneda = 'DOLAR'
		,valor_transaccion = ISNULL (pedi.total_total, 0)
		,fecha_transaccion = pedi.fecha
		,tipo_documento = ISNULL (tido.descripcion, '')
		,numero_documento = ISNULL (hn.id, '')
		,modelo = vehi.descripcion
		,vigencia = 'MENSUAL'
		,ct = CASE 
				WHEN pedi.total_total IS NULL THEN 'VALOR DE LA TRANSACCIÓN, '
				WHEN pedi.fecha IS NULL THEN 'FECHA DE LA TRANSACCIÓN, '
				WHEN tido.descripcion IS NULL THEN 'TIPO DE DOCUMENTO, '
				WHEN hn.id IS NULL THEN 'NÚMERO DE DOCUMENTO, '
				WHEN vehi.descripcion IS NULL THEN 'VEHICULO, '
				ELSE ''
			END
INTO #Transaccion 
FROM	#hn hn
	LEFT JOIN	veh_hn_enc hnen			ON hnen.id = hn.id
	LEFT JOIN	veh_hn_pedidos hnpe		ON hnpe.id_veh_hn_enc = hnen.id
	LEFT JOIN	cot_pedido pedi			ON pedi.id = hnpe.id_cot_pedido
		 JOIN	cot_pedido_item item	ON item.id_cot_pedido = pedi.id
		 JOIN	cot_item vehi			ON vehi.id = item.id_cot_item
	LEFT JOIN	cot_grupo_sub sub		ON sub.id = vehi.id_cot_grupo_sub
	LEFT JOIN	cot_grupo gru			ON gru.id = sub.id_cot_grupo
	LEFT JOIN	cot_tipo tido			ON tido.id = hn.id_cot_tipo	
	LEFT JOIN	v_campos_varios cvar	ON cvar.id_cot_item_lote = vehi.id
WHERE	gru.descripcion = 'VEHICULOS';

SELECT * FROM #Transaccion;

SELECT	id = tra.numero_documento
        ,tra.valor_transaccion
		,valor_tercero = fpag.valor
		,porcentaje_tercero = (fpag.valor * 100) / tra.valor_transaccion 
		,tipo1 = 'val' + CAST (fpag.id_veh_tipo_pago AS varchar(2))
		,tipo2 = 'por' + CAST (fpag.id_veh_tipo_pago AS varchar(2))
		,valCD = reci.valor_total_pagado
		,porCD = CASE 
					WHEN reci.id_veh_hn_enc IS NOT NULL THEN (reci.valor_total_pagado * 100) / tra.valor_transaccion 
					ELSE 0
				END
		,cf = CASE	
				WHEN ISNULL (fpag.valor, 0) + ISNULL (reci.valor_total_pagado, 0) = 0 THEN 'DETALLE DE VALORES PAGADOS, '
				ELSE ''
			END
INTO #Trans
FROM #Transaccion tra 
	LEFT JOIN veh_hn_forma_pago fpag ON fpag.id_veh_hn_enc = tra.numero_documento
	LEFT JOIN v_veh_hn_total_pagado_ped reci ON reci.id_veh_hn_enc = tra.numero_documento


select id
       ,valCaja = sum(val1)
	   ,valUsado = ISNULL (SUM (val2), 0) + ISNULL (SUM (val6), 0)
	   ,valFinanciera = ISNULL (SUM (val3), 0) + ISNULL (SUM (val8), 0) + ISNULL (SUM (val4), 0) + ISNULL (SUM (val7), 0)
	   ,valNC = ISNULL (SUM (val5), 0) + ISNULL (SUM (val10), 0)
	   ,valCD = ISNULL (MAX (valCD), 0)
	   ,refCaja = CASE WHEN SUM (val1) IS NOT NULL THEN 'Valor entregado en caja' ELSE '' END
	   ,refUsado = CASE WHEN SUM (val2) IS NOT NULL THEN 'Vehículo usado ' ELSE '' END + CASE WHEN SUM (val6) IS NOT NULL THEN 'Vehiculo usado consignado' ELSE '' END 
	   ,refFinanciera = CASE WHEN SUM (val3) IS NOT NULL THEN 'Crédito Fianciera ' ELSE '' END + CASE WHEN SUM (val8) IS NOT NULL THEN 'Tarjeta de crèdito' ELSE '' END + CASE WHEN SUM (val4) IS NOT NULL THEN 'Crédito directo' ELSE '' END + CASE WHEN SUM (val7) IS NOT NULL THEN 'Crédito consumo' ELSE '' END 
	   ,refNC = CASE WHEN SUM (val5) IS NOT NULL THEN 'Nota de crèdito' ELSE '' END + CASE WHEN SUM (val10) IS NOT NULL THEN 'Retención' ELSE '' END 
	   ,refCD = CASE WHEN SUM (valCD) IS NOT NULL THEN 'Crédito interno' ELSE '' END
	   ,cf = MAX (cf)
into #pivot1
from #Trans
--PIVOT (SUM(porcentaje_tercero) FOR tipo2 IN (por1)) 
--AS PT2	
PIVOT (SUM(valor_tercero) 
       FOR tipo1 IN (val1, val2, val3, val4, val5, val6, val7, val8, val9, val10)

      ) AS PT1
group by id


select id
       ,porCaja = sum(por1)
	   ,porUsado = ISNULL (SUM (por2), 0) + ISNULL (SUM (por6), 0)
	   ,porFinanciera = ISNULL (SUM (por3), 0) + ISNULL (SUM (por8), 0) + ISNULL (SUM (por4), 0) + ISNULL (SUM (por7), 0)
	   ,porNC = ISNULL (SUM (por5), 0) + ISNULL (SUM (por10), 0)
	   ,porCD = ISNULL (MAX (porCD), 0)
	   ,cf = MAX (cf)
into #pivot2
from #Trans
PIVOT (SUM(porcentaje_tercero) FOR tipo2 IN (por1, por2, por3, por4, por5, por6, por7, por8, por9, por10)) 
AS PT2	
group by id

select p1.id,p1.valCaja,valUsado,valFinanciera,valNC,valCD,porCaja,porUsado,porFinanciera,porNC,porCD,refCaja,refUsado,refFinanciera,refNC,refCD,p1.cf
from #pivot1 p1
join #pivot2 p2 on p1.id = p2.id



-- EXEC [dbo].[GetCotClienteUafPJ_BORRADOR] 12815

---- #Fondos	Obtenemos las formas de pago empleadas en la transacción
--SELECT	id
--		,valCaja = ISNULL (SUM (val1), 0)
--		,valUsado = ISNULL (SUM (val2), 0) + ISNULL (SUM (val6), 0)
--		,valFinanciera = ISNULL (SUM (val3), 0) + ISNULL (SUM (val8), 0) + ISNULL (SUM (val4), 0) + ISNULL (SUM (val7), 0)
--		,valNC = ISNULL (SUM (val5), 0) + ISNULL (SUM (val10), 0)
--		,valCD = ISNULL (MAX (valCD), 0)
--		--,porCaja = ISNULL (SUM (por1), 0)
--		,porCaja = por1
--		,porUsado = ISNULL (SUM (por2), 0) + ISNULL (SUM (por6), 0)
--		,porFinanciera = ISNULL (SUM (por3), 0) + ISNULL (SUM (por8), 0) + ISNULL (SUM (por4), 0) + ISNULL (SUM (por7), 0)
--		,porNC = ISNULL (SUM (por5), 0) + ISNULL (SUM (por10), 0)
--		,porCD = ISNULL (MAX (porCD), 0)
--		,refCaja = CASE WHEN SUM (val1) IS NOT NULL THEN 'Valor entregado en caja' ELSE '' END
--		,refUsado = CASE WHEN SUM (val2) IS NOT NULL THEN 'Vehículo usado ' ELSE '' END + CASE WHEN SUM (val6) IS NOT NULL THEN 'Vehiculo usado consignado' ELSE '' END 
--		,refFinanciera = CASE WHEN SUM (val3) IS NOT NULL THEN 'Crédito Fianciera ' ELSE '' END + CASE WHEN SUM (val8) IS NOT NULL THEN 'Tarjeta de crèdito' ELSE '' END + CASE WHEN SUM (val4) IS NOT NULL THEN 'Crédito directo' ELSE '' END + CASE WHEN SUM (val7) IS NOT NULL THEN 'Crédito consumo' ELSE '' END 
--		,refNC = CASE WHEN SUM (val5) IS NOT NULL THEN 'Nota de crèdito' ELSE '' END + CASE WHEN SUM (val10) IS NOT NULL THEN 'Retención' ELSE '' END 
--		,refCD = CASE WHEN SUM (valCD) IS NOT NULL THEN 'Crédito interno' ELSE '' END
--		,cf = MAX (cf)
--FROM (
--		SELECT	id = tra.numero_documento
--				,valor_tercero = fpag.valor
--				,porcentaje_tercero = (fpag.valor * 100) / tra.valor_transaccion 
--				,tipo1 = 'val' + CAST (fpag.id_veh_tipo_pago AS varchar(2))
--				,tipo2 = 'por' + CAST (fpag.id_veh_tipo_pago AS varchar(2))
--				,valCD = reci.valor_total_pagado
--				,porCD = CASE 
--							WHEN reci.id_veh_hn_enc IS NOT NULL THEN (reci.valor_total_pagado * 100) / tra.valor_transaccion 
--							ELSE 0
--						END
--				,cf = CASE	
--						WHEN ISNULL (fpag.valor, 0) + ISNULL (reci.valor_total_pagado, 0) = 0 THEN 'DETALLE DE VALORES PAGADOS, '
--						ELSE ''
--					END
--		FROM #Transaccion tra 
--			LEFT JOIN veh_hn_forma_pago fpag ON fpag.id_veh_hn_enc = tra.numero_documento
--			LEFT JOIN v_veh_hn_total_pagado_ped reci ON reci.id_veh_hn_enc = tra.numero_documento
--) Tipos
--PIVOT (SUM(valor_tercero) 
--       FOR tipo1 IN (val1, val2, val3, val4, val5, val6, val7, val8, val9, val10)

--      ) AS PT1
--PIVOT (SUM	(porcentaje_tercero) FOR tipo2 IN (por1, por2, por3, por4, por5, por6, por7, por8, por9, por10)) AS PT2	
--GROUP BY id;




-- #Beneficiario
SELECT	beneficiario = CASE WHEN (uaf.nombre3 IS NOT NULL AND LEN (uaf.nombre3) > 0) THEN 'NO' ELSE 'SI' END
		,nombre = uaf.nombre3
		,identificacion = uaf.documento3
		,sexo = ISNULL (UPPER (uaf.telefono3_2), '')
		,nacionalidad = ''
		,parentesco = CASE 
							WHEN uaf.relacion = 1 THEN 'FAMILIAR'
							WHEN uaf.relacion = 2 THEN 'EMPLEADO'
							WHEN uaf.relacion = 3 THEN 'OTRA'
							ELSE ''
						END
		,descripcion = ISNULL (UPPER (uaf.desc_relacion), '')
		,cb = CASE 
					WHEN (uaf.nombre3 IS NOT NULL AND LEN (uaf.nombre3) > 0) THEN 
						CASE	
							WHEN uaf.nombre3 IS NULL THEN 'NOMBRE DEL BENEFICIARIO, '
							WHEN uaf.documento3 IS NULL THEN 'IDENTIFICACIÓN DEL BENEFICIARIO, '
							--WHEN uaf.telefono3_2 IS NULL THEN 'SEXO DEL BENEFICIARIO, '
							WHEN uaf.relacion IS NULL THEN 'PARENTESCO CON EL BENEFICIARIO, '
							WHEN uaf.desc_relacion IS NULL THEN 'RELACIÓN CON EL BENEFICIARIO, '
							ELSE ''
						END
				ELSE '' 
			END
FROM dbo.cot_item_cam cim 
	left join dbo.cot_item_cam_def d on d.id=cim.id_cot_item_cam_def
	left JOIN dbo.cot_cliente_contacto corl ON corl.id = cim.id_id AND d.tipo_dato = 10
	LEFT JOIN dbo.cot_cliente_uaf uaf ON uaf.id_cot_cliente = corl.id_cot_cliente
WHERE cim.id_cot_cliente = @id_cot_cliente;

-- Peps y final
SELECT DISTINCT
		peps1 = CASE p.desemp WHEN 1 THEN 'SI' ELSE 'NO' END
		,cargo1 = ISNULL (p.des_desemp1, '')
		,fecha1 = p.fecha_desemp_1
		,peps1 = CASE p.desemp1 WHEN 1 THEN 'SI' ELSE 'NO' END
		,relacion2 = ISNULL (p.relacion_2, '')
		,nombres2 = ISNULL (p.nombres_rel_2, '')
		,cargo2 = ISNULL (p.cargo_2, '')
		,fecha2 = p.fecha_desemp_2
		,vendedor = UPPER (ven.nombre)
		,cp1 = CASE p.desemp 
					WHEN 1 THEN 
						CASE 
							WHEN p.des_desemp1 IS NULL THEN 'CARGO COMO PEP, '
							WHEN p.fecha_desemp_1 IS NULL THEN 'FECHA DEL CARGO COMO PEP '
							ELSE ''
						END
					ELSE '' 
				END
		,cp2 = CASE p.desemp1
					WHEN 1 THEN 
						CASE 
							WHEN p.relacion_2 IS NULL THEN 'RELACIÓN CON PEP, '
							WHEN p.nombres_rel_2 IS NULL THEN 'NOMBRE DE PEP, '
							WHEN p.cargo_2 IS NULL THEN 'CARGO DE LA PEP, '
							WHEN p.fecha_desemp_2 IS NULL THEN 'FECHA DEL CARGO DE LA PEP, '
							ELSE ''
						END
					ELSE '' 
				END
FROM dbo.cot_cliente c
	left JOIN dbo.cot_cliente_uaf p ON p.id_cot_cliente = c.id
	LEFT JOIN dbo.usuario ven ON ven.id = c.id_usuario_vendedor
WHERE c.id = @id_cot_cliente;
