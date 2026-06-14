/*3) Realizar una consulta que muestre código de producto, nombre de producto y el stock 
total, sin importar en que deposito se encuentre, los datos deben ser ordenados por 
nombre del artículo de menor a mayor.*/

select * from STOCK
order by stoc_producto
-- Me comi el isnull
Select prod_codigo, prod_detalle, sum(isnull(stoc_cantidad,0)) STOCK from Producto
left join STOCK on prod_codigo = stoc_producto
group by prod_codigo, prod_detalle
order by prod_detalle desc

/*4) Realizar una consulta que muestre para todos los artículos código, detalle y cantidad de 
artículos que lo componen. Mostrar solo aquellos artículos para los cuales el stock 
promedio por depósito sea mayor a 100.*/

select prod_codigo, prod_detalle, count(distinct(comp_componente)) componentes from Producto
left join Composicion on comp_producto = prod_codigo
join stock on prod_codigo = stoc_producto
group by prod_codigo, prod_detalle
having avg(stoc_cantidad) > 100

-- Mi solución está mal, agregar el segundo join modifico mi consulta. Al poner el segundo JOIN tenia 12
-- Depósitos, lo que hacía que se duplicaran las cosas. Lo que está mal es la atomicidad, solución en este
-- caso particular es usar un distinc en el count, pero para otras situaciones:

select prod_codigo, prod_detalle, count(comp_componente) componentes from Producto
left join Composicion on comp_producto = prod_codigo
where prod_codigo in (
	select stoc_producto from STOCK
	group by stoc_producto
	having avg(stoc_cantidad) > 100
)
group by prod_codigo, prod_detalle
order by count(comp_componente) desc

/* 5) Realizar una consulta que muestre código de artículo, detalle y cantidad de egresos de 
stock que se realizaron para ese artículo en el año 2012 (egresan los productos que 
fueron vendidos). Mostrar solo aquellos que hayan tenido más egresos que en el 2011. */

-- Los egresos de stock estan en los items de la factura. La fecha en la factura.

select prod_codigo codigo, 
	prod_detalle detalle,
	sum(case year(fact_fecha) when 2012 then item_cantidad else 0 end) ventas
	from Producto -- 2.190 Filas.
join Item_Factura on item_producto = prod_codigo -- 19.484
join Factura on item_numero = fact_numero -- 19.484
				and item_sucursal = fact_sucursal
				and item_tipo = fact_tipo
group by prod_codigo, prod_detalle
having 	sum(case year(fact_fecha) when 2012 then item_cantidad else 0 end) >
		sum(case year(fact_fecha) when 2011 then item_cantidad else 0 end) 

-- Profe:
SELECT 
    prod_codigo, 
    prod_detalle, 
    SUM(item_cantidad)
FROM 
    producto 
    JOIN item_factura ON prod_codigo = item_producto 
    JOIN factura ON item_tipo + item_sucursal + item_numero = fact_tipo + fact_sucursal + fact_numero
WHERE 
    YEAR(fact_fecha) = 2012
GROUP BY 
    prod_codigo, 
    prod_detalle
HAVING 
    SUM(item_cantidad) > isnull((
        SELECT 
            SUM(item_cantidad) 
        FROM 
            item_factura 
            JOIN factura ON item_tipo + item_sucursal + item_numero = fact_tipo + fact_sucursal + fact_numero
        WHERE 
            item_producto = prod_codigo 
            AND YEAR(fact_fecha) = 2011
    ), 0);

-- En teoría no se puede hacer sin subconsulta, pero gemini opinaba otra cosa...

/* 6) Mostrar para todos los rubros de artículos código, detalle, cantidad de artículos de ese
rubro y stock total de ese rubro de artículos. Solo tener en cuenta aquellos artículos que
tengan un stock mayor al del artículo ‘00000000’ en el depósito ‘00’.*/

-- Quiero codigo, detalle, cantidad de articulos DEL RUBRO y stock total DEL RUBRO

select rubr_id codigo, 
	rubr_detalle detalle,
	count(distinct(prod_codigo)) cantidad_articulos,
	sum(isnull(stoc_cantidad, 0)) stock_total
	from Rubro
left join Producto on rubr_id = prod_rubro
left join STOCK on prod_codigo = stoc_producto
        and prod_codigo in 
            (select stoc_producto from STOCK group by stoc_producto having 
                sum(isnull(stoc_cantidad,0)) > 
                (select stoc_cantidad from STOCK where stoc_producto = '00000000' and stoc_deposito = '00'))
group by rubr_id, rubr_detalle
order by 1

-- Como JOINEO sin usar toda la pk de stock, me está alterando la cantidad que devuelve.
-- Se que devuelve una única fila porque estoy comparando con la PK
-- El enunciado pide que el ARTICULO tenga más stock
-- La condición la ponemos en el JOIN para tener en cuenta aquellos queno cumplen la condición.
-- El enunciado pide TODOS los rubros, por eso no hacemos un JOIN o ponemos la condiçión en un WHERE

/* 7) Generar una consulta que muestre para cada artículo código, detalle, mayor precio
menor precio y % de la diferencia de precios (respecto del menor Ej.: menor precio =
10, mayor precio =12 => mostrar 20 %). Mostrar solo aquellos artículos que posean
stock. */

-- Los precios salen de item_factura, mientras que stock está en STOCK

select prod_codigo codigo,
	prod_detalle detalle,
	max(item_precio) precio_max,
	min(item_precio) precio_min,
	str(((max(item_precio)-min(item_precio))/min(item_precio))*100, 6, 2) diferencia
	from Producto
join Item_Factura on prod_codigo = item_producto
where prod_codigo in (select stoc_producto from STOCK group by stoc_producto having sum(stoc_cantidad) > 0)
group by prod_codigo, prod_detalle
order by 1

-- Me falto agregar el str
-- En este ejercicio poner el JOIN no me afecta, porque tener duplicados no afecta ese MAX o MIN
-- En este caso el subselect es mejor, porque el select es estático no tiene que iterar sobre stock
--			Además es más seguro, porque permite agregar cosas a futuro

select prod_codigo codigo,
	prod_detalle detalle,
	max(item_precio) precio_max,
	min(item_precio) precio_min,
	str(((max(item_precio)-min(item_precio))/min(item_precio))*100, 6, 2) diferencia
	from Producto
join Item_Factura on prod_codigo = item_producto
join STOCK on item_producto = stoc_producto
group by prod_codigo, prod_detalle
having sum(stoc_cantidad) > 0
order by 1

-- Opción con JOIN

/* 8) Mostrar para el o los artículos que tengan stock en todos los depósitos, nombre del 
artículo, stock del depósito que más stock tiene. */

select prod_detalle nombre, max(stoc_cantidad) maximo_stoc from Producto
join STOCK on prod_codigo = stoc_producto
where stoc_cantidad > 0
group by prod_detalle
having count(stoc_deposito) = (select count(*) from DEPOSITO) 

/* 9) Mostrar el código del jefe, código del empleado que lo tiene como jefe, nombre del 
mismo y la cantidad de depósitos que ambos tienen asignados. */

select empl_codigo jefe, empl_codigo, empl_nombre, count(distinct depo_codigo) from Empleado 
left join DEPOSITO on (empl_codigo = depo_encargado or empl_jefe = depo_encargado)
group by empl_codigo, empl_codigo, empl_nombre

/*
 10) Mostrar los 10 productos más vendidos en la historia y también los 10 productos menos 
vendidos en la historia. Además mostrar de esos productos, quien fue el cliente que 
mayor compra realizo.
*/

select item_producto, (select top 1 fact_cliente from Factura join Item_Factura on
						item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
						where item_producto = i.item_producto
						group by fact_cliente
						order by sum(item_cantidad) desc) cliente
	from Item_Factura i
join Factura on item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
where item_producto in 
	(select top 10 item_producto from Item_Factura group by item_producto order by sum(item_cantidad) DESC)
	or item_producto in (select top 10 item_producto from Item_Factura group by item_producto order by sum(item_cantidad) ASC)
group by item_producto

-- Los dos ultimos subselects son estáticos.
-- El que más se vendio si se calcula siempre.
-- Siempre que podamos usemos la condición en el where antes que en el having.

/*
 11) Realizar una consulta que retorne el detalle de la familia, la cantidad diferentes de 
productos vendidos y el monto de dichas ventas sin impuestos. Los datos se deberán 
ordenar de mayor a menor, por la familia que más productos diferentes vendidos tenga, 
solo se deberán mostrar las familias que tengan una venta superior a 20000 pesos para 
el año 2012.
*/

select fami_detalle,
	count(distinct prod_codigo) prod_vendidos,
	sum(item_cantidad * item_precio) monto
	from Item_Factura
join Producto on item_producto = prod_codigo
join Familia on fami_id = prod_familia
where prod_familia in (select prod_familia from Producto
						join Item_Factura on prod_codigo = item_producto
						join Factura on item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
						where year(fact_fecha) = 2012
						group by prod_familia)
group by fami_detalle
having sum(item_cantidad*item_precio) > 20000
order by 2 desc

/*
	12) Mostrar nombre de producto, cantidad de clientes distintos que lo compraron importe 
	promedio pagado por el producto, cantidad de depósitos en los cuales hay stock del 
	producto y stock actual del producto en todos los depósitos. Se deberán mostrar 
	aquellos productos que hayan tenido operaciones en el año 2012 y los datos deberán 
	ordenarse de mayor a menor por monto vendido del producto. 
*/

select prod_detalle,
	count(distinct fact_cliente) cant_cliente,
	avg(item_precio) precio_promedio,
	(select count(*) from stock where prod_codigo = stoc_producto) cant,
	(select sum(stoc_cantidad) from STOCK where prod_codigo = stoc_producto) cant_stoc
	from Producto
join Item_Factura on prod_codigo = item_producto
join Factura on item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
where prod_codigo in (select distinct item_producto from Item_Factura
						join Factura on item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
						where year(fact_fecha) = 2012)
group by prod_detalle, prod_codigo
order by sum(item_precio*item_cantidad) desc

/*
	13) Realizar una consulta que retorne para cada producto que posea composición  nombre 
	del producto, precio del producto, precio de la sumatoria de los precios por la cantidad 
	de los productos que lo componen. Solo se deberán mostrar los productos que estén 
	compuestos por más de 2 productos y deben ser ordenados de mayor a menor por 
	cantidad de productos que lo componen. 
*/


select p.prod_detalle nombre, p.prod_precio precio, sum(c.prod_precio * comp_cantidad) sumatoria from Producto p
join Composicion on prod_codigo = comp_producto
join Producto c on comp_componente = c.prod_codigo
group by p.prod_detalle, p.prod_precio
having count(*) >= 2 -- Compuestos por dos productos o más.
order by count(*) desc

/*
	14) Escriba una consulta que retorne una estadística de ventas por cliente. Los campos que 
	debe retornar son: 
 
	Código del cliente 
	Cantidad de veces que compro en el último año 
	Promedio por compra en el último año 
	Cantidad de productos diferentes que compro en el último año 
	Monto de la mayor compra que realizo en el último año 
 
	Se deberán retornar todos los clientes ordenados por la cantidad de veces que compro en 
	el último año. 
	No se deberán visualizar NULLs en ninguna columna
*/

select
	fact_cliente codigo_cliente,
	isnull(count(fact_numero),0) cantidad_compras, -- Usar Primary Key
	AVG(isnull(fact_total,0)) promedio_compra,
	(select count(distinct item_producto) from Item_Factura join Factura on item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
		where YEAR(fact_fecha) = (select max(year(fact_fecha)) from factura) 
			AND fact_cliente = f.fact_cliente) cantidad_productos,
	MAX(isnull(fact_total,0)) mayor_monto 
	from Cliente -- No estaba mal
left join Factura f on clie_codigo = fact_cliente
where YEAR(fact_fecha) = (select max(year(fact_fecha)) from factura)
group by fact_cliente
order by count(fact_numero) desc

-- ReinoCHAD solución

select fact_cliente cliente,
	count(*) facturas,
	AVG(isnull(fact_total,0)) promedio,
	(select count(distinct item_producto) from Factura join Item_Factura
		on item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
		where f1.fact_cliente = fact_cliente and YEAR(fact_fecha) = (select max(year(fact_fecha)) from factura)) productos,
	MAX(fact_total) maximo
from Factura f1
where YEAR(fact_fecha) = (select max(year(fact_fecha)) from factura)
group by fact_cliente

/*
	15) Escriba una consulta que retorne los pares de productos que hayan sido vendidos juntos 
	(en la misma factura) más de 500 veces. El resultado debe mostrar el código y 
	descripción de cada uno de los productos y la cantidad de veces que fueron vendidos 
	juntos. El resultado debe estar ordenado por la cantidad de veces que se vendieron 
	juntos dichos productos. Los distintos pares no deben retornarse más de una vez. 
 
	Ejemplo de lo que retornaría la consulta: 
  
	PROD1 DETALLE1 PROD2 DETALLE2 VECES 
	1731 MARLBORO KS 1 7 1 8 P H ILIPS MORRIS KS 5 0 7 
	1718 PHILIPS MORRIS KS 1 7 0 5 P H I L I P S MORRIS BOX 10 5 6 2 
*/

select p1.prod_codigo cod_1, p1.prod_detalle det_1, p2.prod_codigo cod_2, p2.prod_detalle det_2, count(*) ventas from Item_Factura i1
join Item_Factura i2 
	on i1.item_tipo+i1.item_sucursal+i1.item_numero = i2.item_tipo+i2.item_sucursal+i2.item_numero
		and i1.item_producto < i2.item_producto
join Producto p1 on i1.item_producto = p1.prod_codigo
join Producto p2 on i2.item_producto = p2.prod_codigo
group by p1.prod_codigo, p1.prod_detalle, p2.prod_codigo, p2.prod_detalle
having count(*) > 500
order by count(*) desc

-- Si queremos pares tenemos que iterar dos veces

/*
	16) Con el fin de lanzar una nueva campaña comercial para los clientes que menos compran 
	en la empresa, se pide una consulta SQL que retorne aquellos clientes cuyas compras  
	son inferiores a 1/3 del monto de ventas del producto que más se vendió en el 2012. 
 
	Además mostrar 
 
	1. Nombre del Cliente 
	2. Cantidad de unidades totales vendidas en el 2012 para ese cliente. 
	3. Código de producto que mayor venta tuvo en el 2012 (en caso de existir más de 1, 
	mostrar solamente el de menor código) para ese cliente. 
*/

select clie_razon_social nombre,
	sum(item_cantidad) cant_unidades_vendidas,
	(select top 1 item_producto from Factura
		join Item_Factura on item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
		where year(fact_fecha) = 2012 and fact_cliente = clie_codigo
		group by item_producto
		order by sum(item_cantidad*item_precio) desc, item_producto) prod_mayor
from Cliente
join Factura on fact_cliente = clie_codigo
join Item_Factura on item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
where year(fact_fecha) = 2012
group by clie_razon_social, clie_codigo
having sum(item_cantidad*item_precio) < (select top 1 sum(item_precio*item_cantidad) ventas from Item_Factura
					join Factura on item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
					where year(fact_fecha) = 2012
					group by item_producto
					order by 1 desc)/3

/*
	17) Escriba una consulta que retorne una estadística de ventas por año y mes para cada 
	producto. 
 
	La consulta debe retornar: 
 
	PERIODO: Año y mes de la estadística con el formato YYYYMM 
	PROD: Código de producto 
	DETALLE: Detalle del producto 
	CANTIDAD_VENDIDA= Cantidad vendida del producto en el periodo 
	VENTAS_AÑO_ANT= Cantidad vendida del producto en el mismo mes del periodo 
	pero del año anterior 
	CANT_FACTURAS= Cantidad de facturas en las que se vendió el producto en el 
	periodo 
 
	La consulta no puede mostrar NULL en ninguna de sus columnas y debe estar ordenada 
	por periodo y código de producto.
*/

select year(fact_fecha)*100 + month(fact_fecha) as PERIODO, 
	item_producto PROD, 
	prod_detalle DETALLE,
	sum(item_cantidad) CANTIDAD_VENDIDA,
	isnull((select sum(item_cantidad) from Item_Factura
	join Factura on item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
				and year(fact_fecha)*100 + month(fact_fecha) = year(f.fact_fecha)*100 + month(f.fact_fecha) - 100
				and i.item_producto = item_producto),0) VENTAS_AÑO_ANT,
	count(*) CANT_FACTURAS -- Cada fila corresponde a una factura porque agrupo por producto, misma factura no tiene renglones distintos para el mismo producto.
	from Item_Factura i
join Factura f on item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
join Producto on item_producto = prod_codigo
group by year(fact_fecha)*100 + month(fact_fecha), item_producto, prod_detalle
order by 1, 2

/*
	18) Escriba una consulta que retorne una estadística de ventas para todos los rubros. 
	La consulta debe retornar: 
	DETALLE_RUBRO: Detalle del rubro 
	VENTAS: Suma de las ventas en pesos de productos vendidos de dicho rubro 
	PROD1: Código del producto más vendido de dicho rubro 
	PROD2: Código del segundo producto más vendido de dicho rubro 
	CLIENTE: Código del cliente que compro más productos del rubro en los últimos 30 
	días 
	La consulta no puede mostrar NULL en ninguna de sus columnas y debe estar ordenada 
	por cantidad de productos diferentes vendidos del rubro.
*/

select rubr_detalle DETALLE_RUBRO,
    sum(item_cantidad*item_precio) VENTAS,
    (select top 1 item_producto from Item_Factura 
        join Producto on item_producto = prod_codigo
                        and prod_rubro = rubr_id
        group by item_producto
        order by sum(item_precio*item_cantidad) desc) PROD1,
    (select top 1 item_producto from 
        (select top 2 item_producto, sum(item_precio*item_cantidad) total
         from Item_Factura 
         join Producto on item_producto = prod_codigo and prod_rubro = rubr_id
         group by item_producto
         order by sum(item_precio*item_cantidad) desc) as primeros_dos
		order by total asc) PROD2,
    isnull((select top 1 fact_cliente from Factura
        join Item_Factura on item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
        join Producto on item_producto = prod_codigo
        where DATEADD(day, -30, GETDATE()) < fact_fecha -- facturas de los ultimos 30 dias
                and prod_rubro = rubr_id
        group by fact_cliente
        order by sum(item_cantidad) desc), 'No hay') CLIENTE
from Item_Factura
join Producto on prod_codigo = item_producto
right join Rubro on prod_rubro = rubr_id
group by rubr_detalle, rubr_id
order by count(distinct prod_codigo) desc

/*
	19. En virtud de una recategorizacion de productos referida a la familia de los mismos  se 
	solicita que desarrolle una consulta sql que retorne para todos los productos: 
	 Codigo de producto 
	 Detalle del producto 
	 Codigo de la familia del producto 
	 Detalle de la familia actual del producto 
	 Codigo de la familia sugerido para el producto 
	 Detalla de la familia sugerido para el producto 
	La familia sugerida para un producto es la que poseen la mayoria de los productos cuyo 
	detalle coinciden en los primeros 5 caracteres. 
	En caso que 2 o mas familias pudieran ser sugeridas se debera seleccionar la de menor 
	codigo.  Solo se deben mostrar los productos para los cuales la familia actual sea 
	diferente a la sugerida 
	Los resultados deben ser ordenados por detalle de producto de manera ascendente
*/

select prod_codigo,
	prod_detalle,
	prod_familia familia_actual_id,
	fami_detalle familia_actual_detalle,
	 (select top 1 fami_id from Producto p2 
		join Familia on prod_familia = fami_id
		where SUBSTRING(p2.prod_detalle, 1, 5) = SUBSTRING(p1.prod_detalle, 1, 5)
		group by fami_id
		order by count(*) desc, fami_id desc) familia_sugerida_id,
	 (select top 1 fami_detalle from Producto p2 
		join Familia on prod_familia = fami_id
		where SUBSTRING(p2.prod_detalle, 1, 5) = SUBSTRING(p1.prod_detalle, 1, 5)
		group by fami_detalle, fami_id
		order by count(*) desc, fami_id asc) familia_sugerida_detalle 
from Producto p1
join Familia on prod_familia = fami_id
where not prod_familia = (select top 1 fami_id from Producto p2 
		join Familia on prod_familia = fami_id
		where SUBSTRING(p2.prod_detalle, 1, 5) = SUBSTRING(p1.prod_detalle, 1, 5)
		group by fami_id
		order by count(*) desc, fami_id asc) 
order by prod_detalle asc

/*
	20) Escriba una consulta sql que retorne un ranking de los mejores 3 empleados del 2012 
	Se debera retornar legajo, nombre y apellido, anio de ingreso, puntaje 2011, puntaje 
	2012.  El puntaje de cada empleado se calculara de la siguiente manera: para los que 
	hayan vendido al menos 50 facturas el puntaje se calculara como la cantidad de facturas 
	que superen los 100 pesos que haya vendido en el año, para los que tengan menos de 50 
	facturas en el año el calculo del puntaje sera el 50% de cantidad de facturas realizadas 
	por sus subordinados directos en dicho año. 
*/

select top 3 empl_codigo legajo,
	empl_nombre nombre,
	empl_apellido apellido,
	empl_ingreso año_ingreso,
	case when sum(case when year(fact_fecha) = 2011 then 1 else 0 end) >= 50 then
		sum(case when year(fact_fecha) = 2011 and fact_total > 100 then 1 else 0 end) else
		(select count(*)/2 from Factura join Empleado e2 on e.empl_codigo = e2.empl_jefe
			where fact_vendedor = e2.empl_codigo and fact_fecha = 2011) end puntaje2011,
	case when sum(case when year(fact_fecha) = 2012 then 1 else 0 end) >= 50 then
		sum(case when year(fact_fecha) = 2012 and fact_total > 100 then 1 else 0 end) else
		(select count(*)/2 from Factura join Empleado e2 on e.empl_codigo = e2.empl_jefe
			where fact_vendedor = e2.empl_codigo and fact_fecha = 2012) end puntaje2012
	from Empleado e
left join Factura on fact_vendedor = empl_codigo
group by empl_codigo, empl_nombre, empl_apellido, empl_ingreso
order by 6 desc

SELECT TOP 3 
    E.empl_codigo AS legajo,
    E.empl_nombre AS nombre,
    E.empl_apellido AS apellido,
    YEAR(E.empl_ingreso) AS anio_ingreso,
    
    -- CÁLCULO PUNTAJE 2011
    CASE 
        -- Condición: Si él mismo vendió 50 o más en 2011
        WHEN (SELECT COUNT(*) FROM Factura WHERE fact_vendedor = E.empl_codigo AND YEAR(fact_fecha) = 2011) >= 50 
        -- Resultado True: Contar facturas mayores a $100 en 2011
        THEN (SELECT COUNT(*) FROM Factura WHERE fact_vendedor = E.empl_codigo AND YEAR(fact_fecha) = 2011 AND fact_total > 100)
        -- Resultado False: 50% de las facturas de sus subordinados en 2011
        ELSE (SELECT COUNT(*) * 0.5 
              FROM Factura F 
              JOIN Empleado E2 ON F.fact_vendedor = E2.empl_codigo 
              WHERE E2.empl_jefe = E.empl_codigo AND YEAR(F.fact_fecha) = 2011)
    END AS puntaje_2011,

    -- CÁLCULO PUNTAJE 2012
    CASE 
        -- Condición: Si él mismo vendió 50 o más en 2012
        WHEN (SELECT COUNT(*) FROM Factura WHERE fact_vendedor = E.empl_codigo AND YEAR(fact_fecha) = 2012) >= 50 
        -- Resultado True: Contar facturas mayores a $100 en 2012
        THEN (SELECT COUNT(*) FROM Factura WHERE fact_vendedor = E.empl_codigo AND YEAR(fact_fecha) = 2012 AND fact_total > 100)
        -- Resultado False: 50% de las facturas de sus subordinados en 2012
        ELSE (SELECT COUNT(*) * 0.5 
              FROM Factura F 
              JOIN Empleado E2 ON F.fact_vendedor = E2.empl_codigo 
              WHERE E2.empl_jefe = E.empl_codigo AND YEAR(F.fact_fecha) = 2012)
    END AS puntaje_2012

FROM Empleado E

-- Ordenamos por el alias asignado al puntaje de 2012
ORDER BY puntaje_2012 DESC;

/*
	21. Escriba una consulta sql que retorne para todos los años, en los cuales se haya hecho al 
	menos una factura, la cantidad de clientes a los que se les facturo de manera incorrecta 
	al menos una factura y que cantidad de facturas se realizaron de manera incorrecta. Se 
	considera que una factura es incorrecta cuando la diferencia entre el total de la factura 
	menos el total de impuesto tiene una diferencia mayor a $ 1 respecto a la sumatoria de 
	los costos de cada uno de los items de dicha factura. Las columnas que se deben mostrar 
	son: 
	 Año 
	 Clientes a los que se les facturo mal en ese año 
	 Facturas mal realizadas en ese año 
*/

select year(fact_fecha) año,
	count(distinct fact_cliente) cant_clientes,
	count(distinct fact_numero) cant_fact
from Factura f1
where fact_numero in (select fact_numero from Factura
		join Item_Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
		group by fact_numero
		having abs(avg(fact_total-fact_total_impuestos) - sum(item_cantidad*item_precio)) > 1)
group by year(fact_fecha)
order by 1

/*
	22. Escriba una consulta sql que retorne una estadistica de venta para todos los rubros por  
	trimestre contabilizando todos los años. Se mostraran como maximo 4 filas por rubro (1 
	por cada trimestre). 
	Se deben mostrar 4 columnas: 
	 Detalle del rubro 
	 Numero de trimestre del año (1 a 4) 
	 Cantidad de facturas emitidas en el trimestre en las que se haya vendido al 
	menos un producto del rubro 
	 Cantidad de productos diferentes del rubro vendidos en el trimestre  
	El resultado debe ser ordenado alfabeticamente por el detalle del rubro y dentro de cada 
	rubro primero el trimestre en el que mas facturas se emitieron. 
	No se deberan mostrar aquellos rubros y trimestres para los cuales las facturas emitiadas 
	no superen las 100. 
	En ningun momento se tendran en cuenta los productos compuestos para esta 
	estadistica.
*/

select rubr_detalle rubro, 
	DATEPART(quarter, fact_fecha) trimestre,
	count(distinct fact_numero) cant_facturas,
	count(distinct prod_codigo) cant_productos
from Item_Factura
join Producto on item_producto = prod_codigo
join Rubro on prod_rubro = rubr_id
join Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
where prod_codigo not in (select comp_componente from Composicion)
group by rubr_id, rubr_detalle, DATEPART(quarter, fact_fecha)
having count(distinct fact_numero) > 100
order by 1 desc, 3

/*
	23. Realizar una consulta SQL que para cada año muestre : 
	 Año 
	 El producto con composición más vendido para ese año. 
	 Cantidad de productos que componen directamente al producto más vendido 
	 La cantidad de facturas en las cuales aparece ese producto. 
	 El código de cliente que más compro ese producto. 
	 El porcentaje que representa la venta de ese producto respecto al total de venta 
	del año. 
	El resultado deberá ser ordenado por el total vendido por año en forma descendente. 
*/

select YEAR(fact_fecha) año, 
	item_producto prod_mas_vendido,
	(select count(*) from Composicion where comp_producto = item_producto) cant_componentes,
		count(distinct fact_numero) facturas,
	(select top 1 fact_cliente from Factura
		join Item_Factura on fact_numero = item_numero and fact_sucursal = item_sucursal and fact_tipo = item_tipo
		where YEAR(fact_fecha) = YEAR(f1.fact_fecha) and item_producto = i1.item_producto
		group by fact_cliente
		order by (sum(item_cantidad)) desc) cliente,
	(sum(item_precio*item_cantidad) / (select sum(item_precio*item_cantidad) from Item_Factura
												join Factura on fact_numero = item_numero and fact_sucursal = item_sucursal and fact_tipo = item_tipo
												where YEAR(fact_fecha) = YEAR(f1.fact_fecha)) * 100) porcentaje
from Factura f1
join Item_Factura i1 on fact_numero = item_numero and fact_sucursal = item_sucursal and fact_tipo = item_tipo
group by YEAR(fact_fecha), item_producto
having item_producto = (select top 1 item_producto from Factura
		join Item_Factura on fact_numero = item_numero and fact_sucursal = item_sucursal and fact_tipo = item_tipo
		where YEAR(fact_fecha) = YEAR(f1.fact_fecha) and item_producto in (select comp_producto from Composicion)
		group by item_producto
		order by (sum(item_cantidad*item_precio)) desc) -- Dejo en el grupo solo el producto mas vendido
order by sum(item_cantidad*item_precio) desc

/*
	24. Escriba una consulta que considerando solamente las facturas correspondientes a los 
	dos vendedores con mayores comisiones, retorne los productos con composición 
	facturados al menos en cinco facturas, 
	La consulta debe retornar las siguientes columnas: 
	 Código de Producto 
	 Nombre del Producto 
	 Unidades facturadas 
	El resultado deberá ser ordenado por las unidades facturadas descendente.
*/

select item_producto codigo,
	prod_detalle nombre,
	sum(item_cantidad) unidades
from Factura
join Item_Factura on fact_numero = item_numero and fact_sucursal = item_sucursal and fact_tipo = item_tipo
join Producto on prod_codigo = item_producto
where fact_vendedor in (select top 2 empl_codigo from Empleado
						order by empl_comision desc) and -- Top 2 Empleados con mas comision
		item_producto in (select comp_producto from Composicion) -- Solo los que tienen composición
group by item_producto, prod_detalle
having count(distinct fact_numero) >= 5 -- Más de 5 facturados
order by 3 desc

/*
	25. Realizar una consulta SQL que para cada año y familia muestre : 
	-a. Año 
	-b. El código de la familia más vendida en ese año. 
	-c. Cantidad de Rubros que componen esa familia. 
	-d. Cantidad de productos que componen directamente al producto más vendido de esa familia. 
	-e. La cantidad de facturas en las cuales aparecen productos pertenecientes a esa familia. 
	-f. El código de cliente que más compro productos de esa familia. 
	-g. El porcentaje que representa la venta de esa familia respecto al total de venta del año. 
	El resultado deberá ser ordenado por el total vendido por año y familia en forma 
	descendente.
*/

select YEAR(fact_fecha) año, -- a
	 prod_familia familia_mas_vendida, -- b
	(select count(distinct prod_rubro) from Producto where prod_familia = p1.prod_familia) rubros_de_familia, -- c
	(select count(*) from Composicion 
		where comp_producto = (select top 1 item_producto from Item_Factura
								join Producto on item_producto = prod_codigo
								where prod_familia = p1.prod_familia
								group by item_producto
								order by sum(item_cantidad) desc)) prod_componen, -- d
	count(distinct fact_numero) cant_facturas, -- e
	(select top 1 fact_cliente from Factura
		join Item_Factura on fact_numero = item_numero and fact_sucursal = item_sucursal and fact_tipo = item_tipo
		join Producto on prod_codigo = item_producto
		where prod_familia = p1.prod_familia
		group by fact_cliente
		order by sum(item_cantidad) desc) cliente_mas_compro, -- f
	str((sum(item_cantidad*item_precio)/(select sum(item_cantidad*item_precio) from Item_Factura
									join Factura on fact_numero = item_numero and fact_sucursal = item_sucursal and fact_tipo = item_tipo
									where YEAR(fact_fecha) = YEAR(f1.fact_fecha))*100), 4, 2) porcentaje -- g
from Producto p1
join Item_Factura on item_producto = prod_codigo
join Factura f1 on fact_numero = item_numero and fact_sucursal = item_sucursal and fact_tipo = item_tipo
where prod_familia = (select top 1 prod_familia from Factura 
					join Item_Factura on fact_numero = item_numero and fact_sucursal = item_sucursal and fact_tipo = item_tipo
					join Producto on item_producto = prod_codigo
					where YEAR(fact_fecha) = YEAR(f1.fact_fecha)
					group by prod_familia
					order by sum(item_cantidad) desc)
group by YEAR(fact_fecha), prod_familia
order by sum(item_precio*item_cantidad) desc

/*
	26. Escriba una consulta sql que retorne un ranking de empleados devolviendo las 
	siguientes columnas: 
	 Empleado 
	 Depósitos que tiene a cargo 
	 Monto total facturado en el año corriente 
	 Codigo de Cliente al que mas le vendió 
	 Producto más vendido 
	 Porcentaje de la venta de ese empleado sobre el total vendido ese año. 
	Los datos deberan ser ordenados por venta del empleado de mayor a menor. 
*/

select empl_codigo,
	(select count(*) from DEPOSITO where depo_encargado = empl_codigo) depo_a_cargo,
	sum(fact_total) facturado,
	(select top 1 fact_cliente from Factura where fact_vendedor = empl_codigo
		group by fact_cliente
		order by sum(fact_total) desc) cliente_mas_vendio,
	(select top 1 item_producto from Factura
		join Item_Factura on fact_numero = item_numero and fact_sucursal = item_sucursal and fact_tipo = item_tipo
		where fact_vendedor = empl_codigo
		group by item_producto
		order by sum(item_cantidad) desc) producto_mas_vendido,
	str((sum(fact_total)/(select sum(fact_total) from Factura where YEAR(fact_fecha) = 2012)*100),4,2) porcentaje 
from Empleado
join Factura on fact_vendedor = empl_codigo
where YEAR(fact_fecha) = 2012 -- YEAR(GETDATE()) Para tener resultados pongo 2012
group by empl_codigo
order by facturado desc

/*
	27. Escriba una consulta sql que retorne una estadística basada en la facturacion por año y 
	envase devolviendo las siguientes columnas: 
	 Año 
	 Codigo de envase 
	 Detalle del envase 
	 Cantidad de productos que tienen ese envase 
	 Cantidad de productos facturados de ese envase 
	 Producto mas vendido de ese envase 
	 Monto total de venta de ese envase en ese año 
	 Porcentaje de la venta de ese envase respecto al total vendido de ese año 
	Los datos deberan ser ordenados por año y dentro del año por el envase con más 
	facturación de mayor a menor
*/

select YEAR(fact_fecha) año,
	enva_codigo codigo_envase,
	enva_detalle detalle_envase,
	(select count(*) from Producto where prod_envase = enva_codigo) cant_prod,
	count(distinct prod_codigo) productos_facturados, -- Entiendo que es de ese año, sino sub consulta
	(select top 1 item_producto from Item_Factura
		join Producto on prod_codigo = item_producto
		where prod_envase = enva_codigo
		group by item_producto
		order by sum(item_cantidad) desc) producto_mas_vendido,
	sum(item_precio*item_cantidad) monto_total,
	str((sum(item_precio*item_cantidad)*100/(select sum(item_precio*item_cantidad) from Item_Factura
										join Factura on fact_numero = item_numero and fact_sucursal = item_sucursal and fact_tipo = item_tipo
										where YEAR(fact_fecha) = YEAR(f1.fact_fecha))), 4, 2) porcentaje
from Producto
join Envases on prod_envase = enva_codigo
join Item_Factura on prod_codigo = item_producto
join Factura f1 on fact_numero = item_numero and fact_sucursal = item_sucursal and fact_tipo = item_tipo
group by YEAR(fact_fecha), enva_codigo, enva_detalle
order by año desc, monto_total desc 

/*
	28. Escriba una consulta sql que retorne una estadística por Año y Vendedor que retorne las 
	siguientes columnas: 
	 Año. 
	 Codigo de Vendedor 
	 Detalle del Vendedor // Nombre supongo?
	 Cantidad de facturas que realizó en ese año 
	 Cantidad de clientes a los cuales les vendió en ese año. 
	 Cantidad de productos facturados con composición en ese año // Supongo que de ese vendedor
	 Cantidad de productos facturados sin composicion en ese año. // Supongo que de ese vendedor
	 Monto total vendido por ese vendedor en ese año 
	Los datos deberan ser ordenados por año y dentro del año por el vendedor que haya 
	vendido mas productos diferentes de mayor a menor.
*/

select YEAR(fact_fecha) año,
	fact_vendedor cod_vendedor,
	empl_nombre nombre,
	count(distinct fact_numero) facuras,
	count(distinct fact_cliente) clientes,
	(select count(distinct item_producto) from Item_Factura
		join Factura on fact_numero = item_numero and fact_sucursal = item_sucursal and fact_tipo = item_tipo 
			and fact_vendedor = f1.fact_vendedor and YEAR(fact_fecha) = YEAR(f1.fact_fecha)
		where item_producto in (select comp_producto from Composicion)) prod_compo,
	(select count(distinct item_producto) from Item_Factura
		join Factura on fact_numero = item_numero and fact_sucursal = item_sucursal and fact_tipo = item_tipo 
			and fact_vendedor = f1.fact_vendedor and YEAR(fact_fecha) = YEAR(f1.fact_fecha)
		where item_producto not in (select comp_producto from Composicion)) prod_no_compo,
	sum(item_precio*item_cantidad) monto
from Factura f1
join Empleado on fact_vendedor = empl_codigo
join Item_Factura on fact_numero = item_numero and fact_sucursal = item_sucursal and fact_tipo = item_tipo 
group by fact_vendedor, empl_nombre, YEAR(fact_fecha)
order by YEAR(fact_fecha) desc, count(distinct item_producto) desc

/*
	29. Se solicita que realice una estadística de venta por producto para el año 2011, solo para 
	los productos que pertenezcan a las familias que tengan más de 20 productos asignados 
	a ellas, la cual deberá devolver las siguientes columnas: 
	a. Código de producto 
	b. Descripción del producto 
	c. Cantidad vendida 
	d. Cantidad de facturas en la que esta ese producto 
	e. Monto total facturado de ese producto 
	Solo se deberá mostrar un producto por fila en función a los considerandos establecidos 
	antes.  El resultado deberá ser ordenado por el la cantidad vendida de mayor a menor.
*/

select prod_codigo codigo,
	prod_detalle descripcion,
	sum(item_cantidad) cant_vendida,
	count(distinct fact_numero+fact_sucursal+fact_tipo) cant_facturas,
	sum(item_cantidad*item_precio) facturado
from Item_Factura
join Factura on fact_numero = item_numero and fact_sucursal = item_sucursal and fact_tipo = item_tipo
join Producto on prod_codigo = item_producto
where YEAR(fact_fecha) = 2011 and prod_familia in (select prod_familia from Producto
													group by prod_familia
													having count(*) > 20)
group by prod_codigo, prod_detalle
order by cant_vendida desc

/*
	30. Se desea obtener una estadistica de ventas del año 2012, para los empleados que sean 
	jefes, o sea, que tengan empleados a su cargo, para ello se requiere que realice la 
	consulta que retorne las siguientes columnas: 
	 Nombre del Jefe 
	 Cantidad de empleados a cargo 
	 Monto total vendido de los empleados a cargo 
	 Cantidad de facturas realizadas por los empleados a cargo 
	 Nombre del empleado con mejor ventas de ese jefe -- Que es "mejor ventas"?
	Debido a la perfomance requerida, solo se permite el uso de una subconsulta si fuese 
	necesario. 
	Los datos deberan ser ordenados por de mayor a menor por el Total vendido y solo se 
	deben mostrarse los jefes cuyos subordinados hayan realizado más de 10 facturas.
*/

select e1.empl_nombre nombre_jefe,
	count(distinct e2.empl_codigo) empleados_a_cargo,
	sum(fact_total) monto_total_vendido_empleados,
	count(distinct fact_numero+fact_sucursal+fact_tipo) cantidad_facturas,
	(select top 1 e3.empl_nombre from Empleado e3
		join Factura f2 on f2.fact_vendedor = e3.empl_codigo and YEAR(f2.fact_fecha) = 2012
		where e3.empl_jefe = e1.empl_codigo
		group by e3.empl_codigo, e3.empl_nombre
		order by SUM(fact_total) desc) mejor_empleado
from Empleado e1
join Empleado e2 on e1.empl_codigo = e2.empl_jefe
join Factura f1 on fact_vendedor = e2.empl_codigo and YEAR(fact_fecha) = 2012
group by e1.empl_codigo, e1.empl_nombre
having count(*) > 10
order by monto_total_vendido_empleados desc

/*
	31. Escriba una consulta sql que retorne una estadística por Año y Vendedor que retorne las 
	siguientes columnas: 
	 Año. 
	 Codigo de Vendedor 
	 Detalle del Vendedor 
	 Cantidad de facturas que realizó en ese año 
	 Cantidad de clientes a los cuales les vendió en ese año. 
	 Cantidad de productos facturados con composición en ese año 
	 Cantidad de productos facturados sin composicion en ese año. 
	 Monto total vendido por ese vendedor en ese año 
	Los datos deberan ser ordenados por año y dentro del año por el vendedor que haya 
	vendido mas productos diferentes de mayor a menor. 
*/

select YEAR(fact_fecha) año,
	fact_vendedor cod_vend,
	empl_nombre nombre,
	count(distinct fact_numero+fact_sucursal+fact_tipo) cant_fact,
	count(distinct fact_cliente) cant_clientes,
	count(distinct case when comp_producto is not null then item_producto else null end) cant_prod_comp,
	count(distinct case when comp_producto is null then item_producto else null end) cant_prod_sin_comp,
	(select sum(fact_total) from Factura where YEAR(fact_fecha) = YEAR(f1.fact_fecha) and fact_vendedor = f1.fact_vendedor) total
from Factura f1
join Empleado on fact_vendedor = empl_codigo
join Item_Factura on fact_numero = item_numero and fact_sucursal = item_sucursal and fact_tipo = item_tipo
left join Composicion on comp_producto = item_producto
group by YEAR(fact_fecha), fact_vendedor, empl_nombre

/*
	32. Se desea conocer las familias que sus productos se facturaron juntos en las mismas 
	facturas para ello se solicita que escriba una consulta sql que retorne los pares de 
	familias que tienen productos que se facturaron juntos.  Para ellos deberá devolver las 
	siguientes columnas: 
	 Código de familia  
	 Detalle de familia 
	 Código de familia 
	 Detalle de familia  
	 Cantidad de facturas 
	 Total vendido 
	Los datos deberan ser ordenados por Total vendido y solo se deben mostrar las familias 
	que se vendieron juntas más de 10 veces. 
*/

select f1.fami_id cod_fami_1,
	f1.fami_detalle det_fami_1,
	f2.fami_id cod_fami_2,
	f2.fami_detalle det_fami_2,
	count(distinct i1.item_numero+i1.item_sucursal+i1.item_tipo) cant_fact,
	(select sum(item_precio*item_cantidad) from Item_Factura
		join Producto on item_producto = prod_codigo
		where prod_familia = f1.fami_id or prod_familia = f2.fami_id) total
from Item_Factura i1
join Producto p1 on i1.item_producto = p1.prod_codigo
join Familia f1 on p1.prod_familia = f1.fami_id
join Item_Factura i2 on i1.item_numero = i2.item_numero and i1.item_sucursal = i2.item_sucursal and i1.item_tipo = i2.item_tipo
join Producto p2 on i2.item_producto = p2.prod_codigo
join Familia f2 on f2.fami_id = p2.prod_familia
where f1.fami_id < f2.fami_id -- PROTIP
group by f1.fami_id, f1.fami_detalle, f2.fami_id, f2.fami_detalle
having count(distinct i1.item_numero+i1.item_sucursal+i1.item_tipo) > 10
order by total desc

/*
	33. Se requiere obtener una estadística de venta de productos que sean componentes. Para 
	ello se solicita que realiza la siguiente consulta que retorne la venta de los 
	componentes del producto más vendido del año 2012.  Se deberá mostrar: 
	a. Código de producto 
	b. Nombre del producto 
	c. Cantidad de unidades vendidas 
	d. Cantidad de facturas en la cual se facturo 
	e. Precio promedio facturado de ese producto. 
	f. Total facturado para ese producto 
	El resultado deberá ser ordenado por el total vendido por producto para el año 2012. 
*/

select prod_codigo cod,
	prod_detalle nombre,
	sum(item_cantidad) cant_vendida,
	count(distinct item_numero+item_sucursal+item_tipo) cant_facturas,
	avg(item_precio) precio_promedio,
	sum(item_precio*item_cantidad) total
from Item_Factura
join Producto on prod_codigo = item_producto
join Composicion on comp_componente = item_producto -- Me quedan solo los componentes
join Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo
where YEAR(fact_fecha) = 2012
group by prod_codigo, prod_detalle
order by total desc

/*
	34. Escriba una consulta sql que retorne para todos los rubros la cantidad de facturas mal 
	facturadas por cada mes del año 2011 Se considera que una factura es incorrecta cuando 
	en la misma factura se factutan productos de dos rubros diferentes.  Si no hay facturas 
	mal hechas se debe retornar 0. Las columnas que se deben mostrar son: 
	1- Codigo de Rubro 
	2- Mes 
	3- Cantidad de facturas mal realizadas.
*/

SELECT 
    r.rubr_id codigo_rubro,
    MONTH(f1.fact_fecha) mes,
    COUNT(DISTINCT CASE 
            WHEN p1.prod_rubro <> p2.prod_rubro 
            THEN f1.fact_tipo + f1.fact_sucursal + f1.fact_numero 
            ELSE NULL 
          END) cant_facturas_mal_realizadas
FROM Rubro r
LEFT JOIN Producto p1 ON r.rubr_id = p1.prod_rubro
LEFT JOIN Item_Factura i1 ON p1.prod_codigo = i1.item_producto
LEFT JOIN Factura f1 ON i1.item_numero = f1.fact_numero 
     AND i1.item_sucursal = f1.fact_sucursal 
     AND i1.item_tipo = f1.fact_tipo 
     AND YEAR(f1.fact_fecha) = 2011
LEFT JOIN Item_Factura i2 ON f1.fact_numero = i2.item_numero 
     AND f1.fact_sucursal = i2.item_sucursal 
     AND f1.fact_tipo = i2.item_tipo
LEFT JOIN Producto p2 ON i2.item_producto = p2.prod_codigo
GROUP BY r.rubr_id, MONTH(f1.fact_fecha)
ORDER BY r.rubr_id ASC, mes ASC;

/*
	35. Se requiere realizar una estadística de ventas por año y producto, para ello se solicita 
	que escriba una consulta sql que retorne las siguientes columnas: 
	 Año 
	 Codigo de producto 
	 Detalle del producto 
	 Cantidad de facturas emitidas a ese producto ese año  
	 Cantidad de vendedores diferentes que compraron ese producto ese año. 
	 Cantidad de productos a los cuales compone ese producto, si no compone a ninguno 
	se debera retornar 0. 
	 Porcentaje de la venta de ese producto respecto a la venta total de ese año. 
	Los datos deberan ser ordenados por año y por producto con mayor cantidad vendida.
*/

select YEAR(fact_fecha) año,
	prod_codigo codigo,
	prod_detalle detalle,
	count(distinct fact_numero+fact_tipo+fact_sucursal) cant_fact,
	count(distinct fact_vendedor) vendedores,
	isnull((select count(distinct comp_producto) from Composicion where comp_componente = prod_codigo),0) prod_comp,
	sum(item_precio*item_cantidad)/(select sum(item_precio*item_cantidad) from Item_Factura
									join Factura on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo
									and YEAR(fact_fecha) = YEAR(f1.fact_fecha))*100 total
from Item_Factura
join Factura f1 on item_numero = fact_numero and item_sucursal = fact_sucursal and item_tipo = fact_tipo
join Producto on prod_codigo = item_producto
group by YEAR(fact_fecha), prod_codigo, prod_detalle
order by año desc, sum(item_cantidad) desc

/* 
	Se requiere mostrar los productos que sean componentes y que se hayan vendido en forma unitaria o a través del producto
	al cual compone, por ejemplo una hamburguesa se deberá mostrar si se vendió como hamburguesa y si se vendió un combo 
	que está compuesto por una hamburguesa. 

	Se deberá mostrar:

	Código de producto
	Nombre de producto
	Cantidad de facturas vendidas solo
	Cantidad de facturas vendidas de los productos que compone
	Cantidad de productos a los cuales compone que se vendieron

	El resultado deberá ser ordenado por el componente que se haya vendido solo en más facturas 

	Aclaración: se debe resolver en una sola consulta sin utilizar subconsultas en ningún lugar del Select
*/

select prod_codigo codigo,
	prod_detalle,
	count(distinct i1.item_numero+i1.item_sucursal+i1.item_tipo) fact_solo,
	count(distinct i2.item_numero+i2.item_sucursal+i2.item_tipo) fact_compone,
	count(distinct i2.item_producto) cant_prod_comp_vend
from Item_Factura i1
join Producto on prod_codigo = i1.item_producto
join Composicion on i1.item_producto = comp_componente
left join Item_Factura i2 on i2.item_producto = comp_componente
group by prod_codigo, prod_detalle

/*
	Armar una estadística que muestre: 
 
	a.    Año
	b.    Mes
	c.    Razón Social Cliente
	d.    Rubro
	e.    Familia
	f.    Cantidad de unidades de ese rubro/familia
 
	Se deberán considerar solo aquellos clientes que llegaron a comprar más en monto de ese rubro/familia en ese año que el monto vendido del producto que más se vendió en ese año.
 
	NOTA: No se permite el uso de sub-selects en el FROM ni funciones definidas por el usuario
*/

select YEAR(fact_fecha) año,
	MONTH(fact_fecha) mes,
	clie_razon_social,
	prod_rubro,
	prod_familia,
	sum(item_cantidad) unidades
from Factura f1
join Cliente on fact_cliente = clie_codigo
join Item_Factura on fact_numero = item_numero and fact_sucursal = item_sucursal and fact_tipo = item_tipo
join Producto on prod_codigo = item_producto
group by YEAR(fact_fecha), MONTH(fact_fecha), clie_razon_social, prod_rubro, prod_familia
having sum(item_cantidad*item_precio) > (select top 1 sum(item_cantidad*item_precio) from Item_Factura
											join Factura on fact_numero = item_numero and fact_sucursal = item_sucursal and fact_tipo = item_tipo
											where YEAR(fact_fecha) = YEAR(f1.fact_fecha)
											group by item_producto
											order by sum(item_cantidad*item_precio)) -- Mas se vendio = cantidad*precio

/*
	Realizar una consulta SQL que retorne para el último año, los 5 vendedores con menos clientes asignados, 
	que más vendieron en pesos (si hay varios con menos clientes asignados debe traer el que más vendió):

	1)  Apellido y Nombre  del Vendedor.
	2)  Total de unidades de Producto Vendidas.
	3)  Monto promedio de venta por factura.
	4)  Monto total de ventas.

	El resultado deberá mostrar ordenado la cantidad de ventas descendente, en caso de igualdad de cantidades, 
	ordenar por código de vendedor.
*/

select empl_nombre,
	empl_apellido,
	sum(item_cantidad) unidades,
	AVG(fact_total - fact_total_impuestos) promedio,
	SUM(item_cantidad*item_precio) total
from Empleado
left join Factura on fact_vendedor = empl_codigo and YEAR(fact_fecha) = (select YEAR(MAX(fact_fecha)) from Factura)
join Item_Factura on fact_numero = item_numero and fact_sucursal = item_sucursal and fact_tipo = item_tipo
where fact_vendedor in (select top 5 clie_vendedor from Cliente 
							left join Factura on clie_codigo = fact_cliente
							where clie_vendedor is not null
							group by clie_vendedor 
							order by count(distinct clie_codigo) asc, sum(fact_total) desc)
group by empl_codigo, empl_nombre, empl_apellido

-- CORREGIR CON LO DEL PROFE DA DISTINTO Y NOSE PORQUE =(

/* 
	Dado la baja de operaciones detectada, la empresa está evaluando el lanzamiento de nuevas promociones 
	y beneficios para ciertos clientes. Para lo cual, le solicitan un informe de los 30 clientes que 
	posean mayor límite de crédito, con las siguientes columnas:

	-   Razón social del cliente
	-   Promedio en pesos de las compras realizadas durante el año 2012.
	-   Un string que indique “Compró productos compuestos”, en caso de que alguno de todos 
	los productos comprados tenga composición, en caso contrario ese string estará en blanco.

	Se deberán mostrar 30 filas, si alguno de los clientes no compro en ese año se deberá mostrar en cero.
	Se deberán ordenar los resultados por el código del cliente.

	NOTA: No se permite el uso de sub-selects en el FROM ni funciones definidas por el usuario 
	para este punto. 
*/

select clie_razon_social,
	(select isnull(AVG(fact_total),0) from Factura
		where fact_cliente = clie_codigo and YEAR(fact_fecha) = 2012) promedio,
	(case
		when exists (select 1 from Item_Factura 
						join Composicion on item_producto = comp_producto
						join Factura on item_numero = fact_numero and fact_cliente = clie_codigo)
				then 'Compro productos compuestos'
		else ' ' end) compuestos
						
from Cliente
where clie_codigo in (select top 30 clie_codigo from Cliente order by clie_limite_credito desc)
order by clie_codigo