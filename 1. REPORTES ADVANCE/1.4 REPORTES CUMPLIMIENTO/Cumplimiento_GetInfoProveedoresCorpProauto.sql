-- =============================================
-- Author:		<Javier Chogllo>
-- Create date: <2022-02-16>
-- Description:	<Obtiene información de proveedores de la Corporación Proauto
--               Reporte solicitado por el area de Cumplimiento>
-- =============================================
-- exec [Cumplimiento_GetInfoProveedoresCorpProauto]
alter PROCEDURE [Cumplimiento_GetInfoProveedoresCorpProauto] 
AS
BEGIN
	SET NOCOUNT ON;
	
	declare @emp int = 605
	declare @id_tipo_cliente int = 1193 --CLIENTE / PROVEEDOR
	

	 --561 cliente 495403
	 select cli.id,
			cli.razon_social,
			fecha_compra = max(c.fecha),
			num_compra = c.id,
			t.sw,
			tipo_documento = t.descripcion,
			total = MAX(c.total_total),
			Grupo = MAX(g.descripcion)
	 into #Compras_agrupado_items
	 from cot_cotizacion c
	 join cot_tipo t on t.id = c.id_cot_tipo
	 join cot_cliente cli on cli.id = c.id_cot_cliente
	 join cot_cotizacion_item ci on ci.id_cot_cotizacion = c.id
	 join cot_item i on i.id = ci.id_cot_item
	 JOIN dbo.cot_grupo_sub s ON s.id = i.id_cot_grupo_sub
	 JOIN dbo.cot_grupo g ON g.id = s.id_cot_grupo
	 where c.id_emp = 605
	 and t.sw in (4,4)
	 and t.id not in (1448,1428) --excluye CSI.99.99 - CARGA SALDOS INICIALES INVENTARIO VEH
	 --and cli.id = 380702
	 --and c.id = 495403
	 group by cli.id,cli.razon_social,c.id,t.sw,t.descripcion,g.descripcion

	select x.id_cliente,x.razon_social,x.fecha_compra,x.num_compra,x.total,x.Grupo,x.tipo_documento,x.fila
	into #Compras_Proveedores
	from
	(
		select id_cliente = c.id,
				c.razon_social,
				c.fecha_compra,
				c.num_compra,
				c.total,
				c.Grupo,
				c.tipo_documento,
				fila = rank() over(partition by c.id order by c.fecha_compra desc)
		from #Compras_agrupado_items c
	)x
	where x.fila = 1


	-- Total pagado a proveedores
	select id_prov = c.id,
	       total_pagado = sum(c.total)
	into #Total_pagos_proveedor
	from #Compras_agrupado_items c
	group by c.id


	------------------------------------------------
	-- select final
	------------------------------------------------
	select        TipoCliente = p.descripcion,
	              RUC = cli.nit,
				  Nombres = cli.razon_social,
				  Fecha_creacion = cli.fecha_creacion,
				  Ciudad = ciudad.descripcion,
				  Direccion = cli.direccion,
				  Telefono_1 = cli.tel_1,
				  Telefono_2 = cli.tel_2,
				  Mail = cli.[url],
				  --cli.id,
				  --cal.id_cot_item_cam_combo,
				   Pagado = tpp.total_pagado,
				  [Proveedor es Calificado] = cb.descripcion,
				  [Fecha Calificacion] = cal.fecha,
				  [Fecha Vencimiento] = fec.fecha,
				  compras.Grupo,
				 
				  [Tipo_ult_compra]=compras.tipo_documento,
				  [Num_ult_compra]=compras.num_compra,
				  [Monto ult compra]=compras.total
				  --t.descripcion
              
	from cot_cliente cli
	join cot_cliente_Perfil p on p.id = cli.id_cot_cliente_perfil
	join cot_cliente_pais ciudad on (ciudad.id = cli.id_cot_cliente_pais and ciudad.id_emp = 605)
	--
	join #Compras_Proveedores compras on compras.id_cliente = cli.id
	left join #Total_pagos_proveedor tpp on tpp.id_prov = cli.id

	--
	left join cot_item_cam cal on cli.id = cal.id_cot_cliente and cal.id_cot_item_cam_combo = 1691--in (1691,1785)
	left join cot_item_cam_def d on cal.id_cot_item_cam_def = d.id and d.programa = '0150' and d.id = 1483
	left join cot_item_cam_combo cb on cal.id_cot_item_cam_combo = cb.id --and cb.id = 1691
	--left join cot_item_cam_combo cb on c.id_cot_item_cam_combo = cb.id and cb.id = 1785

	left join cot_item_cam fec on cli.id = fec.id_cot_cliente and fec.id_cot_item_cam_combo = 1785--in (1691,1785)
	left join cot_item_cam_def d2 on fec.id_cot_item_cam_def = d2.id and d2.programa = '0150' and d2.id = 1483
	left join cot_item_cam_combo cb2 on fec.id_cot_item_cam_combo = cb2.id --and cb.id = 1691



	where cli.id_emp = @emp
	and p.id = @id_tipo_cliente 
	--and cli.nit = '1792387485001'--'0102452513001'--'1790598012001'
    --and cli.id = 380702
	
	-- Borrar tablas temporales
	drop table #Compras_agrupado_items
	drop table #Compras_Proveedores
	drop table #Total_pagos_proveedor
END

