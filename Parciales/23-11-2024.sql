/*
	1. El objetivo es realizar una consulta SQL que identifique a los vendedores que, durante los últimos tres años consecutivos, 
    incrementaron sus ventas en un 100% cada año respecto al año anterior.

    La consulta debe devolver los siguientes datos:

    1. El número de fila (orden correlativo). ROWCOUNT?? No entiendo
    2. El nombre del vendedor.
    3. La cantidad de empleados a cargo de cada vendedor.
    4. La cantidad de clientes a los que vendió en total.

    El resultado debe estar ordenado en forma descendente según el monto total de ventas del vendedor (de mayor a menor).

    **Nota:** No se permiten select en el from, es decir, select ... from (select ...) as T, ...
    Ni WITH, ni tablas temporales.
*/

select ROW_NUMBER(), -- ???
    empl_nombre,
    (select isnull(count(*), 0) from Empleado where empl_jefe = f1.fact_vendedor) empleados,
    (select count(distinct fact_cliente) from Factura where fact_vendedor = f1.fact_vendedor) clientes -- Subconsulta porq tengo solo las del ultimo año
from Factura f1
join Empleado on empl_codigo = f1.fact_vendedor
where YEAR(fact_fecha) = (select YEAR(max(fact_fecha)) from Factura f2 where f1.fact_vendedor = f2.fact_vendedor)
group by fact_vendedor, empl_nombre
having sum(fact_total) > (select sum(fact_total) from Factura fsegAño where f1.fact_vendedor = fsegAño.fact_vendedor and YEAR(f1.fact_fecha) - 1 = YEAR(fsegAño.fact_fecha)) * 2
    and (select sum(fact_total) from Factura fsegAño where f1.fact_vendedor = fsegAño.fact_vendedor and YEAR(f1.fact_fecha) - 1 = YEAR(fsegAño.fact_fecha)) >
        (select sum(fact_total) from Factura fterAño where f1.fact_vendedor = fterAño.fact_vendedor and YEAR(f1.fact_fecha) - 2 = YEAR(fterAño.fact_fecha)) * 2
order by (select sum(fact_total) from Factura where fact_vendedor = f1.fact_vendedor) desc -- Subconsulta porq tengo solo las del utlimo año
go

/*
    2. Se requiere diseñar e implementar los objetos necesarios para gestionar un sistema de comisiones de vendedores. 
    La lógica debe contemplar los siguientes aspectos:

    1. **Registro de comisiones:**
       - Se debe almacenar la comisión correspondiente a cada vendedor por cada factura emitida. -- Tabla independiente, con factura, comision, acumulado y vendedor
       - El porcentaje de comisión se obtiene de la tabla emp_comision, que refleja el porcentaje asignado al vendedor en ese momento.
                        -- Entiendo que esa tabla independiente tiene algo como empl_codigo, comision, fecha

    2. **Manejo de cambios en el porcentaje de comisión:**
       - El porcentaje de comisión puede variar a lo largo del tiempo.
       - Sin embargo, dentro de un mismo mes, todas las facturas deben aplicar el mismo porcentaje de comisión vigente para ese mes (que es el último cargado).
                        -- Entiendo que siempre se toma el ultimo de los meses anteriores y si es null tomo el de Empleado

    3. **Visualización dinámica:**
       - La visualización de la información debe ser dinámica y generarse en cualquier momento a partir de las estructuras estáticas de datos.
                        -- Entiendo que pide que pueda ejecutar un proc que me cargue la info con lo que ya hay y además un trigger que lo mantenga actualizado
                        -- Voy a dejarlo en un trigger que es la parte dinámica
                                -- El proc sería parecido, pero con todas las que existen
       - El sistema debe permitir consultar:
        - El porcentaje de comisión y el monto correspondiente factura por factura.
        - El acumulado mensual de las comisiones para cada vendedor, reflejando los valores calculados en base a las reglas establecidas.
*/

-- Segun mi buen amigo Gemini pedia una vista

create trigger TSQLTri on Factura
after insert
as
begin
    declare @factNum char(8), @factTipo char(1), @factSuc char(4), @factVend numeric(6), @factMonto decimal(12,2), @fecha smalldatetime

    declare cFact cursor for
        select fact_numero, fact_tipo, fact_sucursal, fact_vendedor, fact_total, fact_fecha from inserted

    open cFact
    fetch cFact into @factNum, @factTipo, @factSuc, @factVend, @factMonto, @fecha

    while @@FETCH_STATUS = 0
    begin
        declare @comision decimal(12,2) = (select max(comsion) from emp_comision where emp_codigo = @factVend and DATEDIFF(month, fecha, @fecha) >= 1)
        declare @acumulado decimal(12,2) = (select isnull(max(acumulado), 0) from comisionRegistro where vendedor = @factVend and DATEDIFF(month, fecha, @fecha) = 0)
        
        if @comision is null
            select @comision = empl_comision from Empleado where empl_codigo = @factVend

        insert into comisionRegistro(factNum, factTipo, factSuc, vendedor, comision, acumulado, fecha)
        values (@factNum, @factTipo, @factSuc, @factVend, @factMonto*@comision, @acumulado + @factMonto*@comision,@fecha)

        fetch cFact into @factNum, @factTipo, @factSuc, @factVend, @factMonto, @fecha
    end

    close cFact
    deallocate cFact
end
go