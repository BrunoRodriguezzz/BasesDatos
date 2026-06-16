/*
    1. Realizar una consulta SQL que retorne la cantidad total de clientes que cumplen con las siguientes reglas.

    **Reglas:**
    i. Tener compras en años pares
    ii. Haber comprado en cantidades del último año de compra un 10 % más que en su antelúltimo año de compra. 
    iii. Tener más de 10 productos distintos comprados en el último año de compra

    Solamente mostrar resultados si la cantidad total de clientes es mayor a 10.

    **Nota:** No se permiten select en el from, es decir, select ... from (select ...) as T,...
*/

-- Regla 1
select fact_cliente from Factura
where YEAR(fact_fecha)%2 = 0 

-- Regla 2 y 3
select fact_cliente from Factura f1
join Item_Factura on fact_numero = item_numero and fact_sucursal = item_sucursal and fact_tipo = item_tipo
where YEAR(fact_fecha) = (select top 1 YEAR(fact_fecha) from Factura
                            where f1.fact_cliente = fact_cliente
                            order by YEAR(fact_fecha) desc)
group by fact_cliente, YEAR(fact_fecha)
having sum(item_cantidad) > (select isnull(sum(item_cantidad), 0) from Factura
                            join Item_Factura on fact_numero = item_numero and fact_sucursal = item_sucursal and fact_tipo = item_tipo
                            where f1.fact_cliente = fact_cliente and YEAR(fact_fecha) = YEAR(f1.fact_fecha) - 1) * 1.1
            and count(distinct item_producto) > 10

-- Ejercicio 
select (case when count(distinct fact_cliente) > 10 then count(distinct fact_cliente)
                else null end) from Factura
where YEAR(fact_fecha)%2 = 0 
    and fact_cliente in (select fact_cliente from Factura f1
                            join Item_Factura on fact_numero = item_numero and fact_sucursal = item_sucursal and fact_tipo = item_tipo
                            where YEAR(fact_fecha) = (select top 1 YEAR(fact_fecha) from Factura
                                                        where f1.fact_cliente = fact_cliente
                                                        order by YEAR(fact_fecha) desc)
                            group by fact_cliente, YEAR(fact_fecha)
                            having sum(item_cantidad) > (select isnull(sum(item_cantidad), 0) from Factura
                                                        join Item_Factura on fact_numero = item_numero and fact_sucursal = item_sucursal and fact_tipo = item_tipo
                                                        where f1.fact_cliente = fact_cliente and YEAR(fact_fecha) = YEAR(f1.fact_fecha) - 1) * 1.1
                                        and count(distinct item_producto) > 10)
go

/*
    2. Implementar el/los objetos de base de datos necesarios para tener el historial de modificaciones de la tabla familia. Luego, presente un objeto de base de datos que dado una fecha [@fecha smalldatetime] se pueda saber qué valor tenía la tabla familia en esa @fecha.

    **Nota:** Se entiende por historial de modificaciones a una estructura que permita conocer los valores de los atributos que tenía la tabla familia a una fecha dada.
*/

-- Voy a suponer que existe una tabla que COPIA los valores de la tabla familia ante una modificacion PK FECHA y FAMI_ID

create trigger HistorialFami on Familia
after update, insert, delete
AS
BEGIN
    declare @fecha smalldatetime = GETDATE()
    declare @famiID char(3)
    declare @famiDetalle char(50)

    declare cFami cursor FOR
        select fami_id, fami_detalle from Familia

    open cFami
    fetch cFami into @famiID, @famiDetalle

    while @@FETCH_STATUS = 0
    BEGIN
        insert into HistorialFamilia (hist_famiFecha, hist_famiID, hist_famiDetalle)
        VALUE @fecha, @famiID, @famiDetalle

        fetch cFami into @famiID, @famiDetalle
    END

    close cFami
    deallocate cFami
END
go

create FUNCTION verHistorialFamilia(@fecha smalldatetime)
returns TABLE
AS
BEGIN
    return (select * from HistorialFamilia where hist_famiFecha = @fecha)
END