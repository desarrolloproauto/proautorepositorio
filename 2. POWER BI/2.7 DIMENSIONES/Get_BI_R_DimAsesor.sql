USE [dms_smd3]
GO
/****** Object:  StoredProcedure [dbo].[Get_BI_R_DimAsesor_Borrador]    Script Date: 28/4/2022 18:00:05 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ===========================================================================================
-- Author:		<Javier Chogllo / INNOVA>
-- Create date: <2021-02-11>
-- Description:	<Procedimiento para obtener informacion de la dimesion Asesor>
-- Historial:	
				-- (2022/04/28) Se ajusta script para obtener todos los asesores del grupo Asesor 
-- ===========================================================================================

-- exec [dbo].[Get_BI_R_DimAsesor]
ALTER PROCEDURE [dbo].[Get_BI_R_DimAsesor]
AS

DECLARE @emp INT = 605
--DECLARE @emp2 INT = 605
BEGIN
	
	select x.Id,
	       x.NitAsesor,
		   x.Nombre,
		   x.Grupo,
		   x.Estado,
		   --x.anulado,
		   x.id_cot_bodega,
		   x.IdEmpresa
	from
	(
		SELECT Id = u.id,
			   NitAsesor = ISNULL(u.cedula_nit,CAST(u.id AS NVARCHAR(20))),
			   Nombre = UPPER(u.nombre),
			   Grupo = ug.nombre_grupo,
			   Estado = vu.[status],
			   u.id_cot_bodega, --Existen usuarios que no tienen asignado una Agencia por falta de migracion
			   --Estado = 1,
			   IdEmpresa = 1,
			   u.anulado,
			   rank() over(partition by u.cedula_nit order by u.anulado) as fila
		--FROM @Asesor a
		FROM dbo.usuario u 
		JOIN usuario_subgrupo us on us.id = u.id_usuario_subgrupo
		JOIN usuario_cargo uc on uc.id = u.id_usuario_cargo
		JOIN usuario_grupo ug on ug.id = us.id_usuario_grupo
		JOIN dbo.cot_bodega b ON b.id = u.id_cot_bodega
		left JOIN dbo.v_usuario vu ON vu.id = u.id
		--JOIN dbo.usuario_cargo uc ON uc.id = u.id_usuario_cargo
		where b.id_emp = 605
		and us.nombre_subgrupo like '%asesor%'
		--and u.anulado <> 1
	)x
	where x.fila = 1
	--and x.NitAsesor not like '%9999999%'
	order by Nombre
	

END


