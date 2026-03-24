CREATE TABLE toast_test (id SERIAL, value TEXT);
SELECT relname, reltoastrelid FROM pg_class WHERE relname = 'toast_test';

SELECT relname FROM pg_class WHERE oid = 16393;
\d pg_toast.pg_toast_16389

SELECT
    n.nspname || '.' || c.relname AS table_name,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size,
    pg_size_pretty(pg_total_relation_size(c.reltoastrelid)) AS toast_size
FROM pg_class c
JOIN pg_namespace n
    ON c.relnamespace = n.oid
WHERE
    relname = 'toast_test';

INSERT INTO toast_test (value) VALUES ('small value');
SELECT * FROM pg_toast.pg_toast_16389;

INSERT INTO toast_test (value) VALUES (repeat(' ', 4097));
SELECT * FROM pg_toast.pg_toast_16389;

INSERT INTO toast_test (value) VALUES (repeat('s', 400097));
	SELECT count(*) FROM pg_toast.pg_toast_16389;

SELECT chunk_id, chunk_seq, length(chunk_data) FROM pg_toast.pg_toast_16389;

CREATE OR REPLACE FUNCTION generate_random_string(
  length INTEGER,
  characters TEXT default '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
) RETURNS TEXT AS
$$
DECLARE
  result TEXT := '';
BEGIN
  IF length < 1 then
      RAISE EXCEPTION 'Invalid length';
  END IF;
  FOR __ IN 1..length LOOP
    result := result || substr(characters, floor(random() * length(characters))::int + 1, 1);
  end loop;
  RETURN result;
END;
$$ LANGUAGE plpgsql;

INSERT INTO toast_test (value) VALUES (generate_random_string(1024 * 10));

SELECT chunk_id, COUNT(*) as chunks, pg_size_pretty(sum(octet_length(chunk_data)::bigint))
FROM pg_toast.pg_toast_16389 GROUP BY 1 ORDER BY 1;

TRUNCATE toast_test;

\timing
CREATE TABLE t AS
SELECT i AS id, (SELECT jsonb_object_agg(j, j) FROM generate_series(1, 1000) j) js
FROM generate_series(1, 10000) i;


SELECT oid::regclass AS heap_rel,
       pg_size_pretty(pg_relation_size(oid)) AS heap_rel_size,
       reltoastrelid::regclass AS toast_rel,
    pg_size_pretty(pg_relation_size(reltoastrelid)) AS toast_rel_size
FROM pg_class WHERE relname = 't';

\d+ t
SELECT pg_current_wal_lsn();
UPDATE t SET id = id + 1;
SELECT pg_current_wal_lsn();

SELECT pg_size_pretty(pg_wal_lsn_diff('0/1FADE3B0','0/1F96A060')) AS wal_size;

SELECT pg_current_wal_lsn();
UPDATE t SET js = js::jsonb || '{"a":1}';
SELECT pg_current_wal_lsn();
SELECT pg_size_pretty(pg_wal_lsn_diff('0/26818180','0/1FADE3B0')) AS wal_size;
