/*
    1. Realizar una consulta SQL que permita saber si un cliente compró un producto en todos los meses del 2012.

    -- Según Gemini se refiere que Cliente compró un producto cada mes. Es decir que compro el mismo prod cada mes

    Además, mostrar para el 2012:
    1. El cliente
    2. La razón social del cliente
    3. El producto comprado --> Entiendo que se refiere al mas comprado
    4. El nombre del producto
    5. Cantidad de productos distintos comprados por el cliente.
    6. Cantidad de productos con composición comprados por el cliente.

    El resultado deberá ser ordenado poniendo primero aquellos clientes que compraron más de 10 productos distintos en el 2012.

    **Nota:** No se permiten select en el from, es decir, select ... from (select ...) as T,...  
*/

select  fact_cliente,
    clie_razon_social,
    item_producto,
    prod_detalle,
    count(distinct item_producto) prod_comprados,
    count(distinct comp_producto) prod_comp
from Factura f1
join Cliente on clie_codigo = fact_cliente
join Item_Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo
join Producto on item_producto = prod_codigo
left join Composicion on comp_producto = item_producto
where YEAR(fact_fecha) = 2012
group by fact_cliente, clie_razon_social, item_producto, prod_detalle
having count(distinct MONTH(fact_fecha)) = 12 -- Tiene los 12 meses
order by (case when count(distinct item_producto) >= 10 then 1 else 0 end) desc
GO

/*
    2. Implementar una regla de negocio de validación en línea que permita implementar una lógica de control de precios en las ventas. Se deberá poder seleccionar una lista de rubros y aquellos productos de los rubros que sean los seleccionados no podrán aumentar por mes más de un 2%. En caso que no se tenga referencia del mes anterior no validar dicha regla.
*/

-- Donde esta esa lista?? :(
-- No entiendo puntualmente que me pide si algo que me permita mantener la lista, validar precios o ambas.

create procedure controlarRubro (@rubro char(4)) -- Voy a suponer que no modifico la tabla rubro y que tengo una tabla adicional para esto
AS
BEGIN
    insert into RubrosControlados (rubro, vigenciaHasta)
    VALUES (@rubro, DATEADD(month, 1, GETDATE()))
END
GO

create trigger controlPrecioRubros on Item_factura
after insert
AS
BEGIN
    IF EXISTS (select 1 from inserted i
                join Producto p on i.item_producto = p.prod_codigo
                join RubrosControlados on prod_rubro = rubro and GETDATE() < vigenciaHasta
                where p.prod_precio * 1.02 < i.prod_precio) -- El techo
    BEGIN
        PRINT('ERROR: Se supero el precio limite')
        ROLLBACK
    END
END
GO
