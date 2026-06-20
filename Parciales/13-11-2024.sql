/*
	1. Realizar una consulta SQL que muestre, para los clientes que compraron únicamente en años pares, la siguiente información:
	   1. El número de fila.
	   2. El código del cliente.
	   3. El nombre del producto más comprado por el cliente.
	   4. La cantidad total comprada por el cliente en el último año.

	El resultado debe estar ordenado en función de la cantidad máxima comprada por cliente, de mayor a menor.

	**Nota**: No se permiten select en el from, es decir, select ... from (select ...) as T,...
*/

select ROW_NUMBER() over(order by MAX(item_cantidad) desc) linea,
	clie_codigo,
	(select top 1 prod_detalle from Factura f1
		join Item_Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo 
			and fact_cliente = clie_codigo
		join Producto on prod_codigo = item_producto
		group by item_producto, prod_detalle
		order by sum(item_cantidad) desc) prod_mas_comprado,
	(select sum(item_cantidad) from Factura 
		join Item_Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo 
			and fact_cliente = clie_codigo and YEAR(fact_fecha) = (select YEAR(max(fact_fecha)) from Factura)) cant
from Cliente
join Factura on clie_codigo = fact_cliente
join Item_Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo 
where clie_codigo not in (select fact_cliente from Factura where YEAR(fact_fecha)%2 <> 0)
group by clie_codigo
order by MAX(item_cantidad) desc
go

/*
	2. Implementar un sistema de auditoría para registrar cada operación realizada en la tabla "cliente". 
	El sistema deberá almacenar, como mínimo, los valores (campos afectados), el tipo de operación a realizar, 
	y la fecha y hora de ejecución. Solo se permitirán operaciones individuales (no masivas) sobre los registros, 
	pero el intento de realizar operaciones masivas deberá ser registrado en el sistema de auditoría.
*/

create trigger EJTSQL on Cliente
after insert, update, delete
as
begin
	if (select count(*) from inserted) > 1 or (select count(*) from deleted) > 1
	begin
		insert into RegistroCliente (operacion, fechaHora)
		values ('OP_MASIVA', GETDATE())
		rollback
	end

	insert into RegistroCliente (operacion, clie_codigo, clie_razon_social, clie_telefono, clie_domicilio, clie_limite_credito, clie_vendedor, fechaHora)
	select 
		'INSERCIÓN',
		clie_codigo,
		clie_razon_social,
		clie_telefono,
		clie_domicilio,
		clie_limite_credito,
		clie_vendedor,
		GETDATE()
	from inserted

	insert into RegistroCliente (operacion, clie_codigo, clie_razon_social, clie_telefono, clie_domicilio, clie_limite_credito, clie_vendedor, fechaHora)
	select 
		'ELIMINACIÓN',
		clie_codigo,
		clie_razon_social,
		clie_telefono,
		clie_domicilio,
		clie_limite_credito,
		clie_vendedor,
		GETDATE()
	from deleted
end
go

-- PROPUESTA DE PADRE GEMINI

CREATE TRIGGER TR_Auditoria_Cliente ON Cliente
INSTEAD OF INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @cantInserted INT = (SELECT COUNT(*) FROM inserted);
    DECLARE @cantDeleted INT = (SELECT COUNT(*) FROM deleted);

    -- 1. Control de Operaciones Masivas
    IF @cantInserted > 1 OR @cantDeleted > 1
    BEGIN
        INSERT INTO RegistroCliente (operacion, fechaHora)
        VALUES ('OP_MASIVA_RECHAZADA', GETDATE());
        
        PRINT 'Operación cancelada: No se permiten operaciones masivas.';
        RETURN; -- Interrumpe y NO ejecuta la operación original
    END

    -- 2. Detectar y procesar INSERCIÓN (Hay inserted, no hay deleted)
    IF @cantInserted = 1 AND @cantDeleted = 0
    BEGIN
        INSERT INTO RegistroCliente (operacion, clie_codigo, clie_razon_social, fechaHora)
        SELECT 'INSERCIÓN', clie_codigo, clie_razon_social, GETDATE() FROM inserted;
        
        -- Como es INSTEAD OF, debemos ejecutar la inserción real manualmente
        INSERT INTO Cliente (clie_codigo, clie_razon_social, clie_telefono, clie_domicilio, clie_limite_credito, clie_vendedor)
        SELECT clie_codigo, clie_razon_social, clie_telefono, clie_domicilio, clie_limite_credito, clie_vendedor FROM inserted;
    END

    -- 3. Detectar y procesar ELIMINACIÓN (Hay deleted, no hay inserted)
    ELSE IF @cantInserted = 0 AND @cantDeleted = 1
    BEGIN
        INSERT INTO RegistroCliente (operacion, clie_codigo, clie_razon_social, fechaHora)
        SELECT 'ELIMINACIÓN', clie_codigo, clie_razon_social, GETDATE() FROM deleted;
        
        DELETE FROM Cliente WHERE clie_codigo IN (SELECT clie_codigo FROM deleted);
    END

    -- 4. Detectar y procesar ACTUALIZACIÓN (Hay ambas)
    ELSE IF @cantInserted = 1 AND @cantDeleted = 1
    BEGIN
        INSERT INTO RegistroCliente (operacion, clie_codigo, clie_razon_social, fechaHora)
        SELECT 'ACTUALIZACIÓN', clie_codigo, clie_razon_social, GETDATE() FROM inserted;
        
        UPDATE Cliente
        SET clie_razon_social = i.clie_razon_social,
            clie_telefono = i.clie_telefono,
            clie_domicilio = i.clie_domicilio,
            clie_limite_credito = i.clie_limite_credito,
            clie_vendedor = i.clie_vendedor
        FROM inserted i
        WHERE Cliente.clie_codigo = i.clie_codigo;
    END
END
GO