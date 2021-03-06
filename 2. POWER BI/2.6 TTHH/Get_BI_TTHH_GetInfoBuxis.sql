USE [DWH_Buxis]
GO
/****** Object:  StoredProcedure [dbo].[Get_BI_TTHH_GetInfoBuxis]    Script Date: 30/3/2022 9:41:19 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================================================================================================
-- Author:		<Javier Chogllo>
-- Create date: <2021-01-03>
-- Description:	<Actualiza las tablas para el BI de TTHH (Mes Cierre Anterior)>
-- Historial:   <2022-01-18 Se ajusta script para la tabla HeadCount para que obtenga informacion de las empresas:
--                          1	MIRASOL S.A                   
--                          2	EMAULME C.A.                  
--                          3	CORPORACION PROAUTO S.A.      
--                          4	AUTOMOTORES DE LA SIERRA S.A  
--                          10	AUTOFACTOR IMPORT AFI S.A.> 
--              <2022-03-30 Se agrega la tabla "PUESTOS" al Datawarehouse  (JCB)
--              <2022-03-30 Se agrega la tabla "UNIDADES_ORGANIZATIVAS" al Datawarehouse  (JCB)

-- =============================================================================================================================

-- EXEC [dbo].[Get_BI_TTHH_GetInfoBuxis]
ALTER PROCEDURE [dbo].[Get_BI_TTHH_GetInfoBuxis]
AS
BEGIN
	-------------------------------------------------------------------------------------------------
	declare @fec_actual date = GETDATE()
	-------------------------------------------------------------------------------------------------
	
	--declare @fec_cierre date = eomonth(@fec_actual)
	--declare @fec_inicio date = DATEADD(DAY,1,EOMONTH(DATEADD(MONTH,-1,@fec_cierre)))
	--PRINT @fec_cierre
	--PRINT @fec_inicio
	declare @RowsIn int
	declare @RowsDelete int

	-------------------------------------------------------------------------------------------------
	-- Tabla Bitacora Diaria
	-------------------------------------------------------------------------------------------------
	declare @Bitacora_Diaria as table
	(
		fecha_escribe datetime,
		tabla nvarchar(100),
		num_insert int,
		num_rows_actual int	
	)
	SET NOCOUNT ON;
    -------------------------------------------------------------------------------------------------
    -- Tabla: CONCEPTOS
	-- Tipo Actualización: TOTAL (Se actualiza toda la tabla)
	-- Periodicidad: MENSUAL
	-------------------------------------------------------------------------------------------------
	INSERT INTO CONCEPTOS
	select COD_MV,
	       DESC_MV COLLATE SQL_Latin1_General_CP1_CI_AS,
		   MANUAL_CALCULADO COLLATE SQL_Latin1_General_CP1_CI_AS,
		   INGRESO_DESCUENTO COLLATE SQL_Latin1_General_CP1_CI_AS,
		   INFORMATIVO COLLATE SQL_Latin1_General_CP1_CI_AS
	from [SERVER-DB].[BIBUXIS].[dbo].[CONCEPTOS]
	EXCEPT
	select COD_MV,
	       DESC_MV,
		   MANUAL_CALCULADO,
		   INGRESO_DESCUENTO,
		   INFORMATIVO
	from CONCEPTOS
	set @RowsIn = @@ROWCOUNT

	insert @Bitacora_Diaria values(@fec_actual,'CONCEPTOS',@RowsIn,(select COUNT(*) from CONCEPTOS))
	-------------------------------------------------------------------------------------------------
    -- Tabla: CONCEPTOS
	-- Tipo Actualización: CON FECHA DE CIERRE
	-- Periodicidad: MENSUAL
	-------------------------------------------------------------------------------------------------
	DELETE from COSTO_NOMINA
	INSERT INTO COSTO_NOMINA
	select AGRUPACION COLLATE SQL_Latin1_General_CP1_CI_AS,
	       EMPRESA,
		   CLASIFICACION COLLATE SQL_Latin1_General_CP1_CI_AS,
		   FECHA_LIQUIDACION,
		   VALOR,
		   PORCENTAJE,
		   PERSONAL
	from [SERVER-DB].[BIBUXIS].[dbo].[COSTO_NOMINA]
	--EXCEPT
	--select AGRUPACION,
	--       EMPRESA,
	--	   CLASIFICACION,
	--	   FECHA_LIQUIDACION,
	--	   VALOR,
	--	   PORCENTAJE,
	--	   PERSONAL
	--from [SERVER-DB].[BIBUXIS].[dbo].[COSTO_NOMINA]
	set @RowsIn = @@ROWCOUNT

	insert @Bitacora_Diaria values(@fec_actual,'COSTO_NOMINA',@RowsIn,(select COUNT(*) from COSTO_NOMINA))

	-------------------------------------------------------------------------------------------------
    -- Tabla: COSTOS_FINIQUITOS
	-- Tipo Actualización: CON FECHA DE CIERRE
	-- Periodicidad: MENSUAL
	-------------------------------------------------------------------------------------------------
	INSERT INTO COSTOS_FINIQUITOS
	select COD_EMP,
	       [AÑO],
		   MES,
		   COD_MV,
		   VALOR
	from [SERVER-DB].[BIBUXIS].[dbo].[COSTOS_FINIQUITOS]
	EXCEPT
	SELECT COD_EMP,
	       [AÑO],
		   MES,
		   COD_MV,
		   VALOR 
    FROM COSTOS_FINIQUITOS

	set @RowsIn = @@ROWCOUNT

	insert @Bitacora_Diaria values(@fec_actual,'COSTOS_FINIQUITOS',@RowsIn,(select COUNT(*) from COSTOS_FINIQUITOS))

	-------------------------------------------------------------------------------------------------
    -- Tabla: DEPARTAMENTOS
	-- Tipo Actualización: TOTAL
	-- Periodicidad: MENSUAL
	-------------------------------------------------------------------------------------------------
	INSERT INTO DEPARTAMENTOS
	select COD_DEP COLLATE SQL_Latin1_General_CP1_CI_AS,
	       DESCRIPCION COLLATE SQL_Latin1_General_CP1_CI_AS
	from [SERVER-DB].[BIBUXIS].[dbo].[DEPARTAMENTOS]
	EXCEPT
	select COD_DEP,
	       DESCRIPCION
	from DEPARTAMENTOS
	set @RowsIn = @@ROWCOUNT

	insert @Bitacora_Diaria values(@fec_actual,'DEPARTAMENTOS',@RowsIn,(select COUNT(*) from DEPARTAMENTOS))
	-------------------------------------------------------------------------------------------------

	-------------------------------------------------------------------------------------------------
    -- Tabla: EMPRESA
	-- Tipo Actualización: TOTAL
	-- Periodicidad: MENSUAL
	-------------------------------------------------------------------------------------------------
	INSERT INTO EMPRESA
	select COD_EMP ,
	       NOM_EMP COLLATE SQL_Latin1_General_CP1_CI_AS
	from [SERVER-DB].[BIBUXIS].[dbo].[EMPRESA]
	EXCEPT
	select COD_EMP,
	       NOM_EMP
	from EMPRESA
	set @RowsIn = @@ROWCOUNT

	insert @Bitacora_Diaria values(@fec_actual,'EMPRESA',@RowsIn,(select COUNT(*) from EMPRESA))
	-------------------------------------------------------------------------------------------------

	-------------------------------------------------------------------------------------------------
    -- Tabla: FACTS_CONTEO
	-- Tipo Actualización: TOTAL
	-- Periodicidad: MENSUAL
	-------------------------------------------------------------------------------------------------
	INSERT INTO FACTS_CONTEO
	select COD_FCO COLLATE SQL_Latin1_General_CP1_CI_AS,
	       DESC_FCO COLLATE SQL_Latin1_General_CP1_CI_AS
	from [SERVER-DB].[BIBUXIS].[dbo].[FACTS_CONTEO]
	EXCEPT
	select COD_FCO ,
	       DESC_FCO
	from FACTS_CONTEO
	set @RowsIn = @@ROWCOUNT

	insert @Bitacora_Diaria values(@fec_actual,'FACTS_CONTEO',@RowsIn,(select COUNT(*) from FACTS_CONTEO))


	-------------------------------------------------------------------------------------------------
    -- Tabla: HEAD_COUNT
	-- Tipo Actualización: CON FECHA DE CIERRE
	-- Periodicidad: MENSUAL
	-------------------------------------------------------------------------------------------------
	--DELETE hc
	--FROM HEAD_COUNT hc
	--where cast(hc.fecha_cierre as date) = @fec_cierre
	--set @RowsDelete = @@ROWCOUNT
	
	DELETE from HEAD_COUNT
	INSERT INTO HEAD_COUNT
	select EMPRESA,
           ZONA COLLATE SQL_Latin1_General_CP1_CI_AS,
           MARCA COLLATE SQL_Latin1_General_CP1_CI_AS,
           SUCURSAL COLLATE SQL_Latin1_General_CP1_CI_AS,
           NIVEL_JERARQUICO COLLATE SQL_Latin1_General_CP1_CI_AS,
           DEPARTAMENTO COLLATE SQL_Latin1_General_CP1_CI_AS,
           LINEA_NEGOCIO COLLATE SQL_Latin1_General_CP1_CI_AS,
           FECHA_CIERRE,
           GENERO COLLATE SQL_Latin1_General_CP1_CI_AS,
           CANTIDAD_PERSONAS

	from [SERVER-DB].[BIBUXIS].[dbo].[HEAD_COUNT]
	where EMPRESA in (1,2,3,4,10)

	set @RowsIn = @@ROWCOUNT

	insert @Bitacora_Diaria values(@fec_actual,'HEAD_COUNT',@RowsIn,(select COUNT(*) from HEAD_COUNT))
	
	-------------------------------------------------------------------------------------------------
    -- Tabla: INFORMACION_FINANCIERA
	-- Tipo Actualización: CON FECHA DE CIERRE
	-- Periodicidad: MENSUAL
	-------------------------------------------------------------------------------------------------
	INSERT INTO INFORMACION_FINANCIERA
	select COD_EMP COLLATE SQL_Latin1_General_CP1_CI_AS,
	       FECHA,
		   VENTA_NETA,
		   UTILIDAD_NETA,
		   LINEA_NEGOCIO COLLATE SQL_Latin1_General_CP1_CI_AS
	from [SERVER-DB].[BIBUXIS].[dbo].[INFORMACION_FINANCIERA]
	EXCEPT
    select COD_EMP,
	       FECHA,
		   VENTA_NETA,
		   UTILIDAD_NETA,
		   LINEA_NEGOCIO
	from INFORMACION_FINANCIERA
	set @RowsIn = @@ROWCOUNT

	insert @Bitacora_Diaria values(@fec_actual,'INFORMACION_FINANCIERA',@RowsIn,(select COUNT(*) from INFORMACION_FINANCIERA))

	-------------------------------------------------------------------------------------------------
    -- Tabla: EMPRESA
	-- Tipo Actualización: TOTAL
	-- Periodicidad: MENSUAL
	-------------------------------------------------------------------------------------------------
	INSERT INTO LINEAS_NEGOCIO
	select COD_LN COLLATE SQL_Latin1_General_CP1_CI_AS,
	       DESCRIPCION COLLATE SQL_Latin1_General_CP1_CI_AS
	from [SERVER-DB].[BIBUXIS].[dbo].[LINEAS_NEGOCIO]
	EXCEPT
	select COD_LN,
	       DESCRIPCION
	from [LINEAS_NEGOCIO]
	set @RowsIn = @@ROWCOUNT

	insert @Bitacora_Diaria values(@fec_actual,'LINEAS_NEGOCIO',@RowsIn,(select COUNT(*) from LINEAS_NEGOCIO))
	-------------------------------------------------------------------------------------------------

	-------------------------------------------------------------------------------------------------
    -- Tabla: LIQUIDACIONES
	-- Tipo Actualización: CON FECHA MENSUAL
	-- Periodicidad: MENSUAL
	-- TRAER TODO
	-------------------------------------------------------------------------------------------------
	DELETE FROM LIQUIDACIONES
	INSERT INTO LIQUIDACIONES
	select COD_EMP,
		   COD_LQ,
		   DESC_LQ COLLATE SQL_Latin1_General_CP1_CI_AS,
		   COD_PR COLLATE SQL_Latin1_General_CP1_CI_AS,
		   FECHA_DESDE,
		   FECHA_HASTA,
		   FECHA_CIERRE,
		   FECHA_ACUM,
		   ESTADO COLLATE SQL_Latin1_General_CP1_CI_AS
	from [SERVER-DB].[BIBUXIS].[dbo].[LIQUIDACIONES]
	--EXCEPT
	--SELECT COD_EMP,
	--	   COD_LQ,
	--	   DESC_LQ,
	--	   COD_PR,
	--	   FECHA_DESDE,
	--	   FECHA_HASTA,
	--	   FECHA_CIERRE,
	--	   FECHA_ACUM,
	--	   ESTADO
 --   FROM LIQUIDACIONES lq
	set @RowsIn = @@ROWCOUNT

	insert @Bitacora_Diaria values(@fec_actual,'LIQUIDACIONES',@RowsIn,(select COUNT(*) from LIQUIDACIONES))

	-------------------------------------------------------------------------------------------------
    -- Tabla: MAEFUNC_BI
	-- Tipo Actualización: TOTAL
	-- Periodicidad: MENSUAL
	-------------------------------------------------------------------------------------------------
	
	DELETE FROM MAEFUNC_BI
	
	INSERT INTO MAEFUNC_BI
	--select COD_MF,NOM_MF COLLATE SQL_Latin1_General_CP1_CI_AS,TIPO_DOC COLLATE SQL_Latin1_General_CP1_CI_AS,NUMERO_DOC COLLATE SQL_Latin1_General_CP1_CI_AS,PAIS_MF COLLATE SQL_Latin1_General_CP1_CI_AS,PROVINCIA COLLATE SQL_Latin1_General_CP1_CI_AS,CIUDAD_NAC COLLATE SQL_Latin1_General_CP1_CI_AS,FECHA_NACIMIENTO,EDAD,
 --          GENERO COLLATE SQL_Latin1_General_CP1_CI_AS,CARNET_CONADIS COLLATE SQL_Latin1_General_CP1_CI_AS,LICENCIA_TIPO COLLATE SQL_Latin1_General_CP1_CI_AS,PLACA_VEH COLLATE SQL_Latin1_General_CP1_CI_AS,TIPO_SANGRE COLLATE SQL_Latin1_General_CP1_CI_AS,BANCO COLLATE SQL_Latin1_General_CP1_CI_AS,TIPO_CUENTA COLLATE SQL_Latin1_General_CP1_CI_AS,NUMERO_CUENTA COLLATE SQL_Latin1_General_CP1_CI_AS,
 --          PAIS_RES COLLATE SQL_Latin1_General_CP1_CI_AS,PROVINCIA_RES COLLATE SQL_Latin1_General_CP1_CI_AS,CIUDAD_RES COLLATE SQL_Latin1_General_CP1_CI_AS,PARROQUIA_RES COLLATE SQL_Latin1_General_CP1_CI_AS,TELEFONO_MF COLLATE SQL_Latin1_General_CP1_CI_AS,MOVIL_MF COLLATE SQL_Latin1_General_CP1_CI_AS,U_FECH_ANTI,FEC_ING_MF,
 --          U_EMAIL_EMPRE COLLATE SQL_Latin1_General_CP1_CI_AS,U_EMP_ORI_MIGR COLLATE SQL_Latin1_General_CP1_CI_AS,FECHA_EFECTIVA 
	--from [SERVER-DB].[BIBUXIS].[dbo].[MAEFUNC_BI] 
	--EXCEPT
	--select COD_MF,NOM_MF,TIPO_DOC,NUMERO_DOC,PAIS_MF,PROVINCIA,CIUDAD_NAC,FECHA_NACIMIENTO,EDAD,
	--	   GENERO,CARNET_CONADIS,LICENCIA_TIPO,PLACA_VEH,TIPO_SANGRE,BANCO,TIPO_CUENTA,NUMERO_CUENTA,
	--	   PAIS_RES,PROVINCIA_RES,CIUDAD_RES,PARROQUIA_RES,TELEFONO_MF,MOVIL_MF,U_FECH_ANTI,FEC_ING_MF,
 --          U_EMAIL_EMPRE,U_EMP_ORI_MIGR,FECHA_EFECTIVA
	--from MAEFUNC_BI
	SELECT COD_MF,NOM_MF,TIPO_DOC,NUMERO_DOC,PAIS_MF,PROVINCIA,CIUDAD_NAC,FECHA_NACIMIENTO,EDAD,
		   GENERO,CARNET_CONADIS,LICENCIA_TIPO,PLACA_VEH,TIPO_SANGRE,BANCO,TIPO_CUENTA,NUMERO_CUENTA,
		   PAIS_RES,PROVINCIA_RES,CIUDAD_RES,PARROQUIA_RES,TELEFONO_MF,MOVIL_MF,U_FECH_ANTI,FEC_ING_MF,
           U_EMAIL_EMPRE,U_EMP_ORI_MIGR,FECHA_EFECTIVA
	FROM [SERVER-DB].[BIBUXIS].[dbo].[MAEFUNC_BI]
	set @RowsIn = @@ROWCOUNT

	insert @Bitacora_Diaria values(@fec_actual,'MAEFUNC_BI',@RowsIn,(select COUNT(*) from MAEFUNC_BI))

	-------------------------------------------------------------------------------------------------
    -- Tabla: MOT_DESVINCULACION
	-- Tipo Actualización: TOTAL
	-- Periodicidad: MENSUAL
	-------------------------------------------------------------------------------------------------
	INSERT INTO MOT_DESVINCULACION
	select COD_MD COLLATE SQL_Latin1_General_CP1_CI_AS,
	       DESCRIPCION COLLATE SQL_Latin1_General_CP1_CI_AS
	from [SERVER-DB].[BIBUXIS].[dbo].[MOT_DESVINCULACION]
	EXCEPT
	select COD_MD,
	       DESCRIPCION
	from MOT_DESVINCULACION
	set @RowsIn = @@ROWCOUNT

	insert @Bitacora_Diaria values(@fec_actual,'MOT_DESVINCULACION',@RowsIn,(select COUNT(*) from MOT_DESVINCULACION))
	-------------------------------------------------------------------------------------------------
    -- Tabla: MOT_DESVINCULACION
	-- Tipo Actualización: TOTAL
	-- Periodicidad: MENSUAL
	-------------------------------------------------------------------------------------------------
	DELETE FROM RPT_MAEFUNC_BI
	INSERT INTO RPT_MAEFUNC_BI
	select FECHA_CIERRE,
           FECHA_EFECTIVA,
           COD_MF,
           COD_EMP,
           EST_CIV_MF COLLATE SQL_Latin1_General_CP1_CI_AS,
           U_CAP_ESP COLLATE SQL_Latin1_General_CP1_CI_AS,
           U_CAR_CAP_ESP COLLATE SQL_Latin1_General_CP1_CI_AS,
           U_CAP_POR,
           U_PROF COLLATE SQL_Latin1_General_CP1_CI_AS,
           U_NIV_INST COLLATE SQL_Latin1_General_CP1_CI_AS,
           SJH_MF,
           FPAGO_MF COLLATE SQL_Latin1_General_CP1_CI_AS,
           U_PAGO_QUIN COLLATE SQL_Latin1_General_CP1_CI_AS,
           U_RETE_JUDI COLLATE SQL_Latin1_General_CP1_CI_AS,
           SUCURSAL COLLATE SQL_Latin1_General_CP1_CI_AS,
           U_DEPARTAMENTO COLLATE SQL_Latin1_General_CP1_CI_AS,
           TIPO_CONTRATO COLLATE SQL_Latin1_General_CP1_CI_AS,
           FEC_DESV_MF,
           FEC_EGR_MF,
           MOTIVO_DESV_MF COLLATE SQL_Latin1_General_CP1_CI_AS,
           CENCOS_MF COLLATE SQL_Latin1_General_CP1_CI_AS,
           U_DIST_GASTO COLLATE SQL_Latin1_General_CP1_CI_AS,
           U_LINEA_DIST COLLATE SQL_Latin1_General_CP1_CI_AS,
           U_LINEA_DIST_V COLLATE SQL_Latin1_General_CP1_CI_AS,
           U_LINEA_NEGOCIO COLLATE SQL_Latin1_General_CP1_CI_AS,
           ZONA COLLATE SQL_Latin1_General_CP1_CI_AS,
           U_FACTS COLLATE SQL_Latin1_General_CP1_CI_AS,
           CEDIDE_MF COLLATE SQL_Latin1_General_CP1_CI_AS,
           EDAD,
           U_ACU_FON_RES COLLATE SQL_Latin1_General_CP1_CI_AS,
           U_ACU_3RO_ROL COLLATE SQL_Latin1_General_CP1_CI_AS,
           U_ACU_3RO_FEC,
           U_ACU_4TO_ROL COLLATE SQL_Latin1_General_CP1_CI_AS,
           U_ACU_4TO_FEC,
           U_MARCA COLLATE SQL_Latin1_General_CP1_CI_AS,
           COD_PUE,
           PUE_TPO COLLATE SQL_Latin1_General_CP1_CI_AS,
           CODIGO_SECTORIAL COLLATE SQL_Latin1_General_CP1_CI_AS,
           HOMOLOGADO,
           CCO_PUE COLLATE SQL_Latin1_General_CP1_CI_AS
	from [SERVER-DB].[BIBUXIS].[dbo].[RPT_MAEFUNC_BI]
	--EXCEPT
	--select *
	--from RPT_MAEFUNC_BI
	set @RowsIn = @@ROWCOUNT
	insert @Bitacora_Diaria values(@fec_actual,'RPT_MAEFUNC_BI',@RowsIn,(select COUNT(*) from RPT_MAEFUNC_BI))
	-------------------------------------------------------------------------------------------------
    -- Tabla: RPT_MOVHD_BI
	-- Tipo Actualización: MENSUAL
	-- Periodicidad: MENSUAL
	-------------------------------------------------------------------------------------------------
	INSERT INTO RPT_MOVHD_BI
	select 	COD_EMP,
			COD_LQ,
			COD_MV,
			DIFE_MOV,
			COD_MF,
			CENCOS_HD COLLATE SQL_Latin1_General_CP1_CI_AS,
			HORAS_HD,
			IMPTOT_HD
	from [SERVER-DB].[BIBUXIS].[dbo].[RPT_MOVHD_BI]
	EXCEPT
	select *
	from RPT_MOVHD_BI
	set @RowsIn = @@ROWCOUNT

	insert @Bitacora_Diaria values(@fec_actual,'RPT_MOVHD_BI',@RowsIn,(select COUNT(*) from RPT_MOVHD_BI))
	-------------------------------------------------------------------------------------------------
    -- Tabla: SUCURSALES
	-- Tipo Actualización: MENSUAL
	-- Periodicidad: MENSUAL
	-------------------------------------------------------------------------------------------------
	DELETE FROM SUCURSALES
	INSERT INTO SUCURSALES
	select COD_SUC COLLATE SQL_Latin1_General_CP1_CI_AS,
	       DESCRIPCION COLLATE SQL_Latin1_General_CP1_CI_AS,
		   ZONA COLLATE SQL_Latin1_General_CP1_CI_AS,
		   COD_EMP
	FROM [SERVER-DB].[BIBUXIS].[dbo].[SUCURSALES]
	set @RowsIn = @@ROWCOUNT

	insert @Bitacora_Diaria values(@fec_actual,'SUCURSALES',@RowsIn,(select COUNT(*) from SUCURSALES))
	-------------------------------------------------------------------------------------------------
    -- Tabla: VACACIONES
	-- Tipo Actualización: MENSUAL
	-- Periodicidad: MENSUAL
	-------------------------------------------------------------------------------------------------
	INSERT INTO VACACIONES
	select EMPRESA,
           ZONA COLLATE SQL_Latin1_General_CP1_CI_AS,
           MARCA COLLATE SQL_Latin1_General_CP1_CI_AS,
           SUCURSAL COLLATE SQL_Latin1_General_CP1_CI_AS,
           NIVEL_JERARQUICO COLLATE SQL_Latin1_General_CP1_CI_AS,
           DEPARTAMENTO COLLATE SQL_Latin1_General_CP1_CI_AS,
           LINEA_NEGOCIO COLLATE SQL_Latin1_General_CP1_CI_AS,
           FECHA_CIERRE,
           NUM_DIAS_VACACIONES COLLATE SQL_Latin1_General_CP1_CI_AS,
           NUM_PERSONAS
	FROM [SERVER-DB].[BIBUXIS].[dbo].[VACACIONES]
	EXCEPT
	select *
	from VACACIONES
	set @RowsIn = @@ROWCOUNT

	insert @Bitacora_Diaria values(@fec_actual,'VACACIONES',@RowsIn,(select COUNT(*) from VACACIONES))

	-------------------------------------------------------------------------------------------------
    -- Tabla: VIN_DESC
	-- Tipo Actualización: MENSUAL
	-- Periodicidad: MENSUAL
	-------------------------------------------------------------------------------------------------
	INSERT INTO VINC_DESC
	select EMPRESA,
           ZONA COLLATE SQL_Latin1_General_CP1_CI_AS,
           MARCA COLLATE SQL_Latin1_General_CP1_CI_AS,
           SUCURSAL COLLATE SQL_Latin1_General_CP1_CI_AS,
           NIVEL_JERARQUICO COLLATE SQL_Latin1_General_CP1_CI_AS,
           DEPARTAMENTO COLLATE SQL_Latin1_General_CP1_CI_AS,
           LINEA_NEGOCIO COLLATE SQL_Latin1_General_CP1_CI_AS,
           FECHA_CIERRE,
           MOTIVO_DESV_ING COLLATE SQL_Latin1_General_CP1_CI_AS,
           CANTIDAD_PERSONAS
	FROM [SERVER-DB].[BIBUXIS].[dbo].[VINC_DESC]
	EXCEPT
	select *
	from VINC_DESC
	set @RowsIn = @@ROWCOUNT

	insert @Bitacora_Diaria values(@fec_actual,'VINC_DESC',@RowsIn,(select COUNT(*) from VINC_DESC))



	-------------------------------------------------------------------------------------------------
    -- Tabla: PUESTOS
	-------------------------------------------------------------------------------------------------
	DELETE from PUESTOS
	INSERT INTO PUESTOS
	select *
	from [SERVER-DB].[BIBUXIS].[dbo].[PUESTOS]

	-------------------------------------------------------------------------------------------------
    -- Tabla: UNIDADES_ORGANIZATIVAS
	-------------------------------------------------------------------------------------------------
	DELETE from UNIDADES_ORGANIZATIVAS
	INSERT INTO UNIDADES_ORGANIZATIVAS
	select *
	from [SERVER-DB].[BIBUXIS].[dbo].[UNIDADES_ORGANIZATIVAS]

	
	-------------------------------------------------------------------------------------------------
	-- Resultado
	-------------------------------------------------------------------------------------------------
	INSERT HIST_ACTUALIZACION_TABLAS_BUXIS
	select * 
	from @Bitacora_Diaria

	select *
	from HIST_ACTUALIZACION_TABLAS_BUXIS
END
