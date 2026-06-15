/*
    Realizar una consulta SQL que retorne para los 10 clientes que más compraron en el 2012 y que fueron atendidos por más de 3 vendedores distintos:

    - Apellido y Nombre del Cliente. --> El unico que tiene es vendedor, supongo que será razón social
    - Cantidad de Productos distintos comprados en el 2012.
    - Cantidad de unidades compradas dentro del primer semestre del 2012.

    El resultado deberá mostrar ordenado la cantidad de ventas descendente del 2012 de cada cliente, en caso de igualdad de ventas, ordenar por código de cliente.

    **NOTA:** No se permite el uso de sub-selects en el FROM ni funciones definidas por el usuario para este punto.
*/

-- Cantidad de ventas es lo mismo que "mas compraron"? Entiendo que no mas compraron --> monto y cant es un count de distintas facturas

select clie_razon_social,
    count(distinct item_producto) dist_prod,
    sum(case when MONTH(fact_fecha) <= 6 then item_cantidad
                else 0 end) cant_prod
from Factura
join Cliente on fact_cliente = clie_codigo
join Item_Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo
where YEAR(fact_fecha) = 2012 and fact_cliente in (select top 10 fact_cliente from Factura -- Lo hago en una subconsulta, para que no me arruine el orden
                                                    where YEAR(fact_fecha) = 2012
                                                    group by fact_cliente
                                                    having count(distinct fact_vendedor) > 3
                                                    order by sum(fact_total) desc)
group by clie_razon_social, clie_codigo
order by count(distinct fact_numero+fact_sucursal+ fact_tipo) desc, clie_codigo desc
go

/*
    Realizar un stored procedure que reciba un código de producto y una fecha y devuelva la mayor cantidad de días consecutivos a partir de esa fecha que el producto tuvo al menos la venta de una unidad en el día, el sistema de ventas on line está habilitado 24-7 por lo que se deben evaluar todos los días incluyendo domingos y feriados.
*/

create PROCEDURE cantVentConsecutivas(@prod char(8), @fecha smalldatetime, @cont int OUTPUT)
AS
BEGIN
    set @cont = 0

    while exists (select 1 from Item_Factura 
                    JOIN Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo
                    where item_producto = @prod and fact_fecha = @fecha)
    BEGIN
        set @cont = @cont + 1
        set @fecha = DATEADD(DAY, 1, @fecha)
    END

    return @cont
END
GO