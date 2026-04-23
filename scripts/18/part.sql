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
SELECT COUNT(*) FROM logs_y2026m03;

EXPLAIN SELECT * FROM logs WHERE logdate = now()::date;
EXPLAIN SELECT * FROM logs WHERE user_id = 1;

-- partitioning large table 
-- 1 option
\c thai
\dt book.*
\d+ book.tickets
SELECT * INTO book.tickets2 FROM book.tickets;
CREATE TABLE book.tickets2
(
    id bigserial PRIMARY KEY,
    fkRide int REFERENCES book.ride(id), 
    fio text,
    contact jsonb,
    fkSeat int REFERENCES book.seat(id)
);
INSERT INTO book.tickets2 SELECT * FROM book.tickets;

ALTER TABLE book.tickets ADD book_date timestamptz DEFAULT now() NOT NULL;

BEGIN;
SET LOCAL statement_timeout to '1s';
ALTER TABLE book.tickets ADD CONSTRAINT book_tickets_date_check CHECK (book_date < '2026-06-01' and book_date is not null) not valid;
COMMIT;
ALTER TABLE book.tickets VALIDATE CONSTRAINT book_tickets_date_check;
ALTER TABLE book.tickets DROP CONSTRAINT book_tickets_date_check;

CREATE TABLE book.tickets_part (
    id bigserial PRIMARY KEY,
    fkRide int REFERENCES book.ride(id), 
    fio text,
    contact jsonb,
    fkSeat int REFERENCES book.seat(id),
    book_date timestamptz DEFAULT now()
) PARTITION BY RANGE (book_date);

CREATE TABLE book.tickets_part (
    id bigint NOT NULL,
    fkRide int REFERENCES book.ride(id), 
    fio text,
    contact jsonb,
    fkSeat int REFERENCES book.seat(id),
    book_date timestamptz DEFAULT now(),
    PRIMARY KEY (id, book_date)
) PARTITION BY RANGE (book_date);

CREATE TABLE book.tickets_part_y2026m6above PARTITION OF book.tickets_part FOR VALUES FROM ('2026-06-01') TO (MAXVALUE);

BEGIN;
SET statement_timeout TO '1s';
ALTER TABLE book.tickets RENAME TO tickets_archive;
ALTER TABLE book.tickets_part RENAME TO tickets;
ALTER TABLE book.tickets ATTACH PARTITION book.tickets_archive FOR VALUES FROM (MINVALUE) to ('2026-06-01');
COMMIT;

ALTER TABLE book.tickets DROP CONSTRAINT tickets_pkey;
ALTER TABLE book.tickets ADD PRIMARY KEY (id, book_date);

EXPLAIN SELECT * FROM book.tickets WHERE book_date = now()::date;



-- 2 option
DROP TABLE book.tickets;
ALTER TABLE book.tickets2 RENAME TO tickets;
DROP TABLE book.tickets_part;

--EXPLAIN
select t.id, t.fkride, t.fio, t.contact, t.fkseat, r.startdate
into book.tickets1
from book.tickets t
join book.ride r
    on r.id=t.fkride;

set search_path='book';
DO $$
DECLARE 
v_min_date date;
v_max_date date;
v_cur_date date;
v_sql_stmt text;
c_main_table_name varchar(50) = 'tickets_part';
begin
    v_sql_stmt = 'create table '|| quote_ident(c_main_table_name) ||' (like tickets1) partition by range (startdate)';
    execute v_sql_stmt;
    v_sql_stmt = 'create table default_partition_'|| quote_ident(c_main_table_name) ||' partition of '|| quote_ident(c_main_table_name) || ' default';
    execute v_sql_stmt;
    select date_trunc('month', min(startdate)), date_trunc('month', max(startdate)) + interval '1 month'
    into v_min_date, v_max_date
    from tickets1;
    v_cur_date = v_min_date;
    loop
        v_sql_stmt = 'create table ' || quote_ident(c_main_table_name || '_' || to_char(v_cur_date, 'yyyy_mm')) || ' partition of '
        || quote_ident(c_main_table_name) || ' for values from (''' || 
        to_char(v_cur_date, 'yyyy-mm-dd')|| ''') to (''' || to_char(v_cur_date+ interval '1 month', 'yyyy-mm-dd')|| ''')';
        IF v_cur_date >= v_max_date THEN
            EXIT;
        END IF;
        execute v_sql_stmt;
        --raise notice '%', v_sql_stmt;
        v_cur_date = v_cur_date + interval '1 month';
    END LOOP;

end $$;

\dt+ book.*


INSERT INTO tickets_part SELECT * FROM tickets1;

SELECT min(startdate), max(startdate) FROM tickets_part;

DROP TABLE tickets;
ALTER TABLE tickets_part RENAME TO tickets;

CREATE INDEX ON tickets(startdate);

CREATE UNIQUE INDEX tickets_pkey ON tickets(id);

EXPLAIN SELECT * FROM tickets WHERE startdate = '2020-01-01';


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