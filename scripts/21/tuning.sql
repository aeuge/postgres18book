-- tuning
--wget https://storage.googleapis.com/thaibus/thai_small.tar.gz && tar -xf thai_small.tar.gz && psql < thai.sql
psql -d thai
\l+
EXPLAIN SELECT count(*) FROM book.tickets;
EXPLAIN SELECT count(1) FROM book.tickets;
SELECT relname, pg_size_pretty(pg_relation_size(oid)) FROM pg_class WHERE relname like 'tickets%';
VACUUM ANALYZE book.tickets;
SET random_page_cost = 1;
EXPLAIN SELECT count(1) FROM book.tickets;

\d+ book.tickets
ALTER TABLE book.tickets ALTER COLUMN fio SET NOT NULL;
UPDATE book.tickets SET fio = 'no' WHERE fio is NULL;
ALTER TABLE book.tickets ALTER COLUMN fio SET NOT NULL;
EXPLAIN SELECT count(fio) FROM book.tickets;


\timing
CREATE EXTENSION "uuid-ossp";
CREATE TABLE records2 (id int8 not null, filler text);
INSERT INTO records2 SELECT id, repeat(' ', 100) FROM generate_series(1, 10000000) id;

CREATE TABLE records3 (uuid_v4 uuid not null, filler text);
INSERT INTO records3 SELECT gen_random_uuid(), repeat(' ', 100) FROM generate_series(1, 10000000) id;

CREATE INDEX ON records2 (id);
CREATE INDEX ON records3 (uuid_v4);

SELECT COUNT(id) FROM records2;
SELECT COUNT(uuid_v4) FROM records3;

SELECT count(*) FROM pg_settings;

-- UUID v7
CREATE TABLE records7 (uuid_v7 uuid not null, filler text);
INSERT INTO records7 SELECT gen_random_uuid(), repeat(' ', 100) FROM generate_series(1, 10000000) id;
CREATE INDEX ON records7 (uuid_v7);
SELECT COUNT(uuid_v7) FROM records7;

-- memcache
shared_preload_libraries = 'pgmemcache'
CREATE EXTENSION pgmemcache;
memcache_server_add('hostname:port'::TEXT)
memcache_add(key::TEXT, value::TEXT)
newval = memcache_decr(key::TEXT)
memcache_delete(key::TEXT)


-- column store
shared_preload_libraries = 'cstore_fdw'
CREATE EXTENSION cstore_fdw;

CREATE SERVER cstore_server FOREIGN DATA WRAPPER cstore_fdw;
CREATE FOREIGN TABLE table
( ) SERVER cstore_server
OPTIONS(compression 'pglz');

INSERT INTO table SELECT * FROM sourcetable;


-- timescale DB
shared_preload_libraries = 'timescaledb'
CREATE EXTENSION timescaledb;

CREATE TABLE table (time TIMESTAMPTZ, value TEXT);
SELECT create_hypertable(‘table', 'time');
