-- профилирование
sudo -u postgres psql
ALTER SYSTEM SET log_min_duration_statement = 0;
SELECT pg_reload_conf();
SHOW log_min_duration_statement;
SELECT * from test;
exit

sudo DEBIAN_FRONTEND=noninteractive apt install -y pgbadger lynx
sudo su postgres
tail /var/log/postgresql/postgresql-18-main.log
pgbadger /var/log/postgresql/postgresql-18-main.log
pgbadger /var/log/postgresql/postgresql-18-main.log -f stderr
-- утилита чтения HTML из командной строки
lynx out.html


-- что можно сделать
-- добавить информацию - кто вообще запрос то выполнял
ALTER SYSTEM SET log_line_prefix = '%t [%p]: user=%u,db=%d,app=%a,client=%h';
SELECT pg_reload_conf();

-- уменьшить количество строк в процентах
\! ls -la /var/log/postgresql
\! cat ~/workload2.sql
\! /usr/lib/postgresql/18/bin/pgbench -c 1 -j 1 -T 10 -f ~/workload2.sql -n -U postgres thai

-- размер файла Х +750 КБ - 1400 строк записалось в WAL + LOG + файлы данных
ALTER SYSTEM SET log_statement_sample_rate = 0.01;
SELECT pg_reload_conf();
\! /usr/lib/postgresql/18/bin/pgbench -c 1 -j 1 -T 10 -f ~/workload2.sql -n -U postgres thai
\! ls -la /var/log/postgresql
\! tail -n 100 /var/log/postgresql/postgresql-18-main.log


SHOW log_statement_sample_rate;
SHOW log_min_duration_statement;

ALTER SYSTEM SET log_min_duration_statement = 1;
ALTER SYSTEM SET log_min_duration_sample = 0;
SELECT pg_reload_conf();

\! /usr/lib/postgresql/18/bin/pgbench -c 1 -j 1 -T 10 -f ~/workload2.sql -n -U postgres thai
\! ls -la /var/log/postgresql

ALTER SYSTEM SET log_min_duration_statement = 1;
SELECT pg_reload_conf();
\! /usr/lib/postgresql/18/bin/pgbench -c 1 -j 1 -T 10 -f ~/workload2.sql -n -U postgres thai
\! ls -la /var/log/postgresql

\! tail -n 100 /var/log/postgresql/postgresql-18-main.log


-- установим логирование конкретному пользователю
\du
ALTER SYSTEM SET log_min_duration_statement = -1;
ALTER SYSTEM SET log_min_duration_sample = -1;
SELECT pg_reload_conf();
DROP TABLE IF EXISTS test;
CREATE TABLE test(i int);
INSERT INTO test values (1);
DROP OWNED BY eugene CASCADE; -- не забываем про принадлежащие объекты
DROP USER IF EXISTS eugene;
CREATE USER eugene WITH PASSWORD 'password';
ALTER USER postgres WITH PASSWORD 'password';
GRANT ALL PRIVILEGES ON test TO eugene;

ALTER ROLE eugene SET "log_statement" TO 'ddl';
SELECT pg_reload_conf();

\c - eugene localhost 5432
SELECT i FROM test WHERE 1=1;

\! tail -n 100 /var/log/postgresql/postgresql-18-main.log | grep SELECT
-- и видим доступ из под непревилегированного пользователя

\q

psql
ALTER ROLE eugene SET "log_statement" TO 'all';
SHOW log_statement;

\c - eugene localhost 5432
SHOW log_statement;
SELECT i FROM test WHERE 1=2;
INSERT INTO test values (2);

\! tail -n 100 /var/log/postgresql/postgresql-18-main.log | grep SELECT
\! tail -n 100 /var/log/postgresql/postgresql-18-main.log | grep INSERT

-- можно например выводить продолжительность запросов
ALTER ROLE eugene SET "log_duration"=1;
\c - eugene localhost 5432
INSERT INTO test values (4);
SELECT pg_reload_conf();

-- логируем, но время не пишется
-- связано с багофичей
-- https://postgresqlco.nf/doc/en/param/log_duration/
-- проставляется только тогда, когда включен log_min_duration_statement


-- установим логи на БД
psql -c "DROP DATABASE IF EXISTS log;"
psql -c "CREATE DATABASE log;"
psql -c "ALTER DATABASE log SET log_min_duration_statement=1;"
psql -c "CREATE TABLE test(i int);" -d log
psql -c "SELECT i FROM test WHERE 1=2;" -d log
tail -n 100 /var/log/postgresql/main/postgresql-18-main.log


-- auto_explain
-- https://scalegrid.io/blog/introduction-to-auto-explain-postgres/
psql -d thai
SHOW session_preload_libraries;

-- https://postgresqlco.nf/doc/en/param/session_preload_libraries/
ALTER SYSTEM SET session_preload_libraries = auto_explain;
SELECT pg_reload_conf();
-- !!! загружаем в сессию !!!
LOAD 'auto_explain';
SET auto_explain.log_min_duration = 100;
SET auto_explain.log_analyze = true;
SET auto_explain.log_buffers = true;
SET auto_explain.log_format = JSON;

SELECT r.id, 
       r.startdate as depart_date, 
       bs.city || ', ' || bs.name as busstation, 
       count(t.id)
FROM book.ride r
JOIN book.schedule as s
      on r.fkschedule = s.id
JOIN book.busroute br
      on s.fkroute = br.id
JOIN book.busstation bs
      on br.fkbusstationfrom = bs.id
JOIN book.tickets t
      on t.fkride = r.id
GROUP BY r.id, 
         r.startdate, 
         bs.city || ', ' || bs.name
ORDER BY r.startdate
limit 10;

\! tail -n 1000 /var/log/postgresql/postgresql-18-main.log
