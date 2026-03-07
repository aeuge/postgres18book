-- Users

SELECT rolname FROM pg_roles;
SELECT usename, usesuper FROM pg_catalog.pg_user;
\du

CREATE ROLE test;
SELECT * FROM pg_catalog.pg_user;

ALTER USER test LOGIN;
\c - test

-- error

-- now peer authentication with unix socket, but in unix we have not user test
-- enable password by setting peer -> scram-sha-256
exit
nano /etc/postgresql/18/main/pg_hba.conf
pg_ctlcluster restart 18 main

-- set password
sudo -u postgres psql
\password test
or
ALTER USER test PASSWORD 'pass$123';

\c - test
\dt
SELECT * FROM t;

-- create new user with NOLOGIN
CREATE USER test2 WITH PASSWORD 'pass$123' NOLOGIN;
\c - test2

\c - postgres
GRANT SELECT ON t TO test;
\c - test
SELECT * FROM t;

--
CREATE DATABASE testdb;
\c testdb
CREATE SCHEMA testnm;
CREATE TABLE t1(c1 integer);
INSERT INTO t1 VALUES (1);

CREATE ROLE readonly;
GRANT CONNECT ON DATABASE testdb TO readonly;
GRANT USAGE ON SCHEMA testnm TO readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA testnm TO readonly;

CREATE USER testread WITH PASSWORD 'test123';
GRANT readonly TO testread;
\c testdb testread
SELECT * FROM t1;
\dt

\c testdb postgres
DROP TABLE t1;
CREATE TABLE testnm.t1(c1 integer);
INSERT INTO testnm.t1 VALUES (1);
SELECT * FROM testnm.t1;

\c testdb postgres;
ALTER DEFAULT PRIVILEGES IN SCHEMA testnm GRANT SELECT ON TABLES TO readonly; 
\c testdb testread;
SELECT * FROM testnm.t1;

CREATE TABLE t2(c1 integer); 
INSERT INTO t2 VALUES (2);

\c testdb postgres; 
REVOKE CREATE ON SCHEMA public FROM public; 
REVOKE ALL ON DATABASE testdb FROM public; 
\c testdb testread;

CREATE TABLE t3(c1 integer); 
CREATE TEMP TABLE t3(c1 integer);


-- RLS -----------------
-- Создание политики для существующих объектов
DROP TABLE IF EXISTS depart;
CREATE TABLE depart(login text, department text);
INSERT INTO depart VALUES ('eugene', 'CEO'), ('alex', 'Sales'),('ivan', 'Sales');

DROP TABLE IF EXISTS revenue;
CREATE TABLE revenue(department text, amount numeric(10,2));
INSERT INTO revenue(department,amount) SELECT 'CEO', random()* 10000.00 FROM generate_series(1,10);
INSERT INTO revenue(department,amount) SELECT 'Sales', random()* 100.00 FROM generate_series(1,1000);

CREATE POLICY departments ON revenue USING (department = (SELECT department FROM depart WHERE login = current_user));
-- То есть название отдела (department из таблицы revenue) должно совпадать с департаментом в соответствии с именем пользователя из таблички depart
ALTER TABLE revenue ENABLE ROW LEVEL SECURITY;
DROP USER IF EXISTS eugene;
CREATE USER eugene WITH PASSWORD 'test123';
GRANT SELECT ON depart, revenue TO eugene;
DROP USER IF EXISTS alex;
CREATE USER alex WITH PASSWORD 'test123';
GRANT SELECT ON depart, revenue TO alex;

-- проверка под правами 
SELECT department, SUM(amount) FROM revenue GROUP BY department;
\c - alex localhost 5432
SELECT department, SUM(amount) FROM revenue GROUP BY department;
\c - eugene localhost 5432
SELECT department, SUM(amount) FROM revenue GROUP BY department;



-- Создание политики для новых объектов
-- запретительная
-- Для этого создадим новую ограничительную политику (AS RESTRICTIVE)
CREATE POLICY amount ON revenue AS RESTRICTIVE USING (true) WITH CHECK (abs(amount) <= 1000.00);

-- В команде выше два условия:
--    USING (true) — все существующие строки видны в любом случае;
--    WITH CHECK (abs(amount) <= 100.00) — новые строки должны быть не более 1000;
-- И дадим alex еще привилегию на вставку в эту таблицу:
GRANT INSERT ON revenue TO alex;
\c - alex localhost 5432
INSERT INTO revenue VALUES ('Sales', 100);
INSERT INTO revenue VALUES ('CEO', 100);
INSERT INTO revenue VALUES ('test', 100);
INSERT INTO revenue VALUES ('Sales', 1001);

GRANT INSERT ON revenue TO eugene;
\c - eugene localhost 5432
INSERT INTO revenue VALUES ('CEO', 10000);

\q

-- аккуратно при использовании view
CREATE OR REPLACE VIEW tv1 as SELECT department, SUM(amount) FROM revenue GROUP BY department;
SELECT * FROM tv1;
GRANT SELECT ON tv1 TO eugene;
\c - eugene localhost 5432

-- чтобы избежать такой проблемы:
CREATE OR REPLACE VIEW tv2 WITH (security_barrier) as SELECT department, SUM(amount) FROM revenue GROUP BY department;
GRANT SELECT ON tv2 TO eugene;
\c - eugene localhost 5432
SELECT * FROM tv2;


CREATE OR REPLACE VIEW tv4 WITH (security_barrier) as SELECT * FROM revenue WITH CASCADED CHECK OPTION;
GRANT SELECT ON tv4 TO eugene;
\c - eugene localhost 5432
SELECT * FROM tv4;

-- как ни странно, но документация не соответствует и нужно указывать security_invoker
CREATE OR REPLACE VIEW tv5 WITH (security_invoker) as SELECT * FROM revenue WITH CASCADED CHECK OPTION;
GRANT SELECT ON tv5 TO eugene;
\c - eugene localhost 5432
SELECT * FROM tv5;


-- Так что нужно подходить очень осознанно, когда используете RLS
-- также помечено как LEAKPROOF !
-- https://www.postgresql.org/docs/current/rules-privileges.html







