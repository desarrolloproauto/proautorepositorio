USE [MEPA_Reportes]
GO

-- ===================================================================================================
-- Author:		<Angelica Pinos>
-- Create date: <2021-09-08>
-- Description:	<Obtiene el numero de vehiculos (VIN) que han ingresado a los Talleres en el mes actual.
--               No se consideran las devoluciones>
-- Historial:
--               2022-04-08 Se agrega información de Zona2 (JCB)
-- ===================================================================================================

-- EXEC [dbo].[Get_R_VentasCanalRepuestos_GM] 'Zona 1'

alter PROCEDURE [dbo].[Get_R_VentasCanalRepuestos_GM] 
(
	@zona VARCHAR (MAX)	
)
AS
BEGIN
	
	SET NOCOUNT ON;
	DECLARE @devolucion	VARCHAR (MAX) = 'NO'
	DECLARE @fecActual	DATE 
	select @fecActual = fecha from DWH_Repuestos..DimTiempo where diaVigente = 1

	SELECT x.[Linea Negocio],
	       x.Marca,
		   x.Canal,
		   x.Neto,
		   x.[Original / Alt.]
	FROM
	(
		SELECT	[Linea Negocio] = live.linea_vehiculo
				,Marca = M.Marca
				,Canal = v.canal_venta
				,Neto = r.PRECIO_NETO
				,[Original / Alt.] = r.ORIGINAL_ALTERNO
				,Zona = z.zona
		FROM	[DWH_Repuestos].[dbo].FactVentaRepuestos r
			JOIN	[DWH_Repuestos].[dbo].DimLineaNegocio l on l.id_linea_negocio = r.id_linea_negocio
			JOIN	[DWH_Repuestos].[dbo].DimCanalVenta v on v.id_canal_venta = r.id_canal_venta
			JOIN	[DWH_Repuestos].[dbo].DimBodega b on (b.id = r.id_cot_bodega)
			JOIN	[DWH_Repuestos].[dbo].DimZona z on (z.id_zona = b.id_zona)
			JOIN	[DWH_Repuestos].[dbo].DimTipoOrden tior ON r.id_tipo_orden = tior.id_tipo_orden
			JOIN	[DWH_Repuestos].[dbo].DimLineaVehiculo live ON r.id_linea_vehiculo = live.id_linea_vehiculo
			JOIN	[DWH_Repuestos].[dbo].DimMarca m on m.Id = r.id_marca
		WHERE year(r.FECHA) = year(@fecActual) AND month(r.FECHA) =  month(@fecActual)
			AND l.linea_negocio = 'Repuestos'
			--AND z.zona = @zona
			AND r.ORIGINAL_ALTERNO like '%origin%'
			AND m.Marca in ('Chevrolet','Multimarca')

		UNION ALL
		-- Agregado para Zona2
		select [Linea Negocio] = r2.Categoria,
			   r2.Marca,
			   Canal = r2.Subcanal,
			   Neto = r2.ValorVenta,
			   [Original / Alt.] = r2.Tipo,
			   Zona = 'Zona 2'
		from DWH_Repuestos..v_FactVentaResumidoTaller_Zona2_Repuestos r2
		where r2.Anio = year(@fecActual) AND r2.Mes =  month(@fecActual)
		and r2.Tipo = 'ORIGINAL'
		and r2.Marca in ('CHEVROLET','MULTIMARCA')
	)x
	where x.Zona = @zona
	
END