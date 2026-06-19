/*
	1. **Consulta SQL para analizar clientes con patrones de compra específicos:**

	Se debe identificar clientes que realizaron una compra inicial y luego volvieron a comprar después de 5 meses o más.
			-- Compra inicial se refiere a la primer compra?

	La consulta debe mostrar:

	1. Número de fila: Identificador secuencial del resultado.
	2. Código del cliente: ID único del cliente.
	3. Nombre del cliente: Nombre asociado al cliente. -- No tiene nombre sino que tiene razon social
	4. Cantidad total comprada: Total de productos distintos adquiridos por el cliente.
	5. Total facturado: Importe total facturado al cliente.

	El resultado debe estar ordenado de forma descendente por la cantidad de productos adquiridos por cada cliente.

	**Nota:** No se permiten select en el from, es decir, select ... from (select ...) as T,... Ni el uso de with.
*/

select --ROW_NUMBER() numero_fila, -- no se como se usa el ROW_NUMBER
	f1.fact_cliente cod_cliente,
	clie_razon_social nombre,
	count(distinct item_producto) cantidad_total,
	sum(item_cantidad*item_precio) monto_total
from Factura f1
join Cliente on clie_codigo = f1.fact_cliente
join Item_Factura on item_tipo = f1.fact_tipo and item_sucursal = f1.fact_sucursal and item_numero = f1.fact_numero
where f1.fact_cliente in (select distinct fact_cliente from Factura f2 -- Traigo los clientes que tuvieron una compra despues de los 5 meses, si lo hago en el original pierdo facturas.
							where DATEDIFF(month, (select min(fact_fecha) from Factura f3 where f3.fact_cliente = f1.fact_cliente), f2.fact_fecha) >= 5)
group by fact_cliente, clie_razon_social
order by sum(item_cantidad) desc
go

/*
	2. **Corrección de registro de ventas: desagregación de productos compuestos**

	Se detectó un error en el proceso de registro de ventas, donde se almacenaron productos compuestos en lugar de sus componentes individuales. Para solucionar este problema, se debe:

	1. Diseñar e implementar los objetos necesarios para reorganizar las ventas tal como están registradas actualmente.
	2. Desagregar los productos compuestos vendidos en sus componentes individuales, asegurando que cada venta refleje correctamente los elementos que la componen.
	3. Garantizar que la base de datos quede consistente y alineada con las especificaciones requeridas para el manejo de productos.
*/

-- En teoría lo que pide es cambiar todas las ventas de productos compuestos por sus items que componen

create procedure ventaComponente
as
begin
	insert into Item_Factura (item_numero, item_sucursal, item_tipo, item_producto, item_cantidad, item_precio)
	select i.item_numero,
		i.item_sucursal,
		i.item_tipo,
		comp_producto,
		i.item_cantidad * comp_cantidad,
		prod_precio
	from Item_Factura i
	join Composicion on item_producto = comp_producto
	join Producto on comp_componente = prod_codigo

	delete from Item_Factura
	where item_producto in (select comp_producto from Composicion)
end
go

-- Otra cosa q quise probar

create proc stockComponente
as
begin
	declare @itemCompuesto char(8), @cantidad decimal(12,2)

	declare cComp cursor for -- Obtengo el stock de todos los productos con composicion
		select stoc_producto, SUM(stoc_cantidad) from STOCK
		where stoc_producto in (select comp_producto from Composicion)
		group by stoc_producto

	open cComp
	fetch cComp into @itemCompuesto, @cantidad

	while @@FETCH_STATUS = 0
	begin
		declare @componente char(8), @cantidadComponente decimal(12,2)

		declare cComponentes cursor for
			select comp_componente, comp_cantidad from Composicion where comp_producto = @itemCompuesto

		open cComponentes
		fetch cComponentes into @componente, @cantidadComponente

		while @@FETCH_STATUS = 0
		begin
			if exists (select 1 from STOCK where stoc_producto = @componente)
			begin
				update STOCK set stoc_cantidad = stoc_cantidad + (@cantidad*@cantidadComponente/count(*)) -- desconozco si es valido ese count ahi, pero la idea es repartir entre depositos sino subselect
				where stoc_producto = @componente
			end
			else
			begin
				print('Hay un componente que no esta cargado')
				rollback
			end
			fetch cComponentes into @componente, @cantidadComponente
		end

		close cComponentes
		deallocate cComponentes
		

		fetch cComp into @itemCompuesto, @cantidad
	end

	close cComp
	deallocate cComp
end
go