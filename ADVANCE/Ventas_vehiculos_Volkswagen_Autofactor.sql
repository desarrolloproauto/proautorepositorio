-- Actual de Ventas de VW
use DWH_Comercial
go

select veh.Id_Factura,
       veh.FechaComprobante,
	   veh.NitCliente,
       cli.razon_social,
       cli.direccion,
       cli.telefono,
       cli.celular,
       [AÑO] = veh.id_veh_ano,
       VIN = veh.CodigoItem,
       MODELO = veh.Modelo,
       veh.Marca,
       VENDEDOR = a.Nombre,
	   EMPRESA = E.RazonSocial
from FactVentaVehiculos veh
join DimEmpresas e on e.IdEmpresa = veh.IdEmpresa
LEFT join DWH_Repuestos..DimCliente cli on veh.NitCliente = cli.nit_cliente 
LEFT join DimAsesor a on veh.Id_Asesor = a.Id
where veh.Marca = 'Volkswagen'
ORDER BY veh.FechaComprobante ASC

-- informacion ventas autofactor
select veh.Id_Factura,
       veh.FechaComprobante,
	   veh.NitCliente,
       cli.razon_social,
       cli.direccion,
       cli.telefono,
       cli.celular,
       [AÑO] = veh.id_veh_ano,
       VIN = veh.CodigoItem,
       MODELO = veh.Modelo,
       veh.Marca,
       VENDEDOR = a.Nombre,
       EMPRESA = E.RazonSocial
from FactVentaVehiculos veh
join DimEmpresas e on e.IdEmpresa = veh.IdEmpresa
LEFT join DWH_Repuestos..DimCliente cli on veh.NitCliente = cli.nit_cliente 
LEFT join DimAsesor a on veh.Id_Asesor = a.Id
where e.RazonSocial = 'AUTOFACTOR'