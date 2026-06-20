/*
   1. Realizar una consulta SQL que muestre la siguiente información para los clientes que hayan comprado productos 
   en más de tres rubros diferentes en 2012 y que no compró en años impares.

   1. El número de fila.
   2. El código del cliente.
   3. El nombre del cliente.
   4. La cantidad total comprada por el cliente.
   5. La categoría en la que más compró en 2012. ??? Supondre q es rubro

	El resultado debe estar ordenado por la cantidad total comprada, de mayor a menor.

	**Nota**: No se permiten select en el from, es decir, select ... from (select ...) as T,...
*/

select ROW_NUMBER() over(order by sum(item_cantidad) desc) fila,
	fact_cliente,
	clie_razon_social,
	sum(item_cantidad) cant_comprada,
	(select top 1 prod_rubro from Factura
		join Item_Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo
		join Producto on  item_producto = prod_codigo
		where YEAR(fact_fecha) = 2012 and fact_cliente = f1.fact_cliente
		group by prod_rubro
		order by sum(item_cantidad) desc) rubro_mas_compro
from Factura f1
join Item_Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo
join Cliente on fact_cliente = clie_codigo
where fact_cliente in (select fact_cliente from Factura
						join Item_Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo
						join Producto on item_producto = prod_codigo
						where YEAR(fact_fecha) = 2012
						group by fact_cliente
						having count(distinct prod_rubro) > 3) -- Lo pongo fuera para no quedarme solo con prod de 2012
	and fact_cliente not in (select fact_cliente from Factura
								where YEAR(fact_fecha)%2 <> 0) -- Lo mismo si lo pongo dentro estaría filtrando y perderia años
group by fact_cliente, clie_razon_social
order by sum(item_cantidad) desc
go

/*
   2. Implementar los objetos necesarios para registrar, en tiempo real, los 10 productos más vendidos por año en una tabla específica. 
   Esta tabla debe contener exclusivamente la información requerida, sin incluir filas adicionales.
   Los "más vendidos" se definen como aquellos productos con el mayor número de unidades vendidas.
*/

-- En tiempo real --> Trigger sobre Item_factura
-- La estructura debería ser algo como (año, puesto, prod)

create trigger EjTSQL on Item_factura -- Entiendo que son de un mismo año, sino serían unos pequeños ajustes
after insert
as
begin
	delete from RankingProd
	where año = (select top 1 YEAR(fact_fecha) from inserted
					join Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo)

	insert into RankingProd (año, puesto, prod)
	select top 10 YEAR(fact_fecha),
		ROW_NUMBER() over(order by sum(item_cantidad) + (select sum(item_cantidad) from Item_Factura where item_producto = i.item_producto)),
		i.item_producto
	from inserted i
	join Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo
	group by item_producto, YEAR(fact_fecha)
	order by sum(item_cantidad) + (select sum(item_cantidad) from Item_Factura where item_producto = i.item_producto)
end
go

-- No se si after insert ya carga en item