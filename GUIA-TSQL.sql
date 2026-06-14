/*
	1. Hacer una función que dado un artículo y un deposito devuelva un string que 
	indique el estado del depósito según el artículo. Si la cantidad almacenada es 
	menor al límite retornar “OCUPACION DEL DEPOSITO XX %” siendo XX el 
	% de ocupación. Si la cantidad almacenada es mayor o igual al límite retornar 
	“DEPOSITO COMPLETO”.
*/

CREATE FUNCTION EJ1 (@articulo CHAR(8), @deposito CHAR(2))
RETURNS VARCHAR(50)
AS
BEGIN
    DECLARE @mensaje VARCHAR(50);
    SELECT @mensaje = CASE
        WHEN stoc_stock_maximo IS NULL OR stoc_stock_maximo = 0 THEN 'LIMITE NO DEFINIDO'
        WHEN stoc_cantidad >= stoc_stock_maximo THEN 'DEPOSITO COMPLETO'
        ELSE 'OCUPACION DEL DEPOSITO ' + 
             CAST(CAST((stoc_cantidad / stoc_stock_maximo) * 100 AS INT) AS VARCHAR(3)) + ' %'
    END
    FROM STOCK 
    WHERE stoc_producto = @articulo 
      AND stoc_deposito = @deposito
    RETURN ISNULL(@mensaje, 'ARTICULO O DEPOSITO INEXISTENTE');
END;
GO

/*
    2. Realizar una función que dado un artículo y una fecha, retorne el stock que 
    existía a esa fecha
*/

create function EJ2 (@articulo char(8), @fecha smalldatetime)
returns decimal(12,2)
as
begin
    declare @stock_actual decimal(12,2);
    select @stock_actual = sum(stoc_cantidad) from STOCK
        where stoc_producto = @articulo;
    declare @stock_vendido decimal(12,2);
    select @stock_vendido = sum(item_cantidad) from Item_Factura
    join Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo
    where item_producto = @articulo and fact_fecha > @fecha;
    return @stock_actual + @stock_vendido;
end;
go

/*
    3. Cree el/los objetos de base de datos necesarios para corregir la tabla empleado 
    en caso que sea necesario. Se sabe que debería existir un único gerente general 
    (debería ser el único empleado sin jefe). Si detecta que hay más de un empleado 
    sin jefe deberá elegir entre ellos el gerente general, el cual será seleccionado por 
    mayor salario. Si hay más de uno se seleccionara el de mayor antigüedad en la 
    empresa.  Al finalizar la ejecución del objeto la tabla deberá cumplir con la regla 
    de un único empleado sin jefe (el gerente general) y deberá retornar la cantidad 
    de empleados que había sin jefe antes de la ejecución.
*/

create proc EJ3
as
begin
    declare @cantSinJefe numeric(6);
    select @cantSinJefe = count(*) from Empleado where empl_jefe is null;
    if(@cantSinJefe > 1)
    begin
        declare @jefe numeric(6);
        select top 1 @jefe = empl_codigo from Empleado
        where empl_jefe is null
        order by empl_salario desc, empl_ingreso desc
        update Empleado set empl_jefe = @jefe where empl_jefe is null and empl_codigo <> @jefe
    end
end
go

/*
    4. Cree el/los objetos de base de datos necesarios para actualizar la columna de 
    empleado empl_comision con la sumatoria del total de lo vendido por ese 
    empleado a lo largo del último año. Se deberá retornar el código del vendedor 
    que más vendió (en monto) a lo largo del último año.
*/

create proc EJ4 (@MejorVendedor numeric(6) output)
as
begin
    update Empleado set empl_comision = isnull((select sum(fact_total) from Factura
                                            where YEAR(fact_fecha) = (select max(year(fact_fecha)) from factura) and fact_vendedor = empl_codigo),0)
    select top 1 @MejorVendedor = fact_vendedor from Factura
    where YEAR(fact_fecha) = (select max(year(fact_fecha)) from factura)
    group by fact_vendedor
    order by sum(fact_total) desc
end
go

/*
    5. Realizar un procedimiento que complete con los datos existentes en el modelo 
    provisto la tabla de hechos denominada Fact_table tiene las siguiente definición:
    Create table Fact_table ( 
        anio char(4), 
        mes char(2), 
        familia char(3), 
        rubro char(4), 
        zona char(3), No se de donde se saca
        cliente char(6), 
        producto char(8), 
        cantidad decimal(12,2), 
        monto decimal(12,2)) 
    Alter table Fact_table
    Add constraint primary key(anio,mes,familia,rubro,zona,cliente,producto) 
*/

create proc EJ5
as
begin
    insert into Fact_table (anio, mes, familia, rubro, cliente, producto, cantidad, monto)
    select YEAR(fact_fecha),
        MONTH(fact_fecha),
        prod_familia,
        prod_rubro,
        fact_cliente,
        item_producto,
        sum(item_cantidad),
        sum(item_cantidad*item_precio)
    from Item_Factura
    join Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo
    join Producto on prod_codigo = item_producto
    group by YEAR(fact_fecha), MONTH(fact_fecha), prod_familia, prod_rubro, fact_cliente, item_producto
end
go

/*
    6. Realizar un procedimiento que si en alguna factura se facturaron componentes 
    que conforman un combo determinado (o sea que juntos componen otro 
    producto de mayor nivel), en cuyo caso deberá reemplazar las filas 
    correspondientes a dichos productos por una sola fila con el producto que 
    componen con la cantidad de dicho producto que corresponda. 
*/

create proc EJ6
as
begin
    declare @combo char(8);
	declare @combocantidad integer;
	
	declare @fact_tipo char(1);
	declare @fact_suc char(4);
	declare @fact_nro char(8);
	
	declare  cFacturas cursor for --CURSOR PARA RECORRER LAS FACTURAS
		select fact_tipo, fact_sucursal, fact_numero
		from Factura ;
		/* where para hacer una prueba acotada
		where fact_tipo = 'A' and
				fact_sucursal = '0003' and
				fact_numero='00092476'; */
		
		open cFacturas
		
		fetch next from cFacturas
		into @fact_tipo, @fact_suc, @fact_nro
		
		while @@FETCH_STATUS = 0
		begin	
			declare  cProducto cursor for
			select comp_producto --ACA NECESITAMOS UN CURSOR PORQUE PUEDE HABER MAS DE UN COMBO EN UNA FACTURA
			from Item_Factura 
			join Composicion C1 on (item_producto = C1.comp_componente)
			where item_cantidad >= C1.comp_cantidad and
				  item_sucursal = @fact_suc and
				  item_numero = @fact_nro and
				  item_tipo = @fact_tipo
			group by C1.comp_producto
			having COUNT(*) = (select COUNT(*) from Composicion as C2 where C2.comp_producto= C1.comp_producto) -- Cuento cuantos comp tengo vs cuantos tiene si cumple puedo armar el combo
			
			open cProducto
			fetch next from cProducto into @combo
			while @@FETCH_STATUS = 0 
			begin
	  					
				select @combocantidad= MIN(FLOOR((item_cantidad/c1.comp_cantidad)))
				from Item_Factura join Composicion C1 on (item_producto = C1.comp_componente)
				where item_cantidad >= C1.comp_cantidad and
					  item_sucursal = @fact_suc and
					  item_numero = @fact_nro and
					  item_tipo = @fact_tipo and
					  c1.comp_producto = @combo	--SACAMOS CUANTOS COMBOS PUEDO ARMAR COMO M�XIMO (POR ESO EL MIN)
				
				--INSERTAMOS LA FILA DEL COMBO CON EL PRECIO QUE CORRESPONDE
				insert into Item_Factura (item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio)
				select @fact_tipo, @fact_suc, @fact_nro, @combo, @combocantidad, (@combocantidad * (select prod_precio from Producto where prod_codigo = @combo));				

				update Item_Factura  
				set 
				item_cantidad = i1.item_cantidad - (@combocantidad * (select comp_cantidad from Composicion
																		where i1.item_producto = comp_componente 
																			  and comp_producto=@combo)),
				ITEM_PRECIO = (i1.item_cantidad - (@combocantidad * (select comp_cantidad from Composicion
															where i1.item_producto = comp_componente 
																  and comp_producto=@combo))) * 	
													(select prod_precio from Producto where prod_codigo = I1.item_producto)											  															  
				from Item_Factura I1, Composicion C1 
				where I1.item_sucursal = @fact_suc and
					  I1.item_numero = @fact_nro and
					  I1.item_tipo = @fact_tipo AND
					  I1.item_producto = C1.comp_componente AND
					  C1.comp_producto = @combo
					  
				delete from Item_Factura
				where item_sucursal = @fact_suc and
					  item_numero = @fact_nro and
					  item_tipo = @fact_tipo and
					  item_cantidad = 0
				
				fetch next from cproducto into @combo
			end
			close cProducto;
			deallocate cProducto;
			
			fetch next from cFacturas into @fact_tipo, @fact_suc, @fact_nro
			end
			close cFacturas;
			deallocate cFacturas;
	end 
go 

/*
	7. Hacer un procedimiento que dadas dos fechas complete la tabla Ventas. Debe 
	insertar una línea por cada artículo con los movimientos de stock generados por 
	las ventas entre esas fechas. La tabla se encuentra creada y vacía. 

	Código		Detalle		Cant. Mov.		Precio de Venta		Renglón				Ganancia 
	
	Código		Detalle		Cantidad de		Precio				Nro. de línea de	Precio de Venta – Cantidad * 
	del			del			movimientos de	promedio de			la tabla			Costo Actual
	articulo	articulo	ventas (Item	venta
							factura)
*/

-- No entiendo el calculo de ganancia, voy a suponer que costo actual es el que esta en prod --> sum(item_precio*item_cantidad) - sum(item_cantidad*prod_precio)

create proc EJ7 (@fechaInicio smalldatetime, @fechaFin smalldatetime)
as
begin
	insert into Ventas (vent_productoCodigo, vent_productoDetalle, vent_mov, vent_precioProm, vent_renglon, vent_ganancia)
	select prod_codigo, 
		prod_detalle,
		count(distinct fact_numero+fact_tipo+fact_sucursal),
		AVG(item_precio),
		isnull((select max(vent_renglon) + 1 from Ventas),0),
		sum(item_precio*item_cantidad) - sum(item_cantidad*prod_precio)
	from Item_Factura
	join Producto on prod_codigo = item_producto
	join Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo and @fechaInicio < fact_fecha and @fechaFin > fact_fecha
	group by prod_codigo, prod_detalle
end
go

/*
	8. Realizar un procedimiento que complete la tabla Diferencias de precios, para los 
	productos facturados que tengan composición y en los cuales el precio de 
	facturación sea diferente al precio del cálculo de los precios unitarios por 
	cantidad de sus componentes, se aclara que un producto que compone a otro, 
	también puede estar compuesto por otros y así sucesivamente, la tabla se debe 
	crear y está formada por las siguientes columnas: 

	DIFERENCIAS 

	Código		Detalle		Cantidad		Precio_generado			Precio_facturado 
	
	Código		Detalle		Cantidad de		Precio que se			Precio del producto
	del			del			productos que	compone a través de
	articulo	articulo	conforman el	sus componentes
							combo
*/

create table diferencias (
	codigo char(8), 
	detalle char(50),
	cantidad numeric(12,4), 
	precio_combo numeric(12,4),
	precio_facturado numeric(12,4))
go 

create proc EJ8
as
begin
	delete from diferencias;
	insert into Diferencias (codigo, detalle, cantidad, precio_combo, precio_facturado)
	select prod_codigo, prod_detalle, (select count(*) from Composicion where comp_producto = prod_codigo), dbo.EJ8_CalcularPrecio(prod_codigo), item_precio from Producto
	join Composicion on comp_producto = prod_codigo
	join Item_Factura on item_producto = prod_codigo
	group by prod_codigo, prod_detalle, item_precio
end
go

create function EJ8_CalcularPrecio (@prod char(8))
returns decimal(12,2)
as
begin
	if ((select count(*) from Composicion where comp_producto = @prod) = 0)
	begin
		return (select prod_precio from Producto where prod_codigo = @prod);
	end

	declare @comp char(8);
	declare @cant decimal(12,2);
	declare @total decimal(12,2) = 0.0;
	declare cComp cursor for -- recorro los componentes
		select comp_componente, comp_cantidad from Composicion where comp_producto = @prod

	open cComp
	fetch next from cComp into @comp, @cant

	while @@FETCH_STATUS = 0
	begin
		set @total = @total + @cant * dbo.EJ8_CalcularPrecio(@comp);
		fetch next from cComp into @comp, @cant
	end

	return @total;
end
go

/*
	9. Crear el/los objetos de base de datos que ante alguna modificación de un ítem de 
	factura de un artículo con composición realice el movimiento de sus 
	correspondientes componentes. 
*/

create trigger EJ9
on STOCK
instead of update
as
begin
	declare @prod char(8);
	declare @cantN decimal(12,2);
	declare @cantA decimal(12,2);

	declare itemActualizado cursor for
		select stoc_producto, stoc_cantidad from inserted
		
	open itemActualizado
	fetch next from itemActualizado into @prod, @cantN

	while @@FETCH_STATUS = 0
	begin
		if (select count(*) from Composicion where comp_producto = @prod) > 0
		begin
			select @cantA = stoc_cantidad from deleted where stoc_producto = @prod

			declare @comp char(8);
			declare @cant decimal(12,2);

			declare cComp cursor for
				select comp_componente, comp_cantidad from Composicion where comp_producto = @prod

			open cComp
			fetch next from cComp into @comp, @cant

			while @@FETCH_STATUS = 0
			begin
				update STOCK
				set stoc_cantidad = stoc_cantidad + (@cantA - @cantN)*@cant
				where stoc_producto = @comp and stoc_deposito = '00' 
				fetch next from cComp into @comp, @cant
			end

			close cComp;
			deallocate cComp;
		end
		fetch next from itemActualizado into @prod, @cantN
	end
	close itemActualizado;
	deallocate itemActualizado;
end
go

/*
	10. Crear el/los objetos de base de datos que ante el intento de borrar un artículo 
	verifique que no exista stock y si es así lo borre en caso contrario que emita un 
	mensaje de error.  
*/

create trigger EJ10
on Producto
instead of delete
as
begin
	if(select count(*) from deleted join STOCK on stoc_producto = prod_codigo and stoc_cantidad > 0) > 0
		print 'ERROR: Productos con Stock'
	else
		begin
		delete from STOCK where stoc_producto in (select prod_codigo from deleted)
		delete from Producto where prod_codigo in (select prod_codigo from deleted)
		end
end
go

/*
	11. Cree el/los objetos de base de datos necesarios para que dado un código de 
	empleado se retorne la cantidad de empleados que este tiene a su cargo (directa o 
	indirectamente). Solo contar aquellos empleados (directos o indirectos) que 
	tengan un código mayor que su jefe directo
*/

create function EJ11 (@emplCod numeric(6))
returns numeric(6)
as
begin
	if (select count(*) from Empleado where empl_jefe = @emplCod and empl_codigo > @emplCod) = 0 -- No tiene empleados
	begin
		return 0
	end
	return (select count(*) + sum(dbo.EJ11(empl_codigo)) from Empleado where empl_jefe = @emplCod and empl_codigo > @emplCod)
end
go

/*
	12. Cree el/los objetos de base de datos necesarios para que nunca un producto 
	pueda ser compuesto por sí mismo. Se sabe que en la actualidad dicha regla se 
	cumple y que la base de datos es accedida por n aplicaciones de diferentes tipos 
	y tecnologías. No se conoce la cantidad de niveles de composición existentes.
*/

create function EJ12_Compone (@producto char(8), @componente char(8))
returns int 
as 
begin 
    declare @retorno int, @componedor char(8)
    select @retorno = 0
    if @producto = @componente
        return 1
    declare c1 cursor for (select comp_componente from composicion where comp_producto = @producto)
    open c1 
    fetch c1 into @componedor
    while @@fetch_status = 0
    begin
        if (dbo.EJ12_Compone(@componedor, @componente) = 1)
        begin
            select @retorno = 1    
            break
        end
        fetch c1 into @componedor
    end 
    close c1
    deallocate c1
    return @retorno
end 
go 

create trigger EJ12 on Composicion
instead of update, insert
as
begin
	if (select count(*) from inserted where dbo.EJ12_Compone(comp_componente, comp_producto) = 1 ) > 0
	begin
		raiserror('El producto no puede estar compuesto por si mismo',16,1);
		rollback transaction
	end		
end
go

/*
	13. Cree el/los objetos de base de datos necesarios para implantar la siguiente regla 
	“Ningún jefe puede tener un salario mayor al 20% de las suma de los salarios de 
	sus empleados totales (directos + indirectos)”. Se sabe que en la actualidad dicha 
	regla se cumple y que la base de datos es accedida por n aplicaciones de 
	diferentes tipos y tecnologías
*/

create trigger EJ13 on Empleado
after insert, update
as
begin
	if (select count(*) from inserted where empl_salario > 0.2 * dbo.EJ13_SalarioEmpleados(empl_codigo)) > 0
	begin
		raiserror('ERROR: SALARIO DEL JEFE MAYOR AL 20% DE LOS EMPLEADOS', 16, 1)
		rollback transaction
	end
end
go

create function EJ13_SalarioEmpleados(@jefe numeric(6))
returns decimal(12,2)
as
begin
	if (@jefe is null)
		return 0

	return (select empl_salario from Empleado where empl_codigo = @jefe) + 
		(select isnull(sum(dbo.EJ13_SalarioEmpleados(empl_codigo)),0) from Empleado where empl_jefe = @jefe)
end
go

/*
	14. Agregar el/los objetos necesarios para que si un cliente compra un producto 
	compuesto a un precio menor  que la suma de los precios de sus componentes  
	que imprima la  fecha, que cliente, que productos y a qué precio se realizó la 
	compra. No se deberá permitir que dicho precio sea menor a la mitad de la suma (del prod?)
	de los componentes.
*/

create trigger EJ14 on Item_factura
instead of insert
as
begin
	declare @prodComp char(8)
	declare @precCompra decimal(12,2)
	declare @itemTipo char(1)
	declare @itemSucursal char(4)
	declare @itemNumero char(8)

	declare cProd cursor for
		select item_producto, item_precio, item_numero, item_sucursal, item_tipo from inserted join Composicion on comp_producto = item_producto

	open cProd
	fetch next cProd into @prodComp, @precCompra, @itemNumero, @itemSucursal, @itemTipo
	while @@FETCH_STATUS = 0
	begin
		if (@precCompra > (select sum(comp_cantidad*prod_precio) from Composicion 
							join Producto on prod_codigo = comp_componente where comp_producto = @prodComp)/2)
		begin
			raiserror('Error precio venta', 16, 1)
			rollback transaction
		end

		-- Valores
		select YEAR(fact_fecha), fact_cliente, item_producto, fact_total from inserted 
		join Factura on item_numero = fact_numero and fact_sucursal = item_sucursal and fact_tipo = item_tipo
		where item_numero = @itemNumero and item_tipo = @itemTipo and item_sucursal = @itemSucursal


		fetch next cProd into @prodComp, @precCompra, @itemNumero, @itemSucursal, @itemTipo
	end

	close cProd
	deallocate cProd
end
go

/*
	15. Cree el/los objetos de base de datos necesarios para que el objeto principal 
	reciba un producto como parametro y retorne el precio del mismo. 
	Se debe prever que el precio de los productos compuestos sera la sumatoria de 
	los componentes del mismo multiplicado por sus respectivas cantidades. No se 
	conocen los nivles de anidamiento posibles de los productos. Se asegura que 
	nunca un producto esta compuesto por si mismo a ningun nivel. El objeto 
	principal debe poder ser utilizado como filtro en el where de una sentencia 
	select.
*/

create function EJ15(@prod char(8))
returns decimal(12,2)
as
begin
	if exists (select 1 from Composicion where @prod = comp_producto) -- tiene composición
	begin
		return (select sum(dbo.EJ15(comp_componente)*comp_cantidad) from Composicion where @prod = comp_producto)
	end
	return (select prod_precio from Producto where prod_codigo = @prod)
end
go

/*
	16. Desarrolle el/los elementos de base de datos necesarios para que ante una venta 
	automaticamante se descuenten del stock los articulos vendidos. Se descontaran 
	del deposito que mas producto poseea y se supone que el stock se almacena 
	tanto de productos simples como compuestos (si se acaba el stock de los 
	compuestos no se arman combos) 
	En caso que no alcance el stock de un deposito se descontara del siguiente y asi 
	hasta agotar los depositos posibles. En ultima instancia se dejara stock negativo 
	en el ultimo deposito que se desconto.
*/

create trigger EJ16 on Item_factura -- No se pueden usar procedures en el select :(
after insert
as
begin
	declare @prod char(8)
	declare @cant decimal(12,2)

	declare cItem cursor for
		select item_producto, item_cantidad from inserted

	open cItem
	fetch next cItem into @prod, @cant

	while @@FETCH_STATUS = 0
	begin
		exec EJ16_ReducirStock @prod, @cant
		fetch next cItem into @prod, @cant
	end

	close cItem
	deallocate cItem
end
go

create procedure EJ16_ReducirStock(@prod char(8), @cant decimal(12,2))
as
begin
	if exists (select 1 from Composicion where comp_producto = @prod) -- tiene composicion
	begin
		declare @componente char(8)
		declare @cantCompo decimal(12,2)

		declare cComp cursor for
			select @componente, @cantCompo from Composicion where comp_producto = @prod

		open cComp
		fetch cComp into @componente, @cantCompo

		while @@FETCH_STATUS = 0
		begin
			set @cantCompo = @cantCompo * @cant
			exec EJ16_ReducirStock @componente, @cantCompo
			fetch cComp into @componente, @cantCompo
		end

		close cComp
		deallocate cComp
	end
	else
	begin
		declare @cantidadStock decimal(12,2)
		declare @deposito char(2)
		declare @depositoFinal char (2) = (select top 1 stoc_deposito from STOCK where stoc_producto = @prod
											order by stoc_cantidad asc) -- Asi se donde corto y pongo stock negativo

		declare cStock cursor for
			select stoc_cantidad, stoc_deposito from STOCK where stoc_producto = @prod
			order by stoc_cantidad desc

		open cStock
		fetch cStock into @cantidadStock, @deposito

		while @@FETCH_STATUS = 0
		begin
			if @cant > @cantidadStock
			begin
				if @deposito = @depositoFinal -- Último deposito le puedo poner el valor negativo
				begin
					update STOCK set stoc_cantidad = @cantidadStock - @cant
					where stoc_deposito = @deposito and stoc_producto = @prod
				end
				else -- le asigno lo que puedo
				begin
					update STOCK set stoc_cantidad = 0
					where stoc_deposito = @deposito and stoc_producto = @prod

					set @cant = @cant - @cantidadStock
				end
			end
			else -- lo puedo cubrir
			begin
				update STOCK set stoc_cantidad = @cantidadStock - @cant
				where stoc_deposito = @deposito and stoc_producto = @prod
			end
			fetch cStock into @cantidadStock, @deposito
		end

		close cStock
		deallocate cStock
	end
end
go

/*
	17. Sabiendo que el punto de reposicion del stock es la menor cantidad de ese objeto 
	que se debe almacenar en el deposito y que el stock maximo es la maxima 
	cantidad de ese producto en ese deposito, cree el/los objetos de base de datos 
	necesarios para que dicha regla de negocio se cumpla automaticamente. No se 
	conoce la forma de acceso a los datos ni el procedimiento por el cual se 
	incrementa o descuenta stock
*/

-- Entiendo que cuando cargo debe estar por encima del stock de repo y por debajo del maximo, un between

create trigger EJ17 on STOCK
after insert, update
as
begin
	update STOCK set stoc_cantidad = s.stoc_punto_reposicion -- Si esta por debajo lo dejo en el de reposición
	from STOCK s
	join inserted i on s.stoc_producto = i.stoc_producto and s.stoc_deposito = i.stoc_deposito
	where i.stoc_cantidad < s.stoc_punto_reposicion

	update STOCK set stoc_cantidad = s.stoc_stock_maximo -- Si esta por encima lo dejo en el máximo
	from STOCK s
	join inserted i on s.stoc_producto = i.stoc_producto and s.stoc_deposito = i.stoc_deposito
	where i.stoc_cantidad > s.stoc_stock_maximo
end
go

/*
	18. Sabiendo que el limite de credito de un cliente es el monto maximo que se le 
	puede facturar mensualmente, cree el/los objetos de base de datos necesarios 
	para que dicha regla de negocio se cumpla automaticamente. No se conoce la 
	forma de acceso a los datos ni el procedimiento por el cual se emiten las facturas
*/

create trigger EJ18 on Factura
after insert, update
as
begin
	if exists (select 1 from inserted i
				join Cliente on fact_cliente = clie_codigo
				where clie_limite_credito < (select sum(fact_total) from Factura where fact_cliente = i.fact_cliente
													and YEAR(fact_fecha) = YEAR(i.fact_fecha) and MONTH(fact_fecha) = MONTH(i.fact_fecha)))
	begin
		raiserror('Se quedo sin limite de crédito', 16, 1)
		rollback transaction
	end
end
go

/*
	19. Cree el/los objetos de base de datos necesarios para que se cumpla la siguiente 
	regla de negocio automáticamente “Ningún jefe puede tener menos de 5 años de 
	antigüedad y tampoco puede tener más del 50% del personal a su cargo 
	(contando directos e indirectos) a excepción del gerente general”. Se sabe que en 
	la actualidad la regla se cumple y existe un único gerente general.
*/

-- Evaluo solo los empleados a los que le cambio el jefe:
--		Si es un nuevo jefe --> Sus empleados cambiaron
--		Si cambio el jefe --> Cambio el empleado

create trigger EJ19 on Empleado
after insert, update
as
begin
	if exists (select 1 from inserted i join Empleado e on i.empl_jefe = e.empl_codigo and DATEDIFF(YEAR, i.empl_ingreso, GETDATE()) < 5) -- Es un jefe con menos de 5 años --> MALO
	begin
		raiserror('Antigüedad menor a 5', 16, 1)
		rollback transaction
	end
	if exists (select 1 from inserted i join Empleado e on i.empl_jefe = e.empl_codigo
				where e.empl_jefe is not null and -- No es el gerente general
				dbo.EJ19_ContarEmpleadosDireIndire(e.empl_codigo) > (select count(*) from Empleado)/2)
	begin
		raiserror('Tiene muchos empleados', 16, 1)
		rollback transaction
	end
end
go

create function EJ19_ContarEmpleadosDireIndire(@empl numeric(6))
returns int
as
begin
	if not exists (select 1 from Empleado where empl_jefe = @empl) -- No tiene empleados
		return 0

	return (select count(*) + isnull(sum(dbo.EJ19_ContarEmpleadosDireIndire(empl_codigo)), 0) 
				from Empleado where empl_jefe = @empl)
end
go

/*
	20. Crear el/los objeto/s necesarios para mantener actualizadas las comisiones del 
	vendedor. 
	El cálculo de la comisión está dado por el 5% de la venta total efectuada por ese 
	vendedor en ese mes, más un 3% adicional en caso de que ese vendedor haya 
	vendido por lo menos 50 productos distintos en el mes.
*/

-- Entiendo que esto se dispara cuando se hace una factura

create trigger EJ20 on Factura
after insert
as
begin
	declare @vendedor numeric(6)

	declare cVend cursor for	-- Itero sobre aquellos vendedores que realizaron una venta
		select distinct fact_vendedor from inserted

	open cVend
	fetch cVend into @vendedor

	while @@FETCH_STATUS = 0
	begin
		declare @prodVendidos int
		declare @monto decimal(12,2)

		-- Obtengo los montos usando las facturas de ese vendedor en el último mes
		select @prodVendidos = count(distinct item_producto), @monto = sum(item_precio*item_cantidad) from Factura
		join Item_Factura on fact_numero = item_numero and fact_sucursal = item_sucursal and fact_tipo = item_tipo
		where fact_vendedor = @vendedor and MONTH(fact_fecha) = MONTH(getdate()) and YEAR(fact_fecha) = YEAR(getdate())

		update Empleado set empl_comision = (case when @prodVendidos >= 50 then @monto * 0.08
													else @monto * 0.05 end)
		where empl_codigo = @vendedor

		fetch cVend into @vendedor
	end

	close cVend
	deallocate cVend
end
go

/*
	21. Desarrolle el/los elementos de base de datos necesarios para que se cumpla 
	automaticamente la regla de que en una factura no puede contener productos de 
	diferentes familias.  En caso de que esto ocurra no debe grabarse esa factura y 
	debe emitirse un error en pantalla.
*/

create trigger EJ21 on Item_factura
after insert
as
begin
	if exists (select 1 from inserted
				join Producto on item_producto = prod_codigo
				group by item_numero, item_tipo, item_sucursal
				having count(distinct prod_familia) > 1) -- Tiene una factura con productos de más de una familia
	begin
		raiserror('Factura inválida: Tiene productos de más de una familia', 16, 1)
		rollback transaction
	end
end
go

/*
	22. Se requiere recategorizar los rubros de productos, de forma tal que nigun rubro 
	tenga más de 20 productos asignados, si un rubro tiene más de 20 productos 
	asignados se deberan distribuir en otros rubros que no tengan mas de 20 
	productos y si no entran se debra crear un nuevo rubro en la misma familia con 
	la descirpción “RUBRO REASIGNADO”, cree el/los objetos de base de datos 
	necesarios para que dicha regla de negocio quede implementada. 
*/

-- Entiendo que es algo que se ejecuta cuando nosotros decidimos, no automático
-- Entiendo que lo pongo en cualquier rubro y el nuevo rubro debe ser de la familia original

create proc EJ22
as
begin
	declare @rubro char(4)
	declare @excedente int

	declare cRub cursor for
		select prod_rubro, count(*) - 20 from Producto group by prod_rubro having count(*) > 20 -- Rubros con más de 20 productos

	open cRub
	fetch cRub into @rubro, @excedente

	while @@FETCH_STATUS = 0 
	begin
		declare @rubroInsertar char(4)
		declare @cantInsertar int

		declare cRubIns cursor for
			select prod_rubro, 20 - count(*) from Producto group by prod_rubro having count(*) < 20 -- Rubros con menos de 20 prod

		open cRubIns
		fetch cRubIns into @rubroInsertar, @cantInsertar

		while @@FETCH_STATUS = 0 and @excedente > 0
		begin
			set @cantInsertar = least(@cantInsertar, @excedente) -- Inserto lo mínimo (lo q puedo insertar, lo q me falta)
			set @excedente = @excedente - @cantInsertar -- Resto lo que tengo insertar con el mínimo

			update Producto set prod_rubro = @rubroInsertar
			where prod_rubro = @rubro 
			and prod_codigo in (select top (@cantInsertar) prod_codigo from Producto where prod_rubro = @rubro) -- Agarro N elementos

			fetch cRubIns into @rubroInsertar, @cantInsertar
		end

		close cRubIns
		deallocate cRubIns

		while @excedente > 0 -- Creo el nuevo rubro
		begin
			declare @cantAsignar int = least(20, @excedente)

			insert into Rubro (rubr_detalle) -- El ID supongo que es incremental
			values ('RUBRO REASIGNADO')

			declare @nuevoRubro char(4) = (select MAX(rubr_id) from Rubro) -- es el máximo porq es el último que se añadio

			update Producto set prod_rubro = @nuevoRubro
			where prod_rubro = @rubro 
			and prod_codigo in (select top (@cantAsignar) prod_codigo from Producto where prod_rubro = @rubro) -- Agarro N elementos

			set @excedente = @excedente - @cantAsignar
		end
		
		fetch cRub into @rubro, @excedente
	end
	
	close cRub
	deallocate cRub
end
go

/*
	23. Desarrolle el/los elementos de base de datos necesarios para que ante una venta 
	automaticamante se controle que en una misma factura no puedan venderse más 
	de dos productos con composición.  Si esto ocurre debera rechazarse la factura. 
*/

-- Según mi amigo claudio tengo que chequear sobre Item_factura y no sobre inserted

create trigger EJ23 on Item_factura
after insert
as
begin
	if exists (select 1 from Item_Factura join Composicion on item_producto = comp_producto
				group by item_numero, item_tipo, item_sucursal
				having count(distinct item_producto) > 2)
	begin
		raiserror('Se realizo una venta con más de dos productos con composición', 16, 1)
		rollback transaction
	end
end
go

/*
	24. Se requiere recategorizar los encargados asignados a los depositos.  Para ello 
	cree el o los objetos de bases de datos necesarios que lo resueva, teniendo en 
	cuenta que un deposito no puede tener como encargado un empleado que 
	pertenezca a un departamento que no sea de la misma zona que el deposito, si 
	esto ocurre a dicho deposito debera asignársele el empleado con menos 
	depositos asignados que pertenezca a un departamento de esa zona. 
*/

create proc EJ24
as
begin
	declare @depoCod char(2)
	declare @depoZona char(3)

	declare cDeposito cursor for -- Depositos que no cumplen con la regla
		(select depo_codigo, depo_zona from DEPOSITO
		join Empleado on depo_encargado = empl_codigo
		join Departamento on empl_departamento = depa_codigo
		where depo_zona <> depa_zona)

	open cDeposito
	fetch cDeposito into @depoCod, @depoZona

	while @@FETCH_STATUS = 0
	begin
		update DEPOSITO set depo_encargado = (select top 1 empl_codigo from Empleado
												left join DEPOSITO on depo_encargado = empl_codigo
												join Departamento on depa_codigo = empl_departamento
												where depa_zona = @depoZona
												group by empl_codigo
												order by count(distinct depo_codigo) asc) -- Entiendo que podría ser un count(*)
		where depo_codigo = @depoCod

		fetch cDeposito into @depoCod, @depoZona
	end

	close cDeposito
	deallocate cDeposito
end
go

/*
	25. Desarrolle el/los elementos de base de datos necesarios para que no se permita 
	que la composición de los productos sea recursiva, o sea, que si el producto A 
	compone al producto B, dicho producto B no pueda ser compuesto por el 
	producto A, hoy la regla se cumple.
*/

create trigger EJ25 on Composicion
after insert, update
as
begin
	if exists (select 1 from inserted where dbo.EJ25_EvaluarRecursividad(comp_componente, comp_producto) = 1)
	begin
		raiserror('Se detecto una composición circular', 16, 1)
		rollback transaction
	end
end
go

create function EJ25_EvaluarRecursividad(@componente char(8), @producto char(8))
returns bit
as
begin
	if (@componente = @producto)
		return 1
	declare @rta bit = 0
	declare @comp char(8)
	
	declare cComp cursor for
		select comp_componente from Composicion where comp_producto = @componente

	open cComp
	fetch cComp into @comp

	while @@FETCH_STATUS = 0
	begin
		if(dbo.EJ25_EvaluarRecursividad(@comp, @producto) = 1) -- Ta malo
		begin
			set @rta = 1
			break
		end
		fetch cComp into @comp
	end

	close cComp
	deallocate cComp

	return @rta
end
go

/*
	26. Desarrolle el/los elementos de base de datos necesarios para que se cumpla 
	automaticamente la regla de que una factura no puede contener productos que 
	sean componentes de otros productos.  En caso de que esto ocurra no debe 
	grabarse esa factura y debe emitirse un error en pantalla.
*/

-- Tienen que estar en la misma factura los dos? 

create trigger EJ26 on Item_factura
after update, insert
as
begin
	if exists (select 1 from inserted i1
				join Composicion on i1.item_producto = comp_producto
				join Item_Factura i2 on comp_componente = i2.item_producto and i1.item_numero = i2.item_numero and i1.item_sucursal = i2.item_sucursal and i1.item_tipo = i2.item_tipo
				group by i1.item_numero, i1.item_sucursal, i1.item_tipo)
	begin
		raiserror('Se compro prod con composicion y su componente', 16, 1)
		rollback transaction
	end
end
go

/*
	27. Se requiere reasignar los encargados de stock de los diferentes depósitos.  Para 
	ello se solicita que realice el o los objetos de base de datos necesarios para 
	asignar a cada uno de los depósitos el encargado que le corresponda, 
	entendiendo que el encargado que le corresponde es cualquier empleado que no 
	es jefe y que no es vendedor, o sea, que no está asignado a ningun cliente, se 
	deberán ir asignando tratando de que un empleado solo tenga un deposito 
	asignado, en caso de no poder se irán aumentando la cantidad de depósitos 
	progresivamente para cada empleado. 
*/

create proc EJ27
as
begin
	declare @depoCodigo numeric(6)

	declare cDepo cursor for
		select depo_codigo from DEPOSITO

	open cDepo
	fetch cDepo into @depoCodigo

	while @@FETCH_STATUS = 0
	begin
		-- Si no estuviera dentro while, con el cursor se ejecutaría una sola vez la consulta asignando siempre el mismo, creo que el cursor lo arregla.
		update DEPOSITO set depo_encargado = (select top 1 empl_codigo from Empleado
											left join Cliente on empl_codigo = clie_vendedor
											left join DEPOSITO on empl_codigo = depo_encargado
											where clie_vendedor is null and empl_codigo not in (select distinct empl_jefe from Empleado where empl_jefe is not null)
											group by empl_codigo
											order by count(distinct depo_codigo) asc)
		where depo_codigo = @depoCodigo

		fetch cDepo into @depoCodigo
	end

	close cDepo
	deallocate cDepo
end
go

/*
	28. Se requiere reasignar los vendedores a los clientes. Para ello se solicita que 
	realice el o los objetos de base de datos necesarios para asignar a cada uno de los 
	clientes el vendedor que le corresponda, entendiendo que el vendedor que le 
	corresponde es aquel que le vendió más facturas a ese cliente, si en particular un 
	cliente no tiene facturas compradas se le deberá asignar el vendedor con más 
	venta de la empresa, o sea, el que en monto haya vendido más.
*/

create proc EJ28
as
begin
	declare @cliente char(6)
	declare @TOPVendedor numeric(6) = (select top 1 fact_vendedor from Factura group by fact_vendedor order by sum(fact_total) desc)

	declare cCliente cursor for
		select clie_codigo from Cliente

	open cCliente
	fetch cCliente into @cliente

	while @@FETCH_STATUS = 0
	begin
		declare @vendedor numeric(6) = (select top 1 fact_vendedor from Factura
											where fact_cliente = @cliente
											group by fact_vendedor
											order by count(*) desc)

		if @vendedor is null
			set @vendedor = @TOPVendedor

		update Cliente set clie_vendedor = @vendedor
		where clie_codigo = @cliente

		fetch cCliente into @cliente
	end

	close cCliente
	deallocate cCliente
end
go

/*
	29. Desarrolle el/los elementos de base de datos necesarios para que se cumpla 
	automaticamente la regla de que una factura no puede contener productos que 
	sean componentes de diferentes productos.  En caso de que esto ocurra no debe 
	grabarse esa factura y debe emitirse un error en pantalla. 
*/

create trigger EJ29 on Item_factura
after insert
as
begin
	if exists (select 1 from inserted join Composicion on comp_componente = item_producto
				group by item_numero, item_tipo, item_sucursal
				having count(distinct comp_producto) > 1)
	begin
		raiserror('Compra con componentes de productos diferentes', 16, 1)
		rollback transaction
	end
end
go

/*
	30. Agregar el/los objetos necesarios para crear una regla por la cual un cliente no 
	pueda comprar más de 100 unidades en el mes de ningún producto, si esto 
	ocurre no se deberá ingresar la operación y se deberá emitir un mensaje “Se ha 
	superado el límite máximo de compra de un producto”.  Se sabe que esta regla se 
	cumple y que las facturas no pueden ser modificadas.
*/

create trigger EJ30 on Item_factura
after insert
as
begin
	declare @cliente char(6)

	declare cCompra cursor for -- Recorro cada cliente que compro
		select distinct fact_cliente from inserted
		join Factura on item_numero = fact_numero and item_tipo = fact_tipo and item_sucursal = fact_sucursal

	open cCompra
	fetch cCompra into @cliente

	while @@FETCH_STATUS = 0
	begin
		if exists (select 1 from Item_Factura 
			join Factura on item_numero = fact_numero and item_tipo = fact_tipo and item_sucursal = fact_sucursal
			and YEAR(fact_fecha) = YEAR(GETDATE()) and MONTH(fact_fecha) = MONTH(GETDATE()) and fact_cliente = @cliente
			group by item_producto
			having sum(item_cantidad) > 100)
		begin
			raiserror('Límite de compra alcanzado', 16, 1)
			rollback transaction
		end
		
		fetch cCompra into @cliente
	end

	close cCompra
	deallocate cCompra
end
go

/*
	31. Desarrolle el o los objetos de base de datos necesarios, para que un jefe no pueda 
	tener más de 20 empleados a cargo, directa o indirectamente, si esto ocurre 
	debera asignarsele un jefe que cumpla esa condición, si no existe un jefe para 
	asignarle se le deberá colocar como jefe al gerente general que es aquel que no 
	tiene jefe.
*/

-- Entiendo que la regla ya se cumplia, sino sería correr un procedure que lo aplique a todos

create trigger EJ31 on Empleado
after insert, update
as
begin
	declare @jefe numeric(6)
	declare @cantAsignar int
	declare @gerente numeric(6) = (select empl_codigo from Empleado where empl_jefe is null)

	declare cJefe cursor for -- Jefes con más de 20 empleados
		select empl_jefe, (dbo.EJ31_CalcularEmpleados(empl_jefe) - 20) from Empleado where dbo.EJ31_CalcularEmpleados(empl_jefe) > 20 and empl_jefe <> @gerente

	open cJefe
	fetch cJefe into @jefe, @cantAsignar

	while @@FETCH_STATUS = 0
	begin
		declare @empleado numeric(6)
		declare @empleados int
		
		declare cEmpleado cursor for
			select empl_codigo, dbo.EJ31_CalcularEmpleados(empl_codigo) from Empleado where empl_jefe = @jefe

		open cEmpleado
		fetch cEmpleado into @empleado, @empleados

		while @@FETCH_STATUS = 0 and @cantAsignar > 0
		begin
			declare @nuevoJefe numeric(6) = (select top 1 empl_jefe from Empleado where (dbo.EJ31_CalcularEmpleados(empl_jefe) + @empleados) <= 20 and empl_jefe <> @gerente)

			if @nuevoJefe is not null
			begin
				update Empleado set empl_jefe = @nuevoJefe
				where empl_codigo = @empleado

				set @cantAsignar = @cantAsignar - @empleados
			end

			fetch cEmpleado into @empleado, @empleados
		end

		close cEmpleado
		deallocate cEmpleado

		if @cantAsignar > 0
		begin
			-- Repito la lógica pero asignando siempre al gerente
			set @cantAsignar = 0
		end
	end

	close cJefe
	deallocate cJefe
end
go

create function EJ31_CalcularEmpleados(@empl numeric(6))
returns int
as
begin
	if exists (select 1 from Empleado where empl_jefe = @empl) -- Tiene empleados
		return (select count(*) + sum(dbo.EJ31_CalcularEmpleados(empl_codigo)) from Empleado where empl_jefe = @empl)
	return 0
end
go