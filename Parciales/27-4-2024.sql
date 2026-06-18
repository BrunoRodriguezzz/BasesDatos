/*
    1. Diseñar una consulta SQL que identifique a los vendedores cuya suma de ventas durante los últimos dos meses consecutivos ha sido inferior a la suma de ventas en los mismos dos meses consecutivos del año anterior.

    1. El número de fila (por la cantidad de facturas emitidas). No entiendo que pide aca
    2. El nombre del vendedor.
    3. La cantidad de empleados a cargo de cada vendedor.
    4. La cantidad de clientes a los que vendió en total. En esos dos meses? entiendo que como dice TOTAL es el historico

    El resultado debe estar ordenado en forma descendente según el monto total de ventas del vendedor (de mayor a menor).

    **Nota**: No se permiten select en el from, es decir, select ... from (select ...) as T, ... Ni WITH, ni tablas temporales.
*/

select e1.empl_nombre,
    isnull(count(distinct e2.empl_codigo), 0) empleados,
    count(distinct f1.fact_cliente) clientes 
from Factura f1
join Empleado e1 on fact_vendedor = e1.empl_codigo
left join Empleado e2 on fact_vendedor = e2.empl_jefe
GROUP BY fact_vendedor, e1.empl_nombre
having (select sum(fact_total) from Factura f1
        where DATEDIFF(month, f1.fact_fecha, (select MAX(fact_fecha) from Factura f2 where f2.fact_vendedor = f1.fact_vendedor)) <= 1) 
            < (select sum(f3.fact_total) from Factura f3
                            where f1.fact_vendedor = f3.fact_vendedor
                                and DATEDIFF(month, f3.fact_fecha, (select MAX(fact_fecha) from Factura f2 where f2.fact_vendedor = f1.fact_vendedor)) 
                                        BETWEEN 12 and 13) -- Mismos dos meses, between cuenta los extremos?
order by (select sum(fact_total) from Factura where fact_vendedor = f1.fact_vendedor) desc
go

/*
    2. Descripción del problema:

    Se requiere diseñar e implementar los objetos necesarios para crear una regla que detecte inconsistencias en las ventas en línea. En caso de detectar una inconsistencia, deberá registrarse el detalle correspondiente en una estructura adicional. Por el contrario, si no se encuentra ninguna inconsistencia, se deberá registrar que la factura ha sido validada.

    Inconsistencias a considerar:

    1. Que el valor de fact_total no coincida con la suma de los precios multiplicados por las cantidades de los artículos.
    2. Que se genere una factura con una fecha anterior al día actual.
    3. Que se intente eliminar algún registro de una venta. --> Factura o item? Para simplificar voy a asumir que es item, la idea es mas o menos la misma
*/

create trigger TSQL on Item_factura
after insert, update, DELETE
AS
BEGIN
    IF EXISTS (select 1 from inserted i -- REGLA 1
                group by item_numero, item_tipo, item_sucursal
                having sum(item_precio*item_cantidad) <> (select fact_total from Factura
                                                               where i.item_numero = fact_numero and i.item_sucursal = fact_sucursal and i.item_tipo = fact_tipo))
    BEGIN
        insert into RegistroVenta (fecha, detalle)
        VALUES (GETDATE(), 'No se insertaron valores, debido que los totales no coincidian')

        ROLLBACK
    END

    else if exists (select 1 from inserted i -- REGLA 2
                where exists (select 1 from Factura where i.item_numero = fact_numero and i.item_sucursal = fact_sucursal and i.item_tipo = fact_tipo
                                and DATEDIFF(day, fact_fecha, GETDATE()) > 0))
    BEGIN
        insert into RegistroVenta (fecha, detalle)
        VALUES (GETDATE(), 'No se insertaron valores, debido que la fecha era antigua')

        ROLLBACK
    END

    else IF EXISTS (select 1 from deleted d -- REGLA 3
                left join inserted i on i.item_numero = d.item_numero and i.item_sucursal = d.item_sucursal and i.item_tipo = d.item_tipo
                    and i.item_producto = d.item_tipo
                where i.item_producto is null) -- Esta en deleted pero no en inserted -> Se borro, no se actualizo
    BEGIN
        insert into RegistroVenta (fecha, detalle)
        VALUES (GETDATE(), 'Se estan borrando valores de item factura')

        ROLLBACK
    END
    ELSE
    BEGIN
        insert into RegistroVenta (fecha, detalle)
        VALUES (GETDATE(), 'Factura validadas')
    END
END
GO