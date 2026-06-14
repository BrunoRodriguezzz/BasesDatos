/*
    1. Realizar una consulta SQL que retorne para todas las zonas que tengan 3 (tres) o más depósitos.
    - Detalle Zona
    - Cantidad de Depósitos x Zona
    - Cantidad de Productos distintos compuestos en sus depósitos --> Entiendo que productos compuestos no componentes
    - Producto mas vendido en el año 2012 que tenga stock en al menos uno de sus depósitos.
    - Mejor encargado perteneciente a esa zona (El que mas vendió en la historia).

    El resultado deberá ser ordenado por monto total vendido del encargado descendiente.

    **NOTA**: No se permite el uso de sub-selects en el FROM ni funciones definidas por el usuario para este punto.
*/

select zona_detalle, 
    count(distinct depo_codigo) depositos, 
    count(distinct comp_producto) prod_composicion,
    (select top 1 item_producto from Item_Factura
        join Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo and YEAR(fact_fecha) = 2012 
        where item_producto in (select distinct stoc_producto from STOCK join DEPOSITO on stoc_deposito = depo_codigo and depo_zona = zona_codigo)
        group by item_producto
        order by sum(item_cantidad*item_precio) desc) producto2012,
    (select top 1 empl_codigo from Empleado
        join Factura on fact_vendedor = empl_codigo
        where empl_codigo in (select distinct depo_encargado from DEPOSITO where depo_zona = zona_codigo)
        group by empl_codigo
        order by sum(fact_total) desc) encargado
from Zona
JOIN DEPOSITO on depo_zona = zona_codigo
LEFT JOIN STOCK on depo_codigo = stoc_deposito
LEFT JOIN Composicion on stoc_producto = comp_producto
group by zona_codigo, zona_detalle
HAVING count(distinct depo_codigo) >= 3
ORDER BY (select top 1 sum(fact_total) from Empleado
            join Factura on fact_vendedor = empl_codigo
            where empl_codigo in (select distinct depo_encargado from DEPOSITO where depo_zona = zona_codigo)
            group by empl_codigo
            order by sum(fact_total) desc)
GO

/*
    2. Actualmente el campo fact_vendedor representa al empleado que vendió la factura. Implementar el/los objetos necesarios para respetar la integridad referencial de dicho campo suponiendo que no existe una foreign key entre ambos.

    **NOTA**: No se puede usar una foreign key para el ejercicio, deberá buscar otro método.
*/

-- Entiendo que lo que debo hacer es chequear que no sea null y validar que exista

CREATE TRIGGER EJ2 on Factura
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (select 1 from inserted where fact_vendedor is NULL)
    BEGIN
        RAISERROR('La factura requiere un vendedor', 16, 1)
        ROLLBACK TRANSACTION
    END

    IF EXISTS (select 1 from inserted where fact_vendedor not in (select distinct empl_codigo from Empleado))
    BEGIN
        RAISERROR('El vendedor ingresado no existe', 16, 1)
        ROLLBACK TRANSACTION
    END
END
GO