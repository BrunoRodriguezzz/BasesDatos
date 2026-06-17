/*
    1. Realizar una consulta SQL que muestre aquellos productos que tengan 3 componentes a nivel producto y cuyos componentes tengan 2 rubros distintos.

    De estos productos mostrar:

    i. El código de producto.
    ii. El nombre del producto.
    iii. La cantidad de veces que fueron vendidos sus componentes en el 2012. --> Sería la cant de facturas = cant veces
    iv. Monto total vendido del producto.

    El resultado deberá ser ordenado por cantidad de facturas del 2012 en las cuales se vendieron los componentes.

    **Nota**: No se permiten select en el from, es decir, select ... from (select ...) as T, ...
*/

select p1.prod_codigo, 
    p1.prod_detalle,
    isnull(count(distinct fact_tipo+fact_numero+fact_sucursal), 0) cantVentasComp2012,
    (select sum(item_cantidad*item_precio) from Item_Factura where item_producto = p1.prod_codigo) montoTot
from Producto p1
join Composicion on comp_producto = p1.prod_codigo --> Me arruina los JOINS con Item_factura, por lo que tengo que usar subselects si quiero sum
join Producto p2 on comp_componente = p2.prod_codigo
left join Item_Factura on item_producto = p2.prod_codigo
left join Factura ON item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo and YEAR(fact_fecha) = 2012
group by p1.prod_codigo, p1.prod_detalle
having count(distinct comp_componente) = 3 and count(distinct p2.prod_rubro) >= 2
order by cantVentasComp2012 desc -- No veo la diferencia
GO

/*
    2. Implementar una regla de negocio en línea donde se valide que nunca un producto compuesto pueda estar compuesto por componentes de rubros distintos a él.
*/

-- Evaluar de forma recursiva? Entiendo que no, cuando lo piden suele ser explicito

create trigger noDistRubrosComp on Composicion
after insert, UPDATE
AS
BEGIN
    if exists (select 1 from inserted
                join Producto p1 on comp_componente = p1.prod_codigo
                join Producto p2 on comp_producto = p2.prod_codigo
                where p1.prod_rubro <> p2.prod_rubro)
    BEGIN
        ROLLBACK
    END
END
GO
-- Falta revisar la tabla de de Producto, puede cambiar el rubroy se arruina

-- Version recursiva --> Practicar

create trigger noDistRubrosCompRecursivo on Composicion
after INSERT, UPDATE
AS
BEGIN
    IF EXISTS (select 1 from inserted
                join Producto on comp_producto = prod_rubro 
                where dbo.distRubro(comp_producto, prod_rubro))
    BEGIN
        ROLLBACK
    END
END
GO

-- Si retorna 1 es que encontro rubros distintos
create function distRubro(@prod char(8), @rubro char(3))
returns BIT
AS
BEGIN
    if (select prod_rubro from Producto where prod_codigo = @prod) <> @rubro
        return 1

    IF EXISTS (select 1 from Composicion where comp_producto = @prod) -- Tiene compo
    BEGIN
        IF EXISTS (select 1 from Composicion where comp_producto = @prod and
                    dbo.distRubro(comp_producto, @rubro) = 1)
            return 1
    END

    return 0
END
GO