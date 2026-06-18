/*
    1. Realizar una consulta SQL que muestre aquellos clientes que en 2 años consecutivos compraron.

    De estos clientes mostrar:

    i. El código de cliente.
    ii. El nombre del cliente.
    iii. El número de rubros que compró el cliente.
    iv. La cantidad de productos con composición que compró el cliente en el 2012.

    El resultado deberá ser ordenado por cantidad de facturas del cliente en toda la historia, de manera ascendente.

    **Nota**: No se permiten select en el from, es decir, select ... from (select ...) as T, ...
*/

select f1.fact_cliente,
    clie_razon_social,
    count(distinct prod_rubro) rubros,
    (select count(distinct comp_producto) from Factura
        join Item_Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo and YEAR(fact_fecha) = 2012
        join Composicion on comp_producto = item_producto
        where fact_cliente = f1.fact_cliente)
from Item_Factura i1
join Factura f1 on i1.item_numero = f1.fact_numero and i1.item_sucursal = f1.fact_sucursal and i1.item_tipo = f1.fact_tipo
join Factura f2 on f1.fact_cliente = f2.fact_cliente and f1.fact_fecha < f2.fact_fecha
join Producto on prod_codigo = i1.item_producto
join Cliente on clie_codigo = f1.fact_cliente
group by f1.fact_cliente, clie_razon_social
having count(distinct CAST(f2.fact_fecha as date)) >= 365 * 2 -- No se me ocurrio otra forma
order by count(distinct f1.fact_numero+f1.fact_sucursal+f1.fact_tipo) asc
GO

/*
    2. Implementar una regla de negocio para mantener siempre consistente (actualizada bajo cualquier circunstancia) una nueva tabla llamada PRODUCTOS_VENDIDOS. En esta tabla debe registrar el periodo (YYYYMM), el código de producto, el precio máximo de venta y las unidades vendidas. Toda esta información debe estar por periodo (YYYYMM).
*/

create trigger ProdVend on Item_factura
after insert -- Si es un insert es de hoy
AS
BEGIN
    declare @prod char(8)
    declare @cant decimal(12,2)
    declare @maxPrecio decimal(12,2)

    declare @año int = YEAR(GETDATE()), @mes int = MONTH(GETDATE())

    declare cProd cursor for
        select item_producto, MAX(item_precio), sum(item_cantidad) from inserted
        group by item_producto

    open cProd
    fetch cProd into @prod, @maxPrecio, @cant

    while @@FETCH_STATUS = 0
    BEGIN
        IF EXISTS (select 1 from PRODUCTOS_VENDIDOS where prodVendido = @prod and mes = @mes and año = @año)
        BEGIN
            update PRODUCTO_VENDIDOS set cantidad = cantidad + @cant, precio = GREATEST(precio, @maxPrecio)
            where prodVendido = @prod and mes = @mes and año = @año
        END
        ELSE
        BEGIN
            insert into PRODUCTO_VENDIDOS (prodVendido, mes, año, cantidad, precio)
            VALUES (@prod, @mes, @año, @cant, @maxPrecio)
        END

        fetch cProd into @prod, @maxPrecio, @cant
    END

    close cProd
    DEALLOCATE cProd
END
GO