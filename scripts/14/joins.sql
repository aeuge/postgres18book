-- joins

CREATE DATABASE joins;
\c joins
CREATE TABLE a (city_name varchar, country varchar);
INSERT INTO a (city_name, country) VALUES
('Tokyo','Japan'),
('New York','USA'),
('Fukuoka','Japan'),
('Shanghai','China');

CREATE TABLE b (city_name varchar, godzilla_attacks int);
INSERT INTO b (city_name, godzilla_attacks) VALUES
('Fukuoka',3),
('Nagoya',2),
('New York',3),
('Tokai',3),
('Tokyo',13),
('Yokohama',2);

-- inner joins
SELECT a.city_name, b.godzilla_attacks
FROM a
JOIN b on a.city_name = b.city_name;

 -- or
SELECT a.city_name, b.godzilla_attacks
FROM a
INNER JOIN b on a.city_name = b.city_name;

-- or
SELECT a.city_name, b.godzilla_attacks
FROM a, b 
where a.city_name = b.city_name;

-- left
SELECT a.city_name, b.godzilla_attacks
FROM a
LEFT JOIN b on a.city_name = b.city_name;

-- or
SELECT a.city_name, b.godzilla_attacks
FROM a
LEFT OUTER JOIN b on a.city_name = b.city_name;

-- or
SELECT a.city_name, b.godzilla_attacks
FROM b
RIGHT JOIN a on a.city_name = b.city_name;

-- left where b.key is null
SELECT a.city_name, b.godzilla_attacks
FROM a
LEFT JOIN b on a.city_name = b.city_name 
WHERE b.city_name is null;

-- full
SELECT a.country, a.city_name, b.city_name, b.godzilla_attacks
FROM a
FULL JOIN b on a.city_name = b.city_name;

-- full exclude inner
SELECT a.country, a.city_name, b.city_name, b.godzilla_attacks
FROM a
FULL JOIN b on a.city_name = b.city_name
WHERE a.city_name IS NULL OR b.city_name IS NULL;

-- cross
SELECT a.country, a.city_name, b.city_name, b.godzilla_attacks
FROM a
CROSS JOIN b;


-- lateral
SELECT b.city_name, (SELECT a.country FROM a WHERE a.city_name = b.city_name)
FROM b;


SELECT b.city_name
FROM b
JOIN (SELECT a.country FROM a) as foo on true;

SELECT b.city_name
FROM b
JOIN (SELECT a.country FROM a WHERE a.city_name = b.city_name) as foo on true;

SELECT b.city_name, foo.country
FROM b
JOIN LATERAL (SELECT a.country FROM a WHERE a.city_name = b.city_name) as foo on true;

-- second order
-- https://www.db-fiddle.com/f/ecmhKVAphorT9BUVMWKKGG/0

-- union
SELECT a.country as c, a.city_name as n
FROM a
UNION
SELECT 'RUSSIA' as c, b.city_name as n
FROM b
UNION
SELECT 'USA' as c, a.city_name as n
FROM a;

-- union all
SELECT a.country as c, a.city_name as n
FROM a
UNION ALL
SELECT 'RUSSIA' as c, b.city_name as n
FROM b
UNION ALL
SELECT 'USA' as c, a.city_name as n
FROM a;

-- Except
SELECT a.city_name as n
FROM a
EXCEPT ALL
SELECT b.city_name as n
FROM b;

EXPLAIN SELECT a.city_name as n
FROM a
EXCEPT ALL
SELECT b.city_name as n
FROM b;

SELECT a.city_name
FROM a
LEFT JOIN b on a.city_name = b.city_name 
WHERE b.city_name is null;

EXPLAIN SELECT a.city_name
FROM a
LEFT JOIN b on a.city_name = b.city_name 
WHERE b.city_name is null;

-- intersect
SELECT a.city_name as n
FROM a
INTERSECT ALL
SELECT b.city_name as n
FROM b;

-- insane join
SELECT a.city_name, b.city_name, b.godzilla_attacks
FROM a
LEFT JOIN b on (a.country = 'USA' AND b.godzilla_attacks = 2) OR b.godzilla_attacks = 13;


-- demo thai bookings 
-- задача - составить список поездок, сколько всего было мест в автобусе и сколько было занято
psql -d thai
\timing
-- список таблиц
\dt+ book.*

\d+ book.ride
-- Построим список рейсов:
SELECT id
FROM book.ride
LIMIT 10;

-- Добавим дату рейса без времени:
SELECT id, startdate as depart_date
FROM book.ride
LIMIT 10;

-- Добавим басстейшн выезда и отсортируем по дате выезда:
SELECT r.id, r.startdate as depart_date, bs.city || ', ' || bs.name
FROM book.ride r
JOIN book.schedule as s
      ON r.fkschedule = s.id
JOIN book.busroute br
      ON s.fkroute = br.id
JOIN book.busstation bs
      ON br.fkbusstationfrom = bs.id
ORDER BY r.startdate
LIMIT 10;

-- Посчитаем количество проданных билетов:
SELECT r.id, 
       r.startdate as depart_date, 
       bs.city || ', ' || bs.name as busstation, 
       count(t.id)
FROM book.ride r
JOIN book.schedule as s
      ON r.fkschedule = s.id
JOIN book.busroute br
      ON s.fkroute = br.id
JOIN book.busstation bs
      ON br.fkbusstationfrom = bs.id
JOIN book.tickets t
      ON t.fkride = r.id
GROUP BY r.id, 
         r.startdate, 
         bs.city || ', ' || bs.name
ORDER BY r.startdate
LIMIT 10;

-- Видим, что наши запросы начинают выполняться всё дольше и дольше.

-- Посчитаем ещё и вместимость и, используя EXPLAIN ANALYZE, посмотрим на время выполнения запроса, 
-- посчитаем cost и посмотрим, что вообще происходит внутри:
EXPLAIN ANALYZE
SELECT r.id, r.startdate as depart_date, bs.city || ', ' || bs.name as busstation, count(t.id) as order_place, count(st.id) as all_place
FROM book.ride r
JOIN book.schedule as s
      ON r.fkschedule = s.id
JOIN book.busroute br
      ON s.fkroute = br.id
JOIN book.busstation bs
      ON br.fkbusstationfrom = bs.id
JOIN book.tickets t
      ON t.fkride = r.id
JOIN book.seat st
      ON r.fkbus = st.fkbus
GROUP BY r.id, r.startdate, bs.city || ', ' || bs.name
ORDER BY r.startdate
LIMIT 10;
-- 20 sec
-- Видим просто фантастическую стоимость и итоговое количество строк для анализа!

-- вариант с вложенными зависимыми подзапросами
EXPLAIN 
SELECT r.id, r.startdate as depart_date, bs.city || ', ' || bs.name as busstation, 
(SELECT count(t.id) FROM book.tickets t WHERE t.fkride = r.id ) as order_place, 
(SELECT count(st.id) FROM book.seat st WHERE r.fkbus = st.fkbus)  as all_place
FROM book.ride r
JOIN book.schedule as s
      ON r.fkschedule = s.id
JOIN book.busroute br
      ON s.fkroute = br.id
JOIN book.busstation bs
      ON br.fkbusstationfrom = bs.id
GROUP BY r.id, r.startdate, bs.city || ', ' || bs.name
ORDER BY r.startdate
LIMIT 10;

-- 20 -> 2

-- вариант с двумя СТЕ:
-- EXPLAIN
WITH all_place AS (
    SELECT count(s.id) as all_place, s.fkbus as fkbus
    FROM book.seat s
    group by s.fkbus
),
order_place AS (
    SELECT count(t.id) as order_place, t.fkride
    FROM book.tickets t
    group by t.fkride
)
SELECT r.id, r.startdate as depart_date, bs.city || ', ' || bs.name as busstation,  
      t.order_place, st.all_place
FROM book.ride r
JOIN book.schedule as s
      ON r.fkschedule = s.id
JOIN book.busroute br
      ON s.fkroute = br.id
JOIN book.busstation bs
      ON br.fkbusstationfrom = bs.id
JOIN order_place t
      ON t.fkride = r.id
JOIN all_place st
      ON r.fkbus = st.fkbus
GROUP BY r.id, r.startdate, bs.city || ', ' || bs.name, t.order_place,st.all_place
ORDER BY r.startdate
LIMIT 10;

-- 20 -> 0.8

-- еще СТЕ
-- camelCase
-- EXPLAIN
WITH allPlaces AS (
    SELECT count(s.id) as allPlaces, s.fkbus as fkbus
    FROM book.seat s
    group by s.fkbus
),
orderPlaces AS (
    SELECT count(t.id) as orderPlaces, t.fkride
    FROM book.tickets t
    group by t.fkride
),
busstationName AS (
      SELECT s.id as id, bs.city || ', ' || bs.name as busstation
      FROM book.schedule as s
      JOIN book.busRoute br
            ON s.fkroute = br.id
      JOIN book.busStation bs
            ON br.fkbusstationFrom = bs.id
)
SELECT r.id, r.startdate as departDate, bs.busstation as busstation,  
      t.orderPlaces, st.allPlaces
FROM book.ride r
JOIN busstationName bs
      ON bs.id = r.fkschedule
JOIN orderPlaces t
      ON t.fkride = r.id
JOIN allPlaces st
      ON r.fkbus = st.fkbus
GROUP BY r.id, r.startdate, bs.busstation, t.orderPlaces, st.allPlaces
ORDER BY r.startdate
LIMIT 10;


-- то же самое, глянем EXPLAIN
-- планировщик за нас уже все сделал)

-- а если без сортировки
WITH allPlaces AS (
    SELECT count(s.id) as allPlaces, s.fkbus as fkbus
    FROM book.seat s
    group by s.fkbus
),
orderPlaces AS (
    SELECT count(t.id) as orderPlaces, t.fkride
    FROM book.tickets t
    group by t.fkride
),
busstationName AS (
      SELECT s.id as id, bs.city || ', ' || bs.name as busstation
      FROM book.schedule as s
      JOIN book.busRoute br
            ON s.fkroute = br.id
      JOIN book.busStation bs
            ON br.fkbusstationFrom = bs.id
)
SELECT r.id, r.startdate as departDate, bs.busstation as busstation,  
      t.orderPlaces, st.allPlaces
FROM book.ride r
JOIN busstationName bs
      ON bs.id = r.fkschedule
JOIN orderPlaces t
      ON t.fkride = r.id
JOIN allPlaces st
      ON r.fkbus = st.fkbus
GROUP BY r.id, r.startdate, bs.busstation, t.orderPlaces, st.allPlaces
LIMIT 10;

-- 0.5 sec