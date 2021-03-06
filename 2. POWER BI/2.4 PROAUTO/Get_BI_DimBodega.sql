USE [dms_smd3]
GO
/****** Object:  StoredProcedure [dbo].[Get_BI_DimBodega]    Script Date: 22/3/2022 8:46:12 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================================================
-- Author:		<Javier Chogllo / INNOVA>
-- Create date: <2021-03-23>
-- Description:	<Procedimiento para obtener informacion de las Agencias>
-- Historial:
-- <2022-02-14>  Se condideran las bodegas de Transito ya que existen movimientos en estas bodegas (JCB) 
-- <2022-03-21>  Se asignan valores de ciudad, provincia y zona a las bodegas de Transito (JCB) 
-- <2022-03-21>  Se asignan los valores Ciudad=TRANSITO y Zona=NACIONAL para las bodegas de Transito (JCB) 
-- =============================================================================================================
-- exec [dbo].[Get_BI_DimBodega]
--
alter PROCEDURE [dbo].[Get_BI_DimBodega]
AS

DECLARE @emp INT = 601
DECLARE @emp2 INT = 605
BEGIN

	
	DECLARE @Bodegas as table
	(
		[Id] [int],
		[Descripcion] [varchar](100),
		[Ecu_Establecimiento] [char](20),
		[Agencia] [varchar](200),
		[Ciudad] [varchar](200) NULL,
	    id_provincia char(5),
		[Provincia] [varchar](200),
		[Zona] nvarchar(50),
		id_emp [int]
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
				--WHEN b.id IN (1129,1139,1160,1174,1149) THEN 'CUENCA GAC'
				--WHEN b.id IN (1130,1140,1161,1175,1150) THEN 'CUENCA VW'
				WHEN b.id IN (1129,1139,1160,1174,1149) THEN 'CUE GIL RAMIREZ'
				WHEN b.id IN (1130,1140,1161,1175,1150) THEN 'CUE GIL RAMIREZ'
				--WHEN b.id IN (1126,1136,1157,1173,1146) THEN 'QUITO VW'
				WHEN b.id IN (1126,1136,1157,1173,1146) THEN 'QTO RUSIA'
				--WHEN b.id IN (1125,1165,1135,1156,1166,1145) THEN 'QUITO GAC'
				WHEN b.id IN (1125,1165,1135,1156,1166,1145) THEN 'QTO VIOLETAS'
				WHEN b.id IN (1127,1137,1158,1167,1147) THEN 'GUAYAQUIL GAC'
				WHEN b.id IN (1128,1138,1159,1168,1148) THEN 'GUAYAQUIL VW'
				--WHEN b.id IN (1132,1142,1163,1170,1152) THEN 'LOJA VW'
				--WHEN b.id IN (1131,1141,1162,1169,1151) THEN 'LOJA GAC'
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
				WHEN b.id IN (1285) THEN 'QTO USADOS'
				WHEN b.id IN (1300,1303,1304) THEN 'ESME KILOMETRO 7'
				WHEN b.id IN (1306,1307,1308) THEN 'QTO. AV MALDONADO SUR'
				WHEN b.id IN (1301,1302,1305) THEN 'LAGO AGRIO'	
				WHEN b.id IN (1281,1282,1283) THEN 'TRANSITO' --Se coloca la agencia 'TRANSITO' a las bodegas de Transito
				ELSE b.descripcion
		   END,
		   ciudad = CASE	
						WHEN  b.id IN (1281,1282,1283) then 'TRANSITO' --Se coloca la ciudad TRANSITO a las bodegas de Transito
						ELSE p.descripcion
					END,
		   id_provincia = case
							when prov.codigo = '21101' then '11'
							when b.id IN (1281,1282,1283) then '00' --Se coloca la provincia Transito a las bodegas de Transito
							else RIGHT('0' + Ltrim(Rtrim(prov.codigo)),2)
						end,
		   --z.descripcion,
		   prov.descripcion,
		   Zona = CASE WHEN p.descripcion IN ('QUITO','ESMERALDAS','LAGO AGRIO','SUCUMBÍOS','CAYAMBE','PUERTO QUITO') then 'NORTE'
					   WHEN p.descripcion IN ('GUAYAQUIL','MACHALA','PIÑAS','DAULE','DURÁN') then 'COSTA'
					   WHEN p.descripcion IN ('CUENCA','AZOGUES','LOJA') then 'SIERRA'
					   WHEN b.id IN (1281,1282,1283) THEN 'NACIONAL'  --Se coloca la zona NACIONAL a las bodegas de Transito
				  END,
		   b.id_emp
	FROM dbo.cot_bodega b
	left join cot_cliente_pais p on p.id = b.id_cot_cliente_pais
	left join cot_cliente_pais prov on prov.id = p.id_cot_cliente_pais
	--JOIN [dbo].[cot_zona_sub] z on b.id_cot_zona_sub = z.id
	left JOIN cot_zona_sub s on s.id = b.id_cot_zona_sub
    left JOIN cot_zona z on z.id=s.id_cot_zona
	WHERE b.id_emp IN (@emp,@emp2)

	
	---Resultado
	SELECT b.id,
	       b.Descripcion,
		   b.ecu_establecimiento,
		   b.Agencia,
		   b.Ciudad,	
		   id_zona = CASE WHEN b.Zona = 'NORTE' THEN 1
                          WHEN b.Zona = 'COSTA' THEN 2
                          WHEN b.Zona = 'SIERRA' THEN 3
						  WHEN b.Zona = 'NACIONAL' THEN 0
				     END,
		   IdEmpresa = CASE when b.id_emp = 605 then 1 --Proauto
							 when b.id_emp = 601 then 4 --Autofactor
						end,
		   b.id_provincia,
		   id_agencia = case
							WHEN b.Agencia ='MCH AV 25 DE JUNIO' then 1    
							WHEN b.Agencia ='MCH PROVIDENCIA' then 2    
							WHEN b.Agencia ='MCH PIÑAS' then 3    
							WHEN b.Agencia ='GYE AV AMERICAS' then 1    
							WHEN b.Agencia ='GYE JUAN TANCA' then 2    
							WHEN b.Agencia ='GYE CALLE TERCERA' then 4    
							WHEN b.Agencia ='GYE CALLE SEXTA' then 5    
							WHEN b.Agencia ='GYE DAULE' then 3    
							WHEN b.Agencia ='CUE ESPAÑA' then 1    
							WHEN b.Agencia ='CUE QUINTA CHICA' then 2    
							WHEN b.Agencia ='CUE GIL RAMIREZ' then 4    
							WHEN b.Agencia ='AZO IGNACIO NEIRA' then 1    
							WHEN b.Agencia ='LOJ ISIDRO AYORA' then 1    
							WHEN b.Agencia ='LOJ SALVADOR BUST' then 2    
							WHEN b.Agencia ='QTO GRANADOS' then 1    
							WHEN b.Agencia ='QTO CARAPUNGO' then 2    
							WHEN b.Agencia ='QTO VIOLETAS' then 6    
							WHEN b.Agencia ='QTO RUSIA' then 7    
							WHEN b.Agencia ='QTO PORTAL' then 8    
							WHEN b.Agencia ='QTO USADOS' then 9    
							WHEN b.Agencia ='QTO CAYAMBE' then 4    
							WHEN b.Agencia ='QTO CONDADO' then 3    
							WHEN b.Agencia ='QTO PUERTO' then 5 
							WHEN b.Agencia ='TRANSITO' then 0
						end
	FROM @Bodegas b
	WHERE b.Descripcion NOT like '%PROCESO%'
	--AND b.Descripcion NOT like '%INSUMOS%'
	--AND b.Descripcion NOT like '%TRANSITO%'
	--AND b.Descripcion NOT like '%CONSIGNACION%'
	and b.Descripcion NOT like '%NO%USAR%'
	AND b.Descripcion NOT like '%CAJA%ESPECIAL%'
	ORDER BY Id
	
	
END
