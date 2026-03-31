# partitioning
CREATE DATABASE part;
\c part

CREATE TABLE logs (
    id              serial,
    logdate         date not null,
    message         text,
    user_id         int
) PARTITION BY RANGE (logdate);

-- create sections
CREATE TABLE logs_y2026m01 PARTITION OF logs FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE logs_y2026m02 PARTITION OF logs FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE logs_y2026m03 PARTITION OF logs FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE logs_y2026m04 PARTITION OF logs FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE logs_y2026m05 PARTITION OF logs FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE logs_y2026m06 PARTITION OF logs FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE logs_y2026m07 PARTITION OF logs FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE logs_y2026m08 PARTITION OF logs FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE logs_y2026m09 PARTITION OF logs FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE logs_y2026m10 PARTITION OF logs FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE logs_y2026m11 PARTITION OF logs FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE logs_y2026m12 PARTITION OF logs FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');
CREATE TABLE logs_y2027m01 PARTITION OF logs FOR VALUES FROM ('2027-01-01') TO ('2027-02-01');

-- create index
CREATE INDEX ON logs (logdate);

\d+ logs

INSERT INTO logs(logdate, message, user_id) VALUES (now(), 'DELETE RECORD 111 ON TABLE accounts', 33);

SELECT COUNT(*) FROM logs;
SELECT COUNT(*) FROM logs_y2026m05;
SELECT COUNT(*) FROM logs_y2026m06;

EXPLAIN SELECT * FROM logs WHERE logdate = now()::date;
EXPLAIN SELECT * FROM logs WHERE user_id = 1;

-- partitioning large table 
-- 1 option
\c demo
\dt bookings.*
\d+ bookings.bookings

CREATE TABLE bookings.bookings2 (
	book_ref bpchar(6) NOT NULL,
	book_date timestamptz NOT NULL,
	total_amount numeric(10,2) NOT NULL
);
INSERT INTO bookings.bookings2 SELECT * FROM bookings.bookings;

BEGIN;
SET LOCAL statement_timeout to '1s';
ALTER TABLE bookings.bookings ADD CONSTRAINT bookings_book_date_check CHECK (book_date < '2026-06-01' and book_date is not null) not valid;
COMMIT;

ALTER TABLE bookings.bookings VALIDATE CONSTRAINT bookings_book_date_check;

ALTER TABLE bookings.bookings DROP CONSTRAINT bookings_book_date_check;

CREATE TABLE bookings.bookings_part (
	book_ref bpchar(6) NOT NULL,
	book_date timestamptz NOT NULL,
	total_amount numeric(10,2) NOT NULL
) PARTITION BY RANGE (book_date);

CREATE TABLE bookings.bookings_part_y2026m6avobe PARTITION OF bookings.bookings_part FOR VALUES FROM ('2026-06-01') TO (MAXVALUE);


BEGIN;
SET statement_timeout TO '1s';
ALTER TABLE bookings.bookings RENAME TO bookings_archive;
ALTER TABLE bookings.bookings_part RENAME TO bookings;
ALTER TABLE bookings.bookings ATTACH PARTITION bookings.bookings_archive FOR VALUES FROM (MINVALUE) to ('2026-06-01');
COMMIT;

EXPLAIN SELECT * FROM bookings.bookings WHERE book_date = now()::date;

-- 2 option
DROP TABLE bookings.bookings;
ALTER TABLE bookings.bookings2 RENAME TO bookings;

CREATE TABLE bookings.bookings_part (
	book_ref bpchar(6) NOT NULL,
	book_date timestamptz NOT NULL,
	total_amount numeric(10,2) NOT NULL
) PARTITION BY RANGE (book_date);


SELECT min(book_date), max(book_date) FROM bookings.bookings;


CREATE TABLE bookings.bookings_part_y2016m08 PARTITION OF bookings.bookings_part FOR VALUES FROM ('2016-08-01') TO ('2016-09-01');
CREATE TABLE bookings.bookings_part_y2016m09 PARTITION OF bookings.bookings_part FOR VALUES FROM ('2016-09-01') TO ('2016-10-01');
CREATE TABLE bookings.bookings_part_y2016m10 PARTITION OF bookings.bookings_part FOR VALUES FROM ('2016-10-01') TO ('2016-11-01');
CREATE TABLE bookings.bookings_part_y2016m11avobe PARTITION OF bookings.bookings_part FOR VALUES FROM ('2016-11-01') TO (MAXVALUE);

\d+ bookings.bookings_part

INSERT INTO bookings.bookings_part SELECT * FROM bookings.bookings;

-- drop old & rename new
ALTER TABLE bookings.bookings RENAME TO bookings2;

DROP TABLE bookings.bookings;
ALTER TABLE bookings.bookings_part RENAME TO bookings;

-- after sections + data load
CREATE INDEX ON bookings.bookings(book_date);

-- error
CREATE UNIQUE INDEX bookings_pkey2 ON bookings.bookings(book_ref);
ALTER TABLE bookings.bookings ADD CONSTRAINT bookings_pkey_uniq UNIQUE (book_ref);

CREATE UNIQUE INDEX bookings_pkey2 ON bookings.bookings(book_ref, book_date);

EXPLAIN SELECT * FROM bookings.bookings WHERE book_date = now()::date;

-- sliding window
\c part
\d+ logs

INSERT INTO logs(logdate, message, user_id) VALUES ('2026-01-01', 'DELETE RECORD 111 ON TABLE accounts', 33);

ALTER TABLE logs DETACH PARTITION logs_y2026m01;
\d+ logs

SELECT * FROM logs_y2026m01;

CREATE TABLE logs_archive (
    id              serial,
    logdate         date not null,
    message         text,
    user_id         int
) PARTITION BY RANGE (logdate);
ALTER TABLE logs_archive ATTACH PARTITION logs_y2026m01 FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

SELECT * FROM logs_archive;