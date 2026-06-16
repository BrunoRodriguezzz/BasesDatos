/*
    1. Sabiendo que si un producto no es vendido en un depósito determinado entonces no posee registros en él.
    Se requiere una consulta SQL que para todos los productos que se quedaron sin stock en un depósito (cantidad 0 o nula) y poseen un stock mayor al punto de reposición en otro depósito devuelva:

    1. Código de producto
    2. Detalle del producto
    3. Domicilio del depósito sin stock
    4. Cantidad de depósitos con un stock superior al punto de reposición

    La consulta debe ser ordenada por el código de producto.
    **NOTA**: No se permite el uso de sub-selects en el FROM.
*/

select prod_codigo,
    prod_detalle,
    depo_domicilio,
    (select count(stoc_deposito) from STOCK 
        where stoc_producto = prod_codigo and stoc_cantidad > stoc_punto_reposicion) cant
from STOCK
join Producto on stoc_producto = prod_codigo
join DEPOSITO on stoc_deposito = depo_codigo
where isnull(stoc_cantidad, 0) = 0 and exists (select 1 from STOCK 
                                        where stoc_producto = prod_codigo and stoc_cantidad > stoc_punto_reposicion)
order by prod_codigo
GO

/*
    2. Realizar un procedimiento que reciba un código de producto y una fecha y devuelva la mayor cantidad de días consecutivos a partir de esa fecha que el producto tuvo al menos la venta de una unidad en el día, el sistema de ventas on line está habilitado 24-7 por lo que se deben evaluar todos los días incluyendo domingos y feriados.
*/

create procedure diasConsecutivos(@prod char(8), @fecha DATE, @cont int output)
AS
BEGIN
    set @cont = 0

    while exists (select 1 from Item_Factura
                    join Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo
                    where item_producto = @prod and CAST(fact_fecha as date) = @fecha)
    BEGIN
        set @cont = @cont + 1
        set @fecha = DATEADD(DAY, 1, @fecha)
    END

    return @cont
END
GO