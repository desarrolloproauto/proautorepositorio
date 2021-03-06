USE [MEPA_Reportes]
GO
/****** Object:  StoredProcedure [dbo].[Get_RS_R_VentasCanalRepuestos_GM_xFecha]    Script Date: 11/4/2022 10:42:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =====================================================================================================================
-- Author:		<Javier Chogllo>
-- Create date: <2021-11-09>
-- Description:	<Obtiene el numero de vehiculos (VIN) que han ingresado a los Talleres en el mes actual.
--               No se consideran las devoluciones>
-- Historial:
--               2022-04-11 Se agrega información de Zona2 (JCB)
--               2022-04-11 Se controla el ingreso de los parametros de fecha de un mismo mes (JCB)
-- =====================================================================================================================

-- EXEC [Get_RS_R_VentasCanalRepuestos_GM_xFecha] 'Zona 1','2022-03-01','2022-03-31'

ALTER PROCEDURE [dbo].[Get_RS_R_VentasCanalRepuestos_GM_xFecha] 
(
	@zona VARCHAR(10),
	@fecIni	DATE,
	@fecFin	DATE
)
AS
BEGIN
	
	SET NOCOUNT ON;
	DECLARE @devolucion	VARCHAR (MAX) = 'NO'
	declare @Anio_Ini int
	declare @Mes_Ini int
	declare @Anio_Fin int
	declare @Mes_Fin int

	set @Anio_Ini = year(@fecini) 
	set @Anio_Fin = year(@fecfin) 
	set @Mes_Ini = month(@fecini)
	set @Mes_Fin = month(@fecfin)

	IF (@Anio_Ini=@Anio_Fin AND @Mes_Ini=@Mes_Fin)
	BEGIN
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
			--WHERE year(r.FECHA) = year(@fecActual) AND month(r.FECHA) =  month(@fecActual)
			WHERE cast(r.FECHA as date) between @fecIni and  @fecFin
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
			where r2.Anio = year(@fecIni) AND r2.Mes =  month(@fecIni)
			and r2.Tipo = 'ORIGINAL'
			and r2.Marca in ('CHEVROLET','MULTIMARCA')
		)x
		where x.Zona = @zona
	END
	ELSE
	BEGIN
		RAISERROR (N'Fechas ingresadas en diferentes meses',10,1);
	END
END