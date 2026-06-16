/*
    Se solicita una estadística por Año y familia, para ello se deberá mostrar:
    Año, Código de familia, Detalle de familia, cantidad de facturas, cantidad de productos con composición vendidos, monto total vendido. Solo se deberán considerar las familias que tengan al menos un producto con composición y que se hayan vendido conjuntamente (en la misma factura) con otra familia distinta.

    NOTA: No se permite el uso de sub-selects en el FROM ni funciones definidas por el usuario para este punto.
*/

select YEAR(fact_fecha) año,
    fami_id cod_fami,
    fami_detalle detalle_fami,
    count(distinct fact_numero+fact_sucursal+fact_tipo) facturas,
    (select count(distinct comp_producto) from Item_Factura 
        join Producto on prod_codigo = item_producto and prod_familia = fami_id
        join Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo and YEAR(fact_fecha) = YEAR(f1.fact_fecha)
        join Composicion on comp_producto = item_producto) prod_composicion,
    sum(item_cantidad*item_precio) monto
from Factura f1
join Item_Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo
join Producto on prod_codigo = item_producto
join Familia on prod_familia = fami_id
where fami_id in (select distinct prod_familia from Producto join Composicion on prod_codigo = comp_producto) -- Si hago un join considero solo las que se vendieron
    and exists (select 1 from Item_Factura i1
                    join Producto p1 on i1.item_producto = p1.prod_codigo
                    join Item_Factura i2 on i1.item_numero = i2.item_numero and i2.item_sucursal = i1.item_sucursal and i1.item_tipo = i2.item_tipo
                    join Producto p2 on p2.prod_codigo = i2.item_producto
                    where p1.prod_familia = fami_id and p1.prod_familia <> p2.prod_familia)
GROUP BY YEAR(fact_fecha), fami_id, fami_detalle
go

-- Se puede resolver usando un group by

/*
    Se requiere realizar una verificación de los precios de los COMBOs, para ello se solicita que cree el o los objetos necesarios para realizar una operación que actualice que el precio de un producto compuesto (COMBO) es el 90% de la suma de los precios de sus componentes por las cantidades que los componen. Se debe considerar que un producto compuesto puede estar compuesto por otros productos compuestos.
*/

create proc verificarCombo
AS
BEGIN
    UPDATE Producto set prod_precio = dbo.precioCombo(prod_codigo) * 0.9
    where prod_codigo in (select distinct comp_producto from Composicion) 
END
GO

CREATE FUNCTION precioCombo(@prod char(8))
returns decimal(12,2)
AS
BEGIN
    IF EXISTS (select 1 from Composicion where comp_producto = @prod) -- Es un producto con composición
    BEGIN
        return (select SUM(dbo.precioCombo(comp_componente) * comp_cantidad) from Composicion where comp_producto = @prod)
    END

    return (select prod_precio from Producto WHERE prod_codigo = @prod) -- No tiene composicion devuelvo el precio
END
GO