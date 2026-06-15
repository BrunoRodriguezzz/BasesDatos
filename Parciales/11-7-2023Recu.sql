/*
    La empresa necesita recuperar ventas perdidas. Con el fin de lanzar una nueva campaña comercial, se pide una consulta SQL que retorne aquellos clientes cuyas ventas (considerar el fact_total) del año 2012 fueron inferiores al 25% del promedio de ventas de los productos vendidos entre los años 2011 y 2010.
    En base a lo solicitado, se requiere un listado con la siguiente información:

    1. Razón Social del Cliente
    2. Mostrar la leyenda "Cliente Recurrente" si dicho cliente realizó más de una compra en el 2012. En caso de que haya realizado sólo 1 compra, entonces mostrar la leyenda "Única Vez"
    3. Cantidad de productos totales vendidas en el 2012 para ese cliente
    4. Código de producto que mayor venta tuvo en el 2012 (en caso de existir más de 1, mostrar solamente el de menor código) para ese cliente

    **NOTA:** No se permite el uso de sub-selects en el FROM ni funciones definidas por el usuario para este punto.
*/

select clie_razon_social,
    (case when count(distinct fact_numero+fact_sucursal+fact_tipo) > 1 then 'CLIENTE RECURRENTE'
        else 'ÚNICA VEZ' end) leyenda,
    (select sum(item_cantidad) from Item_Factura -- No lo puedo hacer sin subconsulta porque no puedo joinear con Item_factura
        join Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo
            and YEAR(fact_fecha) = 2012 and fact_cliente = clie_codigo) cant_prod,
    (select top 1 item_producto from Item_Factura
        join Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo
            and YEAR(fact_fecha) = 2012 and fact_cliente = clie_codigo
        group by item_producto
        order by sum(item_cantidad*item_precio) desc, item_producto asc) prod
from Factura
join Cliente on clie_codigo = fact_cliente
where YEAR(fact_fecha) = 2012
group by clie_codigo, clie_razon_social
-- Si no pidiera usar el fact_total podría joinear con item fact y hacer la suma
having sum(fact_total) < (select (sum(item_cantidad*item_precio)/count(distinct item_producto)) from Item_Factura --promedio de ventas de los productos, no puede usar avg(sum())
                            join Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo
                            where YEAR(fact_fecha) = 2010 or YEAR(fact_fecha) = 2011)*0.25
go

/*
    2. Para estimar que STOCK se necesita comprar de cada producto, se toma como estimación las ventas de unidades promedio de los últimos 3 meses anteriores a una fecha. Se solicita que se guarde en una tabla (producto, cantidad a reponer) en función del criterio antes mencionado y el stock existente.
*/

-- las ventas de unidades promedio de los últimos 3 meses --> AVG(item_cantidad)? RARETE

create proc estimarReposicion(@fecha smalldatetime)
AS
BEGIN
    delete from Reposicion

    insert into Reposicion (repo_producto, repo_cantidad)
    select 
        item_producto,
        greatest(isnull((SUM(item_cantidad*item_producto)/3 - (select sum(stoc_cantidad) from STOCK where stoc_producto = prod_codigo)), 0)) 
    from Producto
    left join Item_Factura on item_producto = prod_codigo
    left join Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo and DATEDIFF(MONTH, fact_fecha, @fecha) <= 3
    GROUP BY item_producto
END
GO