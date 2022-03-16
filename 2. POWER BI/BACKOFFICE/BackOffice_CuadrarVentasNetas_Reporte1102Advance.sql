
-- Cuadrar Ventas Netas, compara con Reporte 1102 Advance
--381

declare @anio int = 2021
declare @mes int = 5
declare @cuenta_nivel6 varchar(6) = '411101'--'421101'--'411101'


select x.Codigo,
       x.Cuenta,
	   x.Debitos,
	   x.Creditos,
	   x.Saldo
into #temp
from
(
	select Codigo = n.codigo_nivel6,
		   Cuenta = n.descripcion_nivel6 ,
		   Debitos = sum(Suma_debito),
		   Creditos = sum(Suma_credito),
		   Saldo = sum(Suma_debito) + sum(Suma_credito)
	   
	from FactDetalleCuentasNivel8_CCO f
	join DimCuentasNivel n on n.codigo_nivel8 = f.codigo_nivel8
	where f.codigo_nivel6 = @cuenta_nivel6
	and f.Anio = @anio
	and f.Mes = @mes
	group by n.codigo_nivel6,n.descripcion_nivel6
	union all
	select Codigo = f.cuenta,
		   Cuenta = n.descripcion_nivel8,
		   Debitos = sum(Suma_debito),
		   Creditos = sum(Suma_credito),
		   Saldo = sum(Suma_debito) + sum(Suma_credito)
	from FactDetalleCuentasNivel8_CCO f
	join DimCuentasNivel n on n.codigo_nivel8 = f.codigo_nivel8
	where f.codigo_nivel6 = @cuenta_nivel6
	and f.Anio = @anio
	and f.Mes = @mes
	group by f.cuenta, n.descripcion_nivel8
	--order by f.cuenta
)x


select *
from #temp t
order by t.Codigo

select [VENTA NETA] = sum(t.Saldo)
from #temp t
where len(t.Codigo) = 8
--
drop table #temp