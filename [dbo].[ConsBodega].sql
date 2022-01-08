SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER proc [dbo].[ConsBodega]
as 
	select    bodega = b.id, descripcion = b.descripcion,
	  agencia = convert(varchar(100),case	when b.descripcion like '%QUITO%GAC%' then 'GAC QUITO'
							when b.descripcion like '%QUITO%VW%' then 'VW QUITO'
							when b.descripcion like '%LOJA%GAC%' then 'GAC LOJA'
							when b.descripcion like '%LOJA%VW%' then 'VW LOJA'
							when b.descripcion like '%CUENCA%GAC%' then 'GAC CUENCA'
							when b.descripcion like '%CUENCA%VW%' then 'VW CUENCA'
							when b.descripcion like '%GUAYAQUIL%GAC%' then 'GAC GUAYAQUIL'
							when b.descripcion like '%GUAYAQUIL%VW%' then 'VW GUAYAQUIL'
					else 'LOGISTICA' end)
	from      cot_bodega b
	where id_emp = 601

GO
