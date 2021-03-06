USE [dms_smd3]
GO
/****** Object:  StoredProcedure [dbo].[Get_BI_V_GetVehFacturados_NoEntregados]    Script Date: 24/1/2022 15:34:50 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =================================================================================================================================
-- Author:		<Javier Chogllo>
-- Create date: <2021-09-1216
-- Modulo:		<BI>	 			
-- Descripción: <Obtiene información de los vehiculos Entregados y No Entregados, actualiza todos los datos de todos los meses debido
--                 a que pueden haber vehiculos facturados en meses anteriores y que se entreguen en el presente mes >
-- Historial de Cambios:
-- 2021-09-26   Se modifica el SP para que se actualicen los datos del anterior has los primeros 15 dias del mes actual (JCB)
-- 2021-09-26   Se modifica el SP para enviar como parámetro la fecha de cierre o fin de mes (JCB)
-->				
-- =================================================================================================================================

ALTER PROCEDURE [dbo].[Get_BI_V_GetVehFacturados_NoEntregados]
AS

----------------------------------------
declare @fecActual date = cast(getdate() as date)
--declare @fecActual date = DATEADD(MONTH,-1,cast(getdate() as date))
declare @FecFin date = EOMONTH(@fecActual)
--SET @FecIni = '2021-01-01'
PRINT @fecFin
------------------------------------------------------------------------------

BEGIN
	--EXEC [dms_smd3].[dbo].[BI_GetVehFacturados_NoEntregados] @FecIni,@FecFin
	--IF DAY(@fecActual) <= 15
	--BEGIN
	--	declare @FecIni_mesAnterior date = DATEADD(DAY,1,EOMONTH(DATEADD(MONTH,-2,@fecActual)))
	--	declare @FecFin_mesAnterior date = EOMONTH(@FecIni_mesAnterior)
	--	EXEC [dms_smd3].[dbo].[BI_GetVehFacturados_NoEntregados] @FecIni_mesAnterior, @FecFin_mesAnterior
	--END

	EXEC [dms_smd3].[dbo].[BI_V_GetVehFacturados_NoEntregados] @FecFin
END