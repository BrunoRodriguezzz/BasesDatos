/*
    SQL

    Sabiendo que si un producto no es vendido en un depósito determinado entonces no posee registros en él.
    Se requiere una consulta sql que para todos los productos que se quedaron sin stock en un depósito (cantidad 0 o nula) y poseen un stock mayor al punto de reposición en otro depósito devuelva:

    1- Código de producto
    2- Detalle del producto
    3- Domicilio del depósito sin stock
    4- Cantidad de depósitos con un stock superior al punto de reposición

    La consulta debe ser ordenada por el código de producto.

    **NOTA:** No se permite el uso de sub-selects en el FROM.
*/

select prod_codigo,
    prod_detalle,
    depo_domicilio,
    count(distinct s2.stoc_deposito) depositos
from STOCK s1
join Producto on prod_codigo = s1.stoc_producto
join DEPOSITO on depo_codigo = s1.stoc_deposito
join STOCK s2 on s1.stoc_producto = s2.stoc_producto and isnull(s2.stoc_cantidad, 0) > s2.stoc_punto_reposicion
where isnull(s1.stoc_cantidad, 0) = 0
group by prod_codigo, prod_detalle, s1.stoc_deposito, depo_domicilio
order by prod_codigo
go

/*
    TSQL

    Dado el contexto inflacionario se tiene que aplicar un control en el cual nunca se permita vender un producto a un precio que no esté entre 0%-5% del precio de venta del producto el mes anterior, ni tampoco que esté en más de un 50% el precio del mismo producto que hace 12 meses atrás. Aquellos productos nuevos, o que no tuvieron ventas en meses anteriores no debe considerar esta regla ya que no hay precio de referencia.
*/

-- Me propuse a intentar resolverlo en una sola consulta pero bueno
create trigger TSQL on Item_factura
after INSERT
AS
BEGIN
    IF EXISTS (select 1 from inserted i
                join Factura f1 on item_numero = fact_numero and item_sucursal = fact_numero and item_tipo = fact_tipo
                where (case when (select MAX(item_precio) from Item_Factura
                                    join Factura on item_numero = fact_numero and item_sucursal = fact_numero and item_tipo = fact_tipo
                                        and YEAR(f1.fact_fecha) = YEAR(fact_fecha) and MONTH(fact_fecha) = MONTH(f1.fact_fecha) - 1
                                    where item_producto = i.item_producto) is null then i.item_precio
                            else (select MAX(item_precio) from Item_Factura
                                join Factura on item_numero = fact_numero and item_sucursal = fact_numero and item_tipo = fact_tipo
                                    and YEAR(f1.fact_fecha) = YEAR(fact_fecha) and MONTH(fact_fecha) = MONTH(f1.fact_fecha) - 1
                                where item_producto = i.item_producto) end) BETWEEN i.item_precio and i.item_precio * 1.05  -- Ya se que esta al revés pero como lo puedo hacer sino?
                    and item_precio > isnull((select MAX(item_precio) from Item_Factura
                                        join Factura on item_numero = fact_numero and item_sucursal = fact_numero and item_tipo = fact_tipo
                                            and YEAR(f1.fact_fecha) = YEAR(fact_fecha) - 1
                                        where item_producto = i.item_producto), 9999999999) * 1.50) -- Lo mismo no se como podría hacerlo sin hardcodear ese num grande
    BEGIN
        ROLLBACK
    END
END
go

CREATE TRIGGER trg_ControlInflacion_Ventas ON Item_Factura
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Factura f_new ON i.item_numero = f_new.fact_numero 
                          AND i.item_sucursal = f_new.fact_sucursal 
                          AND i.item_tipo = f_new.fact_tipo
        WHERE 
            -- Violación 1: Existe venta el mes pasado Y el nuevo precio NO está entre +0% y +5%
            EXISTS (
                SELECT 1
                FROM Item_Factura i_ant
                JOIN Factura f_ant ON i_ant.item_numero = f_ant.fact_numero 
                                  AND i_ant.item_sucursal = f_ant.fact_sucursal 
                                  AND i_ant.item_tipo = f_ant.fact_tipo
                WHERE i_ant.item_producto = i.item_producto
                  AND DATEDIFF(month, f_ant.fact_fecha, f_new.fact_fecha) = 1
                -- HAVING evalúa solo si se encontraron registros en el WHERE
                HAVING i.item_precio NOT BETWEEN MAX(i_ant.item_precio) AND (MAX(i_ant.item_precio) * 1.05)
            )
            OR
            -- Violación 2: Existe venta hace 12 meses exactos Y el nuevo precio superó el 50%
            EXISTS (
                SELECT 1
                FROM Item_Factura i_ant12
                JOIN Factura f_ant12 ON i_ant12.item_numero = f_ant12.fact_numero 
                                    AND i_ant12.item_sucursal = f_ant12.fact_sucursal 
                                    AND i_ant12.item_tipo = f_ant12.fact_tipo
                WHERE i_ant12.item_producto = i.item_producto
                  AND DATEDIFF(month, f_ant12.fact_fecha, f_new.fact_fecha) = 12
                HAVING i.item_precio > (MAX(i_ant12.item_precio) * 1.50)
            )
    )
    BEGIN
        RAISERROR('ERROR: El precio supera los límites inflacionarios permitidos.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END
GO