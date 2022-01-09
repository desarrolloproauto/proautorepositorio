SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Javier Chogllo>
-- Create date: <2021-02-07>
-- Description:	<Obtner los Operarios de Talleres de la tabla MAEFUNC_BI, se ingresa como parámetro la fecha de cierre mensual >
-- =============================================
-- EXEC [dbo].[BI_T_GetOperariosTaller_Buxis] '31-03-2021'
ALTER PROCEDURE [dbo].[BI_T_GetOperariosTaller_Buxis]
(
	@fecha_corte date
)

AS
BEGIN

	SET NOCOUNT ON;

	declare @emp int = 3 -- CORPORACION PROAUTO S.A. 
	declare @emp2 int = 2 -- EMAULME C.A.     
	declare @emp3 int = 1 -- MIRASOL. 
	declare @emp4 int = 10 --AUTOFACTOR IMPORT AFI S.A.    
	declare @cod_ld VARCHAR(10) = 'T' -- LINEA DISTRIBUCION (TALLER)
	declare @cod_ln int = 5 --LINEA DE NEGOCIO (TALLER)


	declare @Docs as table
	(
		   COD_MF int,
		   NOM_MF varchar(100),
		   NUMERO_DOC char(50),
		   PROVINCIA char(10),
		   FEC_ING_MF datetime,
		   FECHA_CIERRE datetime,
		   EMPRESA varchar(100),
		   COD_EMP smallint,
		   TIPO_CONTRATO varchar(100),
		   COD_LD varchar(10),
		   LINEA_DISTRIBUCION varchar(50),
		   COD_LN varchar(10),
		   LINEA_NEGOCIO varchar(100),
		   ZONA char(10),
		   MARCA char(50),
		   CEDULA_IDENT char(50),
		   DESC_PUESTO_HOMOLOGADO varchar(100),
		   UNIDAD_ORGANIZATIVA varchar(100),
		   DESC_FCO varchar(200),
		   TIPO_AGRUPAMIENTO varchar(100),
		   COD_SUC varchar(10),
		   DESCRIPCION varchar(100)
	)

	insert @Docs     
	SELECT mf.COD_MF,
		   mf.NOM_MF,
		   mf.NUMERO_DOC,
		   mf.PROVINCIA,
		   mf.FEC_ING_MF,
		   r.FECHA_CIERRE,
		   EMPRESA = emp.NOM_EMP,
		   emp.COD_EMP,
		   TIPO_CONTRATO = c.DESCRIPCION,
		   ld.COD_LD,
		   LINEA_DISTRIBUCION = ld.DESCRIPCION,
		   ln.COD_LN,
		   LINEA_NEGOCIO = ln.DESCRIPCION,
		   r.ZONA,
		   MARCA = r.U_MARCA,
		   CEDULA_IDENT = r.CEDIDE_MF,
		   DESC_PUESTO_HOMOLOGADO = h.DESC_HOM,
		   UNIDAD_ORGANIZATIVA = uorg.DESC_UNI,
		   fc.DESC_FCO,
		   TIPO_AGRUPAMIENTO = ta.DESC_TAG,
		   s.COD_SUC,
		   s.DESCRIPCION
	--into #Docs
	from MAEFUNC_BI mf 
	join RPT_MAEFUNC_BI r on r.COD_MF = mf.COD_MF
	join EMPRESA emp on (emp.COD_EMP = r.COD_EMP)
	JOIN DEPARTAMENTOS dep on dep.COD_DEP = r.U_DEPARTAMENTO
	join TIPO_CONTRATO c on r.TIPO_CONTRATO = c.COD_TC
	JOIN LINEA_DISTRIBUCION ld on ld.COD_LD = r.U_LINEA_DIST
	JOIN LINEAS_NEGOCIO ln on ln.COD_LN = r.U_LINEA_NEGOCIO
	JOIN PUESTOS p on r.COD_PUE = p.COD_PUE
	JOIN HOMOLOGADOS h on h.COD_HOM = r.HOMOLOGADO
	join UNIDADES_ORGANIZATIVAS uorg on uorg.COD_UNI = p.UNIDAD_ORGANIZATIVA
	JOIN FACTS_CONTEO fc on fc.COD_FCO = p.FACTS_CONTEO
	join FACTS_VALORES fv on fv.COD_FVA = p.FACTS_VALOR
	join TIPO_AGRUPAMIENTO ta on ta.COD_TAG = p.TIPO_AGRUPAMIENTO
	join SUCURSALES s on cast(s.COD_SUC as int) = cast(r.SUCURSAL as int)
	WHERE r.FECHA_CIERRE = @fecha_corte
	--AND NUMERO_DOC = '0104321401'--'0104321401'  -- Datos del empleado
	order by FECHA_CIERRE

	
	select codigo_tecnico = d.COD_MF,
	       nombre = d.NOM_MF,
		   nit = d.NUMERO_DOC,
		   fecha_ingreso = d.FEC_ING_MF,
		   fecha_cierre = d.FECHA_CIERRE,
		   id_empresa = CASE
							WHEN d.COD_EMP IN (1,3,10) then 1 --CORPORACION PROAUTO S.A.      Homologado para el BI
							WHEN d.COD_EMP = 2 then 3 --EMAULME C.A.           Homologado para el BI  

						END,
           empresa = d.EMPRESA,
		   id_zona = CASE 
						WHEN d.ZONA = 'ZONA 1' THEN 1 --Homologado para el BI
						WHEN d.ZONA = 'ZONA 2' THEN 2
						WHEN d.ZONA = 'ZONA 3' THEN 3
				  END,
		   d.ZONA,
		   id_marca = case
						when d.MARCA = 'CHEVROLET' THEN 1 --Homologado para el BI
						when d.MARCA = 'VOLKSWAGEN' THEN 3
						when d.MARCA = 'GAC' THEN 2
						ELSE 1  --por defecto Chevrolet
					   END,
			marca = d.MARCA,
			puesto = d.DESC_PUESTO_HOMOLOGADO,
			cod_sucursal = d.COD_SUC,
			d.UNIDAD_ORGANIZATIVA,
			d.DESC_FCO,
			id_bodega_homologado = CASE 
										WHEN d.COD_SUC = 1 then 1217
										WHEN d.COD_SUC = 115 then 1303
										WHEN d.COD_SUC = 114 then 1302
										WHEN d.COD_SUC IN (24,108) then 1183 --MATRIZ ESPAÑA
										WHEN d.COD_SUC = 116 then 1212
										WHEN d.COD_SUC = 7 then 1222
										WHEN d.COD_SUC = 4 then 1232
										WHEN d.COD_SUC = 104 then 1208
										WHEN d.COD_SUC = 99 then 1188
										--WHEN d.COD_SUC = 22 then ?? ASO2 CAMIONES Emaulme
										WHEN d.COD_SUC = 99 then 1188
										WHEN d.COD_SUC = 113 then 1243
										WHEN d.COD_SUC = 3 then 1227
										WHEN d.COD_SUC IN (101,103) then 1198  -- GIL RAMIREZ GAC_VW
										WHEN d.COD_SUC in (27,100) then 1203
										WHEN d.COD_SUC = 2 then 1238
										WHEN d.COD_SUC = 57 then 1159 --GUAYAQUIL VW
										WHEN d.COD_SUC = 59 then 1161 --GUAYAQUIL GAC
									end,
			sucursal = d.DESCRIPCION
	--into FactTecnicosTallerCierreMensualTTHH
	from @Docs d
	where d.COD_EMP in (@emp,@emp2,@emp3,@emp4)
	and d.COD_LD = @cod_ld
	AND d.COD_LN = @cod_ln
	--AND d.DESC_PUESTO_HOMOLOGADO LIKE '%tec%'
	and d.DESC_FCO IN ('MECANICA / Tecnicos Internos','COLISIÓN / Tecnicos Internos',
	                   'MECANICA / Soporte Administrativo Operativo','COLISIÓN / Soporte Administrativo Operativo',
					   'OTRAS MARCAS / Otras Marcas')
	
	

END
GO
