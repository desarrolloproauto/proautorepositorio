USE [dms_smd3]
GO
/****** Object:  StoredProcedure [dbo].[Get_BI_R_DimMarca]    Script Date: 21/3/2022 16:10:36 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--- =============================================
-- Author:		<Javier Chogllo B.>
-- Create date: <2021-07-02>
-- Description:	<Description,,>
-- Historial:	(2022-03-21) <Se elimina las marca 'Todas Las Marcas' (JCB)>
-- =============================================
ALTER PROCEDURE [dbo].[Get_BI_R_DimMarca]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	declare @emp int = 605

    select  DISTINCT Id = left(c.codigo,1),
			Marca = case	
						when left(c.codigo,1) = 1 then 'Chevrolet'
						when left(c.codigo,1) = 2 then 'Gac'
						when left(c.codigo,1) = 3 then 'Volkswagen'
						when left(c.codigo,1) = 9 then 'Multimarca'
						--when left(c.codigo,1) = 0 then 'Todas las marcas'
					END
	from con_cco c with(nolock)
	where id_emp = @emp
	and left(c.codigo,1) <> 0
END
