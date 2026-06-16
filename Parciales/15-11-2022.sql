/*
    1. Realizar una consulta SQL que permita saber los clientes que compraron todos los rubros disponibles del sistema en el 2012.

    De estos clientes mostrar, siempre para el 2012:

    1. El código del cliente
    2. Código de producto que en cantidades más compró.
    3. El nombre del producto del punto 2.
    4. Cantidad de productos distintos comprados por el cliente.
    5. Cantidad de productos con composición comprados por el cliente.

    El resultado deberá ser ordenado por razón social del cliente alfabéticamente primero y luego, los clientes que compraron entre un 20% y 30% del total facturado en el 2012 primero, luego, los restantes.

    **Nota**: No se permiten select en el from, es decir, select ... from (select ...) as T,...
*/

select fact_cliente,
    (select top 1 item_producto from Item_Factura
        join Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo and YEAR(fact_fecha) = 2012 and fact_cliente = f1.fact_cliente
        group by item_producto
        order by sum(item_cantidad) desc) prod_masCompro,
    (select top 1 prod_detalle from Item_Factura
        join Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo and YEAR(fact_fecha) = 2012 and fact_cliente = f1.fact_cliente
        join Producto on prod_codigo = item_producto
        group by item_producto, prod_detalle
        order by sum(item_cantidad) desc) nombre_prod,
    count(distinct item_producto) cant_prod,
    (select isnull(count(distinct comp_producto), 0) from Item_Factura
        join Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo and YEAR(fact_fecha) = 2012 and fact_cliente = f1.fact_cliente
        join Composicion on item_producto = comp_producto) cant_prodComposicion
from Factura f1
join Item_Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo
join Producto on prod_codigo = item_producto
join Cliente on fact_cliente = clie_codigo
where YEAR(fact_fecha) = 2012
GROUP BY fact_cliente, clie_razon_social
having count(distinct prod_rubro) = (select count(*) from Rubro)
order by (case when sum(item_cantidad*item_precio) BETWEEN (select sum(fact_total) from Factura where YEAR(fact_fecha) = 2012) * 0.2 and
                (select sum(fact_total) from Factura where YEAR(fact_fecha) = 2012) * 0.3 then 1 else 2 end) asc, clie_razon_social
go

/*
    2. Implementar una regla de negocio en línea que al realizar una venta (SOLO INSERCION) permita componer los productos descompuestos, es decir, si se guardan en la factura 2 hamb. 2 papas 2 gaseosas se deberá guardar en la factura 2 (DOS) COMBO1. Si 1 combo1 equivale a: 1 hamb. 1 papa y 1 gaseosa.

    **Nota**: Considerar que cada vez que se guardan los items, se mandan todos los productos de ese item a la vez, y no de manera parcial.
*/

create trigger ComponerCombo on Item_factura
after insert
AS
BEGIN
    declare @tipo char(1), @sucursal char(4), @itemNum char(8)

    declare cFact cursor FOR
        select item_tipo, item_numero, item_sucursal from inserted

    open cFact
    fetch cFact into @tipo, @itemNum, @sucursal

    while @@FETCH_STATUS = 0
    BEGIN
        declare @prodCompuesto char(8)

        declare cProdCompuesto cursor for
            select comp_producto from inserted
            join Composicion c1 on comp_componente = item_producto
            where item_numero = @itemNum and item_sucursal = @sucursal and item_tipo = @tipo
                and item_cantidad >= comp_cantidad
            GROUP BY comp_producto
            having count(*) = (select count(*) from Composicion where comp_producto = c1.comp_producto)

        open cProdCompuesto
        fetch cProdCompuesto into @prodCompuesto
        
        while @@FETCH_STATUS = 0
        BEGIN
            declare @cantCombo decimal(12,2) = (select top 1 item_cantidad/comp_cantidad from inserted
                                                join Composicion on item_producto = comp_componente and comp_producto = @prodCompuesto
                                                where item_numero = @itemNum and item_sucursal = @sucursal and item_tipo = @tipo
                                                order by 1 asc)
            
            declare @precio decimal(12,2) = (select prod_precio from Producto where prod_codigo = @prodCompuesto)
            
            insert into Item_Factura (item_numero, item_sucursal, item_tipo, item_producto, item_cantidad, item_precio)
            values (@itemNum, @sucursal, @tipo, @prodCompuesto, @cantCombo, @precio)

            -- Actualizo lo que saque
            update i set item_cantidad = item_cantidad - (@cantCombo * (select comp_cantidad from Composicion where comp_componente = item_producto))
            from Item_Factura i
            join Composicion on item_producto = comp_componente and comp_producto = @prodCompuesto
            where item_numero = @itemNum and item_sucursal = @sucursal and item_tipo = @tipo

            -- Elimino los que ya no tienen cantidad
            delete from Item_Factura
            where item_numero = @itemNum and item_sucursal = @sucursal and item_tipo = @tipo and item_cantidad = 0

            fetch cProdCompuesto into @prodCompuesto
        END

        close cProdCompuesto
        deallocate cProdCompuesto

        fetch cFact into @tipo, @itemNum, @sucursal
    END

    close cFact
    deallocate cFact
END
GO