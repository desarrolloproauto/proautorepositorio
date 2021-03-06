USE [dms_smd3]
GO
/****** Object:  StoredProcedure [dbo].[BI_BO_DetalleCuentasNivel8_SIN_CCO]    Script Date: 21/4/2022 23:29:55 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =====================================================================================================================================================================
-- Author:		<Javier Chogllo>
-- Create date: <2021-08-07>
-- Description:	<Obtiene el detalle de Cuentas al Nivel 8, donde se especifican sus valores (Debito / Credito) y el Centro de Costos al que afectan Contablemente >
-- Historial:
--              <2022-04-21> Se modifica el tamaño del campo "tercero" a nvarchar(max)     JCB
-- =====================================================================================================================================================================
-- EXEC [dbo].[BI_BO_DetalleCuentasNivel8_SIN_CCO] '2021-08-22'
ALTER PROCEDURE [dbo].[BI_BO_DetalleCuentasNivel8_SIN_CCO]
(
	@fecActual DATE
)
AS
BEGIN
	--------------------------------------------------------------------------------
	set nocount on;
	set transaction isolation level read uncommitted;
	--------------------------------------------------------------------------------
	declare @emp int = 605
	declare @fecIni DATE = DATEADD(DAY,1,EOMONTH(DATEADD(MONTH,-1,@fecActual)))
	declare @fecFin DATE = EOMONTH(@fecActual)
	declare @Anio int = YEAR(@fecActual)
	declare @Mes int = MONTH(@fecActual)

	-- Tabla Resultado
	declare @ConsultaCuenta_Tot_Acumulado as table
		(
			A NVARCHAR(10),
			Codigo nvarchar(20),
			Cuenta nvarchar(200),
			[Saldo Anterior] nvarchar(50),
			Debitos nvarchar(50),
			Creditos nvarchar(50),
			[Nuevo Saldo] nvarchar(50),
			Id int,
			ter int,
			cco int,
			id_cot_cliente int,
			id_con_cco int,
			[!n] int
		)

    ---------------------------------------------------------------------
	-- Cuentas --Tomado del SP [dbo].[GetConMediosCuentasVentana] 
	-- Almacena todas las Cuentas de todos los Niveles
	---------------------------------------------------------------------
	declare @buscar varchar(20)=''
	declare @Cuentas as table 
	(
		codigo varchar(32),
		descripcion nvarchar(80),
		afe char(1),
		ter tinyint,
		doc tinyint,
		cco tinyint,
		bas tinyint,
		porcen_ret money,
		id_con_cta int,
		id_con_cta_tit int,
		[!n] int
	)
	insert @Cuentas
	Select	c.codigo,
			c.descripcion,
			c.afe,
			c.ter,
			c.doc,
			c.cco,
			c.bas,
			c.porcen_ret,
			id_con_cta=c.id,
			id_con_cta_tit=c.id_con_cta_tit,
			[!n]=case when afe is null then 1 else null end
	from	v_con_cta_tit c
	where	c.id_emp=@emp 
	and		(@buscar='-1' or c.codigo like @buscar + '%')
	order by c.codigo

	------------------------------------------------------------------------------------------------------
	-- Tabla CuentasCabecera 
	-- Almacena todas las Cuentas Cabecera o Cuentas Padre, es decir las cuentas que tienen cuentas hijas
	------------------------------------------------------------------------------------------------------
	declare @CuentasCabecera as table
	(
		codigo varchar(32),
		descripcion nvarchar(80),
		id_con_cta int,
		id_con_cta_tit int
	)
	insert @CuentasCabecera
	select c.codigo,
	       c.descripcion,
		   c.id_con_cta,
		   c.id_con_cta_tit
	from @Cuentas c
	where c.[!n] = 1
	--AND descripcion in ('VENTAS NETAS')

	------------------------------------------------------------------------------------------------------
	-- Tabla CuentasNivel8_CCO 
	-- Almacena las Cuentas de Nivel 8 (8 digitos) y que tengan Centro de Costos.
	------------------------------------------------------------------------------------------------------
	declare @CuentasNivel8_CCO as table
	(
		codigo varchar(32),
		descripcion nvarchar(80),
		id_con_cta int,
		id_con_cta_tit int,
		cco tinyint
	)
	insert @CuentasNivel8_CCO
	select c.codigo,
	       c.descripcion,
		   c.id_con_cta,
		   c.id_con_cta_tit,
		   c.cco
	from @Cuentas c
	where c.afe = 'S' 
	and isnull(c.cco,0) = 0 --Cuenta Nivel 8 que tienen Centro de Costos

	------------------------------------------------------------------------------------------------------------------------
	-- Cursor para iterar en la tabla @CuentasNivel8_CCO 
	-- Se ejecuta el SP GetConConsultaCuenta_Tot y se obtienen los valores (Totales) para cada cuenta
	--	Codigo	Cuenta			Anio	Mes		Grupo	Saldo Anterior		Debitos			Creditos		Nuevo Saldo
	--  411101	VENTAS NETAS	2021	7				-$29,019,819.34		$2,273,502.48	$11,702,972.37	-$38,449,289.23
		--------------------------------------------------------------------------------------------------------------------
	declare @id_con_cta_tit int
	DECLARE cur_cuentas_cco CURSOR FORWARD_ONLY STATIC READ_ONLY FOR  
		select distinct d.id_con_cta_tit
		from @CuentasNivel8_CCO d
	OPEN cur_cuentas_cco
	FETCH NEXT FROM cur_cuentas_cco INTO @id_con_cta_tit

	WHILE @@fetch_status = 0  
	begin   
		-- Obtenemos la cuenta Padre de la Cuenta Nivel8
		declare @codigo_cuenta varchar(10)
		select @codigo_cuenta = c.codigo 
		from @CuentasCabecera c
		where c.id_con_cta = @id_con_cta_tit
	   		
		--Variables que utiliza el procedimiento GetConConsultaCuenta_Tot que se ejecuta mas adelante
		declare @cuentaInf varchar(10) = @codigo_cuenta
		declare @cuentaSup varchar(10) = CONCAT(@codigo_cuenta,'zzz')
		--print @cuentaInf print @cuentaSup

		declare @factor INT=1
		declare @cli INT=0
		declare @cen INT=0
		declare @niif SMALLINT=0
		declare @ccoDis INT=0
		declare @ccoGru INT=0
		declare @ccoSub INT=0
		declare @vec VARCHAR(4)='0'
		declare @ceninf VARCHAR(50)=''
		declare @censup VARCHAR(50)=''
		declare @nada INT=0
		declare @consol INT=0 --SGQ-702

		--Tabla que almacena los valores al ejecutar el procedimiento GetConConsultaCuenta_Tot
		declare @ConsultaCuenta_Tot as table
		(
			A NVARCHAR(10),
			Codigo nvarchar(20),
			Cuenta nvarchar(200),
			[Saldo Anterior] nvarchar(50),
			Debitos nvarchar(50),
			Creditos nvarchar(50),
			[Nuevo Saldo] nvarchar(50),
			Id int,
			ter int,
			cco int,
			id_cot_cliente int,
			id_con_cco int,
			[!n] int
		)

		-- Insertamos en la tabla @@ConsultaCuenta_Tot la ejecucion del SP GetConConsultaCuenta_Tot que obtiene los valores de las cuentas
		INSERT @ConsultaCuenta_Tot
		exec GetConConsultaCuenta_Tot @emp,@Anio,@Mes,@cuentaInf,@factor,@cli,@cuentaSup,@cen,@niif,@ccoDis,@ccoGru,@ccoSub,@vec,@ceninf,@censup,@nada,@consol

		
		insert into @ConsultaCuenta_Tot_Acumulado
		select * 
		from @ConsultaCuenta_Tot t
		where t.Id = @id_con_cta_tit

		-- Eliminamos los datos de la tabla que se utiliza dentro del cursor
		delete from @ConsultaCuenta_Tot

		FETCH NEXT FROM cur_cuentas_cco INTO @id_con_cta_tit
	end  
	CLOSE cur_cuentas_cco  
	DEALLOCATE cur_cuentas_cco 

	-- Resultado 
	declare @CuentasNivel6_SIN_CCO table
	(
		Codigo nvarchar(20),
		Cuenta nvarchar(200),
		Anio int,
		Mes int,
		Grupo nvarchar(50),
		[Saldo Anterior] nvarchar(50),
		Debitos nvarchar(50),
		Creditos nvarchar(50),
		[Nuevo Saldo] nvarchar(50)
	)
	insert @CuentasNivel6_SIN_CCO
	select Codigo,
	       Cuenta,
	       Anio = @Anio,
		   Mes = @Mes,
		   Grupo = '',
		   [Saldo Anterior] = ISNULL(r.[Saldo Anterior],0),
		   Debitos = ISNULL(r.[Debitos],0),
		   Creditos = ISNULL(r.Creditos,0),
		   [Nuevo Saldo] = ISNULL(r.[Nuevo Saldo],0)
	from @ConsultaCuenta_Tot_Acumulado r
	order by 1

	-------------------------------------------------------------------------------------------------------------------
	-------- 2da. Parte ----------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------------------
	
	declare @DetalleCuentasNivel8_SIN_CCO_Consolidado AS TABLE
	(
			Anio int,
			Mes int,
			codigo_nivel6 varchar(32),
			codigo_nivel8 varchar(32),
			cuenta varchar(32),
			centro NVARCHAR(50),
			cod_centro varchar(10),
			Suma_credito decimal(18,2),
			Suma_debito decimal(18,2)
	)

    -- Cursor para iterar en la tabla @CuentasNivel6_CCO
	declare @codigo_nivel4 varchar(4)
	DECLARE cur_CuentasNivel6 CURSOR FORWARD_ONLY STATIC READ_ONLY FOR  
		select distinct left(p.Codigo,4)
		from @CuentasNivel6_SIN_CCO p
		--WHERE p.Codigo in ('111101','111102')
				
	OPEN cur_CuentasNivel6
	FETCH NEXT FROM cur_CuentasNivel6 INTO @codigo_nivel4

	WHILE @@fetch_status = 0  
	begin   
		-- Ejecutamos el procedimiento [dbo].[GetConExportarContable_ids]
		declare @usu int = 11071
		declare @cta_inf varchar(32)= @codigo_nivel4
		declare @cta_sup varchar(32)=concat(@cta_inf,'zzz')
		declare @cli2 int = 0
		declare @d1 int=0
		declare @d2 int=0
		declare @d3 int=0
		declare @d4 int=0
		declare @cco_dis int=0
		declare @cco_gru int=0
		declare @cco_sub int=0
		declare @cco_cen int=0
		declare @tipo int=0
		declare @Sw int=-1000 --CSP 737

		declare @Contable_ids as table--Tabla que almacena el resultado de la ejecucion del SP GetConExportarContable_ids
		(
			cua int
		)
		insert @Contable_ids
		EXEC GetConExportarContable_ids @emp,@usu,@fecIni,@fecFin,@cta_inf,@cta_sup,0,0,0,0,0,0,0,0,0,0,@Sw;
		
		-- Ejecutamos el procedimiento GetConExportarContable
		declare @ExportarContable as table
		(
			id_con_mon int,
			tipo nvarchar(200),
			numero int,
			seq int,
			fecha datetime,
			cuenta varchar(32),
			descripcion nvarchar(200),
			debito money,
			credito money,
			base money,
			debito_niif money,
			credito_niif money,
			nit nvarchar(20),
			tercero nvarchar(MAX),
			centro_distrito NVARCHAR(100),
			centro_grupo NVARCHAR(100),
			centro_sub NVARCHAR(100),
			centro NVARCHAR(100),
			cod_centro varchar(10),
			documento varchar(100),
			--Notas varchar(max),
			dest1 varchar(300),
			dest2 varchar(300),
            dest3 varchar(300),
            dest4 varchar(300),
			sw smallint,
			id_origen int,
			Bodega varchar(100)
		)
		insert @ExportarContable
		exec BI_GetConExportarContable @usu,0
		
		declare @DetalleCuentasNivel8_SIN_CCO AS TABLE
		(
			Anio int,
			Mes int,
			codigo_nivel6 varchar(32),
			codigo_nivel8 varchar(32),
			cuenta varchar(32),
			centro NVARCHAR(50),
			cod_centro varchar(10),
			Suma_credito decimal(18,2),
			Suma_debito decimal(18,2)
		)

		insert @DetalleCuentasNivel8_SIN_CCO
		select @Anio,
		       @Mes,
			   codigo_nivel8 = left(e.cuenta,6),
		       codigo_nivel8 = e.cuenta,
		       e.cuenta,
		       e.centro,
			   e.cod_centro,
			   Suma_credito = convert(decimal(18,2),sum(isnull(credito * (-1),0))),
			   Suma_debito = convert(decimal(18,2),sum(isnull(debito,0)))
		from @ExportarContable e
		--left join @CuentasNivel6_SIN_CCOp on (p.Codigo = left(e.cuenta,6))
		--where e.cuenta = '41110101'
		--and e.centro in ('1178202 Chevrolet  Qto. Esmeraldas Rep. Taller','1178301 Chevrolet  Qto Esmeraldas Tal. Mecanica')
		group by e.cuenta,e.centro,e.cod_centro

		-- Consolidamos los datos de la tabla @ResultadoXCuentaXCentro en la tabla @ResultadoXCuentaXCentro_Consolidado
		insert into @DetalleCuentasNivel8_SIN_CCO_Consolidado
		select * from @DetalleCuentasNivel8_SIN_CCO

		-- Eliminamos los datos de la tabla @DetalleCuentasNivel8_CCO
		delete from @DetalleCuentasNivel8_SIN_CCO
		delete from @ExportarContable
		delete from @Contable_ids



		FETCH NEXT FROM cur_CuentasNivel6 INTO @codigo_nivel4
	end  
	CLOSE cur_CuentasNivel6  
	DEALLOCATE cur_CuentasNivel6 

	select *
	from @DetalleCuentasNivel8_SIN_CCO_Consolidado r

	
END
