USE [dms_smd3]
GO
/****** Object:  StoredProcedure [dbo].[Get_BI_R_DimBodega]    Script Date: 7/2/2022 19:24:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ==================================================================================================
-- Author:		<Javier Chogllo / INNOVA>
-- Create date: <2021-03-23>
-- Description:	<Procedimiento para obtener informacion de las Agencias>
-- Historial:
-- <2022-01-04>  So corrige para obtener de manera correcta la Ciudad (JCB)   
-- <2022-01-04>  Se consideran las bodegas de Consignacion e Insumos para la tabla FactInventarioRepuestos (JCB) 
-- <2022-02-08>  Se condideran las bodegas de Transito ya que existen movimientos en estas bodegas (JCB) 
-- ==================================================================================================
-- exec [dbo].[Get_BI_R_DimBodega]

ALTER PROCEDURE [dbo].[Get_BI_R_DimBodega]
AS

DECLARE @emp INT = 601
DECLARE @emp2 INT = 605
BEGIN

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 
	SET NOCOUNT ON; 

	declare @bodegas as table
	(
		id int,
		descripcion varchar(100),
		ecu_establecimiento char(3),
		Agencia varchar(50),
		Ciudad varchar(100),
		Zona varchar(200),
		id_emp int
	)
	
	--
	insert @Bodegas
	SELECT DISTINCT b.id,
           Descripcion = b.descripcion,
		   b.ecu_establecimiento,
		   Agencia = 
		   CASE
				WHEN b.id IN (1275,1276,1277,1278,1279) THEN 'GYE CALLE SEXTA'
				WHEN b.id IN (1272,1273,1274) THEN 'GYE CALLE TERCERA'
				WHEN b.id IN (1267,1268,1269,1270,1271) THEN 'GYE DAULE'
				WHEN b.id IN (1262,1263,1264,1265,1266) THEN 'GYE JUAN TANCA'
				WHEN b.id IN (1257,1258,1259,1260,1261) THEN 'GYE AV AMERICAS'
				WHEN b.id IN (1252,1253,1254,1255,1256) THEN 'MCH PROVIDENCIA'
				WHEN b.id IN (1247,1248,1249,1250,1251) THEN 'MCH AV 25 DE JUNIO'
				WHEN b.id IN (1241,1242,1243,1244,1245) THEN 'QTO RUSIA'
				WHEN b.id IN (1211,1212,1213,1214,1294,1309) THEN 'LOJ SALVADOR BUST'
				WHEN b.id IN (1206,1207,1208,1209,1210) THEN 'LOJ ISIDRO AYORA'
				WHEN b.id IN (1201,1202,1203,1204,1205) THEN 'AZO IGNACIO NEIRA'
				WHEN b.id IN (1196,1197,1198,1199,1200) THEN 'CUE GIL RAMIREZ'
				WHEN b.id IN (1187,1188,1189,1190,1180,1291) THEN 'CUE QUINTA CHICA'
				WHEN b.id IN (1181,1182,1183,1184,1185,1290,1293,1296) THEN 'CUE ESPAÑA'
				WHEN b.id IN (1181,1182,1183,1184,1185) THEN 'QTO PORTAL'
				WHEN b.id IN (1129,1139,1160,1174,1149) THEN 'CUE GIL RAMIREZ'
				WHEN b.id IN (1130,1140,1161,1175,1150) THEN 'CUE GIL RAMIREZ'
				WHEN b.id IN (1126,1136,1157,1173,1146) THEN 'QTO RUSIA'
				WHEN b.id IN (1125,1165,1135,1156,1166,1145) THEN 'QTO VIOLETAS'
				WHEN b.id IN (1127,1137,1158,1167,1147) THEN 'GUAYAQUIL GAC'
				WHEN b.id IN (1128,1138,1159,1168,1148) THEN 'GUAYAQUIL VW'
				WHEN b.id IN (1132,1142,1163,1170,1152) THEN 'LOJ ISIDRO AYORA'
				WHEN b.id IN (1131,1141,1162,1169,1151) THEN 'LOJ ISIDRO AYORA'
				WHEN b.id IN (1215,1216,1289,1217,1218,1219,1297) THEN 'QTO GRANADOS'
				WHEN b.id IN (1220,1221,1222,1295,1223,1224) THEN 'QTO CARAPUNGO'
				WHEN b.id IN (1225,1226,1227,1228,1229) THEN 'QTO CONDADO'
				WHEN b.id IN (1230,1231,1232,1233,1234) THEN 'QTO CAYAMBE'
				WHEN b.id IN (1236,1237,1238,1239,1240) THEN 'QTO VIOLETAS'
				WHEN b.id IN (1286,1287,1288) THEN 'QTO GUAJALO'
				WHEN b.id IN (1246) THEN 'QTO PORTAL'
				WHEN b.id IN (1235) THEN 'QTO PUERTO'
				WHEN b.id IN (1280) THEN 'MCH PIÑAS'
				WHEN b.id IN (1292) THEN 'LOJ ISIDRO AYORA'
				WHEN b.id IN (1285) THEN 'QUITO USADOS'
				WHEN b.id IN (1300,1303,1304) THEN 'ESME KILOMETRO 7'
				WHEN b.id IN (1306,1307,1308) THEN 'QTO. AV MALDONADO SUR'
				WHEN b.id IN (1301,1302,1305) THEN 'LAGO AGRIO'
				ELSE b.descripcion
		   END,
		   Ciudad = p.descripcion,
		   Zona = CASE WHEN p.descripcion IN ('QUITO','ESMERALDAS','LAGO AGRIO','SUCUMBÍOS','CAYAMBE','PUERTO QUITO') then 'NORTE'
																      WHEN p.descripcion IN ('GUAYAQUIL','MACHALA','PIÑAS','DAULE','DURÁN') then 'COSTA'
						                                              WHEN p.descripcion IN ('CUENCA','AZOGUES','LOJA') then 'SIERRA'
				  END,
		   b.id_emp
	FROM dbo.cot_bodega b
	left JOIN dbo.cot_cliente_pais p ON p.id = b.id_cot_cliente_pais
	LEFT JOIN dbo.cot_zona_sub s ON s.id = b.id_cot_zona_sub
	--left join cot_zona z on s.id_cot_zona = z.id
	WHERE b.id_emp IN (@emp,@emp2)

	
	---Resultado
	SELECT b.id,
	       b.Descripcion,
		   ecu_establecimiento = isnull(b.ecu_establecimiento,'Sin asignar'),
		   b.Agencia,
		   Ciudad = b.Ciudad,	
		   id_zona = CASE WHEN b.Zona IN ('NORTE') THEN 1
                          WHEN b.Zona = 'COSTA' THEN 2
                          WHEN b.Zona = 'SIERRA' THEN 3
				     END,
		   IdEmpresa = CASE 
							WHEN b.Zona IN ('NORTE','SIERRA') then case	
																	when b.id_emp = 605 then 1 --Proauto
																	when b.id_emp = 601 then 4 --Autofactor
																end
							WHEN b.Zona IN ('COSTA') then case	
																	when b.id_emp = 605 then 3 --Proauto
																	when b.id_emp = 601 then 4 --Autofactor
																end --Emaulme
						end
	FROM @Bodegas b
	--WHERE ISNULL(t.Ciudad,'0') <> '0'
	WHERE b.Descripcion NOT like '%PROCESO%'
	--AND b.Descripcion NOT like '%INSUMOS%'
	--AND b.Descripcion NOT like '%TRANSITO%'
	--AND b.Descripcion NOT like '%CONSIGNACION%'
	AND b.Descripcion NOT like '%VEHICULOS%'
	--AND b.Descripcion NOT like '%REPUESTOS%'
	AND b.Descripcion NOT like '%NO%USAR%'
	AND b.Descripcion NOT like '%ADM%'
	AND b.Descripcion NOT like '%EXPRESS%'
	AND b.Descripcion NOT like '%USADO%'
	AND b.Descripcion NOT like '%TALLER%'
	AND b.Descripcion NOT like '%DCTOS%FISI%'
	AND b.Descripcion NOT like '%CAJA%ESPECIAL%'
	ORDER BY IdEmpresa
	
END


